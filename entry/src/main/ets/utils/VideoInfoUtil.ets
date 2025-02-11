import { media } from '@kit.MediaKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { image } from '@kit.ImageKit';

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

class VideoInfoUtil {
  private GB = 1024 * 1024 * 1024 // 1GB in bytes
  private MB = 1024 * 1024 // 1MB in bytes
  private VIDEO_SPEED = 1
  private video_speed_map =
    new Map([[0.125, media.PlaybackSpeed.SPEED_FORWARD_0_125_X], [0.5, media.PlaybackSpeed.SPEED_FORWARD_0_50_X],
      [0.75, media.PlaybackSpeed.SPEED_FORWARD_0_75_X], [1.25, media.PlaybackSpeed.SPEED_FORWARD_1_25_X],
      [1.5, media.PlaybackSpeed.SPEED_FORWARD_1_50_X], [1.75, media.PlaybackSpeed.SPEED_FORWARD_1_75_X]])
  public support_video_format = ['mp4', 'flv', 'mkv', 'ts', 'mov', 'rmvb', 'wmv', 'avi']
  private speed_index_map: Record<number, number> = {
    //倍速 select 索引
    0.5: 0,
    0.75: 1,
    1: 2,
    1.25: 3,
    1.5: 4,
    2: 5,
    3: 6
  };
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
    '7680': '8K Ultra HD'
  };

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
      hdr_type: metadata.hdrType ? media.HdrType.AV_HDR_TYPE_VIVID : media.HdrType.AV_HDR_TYPE_NONE
    }
    this.testFetchFrameByTime(uri, tmp.size, date, sandbox_path)
    return tmp
  }

  async testFetchFrameByTime(uri: string, size: number[], date: string, sandbox_path: string) {
    let avImageGenerator: media.AVImageGenerator = await media.createAVImageGenerator()
    let file = fs.openSync(uri, fs.OpenMode.READ_ONLY)
    let avFileDescriptor: media.AVFileDescriptor = { fd: file.fd };
    avImageGenerator.fdSrc = avFileDescriptor
    let timeUs = 0
    let queryOption = media.AVImageQueryOptions.AV_IMAGE_QUERY_NEXT_SYNC
    let param: media.PixelMapParams = {
      width: size[0],
      height: size[1],
    }
    avImageGenerator.fetchFrameByTime(timeUs, queryOption, param).then((pixelMap: PixelMap) => {
      let packer = image.createImagePacker()
      let file1 = fs.openSync(sandbox_path + date, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE)
      packer.packToFile(pixelMap, file1.fd, { format: 'image/jpeg', quality: 100 }).then(() => {
        fs.closeSync(file1)
      }).catch()
      avImageGenerator.release()
      fs.closeSync(file)
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
    if (!Number.isInteger(video_speed)) {
      this.VIDEO_SPEED = video_speed
      return this.video_speed_map.get(video_speed)!
    } else if (video_speed !== this.VIDEO_SPEED && this.VIDEO_SPEED !== 1) {
      const PRE_VIDEO_SPEED = this.VIDEO_SPEED
      this.VIDEO_SPEED = 1
      return video_speed === 1 ? video_speed : PRE_VIDEO_SPEED
    } else {
      this.VIDEO_SPEED = video_speed
      return video_speed
    }
  }

  getVideoSpeedShow(speed: number) {
    return this.speed_index_map[speed]
  }

  videoWidthAndHeightFormat(size: string) {
    for (const key of Object.entries(this.video_size_map)) {
      if (size.includes(key[0])) {
        return key[1];
      }
    }
    return size.split(',')[0] + ' x ' + size.split(',')[1]
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
}

const videoInfoUtil = new VideoInfoUtil()

export default videoInfoUtil as VideoInfoUtil