import { media } from '@kit.MediaKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';


class VideoUtil {
  private GB = 1024 * 1024 * 1024 // 1GB in bytes
  private MB = 1024 * 1024 // 1MB in bytes
  private VIDEO_SPEED = 1
  private videoSpeedMap =
    new Map([[0.125, media.PlaybackSpeed.SPEED_FORWARD_0_125_X], [0.5, media.PlaybackSpeed.SPEED_FORWARD_0_50_X],
      [0.75, media.PlaybackSpeed.SPEED_FORWARD_0_75_X], [1.25, media.PlaybackSpeed.SPEED_FORWARD_1_25_X],
      [1.5, media.PlaybackSpeed.SPEED_FORWARD_1_50_X], [1.75, media.PlaybackSpeed.SPEED_FORWARD_1_75_X]])

  // 绑定系统播放倍速库，获取实际倍速
  getVideoSpeed(videoSpeed: number) {
    if (!Number.isInteger(videoSpeed)) {
      this.VIDEO_SPEED = videoSpeed
      return this.videoSpeedMap.get(videoSpeed)!
    } else if (videoSpeed !== this.VIDEO_SPEED && this.VIDEO_SPEED !== 1) {
      const PRE_VIDEO_SPEED = this.VIDEO_SPEED
      this.VIDEO_SPEED = 1
      return videoSpeed === 1 ? videoSpeed : PRE_VIDEO_SPEED
    } else {
      this.VIDEO_SPEED = videoSpeed
      return videoSpeed
    }
  }

  // 视频分辨率格式化
  videoSizeFormat(size: string) {
    if (size.includes('1080')) {
      return "1080P FHD"
    } else if (size.includes('2160')) {
      return "4K Ultra HD"
    } else if (size.includes('720')) {
      return "720P HD"
    } else {
      return size.split(',')[0] + ' x ' + size.split(',')[1]
    }
  }

  async getVideoSize(uri: string): Promise<string> {
    return new Promise((resolve, reject) => {
      let file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      fs.stat(file.fd, (err: BusinessError, stat: fs.Stat) => {
        if (err) {
          hilog.error(777, 'testFlag',
            "get file info failed with error message: " + err.message + ", error code: " + err.code);
          reject('app.string.unknown_size'); // Rejecting the promise
        } else {
          const size = stat.size > this.GB ?
            (stat.size / this.GB).toFixed(2) + ' GB' :
            (stat.size / this.MB).toFixed(2) + ' MB';
          hilog.error(777, 'testFlag', 'size: ' + size);
          resolve(size); // Resolving the promise with the size
        }
      });
    });
  }
}

const videoUtil = new VideoUtil()

export default videoUtil as VideoUtil