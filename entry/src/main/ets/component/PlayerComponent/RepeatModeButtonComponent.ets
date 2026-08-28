import { SweetRepeatMode } from '../../common/enum/SweetRepeatMode'
import AVSessionUtil from '../../utils/AVSessionUtil'
import ToolsUtil from '../../utils/ToolsUtil'
import VideoOperateUtil from '../../utils/VideoOperateUtil'

export function getRepeatModeIcon(repeatMode: SweetRepeatMode): Resource {
  switch (repeatMode) {
    case SweetRepeatMode.SINGLE:
      return $r('sys.symbol.repeat_1')
    case SweetRepeatMode.RANDOM:
      return $r('sys.symbol.shuffle')
    case SweetRepeatMode.LIST:
      return $r('sys.symbol.repeat')
    case SweetRepeatMode.SEQUENCE:
      return $r('sys.symbol.order_play')
    default:
      return $r('sys.symbol.order_play')
  }
}

export function getRepeatModeText(repeatMode: SweetRepeatMode): string {
  switch (repeatMode) {
    case SweetRepeatMode.SINGLE:
      return '单曲循环'
    case SweetRepeatMode.RANDOM:
      return '随机播放'
    case SweetRepeatMode.LIST:
      return '列表循环'
    case SweetRepeatMode.SEQUENCE:
      return '顺序播放'
    default:
      return '列表循环'
  }
}

@ComponentV2
export struct RepeatModeButtonComponent {
  @Param repeatMode: SweetRepeatMode = SweetRepeatMode.LIST
  @Param playing: boolean = false
  @Param playTime: number = 0
  @Param compact: boolean = false
  @Event onRepeatModeChange: (repeatMode: SweetRepeatMode) => void = (_repeatMode: SweetRepeatMode) => {
  }

  build() {
    if (this.compact) {
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph(getRepeatModeIcon(this.repeatMode))
          .fontSize(21)
          .fontColor([Color.White])
      }
      .width(40)
      .height(40)
      .backgroundColor('#55000000')
      .onClick(() => this.switchRepeatMode())
    } else {
      Row({ space: 10 }) {
        SymbolGlyph(getRepeatModeIcon(this.repeatMode))
          .fontSize(22)
          .fontColor([$r('app.color.text_color')])
        Text(getRepeatModeText(this.repeatMode))
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_color'))
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 16 })
      .borderRadius(12)
      .backgroundColor($r('app.color.list_item_background'))
      .margin({ top: 6, bottom: 6 })
      .onClick(() => this.switchRepeatMode())
      .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.96 })
    }
  }

  private switchRepeatMode(): void {
    const repeatMode = VideoOperateUtil.getRepeatMode(this.repeatMode)
    this.onRepeatModeChange(repeatMode)
    AVSessionUtil.updatePlaybackSessionState(this.playing, this.playTime, repeatMode)
    ToolsUtil.showToast(getRepeatModeText(repeatMode))
  }
}
