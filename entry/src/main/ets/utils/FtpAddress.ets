import ToolsUtil from './ToolsUtil'
import { FtpServer } from '../interfaces/FtpInterface'

export interface ParsedFtpAddress {
  host: string
  port: number
  path: string
  user: string
  password: string
  hasUser: boolean
  hasPassword: boolean
  directory: boolean
}

/** Public URLs are encoded; native FFmpeg paths are decoded exactly once. */
export default class FtpAddress {
  static path(value: string): string {
    if (/[\\\u0000-\u001f\u007f]/.test(value)) throw new Error(ToolsUtil.getStringResource($r('app.string.ftp_invalid_address').id))
    const parts = value.split('/').filter((part: string) => part.length > 0)
    if (parts.some((part: string) => part === '.' || part === '..')) throw new Error(ToolsUtil.getStringResource($r('app.string.ftp_invalid_address').id))
    return parts.join('/')
  }

  static decode(value: string): string {
    try {
      return FtpAddress.path(value.split('/').map((part: string) => {
        const decoded = decodeURIComponent(part)
        if (decoded.includes('/') || decoded.includes('\\')) throw new Error('invalid')
        return decoded
      }).join('/'))
    } catch (_) { throw new Error(ToolsUtil.getStringResource($r('app.string.ftp_invalid_address').id)) }
  }

  static encode(value: string): string {
    return '/' + FtpAddress.path(value).split('/').map((part: string) => encodeURIComponent(part)).join('/')
  }

  static credentials(user: string, password: string): void {
    if (/[\u0000-\u001f\u007f]/.test(user + password) || (!user && password)) {
      throw new Error(ToolsUtil.getStringResource($r('app.string.ftp_invalid_credentials').id))
    }
  }

  static parse(value: string): ParsedFtpAddress {
    const raw = value.trim()
    const match = /^ftp:\/\/([^/]+)(\/.*)?$/i.exec(raw)
    if (!match || /[\u0000-\u0020\u007f\\]/.test(raw)) throw new Error(ToolsUtil.getStringResource($r('app.string.ftp_invalid_address').id))
    let authority = match[1]
    let user = '', password = '', hasUser = false, hasPassword = false
    const at = authority.lastIndexOf('@')
    if (at >= 0) {
      hasUser = true
      const login = authority.substring(0, at)
      authority = authority.substring(at + 1)
      const colon = login.indexOf(':')
      hasPassword = colon >= 0
      try {
        user = decodeURIComponent(colon < 0 ? login : login.substring(0, colon))
        password = colon < 0 ? '' : decodeURIComponent(login.substring(colon + 1))
      } catch (_) { throw new Error(ToolsUtil.getStringResource($r('app.string.ftp_invalid_credentials').id)) }
      FtpAddress.credentials(user, password)
    }
    const hostPort = /^(\[[0-9a-f:.]+\]|[a-z0-9._-]+)(?::([0-9]+))?$/i.exec(authority)
    const port = hostPort?.[2] ? Number(hostPort[2]) : 21
    if (!hostPort || port < 1 || port > 65535 || !Number.isInteger(port)) throw new Error(ToolsUtil.getStringResource($r('app.string.ftp_invalid_address').id))
    const path = match[2] ?? '/'
    if (/[?#]/.test(path)) throw new Error(ToolsUtil.getStringResource($r('app.string.ftp_invalid_address').id))
    return { host: hostPort[1].toLowerCase(), port: port, path: FtpAddress.decode(path), user: user,
      password: password, hasUser: hasUser, hasPassword: hasPassword, directory: !match[2] || path.endsWith('/') }
  }

  static base(value: string): string {
    const address = FtpAddress.parse(value)
    if (address.hasUser) throw new Error(ToolsUtil.getStringResource($r('app.string.ftp_use_credentials_fields').id))
    return FtpAddress.root(address) + (address.path ? FtpAddress.encode(address.path).substring(1) + '/' : '')
  }

  static root(address: ParsedFtpAddress): string {
    return `ftp://${address.host}:${address.port}/`
  }

  static uri(server: FtpServer, path: string): string {
    return `sweetftp://${server.id}${FtpAddress.encode(path)}`
  }

  static reference(value: string): string[] | null {
    return /^sweetftp:\/\/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})(\/.*)$/i.exec(value)
  }
}
