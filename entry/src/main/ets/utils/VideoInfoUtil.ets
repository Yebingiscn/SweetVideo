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
}

class VideoInfoUtil {
  private GB = 1024 * 1024 * 1024 // 1GB in bytes
  private MB = 1024 * 1024 // 1MB in bytes
  private VIDEO_SPEED = 1
  private video_speed_map =
    new Map([[0.125, media.PlaybackSpeed.SPEED_FORWARD_0_125_X], [0.5, media.PlaybackSpeed.SPEED_FORWARD_0_50_X],
      [0.75, media.PlaybackSpeed.SPEED_FORWARD_0_75_X], [1.00, media.PlaybackSpeed.SPEED_FORWARD_1_00_X],
      [1.25, media.PlaybackSpeed.SPEED_FORWARD_1_25_X], [1.5, media.PlaybackSpeed.SPEED_FORWARD_1_50_X],
      [1.75, media.PlaybackSpeed.SPEED_FORWARD_1_75_X], [2.00, media.PlaybackSpeed.SPEED_FORWARD_2_00_X],
      [3.00, media.PlaybackSpeed.SPEED_FORWARD_3_00_X]])
  public support_video_format = ['mp4', 'flv', 'mkv', 'ts', 'mov', 'rmvb', 'wmv', 'avi']
  private speed_index_map: Record<number, number> = {
    //倍速 select 索引
    0.5: 0,
    0.75: 1,
    1: 2,
    1.25: 3,
    1.5: 4,
    1.75: 5,
    2: 6,
    3: 7
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
      hdr_type: metadata.hdrType ? media.HdrType.AV_HDR_TYPE_VIVID : media.HdrType.AV_HDR_TYPE_NONE,
    }
    this.getVideoCover(sandbox_path, date, uri, tmp.size, parseInt(metadata.duration || '0'))
    return tmp
  }

  async getVideoCover(sandbox_path: string, date: string, uri: string, size: number[], time: number) {
    ReqPermission.persistPermission(uri);
    const avMetadataExtractor: media.AVMetadataExtractor = await media.createAVMetadataExtractor();
    const file = fs.openSync(uri);
    avMetadataExtractor.fdSrc = file;
    avMetadataExtractor.fetchAlbumCover().then((pixelMap: image.PixelMap) => {
      this.saveVideoImg(sandbox_path, date, pixelMap)
    }).catch((error: BusinessError) => {
      console.error(`Failed to fetch AlbumCover, error message:${error.message}`);
      this.getVideoImage(uri, size, date, sandbox_path, time)
    });
  }

  async getVideoImage(uri: string, size: number[], date: string, sandbox_path: string, time: number) {
    let avImageGenerator: media.AVImageGenerator = await media.createAVImageGenerator()
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
    packer.packToFile(pixelMap, file1.fd, { format: 'image/jpeg', quality: 100 }).then(() => {
      fs.closeSync(file1)
    }).catch()
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

const videoInfoUtil = new VideoInfoUtil()

export default videoInfoUtil as VideoInfoUtil