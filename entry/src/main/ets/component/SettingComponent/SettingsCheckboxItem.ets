import { SymbolGlyphFancyModifier } from '../../common/AttributeModifierConfig'
import {
  ItemRestriction, SegmentButton, SegmentButtonOptions, SegmentButtonTextItem
} from '@kit.ArkUI'

@Component
export struct SettingsCheckboxItem {
  @Prop symbol: Resource | undefined = undefined
  @Prop message: ResourceStr = ''
  @Prop @Watch('onTipsChange') tips: ResourceStr[]
  @State tabOptions: SegmentButtonOptions = this.createTabOptions()
  @State @Watch('onSegmentButtonChange') tabSelectedIndexes: number[] = [1]

  onSegmentButtonChange() {
    this.onButtonClick(Number(this.tabSelectedIndexes.toString()))
  }

  onButtonClick = (_tabSelectedIndexes: number) => {
  }

  build() {
    Row() {
      Column() {
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
        }.height('auto').width('100%').margin({ bottom: 10 })

        SegmentButton({
          options: this.tabOptions,
          selectedIndexes: $tabSelectedIndexes,
        })
      }.height('100%').width('100%')
    }
    .align(Alignment.Center)
    .backgroundColor($r('app.color.start_window_background_blur'))
    .height(80)
    .borderRadius(16)
    .padding({
      right: 15,
      left: 15,
      top: 10,
      bottom: 10
    })
    .margin({ top: 5, bottom: 5 })
  }

  onTipsChange() {
    this.tabOptions = this.createTabOptions()
  }

  private createTabOptions(): SegmentButtonOptions {
    const buttonItems: SegmentButtonTextItem[] = this.tips.map((tip: ResourceStr) => {
      const item: SegmentButtonTextItem = { text: tip }
      return item
    })
    return SegmentButtonOptions.tab({
      buttons: buttonItems as ItemRestriction<SegmentButtonTextItem>,
      backgroundBlurStyle: BlurStyle.BACKGROUND_THICK,
      selectedBackgroundColor: $r('app.color.main_color'),
      selectedFontColor: $r('sys.color.white')
    });
  }
}