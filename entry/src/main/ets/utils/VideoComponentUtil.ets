import { media } from "@kit.MediaKit"


class VideoUtil {
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
    } else if (videoSpeed != this.VIDEO_SPEED && this.VIDEO_SPEED != 1) {
      let PRE_VIDEO_SPEED = this.VIDEO_SPEED
      this.VIDEO_SPEED = 1
      return PRE_VIDEO_SPEED
    } else {
      this.VIDEO_SPEED = videoSpeed
      return videoSpeed
    }
  }

  // 视频分辨率格式化
  videoSizeFormat(size: string) {
    if (size == '1920,1080' || size == '1080,1920') {
      return "1080P FHD"
    } else if (size == '2160,3840' || size == '3840,2160') {
      return "4K Ultra HD"
    } else if (size == '1920,720' || size == '720,1920') {
      return "720P HD"
    } else {
      return size.split(',')[0] + ' x ' + size.split(',')[1]
    }
  }
}

const VideoComponentUtil = new VideoUtil()

export default VideoComponentUtil