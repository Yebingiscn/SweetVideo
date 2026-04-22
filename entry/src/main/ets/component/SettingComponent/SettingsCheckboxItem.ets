import { SymbolGlyphFancyModifier } from '../../common/AttributeModifierConfig'

@ComponentV2
export struct SettingsCheckboxItem {
  @Param symbol: Resource | undefined = undefined
  @Param message: ResourceStr = ''
  @Param tips: ResourceStr[] = []
  @Param tabSelectedIndex: number = 0
  @Local _tabSelectedIndex: number = 0

  @Event onButtonClick: (_tabSelectedIndex: number) => void = () => {}

  aboutToAppear(): void {
    this._tabSelectedIndex = this.tabSelectedIndex
  }

  @Monitor('tabSelectedIndex')
  onTabSelectedIndexMonitor() {
    this._tabSelectedIndex = this.tabSelectedIndex
  }

  build() {
    Column({ space: 10 }) {
      // 标题行
      Row({ space: 10 }) {
        SymbolGlyph(this.symbol)
          .attributeModifier(new SymbolGlyphFancyModifier(22, '', ''))
          .symbolEffect(new ReplaceSymbolEffect(EffectScope.WHOLE))
        Text(this.message)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.MARQUEE })
          .layoutWeight(1)
      }
      .width('100%')

      Row({ space: 8 }) {
        ForEach(this.tips, (tip: ResourceStr, index: number) => {
          Button(tip)
            .fontSize(14)
            .fontWeight(this._tabSelectedIndex === index ? FontWeight.Medium : FontWeight.Regular)
            .fontColor(this._tabSelectedIndex === index ? $r('sys.color.white') : $r('app.color.text_color'))
            .backgroundColor(this._tabSelectedIndex === index ? $r('app.color.main_color') :
              $r('app.color.start_window_background'))
            .borderRadius(12)
            .height(32)
            .layoutWeight(1)
            .onClick(() => {
              this._tabSelectedIndex = index
              this.onButtonClick(index)
            })
        }, (tip: ResourceStr, index: number) => index.toString())
      }
      .width('100%')
    }
    .width('100%')
    .height(100)
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('app.color.start_window_background_blur'))
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
