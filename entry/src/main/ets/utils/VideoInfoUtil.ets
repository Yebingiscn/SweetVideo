import { media } from '@kit.MediaKit'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import PrivacySpaceUtil from './PrivacySpaceUtil'
import SelectFileUtil from './SelectFileUtil'
import { SCREEN_EXTEND_LIST, VIDEO_SIZE_MAP } from '../common/Constants'
import { salmonLogger } from 'salmonlogger'
import { image } from '@kit.ImageKit'
import { extractVideoFrameAsCoverInTaskPool } from './TaskpoolUtil'
import ToolsUtil from './ToolsUtil'
import fileIo from '@ohos.file.fs'

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

  // 设置存储的视频信息（优化版：减少文件打开次数）
  static async setVideoInfoOptimized(date: string, uri: string, file_name: string, metadata: media.AVMetadata,
    sandbox_video: string, sandbox_path: string, fileSize: number, pixelMap: image.PixelMap | undefined) {
    let time = '0'
    let hdr_type = media.HdrType.AV_HDR_TYPE_NONE
    let duration = '0'
    if (canIUse('SystemCapability.Multimedia.Media.AVMetadataExtractor')) {
      time = metadata.duration || '0'
      duration = metadata.duration || '0'
      hdr_type = metadata.hdrType ? media.HdrType.AV_HDR_TYPE_VIVID : media.HdrType.AV_HDR_TYPE_NONE
    }

    const video_size = ToolsUtil.formatFileSize(fileSize)

    let targetVideo: VideoMetadata = {
      uri: PrivacySpaceUtil.getPrivacyMode()! ? sandbox_video + date : uri,
      title: file_name,
      date: date,
      size: VideoInfoUtil.getVideoWidthAndHeight(metadata),
      time: parseInt(time),
      last_play: 0,
      format: VideoInfoUtil.getVideoFormat(file_name),
      video_size: video_size,
      hdr_type: hdr_type,
      start_time: 0,
      end_time: 0,
      external_subtitle_format: '',
      pointA: 0,
      pointB: 0
    }
    if (pixelMap) {
      await SelectFileUtil.saveVideoImageToSandBox(sandbox_path, date, pixelMap)
    } else {
      // 使用 TaskPool 提取视频帧作为封面
      const frameResult = await extractVideoFrameAsCoverInTaskPool(
        uri,
        targetVideo.size[0],
        targetVideo.size[1],
        parseInt(duration)
      )
      if (frameResult.success && frameResult.pixelMap) {
        await SelectFileUtil.saveVideoImageToSandBox(sandbox_path, date, frameResult.pixelMap)
      } else if (frameResult.error) {
        salmonLogger.addLog(TAG, 'extract video frame as cover error: ' + frameResult.error, true)
      }
    }
    return targetVideo
  }

  public static getVideoFormat(videoName: string) {
    return videoName.split('.')[videoName.split('.').length-1]
  }

  public static optimizedFormat(speed: number): string {
    return speed ? speed.toFixed(2).replace(/\.?0+$/, '') + 'x' : '1x'
  }

  static getVideoTitle(item: VideoMetadata | undefined) {
    if (!item) {
      return ''
    }
    return item.title.slice(0, item.title.lastIndexOf('.'))
  }

  // 获取视频长宽
  static getVideoWidthAndHeight(metadata: media.AVMetadata) {
    if (canIUse('SystemCapability.Multimedia.Media.AVMetadataExtractor')) {
      const isPortrait = metadata.videoOrientation === '90' || metadata.videoOrientation === '270'
      const width = parseInt(String(isPortrait ? metadata.videoHeight : metadata.videoWidth)) || 0
      const height = parseInt(String(isPortrait ? metadata.videoWidth : metadata.videoHeight)) || 0
      return [width, height]
    } else {
      return [0, 0]
    }
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
    return new Promise((resolve, reject) => {
      try {
        let file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY)
        fileIo.stat(file.fd, (err: BusinessError, stat: fileIo.Stat) => {
          if (err) {
            reject('app.string.unknown_size')
          } else if (return_string) {
            const size = ToolsUtil.formatFileSize(stat.size)
            resolve(size)
          } else {
            resolve(stat.size)
          }
        })
      } catch (error) {
        salmonLogger.addLog(TAG, 'getVideoSize error:' + error, true)
      }
    })
  }

  // 保存视频初始长宽，变更后视频长宽后使用
  static saveOriginalVideoWidthAndHeight(playAreaWidth: number, playAreaHeight: number) {
    VideoInfoUtil.playAreaWidth = playAreaWidth
    VideoInfoUtil.playAreaHeight = playAreaHeight
  }
}