import { SymbolGlyphFancyModifier } from '../../common/AttributeModifierConfig'

@Component
export struct SettingsToggleItem {
  @State symbol: Resource | undefined = undefined
  @State symbol1: Resource | undefined = undefined
  @State message: ResourceStr = ''
  @State enable: boolean = false
  onChange = (_checked: boolean) => {
  }

  build() {
    Row() {
      Flex({ justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Center }) {
        Row({ space: 10 }) {
          SymbolGlyph(this.enable && this.symbol1 ? this.symbol1 : this.symbol)
            .attributeModifier(new SymbolGlyphFancyModifier(22, '', ''))
            .symbolEffect(new ReplaceSymbolEffect(EffectScope.WHOLE), Number(this.enable))
          Text(this.message)
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.MARQUEE })
            .layoutWeight(1)
        }.layoutWeight(1)

        Toggle({ type: ToggleType.Switch, isOn: this.enable })
          .onChange((checked: boolean) => {
            this.enable = checked
            this.onChange(checked)
          })
          .selectedColor($r('app.color.main_color'))
          .width(45)
          .height(27)
      }.align(Alignment.Center)

    }
    .backgroundColor($r('app.color.start_window_background_blur'))
    .height(55)
    .borderRadius(16)
    .padding({
      right: 15,
      left: 15,
      top: 10,
      bottom: 10
    })
    .margin({ top: 5, bottom: 5 })
  }
}