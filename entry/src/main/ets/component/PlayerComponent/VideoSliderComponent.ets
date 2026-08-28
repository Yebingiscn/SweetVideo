import { PlayerControllerFactory, PlayerControllerInterface } from '../../controller/PlayerControllerFactory'
import { VIDEO_HDR_TYPE } from '../../common/enum/HDR_TYPE'
import { GradientTagBuilder, SolidColorTagBuilder } from '../common/MediaTagBuilder'
import { AnimatedPlaybackTimeBuilder, PlaybackProgressSliderComponent } from './PlaybackProgressComponent'

@ComponentV2
export struct VideoSliderComponent {
  @Consumer('player') player: PlayerControllerInterface =
    PlayerControllerFactory.createAVPlayerController() as PlayerControllerInterface

  private get networkStatusText(): string {
    const cache = this.player.networkCacheDuration.toFixed(1)
    const prefix = this.player.networkBuffering ? '缓冲中 · ' : ''
    return `${prefix}${this.player.networkSpeedText} · 缓冲 ${this.player.networkBufferPercent}% · ${cache}s`
  }

  @Event onSliderChange: (_value: number) => void = () => {
  }
  @Event onSliderTouch: (_event: TouchEvent) => void = () => {
  }

  build() {
    Column() {
      Row() {
        AnimatedPlaybackTimeBuilder({
          playTime: this.player.playTime,
          totalTime: this.player.nowPlaying?.time || 0
        })

        Text(this.player.isMpvPlayer() ? $r('app.string.MPV_Player') : $r('app.string.AV_PLAYER'))
          .fontWeight(FontWeight.Medium)
          .fontSize(16)
          .fontColor($r('sys.color.white'))
          .opacity(0.9)
          .textShadow({ color: Color.Black, type: ShadowType.BLUR, radius: 4 })
          .margin({ left: 8 })

        if (this.player.nowPlaying?.hdr_type === VIDEO_HDR_TYPE.HDR_VIVID) {
          GradientTagBuilder({
            symbol: $r('sys.symbol.hdr'),
            label: 'HDR Vivid',
            marginLeft: 6,
            marginRight: 0
          })
        } else if (this.player.nowPlaying?.hdr_type === VIDEO_HDR_TYPE.DOLBY_VISION) {
          SolidColorTagBuilder({
            symbol: $r('sys.symbol.dolby_fill'),
            label: 'DOLBY VISION',
            symbolSize: 16,
            marginLeft: 6,
            marginRight: 0
          })
        } else if (this.player.nowPlaying?.hdr_type === VIDEO_HDR_TYPE.HDR10) {
          SolidColorTagBuilder({
            label: 'HDR 10',
            textColor: $r('sys.color.black'),
            bgColor: '#de9e44',
            opacity: 0.9,
            marginLeft: 6,
            marginRight: 0
          })
        }

        if (this.player.networkPlaybackActive) {
          Text(this.networkStatusText)
            .fontWeight(FontWeight.Medium)
            .fontSize(16)
            .fontColor(this.player.networkBuffering ? '#FFFFA726' : $r('sys.color.white'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .textShadow({ color: Color.Black, type: ShadowType.BLUR, radius: 4 })
            .margin({ left: 6 })
        }

        Blank() // 将剩余时间推至右侧

        Text('-')
          .fontWeight(FontWeight.Medium)
          .fontSize(16)
          .fontColor($r('sys.color.white'))
          .opacity(0.9)
          .textShadow({ color: Color.Black, type: ShadowType.BLUR, radius: 4 })
        if (this.showHours()) {
          Text(Math.floor(this.remainSec() / 3600).toString().padStart(2, '0'))
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
        Text(Math.floor((this.remainSec() % 3600) / 60).toString().padStart(2, '0'))
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
        Text((this.remainSec() % 60).toString().padStart(2, '0'))
          .fontWeight(FontWeight.Medium)
          .fontSize(16)
          .fontColor($r('sys.color.white'))
          .textAlign(TextAlign.End)
          .opacity(0.9)
          .textShadow({ color: Color.Black, type: ShadowType.BLUR, radius: 4 })
          .contentTransition({ flipDirection: FlipDirection.DOWN, enableBlur: true })
      }
      .width('100%')
      .height('auto')

      PlaybackProgressSliderComponent({
        playTime: this.player.playTime,
        totalTime: this.player.nowPlaying?.time || 0,
        onSliderChange: (value: number) => this.onSliderChange(value),
        onSliderTouch: (event: TouchEvent) => this.onSliderTouch(event)
      })
    }
    .height('auto')
    .width('90%')
  }

  private remainSec(): number {
    return Math.floor(Math.max((this.player.nowPlaying?.time || 0) - this.player.playTime, 0) /
      (this.player.speed || 1) / 1000)
  }

  private showHours(): boolean {
    return (this.player.nowPlaying?.time || 0) >= 3600000
  }
}
