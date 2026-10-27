import { fileIo as fs } from '@kit.CoreFileKit'
import { http } from '@kit.NetworkKit'
import { util } from '@kit.ArkTS'
import { smbClose } from 'libmpvnative.so'
import SmbUtil from './SmbUtil'
import SmbAddress from './SmbAddress'
import WebDavUtil, { WebDavRequest } from './WebDavUtil'
import WebDavAddress from './WebDavAddress'
import { SmbServer } from '../interfaces/SmbInterface'
import { WebDavServer } from '../interfaces/WebDavInterface'
import { PathUtils } from './PathUtils'
import ToolsUtil from './ToolsUtil'
import BluRayDirectory from './BluRayDirectory'

interface DiscEntry { name: string; size: number; directory: boolean }
interface DiscControlFile { relative: string; size: number }

/** Navigation files are cached; M2TS data is streamed on demand by libbluray. */
export class NetworkBluRay {
  localRoot: string = ''
  streamRoot: string = ''
  headers: Record<string, string> = {}
  private request: WebDavRequest = new WebDavRequest()
  private closed: boolean = false
  private smbServer: SmbServer | undefined = undefined
  private davServer: WebDavServer | undefined = undefined
  private password: string = ''
  private rootPath: string = ''
  private smbRoot: string = ''
  private fileSessions: Set<string> = new Set()
  private bytes: number = 0

  private check(): void {
    if (this.closed) throw new Error(ToolsUtil.getStringResource($r('app.string.network_playback_cancelled').id))
  }

  async prepare(uri: string): Promise<void> {
    try {
      const match = /^(smb|webdav):\/\/([0-9a-f-]{36})\/(.*)$/i.exec(uri)
      if (!match || !BluRayDirectory.isRemoteEntry(uri)) throw new Error('Invalid disc reference')
      const path = match[1].toLowerCase() === 'smb' ? SmbAddress.decodePath(match[3]) : WebDavAddress.decode(match[3])
      this.rootPath = path.replace(/(?:^|\/)BDMV\/index\.bdmv$/i, '')
      if (match[1].toLowerCase() === 'smb') {
        this.smbServer = SmbUtil.servers().find((server: SmbServer) => server.id === match[2])
        if (!this.smbServer) throw new Error('Connection removed')
        this.password = await SmbUtil.password(this.smbServer.id)
      } else {
        this.davServer = WebDavUtil.servers().find((server: WebDavServer) => server.id === match[2])
        if (!this.davServer) throw new Error('Connection removed')
        this.password = this.davServer.user ? await WebDavUtil.password(this.davServer.id) : ''
        this.headers = WebDavUtil.headers(this.davServer.user, this.password)
        this.streamRoot = WebDavAddress.url(this.davServer, this.rootPath).replace(/\/$/, '') + '/'
      }
      this.check()
      const top = await this.list('BDMV')
      if (!top.some((e: DiscEntry) => !e.directory && e.name === 'index.bdmv') ||
        !['PLAYLIST', 'CLIPINF', 'STREAM'].every((name: string) => top.some((e: DiscEntry) => e.directory && e.name === name))) {
        throw new Error('Incomplete disc')
      }
      const files: DiscControlFile[] = top.filter((e: DiscEntry) => !e.directory &&
        (e.name === 'index.bdmv' || e.name === 'MovieObject.bdmv'))
        .map((e: DiscEntry): DiscControlFile => ({ relative: 'BDMV/' + e.name, size: e.size }))
      for (const directory of ['PLAYLIST', 'CLIPINF']) {
        const entries = await this.list('BDMV/' + directory)
        const suffix = directory === 'PLAYLIST' ? 'mpls' : 'clpi'
        const valid = entries.filter((e: DiscEntry) => !e.directory && new RegExp('^[0-9]{5}\\.' + suffix + '$').test(e.name))
        if (!valid.length) throw new Error('Missing disc metadata')
        valid.forEach((e: DiscEntry) => files.push({ relative: 'BDMV/' + directory + '/' + e.name, size: e.size }))
      }
      const streams = await this.list('BDMV/STREAM')
      if (!streams.some((e: DiscEntry) => !e.directory && /^[0-9]{5}\.m2ts$/.test(e.name) && e.size > 0)) {
        throw new Error('Missing disc streams')
      }
      if (files.length > 4096 || files.some((f: DiscControlFile) => f.size > 8 * 1024 * 1024) ||
        files.reduce((total: number, f: DiscControlFile) => total + f.size, 0) > 64 * 1024 * 1024) {
        throw new Error('Disc metadata exceeds limit')
      }
      this.check()
      this.localRoot = PathUtils.appContext!.cacheDir + '/network-bdmv-' + util.generateRandomUUID(true)
      for (const directory of ['BDMV/PLAYLIST', 'BDMV/CLIPINF', 'BDMV/STREAM']) fs.mkdirSync(this.localRoot + '/' + directory, true)
      for (let offset = 0; offset < files.length; offset += 4) {
        this.check()
        const results = await Promise.allSettled(files.slice(offset, offset + 4).map((file: DiscControlFile) => this.download(file)))
        if (results.some(result => result.status === 'rejected')) throw new Error('Disc metadata download failed')
      }
      this.check()
      if (this.smbServer) {
        const root = await SmbUtil.openDisc(uri, this.password)
        if (this.closed) { smbClose(root); this.check() }
        this.smbRoot = root
        this.streamRoot = root + '/'
      }
    } catch (_error) {
      this.close()
      throw new Error(ToolsUtil.getStringResource($r('app.string.network_bluray_prepare_failed').id))
    }
  }

  private path(relative: string): string { return this.rootPath ? this.rootPath + '/' + relative : relative }

  private async list(relative: string): Promise<DiscEntry[]> {
    this.check()
    const entries: DiscEntry[] = this.smbServer ? await SmbUtil.list(this.smbServer, this.path(relative), this.password) :
      await WebDavUtil.list(this.davServer!, this.path(relative), this.password, this.request)
    this.check()
    return entries
  }

  private async download(file: DiscControlFile): Promise<void> {
    let session = ''
    try {
      this.check()
      const url = this.smbServer ? await SmbUtil.open(SmbUtil.uri(this.smbServer, this.path(file.relative))) :
        WebDavAddress.url(this.davServer!, this.path(file.relative))
      if (this.smbServer) { session = url; this.fileSessions.add(url) }
      this.check()
      const response = await this.request.request(url, { method: http.RequestMethod.GET, header: this.headers,
        expectDataType: http.HttpDataType.ARRAY_BUFFER, usingCache: false, maxRedirects: 0,
        connectTimeout: 5000, readTimeout: 15000, maxLimit: 8 * 1024 * 1024 })
      this.check()
      if (response.responseCode !== 200 || !(response.result instanceof ArrayBuffer)) throw new Error('Disc metadata read failed')
      const bytes = response.result as ArrayBuffer
      this.bytes += bytes.byteLength
      if (this.bytes > 64 * 1024 * 1024 || bytes.byteLength < 8 ||
        (file.size > 0 && bytes.byteLength !== file.size)) throw new Error('Incomplete disc metadata')
      const data = new Uint8Array(bytes)
      const magic = String.fromCharCode(data[0], data[1], data[2], data[3])
      const expected = file.relative.endsWith('.mpls') ? 'MPLS' : file.relative.endsWith('.clpi') ? 'HDMV' :
        file.relative.endsWith('/index.bdmv') ? 'INDX' : 'MOBJ'
      if (magic !== expected) throw new Error('Invalid disc metadata')
      const out = fs.openSync(this.localRoot + '/' + file.relative, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC)
      try {
        if (fs.writeSync(out.fd, bytes) !== bytes.byteLength) throw new Error('Disc cache write failed')
      } finally { fs.closeSync(out) }
    } finally {
      if (session) { this.fileSessions.delete(session); smbClose(session) }
    }
  }

  close(): void {
    this.closed = true
    this.request.close()
    this.fileSessions.forEach((url: string) => smbClose(url))
    this.fileSessions.clear()
    if (this.smbRoot) smbClose(this.smbRoot)
    this.smbRoot = ''; this.streamRoot = ''; this.headers = {}; this.password = ''
    const root = this.localRoot
    this.localRoot = ''
    const prefix = PathUtils.appContext?.cacheDir + '/network-bdmv-'
    if (root.startsWith(prefix) && /^[0-9a-f-]{36}$/i.test(root.substring(prefix.length))) {
      try { fs.rmdirSync(root) } catch (_) {}
    }
  }
}
