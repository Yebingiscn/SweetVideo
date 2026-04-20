import { AVPlayerController } from '../../controller/AVPlayerController'
import { MpvController } from '../../controller/MpvController/MpvController'
import VideoInfoUtil from '../../utils/VideoInfoUtil'

@Component
export struct PlaybackSpeedMenuComponent {
  @Consume('player') player: AVPlayerController | MpvController
  onSpeedChange = (_speed: number) => {
  }

  build() {
    Row() {
      Text(`${this.player.speed}x`).fontColor($r('sys.color.white')).padding({ left: 5 })
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
        .padding({ left: 15 })
    }
  }
}