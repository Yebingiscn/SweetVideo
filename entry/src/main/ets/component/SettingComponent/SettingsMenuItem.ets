import { SymbolGlyphFancyModifier } from '../../utils/AttributeModifierUtil'

@Component
export struct SettingsMenuItem {
  @State symbol: Resource | undefined = undefined
  @State message: ResourceStr = ''
  @Prop selected: number = 0
  @State list: string[] = []
  @State private select: SelectOption[] = []
  onChange = (_index: number) => {
  }

  aboutToAppear(): void {
    for (let text of this.list) {
      this.select.push({ value: text })
    }
  }

  build() {
    Flex({ justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Center }) {
      Row({ space: 10 }) {
        SymbolGlyph(this.symbol)
          .attributeModifier(new SymbolGlyphFancyModifier(22, '', ''))
        Text(this.message)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.MARQUEE })
          .layoutWeight(1)
      }
      .layoutWeight(1)

      Select(this.select)
        .selected(this.selected)
        .value(this.list[this.selected])
        .selectedOptionFont({ weight: FontWeight.Medium })
        .selectedOptionFontColor($r('app.color.text_color'))
        .selectedOptionBgColor($r('app.color.main_color'))
        .menuBackgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THIN)
        .onSelect((index: number) => {
          this.selected = index
          this.onChange(index)
        })
        .divider(null)
    }
    .align(Alignment.Center)
    .backgroundColor($r('app.color.start_window_background_blur'))
    .height(65)
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