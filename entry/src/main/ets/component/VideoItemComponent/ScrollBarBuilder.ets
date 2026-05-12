import { ButtonFancyModifier, SymbolGlyphFancyModifier } from '../../common/AttributeModifierConfig'
import { SafeHeight, Setting } from '../../utils/ObservedUtil'

export class ScrollBarBuilderValue {
  videoListController: Scroller | null = null
  fileFolderLength: number = 0
}

@Builder
export function ScrollBarBuilder(scrollBarBuilderValue: ScrollBarBuilderValue) {
  ScrollBar({
    scroller: scrollBarBuilderValue.videoListController,
    direction: ScrollBarDirection.Vertical,
    state: BarState.Auto
  }) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      SymbolGlyph($r('sys.symbol.line_2_horizontal'))
        .attributeModifier(new SymbolGlyphFancyModifier(20, '', ''))
    }
    .attributeModifier(new ButtonFancyModifier(30, 30))
    .borderRadius(8)
    .backgroundEffect({ radius: 100 })
    .useEffect(true, EffectType.WINDOW_EFFECT)
  }
  .margin({
    top: SafeHeight.topSafeHeight +
      (Setting.showToast && scrollBarBuilderValue.fileFolderLength > 1 ? 90 : 65), bottom: SafeHeight.bottomSafeHeight
  })
  .width(30)
}