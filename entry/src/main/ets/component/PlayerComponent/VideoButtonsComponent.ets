import { AVCastPicker } from '@kit.AVSessionKit'
import ToolsUtil from '../../utils/ToolsUtil'
import { KeyCode } from '@kit.InputKit'
import { ButtonFancyModifier, SymbolGlyphFancyModifier } from '../../common/AttributeModifierConfig'
import { RepeatMode } from '../../common/enum/RepeatMode'
import AVSessionUtil from '../../utils/AVSessionUtil'
import { AVPlayerController } from '../../controller/AVPlayerController'
import VideoOperateUtil from '../../utils/VideoOperateUtil'

@Component
export struct VideoButtonsComponent {
  @Prop screenHeight: number
  @Prop screenWidth: number
  @Prop playing: boolean
  @Prop speed: number
  @Link repeatMode: RepeatMode
  @Link sideBarStatusTmp: Visibility
  @Link sideBarStatus: boolean
  @BuilderParam AVCastPickerBuilderBridge: () => void
  @BuilderParam videoSettingBuilder: () => void
  @BuilderParam playbackSpeedMenu: () => void
  @Consume('player') player: AVPlayerController
  onScreenRotationOrFullScreenClick = async () => {
  }
  onTogglePlaybackClick = () => {
  }
  onPlayNextVideoClick = () => {
  }
  onSideBaClose = () => {
  }

  build() {
    GridRow({ columns: this.screenHeight / this.screenWidth > 1.4 ? 8 : 16, gutter: 5 }) {
      GridCol() {
        Button({ type: ButtonType.Circle, stateEffect: true }) { // 播放按钮
          SymbolGlyph(this.playing ? $r('sys.symbol.pause_fill') : $r('sys.symbol.play_fill'))
            .attributeModifier(new SymbolGlyphFancyModifier(23, '', ''))
            .fontColor(['#f0f0f0'])
        }
        .attributeModifier(new ButtonFancyModifier(40, 40))
        .backgroundColor('#50000000')
        .onClick(() => {
          ToolsUtil.startVibration()
          this.onTogglePlaybackClick()
        })
        .onKeyEvent((event: KeyEvent) => {
          if ((event.keyCode === KeyCode.KEYCODE_SPACE && event.type === KeyType.Down)) {
            this.onTogglePlaybackClick()
          }
        })
        .defaultFocus(true) // 自动获取键盘焦点
      }.span({ xs: 2, sm: 2, md: 2 })

      GridCol() {
        Button({ type: ButtonType.Circle, stateEffect: true }) { // 下一首按钮
          SymbolGlyph($r('sys.symbol.forward_end_fill'))
            .attributeModifier(new SymbolGlyphFancyModifier(23, '', ''))
            .fontColor(['#f0f0f0'])
        }
        .attributeModifier(new ButtonFancyModifier(40, 40))
        .backgroundColor('#50000000')
        .onClick(() => {
          this.onPlayNextVideoClick()
        })
      }.span({ xs: 2, sm: 2, md: 2 })

      GridCol() { // 投播
        AVCastPicker({
          normalColor: Color.White,
          onStateChange: AVSessionUtil.castOnStateChange,
          customPicker: () => this.AVCastPickerBuilderBridge()
        })
          .width(23)
          .height(23)
          .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
      }.span({ xs: 2, sm: 2, md: 2 })

      GridCol() {
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.gearshape'))
            .attributeModifier(new SymbolGlyphFancyModifier(23, '', ''))
            .fontColor(['#f0f0f0'])
        }
        .attributeModifier(new ButtonFancyModifier(40, 40))
        .backgroundColor('#50000000')
        .bindMenu(this.videoSettingBuilder,
          { backgroundBlurStyle: BlurStyle.COMPONENT_ULTRA_THIN })
      }.span({ xs: 2, sm: 2, md: 2 })

      GridCol() {
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph(this.getRepeatModeIcon())
            .attributeModifier(new SymbolGlyphFancyModifier(23, '', ''))
            .fontColor(['#f0f0f0'])
        }
        .attributeModifier(new ButtonFancyModifier(40, 40))
        .backgroundColor('#50000000')
        .onClick(() => {
          // LIST -> SINGLE -> RANDOM -> SEQUENCE -> 回到LIST
          this.repeatMode = VideoOperateUtil.getRepeatMode(this.repeatMode)
          ToolsUtil.showToast(this.getRepeatModeText())
          AVSessionUtil.updatePlaybackSessionState(this.player.playing, this.player.playTime, this.repeatMode)
        })
      }.span({ xs: 2, sm: 2, md: 2 })

      GridCol() {
        Button({ type: ButtonType.Circle, stateEffect: true }) { //选集
          SymbolGlyph($r('sys.symbol.music_note_list'))
            .attributeModifier(new SymbolGlyphFancyModifier(23, '', ''))
            .fontColor(['#f0f0f0'])
        }
        .attributeModifier(new ButtonFancyModifier(40, 40))
        .backgroundColor('#50000000')
        .onClick(() => {
          if (this.sideBarStatus) {
            this.onSideBaClose()
          } else {
            this.sideBarStatusTmp = Visibility.Visible
            this.sideBarStatus = true
          }
        })
      }.span({ xs: 2, sm: 2, md: 2 })

      GridCol() {
        Button({ type: ButtonType.Circle, stateEffect: true }) { // 倍速调整按钮
          Text(`${this.speed}x`)
            .fontSize(18)
            .fontColor($r('sys.color.white'))
            .minFontSize(8)
            .maxFontSize(18)
            .maxLines(1)
            .padding(5)
        }
        .attributeModifier(new ButtonFancyModifier(40, 40))
        .backgroundColor('#50000000')
        .bindMenu(this.playbackSpeedMenu,
          { backgroundBlurStyle: BlurStyle.COMPONENT_ULTRA_THIN })
      }.span({ xs: 2, sm: 2, md: 2 })

      GridCol() {
        Button({ type: ButtonType.Circle, stateEffect: true }) { // 屏幕旋转按钮
          SymbolGlyph($r('sys.symbol.fullscreen'))
            .attributeModifier(new SymbolGlyphFancyModifier(23, '', ''))
            .fontColor(['#f0f0f0'])
        }
        .attributeModifier(new ButtonFancyModifier(40, 40))
        .backgroundColor('#50000000')
        .onClick(async () => {
          await this.onScreenRotationOrFullScreenClick()
        })
      }.span({ xs: 2, sm: 2, md: 2 })
    }.width('95%')
  }

  /**
   * 获取当前播放模式对应的图标
   * @returns 播放模式图标
   */
  private getRepeatModeIcon(): Resource {
    switch (this.repeatMode) {
      case RepeatMode.SINGLE:
        return $r('sys.symbol.repeat_1')
      case RepeatMode.RANDOM:
        return $r('sys.symbol.shuffle')
      case RepeatMode.LIST:
        return $r('sys.symbol.repeat')
      case RepeatMode.SEQUENCE:
        return $r('sys.symbol.order_play')
      default:
        return $r('sys.symbol.order_play')
    }
  }

  /**
   * 获取当前播放模式对应的文本
   * @returns 播放模式文本
   */
  private getRepeatModeText(): string {
    switch (this.repeatMode) {
      case RepeatMode.SINGLE:
        return '单曲循环'
      case RepeatMode.RANDOM:
        return '随机播放'
      case RepeatMode.LIST:
        return '列表循环'
      case RepeatMode.SEQUENCE:
        return '顺序播放'
      default:
        return '列表循环'
    }
  }
}