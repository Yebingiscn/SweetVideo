import { media } from '@kit.MediaKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { image } from '@kit.ImageKit';
import ReqPermission from '../utils/ReqPermissionUtil';

export interface VideoMetadata {
  uri: string
  title: string
  date: string
  size: number[]
  time: number
  last_play: number
  format: string
  video_size: string
  hdr_type: number
}

export interface VideoMetadataFromPlayer {
  uri: string
  title: string
  date: string,
  size: number[]
  time: number
  last_play: number
}

export interface AudioTrack {
  index: number;
  language: string;
  name: string;
  mime: string
}

interface shadowFancyInterface {
  radius: number;
  color: Resource;
  offsetX: number;
  offsetY: number;
}

export const DEFAULT_DIALOG_SHADOW: shadowFancyInterface = {
  radius: 26,
  color: $r('app.color.shadow_color'), // 确保颜色资源路径正确
  offsetX: 0,
  offsetY: 0
};

class VideoInfoUtil {
  public support_video_format = [
    'mp4', 'flv', 'mkv', 'ts', 'mov', 'rmvb', 'wmv', 'avi', 'm4v'
  ];
  public support_audio_format = [
    'wav', 'mp3', 'flac', 'dsf', 'dsd', 'dff', 'm4a', 'ape', 'aac', 'ogg', 'amr', 'aif', 'aiff', 'dts', 'wma'
  ];
  public support_subtitle_format = ['srt', 'vtt']
  public speed_index_map: number[] = [0.25, 0.5, 0.75, 1, 1.25, 1.5, 1.75, 2, 3]
  public scale_factors = new Map<string, number>([
    ['等比放大 110%', 1.1],
    ['等比放大 120%', 1.2],
    ['等比放大 130%', 1.3],
    ['等比放大 140%', 1.4]
  ]);
  public screen_extend_map: string[] =
    ['原始比例', '填满屏幕', '等比放大 110%', '等比放大 120%', '等比放大 130%', '等比放大 140%']
  public play_area_width: number = 0
  public play_area_height: number = 0
  private GB = 1024 * 1024 * 1024 // 1GB in bytes
  private MB = 1024 * 1024 // 1MB in bytes
  private VIDEO_SPEED = 1
  private video_speed_map =
    new Map([[0.125, media.PlaybackSpeed.SPEED_FORWARD_0_125_X], [0.25, media.PlaybackSpeed.SPEED_FORWARD_0_25_X],
      [0.5, media.PlaybackSpeed.SPEED_FORWARD_0_50_X],
      [0.75, media.PlaybackSpeed.SPEED_FORWARD_0_75_X], [1, media.PlaybackSpeed.SPEED_FORWARD_1_00_X],
      [1.25, media.PlaybackSpeed.SPEED_FORWARD_1_25_X], [1.5, media.PlaybackSpeed.SPEED_FORWARD_1_50_X],
      [1.75, media.PlaybackSpeed.SPEED_FORWARD_1_75_X], [2, media.PlaybackSpeed.SPEED_FORWARD_2_00_X],
      [3, media.PlaybackSpeed.SPEED_FORWARD_3_00_X]])
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
  private MAX_CONCURRENT = 3;
  private pendingQueue: Array<() => Promise<void>> = [];
  private activeCount = 0;

  // 设置存储的视频信息
  async setVideoInfo(date: string, uri: string, file_name: string, metadata: media.AVMetadata, encryption: boolean,
    sandbox_video: string, sandbox_path: string) {
    let tmp: VideoMetadata = {
      uri: encryption ? sandbox_video + date : uri,
      title: file_name,
      date: date,
      size: this.getVideoWidthAndHeight(metadata),
      time: parseInt(metadata.duration || '0'),
      last_play: 0,
      format: file_name.split('.')[file_name.split('.').length-1],
      video_size: await this.getVideoSize(encryption ? sandbox_video + date : uri),
      hdr_type: metadata.hdrType ? media.HdrType.AV_HDR_TYPE_VIVID : media.HdrType.AV_HDR_TYPE_NONE,
    }
    this.getVideoCover(sandbox_path, date, uri, tmp.size, parseInt(metadata.duration || '0'))
    return tmp
  }

  // 并发控制核心方法
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
    if (this.activeCount < this.MAX_CONCURRENT && this.pendingQueue.length > 0) {
      this.activeCount++;
      const task = this.pendingQueue.shift()!;
      task();
    }
  }

  async getVideoCover(sandbox_path: string, date: string, uri: string, size: number[], time: number) {
    return this.enqueue(async () => {
      await ReqPermission.persistPermission(uri);

      const avMetadataExtractor: media.AVMetadataExtractor = await media.createAVMetadataExtractor();
      const file = fs.openSync(uri);

      try {
        avMetadataExtractor.fdSrc = file;
        const pixelMap = await avMetadataExtractor.fetchAlbumCover();
        await this.saveVideoImg(sandbox_path, date, pixelMap);
      } catch (error) {
        console.error(`AlbumCover failed: ${error.message}`);
        await this.getVideoImage(uri, size, date, sandbox_path, time);
      } finally {
        fs.closeSync(file)
        avMetadataExtractor.release();
      }
    });
  }

  public optimizedFormat(speed: number): string {
    const str = speed.toFixed(2);
    let end = str.length;
    while (end > 0 && (str[end - 1] === '0' || str[end - 1] === '.')) {
      end--;
      if (str[end] === '.') {
        break;
      }
    }
    return str.slice(0, end || 1) + 'x';
  }

  async getVideoImage(uri: string, size: number[], date: string, sandbox_path: string, time: number) {
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
      this.saveVideoImg(sandbox_path, date, pixelMap)
      avImageGenerator.release()
      fs.closeSync(file)
    })
  }

  saveVideoImg(sandbox_path: string, date: string, pixelMap: image.PixelMap) {
    let packer = image.createImagePacker()
    let file1 = fs.openSync(sandbox_path + date, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE)
    packer.packToFile(pixelMap, file1.fd, { format: 'image/jpeg', quality: 85 }).then(() => {
      fs.closeSync(file1)
    }).catch((error: BusinessError) => {
      console.error(`Failed to pack the image to file.code ${error.code},message is ${error.message}`);
      fs.closeSync(file1)
    })
  }

  getVideoWidthAndHeight(metadata: media.AVMetadata) {
    const isPortrait = metadata.videoOrientation === '90' || metadata.videoOrientation === '270'
    const width = parseInt(String(isPortrait ? metadata.videoHeight : metadata.videoWidth)) || 0
    const height = parseInt(String(isPortrait ? metadata.videoWidth : metadata.videoHeight)) || 0
    return [width, height]
  }

  // 绑定系统播放倍速库，获取实际倍速
  getVideoSpeed(video_speed: number) {
    if (this.VIDEO_SPEED === 1) {
      this.VIDEO_SPEED = video_speed
      return this.video_speed_map.get(video_speed)!
    } else {
      let pre_speed = this.VIDEO_SPEED
      this.VIDEO_SPEED = 1
      return pre_speed
    }
  }

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

  async getVideoSize(uri: string): Promise<string> {
    return new Promise((resolve, reject) => {
      let file = fs.openSync(uri, fs.OpenMode.READ_ONLY)
      fs.stat(file.fd, (err: BusinessError, stat: fs.Stat) => {
        if (err) {
          reject('app.string.unknown_size')
        } else {
          const size = stat.size > this.GB ?
            (stat.size / this.GB).toFixed(2) + ' GB' :
            (stat.size / this.MB).toFixed(2) + ' MB'
          resolve(size)
        }
      });
    });
  }

  async getAudioTracks(avPlayer: media.AVPlayer): Promise<AudioTrack[]> {
    const getTrackDescriptions = (): Promise<AudioTrack[]> => {
      return new Promise((resolve, reject) => {
        avPlayer.getTrackDescription((error: BusinessError, arrList: Array<media.MediaDescription>) => {
          if (error || !arrList || arrList.length === 0) {
            console.error(`Failed to get TrackDescription, error: ${error}`);
            return reject(error || new Error("No audio tracks available"));
          }
          const audioTracks: AudioTrack[] = arrList
            .filter(description =>
            description[media.MediaDescriptionKey.MD_KEY_TRACK_TYPE] === media.MediaType.MEDIA_TYPE_AUD
            )
            .map((description): AudioTrack => {
              return {
                index: description[media.MediaDescriptionKey.MD_KEY_TRACK_INDEX] as number,
                language: description[media.MediaDescriptionKey.MD_KEY_LANGUAGE] as string,
                name: description[media.MediaDescriptionKey.MD_KEY_TRACK_NAME] as string,
                mime: description[media.MediaDescriptionKey.MD_KEY_CODEC_MIME] as string
              };
            });
          resolve(audioTracks);
        });
      });
    };

    try {
      const audioTracks = await getTrackDescriptions();
      return audioTracks; // 返回包含音轨索引、语言和名称的对象数组
    } catch (error) {
      console.error("获取 audioTracks 失败:", error);
      return []; // 返回空数组表示没有获取到音轨
    }
  }
}

export default new VideoInfoUtil()