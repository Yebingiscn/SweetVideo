import { SCREEN_EXTEND_LIST, SUPPORT_AUDIO_FORMAT, VIDEO_SIZE_MAP } from '../common/Constants'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import FFmpegThumbnailUtil, { FFmpegMediaProbe } from './FFmpegThumbnailUtil'
import { image } from '@kit.ImageKit'
import { salmonLogger } from 'salmonlogger'
import PrivacySpaceUtil from './PrivacySpaceUtil'
import SelectFileUtil, { SavePixelMapOptions } from './SelectFileUtil'
import TextEncodingUtil from './TextEncodingUtil'
import ToolsUtil from './ToolsUtil'
import { fileIo } from '@kit.CoreFileKit'


interface AspectRatioSize {
  width: number
  height: number
}


const TAG = 'VideoInfoUtil'


export default class VideoInfoUtil {
  public static screenExtendMap: string[] = SCREEN_EXTEND_LIST.map(item => item.value as string)
  // 播放器视频宽度
  public static playAreaWidth: number = 0
  // 播放器视频高度
  public static playAreaHeight: number = 0
  public static ASPECT_RATIO_MAP: Map<string, number> = new Map([[VideoInfoUtil.screenExtendMap[5], 16 / 9],
    [VideoInfoUtil.screenExtendMap[6], 4 / 3]])
  public static readonly videoSpeedListAll: number[] = [
    0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0,
    2.25, 2.5, 2.75, 3.0, 3.25, 3.5, 3.75, 4.0
  ]
  public static playerEngineList = ['系统播放器', 'MPV播放器']

  static buildVideoMetadata(date: string, uri: string, file_name: string, sandbox_video: string,
    fileSize: number, probe?: FFmpegMediaProbe): VideoMetadata {
    const videoDimensions = VideoInfoUtil.getPlayableResolution(probe)
    const video_size = ToolsUtil.formatFileSize(fileSize)

    return {
      uri: PrivacySpaceUtil.getPrivacyMode()! ? sandbox_video + date : uri,
      title: VideoInfoUtil.resolveImportedTitle(file_name, probe),
      date: date,
      size: videoDimensions,
      cover_size: [probe?.coverWidth || 0, probe?.coverHeight || 0],
      has_video_track: VideoInfoUtil.probeHasVideoTrack(probe),
      time: Math.round(probe?.durationMs || 0),
      last_play: 0,
      format: VideoInfoUtil.getVideoFormat(file_name),
      video_size: video_size,
      frame_rate: Math.round(probe?.frameRate || 0),
      hdr_type: probe?.hdrType || 0,
      audio_type: probe?.audioType || 0,
      start_time: 0,
      end_time: 0,
      external_subtitle_format: '',
      pointA: 0,
      pointB: 0,
    }
  }

  static resolveImportedTitle(fileName: string, probe?: FFmpegMediaProbe): string {
    const embeddedTitle = probe ? probe.title.trim() : ''
    if (!TextEncodingUtil.isUsable(embeddedTitle)) {
      return fileName
    }
    if (VideoInfoUtil.probeHasVideoTrack(probe) &&
      VideoInfoUtil.isAudioTrackLabel(embeddedTitle)) {
      return fileName
    }
    return embeddedTitle
  }

  /**
   * AVPlayer 的布局初始化需要非零宽高。视频使用真实视频轨尺寸，
   * 纯音频使用内嵌封面的原始尺寸；两者都缺失时以 1:1 安全值兜底。
   */
  static getPlayableResolution(probe: FFmpegMediaProbe | undefined): number[] {
    const sourceWidth = probe?.sourceWidth || 0
    const sourceHeight = probe?.sourceHeight || 0
    if (sourceWidth > 0 && sourceHeight > 0) {
      return [sourceWidth, sourceHeight]
    }
    const coverWidth = probe?.coverWidth || 0
    const coverHeight = probe?.coverHeight || 0
    if (coverWidth > 0 && coverHeight > 0) {
      return [coverWidth, coverHeight]
    }
    return [1, 1]
  }

  static probeHasVideoTrack(probe: FFmpegMediaProbe | undefined): boolean {
    if (!probe) {
      return false
    }
    return probe.sourceWidth > 0 || probe.sourceHeight > 0 || probe.videoCodec.trim().length > 0
  }

  static hasVideoTrack(metadata: VideoMetadata | undefined): boolean {
    if (!metadata) {
      return false
    }
    if (metadata.has_video_track !== undefined) {
      return metadata.has_video_track
    }
    // 兼容升级前没有该字段的记录。
    return !SUPPORT_AUDIO_FORMAT.includes(metadata.format.toLowerCase())
  }

  static getDisplayResolution(metadata: VideoMetadata | undefined): number[] {
    if (metadata?.size && metadata.size[0] > 0 && metadata.size[1] > 0) {
      return metadata.size
    }
    if (metadata?.cover_size && metadata.cover_size[0] > 0 && metadata.cover_size[1] > 0) {
      return metadata.cover_size
    }
    return [0, 0]
  }

  static async saveCoverDeferred(uri: string, sandbox_path: string, date: string, durationMs: number,
    pixelMap: image.PixelMap | undefined) {
    const saveCoverOptions: SavePixelMapOptions = { releasePixelMap: true, deleteOnFail: true }
    let saved = false
    if (pixelMap) {
      const result = await SelectFileUtil.savePixelMapToFile(sandbox_path, date, pixelMap, saveCoverOptions)
      saved = result !== ''
    }
    if (!saved) {
      const frameResult = await FFmpegThumbnailUtil.extractCover(uri, durationMs)
      if (frameResult.success && frameResult.pixelMap) {
        await SelectFileUtil.savePixelMapToFile(sandbox_path, date, frameResult.pixelMap, saveCoverOptions)
      } else if (frameResult.error) {
        salmonLogger.addLog(TAG, 'extract video frame as cover error: ' + frameResult.error, true)
      }
    }
  }

  // 设置存储的视频信息（优化版：减少文件打开次数）
  static async setVideoInfoOptimized(date: string, uri: string, file_name: string, sandbox_video: string,
    sandbox_path: string, fileSize: number, pixelMap: image.PixelMap | undefined,
    probe?: FFmpegMediaProbe): Promise<VideoMetadata> {
    const targetVideo = VideoInfoUtil.buildVideoMetadata(
      date, uri, file_name, sandbox_video, fileSize, probe)
    const saveCoverOptions: SavePixelMapOptions = { releasePixelMap: true, deleteOnFail: true }
    if (pixelMap) {
      await SelectFileUtil.savePixelMapToFile(sandbox_path, date, pixelMap, saveCoverOptions)
    } else {
      const frameResult = await FFmpegThumbnailUtil.extractCover(uri, probe?.durationMs || 0)
      if (frameResult.success && frameResult.pixelMap) {
        targetVideo.hdr_type = frameResult.hdrType
        targetVideo.audio_type = frameResult.audioType
        if (frameResult.sourceWidth > 0 && frameResult.sourceHeight > 0) {
          targetVideo.has_video_track = true
          targetVideo.size = [frameResult.sourceWidth, frameResult.sourceHeight]
        }
        if (frameResult.coverWidth > 0 && frameResult.coverHeight > 0) {
          targetVideo.cover_size = [frameResult.coverWidth, frameResult.coverHeight]
          if (!targetVideo.has_video_track) {
            targetVideo.size = [frameResult.coverWidth, frameResult.coverHeight]
          }
        }
        if (targetVideo.time <= 0 && frameResult.durationMs > 0) {
          targetVideo.time = frameResult.durationMs
        }
        if (targetVideo.frame_rate <= 0 && frameResult.frameRate > 0) {
          targetVideo.frame_rate = Math.round(frameResult.frameRate)
        }
        await SelectFileUtil.savePixelMapToFile(sandbox_path, date, frameResult.pixelMap, saveCoverOptions)
      } else if (frameResult.error) {
        salmonLogger.addLog(TAG, 'extract video frame as cover error: ' + frameResult.error, true)
      }
    }
    return targetVideo
  }

  public static getVideoFormat(videoName: string) {
    return videoName.split('.')[videoName.split('.').length - 1]
  }

  public static optimizedFormat(speed: number): string {
    return speed ? speed.toFixed(2).replace(/\.?0+$/, '') + 'x' : '1x'
  }

  static getVideoTitle(item: VideoMetadata | undefined) {
    if (!item) {
      return ''
    }
    const dotIndex = item.title.lastIndexOf('.')
    return dotIndex > 0 ? item.title.slice(0, dotIndex) : item.title
  }

  static getVideoSpeedTextList() {
    return VideoInfoUtil.videoSpeedListAll.map(speed =>
    `${speed}x`.replace(/(\.0+)?x$/, 'x')  // 同时处理整数和小数
    )
  }

  // 获取视频标签格式化
  static videoWidthAndHeightFormat(size: string, forceDefault: boolean = false) {
    const sizeArray = size.split(',')
    const width = sizeArray[0]
    const height = sizeArray[1]
    const sizeKey = `${width}x${height}`

    // 如果 forceDefault 为真，则直接返回默认格式
    if (forceDefault) {
      return `${width} x ${height}`
    }

    // 匹配优先级
    return VIDEO_SIZE_MAP[sizeKey] || // 1. 精确匹配宽高
      VIDEO_SIZE_MAP[height] || // 2. 标准高度命名
      VIDEO_SIZE_MAP[width] || // 3. 特殊宽度标准
      `${width} x ${height}` // 4. 默认格式
  }

  // 获取视频大小
  static async getVideoSize(uri: string, return_string: boolean): Promise<string | number> {
    let file: fileIo.File | undefined
    try {
      file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY)
      const stat = fileIo.statSync(file.fd)
      if (return_string) {
        return ToolsUtil.formatFileSize(stat.size)
      }
      return stat.size
    } catch (error) {
      salmonLogger.addLog(TAG, 'getVideoSize error:' + error, true)
      return 'app.string.unknown_size'
    } finally {
      if (file) {
        try {
          fileIo.closeSync(file)
        } catch (error) {
          salmonLogger.addLog(TAG, 'getVideoSize close file error:' + error, true)
        }
      }
    }
  }

  // 保存视频初始长宽，变更后视频长宽后使用
  static saveOriginalVideoWidthAndHeight(playAreaWidth: number, playAreaHeight: number) {
    VideoInfoUtil.playAreaWidth = playAreaWidth
    VideoInfoUtil.playAreaHeight = playAreaHeight
  }

  static calculateAspectRatioSize(videoWidth: number, videoHeight: number, maxSize: number): AspectRatioSize {
    if (videoWidth <= 0 || videoHeight <= 0) {
      const result: AspectRatioSize = { width: maxSize, height: maxSize }
      return result
    }
    const aspectRatio = videoWidth / videoHeight
    if (aspectRatio >= 1) {
      const result: AspectRatioSize = { width: maxSize, height: Math.round(maxSize / aspectRatio) }
      return result
    }
    const result: AspectRatioSize = { width: Math.round(maxSize * aspectRatio), height: maxSize }
    return result
  }

  private static isAudioTrackLabel(value: string): boolean {
    const compact = value.toLowerCase().replace(/\s/g, '')
    const exactLabels: string[] = [
      '中文普通话', '普通话', '国语', '中文', '粤语', '英语', '日语', '韩语',
      'mandarin', 'chinese', 'english', 'japanese', 'korean',
      'audiotrack', 'audio', 'stereo', '立体声'
    ]
    if (exactLabels.includes(compact)) {
      return true
    }
    return compact.length <= 32 &&
      (compact.startsWith('中文普通话') || compact.startsWith('mandarin') ||
        compact.startsWith('chineseaudio'))
  }
}
