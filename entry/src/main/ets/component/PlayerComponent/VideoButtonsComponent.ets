import { ButtonFancyModifier, SymbolGlyphFancyModifier } from '../../common/AttributeModifierConfig'
import { SweetRepeatMode } from '../../common/enum/SweetRepeatMode'
import { PlayerControllerFactory, PlayerControllerInterface } from '../../controller/PlayerControllerFactory'
import AVSessionUtil from '../../utils/AVSessionUtil'
import ToolsUtil from '../../utils/ToolsUtil'
import VideoOperateUtil from '../../utils/VideoOperateUtil'
import { AVCastPicker } from '@kit.AVSessionKit'

class VideoControlIconValue {
  icon: Resource | undefined = undefined
}

@Builder
function VideoControlIcon(videoControlIconValue: VideoControlIconValue) {
  SymbolGlyph(videoControlIconValue?.icon)
    .attributeModifier(new SymbolGlyphFancyModifier(23, '', ''))
    .fontColor(['#f0f0f0'])
    .opacity(0.8)
}

@ComponentV2
export struct VideoButtonsComponent {
  @Param sideBarStatusTmp: Visibility = Visibility.Hidden
  @Local _sideBarStatusTmp: Visibility = Visibility.Hidden
  @Param sideBarStatus: boolean = false
  @Local _sideBarStatus: boolean = false
  @BuilderParam AVCastPickerBuilderBridge: () => void
  @BuilderParam videoSettingBuilder: () => void
  @BuilderParam playbackSpeedMenu: () => void
  @Consumer('player') player: PlayerControllerInterface =
    PlayerControllerFactory.createAVPlayerController() as PlayerControllerInterface
  @Event onScreenRotationOrFullScreenClick: () => Promise<void> = async () => {
  }
  @Event onSideBarStatusTmpChange: (v: Visibility) => void = () => {
  }
  @Event onSideBarStatusChange: (v: boolean) => void = () => {
  }

  aboutToAppear(): void {
    this._sideBarStatusTmp = this.sideBarStatusTmp
    this._sideBarStatus = this.sideBarStatus
  }

  @Monitor('sideBarStatusTmp')
  onSideBarStatusTmpMonitor() {
    this._sideBarStatusTmp = this.sideBarStatusTmp
  }

  @Monitor('sideBarStatus')
  onSideBarStatusMonitor() {
    this._sideBarStatus = this.sideBarStatus
  }

  @Event onTogglePlaybackClick: () => void = () => {
  }
  @Event onPlayNextVideoClick: () => void = () => {
  }
  @Event onSideBaClose: () => void = () => {
  }
  @Event onChangeRepeatMode: (_repeatMode: SweetRepeatMode) => void = () => {
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
        VideoControlIcon({ icon: this.player.playing ? $r('sys.symbol.pause_fill') : $r('sys.symbol.play_fill') })
      }
      .circleButton()
      .onClick(() => {
        ToolsUtil.startVibration()
        this.onTogglePlaybackClick()
      })
      .defaultFocus(true)

      // 下一首按钮
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        VideoControlIcon({ icon: $r('sys.symbol.forward_end_fill') })
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
        VideoControlIcon({ icon: $r('sys.symbol.gearshape') })
      }
      .circleButton()
      .bindMenu(this.videoSettingBuilder,
        { backgroundBlurStyle: BlurStyle.COMPONENT_THIN })

      // 循环模式按钮
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        VideoControlIcon({ icon: this.getRepeatModeIcon() })
      }
      .circleButton()
      .onClick(() => {
        const repeatMode = VideoOperateUtil.getRepeatMode(this.player.repeatMode)
        ToolsUtil.showToast(this.getRepeatModeText(repeatMode))
        AVSessionUtil.updatePlaybackSessionState(this.player.playing, this.player.playTime, this.player.repeatMode)
        this.onChangeRepeatMode(repeatMode)
      })

      // 倍速调整按钮
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        Text(`${this.player.speed}x`)
          .fontSize(15)
          .fontColor($r('sys.color.white'))
          .maxLines(1)
          .padding(5)
          .opacity(0.9)
          .textShadow({ color: Color.Black, type: ShadowType.BLUR, radius: 3 })
      }
      .circleButton()
      .bindMenu(this.playbackSpeedMenu,
        { backgroundBlurStyle: BlurStyle.COMPONENT_THIN })

      // 选集按钮
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        VideoControlIcon({ icon: $r('sys.symbol.music_note_list') })
      }
      .circleButton()
      .onClick(() => {
        if (this._sideBarStatus) {
          this.onSideBaClose()
        } else {
          this._sideBarStatusTmp = Visibility.Visible
          this.onSideBarStatusTmpChange(Visibility.Visible)
          this._sideBarStatus = true
          this.onSideBarStatusChange(true)
        }
      })

      // 屏幕旋转按钮
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        VideoControlIcon({ icon: $r('sys.symbol.fullscreen') })
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

  /**
   * 获取当前播放模式对应的文本
   * @returns 播放模式文本
   */
  private getRepeatModeText(repeatMode: SweetRepeatMode): string {
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
}