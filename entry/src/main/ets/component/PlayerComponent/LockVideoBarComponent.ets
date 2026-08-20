import { ButtonFancyModifier, SymbolGlyphFancyModifier } from '../../common/AttributeModifierConfig'
import { PlayerControllerFactory, PlayerControllerInterface } from '../../controller/PlayerControllerFactory'
import { XAnimation } from '../../utils/AnimationUtil'

@ComponentV2
export struct LockVideoBarComponent {
  @Consumer('player') player: PlayerControllerInterface =
    PlayerControllerFactory.createAVPlayerController() as PlayerControllerInterface
  @Event onLockClick: () => void = () => {
  }
  @Param lockRotation: boolean = false
  @Event onLockRotationClick: () => Promise<void> = async () => {
  }

  build() {
    Column({ space: 40 }) {
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph(this.lockRotation ? $r('sys.symbol.lock_fill') : $r('sys.symbol.rotate_left'))
          .fontWeight(FontWeight.Bold)
          .attributeModifier(new SymbolGlyphFancyModifier(23, '', ''))
          .fontColor(['#f0f0f0'])
          .opacity(0.8)
      }
      .backgroundBlurStyle(BlurStyle.BACKGROUND_THIN)
      .attributeModifier(new ButtonFancyModifier(40, 40))
      .backgroundColor('#50000000')
      .aspectRatio(1)
      .onClick(async () => {
        await this.onLockRotationClick()
      })

      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph(this.player.isLock ? $r('sys.symbol.lock_fill') : $r('sys.symbol.lock_open_fill'))
          .fontWeight(FontWeight.Bold)
          .attributeModifier(new SymbolGlyphFancyModifier(23, '', ''))
          .fontColor(['#f0f0f0'])
          .opacity(0.8)
      }
      .backgroundBlurStyle(BlurStyle.BACKGROUND_THIN)
      .attributeModifier(new ButtonFancyModifier(40, 40))
      .backgroundColor('#50000000')
      .aspectRatio(1)
      .onClick(() => {
        this.onLockClick()
      })
    }
    .zIndex(100)
    .position({ bottom: this.player.screenHeight / 2 - 40, left: this.player.screenWidth - 80 })
    .transition(TransitionEffect.translate({ x: 80 })
      .combine(TransitionEffect.OPACITY)
      .animation(XAnimation.getAnimationCurve()))
  }
}