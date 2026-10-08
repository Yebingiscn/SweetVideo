import preferences from '@ohos.data.preferences'
import asset from '@ohos.security.asset'
import { util } from '@kit.ArkTS'
import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import { http } from '@kit.NetworkKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { ftpCancel, ftpClose, ftpList, ftpOpen, FtpOptions } from 'libmpvnative.so'
import { salmonLogger } from 'salmonlogger'
import { FtpEntry, FtpServer } from '../interfaces/FtpInterface'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import ToolsUtil from './ToolsUtil'
import FtpAddress from './FtpAddress'
import { PathUtils } from './PathUtils'
import TextEncodingUtil from './TextEncodingUtil'

interface FtpNativeError extends Error {
  code?: string;
  nativeStatus?: number
}

/** Own cancellation tokens before native work is queued, including async credential reads. */
export class FtpRequest {
  private tokens: Set<string> = new Set()
  private closed: boolean = false

  token(): string {
    if (this.closed) {
      throw new Error(ToolsUtil.getStringResource($r('app.string.ftp_cancelled').id))
    }
    const token = util.generateRandomUUID(true)
    this.tokens.add(token)
    return token
  }

  check(): void {
    if (this.closed) {
      throw new Error(ToolsUtil.getStringResource($r('app.string.ftp_cancelled').id))
    }
  }

  done(token: string): void {
    this.tokens.delete(token)
  }

  close(): void {
    this.closed = true
    this.tokens.forEach((token: string) => ftpCancel(token))
    this.tokens.clear()
  }
}

export default class FtpUtil {
  static editingServer: FtpServer | undefined = undefined
  private static subtitles: Map<string, Promise<void>> = new Map()

  static isFtp(uri: string): boolean {
    return /^(ftp|sweetftp):\/\//i.test(uri.trim())
  }

  static servers(): FtpServer[] {
    try {
      return JSON.parse(preferences.getPreferencesSync(PathUtils.appContext!, { name: 'ftp_servers' })
        .getSync('servers', '[]') as string) as FtpServer[]
    } catch (_) {
      throw new Error(ToolsUtil.getStringResource($r('app.string.ftp_config_read_failed').id))
    }
  }

  static async password(id: string): Promise<string> {
    const query: asset.AssetMap = new Map()
    query.set(asset.Tag.ALIAS, FtpUtil.alias(id));
    query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL)
    try {
      const values = await asset.query(query)
      if (!values.length) {
        throw new Error('missing')
      }
      return JSON.parse(
        util.TextDecoder.create('utf-8').decodeToString(values[0].get(asset.Tag.SECRET) as Uint8Array)) as string
    } catch (_) {
      throw new Error(ToolsUtil.getStringResource($r('app.string.ftp_password_read_failed').id))
    }
  }

  static async save(server: FtpServer, password: string): Promise<void> {
    server.baseUrl = FtpAddress.base(server.baseUrl)
    FtpAddress.credentials(server.user, password)
    const servers = FtpUtil.servers().filter((item: FtpServer) => item.id !== server.id)
    const attributes: asset.AssetMap = new Map()
    attributes.set(asset.Tag.ALIAS, FtpUtil.alias(server.id))
    attributes.set(asset.Tag.SECRET, new util.TextEncoder().encodeInto(JSON.stringify(password)))
    attributes.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_FIRST_UNLOCKED)
    attributes.set(asset.Tag.CONFLICT_RESOLUTION, asset.ConflictResolution.OVERWRITE)
    try {
      await asset.add(attributes)
    } catch (_) {
      throw new Error(ToolsUtil.getStringResource($r('app.string.ftp_password_save_failed').id))
    }
    servers.push(server);
    await FtpUtil.write(servers)
  }

  static async remove(id: string): Promise<void> {
    await FtpUtil.write(FtpUtil.servers().filter((item: FtpServer) => item.id !== id))
    const query: asset.AssetMap = new Map();
    query.set(asset.Tag.ALIAS, FtpUtil.alias(id))
    try {
      await asset.remove(query)
    } catch (_) {
      salmonLogger.addLog('FTP', '连接已删除，凭据清理失败', true)
    }
  }

  static error(error: FtpNativeError): Error {
    const code = error?.code ?? ''
    salmonLogger.addLog('FTP',
      `操作失败 code=${/^ftp_[a-z_]+$/.test(code) ? code : 'unknown'} status=${error?.nativeStatus ?? 0}`, true)
    let message: Resource = $r('app.string.ftp_request_failed')
    if (code === 'ftp_auth_failed') {
      message = $r('app.string.ftp_auth_failed')
    } else if (code ===
      'ftp_timeout') {
      message = $r('app.string.ftp_timeout')
    } else if (code === 'ftp_connection_refused') {
      message =
        $r('app.string.ftp_connection_refused')
    } else if (code === 'ftp_cancelled') {
      message =
        $r('app.string.ftp_cancelled')
    } else if (code === 'ftp_unavailable') {
      message =
        $r('app.string.ftp_unavailable')
    } else if (code === 'ftp_listing_unsupported') {
      message =
        $r('app.string.ftp_listing_unsupported')
    } else if (code === 'ftp_invalid_listing') {
      message =
        $r('app.string.ftp_invalid_listing')
    } else if (code === 'ftp_directory_too_large') {
      message =
        $r('app.string.ftp_directory_too_large')
    } else if (code === 'ftp_seek_unsupported' ||
      code === 'ftp_size_unsupported') {
      message = $r('app.string.ftp_seek_unsupported')
    } else if (code ===
      'ftp_busy') {
      message = $r('app.string.ftp_busy')
    } else if (code === 'ftp_invalid_address') {
      message =
        $r('app.string.ftp_invalid_address')
    }
    return new Error(ToolsUtil.getStringResource(message.id))
  }

  static async list(server: FtpServer, folder: string, password?: string, owner?: FtpRequest): Promise<FtpEntry[]> {
    const request = owner ?? new FtpRequest()
    const token = request.token()
    try {
      const options = FtpUtil.options(server, password ?? await FtpUtil.password(server.id))
      request.check()
      let entries: FtpEntry[]
      try {
        entries = await ftpList(options, FtpUtil.path(server, folder), token)
      } catch (error) {
        throw FtpUtil.error(error as FtpNativeError)
      }
      request.check()
      return entries.sort((a: FtpEntry, b: FtpEntry) => a.directory !== b.directory ? (a.directory ? -1 : 1) :
        a.name.localeCompare(b.name))
    } finally {
      request.done(token);
      if (!owner) {
        request.close()
      }
    }
  }

  static async prepareUri(value: string): Promise<string> {
    const uri = value.trim()
    if (/^(ftps|sftp):\/\//i.test(uri)) {
      throw new Error(ToolsUtil.getStringResource($r('app.string.ftp_plain_only').id))
    }
    if (!FtpUtil.isFtp(uri)) {
      return uri
    }
    const reference = FtpAddress.reference(uri)
    if (reference) {
      const server = FtpUtil.servers().find((item: FtpServer) => item.id === reference[1])
      if (!server) {
        throw new Error(ToolsUtil.getStringResource($r('app.string.ftp_connection_deleted').id))
      }
      const path = FtpAddress.decode(reference[2])
      if (!path || uri.endsWith('/')) {
        throw new Error(
          ToolsUtil.getStringResource($r('app.string.ftp_file_required').id))
      }
      return FtpAddress.uri(server, path)
    }
    const address = FtpAddress.parse(uri)
    if (!address.path || address.directory) {
      throw new Error(
        ToolsUtil.getStringResource($r('app.string.ftp_file_required').id))
    }
    const base = FtpAddress.root(address)
    const matches = FtpUtil.servers().filter((item: FtpServer) => item.baseUrl === base && item.user === address.user)
    let server: FtpServer | undefined = undefined
    if (!address.hasPassword) {
      if (matches.length > 1) {
        throw new Error(ToolsUtil.getStringResource($r('app.string.ftp_multiple_accounts').id))
      }
      server = matches[0]
    } else {
      for (const candidate of matches) {
        if (await FtpUtil.password(candidate.id) === address.password) {
          server = candidate;
          break
        }
      }
    }
    if (!server) {
      server = {
        id: util.generateRandomUUID(true),
        name: address.host,
        baseUrl: base,
        user: address.user
      }
      await FtpUtil.save(server, address.password)
    }
    return FtpAddress.uri(server, address.path)
  }

  static displayUri(uri: string): string {
    const reference = FtpAddress.reference(uri)
    if (!reference) {
      return uri
    }
    const server = FtpUtil.servers().find((item: FtpServer) => item.id === reference[1])
    if (!server) {
      return uri
    }
    const base =
      server.user ? server.baseUrl.replace(/^ftp:\/\//i, `ftp://${encodeURIComponent(server.user)}@`) : server.baseUrl
    return base + FtpAddress.encode(FtpAddress.decode(reference[2])).substring(1)
  }

  static async open(uri: string, request: FtpRequest): Promise<string> {
    const token = request.token()
    try {
      const reference = FtpAddress.reference(await FtpUtil.prepareUri(uri))
      if (!reference) {
        throw new Error(ToolsUtil.getStringResource($r('app.string.ftp_invalid_address').id))
      }
      const server = FtpUtil.servers().find((item: FtpServer) => item.id === reference[1])
      if (!server) {
        throw new Error(ToolsUtil.getStringResource($r('app.string.ftp_connection_deleted').id))
      }
      const options = FtpUtil.options(server, await FtpUtil.password(server.id))
      request.check()
      let url: string
      try {
        url = await ftpOpen(options, FtpUtil.path(server, FtpAddress.decode(reference[2])), token)
      } catch (error) {
        throw FtpUtil.error(error as FtpNativeError)
      }
      try {
        request.check()
      } catch (error) {
        ftpClose(url);
        throw error instanceof Error ? error : new Error('cancelled')
      }
      return url
    } finally {
      request.done(token)
    }
  }

  static async fileId(uri: string): Promise<string> {
    try {
      const md = cryptoFramework.createMd('SHA256')
      await md.update({ data: new util.TextEncoder().encodeInto(uri) })
      return 'ftp_' +
        Array.from((await md.digest()).data).map((byte: number) => byte.toString(16).padStart(2, '0')).join('')
    } catch (error) {
      return ''
    }
  }

  static async cacheSubtitle(item: VideoMetadata): Promise<void> {
    if (!item.ftp_subtitle_uri || !/^ftp_[0-9a-f]{64}$/.test(item.date)) {
      return
    }
    const pending = FtpUtil.subtitles.get(item.date)
    if (pending) {
      return pending
    }
    const task = FtpUtil.downloadSubtitle(item)
    FtpUtil.subtitles.set(item.date, task)
    try {
      await task
    } finally {
      FtpUtil.subtitles.delete(item.date)
    }
  }

  private static alias(id: string): Uint8Array {
    return new util.TextEncoder().encodeInto(`sweetvideo.ftp.${id}`)
  }

  private static async write(servers: FtpServer[]): Promise<void> {
    try {
      const store = preferences.getPreferencesSync(PathUtils.appContext!, { name: 'ftp_servers' })
      store.putSync('servers', JSON.stringify(servers));
      await store.flush()
    } catch (_) {
      throw new Error(ToolsUtil.getStringResource($r('app.string.ftp_config_save_failed').id))
    }
  }

  private static options(server: FtpServer, password: string): FtpOptions {
    const address = FtpAddress.parse(server.baseUrl)
    FtpAddress.credentials(server.user, password)
    return {
      host: address.host,
      port: address.port,
      user: server.user,
      password: password
    }
  }

  private static path(server: FtpServer, folder: string): string {
    return FtpAddress.path(
      [FtpAddress.parse(server.baseUrl).path, folder].filter((part: string) => part.length > 0).join('/'))
  }

  private static async downloadSubtitle(item: VideoMetadata): Promise<void> {
    const path = PathUtils.subtitlePath + item.date
    try {
      if (await fs.access(path)) {
        return
      }
    } catch (_) {
    }
    const request = new FtpRequest()
    const temporary = `${path}.${util.generateRandomUUID(true)}.tmp`
    const httpRequest = http.createHttp()
    let url = ''
    try {
      url = await FtpUtil.open(item.ftp_subtitle_uri!, request)
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        usingCache: false,
        maxRedirects: 0,
        connectTimeout: 5000,
        readTimeout: 15000,
        maxLimit: 8 * 1024 * 1024
      })
      if (response.responseCode !== 200) {
        throw new Error('request')
      }
      const bytes = response.result as ArrayBuffer
      const text = util.TextDecoder.create(TextEncodingUtil.detectBufferEncoding(bytes) || 'UTF-8')
        .decodeToString(new Uint8Array(bytes))
      const file = await fs.open(temporary, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC)
      try {
        await fs.write(file.fd, text)
      } finally {
        await fs.close(file)
      }
      await fs.rename(temporary, path)
    } catch (_) {
      throw new Error(ToolsUtil.getStringResource($r('app.string.ftp_subtitle_download_failed').id))
    } finally {
      request.close()
      try {
        httpRequest.destroy()
      } catch (_) {
      }
      if (url) {
        try {
          ftpClose(url)
        } catch (_) {
        }
      }
      try {
        if (await fs.access(temporary)) {
          await fs.unlink(temporary)
        }
      } catch (_) {
      }
    }
  }
}

export class FtpPlayback {
  private request: FtpRequest | undefined = undefined
  private url: string = ''

  async resolve(uri: string): Promise<string> {
    this.close()
    const request = new FtpRequest();
    this.request = request
    try {
      const url = await FtpUtil.open(uri, request)
      if (this.request !== request) {
        ftpClose(url);
        throw new Error(ToolsUtil.getStringResource($r('app.string.ftp_cancelled').id))
      }
      this.url = url
      return url
    } finally {
      request.close();
      if (this.request === request) {
        this.request = undefined
      }
    }
  }

  close(): void {
    this.request?.close();
    this.request = undefined
    if (this.url) {
      ftpClose(this.url)
    }
    this.url = ''
  }
}
