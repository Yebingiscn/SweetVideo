import preferences from '@ohos.data.preferences'
import asset from '@ohos.security.asset'
import { util } from '@kit.ArkTS'
import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import { http } from '@kit.NetworkKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { smbClose, SmbEntry, smbList, smbOpen, SmbOptions } from 'libmpvnative.so'
import { SmbServer } from '../interfaces/SmbInterface'
import { PathUtils } from './PathUtils'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import TextEncodingUtil from './TextEncodingUtil'
import SmbAddress, { ParsedSmbAddress } from './SmbAddress'
import { salmonLogger } from 'salmonlogger'
import ToolsUtil from './ToolsUtil'

const TAG = 'SmbUtil'

export default class SmbUtil {
  static editingServer: SmbServer | undefined = undefined
  private static subtitleTasks: Map<string, Promise<void>> = new Map()

  static servers(): SmbServer[] {
    try {
      const store = preferences.getPreferencesSync(PathUtils.appContext!, { name: 'smb_servers' })
      return JSON.parse(store.getSync('servers', '[]') as string) as SmbServer[]
    } catch (error) {
      return []
    }
  }

  static async password(id: string): Promise<string> {
    const query: asset.AssetMap = new Map()
    query.set(asset.Tag.ALIAS, SmbUtil.alias(id))
    query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL)
    try {
      const values = await asset.query(query)
      if (values.length === 0) {
        return ''
      }
      const bytes = values[0].get(asset.Tag.SECRET) as Uint8Array
      // JSON wrapping also represents an intentionally empty guest password.
      return JSON.parse(util.TextDecoder.create('utf-8').decodeToString(bytes)) as string
    } catch (error) {
      throw new Error('无法读取 SMB 密码，请编辑服务器并重新保存')
    }
  }

  static async save(server: SmbServer, password: string): Promise<void> {
    const attributes: asset.AssetMap = new Map()
    attributes.set(asset.Tag.ALIAS, SmbUtil.alias(server.id))
    attributes.set(asset.Tag.SECRET, new util.TextEncoder().encodeInto(JSON.stringify(password)))
    attributes.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_FIRST_UNLOCKED)
    attributes.set(asset.Tag.CONFLICT_RESOLUTION, asset.ConflictResolution.OVERWRITE)
    try {
      await asset.add(attributes)
    } catch (error) {
      salmonLogger.addLog(TAG, 'save error', true)
    }
    const servers = SmbUtil.servers().filter((item: SmbServer) => item.id !== server.id)
    servers.push(server)
    await SmbUtil.writeServers(servers)
  }

  static async remove(id: string): Promise<void> {
    const query: asset.AssetMap = new Map()
    query.set(asset.Tag.ALIAS, SmbUtil.alias(id))
    try {
      await asset.remove(query)
    } catch (error) {
      salmonLogger.addLog(TAG, 'remover error', true)
    }
    await SmbUtil.writeServers(SmbUtil.servers().filter((item: SmbServer) => item.id !== id))
  }

  static options(server: SmbServer, password: string): SmbOptions {
    const host = server.host.includes(':') && !server.host.startsWith('[') ? `[${server.host}]` : server.host
    return {
      host: `${host}:${server.port}`,
      share: server.share,
      user: server.user,
      password: password,
      domain: server.domain,
      seal: server.seal
    }
  }

  static async list(server: SmbServer, path: string, password?: string): Promise<SmbEntry[]> {
    const secret = password === undefined ? await SmbUtil.password(server.id) : password
    salmonLogger.addLog(TAG, `[SMB] 开始列目录 host=${server.host}:${server.port} share=${server.share} path=${path}`)
    try {
      const entries = await smbList(SmbUtil.options(server, secret), path)
      salmonLogger.addLog(TAG, `[SMB] 列目录成功 path=${path} entries=${entries.length}`)
      return entries.sort((a: SmbEntry, b: SmbEntry) => {
        if (a.directory !== b.directory) {
          return a.directory ? -1 : 1
        }
        return a.name.localeCompare(b.name, 'zh-CN', { numeric: true })
      })
    } catch (error) {
      salmonLogger.addLog(TAG, `[SMB] 列目录失败 path=${path}: ${error}`, true)
      throw error instanceof Error ? error : new Error(String(error))
    }
  }

  static uri(server: SmbServer, path: string): string {
    return `smb://${server.id}/${path.split('/').map((part: string) => encodeURIComponent(part)).join('/')}`
  }

  static isSmb(uri: string): boolean {
    return SmbAddress.isSmb(uri)
  }

  /** Persist credentials before a pasted address can enter stream lists or history. */
  static async prepareUri(value: string): Promise<string> {
    const uri = value.trim()
    if (!SmbUtil.isSmb(uri)) {
      return uri
    }
    const id = SmbUtil.referenceId(uri)
    if (id) {
      const server = SmbUtil.servers().find((item: SmbServer) => item.id === id)
      if (!server) {
        throw new Error('SMB 服务器已删除，请重新添加')
      }
      const path = SmbAddress.decodePath(uri.substring(uri.indexOf('/', 6) + 1))
      if (!path || uri.endsWith('/')) {
        throw new Error('请输入具体文件地址；目录请在 SMB 页面打开')
      }
      return SmbUtil.uri(server, path)
    }
    const address = SmbAddress.parse(uri)
    if (!address.share || !address.path || address.directory) {
      throw new Error(
        '请输入包含共享名和文件名的 SMB 地址；目录请在 SMB 页面打开')
    }
    const matches = SmbUtil.matchingServers(address)
    let server: SmbServer | undefined = undefined
    if (!address.hasPassword) {
      if (matches.length > 1) {
        throw new Error('此共享有多个已保存账号，请在地址中指定用户名，或从 SMB 页面选择连接')
      }
      server = matches[0]
    } else {
      // A pasted password must not overwrite a working connection used by other files.
      for (const candidate of matches) {
        if (await SmbUtil.password(candidate.id) === address.password) {
          server = candidate;
          break
        }
      }
    }
    if (!server) {
      server = {
        id: util.generateRandomUUID(true),
        name: `${address.host} / ${address.share}${address.user ? ' (' + address.user + ')' : ''}`,
        host: address.host,
        port: address.port,
        share: address.share,
        user: address.user,
        domain: address.domain,
        seal: matches.some((candidate: SmbServer) => candidate.seal)
      }
      await SmbUtil.save(server, address.password)
    }
    return SmbUtil.uri(server, address.path)
  }

  /** Reconstruct an editable, credential-free network address for saved stream references. */
  static displayUri(value: string): string {
    const id = SmbUtil.referenceId(value)
    if (!id) {
      return value
    }
    const server = SmbUtil.servers().find((item: SmbServer) => item.id === id)
    if (!server) {
      return value
    }
    const host =
      server.host.includes(':') && !server.host.startsWith('[') ? `[${server.host.replace('%', '%25')}]` : server.host
    const login = server.user || server.domain ?
      `${encodeURIComponent(server.domain ? server.domain + ';' + server.user : server.user)}@` : ''
    return `smb://${login}${host}${server.port === 445 ? '' : ':' + server.port}/${encodeURIComponent(
      server.share)}/${value.substring(value.indexOf('/', 6) + 1)}`
  }

  static async fileId(uri: string): Promise<string> {
    try {
      const md = cryptoFramework.createMd('SHA256')
      await md.update({ data: new util.TextEncoder().encodeInto(uri) })
      const digest = await md.digest()
      return 'smb_' + Array.from(digest.data).map((byte: number) => byte.toString(16).padStart(2, '0')).join('')
    } catch (error) {
      return ''
    }
  }

  static async open(uri: string): Promise<string> {
    uri = await SmbUtil.prepareUri(uri)
    const slash = uri.indexOf('/', 6)
    if (slash < 0) {
      throw new Error('SMB 文件地址无效')
    }
    const id = uri.substring(6, slash)
    const server = SmbUtil.servers().find((item: SmbServer) => item.id === id)
    if (!server) {
      throw new Error('SMB 服务器已删除，请重新添加')
    }
    const path = uri.substring(slash + 1).split('/').map((part: string) => ToolsUtil.safeDecodeURIComponent(part)).join('/')
    salmonLogger.addLog(TAG, `[SMB] 开始打开文件 host=${server.host}:${server.port} share=${server.share} path=${path}`)
    try {
      const url = await smbOpen(SmbUtil.options(server, await SmbUtil.password(id)), path, util.generateRandomUUID(true))
      salmonLogger.addLog(TAG, `[SMB] 文件打开成功 path=${path}`)
      return url
    } catch (error) {
      salmonLogger.addLog(TAG, `[SMB] 文件打开失败 path=${path}: ${error}`, true)
      throw error instanceof Error ? error : new Error(String(error))
    }
  }

  static playable(name: string): boolean {
    return /\.(mp4|mkv|avi|mov|wmv|flv|ts|m2ts|mts|m4v|webm|mpg|mpeg|rm|rmvb|vob|mp3|flac|wav|aac|m4a|ogg|opus|ape|aiff|aif|wma|dff|dsf|dts|ac3|eac3|av3a)$/i.test(
      name)
  }

  static async cacheSubtitle(item: VideoMetadata): Promise<void> {
    if (!item.smb_subtitle_uri || !SmbUtil.isSmb(item.uri)) {
      return
    }
    const pending = SmbUtil.subtitleTasks.get(item.date)
    if (pending) {
      return pending
    }
    const task = SmbUtil.downloadSubtitle(item)
    SmbUtil.subtitleTasks.set(item.date, task)
    try {
      await task
    } finally {
      SmbUtil.subtitleTasks.delete(item.date)
    }
  }

  private static async writeServers(servers: SmbServer[]): Promise<void> {
    try {
      const store = preferences.getPreferencesSync(PathUtils.appContext!, { name: 'smb_servers' })
      store.putSync('servers', JSON.stringify(servers))
      await store.flush()
    } catch (error) {
      salmonLogger.addLog(TAG, 'writeServers erro', true)
    }

  }

  private static alias(id: string): Uint8Array {
    return new util.TextEncoder().encodeInto(`sweetvideo.smb.${id}`)
  }

  private static referenceId(uri: string): string {
    const match = /^smb:\/\/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\//i.exec(uri.trim())
    return match ? match[1].toLowerCase() : ''
  }

  private static matchingServers(address: ParsedSmbAddress): SmbServer[] {
    return SmbUtil.servers().filter((server: SmbServer) =>
    server.host.replace(/^\[|\]$/g, '').toLowerCase() === address.host &&
      server.port === address.port && server.share.toLowerCase() === address.share.toLowerCase() &&
      (!address.hasUser ||
        (server.user === address.user && server.domain.toLowerCase() === address.domain.toLowerCase())))
  }

  private static async downloadSubtitle(item: VideoMetadata): Promise<void> {
    if (!/^smb_[0-9a-f]{64}$/.test(item.date)) {
      return
    }
    const path = PathUtils.subtitlePath + item.date
    try {
      if (await fs.access(path)) {
        return
      }
    } catch (error) {
      // A missing subtitle is expected; other access failures should be visible.
      const message = error instanceof Error ? error.message : String(error)
      if (!message.toLowerCase().includes('not exist') && !message.includes('13900002')) {
        salmonLogger.addLog(TAG, `检查字幕缓存失败: ${message}`, true)
        throw new Error('无法检查字幕缓存文件')
      }
    }
    let url = ''
    try {
      url = await SmbUtil.open(item.smb_subtitle_uri!)
    } catch (error) {
      salmonLogger.addLog(TAG, `打开共享字幕失败: ${error}`, true)
      throw new Error('无法打开共享字幕')
    }
    let request: http.HttpRequest | undefined = undefined
    const temporary = `${path}.${util.generateRandomUUID(true)}.tmp`
    try {
      try {
        request = http.createHttp()
      } catch (error) {
        salmonLogger.addLog(TAG, `创建字幕请求失败: ${error}`, true)
        throw new Error('无法创建字幕请求')
      }
      let response: http.HttpResponse
      try {
        response = await request.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: 5000,
        readTimeout: 10000,
        maxLimit: 8 * 1024 * 1024,
        usingCache: false
        })
      } catch (error) {
        salmonLogger.addLog(TAG, `请求共享字幕失败: ${error}`, true)
        throw new Error('共享字幕请求失败')
      }
      if (response.responseCode !== 200) {
        throw new Error('字幕读取失败')
      }
      const bytes = response.result as ArrayBuffer
      const encoding = TextEncodingUtil.detectBufferEncoding(bytes) || 'UTF-8'
      const text = util.TextDecoder.create(encoding).decodeToString(new Uint8Array(bytes))
      let file: fs.File
      try {
        file = await fs.open(temporary, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC)
      } catch (error) {
        salmonLogger.addLog(TAG, `创建字幕临时文件失败: ${error}`, true)
        throw new Error('无法创建字幕临时文件')
      }
      try {
        try {
          await fs.write(file.fd, text)
        } catch (error) {
          salmonLogger.addLog(TAG, `写入字幕临时文件失败: ${error}`, true)
          throw new Error('无法写入字幕临时文件')
        }
      } finally {
        try {
          await fs.close(file)
        } catch (error) {
          salmonLogger.addLog(TAG, `关闭字幕临时文件失败: ${error}`, true)
          throw new Error('无法关闭字幕临时文件')
        }
      }
      try {
        await fs.rename(temporary, path)
      } catch (error) {
        salmonLogger.addLog(TAG, `提交字幕缓存失败: ${error}`, true)
        throw new Error('无法保存字幕缓存')
      }
    } catch (error) {
      salmonLogger.addLog(TAG, `下载字幕失败: ${error}`, true)
      throw error instanceof Error ? error : new Error(String(error))
    } finally {
      try {
        request?.destroy()
      } catch (error) {
        salmonLogger.addLog(TAG, `关闭字幕请求失败: ${error}`, true)
      }
      try {
        if (url) {
          smbClose(url)
        }
      } catch (error) {
        salmonLogger.addLog(TAG, `关闭字幕 SMB 会话失败: ${error}`, true)
      }
      try {
        if (await fs.access(temporary)) {
          await fs.unlink(temporary)
        }
      } catch (error) {
        salmonLogger.addLog(TAG, `清理字幕临时文件失败: ${error}`, true)
      }
    }
  }
}

/** Each player owns its URL; late opens after a switch/release are discarded. */
export class SmbPlayback {
  private source: string = ''
  private url: string = ''
  private version: number = 0

  async resolve(source: string): Promise<string> {
    if (source === this.source && this.url) {
      return this.url
    }
    this.close()
    if (!SmbUtil.isSmb(source)) {
      return source
    }
    const version = this.version
    salmonLogger.addLog(TAG, `[SMB] 准备播放 source=${source}`)
    let url: string
    try {
      url = await SmbUtil.open(source)
    } catch (error) {
      salmonLogger.addLog(TAG, `[SMB] 播放打开失败 source=${source}: ${error}`, true)
      throw error instanceof Error ? error : new Error(String(error))
    }
    if (version !== this.version) {
      smbClose(url)
      salmonLogger.addLog(TAG, '[SMB] 播放请求已取消，已关闭临时会话')
      throw new Error('SMB 播放请求已取消')
    }
    this.source = source
    this.url = url
    salmonLogger.addLog(TAG, '[SMB] 播放会话已就绪')
    return url
  }

  current(source: string): string {
    if (SmbUtil.isSmb(source)) {
      if (source !== this.source || !this.url) {
        throw new Error('SMB 播放连接尚未就绪')
      }
      return this.url
    }
    return source
  }

  close(): void {
    this.version++
    if (this.url) {
      smbClose(this.url)
      salmonLogger.addLog(TAG, '[SMB] 播放会话已关闭')
    }
    this.source = ''
    this.url = ''
  }
}
