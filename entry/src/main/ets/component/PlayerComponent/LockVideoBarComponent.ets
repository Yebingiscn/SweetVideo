import { ButtonFancyModifier, SymbolGlyphFancyModifier } from '../../common/AttributeModifierConfig'
import { PlayerControllerFactory, PlayerControllerInterface } from '../../controller/PlayerControllerFactory'
import { XAnimation } from '../../utils/AnimationUtil'

@ComponentV2
export struct LockVideoBarComponent {
  @Param buttonsOnLeft: boolean = false
  @Consumer('player') player: PlayerControllerInterface =
    PlayerControllerFactory.createAVPlayerController() as PlayerControllerInterface
  @Event onLockClick: () => void = () => {
  }
  @Event onCaptureScreen: () => void = () => {
  }

  build() {
    Column({ space: 12 }) {
      Button({ type: ButtonType.Circle, stateEffect: false }) {
        SymbolGlyph($r('sys.symbol.camera'))
          .fontSize(27)
          .fontColor(['#f0f0f0'])
          .opacity(0.8)
      }
      .attributeModifier(new ButtonFancyModifier(40, 40))
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        this.onCaptureScreen()
      })

      Button({ type: ButtonType.Circle, stateEffect: false }) {
        SymbolGlyph(this.player.isLock ? $r('sys.symbol.lock_fill') : $r('sys.symbol.lock_open_fill'))
          .fontWeight(FontWeight.Bold)
          .attributeModifier(new SymbolGlyphFancyModifier(23, '', ''))
          .fontColor(['#f0f0f0'])
          .opacity(0.8)
      }
      .attributeModifier(new ButtonFancyModifier(40, 40))
      .backgroundColor(Color.Transparent)
      .aspectRatio(1)
      .margin({ top: 20 })
      .onClick(() => {
        this.onLockClick()
      })
    }
    .position({ bottom: this.player.screenHeight / 2 - 40,
      left: this.buttonsOnLeft ? 40 : this.player.screenWidth - 80 })
    .transition(TransitionEffect.translate({ x: this.buttonsOnLeft ? -80 : 80 })
      .combine(TransitionEffect.OPACITY)
      .animation(XAnimation.getAnimationCurve()))
    .zIndex(100)
  }
}
