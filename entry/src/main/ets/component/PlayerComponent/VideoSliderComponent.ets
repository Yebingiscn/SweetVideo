import { PlayerControllerFactory, PlayerControllerInterface } from '../../controller/PlayerControllerFactory'
import TimeUtil from '../../utils/TimeUtil'
import { VIDEO_HDR_TYPE } from '../../common/enum/HDR_TYPE'
import { GradientTagBuilder, SolidColorTagBuilder } from '../common/MediaTagBuilder'

@ComponentV2
export struct VideoSliderComponent {
  @Consumer('player') player: PlayerControllerInterface =
    PlayerControllerFactory.createAVPlayerController() as PlayerControllerInterface
  @Event onSliderChange: (_value: number) => void = () => {
  }
  @Event onSliderTouch: (_event: TouchEvent) => void = () => {
  }

  build() {
    Column() {
      Row() {
        if (this.player.nowPlaying?.time) {
          if (this.showHours()) {
            Text(Math.floor(this.curSec() / 3600).toString().padStart(2, '0'))
              .fontWeight(FontWeight.Medium)
              .fontSize(16)
              .fontColor($r('sys.color.white'))
              .opacity(0.9)
              .textShadow({ color: Color.Black, type: ShadowType.BLUR, radius: 4 })
              .contentTransition({ flipDirection: FlipDirection.DOWN, enableBlur: true })
            Text(':')
              .fontWeight(FontWeight.Medium)
              .fontSize(16)
              .fontColor($r('sys.color.white'))
              .opacity(0.9)
          }
          Text(Math.floor((this.curSec() % 3600) / 60).toString().padStart(2, '0'))
            .fontWeight(FontWeight.Medium)
            .fontSize(16)
            .fontColor($r('sys.color.white'))
            .opacity(0.9)
            .textShadow({ color: Color.Black, type: ShadowType.BLUR, radius: 4 })
            .contentTransition({ flipDirection: FlipDirection.DOWN, enableBlur: true })
          Text(':')
            .fontWeight(FontWeight.Medium)
            .fontSize(16)
            .fontColor($r('sys.color.white'))
            .opacity(0.9)
          Text((this.curSec() % 60).toString().padStart(2, '0'))
            .fontWeight(FontWeight.Medium)
            .fontSize(16)
            .fontColor($r('sys.color.white'))
            .opacity(0.9)
            .textShadow({ color: Color.Black, type: ShadowType.BLUR, radius: 4 })
            .contentTransition({ flipDirection: FlipDirection.DOWN, enableBlur: true })
          Text(' / ')
            .fontWeight(FontWeight.Medium)
            .fontSize(16)
            .fontColor($r('sys.color.white'))
            .opacity(0.9)
          if (this.showHours()) {
            Text(Math.floor(this.totSec() / 3600).toString().padStart(2, '0'))
              .fontWeight(FontWeight.Medium)
              .fontSize(16)
              .fontColor($r('sys.color.white'))
              .opacity(0.9)
              .textShadow({ color: Color.Black, type: ShadowType.BLUR, radius: 4 })
              .contentTransition({ flipDirection: FlipDirection.DOWN, enableBlur: true })
            Text(':')
              .fontWeight(FontWeight.Medium)
              .fontSize(16)
              .fontColor($r('sys.color.white'))
              .opacity(0.9)
          }
          Text(Math.floor((this.totSec() % 3600) / 60).toString().padStart(2, '0'))
            .fontWeight(FontWeight.Medium)
            .fontSize(16)
            .fontColor($r('sys.color.white'))
            .opacity(0.9)
            .textShadow({ color: Color.Black, type: ShadowType.BLUR, radius: 4 })
            .contentTransition({ flipDirection: FlipDirection.DOWN, enableBlur: true })
          Text(':')
            .fontWeight(FontWeight.Medium)
            .fontSize(16)
            .fontColor($r('sys.color.white'))
            .opacity(0.9)
          Text((this.totSec() % 60).toString().padStart(2, '0'))
            .fontWeight(FontWeight.Medium)
            .fontSize(16)
            .fontColor($r('sys.color.white'))
            .opacity(0.9)
            .textShadow({ color: Color.Black, type: ShadowType.BLUR, radius: 4 })
            .contentTransition({ flipDirection: FlipDirection.DOWN, enableBlur: true })
        } else {
          Text('--:-- / --:--')
            .fontWeight(FontWeight.Medium)
            .fontSize(16)
            .fontColor($r('sys.color.white'))
            .opacity(0.9)
            .textShadow({ color: Color.Black, type: ShadowType.BLUR, radius: 4 })
        }

        Text(this.player.isMpvPlayer() ? $r('app.string.MPV_Player') : $r('app.string.AV_PLAYER'))
          .fontWeight(FontWeight.Medium)
          .fontSize(16)
          .fontColor($r('sys.color.white'))
          .opacity(0.9)
          .textShadow({ color: Color.Black, type: ShadowType.BLUR, radius: 4 })
          .margin({ left: 8 })

        if (this.player.nowPlaying?.hdr_type === VIDEO_HDR_TYPE.HDR_VIVID) {
          GradientTagBuilder({ symbol: $r('sys.symbol.hdr'), label: 'HDR Vivid', marginLeft: 6, marginRight: 0 })
        } else if (this.player.nowPlaying?.hdr_type === VIDEO_HDR_TYPE.DOLBY_VISION) {
          SolidColorTagBuilder({ symbol: $r('sys.symbol.dolby_fill'), label: 'DOLBY VISION', symbolSize: 16, marginLeft: 6, marginRight: 0 })
        } else if (this.player.nowPlaying?.hdr_type === VIDEO_HDR_TYPE.HDR10) {
          SolidColorTagBuilder({ label: 'HDR 10', textColor: $r('sys.color.black'), bgColor: '#de9e44', opacity: 0.9, marginLeft: 6, marginRight: 0 })
        }

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

  private curSec(): number {
    return Math.floor(Math.min(Math.max(this.player.playTime, 0), this.player.nowPlaying?.time || 0) / 1000)
  }

  private totSec(): number {
    return Math.floor((this.player.nowPlaying?.time || 0) / 1000)
  }

  private showHours(): boolean {
    return (this.player.nowPlaying?.time || 0) >= 3600000
  }
}