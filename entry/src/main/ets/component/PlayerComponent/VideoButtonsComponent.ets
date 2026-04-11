import { ButtonFancyModifier, SymbolGlyphFancyModifier } from '../../common/AttributeModifierConfig'
import { RepeatMode } from '../../common/enum/RepeatMode'
import { AVPlayerController } from '../../controller/AVPlayerController'
import { MpvController } from '../../controller/MpvController/MpvController'
import AVSessionUtil from '../../utils/AVSessionUtil'
import ToolsUtil from '../../utils/ToolsUtil'
import VideoOperateUtil from '../../utils/VideoOperateUtil'
import { AVCastPicker } from '@kit.AVSessionKit'

@Component
export struct VideoButtonsComponent {
  @Link sideBarStatusTmp: Visibility
  @Link sideBarStatus: boolean
  @BuilderParam AVCastPickerBuilderBridge: () => void
  @BuilderParam videoSettingBuilder: () => void
  @BuilderParam playbackSpeedMenu: () => void
  @Consume('player') player: AVPlayerController | MpvController
  onScreenRotationOrFullScreenClick = async () => {
  }
  onTogglePlaybackClick = () => {
  }
  onPlayNextVideoClick = () => {
  }
  onSideBaClose = () => {
  }
  onChangeRepeatMode = (_repeatMode: RepeatMode) => {
  }

  @Styles
  circleButton() {
    .attributeModifier(new ButtonFancyModifier(40, 40))
    .backgroundColor('#50000000')
    .backgroundBlurStyle(BlurStyle.BACKGROUND_THIN)
  }

  build() {
    Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceEvenly }) {
      // 播放按钮
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph(this.player.playing ? $r('sys.symbol.pause_fill') : $r('sys.symbol.play_fill'))
          .attributeModifier(new SymbolGlyphFancyModifier(23, '', ''))
          .fontColor(['#f0f0f0'])
          .opacity(0.8)
      }
      .circleButton()
      .onClick(() => {
        ToolsUtil.startVibration()
        this.onTogglePlaybackClick()
      })
      .defaultFocus(true)

      // 下一首按钮
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.forward_end_fill'))
          .attributeModifier(new SymbolGlyphFancyModifier(23, '', ''))
          .fontColor(['#f0f0f0'])
          .opacity(0.8)
      }
      .circleButton()
      .onClick(() => {
        this.onPlayNextVideoClick()
      })

      // 投播按钮
      AVCastPicker({
        normalColor: Color.White,
        onStateChange: AVSessionUtil.castOnStateChange,
        customPicker: () => this.AVCastPickerBuilderBridge()
      })
        .width(40)
        .height(40)
        .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })

      // 设置按钮
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.gearshape'))
          .attributeModifier(new SymbolGlyphFancyModifier(23, '', ''))
          .fontColor(['#f0f0f0'])
          .opacity(0.8)
      }
      .circleButton()
      .bindMenu(this.videoSettingBuilder,
        { backgroundBlurStyle: BlurStyle.COMPONENT_ULTRA_THIN })

      // 循环模式按钮
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph(this.getRepeatModeIcon())
          .attributeModifier(new SymbolGlyphFancyModifier(23, '', ''))
          .fontColor(['#f0f0f0'])
          .opacity(0.8)
      }
      .circleButton()
      .onClick(() => {
        const repeatMode = VideoOperateUtil.getRepeatMode(this.player.repeatMode)
        ToolsUtil.showToast(this.getRepeatModeText(repeatMode))
        AVSessionUtil.updatePlaybackSessionState(this.player.playing, this.player.playTime, this.player.repeatMode)
        this.onChangeRepeatMode(repeatMode)
      })

      // 选集按钮
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.music_note_list'))
          .attributeModifier(new SymbolGlyphFancyModifier(23, '', ''))
          .fontColor(['#f0f0f0'])
          .opacity(0.8)
      }
      .circleButton()
      .onClick(() => {
        if (this.sideBarStatus) {
          this.onSideBaClose()
        } else {
          this.sideBarStatusTmp = Visibility.Visible
          this.sideBarStatus = true
        }
      })

      // 倍速调整按钮
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        Text(`${this.player.speed}x`)
          .fontSize(18)
          .fontColor($r('sys.color.white'))
          .maxLines(1)
          .padding(5)
          .opacity(0.8)
      }
      .circleButton()
      .bindMenu(this.playbackSpeedMenu,
        { backgroundBlurStyle: BlurStyle.COMPONENT_ULTRA_THIN })

      // 屏幕旋转按钮
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.fullscreen'))
          .attributeModifier(new SymbolGlyphFancyModifier(23, '', ''))
          .fontColor(['#f0f0f0'])
          .opacity(0.8)
      }
      .circleButton()
      .onClick(async () => {
        await this.onScreenRotationOrFullScreenClick()
      })
    }
    .width('95%')
  }

  /**
   * 获取当前播放模式对应的图标
   * @returns 播放模式图标
   */
  private getRepeatModeIcon(): Resource {
    switch (this.player.repeatMode) {
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
  private getRepeatModeText(repeatMode: RepeatMode): string {
    switch (repeatMode) {
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