import { SymbolGlyphFancyModifier } from '../../utils/AttributeModifierUtil'
import {
  ItemRestriction, SegmentButton, SegmentButtonOptions, SegmentButtonTextItem
} from '@kit.ArkUI'

@Component
export struct SettingsCheckboxItem {
  @State symbol: Resource | undefined = undefined
  @State message: ResourceStr = ''
  @Prop tips: ResourceStr[]
  @State tabOptions: SegmentButtonOptions = SegmentButtonOptions.tab({
    buttons: [{ text: this.tips[0] }, { text: this.tips[1] }, {
      text: this.tips[2]
    }] as ItemRestriction<SegmentButtonTextItem>,
    backgroundBlurStyle: BlurStyle.BACKGROUND_THICK,
    selectedBackgroundColor: $r('app.color.main_color'),
    selectedFontColor: $r('sys.color.white')
  });
  @State @Watch('onSegmentButtonChange') tabSelectedIndexes: number[] = [1];

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
}