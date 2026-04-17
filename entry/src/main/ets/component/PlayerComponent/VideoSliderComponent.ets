import { AVPlayerController } from '../../controller/AVPlayerController'
import { MpvController } from '../../controller/MpvController/MpvController'
import TimeUtil from '../../utils/TimeUtil'

@Component
export struct VideoSliderComponent {
  @Consume('player') player: AVPlayerController | MpvController
  onSliderChange = (_value: number) => {
  }
  onSliderTouch = (_event: TouchEvent) => {
  }

  build() {
    Column() {
      Row() {
        Text(TimeUtil.getPlayTime(this.player.playTime, this.player.nowPlaying?.time) + '/' +
          TimeUtil.convertMSToHHMMSS(this.player.nowPlaying?.time || 0))
          .fontWeight(FontWeight.Medium)
          .fontSize(16)
          .fontColor($r('sys.color.white'))
          .textAlign(TextAlign.Start)
          .opacity(0.8)

        Text(TimeUtil.getRemainTime(this.player.playTime, this.player.nowPlaying?.time || 0, this.player.speed))
          .fontWeight(FontWeight.Medium)
          .fontSize(16)
          .fontColor($r('sys.color.white'))
          .textAlign(TextAlign.End)
          .opacity(0.8)
      }.width('100%').height('auto')
      .justifyContent(FlexAlign.SpaceBetween)

      Slider({
        value: this.player.playTime,
        min: 0,
        // 防御性处理：当 time 为 0 或 undefined 时，默认 max 为 1，避免 Slider 组件因 max=0 出现渲染异常
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
        .opacity(0.8)
    }.height('auto').width('90%')
  }
}