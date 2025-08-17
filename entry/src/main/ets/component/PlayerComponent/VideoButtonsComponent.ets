import { AVCastPicker } from '@kit.AVSessionKit'
import ToolsUtil from '../../utils/ToolsUtil'
import VideoOperateUtil from '../../utils/VideoOperateUtil'
import { KeyCode } from '@kit.InputKit'
import { ButtonFancyModifier, SymbolGlyphFancyModifier } from '../../utils/AttributeModifierUtil'

@Component
export struct VideoButtonsComponent {
  @Prop screenArco: number
  @Prop playing: boolean
  @Prop speed: number
  @BuilderParam aVCastPickerBuilderBridge: () => void
  @BuilderParam videoSettingBuilder: () => void
  @BuilderParam playbackSpeedMenu: () => void
  onScreenRotationOrFullScreenClick = async () => {
  }
  onTogglePlaybackClick = () => {
  }
  onPlayNextVideoClick = () => {
  }
  onSideBarStatusClick = () => {
  }

  build() {
    GridRow({ columns: this.screenArco > 1.4 ? 8 : 16, gutter: 5 }) {
      GridCol() {
        Button({ type: ButtonType.Circle, stateEffect: true }) { // 播放按钮
          SymbolGlyph(this.playing ? $r('sys.symbol.pause_fill') : $r('sys.symbol.play_fill'))
            .attributeModifier(new SymbolGlyphFancyModifier(23, '', ''))
            .fontColor(['#f0f0f0'])
            .symbolEffect(new ReplaceSymbolEffect(EffectScope.WHOLE), Number(this.playing))
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
          onStateChange: VideoOperateUtil.castOnStateChange,
          customPicker: () => this.aVCastPickerBuilderBridge()
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
        .bindMenu(this.videoSettingBuilder)
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
          this.onSideBarStatusClick()
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
        .bindMenu(this.playbackSpeedMenu, {
          backgroundColor: Color.Transparent,
          backgroundBlurStyle: BlurStyle.COMPONENT_ULTRA_THIN,
        })
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
}