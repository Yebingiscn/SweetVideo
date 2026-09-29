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
      if (!embedded || !user || /[;\\]/.test(user)) throw new Error('域账号格式应为 域\\用户名')
      if (domain && domain.toLowerCase() !== embedded.toLowerCase()) throw new Error('用户名中的域与域输入框不一致')
      domain = embedded
    }
    if (/[\u0000-\u001f\u007f]/.test(user + domain)) throw new Error('SMB 账号包含控制字符')
    if (!user && domain) throw new Error('填写域时也需要填写用户名')
    return { user: user, domain: domain }
  }

  static isSmb(value: string): boolean { return /^smb:\/\//i.test(value.trim()) }

  private static decode(value: string): string {
    try {
      const decoded = decodeURIComponent(value)
      if (/[\u0000-\u001f\u007f]/.test(decoded)) throw new Error()
      return decoded
    } catch (_error) { throw new Error('SMB 地址编码无效，请将特殊字符进行 URL 编码') }
  }

  static path(value: string): string {
    const parts = value.split('/').filter((part: string) => part.length > 0)
    if (parts.some((part: string) => part === '.' || part === '..' || /[\\\u0000-\u001f\u007f]/.test(part))) {
      throw new Error('SMB 路径不能包含 ..、反斜杠或控制字符')
    }
    return parts.join('/')
  }

  static decodePath(value: string): string {
    const parts = value.split('/').filter((part: string) => part.length > 0).map((part: string) => {
      const decoded = SmbAddress.decode(part)
      if (decoded.includes('/') || decoded.includes('\\')) throw new Error('SMB 路径段不能包含编码后的斜杠')
      return decoded
    })
    return SmbAddress.path(parts.join('/'))
  }

  static parse(value: string): ParsedSmbAddress {
    const raw = value.trim()
    if (!SmbAddress.isSmb(raw)) throw new Error('请输入 smb:// 开头的地址')
    if (/[\u0000-\u001f\u007f]/.test(raw)) throw new Error('SMB 地址包含控制字符')
    const body = raw.substring(6)
    const slash = body.indexOf('/')
    let authority = slash < 0 ? body : body.substring(0, slash)
    const rawPath = slash < 0 ? '' : body.substring(slash + 1)
    if (/[?#]/.test(rawPath)) throw new Error('SMB 文件名中的 # 和 ? 请分别写为 %23 和 %3F；暂不支持 URL 查询参数')
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
      if (close < 0) throw new Error('IPv6 地址需要使用方括号，例如 smb://[::1]/Movies')
      host = SmbAddress.decode(authority.substring(1, close))
      const suffix = authority.substring(close + 1)
      if (suffix && !/^:[0-9]+$/.test(suffix)) throw new Error('SMB 端口无效')
      portText = suffix ? suffix.substring(1) : ''
      if (!host.includes(':') || !/^[0-9a-f:.]+(?:%[a-z0-9_.-]+)?$/i.test(host)) throw new Error('IPv6 地址无效')
    } else {
      const colon = authority.indexOf(':')
      if (colon >= 0 && authority.indexOf(':', colon + 1) >= 0) throw new Error('IPv6 地址请放在方括号内')
      host = colon < 0 ? authority : authority.substring(0, colon)
      portText = colon < 0 ? '' : authority.substring(colon + 1)
      if (colon >= 0 && !portText) throw new Error('SMB 端口不能为空')
      if (!host || /[\s\\/?#@%\[\]]/.test(host)) throw new Error('SMB 主机地址无效')
    }
    const port = portText ? Number(portText) : 445
    if ((portText && !/^[0-9]+$/.test(portText)) || !Number.isInteger(port) || port < 1 || port > 65535) {
      throw new Error('端口应为 1–65535，默认 445')
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
