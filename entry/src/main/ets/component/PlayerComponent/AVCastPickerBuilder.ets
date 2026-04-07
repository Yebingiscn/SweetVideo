import { ButtonFancyModifier, SymbolGlyphFancyModifier } from '../../common/AttributeModifierConfig'
import { Setting } from '../../utils/ObservedUtil'
import ToolsUtil from '../../utils/ToolsUtil'

@Builder
export function AVCastPickerBuilder(): void {
  Button({ type: ButtonType.Circle, stateEffect: true }) {
    SymbolGlyph($r('sys.symbol.dot_radiowaves_left_and_right'))
      .attributeModifier(new SymbolGlyphFancyModifier(23, '', ''))
      .fontColor(['#f0f0f0'])
      .opacity(0.8)
  }
  .attributeModifier(new ButtonFancyModifier(40, 40))
  .backgroundColor('#50000000')
  .backgroundBlurStyle(BlurStyle.BACKGROUND_THIN)
  .onClick(() => {
    if (!Setting.allowBackgroundPlay) {
      ToolsUtil.showToast('需要在设置中允许后台播放才能进行投播')
      return
    }
  })
}