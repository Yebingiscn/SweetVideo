import SmbUtil, { SmbPlayback } from './SmbUtil'
import WebDavUtil, { WebDavRequest, WebDavSource } from './WebDavUtil'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import ToolsUtil from './ToolsUtil.ets'
import FtpUtil, { FtpPlayback } from './FtpUtil'

/** Credentials belong to a player session, never to persisted media metadata. */
export class NetworkPlayback {
  static async cacheSubtitle(item: VideoMetadata): Promise<void> {
    if (FtpUtil.isFtp(item.uri)) await FtpUtil.cacheSubtitle(item)
    else if (/^webdav:\/\//i.test(item.uri)) await WebDavUtil.cacheSubtitle(item)
    else await SmbUtil.cacheSubtitle(item)
  }

  private smb: SmbPlayback = new SmbPlayback()
  private ftp: FtpPlayback = new FtpPlayback()
  private source: string = ''
  private url: string = ''
  private authorization: Record<string, string> = {}
  private version: number = 0
  private request: WebDavRequest | undefined = undefined

  async resolve(source: string): Promise<string> {
    if (this.source === source && this.url) return this.url
    this.close()
    if (/^(ftps|sftp):\/\//i.test(source)) throw new Error(ToolsUtil.getStringResource($r('app.string.ftp_plain_only').id))
    const version = this.version
    if (FtpUtil.isFtp(source)) {
      const url = await this.ftp.resolve(source)
      if (version !== this.version) throw new Error(ToolsUtil.getStringResource($r('app.string.ftp_cancelled').id))
      this.url = url
    } else if (/^webdav:\/\//i.test(source)) {
      const request = new WebDavRequest()
      this.request = request
      let resolved: WebDavSource
      try { resolved = await WebDavUtil.prepareSource(source, request) }
      finally {
        request.close()
        if (this.request === request) this.request = undefined
      }
      if (version !== this.version) throw new Error(ToolsUtil.getStringResource($r('app.string.webdav_playback_cancelled').id))
      this.authorization = resolved.headers
      this.url = resolved.url
    } else {
      const url = await this.smb.resolve(source)
      if (version !== this.version) throw new Error(ToolsUtil.getStringResource($r('app.string.network_playback_cancelled').id))
      this.url = url
    }
    this.source = source
    return this.url
  }

  current(source: string): string {
    if (FtpUtil.isFtp(source) || /^webdav:\/\//i.test(source)) {
      if (source !== this.source || !this.url) throw new Error(ToolsUtil.getStringResource($r('app.string.network_playback_cancelled').id))
      return this.url
    }
    return this.smb.current(source)
  }

  headers(original?: Record<string, string>): Record<string, string> | undefined {
    if (FtpUtil.isFtp(this.source)) return undefined
    return /^webdav:\/\//i.test(this.source) ? this.authorization : original
  }

  close(): void {
    this.version++
    this.request?.close()
    this.request = undefined
    this.smb.close()
    this.ftp.close()
    this.source = ''; this.url = ''; this.authorization = {}
  }
}
