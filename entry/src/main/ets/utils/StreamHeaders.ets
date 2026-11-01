import ToolsUtil from './ToolsUtil'

export interface StreamAddress {
  url: string
  headers: Record<string, string>
}

/** Shared parsing for user-entered headers, M3U directives and URL pipe options. */
export default class StreamHeaders {
  static put(headers: Record<string, string>, name: string, value: string): void {
    let key = name.trim().toLowerCase().replace(/^!/, '')
    if (key === 'referrer') key = 'referer'
    if (key === 'ua' || key === 'user_agent') key = 'user-agent'
    if (!/^[a-z0-9!#$%&'*+.^_`|~-]+$/.test(key) || /[\x00-\x1f\x7f]/.test(value) ||
      ['host', 'content-length', 'transfer-encoding', 'connection'].includes(key)) {
      throw new Error(ToolsUtil.getStringResource($r('app.string.stream_headers_invalid').id))
    }
    headers[key] = value.trim()
  }

  static merge(base?: Record<string, string>, overrides?: Record<string, string>): Record<string, string> {
    const result: Record<string, string> = {}
    for (const source of [base, overrides]) {
      if (source) Object.keys(source).forEach((key: string) => StreamHeaders.put(result, key, source[key]))
    }
    // Leave room for separators and escaping in the native 8 KiB header buffer.
    if (encodeURIComponent(JSON.stringify(result)).length > 7000) {
      throw new Error(ToolsUtil.getStringResource($r('app.string.stream_headers_invalid').id))
    }
    return result
  }

  static parseText(text: string): Record<string, string> {
    const headers: Record<string, string> = {}
    for (const line of text.replace(/\r\n/g, '\n').split('\n')) {
      if (!line.trim()) continue
      const colon = line.indexOf(':')
      if (colon <= 0) throw new Error(ToolsUtil.getStringResource($r('app.string.stream_headers_invalid').id))
      StreamHeaders.put(headers, line.substring(0, colon), line.substring(colon + 1).trim())
    }
    return StreamHeaders.merge(headers)
  }

  static format(headers?: Record<string, string>): string {
    return headers ? Object.keys(headers).map((key: string) => `${key}: ${headers[key]}`).join('\n') : ''
  }

  static options(text: string): Record<string, string> {
    const headers: Record<string, string> = {}
    for (const item of text.split(/[&|]/)) {
      const eq = item.indexOf('=')
      if (eq <= 0) continue
      const key = ToolsUtil.safeDecodeURIComponent(item.substring(0, eq))
      // Kodi transport options are not HTTP fields.
      if (['seekable', 'reconnect', 'connection-timeout'].includes(key.toLowerCase())) continue
      StreamHeaders.put(headers, key, ToolsUtil.safeDecodeURIComponent(item.substring(eq + 1)))
    }
    return StreamHeaders.merge(headers)
  }

  static address(value: string): StreamAddress {
    const pipe = /^https?:\/\//i.test(value.trim()) ? value.indexOf('|') : -1
    return { url: (pipe < 0 ? value : value.substring(0, pipe)).trim(),
      headers: pipe < 0 ? {} : StreamHeaders.options(value.substring(pipe + 1)) }
  }

  static directive(line: string): Record<string, string> {
    const vlc = line.match(/^#EXTVLCOPT:http-(user-agent|referrer|referer|origin|cookie|authorization|header)=(.*)$/i)
    if (vlc) {
      if (vlc[1].toLowerCase() === 'header') return StreamHeaders.parseText(vlc[2])
      const headers: Record<string, string> = {}
      StreamHeaders.put(headers, vlc[1], vlc[2])
      return headers
    }
    const kodi = line.match(/^#KODIPROP:inputstream\.(?:adaptive|ffmpegdirect)\.(?:stream_headers|manifest_headers|common_headers)=(.*)$/i)
    return kodi ? StreamHeaders.options(kodi[1]) : {}
  }

  static identity(url: string, headers?: Record<string, string>): string {
    const normalized = StreamHeaders.merge(headers)
    return url + '\n' + Object.keys(normalized).sort().map((key: string) => `${key}:${normalized[key]}`).join('\n')
  }

  static sameOrigin(first: string, second: string): boolean {
    const a = first.match(/^https?:\/\/[^/]+/i)?.[0].toLowerCase()
    const b = second.match(/^https?:\/\/[^/]+/i)?.[0].toLowerCase()
    return a !== undefined && a === b
  }
}
