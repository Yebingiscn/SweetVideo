import { media } from '@kit.MediaKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { image } from '@kit.ImageKit';
import ReqPermission from '../utils/ReqPermissionUtil';
import { VideoMetadata } from '../interfaces/VideoMetadataInterface';
import PrivacySpaceUtil from './PrivacySpaceUtil';
import { FileProcessorUtil } from './FileProcessorUtil';
import NavigationAddress from '../common/NavigationAddress';

// 视频信息类
class VideoInfoUtil {
  // 视频格式支持列表
  public support_video_format = [
    'mp4', 'flv', 'mkv', 'ts', 'mov', 'rmvb', 'wmv', 'avi', 'm4v'
  ];
  // 音频格式支持列表
  public support_audio_format = [
    'wav', 'mp3', 'flac', 'dsf', 'dsd', 'dff', 'm4a', 'ape', 'aac', 'ogg', 'amr', 'aif', 'aiff', 'dts', 'wma', 'av3a'
  ];
  // 字幕格式支持列表
  public support_subtitle_format = ['srt', 'vtt', 'ass']
  // 屏幕比例放大列表
  public scale_factors = new Map<string, number>([
    ['等比放大 110%', 1.1],
    ['等比放大 120%', 1.2],
    ['等比放大 130%', 1.3],
    ['等比放大 140%', 1.4]
  ]);
  // 屏幕比例放大列表
  public screen_extend_map: string[] =
    ['原始比例', '填满屏幕', '16:9', '4:3', '等比放大 110%', '等比放大 120%', '等比放大 130%', '等比放大 140%']
  // 播放器视频宽度
  public play_area_width: number = 0
  // 播放器视频高度
  public play_area_height: number = 0
  private GB = 1024 * 1024 * 1024 // 1GB in bytes
  private MB = 1024 * 1024 // 1MB in bytes
  // 倍速枚举，绑定系统倍速，倍速映射：用户倍速 ↔ 系统枚举
  private VIDEO_SPEED_MAP =
    new Map<number, media.PlaybackSpeed>([[0.125, media.PlaybackSpeed.SPEED_FORWARD_0_125_X],
      [0.25, media.PlaybackSpeed.SPEED_FORWARD_0_25_X],
      [0.5, media.PlaybackSpeed.SPEED_FORWARD_0_50_X],
      [0.75, media.PlaybackSpeed.SPEED_FORWARD_0_75_X], [1, media.PlaybackSpeed.SPEED_FORWARD_1_00_X],
      [1.25, media.PlaybackSpeed.SPEED_FORWARD_1_25_X], [1.5, media.PlaybackSpeed.SPEED_FORWARD_1_50_X],
      [1.75, media.PlaybackSpeed.SPEED_FORWARD_1_75_X], [2, media.PlaybackSpeed.SPEED_FORWARD_2_00_X],
      [3, media.PlaybackSpeed.SPEED_FORWARD_3_00_X]])
  // 反向映射：系统枚举 → 用户倍速
  private REVERSE_SPEED_MAP = new Map<media.PlaybackSpeed, number>(
    Array.from(this.VIDEO_SPEED_MAP.entries()).map((entry) => [entry[1], entry[0]])
  );
  // 类成员变量
  private readonly videoSpeedListAll: number[] = Array.from(this.VIDEO_SPEED_MAP.keys())
    .filter(speed => speed >= 0.25)
    .sort((a, b) => a - b);
  private readonly videoSpeedListRedPlayer: number[] = this.videoSpeedListAll.filter(s => s <= 2);
  // 视频标签格式化
  private video_size_map: Record<string, string> = {
    '720': '720P HD',
    '800': 'HD+',
    '900': '900P HD+',
    '960': 'HD+',
    '1080': '1080P FHD',
    '1440': '2K QHD',
    '1600': 'UW QHD',
    '1666': 'Quad HD+',
    '1800': 'QHD+',
    '1960': '1080P FHD',
    '2560': '2K QHD',
    '3840': '4K Ultra HD',
    '4096': '4K Ultra HD',
    '7680': '8K Ultra HD',
    '2720x1530': 'FHD+',
    '1216x2160': 'FHD+',
  };
  private pendingQueue: Array<() => Promise<void>> = [];
  private activeCount = 0;

  // 设置存储的视频信息
  async setVideoInfo(date: string, uri: string, file_name: string, metadata: media.AVMetadata,
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
      size: this.getVideoWidthAndHeight(metadata),
      time: parseInt(time),
      last_play: 0,
      format: this.getVideoFormat(file_name),
      video_size: await this.getVideoSize(PrivacySpaceUtil.getPrivacyMode()! ? sandbox_video + date : uri,
        true) as string,
      hdr_type: hdr_type,
      start_time: 0,
      end_time: 0
    }
    this.getVideoCover(sandbox_path, date, uri, targetVideo.size, parseInt(duration))
    return targetVideo
  }

  // 获取视频封面，需要控制并发，不然获取不了,这里实现一个队列来控制并发
  async getVideoCover(sandbox_path: string, date: string, uri: string, size: number[], time: number) {
    if (canIUse('SystemCapability.Multimedia.Media.AVMetadataExtractor')) {
      return this.enqueue(async () => {
        await ReqPermission.persistPermission(uri);
        const avMetadataExtractor: media.AVMetadataExtractor = await media.createAVMetadataExtractor();
        const file = fs.openSync(uri);
        try {
          avMetadataExtractor.fdSrc = file;
          const pixelMap = await avMetadataExtractor.fetchAlbumCover();
          this.saveVideoImageToPrivacySpace(sandbox_path, date, pixelMap);
        } catch (error) {
          console.error(`AlbumCover failed: ${error.message}`);
          await this.getVideoImage(uri, size, date, sandbox_path, time);
        } finally {
          fs.closeSync(file)
          avMetadataExtractor.release();
        }
      });
    }
  }

  public getVideoFormat(videoName: string) {
    return videoName.split('.')[videoName.split('.').length-1]
  }

  public optimizedFormat(speed: number): string {
    if (speed) {
      const str = speed.toFixed(2);
      let end = str.length;
      while (end > 0 && (str[end - 1] === '0' || str[end - 1] === '.')) {
        end--;
        if (str[end] === '.') {
          break;
        }
      }
      return str.slice(0, end || 1) + 'x';
    } else {
      return '1x'
    }
  }

  getVideoTitle(item: VideoMetadata) {
    return item.title.slice(0, item.title.lastIndexOf('.'))
  }

  // 视频没有封面设置获取指定时间的截图作为视频封面
  async getVideoImage(uri: string, size: number[], date: string, sandbox_path: string, time: number) {
    if (canIUse('SystemCapability.Multimedia.Media.AVImageGenerator')) {
      let avImageGenerator: media.AVImageGenerator = await media.createAVImageGenerator();
      let file = fs.openSync(uri, fs.OpenMode.READ_ONLY)
      let avFileDescriptor: media.AVFileDescriptor = { fd: file.fd };
      avImageGenerator.fdSrc = avFileDescriptor
      let timeUs = (time > 0) ? time * 100 : 0
      let queryOption = media.AVImageQueryOptions.AV_IMAGE_QUERY_NEXT_SYNC
      let param: media.PixelMapParams = {
        width: size[0],
        height: size[1],
      }
      avImageGenerator.fetchFrameByTime(timeUs, queryOption, param).then((pixelMap: PixelMap) => {
        this.saveVideoImageToPrivacySpace(sandbox_path, date, pixelMap)
        avImageGenerator.release()
        fs.closeSync(file)
      })
    }
  }

  // 保存封面，封面获取后复制到应用私有目录下
  saveVideoImageToPrivacySpace(sandbox_path: string, date: string, pixelMap: image.PixelMap) {
    let packer = image.createImagePacker()
    let file1 = fs.openSync(sandbox_path + date, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE)
    // 设置为85平衡内存、导入速度以及图片质量
    packer.packToFile(pixelMap, file1.fd, { format: 'image/webp', quality: 85 }).then(() => {
      fs.closeSync(file1)
    }).catch((error: BusinessError) => {
      console.error(`Failed to pack the image to file.code ${error.code},message is ${error.message}`);
      fs.closeSync(file1)
    })
  }

  // 获取视频长宽
  getVideoWidthAndHeight(metadata: media.AVMetadata) {
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
  mapToSystemSpeed(userSpeed: number): media.PlaybackSpeed {
    return this.VIDEO_SPEED_MAP.get(userSpeed) || media.PlaybackSpeed.SPEED_FORWARD_1_00_X;
  }

  // 反向：系统枚举 → 用户倍速
  mapFromSystemSpeed(systemEnum: media.PlaybackSpeed): number {
    return this.REVERSE_SPEED_MAP.get(systemEnum) || 1.0;
  }

  getVideoSpeedList(player: string): number[] {
    return player === NavigationAddress.RED_PLAYER
      ? this.videoSpeedListRedPlayer
      : this.videoSpeedListAll;
  }

  // 获取视频标签格式化
  videoWidthAndHeightFormat(size: string) {
    const sizeArray = size.split(',');
    const width = sizeArray[0];
    const height = sizeArray[1];
    const sizeKey = `${width}x${height}`;
    // 匹配优先级
    return this.video_size_map[sizeKey] || // 1. 精确匹配宽高
    this.video_size_map[height] || // 2. 标准高度命名
    this.video_size_map[width] || // 3. 特殊宽度标准
      `${width} x ${height}`; // 4. 默认格式
  }

  // 获取视频大小
  async getVideoSize(uri: string, return_string: boolean): Promise<string | number> {
    return new Promise((resolve, reject) => {
      let file = fs.openSync(uri, fs.OpenMode.READ_ONLY)
      fs.stat(file.fd, (err: BusinessError, stat: fs.Stat) => {
        if (err) {
          reject('app.string.unknown_size')
        } else if (return_string) {
          const size = stat.size > this.GB ?
            (stat.size / this.GB).toFixed(2) + ' GB' :
            (stat.size / this.MB).toFixed(2) + ' MB'
          resolve(size)
        } else {
          resolve(stat.size)
        }
      });
    });
  }

  // 保存视频初始长宽，变更后视频长宽后使用
  saveVideoWidthAndHeight(play_area_width: number, play_area_height: number) {
    this.play_area_width = play_area_width
    this.play_area_height = play_area_height
  }

  // 实现了一个并发控制队列方法
  private async enqueue<T>(task: () => Promise<T>): Promise<T> {
    return new Promise((resolve, reject) => {
      const wrappedTask = async () => {
        try {
          const result = await task();
          resolve(result);
        } catch (error) {
          reject(error);
        } finally {
          this.activeCount--;
          this.processNext();
        }
      };

      this.pendingQueue.push(wrappedTask);
      this.processNext();
    });
  }

  private processNext() {
    if (this.activeCount < FileProcessorUtil.MAX_CONCURRENT && this.pendingQueue.length > 0) {
      this.activeCount++;
      const task = this.pendingQueue.shift()!;
      task();
    }
  }
}

export default new VideoInfoUtil()