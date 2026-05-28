import { AVPlayerController } from '../../controller/AVPlayerController'
import { MpvController } from '../../controller/MpvController/MpvController'
import TimeUtil from '../../utils/TimeUtil'

@ComponentV2
export struct VideoSliderComponent {
  @Consumer('player') player: AVPlayerController | MpvController = new AVPlayerController()
  @Event onSliderChange: (_value: number) => void = () => {
  }
  @Event onSliderTouch: (_event: TouchEvent) => void = () => {
  }

  build() {
    Column() {
      Row() {
        Text(TimeUtil.getPlayTime(this.player.playTime, this.player.nowPlaying?.time) + '/' +
          TimeUtil.convertMSToHHMMSS(this.player.nowPlaying?.time || 0))
          .fontWeight(FontWeight.Medium)
          .fontSize(16)
          .fontColor($r('sys.color.white'))
          .opacity(0.9)
          .textShadow({ color: Color.Black, type: ShadowType.BLUR, radius: 4 })

        Text(this.player instanceof MpvController ? $r('app.string.MPV_Player') : $r('app.string.AV_PLAYER'))
          .fontWeight(FontWeight.Medium)
          .fontSize(16)
          .fontColor($r('sys.color.white'))
          .opacity(0.9)
          .textShadow({ color: Color.Black, type: ShadowType.BLUR, radius: 4 })
          .margin({ left: 8 })

        Blank() // 将剩余时间推至右侧

        Text(TimeUtil.getRemainTime(this.player.playTime, this.player.nowPlaying?.time || 0, this.player.speed))
          .fontWeight(FontWeight.Medium)
          .fontSize(16)
          .fontColor($r('sys.color.white'))
          .textAlign(TextAlign.End)
          .opacity(0.9)
          .textShadow({ color: Color.Black, type: ShadowType.BLUR, radius: 4 })
      }
      .width('100%')
      .height('auto')

      Slider({
        value: this.player.playTime,
        min: 0,
        max: this.player.nowPlaying?.time || 1,
        style: SliderStyle.NONE
      })
        .trackThickness(12)
        .selectedBorderRadius(16)
        .onChange((value) => {
          this.onSliderChange(value)
        })
        .onTouch((event) => {
          this.onSliderTouch(event)
        })
        .animation({ duration: 100, curve: Curve.Smooth })
        .selectedColor('#e0e0e0')
        .height('auto')
        .width('100%')
        .opacity(0.9)
    }
    .height('auto')
    .width('90%')
  }
}