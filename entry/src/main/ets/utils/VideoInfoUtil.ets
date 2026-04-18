import { media } from '@kit.MediaKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import PrivacySpaceUtil from './PrivacySpaceUtil'
import { ConcurrentQueue } from './FileProcessorUtil'
import SelectFileUtil from './SelectFileUtil'
import PermissionUtil from './PermissionUtil'
import { GB, MB, SCREEN_EXTEND_LIST, VIDEO_SIZE_MAP, VIDEO_SPEED_MAP } from '../common/Constants'
import { salmonLogger } from 'salmonlogger'
import { VideoRepository } from '../repository/VideoRepository'
import { VideoEntity } from '../entity/VideoEntity'
import { coverEventBus } from './CoverEventUtil'

const TAG = 'VideoInfoUtil'

// 视频信息类
export default class VideoInfoUtil {
  public static screenExtendMap: string[] = SCREEN_EXTEND_LIST.map(item => item.value as string)
  // 播放器视频宽度
  public static playAreaWidth: number = 0
  // 播放器视频高度
  public static playAreaHeight: number = 0
  public static ASPECT_RATIO_MAP: Map<string, number> = new Map([[VideoInfoUtil.screenExtendMap[5], 16 / 9],
    [VideoInfoUtil.screenExtendMap[6], 4 / 3]])
  public static readonly videoSpeedListAll: number[] = Array.from(VIDEO_SPEED_MAP.keys())
    .filter(speed => speed >= 0.25)
    .sort((a, b) => a - b)
  public static playerEngineList = ['系统播放器', 'MPV播放器']
  // 反向映射：系统枚举 → 用户倍速
  private static REVERSE_SPEED_MAP = new Map<media.PlaybackSpeed, number>(
    Array.from(VIDEO_SPEED_MAP.entries()).map((entry) => [entry[1], entry[0]])
  )

  // 构建视频元数据对象
  // 导入优化：新增 skipCover 参数（默认 false）。当 skipCover=true 时跳过同步封面获取，
  // 仅返回带有 'Unknown' video_size 的元数据，由调用方将封面获取任务加入后台队列异步处理。
  // 这大幅减少了批量导入大文件时的 UI 阻塞时间。
  static async setVideoInfo(date: string, uri: string, file_name: string, metadata: media.AVMetadata,
    sandbox_video: string, sandbox_path: string, skipCover: boolean = false): Promise<VideoMetadata> {
    let time = '0'
    let hdr_type = media.HdrType.AV_HDR_TYPE_NONE
    let duration = '0'
    if (canIUse('SystemCapability.Multimedia.Media.AVMetadataExtractor')) {
      time = metadata.duration || '0'
      duration = metadata.duration || '0'
      hdr_type = metadata.hdrType ? media.HdrType.AV_HDR_TYPE_VIVID : media.HdrType.AV_HDR_TYPE_NONE
    }

    // 导入优化：默认使用 'Unknown'，避免在导入主流程中同步调用 getVideoSize（I/O 阻塞）。
    // 真实大小由后台异步任务 fetchCoverAndFileSizeAsync 更新到数据库。
    const estimatedSize = 'Unknown'

    let targetVideo: VideoMetadata = {
      uri: PrivacySpaceUtil.getPrivacyMode()! ? sandbox_video + date : uri,
      title: file_name,
      date: date,
      size: VideoInfoUtil.getVideoWidthAndHeight(metadata),
      time: parseInt(time),
      last_play: 0,
      format: VideoInfoUtil.getVideoFormat(file_name),
      video_size: estimatedSize,
      hdr_type: hdr_type,
      start_time: 0,
      end_time: 0,
      external_subtitle_format: '',
      pointA: 0,
      pointB: 0
    }

    // 仅非跳过模式下同步获取封面（如隐私空间导入仍需同步封面）
    if (!skipCover) {
      await VideoInfoUtil.getVideoCover(sandbox_path, date, uri, targetVideo.size, parseInt(duration))
    }

    return targetVideo
  }

  // 异步获取视频封面和真实文件大小，并更新数据库
  // 使用场景：普通视频导入时 skipCover=true，导入完成后再由 SelectFileUtil.processPendingCoverTasks
  // 在后台串行调用此方法，既避免阻塞导入流程，又能补全封面和文件大小信息。
  static async fetchCoverAndFileSizeAsync(
    videoEntity: VideoEntity,
    sandbox_path: string,
    uri: string
  ): Promise<void> {
    try {
      // 异步获取封面
      await VideoInfoUtil.getVideoCover(sandbox_path, videoEntity.date, uri, [videoEntity.width, videoEntity.height], videoEntity.duration)

      // 异步获取真实文件大小
      const actualSize = await VideoInfoUtil.getVideoSize(uri, true) as string

      // ORM 改造：将补全后的 fileSize 写回数据库
      const videoRepo = VideoRepository.getInstance()
      videoEntity.fileSize = actualSize
      await videoRepo.save(videoEntity)

      // 通知 UI 封面已就绪，触发对应列表项刷新
      coverEventBus.emit('coverReady', { date: videoEntity.date })

      salmonLogger.addLog(TAG, `异步更新视频信息完成: ${videoEntity.title}, size=${actualSize}`, false)
    } catch (error) {
      salmonLogger.addLog(TAG, `异步获取封面失败: ${videoEntity.title}, error=${error}`, true)
    }
  }

  // 获取视频封面，需要控制并发，不然获取不了,这里实现一个队列来控制并发
  static async getVideoCover(sandbox_path: string, date: string, uri: string, size: number[], time: number) {
    if (canIUse('SystemCapability.Multimedia.Media.AVMetadataExtractor')) {
      return ConcurrentQueue.enqueue(async () => {
        await PermissionUtil.persistPermission(uri)
        let file: fs.File | undefined
        let avMetadataExtractor: media.AVMetadataExtractor | undefined
        try {
          avMetadataExtractor = await media.createAVMetadataExtractor()
          file = fs.openSync(uri)
          avMetadataExtractor.fdSrc = file
          const pixelMap = await avMetadataExtractor.fetchAlbumCover()
          await SelectFileUtil.saveVideoImageToSandBox(sandbox_path, date, pixelMap)
        } catch (error) {
          await VideoInfoUtil.getVideoImage(uri, size, date, sandbox_path, time)
        } finally {
          if (file) {
            fs.closeSync(file)
          }
          if (avMetadataExtractor) {
            avMetadataExtractor?.release()?.catch(() => {
              salmonLogger.addLog(TAG, 'avMetadataExtractor release error', true)
            })
          }
        }
      })
    }
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

  // 视频没有封面时，获取指定时间帧的截图作为封面
  // 修复：原代码使用 Promise.then 导致资源释放时机不可控，且未处理 await 异常；
  //       现改为 async/await + finally 确保 avImageGenerator 和 file 总是被释放，防止 fd 泄漏。
  static async getVideoImage(uri: string, size: number[], date: string, sandbox_path: string, time: number) {
    if (canIUse('SystemCapability.Multimedia.Media.AVImageGenerator')) {
      let avImageGenerator: media.AVImageGenerator | undefined = undefined
      let file: fs.File | undefined = undefined
      try {
        avImageGenerator = await media.createAVImageGenerator()
        file = fs.openSync(uri, fs.OpenMode.READ_ONLY)
        let avFileDescriptor: media.AVFileDescriptor = { fd: file.fd }
        avImageGenerator.fdSrc = avFileDescriptor
        let timeUs = (time > 0) ? time * 100 : 0 // 微秒
        let queryOption = media.AVImageQueryOptions.AV_IMAGE_QUERY_CLOSEST
        let param: media.PixelMapParams = {
          width: size[0],
          height: size[1],
        }
        // 使用 await 等待缩略图生成完成，确保在 finally 释放资源前 pixelMap 已就绪
        const pixelMap = await avImageGenerator.fetchFrameByTime(timeUs, queryOption, param)
        await SelectFileUtil.saveVideoImageToSandBox(sandbox_path, date, pixelMap)
      } catch (error) {
        salmonLogger.addLog(TAG, 'get video image error:' + error, true)
      } finally {
        // 确保资源释放，避免文件描述符泄漏或内存占用
        if (avImageGenerator) {
          try {
            await avImageGenerator.release()
          } catch {
            salmonLogger.addLog(TAG, 'avImageGenerator release error', true)
          }
        }
        if (file) {
          try {
            fs.closeSync(file)
          } catch (e) {
            salmonLogger.addLog(TAG, 'Failed to close file: ' + e, false)
          }
        }
      }
    }
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

  // 正向：用户倍速 → 系统枚举
  static mapToSystemSpeed(userSpeed: number): media.PlaybackSpeed {
    const systemSpeed = VIDEO_SPEED_MAP.get(userSpeed)
    if (systemSpeed !== undefined) {
      return systemSpeed
    }
    return media.PlaybackSpeed.SPEED_FORWARD_1_00_X
  }

  // 反向：系统枚举 → 用户倍速
  static mapFromSystemSpeed(systemEnum: media.PlaybackSpeed): number {
    const userSpeed = VideoInfoUtil.REVERSE_SPEED_MAP.get(systemEnum)
    if (userSpeed !== undefined) {
      return userSpeed
    }
    return 1.0
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
        let file = fs.openSync(uri, fs.OpenMode.READ_ONLY)
        fs.stat(file.fd, (err: BusinessError, stat: fs.Stat) => {
          if (err) {
            reject('app.string.unknown_size')
          } else if (return_string) {
            const size = stat.size > GB ?
              (stat.size / GB).toFixed(2) + ' GB' :
              (stat.size / MB).toFixed(2) + ' MB'
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