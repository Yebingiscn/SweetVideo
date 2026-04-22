import { SymbolGlyphFancyModifier } from '../../common/AttributeModifierConfig'

@ComponentV2
export struct SettingsMenuItem {
  @Param symbol: Resource | undefined = undefined
  @Param message: ResourceStr = ''
  @Param selected: number = 0
  @Local _selected: number = 0
  @Param list: ResourceStr[] = []
  @Local private select: SelectOption[] = []
  @Event onChange: (_index: number) => void = () => {
  }

  aboutToAppear(): void {
    this._selected = this.selected
    for (let text of this.list) {
      this.select.push({ value: text })
    }
  }

  @Monitor('selected')
  onSelectedMonitor() {
    this._selected = this.selected
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
        .selected(this._selected)
        .value(this.list[this._selected])
        .selectedOptionFont({ weight: FontWeight.Medium })
        .selectedOptionFontColor($r('app.color.text_color'))
        .selectedOptionBgColor($r('app.color.main_color'))
        .selectedOptionFontColor($r('sys.color.white'))
        .menuBackgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THIN)
        .onSelect((index: number) => {
          this._selected = index
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
