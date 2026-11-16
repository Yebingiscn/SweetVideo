import { ButtonFancyModifier, SymbolGlyphFancyModifier } from '../../common/AttributeModifierConfig'
import type { PlayerControllerInterface } from '../../controller/PlayerControllerFactory'
import AVSessionUtil from '../../utils/AVSessionUtil'
import ToolsUtil from '../../utils/ToolsUtil'
import { AVCastPicker, AVCastPickerState } from '@kit.AVSessionKit'
import { HiCar } from '../../utils/HiCarUtil'
import HiCarLayout from '../../utils/HiCarLayout'
import { MaterialCapability } from '../../common/MaterialCapability'
import { uiMaterial } from '@kit.ArkUI'

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
  @Require @Param player: PlayerControllerInterface
  @Event onScreenRotationOrFullScreenClick: () => Promise<void> = async () => {
  }
  @Event onControlsOverlay: (name: string, visible: boolean) => void = () => {
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
  @Event onPlayPreviousVideoClick: () => void = () => {
  }
  @Event onPlayNextVideoClick: () => void = () => {
  }
  @Event onSideBaClose: () => void = () => {
  }

  @Styles
  iconButton() {
    .attributeModifier(new ButtonFancyModifier(40, 40))
    .backgroundColor(Color.Transparent)
    .margin({ left: HiCar.enabled ? 8 : 0, right: HiCar.enabled ? 8 : 0, bottom: HiCar.enabled ? 4 : 0 })
    .flexShrink(0)
  }

  build() {
    Flex({ wrap: FlexWrap.Wrap, justifyContent: HiCar.enabled ? FlexAlign.Start : FlexAlign.SpaceEvenly }) {
      // 上一首按钮
        Button({ type: ButtonType.Circle, stateEffect: false }) {
          VideoControlIcon({ icon: $r('sys.symbol.backward_end_fill') })
        }
        .iconButton()
        .accessibilityText($r('app.string.hicar_previous'))
        .onClick(() => {
          this.onPlayPreviousVideoClick()
        })
      // 播放按钮
      Button({ type: ButtonType.Circle, stateEffect: false }) {
        VideoControlIcon({ icon: this.player.playing ? $r('sys.symbol.pause_fill') : $r('sys.symbol.play_fill') })
      }
      .iconButton()
      .accessibilityText(this.player.playing ? $r('app.string.hicar_pause') : $r('app.string.hicar_play'))
      .onClick(() => {
        ToolsUtil.startVibration()
        this.onTogglePlaybackClick()
      })
      .defaultFocus(true)
      // 下一首按钮
        Button({ type: ButtonType.Circle, stateEffect: false }) {
          VideoControlIcon({ icon: $r('sys.symbol.forward_end_fill') })
        }
        .iconButton()
        .accessibilityText($r('app.string.hicar_next'))
        .onClick(() => {
          this.onPlayNextVideoClick()
        })
      // 投播按钮
        AVCastPicker({
          normalColor: Color.White,
          onStateChange: (state: AVCastPickerState) => {
            AVSessionUtil.castOnStateChange(state)
            this.onControlsOverlay('cast-picker', state === AVCastPickerState.STATE_APPEARING)
          },
          customPicker: () => this.AVCastPickerBuilderBridge()
        })
          .width(40)
          .height(40)
          .margin({ left: HiCar.enabled ? 8 : 0, right: HiCar.enabled ? 8 : 0, bottom: HiCar.enabled ? 4 : 0 })
          .flexShrink(0)
          .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
        // 设置按钮
        Button({ type: ButtonType.Circle, stateEffect: false }) {
          VideoControlIcon({ icon: $r('sys.symbol.gearshape') })
        }
        .iconButton()
        .bindMenu(this.videoSettingBuilder, {
          onWillAppear: () => this.onControlsOverlay('settings-menu', true),
          onDidDisappear: () => this.onControlsOverlay('settings-menu', false),
          systemMaterial: MaterialCapability.hdsSupported ? new uiMaterial.ImmersiveMaterial({
            style: uiMaterial.ImmersiveStyle.THICK
          }) : undefined
        })
        // 倍速调整按钮
        Button({ type: ButtonType.Circle, stateEffect: false }) {
          Text(`${this.player.speed}x`)
            .fontSize(15)
            .fontColor($r('sys.color.white'))
            .maxLines(1)
            .padding(5)
            .opacity(0.9)
            .textShadow({ color: Color.Black, type: ShadowType.BLUR, radius: 3 })
        }
        .iconButton()
        .bindMenu(this.playbackSpeedMenu,
          {
            onWillAppear: () => this.onControlsOverlay('speed-menu', true),
            onDidDisappear: () => this.onControlsOverlay('speed-menu', false),
            systemMaterial: MaterialCapability.hdsSupported ? new uiMaterial.ImmersiveMaterial({
              style: uiMaterial.ImmersiveStyle.THICK
            }) : undefined
          })
        // 选集按钮
        Button({ type: ButtonType.Circle, stateEffect: false }) {
          VideoControlIcon({ icon: $r('sys.symbol.music_note_list') })
        }
        .iconButton()
        .accessibilityText($r('app.string.hicar_playlist'))
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
        Button({ type: ButtonType.Circle, stateEffect: false }) {
          VideoControlIcon({ icon: $r('sys.symbol.fullscreen') })
        }
        .iconButton()
        .onClick(async () => {
          await this.onScreenRotationOrFullScreenClick()
        })
    }
    .width(HiCar.enabled ? HiCarLayout.buttonWidth(this.player.screenWidth - HiCar.leftInset - HiCar.rightInset) : '95%')
  }
}
