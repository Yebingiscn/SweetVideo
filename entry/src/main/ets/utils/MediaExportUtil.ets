import { fileIo } from '@kit.CoreFileKit'
import FFmpegThumbnailUtil, { FFmpegMediaProbe } from './FFmpegThumbnailUtil'
import { salmonLogger } from 'salmonlogger'

// 无媒体记录的隐私文件仅有内部 ID；按容器识别导出后缀，不修改源文件或重建记录。
export default class MediaExportUtil {
  private static readonly EXTENSIONS: Map<string, string> = new Map([
    ['avi', 'avi'], ['flv', 'flv'], ['mpegts', 'ts'], ['mpeg', 'mpg'], ['rm', 'rmvb'],
    ['mp3', 'mp3'], ['wav', 'wav'], ['flac', 'flac'], ['aac', 'aac'], ['amr', 'amr'],
    ['aiff', 'aiff'], ['ape', 'ape'], ['wv', 'wv'], ['dsf', 'dsf'], ['dsdiff', 'dff'],
    ['dts', 'dts'], ['av3a', 'av3a'], ['mp4', 'mp4'], ['mov', 'mov'], ['m4a', 'm4a'],
    ['3gp', '3gp'], ['3g2', '3g2'], ['mj2', 'mj2'], ['webm', 'webm']
  ])

  static buildFileName(title: string, format: string): string {
    const name = title.trim().replace(/\.+$/, '') || 'media'
    const extension = format.trim().replace(/^\.+/, '').toLowerCase()
    if (!extension || name.toLowerCase().endsWith(`.${extension}`)) {
      return name
    }
    return `${name}.${extension}`
  }

  static async detectExtension(uri: string, mediaProbe?: FFmpegMediaProbe): Promise<string> {
    let file: fileIo.File | undefined
    let extractorId: number | undefined
    try {
      file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY)
      const buffer = new ArrayBuffer(4096)
      const bytesRead = fileIo.readSync(file.fd, buffer, { length: buffer.byteLength })
      const extension = MediaExportUtil.extensionFromHeader(new Uint8Array(buffer, 0, bytesRead))
      if (extension) {
        return extension
      }
    } catch (_) {
      salmonLogger.addLog('MediaExportUtil', '导出格式文件头识别失败，尝试媒体探测', true)
    } finally {
      if (file) {
        try {
          fileIo.closeSync(file)
        } catch (_) {
          salmonLogger.addLog('MediaExportUtil', '关闭格式探测文件失败', true)
        }
      }
    }
    if (mediaProbe) {
      // 恢复扫描已完成探测，复用结果，避免再次创建原生探测器。
      return MediaExportUtil.extensionFromFormat(mediaProbe.formatName,
        mediaProbe.sourceWidth > 0 || mediaProbe.sourceHeight > 0 || mediaProbe.videoCodec.trim().length > 0)
    }
    try {
      // 只读取容器和轨道信息，不解码封面，也不创建系统播放器。
      extractorId = FFmpegThumbnailUtil.createLocalExtractor(uri)
      const probe = await FFmpegThumbnailUtil.getMediaInfo(extractorId)
      return MediaExportUtil.extensionFromFormat(probe.formatName, probe.videoCodec.trim().length > 0)
    } catch (_) {
      salmonLogger.addLog('MediaExportUtil', '无法识别导出格式，以 bin 保留原始文件', true)
      return 'bin'
    } finally {
      try {
        FFmpegThumbnailUtil.releaseExtractor(extractorId)
      } catch (_) {
        salmonLogger.addLog('MediaExportUtil', '释放导出格式探测器失败', true)
      }
    }
  }

  static extensionFromFormat(formatName: string, hasVideo: boolean): string {
    const formats = formatName.toLowerCase().split(',').map((name: string) => name.trim())
    if (formats.includes('matroska')) {
      return hasVideo ? 'mkv' : 'mka'
    }
    if (formats.includes('mp4') && formats.includes('mov')) {
      return hasVideo ? 'mp4' : 'm4a'
    }
    if (formats.includes('asf')) {
      return hasVideo ? 'wmv' : 'wma'
    }
    if (formats.includes('ogg')) {
      return hasVideo ? 'ogv' : 'ogg'
    }
    for (const format of formats) {
      const extension = MediaExportUtil.EXTENSIONS.get(format)
      if (extension) {
        return extension
      }
    }
    return 'bin'
  }

  static extensionFromHeader(header: Uint8Array): string {
    // FFmpeg 的 MOV/MP4、Matroska/WebM 共用探测名称，优先用容器头区分。
    // https://ffmpeg.org/doxygen/trunk/mov_8c.html
    let offset = 0
    while (offset + 12 <= header.length) {
      const boxSize = header[offset] * 0x1000000 + header[offset + 1] * 0x10000 +
        header[offset + 2] * 0x100 + header[offset + 3]
      if (MediaExportUtil.ascii(header, offset + 4, 4) === 'ftyp' && boxSize >= 16 &&
        offset + 16 <= header.length) {
        const brand = MediaExportUtil.ascii(header, offset + 8, 4).trim().toLowerCase()
        if (brand === 'qt') return 'mov'
        if (brand.startsWith('3g2')) return '3g2'
        if (brand.startsWith('3g')) return '3gp'
        if (brand === 'mjp2' || brand === 'mj2s') return 'mj2'
        if (['m4a', 'm4b', 'm4p', 'm4v'].includes(brand)) return brand
        if (brand.startsWith('iso') || ['mp41', 'mp42', 'avc1', 'dash', 'msdh', 'msix'].includes(brand)) {
          return 'mp4'
        }
        return ''
      }
      if (boxSize < 8 || boxSize > header.length - offset) break
      offset += boxSize
    }
    // EBML DocType (0x4282)，不根据编码器或文件内容中的任意文本猜测 WebM。
    // https://www.matroska.org/technical/notes.html
    if (header[0] === 0x1a && header[1] === 0x45 && header[2] === 0xdf && header[3] === 0xa3) {
      for (let index = 4; index + 3 < header.length; index++) {
        if (header[index] === 0x42 && header[index + 1] === 0x82 && (header[index + 2] & 0x80) !== 0) {
          const length = header[index + 2] & 0x7f
          const docType = MediaExportUtil.ascii(header, index + 3, length)
          if (docType === 'webm') return 'webm'
          if (docType === 'matroska') return 'mkv'
        }
      }
    }
    return ''
  }

  private static ascii(bytes: Uint8Array, offset: number, length: number): string {
    if (offset + length > bytes.length) return ''
    let value = ''
    for (let index = offset; index < offset + length; index++) {
      value += String.fromCharCode(bytes[index])
    }
    return value
  }
}
