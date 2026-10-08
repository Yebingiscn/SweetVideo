import { ButtonFancyModifier, SymbolGlyphFancyModifier } from '../../common/AttributeModifierConfig'

@Builder
export function AVCastPickerBuilder(): void {
  Button({ type: ButtonType.Circle, stateEffect: false }) {
    SymbolGlyph($r('sys.symbol.dot_radiowaves_left_and_right'))
      .attributeModifier(new SymbolGlyphFancyModifier(23, '', ''))
      .fontColor(['#f0f0f0'])
      .opacity(0.8)
  }
  .attributeModifier(new ButtonFancyModifier(40, 40))
  .backgroundColor(Color.Transparent)
}
