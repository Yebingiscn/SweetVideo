import { media } from '@kit.MediaKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import PrivacySpaceUtil from './PrivacySpaceUtil'
import { ConcurrentQueue } from './FileProcessorUtil'
import SelectFileUtil from './SelectFileUtil'
import PermissionUtil from './PermissionUtil'
import { GB, MB, SCREEN_EXTEND_LIST, VIDEO_SIZE_MAP, VIDEO_SPEED_MAP } from '../common/Constants'

// 视频信息类
export default class VideoInfoUtil {
  public static screenExtendMap: string[] = SCREEN_EXTEND_LIST.map(item => item.value as string)
  // 播放器视频宽度
  public static playAreaWidth: number = 0
  // 播放器视频高度
  public static playAreaHeight: number = 0
  public static ASPECT_RATIO_MAP: Map<string, number> = new Map([[VideoInfoUtil.screenExtendMap[4], 16 / 9],
    [VideoInfoUtil.screenExtendMap[5], 4 / 3]])
  public static readonly videoSpeedListAll: number[] = Array.from(VIDEO_SPEED_MAP.keys())
    .filter(speed => speed >= 0.25)
    .sort((a, b) => a - b)
  public static playerList = ['系统播放器', 'MPV播放器']
  // 反向映射：系统枚举 → 用户倍速
  private static REVERSE_SPEED_MAP = new Map<media.PlaybackSpeed, number>(
    Array.from(VIDEO_SPEED_MAP.entries()).map((entry) => [entry[1], entry[0]])
  )

  // 设置存储的视频信息
  static async setVideoInfo(date: string, uri: string, file_name: string, metadata: media.AVMetadata,
    sandbox_video: string, sandbox_path: string) {
    let time = '0'
    let hdr_type = media.HdrType.AV_HDR_TYPE_NONE
    let duration = '0'
    if (canIUse('SystemCapability.Multimedia.Media.AVMetadataExtractor')) {
      time = metadata.duration || '0'
      duration = metadata.duration || '0'
      hdr_type = metadata.hdrType ? media.HdrType.AV_HDR_TYPE_VIVID : media.HdrType.AV_HDR_TYPE_NONE
    }
    let targetVideo: VideoMetadata = {
      uri: PrivacySpaceUtil.getPrivacyMode()! ? sandbox_video + date : uri,
      title: file_name,
      date: date,
      size: VideoInfoUtil.getVideoWidthAndHeight(metadata),
      time: parseInt(time),
      last_play: 0,
      format: VideoInfoUtil.getVideoFormat(file_name),
      video_size: await VideoInfoUtil.getVideoSize(PrivacySpaceUtil.getPrivacyMode()! ? sandbox_video + date : uri,
        true) as string,
      hdr_type: hdr_type,
      start_time: 0,
      end_time: 0,
      external_subtitle_format: '',
      pointA: 0,
      pointB: 0
    }
    VideoInfoUtil.getVideoCover(sandbox_path, date, uri, targetVideo.size, parseInt(duration))
    return targetVideo
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
          SelectFileUtil.saveVideoImageToPrivacySpace(sandbox_path, date, pixelMap)
        } catch (error) {
          console.error(`AlbumCover failed: ${error.message}`)
          await VideoInfoUtil.getVideoImage(uri, size, date, sandbox_path, time)
        } finally {
          if (file) {
            fs.closeSync(file)
          }
          if (avMetadataExtractor) {
            avMetadataExtractor?.release()?.catch(() => {
              console.error('release error')
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

  static getVideoTitle(item: VideoMetadata) {
    return item.title.slice(0, item.title.lastIndexOf('.'))
  }

  // 视频没有封面设置获取指定时间的截图作为视频封面
  static async getVideoImage(uri: string, size: number[], date: string, sandbox_path: string, time: number) {
    if (canIUse('SystemCapability.Multimedia.Media.AVImageGenerator')) {
      try {
        let avImageGenerator: media.AVImageGenerator = await media.createAVImageGenerator()
        let file = fs.openSync(uri, fs.OpenMode.READ_ONLY)
        let avFileDescriptor: media.AVFileDescriptor = { fd: file.fd }
        avImageGenerator.fdSrc = avFileDescriptor
        let timeUs = (time > 0) ? time * 100 : 0 // 微秒
        let queryOption = media.AVImageQueryOptions.AV_IMAGE_QUERY_CLOSEST
        let param: media.PixelMapParams = {
          width: size[0],
          height: size[1],
        }
        avImageGenerator.fetchFrameByTime(timeUs, queryOption, param).then((pixelMap: PixelMap) => {
          SelectFileUtil.saveVideoImageToPrivacySpace(sandbox_path, date, pixelMap)
          avImageGenerator.release()?.catch(() => {
            console.error('release error')
          })
          fs.closeSync(file)
        })?.catch(() => {
          console.error('fetch frame error')
        })
      } catch (error) {
        console.error('get video image error:' + error)
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
  static videoWidthAndHeightFormat(size: string) {
    const sizeArray = size.split(',')
    const width = sizeArray[0]
    const height = sizeArray[1]
    const sizeKey = `${width}x${height}`
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
        console.error('size error:' + error)
      }
    })
  }

  // 保存视频初始长宽，变更后视频长宽后使用
  static saveOriginalVideoWidthAndHeight(play_area_width: number, play_area_height: number) {
    VideoInfoUtil.playAreaWidth = play_area_width
    VideoInfoUtil.playAreaHeight = play_area_height
  }
}