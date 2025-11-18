import { ButtonFancyModifier, SymbolGlyphFancyModifier } from '../../utils/AttributeModifierUtil'

@Component
export struct LockVideoBarComponent {
  @Link isLock: boolean
  @Link screenHeight: number
  @Link screenWidth: number
  @Link showControl: boolean
  @Link lockVisibility: boolean

  build() {
    if (this.lockVisibility) {
      Button({ type: ButtonType.Circle, stateEffect: true }) { //锁定播放栏
        SymbolGlyph(this.isLock ? $r('sys.symbol.lock_fill') : $r('sys.symbol.lock_open_fill'))
          .fontWeight(FontWeight.Bold)
          .attributeModifier(new SymbolGlyphFancyModifier(23, '', ''))
          .fontColor(['#f0f0f0'])
      }
      .zIndex(100)
      .attributeModifier(new ButtonFancyModifier(40, 40))
      .backgroundColor('#50000000')
      .aspectRatio(1)
      .onClick(() => {
        this.isLock = !this.isLock
        this.showControl = true
      })
      .position({ bottom: this.screenHeight / 2, left: this.screenHeight > this.screenWidth ? 30 : 50 })
    }
  }
}