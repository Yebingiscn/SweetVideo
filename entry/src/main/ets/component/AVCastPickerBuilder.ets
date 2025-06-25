import { ButtonFancyModifier, SymbolGlyphFancyModifier } from '../utils/AttributeModifierUtil'

@Builder
export function AVCastPickerBuilder(): void {
  Button({ type: ButtonType.Circle, stateEffect: true }) {
    SymbolGlyph($r('sys.symbol.dot_radiowaves_left_and_right'))
      .attributeModifier(new SymbolGlyphFancyModifier(23, '', ''))
      .fontColor(['#f0f0f0'])
  }
  .attributeModifier(new ButtonFancyModifier(40, 40))
  .backgroundColor('#50000000')
}