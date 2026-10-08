import { WebDavServer } from '../interfaces/WebDavInterface'
import ToolsUtil from './ToolsUtil'

/** Paths are decoded internally, encoded once at the HTTP boundary. */
export default class WebDavAddress {
  static base(value: string): string {
    const match = /^(https?):\/\/([^/?#]+)(\/[^?#]*)?$/i.exec(value.trim())
    if (!match || /[@\s\\\u0000-\u001f\u007f]/.test(match[2])) {
      throw new Error(ToolsUtil.getStringResource($r('app.string.webdav_address_required').id))
    }
    const authority = /^(\[[0-9a-f:.]+\]|[^:\[\]%]+)(?::([0-9]+))?$/i.exec(match[2])
    if (!authority || (authority[2] && (Number(authority[2]) < 1 || Number(authority[2]) > 65535))) {
      throw new Error(ToolsUtil.getStringResource($r('app.string.webdav_host_invalid').id))
    }
    const path = WebDavAddress.decode(match[3] ?? '/')
    return `${match[1].toLowerCase()}://${match[2]}${WebDavAddress.encode(path)}/`
  }

  static path(value: string): string {
    if (/[\\\u0000-\u001f\u007f]/.test(value)) throw new Error(ToolsUtil.getStringResource($r('app.string.webdav_path_invalid').id))
    const parts = value.split('/').filter((part: string) => part.length > 0)
    if (parts.some((part: string) => part === '.' || part === '..')) throw new Error(ToolsUtil.getStringResource($r('app.string.webdav_path_dots').id))
    return parts.join('/')
  }

  static decode(value: string): string {
    try {
      return WebDavAddress.path(value.split('/').map((part: string) => {
        const decoded = decodeURIComponent(part)
        if (decoded.includes('/') || decoded.includes('\\')) throw new Error(ToolsUtil.getStringResource($r('app.string.webdav_path_slash').id))
        return decoded
      }).join('/'))
    } catch (_) { throw new Error(ToolsUtil.getStringResource($r('app.string.webdav_path_encoding').id)) }
  }

  static encode(value: string): string {
    const path = WebDavAddress.path(value)
    return path ? '/' + path.split('/').map((part: string) => encodeURIComponent(part)).join('/') : ''
  }

  static uri(server: WebDavServer, path: string): string {
    return `webdav://${server.id}${WebDavAddress.encode(path)}`
  }

  static url(server: WebDavServer, path: string): string {
    return WebDavAddress.base(server.baseUrl).replace(/\/$/, '') + WebDavAddress.encode(path)
  }

  /** Accept only direct children of the requested directory on the same origin. */
  static child(href: string, directoryUrl: string, folder: string): string | undefined {
    const directory = /^(https?:\/\/[^/]+)(\/.*)$/i.exec(directoryUrl)
    if (!directory) return undefined
    let raw = href.trim()
    if (/^https?:\/\//i.test(raw)) {
      const absolute = /^(https?:\/\/[^/]+)(\/.*)$/i.exec(raw)
      if (!absolute || absolute[1].toLowerCase() !== directory[1].toLowerCase()) return undefined
      raw = absolute[2]
    } else if (raw.startsWith('//')) return undefined
    else if (!raw.startsWith('/')) raw = directory[2].replace(/\/?$/, '/') + raw
    if (/[?#]/.test(raw)) return undefined
    const parent = WebDavAddress.decode(directory[2])
    const candidate = WebDavAddress.decode(raw)
    const prefix = parent ? parent + '/' : ''
    if (!candidate.startsWith(prefix)) return undefined
    const name = candidate.substring(prefix.length)
    if (!name || name.includes('/')) return undefined
    return WebDavAddress.path(folder ? folder + '/' + name : name)
  }
}
