import { ColorMetrics, SegmentButtonV2Items } from '@kit.ArkUI'

const TAG = 'SettingsSegmentButtonItem'

@ComponentV2
export struct SettingsSegmentButtonItem {
  @Param symbol: Resource | undefined = undefined
  @Param message: ResourceStr = ''
  @Param tips: ResourceStr[] = []
  @Param @Once tabSelectedIndex: number = 0
  @Local _tabSelectedIndex: number = 0
  @Local textItems: SegmentButtonV2Items = this.createTabOptions()
  private itemSelectedBackgroundColor: ColorMetrics | undefined = undefined
  private itemSelectedFontColor: ColorMetrics | undefined = undefined
  @Event onButtonClick: (_tabSelectedIndex: number) => void = () => {
  }

  @Monitor('tabSelectedIndex')
  onIndexChange() {
    this.onButtonClick(this.tabSelectedIndex!!)
  }

  @Monitor('tips')
  onTipsChange() {
    this.textItems = this.createTabOptions()
  }

  aboutToAppear(): void {
    this.getColor()
  }

  build() {
    Column({ space: 10 }) {
      // 标题行
      Row({ space: 10 }) {
        SymbolGlyph(this.symbol)
          .attributeModifier(new SymbolGlyphFancyModifier(22, '', ''))
          .symbolEffect(new ReplaceSymbolEffect(EffectScope.WHOLE))
        Text(this.message)
          .attributeModifier(new SettingsTitleModifier())
          .layoutWeight(1)
      }

      CapsuleSegmentButtonV2({
        items: this.textItems,
        selectedIndex: this.tabSelectedIndex!!,
        buttonBackgroundBlurStyle: BlurStyle.BACKGROUND_THICK,
        itemSelectedFontColor: this.itemSelectedFontColor,
        itemSelectedBackgroundColor: this.itemSelectedBackgroundColor
      })
    }
    .width('100%')
    .height(100)
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
    .attributeModifier(new SettingsItemModifier())
  }

  private getColor() {
    try {
      this.itemSelectedBackgroundColor = ColorMetrics.resourceColor($r('app.color.main_color'))
      this.itemSelectedFontColor = ColorMetrics.resourceColor($r('sys.color.white'))
    } catch (error) {
      salmonLogger.addLog(TAG, 'getColor error', true)
    }
  }

  private createTabOptions(): SegmentButtonV2Items {
    const safeTips = this.tips ?? []
    const buttonItems: SegmentButtonV2ItemOptions[] = safeTips.map((tip: ResourceStr) =>
    ({ text: tip } as SegmentButtonV2ItemOptions)
    )
    return new SegmentButtonV2Items(buttonItems)
  }
}
