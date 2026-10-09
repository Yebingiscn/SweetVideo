import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import VideoInfoUtil from './VideoInfoUtil'
import { FrameSize } from '../interfaces/FrameSizeInterface'
import { salmonLogger } from 'salmonlogger'
import { Setting } from './ObservedUtil'
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

const TAG = 'FramePreviewSession'

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
  static coverTimeUs(durationMs: number, randomCover: boolean): number {
    if (!randomCover) {
      return durationMs >= 3600000 ? 180000000 : 0
    }
    // 未知时长不盲目 seek；短视频取样上限严格小于结尾。
    if (!Number.isFinite(durationMs) || durationMs <= 0) {
      return 0
    }
    return Math.floor(Math.random() * Math.min(durationMs, 300000) * 1000)
  }

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
    maxHeight: number, preferEmbeddedCover: boolean = false, keyframeCover: boolean = false): Promise<FFmpegThumbnailResult> {
    try {
      const frameTask: Promise<FFmpegThumbnailFrame> = extractThumbnailFrame(
        extractorId,
        Math.max(0, timeUs),
        Math.max(1, maxWidth),
        Math.max(1, maxHeight),
        preferEmbeddedCover,
        keyframeCover
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
    maxHeight: number, preferEmbeddedCover: boolean = false, keyframeCover: boolean = false): Promise<FFmpegThumbnailResult> {
    let extractorId: number | undefined
    try {
      extractorId = FFmpegThumbnailUtil.createLocalExtractor(uri)
      return await FFmpegThumbnailUtil.extractFrame(
        extractorId, timeUs, maxWidth, maxHeight, preferEmbeddedCover, keyframeCover)
    } catch (error) {
      return buildFailureResult(String(error))
    } finally {
      FFmpegThumbnailUtil.releaseExtractor(extractorId)
    }
  }

  static async extractCover(uri: string, durationMs: number, maxEdge: number = 480):
    Promise<FFmpegThumbnailResult> {
    const randomCover = Setting.randomCover
    const timeUs = FFmpegThumbnailUtil.coverTimeUs(durationMs, randomCover)
    const result = await FFmpegThumbnailUtil.extractFrameFromUri(uri, timeUs, maxEdge, maxEdge,
      !randomCover, randomCover)
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
      const randomCover = Setting.randomCover
      const timeUs = FFmpegThumbnailUtil.coverTimeUs(probe.durationMs, randomCover)
      const thumbnail = await FFmpegThumbnailUtil.extractFrame(extractorId, timeUs, maxEdge, maxEdge,
        !randomCover, randomCover)
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
      const randomCover = Setting.randomCover
      const durationMs = randomCover ? (await FFmpegThumbnailUtil.getMediaInfo(extractorId)).durationMs : 0
      return await FFmpegThumbnailUtil.extractFrame(extractorId,
        FFmpegThumbnailUtil.coverTimeUs(durationMs, randomCover), maxEdge, maxEdge, !randomCover, randomCover)
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

/** 播放预览的句柄与串行创建、释放任务共用一个生命周期。 */
export interface FramePreviewTarget {
  nowPlaying: VideoMetadata | undefined
  playTime: number
  pixelMap: image.PixelMap | null
}

interface FramePreviewRequest {
  target: FramePreviewTarget
  media: VideoMetadata
  time: number
  generation: number
  requestVersion: number
}

export class FramePreviewSession {
  private requestOwner: FramePreviewTarget | undefined = undefined
  private pendingRequest: FramePreviewRequest | undefined = undefined
  private requestVersion: number = 0
  private lastFrameFetchTime: number = 0
  private lastFrameFetchPlayTime: number = -1
  private frameFetchTimer: number = 0
  private readonly FRAME_FETCH_INTERVAL: number = 200

  async requestFrame(target: FramePreviewTarget, time: number, isFirstFrame: boolean): Promise<void> {
    if (!Setting.showFrameImgStatus || !target.nowPlaying) { return }
    if (this.requestOwner !== target) {
      this.cancelRequests()
      this.requestOwner = target
    }
    this.pendingRequest = {
      target: target, media: target.nowPlaying, time: time,
      generation: this.generation, requestVersion: this.requestVersion
    }
    if (isFirstFrame) {
      clearTimeout(this.frameFetchTimer)
      this.frameFetchTimer = 0
      await this.fetchPendingFrame()
    } else {
      this.schedulePendingFrameFetch()
    }
  }

  cancelRequests(target?: FramePreviewTarget): void {
    if (target && this.requestOwner !== target) { return }
    this.requestVersion++
    clearTimeout(this.frameFetchTimer)
    this.frameFetchTimer = 0
    this.pendingRequest = undefined
    this.requestOwner = undefined
    this.lastFrameFetchTime = 0
    this.lastFrameFetchPlayTime = -1
  }

  private schedulePendingFrameFetch(): void {
    if (!this.pendingRequest || !this.updatePix || this.frameFetchTimer) { return }
    const remaining = this.FRAME_FETCH_INTERVAL - (Date.now() - this.lastFrameFetchTime)
    if (remaining <= 0) {
      void this.fetchPendingFrame()
      return
    }
    this.frameFetchTimer = setTimeout(() => {
      this.frameFetchTimer = 0
      void this.fetchPendingFrame()
    }, remaining)
  }

  private async fetchPendingFrame(): Promise<void> {
    if (!this.pendingRequest || !this.updatePix) { return }
    const request = this.pendingRequest
    this.pendingRequest = undefined
    if (request.generation !== this.generation || request.requestVersion !== this.requestVersion ||
      request.media !== request.target.nowPlaying) {
      this.schedulePendingFrameFetch()
      return
    }
    if (Math.floor(request.time) === Math.floor(this.lastFrameFetchPlayTime)) {
      this.schedulePendingFrameFetch()
      return
    }
    this.lastFrameFetchTime = Date.now()
    this.lastFrameFetchPlayTime = request.time
    try {
      const img = await this.fetchFrame(request.time, request.media.size, VideoInfoUtil.hasVideoTrack(request.media))
      if (img && request.generation === this.generation && request.requestVersion === this.requestVersion &&
        request.media === request.target.nowPlaying && Math.abs(request.target.playTime - request.time) < 3000) {
        request.target.pixelMap = img
      } else {
        await img?.release()
      }
    } catch (error) {
      salmonLogger.addLog(TAG, '获取视频帧失败:' + error, true)
    } finally {
      this.schedulePendingFrameFetch()
    }
  }

  private frameExtractorId: number | undefined = undefined
  private generation: number = 0
  private busy: boolean = false
  private frameExtractorLifecycleTask: Promise<void> = Promise.resolve()

  private get updatePix(): boolean {
    return this.frameExtractorId !== undefined && !this.busy
  }

  async prepare(uri: string): Promise<void> {
    this.cancelRequests()
    if (!Setting.showFrameImgStatus) {
      return
    }
    const generation = ++this.generation
    const previousTask = this.frameExtractorLifecycleTask
    const task = previousTask.catch(() => {
    }).then(async () => {
      await this.releaseFrameExtractorNow()
      if (!Setting.showFrameImgStatus || generation !== this.generation) {
        return
      }
      let extractorId: number | undefined
      try {
        extractorId = FFmpegThumbnailUtil.createLocalExtractor(uri)
        this.frameExtractorId = extractorId
      } catch (error) {
        salmonLogger.addLog(TAG, 'prepare error' + error, true)
        FFmpegThumbnailUtil.releaseExtractor(extractorId)
      }
    })
    this.frameExtractorLifecycleTask = task
    await task
    this.schedulePendingFrameFetch()
  }

  async release(): Promise<void> {
    this.cancelRequests()
    this.generation++
    const previousTask = this.frameExtractorLifecycleTask
    const task = previousTask.catch(() => {
    }).then(async () => {
      await this.releaseFrameExtractorNow()
    })
    this.frameExtractorLifecycleTask = task
    await task
  }

  private async fetchFrame(time: number, videoSize?: number[], hasVideoTrack: boolean = true):
    Promise<image.PixelMap | undefined> {
    const generation = this.generation
    this.busy = true
    // 抽帧也进入同一队列；释放不能抢在 native 异步抽帧结束之前关闭句柄。
    const task = this.frameExtractorLifecycleTask.catch(() => {}).then(async (): Promise<image.PixelMap | undefined> => {
      if (!Setting.showFrameImgStatus || generation !== this.generation) { return undefined }
      try {
        let size: FrameSize
        if (!videoSize || !hasVideoTrack) {
          return undefined
        }
        if (videoSize[0] <= 0 || videoSize[1] <= 0) {
          return undefined
        }
        if (videoSize.length >= 2) {
          const aspectSize = VideoInfoUtil.calculateAspectRatioSize(videoSize[0], videoSize[1], 200)
          size = { width: aspectSize.width, height: aspectSize.height }
        } else {
          size = { width: 100, height: 100 }
        }
        const extractorId = this.frameExtractorId
        if (extractorId === undefined) {
          return undefined
        }
        const result = await FFmpegThumbnailUtil.extractFrame(extractorId, time * 1000, size.width, size.height)
        if (generation !== this.generation) {
          await result.pixelMap?.release()
          return undefined
        }
        if (!result.success && result.error) {
          salmonLogger.addLog(TAG, 'FFmpeg fetchFrame error: ' + result.error, true)
        }
        return result.pixelMap
      } catch (e) {
        salmonLogger.addLog(TAG, 'fetchFrame error', e)
        return undefined
      }
    })
    this.frameExtractorLifecycleTask = task.then(() => {}, () => {})
    try {
      return await task
    } finally {
      this.busy = false
    }
  }

  private async releaseFrameExtractorNow(): Promise<void> {
    const extractorId = this.frameExtractorId
    this.frameExtractorId = undefined
    try {
      FFmpegThumbnailUtil.releaseExtractor(extractorId)
    } catch (error) {
      salmonLogger.addLog(TAG, `releaseFrameExtractor error: ${error}`, true)
    }
  }

}

export const framePreviewSession = new FramePreviewSession()
