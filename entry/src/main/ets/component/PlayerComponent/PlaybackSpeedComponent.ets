import { AVPlayerController } from '../../controller/AVPlayerController'
import { MpvController } from '../../controller/MpvController/MpvController'
import VideoInfoUtil from '../../utils/VideoInfoUtil'

@ComponentV2
export struct PlaybackSpeedMenuComponent {
  @Consumer('player') player: AVPlayerController | MpvController = new AVPlayerController()
  @Event onSpeedChange: (_speed: number) => void = () => {}

  build() {
    Row() {
      Text(`${this.player.speed}x`)
        .fontColor($r('sys.color.white'))
        .width(50)
        .textAlign(TextAlign.Center)
      Slider({
        value: this.player.speed,
        min: VideoInfoUtil.videoSpeedListAll[0],
        max: VideoInfoUtil.videoSpeedListAll[VideoInfoUtil.videoSpeedListAll.length - 1],
        step: 0.25,
        style: SliderStyle.NONE,
        direction: Axis.Horizontal,
        reverse: false
      })
        .trackBorderRadius(16)
        .selectedColor($r('app.color.main_color'))
        .enableHapticFeedback(true)
        .width(160)
        .height(40)
        .trackThickness(40)
        .selectedBorderRadius(16)
        .onChange((value) => {
          this.onSpeedChange(value)
        })
    }
  }
}