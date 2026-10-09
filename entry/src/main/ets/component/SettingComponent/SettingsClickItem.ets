import {
  SettingsItemModifier,
  SettingsTitleModifier,
  SymbolGlyphFancyModifier
} from '../../common/AttributeModifierConfig'

export interface SettingsClickItemParams {
  symbol?: Resource
  message?: ResourceStr
  tag?: ResourceStr
  showArrow?: boolean
  onPress?: () => void
  onLongPress?: () => void
}

// Reference parameters keep dynamic labels/tags current without a component lifecycle.
@Builder
export function SettingsClickItem($$: SettingsClickItemParams) {
  Button({ type: ButtonType.Normal, stateEffect: true }) {
    Row() {
      Row({ space: 10 }) {
        if ($$.symbol) {
          SymbolGlyph($$.symbol)
            .attributeModifier(new SymbolGlyphFancyModifier(22, '', ''))
        }
        Text($$.message ?? '')
          .attributeModifier(new SettingsTitleModifier())
          .constraintSize({ maxWidth: '85%' })
          .textOverflow({ overflow: TextOverflow.MARQUEE })
        if ($$.tag) {
          Text($$.tag)
            .fontSize(12)
            .fontColor(Color.White)
            .backgroundColor($r('app.color.main_color'))
            .borderRadius(6)
            .padding({ left: 4, right: 4, top: 1, bottom: 1 })
            .flexShrink(0)
        }
      }.layoutWeight(1)

      if ($$.showArrow !== false) {
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .attributeModifier(new SymbolGlyphFancyModifier(22, '', ''))
          .margin(5)
          .flexShrink(0)
      }
    }
    .justifyContent(FlexAlign.SpaceBetween)
    .alignItems(VerticalAlign.Center)
    .width('100%')
    .align(Alignment.Center)
  }
  .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
  .onClick(() => { $$.onPress?.() })
  .gesture(LongPressGesture().onAction(() => { $$.onLongPress?.() }))
  .attributeModifier(new SettingsItemModifier())
  .height(55)
}
