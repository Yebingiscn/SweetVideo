import { util } from '@kit.ArkTS'
import { UniversalDetector } from '@ohos/juniversalchardet'
import { salmonLogger } from 'salmonlogger'

const TAG = 'TextEncodingUtil'

/** Charset detection and decoding shared by text files and FFmpeg metadata. */
export default class TextEncodingUtil {
  private static readonly WINDOWS_1252_BYTES: Map<number, number> = new Map([
    [0x20AC, 0x80], [0x201A, 0x82], [0x0192, 0x83], [0x201E, 0x84],
    [0x2026, 0x85], [0x2020, 0x86], [0x2021, 0x87], [0x02C6, 0x88],
    [0x2030, 0x89], [0x0160, 0x8A], [0x2039, 0x8B], [0x0152, 0x8C],
    [0x017D, 0x8E], [0x2018, 0x91], [0x2019, 0x92], [0x201C, 0x93],
    [0x201D, 0x94], [0x2022, 0x95], [0x2013, 0x96], [0x2014, 0x97],
    [0x02DC, 0x98], [0x2122, 0x99], [0x0161, 0x9A], [0x203A, 0x9B],
    [0x0153, 0x9C], [0x017E, 0x9E], [0x0178, 0x9F]
  ])

  static async detectFileEncoding(filePath: string): Promise<string> {
    try {
      return await UniversalDetector.detectCharset(filePath)
    } catch (error) {
      salmonLogger.addLog(TAG, 'File encoding detection failed: ' + error, true)
      return ''
    }
  }

  static detectBufferEncoding(buffer: ArrayBuffer): string {
    if (buffer.byteLength === 0) {
      return 'UTF-8'
    }
    const detector = new UniversalDetector()
    try {
      const detectionLength = Math.min(buffer.byteLength, 256 * 1024)
      detector.handleData(buffer, 0, detectionLength)
      detector.dataEnd()
      return detector.getDetectedCharset() || ''
    } catch (error) {
      salmonLogger.addLog(TAG, 'Buffer encoding detection failed: ' + error, true)
      return ''
    } finally {
      detector.reset()
    }
  }

  /** Decode FFmpeg's original tag bytes without first forcing them through UTF-8. */
  static decodeMetadata(buffer: ArrayBuffer | undefined, fallback: string = ''): string {
    if (!buffer || buffer.byteLength === 0) {
      return TextEncodingUtil.clean(fallback)
    }

    const detectedEncoding = TextEncodingUtil.detectBufferEncoding(buffer)
    let decoded = TextEncodingUtil.decode(buffer, detectedEncoding)
    if (!TextEncodingUtil.isUsable(decoded)) {
      const fallbacks: string[] = ['UTF-8', 'GB18030', 'GBK']
      for (const encoding of fallbacks) {
        if (encoding === detectedEncoding.toUpperCase()) {
          continue
        }
        const candidate = TextEncodingUtil.decode(buffer, encoding)
        if (TextEncodingUtil.isUsable(candidate)) {
          decoded = candidate
          break
        }
      }
    }

    // Very short legacy Chinese tags can be mistaken for a Western codepage.
    // Prefer a clean GB18030 result only when it clearly restores CJK text.
    if (!TextEncodingUtil.containsCjk(decoded)) {
      const gbCandidate = TextEncodingUtil.decode(buffer, 'GB18030')
      if (TextEncodingUtil.containsCjk(gbCandidate) &&
        TextEncodingUtil.extendedCharacterCount(decoded) >= 2) {
        decoded = gbCandidate
      }
    }

    const repaired = TextEncodingUtil.repairWesternMojibake(decoded)
    if (TextEncodingUtil.containsCjk(repaired) && !TextEncodingUtil.containsCjk(decoded)) {
      decoded = repaired
    }
    decoded = TextEncodingUtil.clean(decoded)
    return TextEncodingUtil.isUsable(decoded) ? decoded : ''
  }

  static isUsable(value: string): boolean {
    const cleaned = TextEncodingUtil.clean(value)
    if (cleaned.length === 0 || cleaned.includes('\uFFFD') || cleaned.includes('锟斤拷')) {
      return false
    }
    for (let index = 0; index < cleaned.length; index++) {
      const code = cleaned.charCodeAt(index)
      if ((code < 0x20 && code !== 0x09 && code !== 0x0A && code !== 0x0D) || code === 0x7F) {
        return false
      }
    }
    return true
  }

  private static decode(buffer: ArrayBuffer, encoding: string): string {
    if (encoding.length === 0) {
      return ''
    }
    try {
      const decoder = util.TextDecoder.create(encoding, { ignoreBOM: true })
      return TextEncodingUtil.clean(decoder.decodeToString(new Uint8Array(buffer), { stream: false }))
    } catch {
      return ''
    }
  }

  private static repairWesternMojibake(value: string): string {
    if (value.length === 0 || TextEncodingUtil.containsCjk(value)) {
      return ''
    }
    const raw = new ArrayBuffer(value.length)
    const bytes = new Uint8Array(raw)
    let extendedCharacters = 0
    for (let index = 0; index < value.length; index++) {
      const code = value.charCodeAt(index)
      let byte = code <= 0xFF ? code : TextEncodingUtil.WINDOWS_1252_BYTES.get(code)
      if (byte === undefined) {
        return ''
      }
      if (byte >= 0x80) {
        extendedCharacters++
      }
      bytes[index] = byte
    }
    if (extendedCharacters < 2) {
      return ''
    }
    const detectedEncoding = TextEncodingUtil.detectBufferEncoding(raw)
    const decoded = TextEncodingUtil.decode(raw, detectedEncoding)
    if (TextEncodingUtil.containsCjk(decoded)) {
      return decoded
    }
    const utf8 = TextEncodingUtil.decode(raw, 'UTF-8')
    if (TextEncodingUtil.containsCjk(utf8)) {
      return utf8
    }
    return TextEncodingUtil.decode(raw, 'GB18030')
  }

  private static containsCjk(value: string): boolean {
    let count = 0
    for (let index = 0; index < value.length; index++) {
      const code = value.charCodeAt(index)
      if ((code >= 0x3400 && code <= 0x9FFF) || (code >= 0xF900 && code <= 0xFAFF)) {
        count++
        if (count >= 2) {
          return true
        }
      }
    }
    return false
  }

  private static extendedCharacterCount(value: string): number {
    let count = 0
    for (let index = 0; index < value.length; index++) {
      if (value.charCodeAt(index) >= 0x80) {
        count++
      }
    }
    return count
  }

  private static clean(value: string): string {
    return value.replace(/\u0000/g, '').trim()
  }
}
