import { SymbolGlyphFancyModifier, ButtonFancyModifier } from '../../common/AttributeModifierConfig'
import { AVPlayerController } from '../../controller/AVPlayerController'
import { MpvController } from '../../controller/MpvController/MpvController'

@Component
export struct LockVideoBarComponent {
  @Consume('player') player: AVPlayerController | MpvController
  @Link isLock: boolean
  @Link showControl: boolean

  build() {
    Button({ type: ButtonType.Circle, stateEffect: true }) { //锁定播放栏
      SymbolGlyph(this.isLock ? $r('sys.symbol.lock_fill') : $r('sys.symbol.lock_open_fill'))
        .fontWeight(FontWeight.Bold)
        .attributeModifier(new SymbolGlyphFancyModifier(23, '', ''))
        .fontColor(['#f0f0f0'])
        .opacity(0.8)
    }
    .backgroundBlurStyle(BlurStyle.BACKGROUND_THIN)
    .zIndex(100)
    .attributeModifier(new ButtonFancyModifier(40, 40))
    .backgroundColor('#50000000')
    .aspectRatio(1)
    .onClick(() => {
      this.isLock = !this.isLock
      this.showControl = true
    })
    .position({ bottom: this.player.screenHeight / 2, left: this.player.screenWidth - 80 })
  }
}