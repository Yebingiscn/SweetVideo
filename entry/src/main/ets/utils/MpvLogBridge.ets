import { registerMpvLogCallback } from 'libmpvnative.so'
import { salmonLogger } from 'salmonlogger'

export function sanitizeMpvLog(text: string): string {
  // Decoder/HTTP errors may contain signed URLs, credentials or headers.
  return text
    .replace(/\b(?:https?|rtsp|rtmp|ftp|smb|webdav|file):\/\/[^\s<>"']+/gi, '[redacted-url]')
    .replace(/\b(?:authorization|proxy-authorization|cookie|set-cookie)\s*[:=][^\r\n]*/gi, '[redacted-header]')
    .trim()
}

export class MpvLogBridge {
  private static started: boolean = false

  static start(): void {
    if (MpvLogBridge.started) {
      return
    }
    try {
      MpvLogBridge.started = registerMpvLogCallback((prefix: string, level: number, text: string,
        timestampMs: number) => {
        const message = sanitizeMpvLog(text)
        if (!message) {
          return
        }
        const label = level <= 10 ? 'fatal' : level <= 20 ? 'error' : level <= 30 ? 'warn' : 'info'
        // Preserve native occurrence time: the ArkTS thread may dispatch later.
        salmonLogger.addLog(`MPV/${prefix}`, `[${label} nativeTime=${timestampMs}] ${message}`, level <= 30)
      })
    } catch (error) {
      salmonLogger.addLog('MPV/log', `原生日志接入失败: ${error}`, true)
    }
  }
}
