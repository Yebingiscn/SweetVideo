import preferences from '@ohos.data.preferences'
import asset from '@ohos.security.asset'
import { util, xml } from '@kit.ArkTS'
import { http } from '@kit.NetworkKit'
import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { salmonLogger } from 'salmonlogger'
import ToolsUtil from './ToolsUtil'
import { WebDavEntry, WebDavServer } from '../interfaces/WebDavInterface'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import { PathUtils } from './PathUtils'
import TextEncodingUtil from './TextEncodingUtil'
import WebDavAddress from './WebDavAddress'
import WebDavListing from './WebDavListing'

export interface WebDavSource {
  url: string
  headers: Record<string, string>
}

export class WebDavRequest {
  private requests: Set<http.HttpRequest> = new Set()
  private closed: boolean = false

  async request(url: string, options: http.HttpRequestOptions): Promise<http.HttpResponse> {
    if (this.closed) throw new Error(ToolsUtil.getStringResource($r('app.string.webdav_request_cancelled').id))
    const request = http.createHttp()
    this.requests.add(request)
    try {
      const response = await request.request(url, options)
      if (this.closed) throw new Error(ToolsUtil.getStringResource($r('app.string.webdav_request_cancelled').id))
      return response
    } catch (_) {
      throw new Error(this.closed ? ToolsUtil.getStringResource($r('app.string.webdav_request_cancelled').id) : ToolsUtil.getStringResource($r('app.string.webdav_request_failed_generic').id))
    } finally {
      if (this.requests.delete(request)) {
        try { request.destroy() } catch (_) {}
      }
    }
  }

  close(): void {
    this.closed = true
    this.requests.forEach((request: http.HttpRequest) => { try { request.destroy() } catch (_) {} })
    this.requests.clear()
  }
}

export default class WebDavUtil {
  static editingServer: WebDavServer | undefined = undefined
  private static subtitles: Map<string, Promise<void>> = new Map()

  static servers(): WebDavServer[] {
    try {
      return JSON.parse(preferences.getPreferencesSync(PathUtils.appContext!, { name: 'webdav_servers' })
        .getSync('servers', '[]') as string) as WebDavServer[]
    } catch (_) { throw new Error(ToolsUtil.getStringResource($r('app.string.webdav_config_read_failed').id)) }
  }

  private static alias(id: string): Uint8Array {
    return new util.TextEncoder().encodeInto(`sweetvideo.webdav.${id}`)
  }

  static async password(id: string): Promise<string> {
    const query: asset.AssetMap = new Map()
    query.set(asset.Tag.ALIAS, WebDavUtil.alias(id))
    query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL)
    try {
      const values = await asset.query(query)
      if (!values.length) throw new Error('missing')
      return JSON.parse(util.TextDecoder.create('utf-8').decodeToString(
        values[0].get(asset.Tag.SECRET) as Uint8Array)) as string
    } catch (_) { throw new Error(ToolsUtil.getStringResource($r('app.string.webdav_password_read_failed').id)) }
  }

  static async save(server: WebDavServer, password: string): Promise<void> {
    server.baseUrl = WebDavAddress.base(server.baseUrl)
    WebDavUtil.headers(server.user, password)
    const servers = WebDavUtil.servers().filter((item: WebDavServer) => item.id !== server.id)
    const attributes: asset.AssetMap = new Map()
    attributes.set(asset.Tag.ALIAS, WebDavUtil.alias(server.id))
    attributes.set(asset.Tag.SECRET, new util.TextEncoder().encodeInto(JSON.stringify(password)))
    attributes.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_FIRST_UNLOCKED)
    attributes.set(asset.Tag.CONFLICT_RESOLUTION, asset.ConflictResolution.OVERWRITE)
    try { await asset.add(attributes) } catch (_) { throw new Error(ToolsUtil.getStringResource($r('app.string.webdav_password_save_failed').id)) }
    servers.push(server)
    await WebDavUtil.write(servers)
  }

  static async remove(id: string): Promise<void> {
    await WebDavUtil.write(WebDavUtil.servers().filter((item: WebDavServer) => item.id !== id))
    const query: asset.AssetMap = new Map()
    query.set(asset.Tag.ALIAS, WebDavUtil.alias(id))
    try { await asset.remove(query) } catch (_) { salmonLogger.addLog('WebDAV', '连接已删除，凭据清理失败', true) }
  }

  private static async write(servers: WebDavServer[]): Promise<void> {
    try {
      const store = preferences.getPreferencesSync(PathUtils.appContext!, { name: 'webdav_servers' })
      store.putSync('servers', JSON.stringify(servers)); await store.flush()
    } catch (_) { throw new Error(ToolsUtil.getStringResource($r('app.string.webdav_config_save_failed').id)) }
  }

  static headers(user: string, password: string): Record<string, string> {
    if (/[\r\n\u0000]/.test(user + password) || user.includes(':')) throw new Error(ToolsUtil.getStringResource($r('app.string.webdav_credentials_invalid').id))
    if (!user && password) throw new Error(ToolsUtil.getStringResource($r('app.string.password_needs_user').id))
    const headers: Record<string, string> = {}
    if (user) headers['Authorization'] = 'Basic ' + new util.Base64Helper().encodeToStringSync(
      new util.TextEncoder().encodeInto(`${user}:${password}`))
    return headers
  }

  static checkStatus(code: number, expected: number): void {
    if (code === expected) return
    if (code === 401) throw new Error(ToolsUtil.getStringResource($r('app.string.webdav_auth_failed').id))
    if (code === 403) throw new Error(ToolsUtil.getStringResource($r('app.string.webdav_forbidden').id))
    if (code === 404) throw new Error(ToolsUtil.getStringResource($r('app.string.webdav_not_found').id))
    if (code === 405 || code === 501) throw new Error(ToolsUtil.getStringResource($r('app.string.webdav_browsing_unsupported').id))
    throw new Error(ToolsUtil.getStringResourceArgs($r('app.string.webdav_request_failed').id, code))
  }

  static async list(server: WebDavServer, folder: string, password?: string,
    owner?: WebDavRequest): Promise<WebDavEntry[]> {
    const request = owner ?? new WebDavRequest()
    try {
      const headers = WebDavUtil.headers(server.user, password ?? (server.user ? await WebDavUtil.password(server.id) : ''))
      headers['Depth'] = '1'; headers['Content-Type'] = 'application/xml; charset=utf-8'
      const url = WebDavAddress.url(server, folder).replace(/\/?$/, '/')
      // POST supplies an XML body; customMethod overrides the wire method to PROPFIND.
      const response = await request.request(url, { method: http.RequestMethod.POST, customMethod: 'PROPFIND', header: headers,
        extraData: '<?xml version="1.0" encoding="utf-8"?><d:propfind xmlns:d="DAV:"><d:prop><d:resourcetype/><d:getcontentlength/></d:prop></d:propfind>',
        expectDataType: http.HttpDataType.STRING, usingCache: false, maxRedirects: 0,
        connectTimeout: 5000, readTimeout: 15000, maxLimit: 8 * 1024 * 1024 })
      WebDavUtil.checkStatus(response.responseCode, 207)
      const text = response.result as string
      if (/<!DOCTYPE|<!ENTITY/i.test(text)) throw new Error(ToolsUtil.getStringResource($r('app.string.webdav_unsupported_xml').id))
      const listing = new WebDavListing(url, folder)
      const bytes = new util.TextEncoder().encodeInto(text)
      try {
        new xml.XmlPullParser(bytes.buffer as ArrayBuffer, 'UTF-8').parseXml({ supportDoctype: false, ignoreNameSpace: false,
        tokenValueCallbackFunction: (event: xml.EventType, info: xml.ParseInfo): boolean => {
          if (event === xml.EventType.START_TAG) listing.start(info.getName(), info.getNamespace())
          else if (event === xml.EventType.END_TAG) listing.end()
          else if (event === xml.EventType.TEXT || event === xml.EventType.CDSECT ||
            event === xml.EventType.ENTITY_REFERENCE || event === xml.EventType.WHITESPACE) listing.characters(info.getText())
          return true
        } })
      } catch (_) { throw new Error(ToolsUtil.getStringResource($r('app.string.webdav_invalid_xml').id)) }
      return listing.finish()
    } catch (error) {
      salmonLogger.addLog('WebDAV', '目录读取失败', true)
      throw error instanceof Error ? error : new Error(ToolsUtil.getStringResource($r('app.string.webdav_directory_parse_failed').id))
    } finally { if (!owner) request.close() }
  }

  static async source(uri: string): Promise<WebDavSource> {
    const match = /^webdav:\/\/([0-9a-f-]{36})(\/.*)$/i.exec(uri)
    if (!match) throw new Error(ToolsUtil.getStringResource($r('app.string.webdav_invalid_file_ref').id))
    const server = WebDavUtil.servers().find((item: WebDavServer) => item.id === match[1])
    if (!server) throw new Error(ToolsUtil.getStringResource($r('app.string.webdav_connection_deleted').id))
    return { url: WebDavAddress.url(server, WebDavAddress.decode(match[2])),
      headers: WebDavUtil.headers(server.user, server.user ? await WebDavUtil.password(server.id) : '') }
  }

  /** Reject redirecting playback endpoints before credentials enter an engine. */
  static async prepareSource(uri: string, request: WebDavRequest): Promise<WebDavSource> {
    const source = await WebDavUtil.source(uri)
    let response = await request.request(source.url, { method: http.RequestMethod.HEAD, header: source.headers,
      usingCache: false, maxRedirects: 0, connectTimeout: 5000, readTimeout: 10000 })
    if (response.responseCode === 405 || response.responseCode === 501) {
      const headers: Record<string, string> = {}
      headers['Range'] = 'bytes=0-0'
      Object.keys(source.headers).forEach((key: string) => { headers[key] = source.headers[key] })
      response = await request.request(source.url, { method: http.RequestMethod.GET, header: headers,
        expectDataType: http.HttpDataType.ARRAY_BUFFER, usingCache: false, maxRedirects: 0,
        connectTimeout: 5000, readTimeout: 10000, maxLimit: 64 * 1024 })
    }
    if (response.responseCode !== 200 && response.responseCode !== 206) {
      WebDavUtil.checkStatus(response.responseCode, 200)
    }
    return source
  }

  static async fileId(uri: string): Promise<string> {
    const md = cryptoFramework.createMd('SHA256')
    await md.update({ data: new util.TextEncoder().encodeInto(uri) })
    return 'webdav_' + Array.from((await md.digest()).data)
      .map((byte: number) => byte.toString(16).padStart(2, '0')).join('')
  }

  static async cacheSubtitle(item: VideoMetadata): Promise<void> {
    if (!item.webdav_subtitle_uri || !/^webdav_[0-9a-f]{64}$/.test(item.date)) return
    const pending = WebDavUtil.subtitles.get(item.date)
    if (pending) return pending
    const task = WebDavUtil.downloadSubtitle(item)
    WebDavUtil.subtitles.set(item.date, task)
    try { await task } finally { WebDavUtil.subtitles.delete(item.date) }
  }

  private static async downloadSubtitle(item: VideoMetadata): Promise<void> {
    const path = PathUtils.subtitlePath + item.date
    try { if (await fs.access(path)) return } catch (_) {}
    const request = new WebDavRequest()
    const temporary = `${path}.${util.generateRandomUUID(true)}.tmp`
    try {
      const source = await WebDavUtil.source(item.webdav_subtitle_uri!)
      const response = await request.request(source.url, { method: http.RequestMethod.GET, header: source.headers,
        expectDataType: http.HttpDataType.ARRAY_BUFFER, usingCache: false, maxRedirects: 0,
        connectTimeout: 5000, readTimeout: 10000, maxLimit: 8 * 1024 * 1024 })
      WebDavUtil.checkStatus(response.responseCode, 200)
      const bytes = response.result as ArrayBuffer
      const text = util.TextDecoder.create(TextEncodingUtil.detectBufferEncoding(bytes) || 'UTF-8')
        .decodeToString(new Uint8Array(bytes))
      const file = await fs.open(temporary, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC)
      try { await fs.write(file.fd, text) } finally { await fs.close(file) }
      await fs.rename(temporary, path)
    } catch (_) { throw new Error(ToolsUtil.getStringResource($r('app.string.webdav_subtitle_download_failed').id)) }
    finally {
      request.close()
      try { if (await fs.access(temporary)) await fs.unlink(temporary) } catch (_) {}
    }
  }
}
