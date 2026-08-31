import { fileIo as fs } from '@kit.CoreFileKit'
import { image } from '@kit.ImageKit'
import { media } from '@kit.MediaKit'
import {
  createThumbnailExtractor,
  extractThumbnailFrame,
  FFmpegMediaInfo,
  FFmpegThumbnailFrame,
  getMediaInfo as getNativeMediaInfo,
  releaseThumbnailExtractor
} from 'libmpvnative.so'
import TextEncodingUtil from './TextEncodingUtil'

export interface FFmpegMediaProbe {
  sourceWidth: number
  sourceHeight: number
  coverWidth: number
  coverHeight: number
  rotation: number
  durationMs: number
  frameRate: number
  bitRate: number
  hdrType: number
  dolbyVisionProfile: number
  audioType: number
  audioStreamCount: number
  subtitleStreamCount: number
  hasEmbeddedCover: boolean
  formatName: string
  formatLongName: string
  videoCodec: string
  audioCodec: string
  title: string
  artist: string
  album: string
  comment: string
  creationTime: string
}

export interface FFmpegThumbnailResult {
  pixelMap: image.PixelMap | undefined
  success: boolean
  error?: string
  sourceWidth: number
  sourceHeight: number
  coverWidth: number
  coverHeight: number
  durationMs: number
  frameRate: number
  hdrType: number
  dolbyVisionProfile: number
  audioType: number
  colorManaged: boolean
}

export interface FFmpegProbeResult {
  probe: FFmpegMediaProbe | undefined
  success: boolean
  error?: string
}

export interface FFmpegMediaCoverResult {
  probe: FFmpegMediaProbe | undefined
  thumbnail: FFmpegThumbnailResult
}

function buildFailureResult(error: string): FFmpegThumbnailResult {
  return {
    pixelMap: undefined,
    success: false,
    error: error,
    sourceWidth: 0,
    sourceHeight: 0,
    coverWidth: 0,
    coverHeight: 0,
    durationMs: 0,
    frameRate: 0,
    hdrType: 0,
    dolbyVisionProfile: 0,
    audioType: 0,
    colorManaged: false
  }
}

export default class FFmpegThumbnailUtil {
  static createLocalExtractor(uri: string): number {
    let file: fs.File | undefined
    try {
      file = fs.openSync(uri, fs.OpenMode.READ_ONLY)
    } catch (error) {
      throw new Error(`FFmpeg thumbnail source open failed: ${String(error)}`)
    }
    try {
      // native 会同步复制 fd，所以这里可以立即关闭 ArkTS 持有的文件。
      return createThumbnailExtractor(file.fd)
    } finally {
      try {
        fs.closeSync(file)
      } catch {
      }
    }
  }

  static createNetworkExtractor(url: string): number {
    return createThumbnailExtractor(url)
  }

  static releaseExtractor(extractorId: number | undefined): void {
    if (extractorId === undefined) {
      return
    }
    releaseThumbnailExtractor(extractorId)
  }

  static async getMediaInfo(extractorId: number): Promise<FFmpegMediaProbe> {
    const infoTask: Promise<FFmpegMediaInfo> = getNativeMediaInfo(extractorId)
    const info = await infoTask
    return {
      sourceWidth: info.sourceWidth,
      sourceHeight: info.sourceHeight,
      coverWidth: info.coverWidth,
      coverHeight: info.coverHeight,
      rotation: info.rotation,
      durationMs: info.durationMs,
      frameRate: info.frameRate,
      bitRate: info.bitRate,
      hdrType: info.hdrType,
      dolbyVisionProfile: info.dolbyVisionProfile,
      audioType: info.audioType,
      audioStreamCount: info.audioStreamCount,
      subtitleStreamCount: info.subtitleStreamCount,
      hasEmbeddedCover: info.hasEmbeddedCover,
      formatName: info.formatName,
      formatLongName: info.formatLongName,
      videoCodec: info.videoCodec,
      audioCodec: info.audioCodec,
      title: TextEncodingUtil.decodeMetadata(info.titleData, info.title),
      artist: TextEncodingUtil.decodeMetadata(info.artistData, info.artist),
      album: TextEncodingUtil.decodeMetadata(info.albumData, info.album),
      comment: TextEncodingUtil.decodeMetadata(info.commentData, info.comment),
      creationTime: TextEncodingUtil.decodeMetadata(info.creationTimeData, info.creationTime)
    }
  }

  static async probeUri(uri: string): Promise<FFmpegProbeResult> {
    let extractorId: number | undefined
    try {
      extractorId = FFmpegThumbnailUtil.createLocalExtractor(uri)
      const probe = await FFmpegThumbnailUtil.getMediaInfo(extractorId)
      probe.hdrType = await FFmpegThumbnailUtil.correctHdrVivid(uri, probe.hdrType)
      return { probe: probe, success: true }
    } catch (error) {
      return { probe: undefined, success: false, error: String(error) }
    } finally {
      FFmpegThumbnailUtil.releaseExtractor(extractorId)
    }
  }

  static async extractFrame(extractorId: number, timeUs: number, maxWidth: number,
    maxHeight: number, preferEmbeddedCover: boolean = false): Promise<FFmpegThumbnailResult> {
    try {
      const frameTask: Promise<FFmpegThumbnailFrame> = extractThumbnailFrame(
        extractorId,
        Math.max(0, timeUs),
        Math.max(1, maxWidth),
        Math.max(1, maxHeight),
        preferEmbeddedCover
      )
      const frame = await frameTask
      const options: image.InitializationOptions = {
        size: { width: frame.width, height: frame.height },
        srcPixelFormat: image.PixelMapFormat.RGBA_8888,
        pixelFormat: image.PixelMapFormat.RGBA_8888,
        alphaType: image.AlphaType.OPAQUE,
        editable: false
      }
      const pixelMap = await image.createPixelMap(frame.data, options)
      return {
        pixelMap: pixelMap,
        success: true,
        sourceWidth: frame.sourceWidth,
        sourceHeight: frame.sourceHeight,
        coverWidth: frame.coverWidth,
        coverHeight: frame.coverHeight,
        durationMs: frame.durationMs,
        frameRate: frame.frameRate,
        hdrType: frame.hdrType,
        dolbyVisionProfile: frame.dolbyVisionProfile,
        audioType: frame.audioType,
        colorManaged: frame.colorManaged
      }
    } catch (error) {
      return buildFailureResult(String(error))
    }
  }

  static async extractFrameFromUri(uri: string, timeUs: number, maxWidth: number,
    maxHeight: number, preferEmbeddedCover: boolean = false): Promise<FFmpegThumbnailResult> {
    let extractorId: number | undefined
    try {
      extractorId = FFmpegThumbnailUtil.createLocalExtractor(uri)
      return await FFmpegThumbnailUtil.extractFrame(
        extractorId, timeUs, maxWidth, maxHeight, preferEmbeddedCover)
    } catch (error) {
      return buildFailureResult(String(error))
    } finally {
      FFmpegThumbnailUtil.releaseExtractor(extractorId)
    }
  }

  static async extractCover(uri: string, durationMs: number, maxEdge: number = 480):
    Promise<FFmpegThumbnailResult> {
    const oneHourMs = 3600000
    const timeUs = durationMs >= oneHourMs ? 180000000 : 0
    const result = await FFmpegThumbnailUtil.extractFrameFromUri(uri, timeUs, maxEdge, maxEdge, true)
    result.hdrType = await FFmpegThumbnailUtil.correctHdrVivid(uri, result.hdrType)
    return result
  }

  /** 同一个 FFmpeg 会话先探测媒体信息，再按时长选择封面帧。 */
  static async probeAndExtractCover(uri: string, maxEdge: number = 480): Promise<FFmpegMediaCoverResult> {
    let extractorId: number | undefined
    let probe: FFmpegMediaProbe | undefined
    try {
      extractorId = FFmpegThumbnailUtil.createLocalExtractor(uri)
      probe = await FFmpegThumbnailUtil.getMediaInfo(extractorId)
      const oneHourMs = 3600000
      const timeUs = probe.durationMs >= oneHourMs ? 180000000 : 0
      const thumbnail = await FFmpegThumbnailUtil.extractFrame(extractorId, timeUs, maxEdge, maxEdge, true)
      if (thumbnail.success) {
        if (thumbnail.sourceWidth > 0 && thumbnail.sourceHeight > 0) {
          probe.sourceWidth = thumbnail.sourceWidth
          probe.sourceHeight = thumbnail.sourceHeight
        }
        if (thumbnail.durationMs > 0) {
          probe.durationMs = thumbnail.durationMs
        }
        if (thumbnail.frameRate > 0) {
          probe.frameRate = thumbnail.frameRate
        }
        if (thumbnail.coverWidth > 0 && thumbnail.coverHeight > 0) {
          probe.coverWidth = thumbnail.coverWidth
          probe.coverHeight = thumbnail.coverHeight
        }
        probe.hdrType = thumbnail.hdrType
        probe.dolbyVisionProfile = thumbnail.dolbyVisionProfile
        probe.audioType = thumbnail.audioType
      }
      probe.hdrType = await FFmpegThumbnailUtil.correctHdrVivid(uri, probe.hdrType)
      if (thumbnail.success) {
        thumbnail.hdrType = probe.hdrType
      }
      return { probe: probe, thumbnail: thumbnail }
    } catch (error) {
      return { probe: probe, thumbnail: buildFailureResult(String(error)) }
    } finally {
      FFmpegThumbnailUtil.releaseExtractor(extractorId)
    }
  }

  static async extractNetworkCover(url: string, maxEdge: number = 480): Promise<FFmpegThumbnailResult> {
    let extractorId: number | undefined
    try {
      extractorId = FFmpegThumbnailUtil.createNetworkExtractor(url)
      return await FFmpegThumbnailUtil.extractFrame(extractorId, 0, maxEdge, maxEdge, true)
    } catch (error) {
      return buildFailureResult(String(error))
    } finally {
      FFmpegThumbnailUtil.releaseExtractor(extractorId)
    }
  }

  /**
   * FFmpeg can see PQ transfer characteristics before it sees HDR Vivid's
   * dynamic metadata and may therefore classify the file as HDR10. HarmonyOS
   * exposes an authoritative Vivid flag, so query it only for HDR10 candidates.
   */
  private static async correctHdrVivid(uri: string, hdrType: number): Promise<number> {
    const hdr10 = 2
    const hdrVivid = 1
    if (hdrType !== hdr10 ||
      !canIUse('SystemCapability.Multimedia.Media.AVMetadataExtractor')) {
      return hdrType
    }

    let extractor: media.AVMetadataExtractor | undefined
    let file: fs.File | undefined
    try {
      extractor = await media.createAVMetadataExtractor()
      file = fs.openSync(uri, fs.OpenMode.READ_ONLY)
      extractor.fdSrc = { fd: file.fd }
      const metadata = await extractor.fetchMetadata()
      return metadata.hdrType === media.HdrType.AV_HDR_TYPE_VIVID ? hdrVivid : hdrType
    } catch {
      return hdrType
    } finally {
      if (extractor) {
        try {
          await extractor.release()
        } catch {
        }
      }
      if (file) {
        try {
          fs.closeSync(file)
        } catch {
        }
      }
    }
  }
}
