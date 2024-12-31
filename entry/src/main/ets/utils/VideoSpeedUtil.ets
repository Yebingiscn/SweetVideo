import { media } from "@kit.MediaKit"

/*
 * 绑定系统播放倍速库，获取实际倍速
 * */
class VideoSpeed {
  private VIDEO_SPEED = 1
  private videoSpeedMap =
    new Map([[0.125, media.PlaybackSpeed.SPEED_FORWARD_0_125_X], [0.5, media.PlaybackSpeed.SPEED_FORWARD_0_50_X],
      [0.75, media.PlaybackSpeed.SPEED_FORWARD_0_75_X], [1.25, media.PlaybackSpeed.SPEED_FORWARD_1_25_X],
      [1.5, media.PlaybackSpeed.SPEED_FORWARD_1_50_X], [1.75, media.PlaybackSpeed.SPEED_FORWARD_1_75_X]])

  getVideoSpeed(speed: number) {
    if (this.videoSpeedMap.has(speed)) {
      this.VIDEO_SPEED = speed
      return this.videoSpeedMap.get(speed)!
    } else if (speed != this.VIDEO_SPEED && this.VIDEO_SPEED != 1) {
      let PRE_VIDEO_SPEED = this.VIDEO_SPEED
      this.VIDEO_SPEED = 1
      return PRE_VIDEO_SPEED
    } else {
      this.VIDEO_SPEED = speed
      return speed
    }
  }
}

const VideoSpeedUtil = new VideoSpeed()

export default VideoSpeedUtil