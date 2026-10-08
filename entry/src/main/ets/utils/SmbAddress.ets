import ToolsUtil from './ToolsUtil'

export interface SmbLogin {
  user: string
  domain: string
}

export interface ParsedSmbAddress {
  host: string
  port: number
  share: string
  path: string
  user: string
  password: string
  domain: string
  hasUser: boolean
  hasPassword: boolean
  directory: boolean
}

/** Parse SMB addresses without URL's dot-segment or percent-encoding normalization. */
export default class SmbAddress {
  static login(user: string, domain: string = ''): SmbLogin {
    user = user.trim()
    domain = domain.trim()
    const separator = user.includes(';') ? user.indexOf(';') : user.indexOf('\\')
    if (separator >= 0) {
      const embedded = user.substring(0, separator).trim()
      user = user.substring(separator + 1).trim()
      if (!embedded || !user || /[;\\]/.test(user)) throw new Error(ToolsUtil.getStringResource($r('app.string.smb_domain_format').id))
      if (domain && domain.toLowerCase() !== embedded.toLowerCase()) throw new Error(ToolsUtil.getStringResource($r('app.string.smb_domain_mismatch').id))
      domain = embedded
    }
    if (/[\u0000-\u001f\u007f]/.test(user + domain)) throw new Error(ToolsUtil.getStringResource($r('app.string.smb_user_control_chars').id))
    if (!user && domain) throw new Error(ToolsUtil.getStringResource($r('app.string.smb_domain_needs_user').id))
    return { user: user, domain: domain }
  }

  static isSmb(value: string): boolean { return /^smb:\/\//i.test(value.trim()) }

  private static decode(value: string): string {
    try {
      const decoded = decodeURIComponent(value)
      if (/[\u0000-\u001f\u007f]/.test(decoded)) throw new Error()
      return decoded
    } catch (_error) { throw new Error(ToolsUtil.getStringResource($r('app.string.smb_address_encoding_invalid').id)) }
  }

  static path(value: string): string {
    const parts = value.split('/').filter((part: string) => part.length > 0)
    if (parts.some((part: string) => part === '.' || part === '..' || /[\\\u0000-\u001f\u007f]/.test(part))) {
      throw new Error(ToolsUtil.getStringResource($r('app.string.smb_path_invalid').id))
    }
    return parts.join('/')
  }

  static decodePath(value: string): string {
    const parts = value.split('/').filter((part: string) => part.length > 0).map((part: string) => {
      const decoded = SmbAddress.decode(part)
      if (decoded.includes('/') || decoded.includes('\\')) throw new Error(ToolsUtil.getStringResource($r('app.string.smb_path_slash').id))
      return decoded
    })
    return SmbAddress.path(parts.join('/'))
  }

  static parse(value: string): ParsedSmbAddress {
    const raw = value.trim()
    if (!SmbAddress.isSmb(raw)) throw new Error(ToolsUtil.getStringResource($r('app.string.smb_scheme_required').id))
    if (/[\u0000-\u001f\u007f]/.test(raw)) throw new Error(ToolsUtil.getStringResource($r('app.string.smb_address_control_chars').id))
    const body = raw.substring(6)
    const slash = body.indexOf('/')
    let authority = slash < 0 ? body : body.substring(0, slash)
    const rawPath = slash < 0 ? '' : body.substring(slash + 1)
    if (/[?#]/.test(rawPath)) throw new Error(ToolsUtil.getStringResource($r('app.string.smb_filename_escape').id))
    let user = '', password = '', domain = ''
    let hasUser = false, hasPassword = false
    const at = authority.lastIndexOf('@')
    if (at >= 0) {
      hasUser = true
      const credentials = authority.substring(0, at)
      authority = authority.substring(at + 1)
      const colon = credentials.indexOf(':')
      hasPassword = colon >= 0
      const login = SmbAddress.decode(colon < 0 ? credentials : credentials.substring(0, colon))
      password = colon < 0 ? '' : SmbAddress.decode(credentials.substring(colon + 1))
      const account = SmbAddress.login(login)
      domain = account.domain
      user = account.user
    }
    let host = '', portText = ''
    if (authority.startsWith('[')) {
      const close = authority.indexOf(']')
      if (close < 0) throw new Error(ToolsUtil.getStringResource($r('app.string.smb_ipv6_brackets').id))
      host = SmbAddress.decode(authority.substring(1, close))
      const suffix = authority.substring(close + 1)
      if (suffix && !/^:[0-9]+$/.test(suffix)) throw new Error(ToolsUtil.getStringResource($r('app.string.smb_port_invalid_short').id))
      portText = suffix ? suffix.substring(1) : ''
      if (!host.includes(':') || !/^[0-9a-f:.]+(?:%[a-z0-9_.-]+)?$/i.test(host)) throw new Error(ToolsUtil.getStringResource($r('app.string.smb_ipv6_invalid').id))
    } else {
      const colon = authority.indexOf(':')
      if (colon >= 0 && authority.indexOf(':', colon + 1) >= 0) throw new Error(ToolsUtil.getStringResource($r('app.string.smb_ipv6_in_brackets').id))
      host = colon < 0 ? authority : authority.substring(0, colon)
      portText = colon < 0 ? '' : authority.substring(colon + 1)
      if (colon >= 0 && !portText) throw new Error(ToolsUtil.getStringResource($r('app.string.smb_port_required').id))
      if (!host || /[\s\\/?#@%\[\]]/.test(host)) throw new Error(ToolsUtil.getStringResource($r('app.string.smb_host_invalid').id))
    }
    const port = portText ? Number(portText) : 445
    if ((portText && !/^[0-9]+$/.test(portText)) || !Number.isInteger(port) || port < 1 || port > 65535) {
      throw new Error(ToolsUtil.getStringResource($r('app.string.smb_port_invalid').id))
    }
    const path = SmbAddress.decodePath(rawPath)
    const pathSlash = path.indexOf('/')
    return {
      host: host.toLowerCase(), port: port,
      share: pathSlash < 0 ? path : path.substring(0, pathSlash),
      path: pathSlash < 0 ? '' : path.substring(pathSlash + 1),
      user: user, password: password, domain: domain, hasUser: hasUser, hasPassword: hasPassword,
      directory: !path || pathSlash < 0 || rawPath.endsWith('/')
    }
  }
}
