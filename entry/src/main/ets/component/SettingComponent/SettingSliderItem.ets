import { SymbolGlyphFancyModifier } from '../../common/AttributeModifierConfig'
import TimeUtil from '../../utils/TimeUtil'

@Component
export struct SettingSliderItem {
  @State symbol: Resource | undefined = undefined
  @State message: ResourceStr = ''
  @Prop selected: number = 0
  @State textSliderMode: boolean = false
  onChangeComplete = (_value: number) => {
  }

  build() {
    Flex({ justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Center }) {
      Row({ space: 12 }) {
        SymbolGlyph(this.symbol)
          .attributeModifier(new SymbolGlyphFancyModifier(22, '', ''))
        Text(this.getDisplayText())
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.MARQUEE })
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)

      Slider({
        value: this.selected,
        min: 0,
        max: 300,
        style: SliderStyle.InSet
      })
        .onChange((value) => {
          this.selected = value
        })
        .onTouch((event) => {
          if (event.type == TouchType.Up) {
            this.onChangeComplete(this.selected)
          }
        })
        .selectedColor($r('app.color.main_color'))
        .width('100%')
        .enableHapticFeedback(true)
    }
    .align(Alignment.Center)
    .backgroundColor($r('app.color.start_window_background_blur'))
    .height(65)
    .borderRadius(16)
    .padding({
      right: 10,
      left: 15,
      top: 10,
      bottom: 10
    })
    .margin({ top: 5, bottom: 5 })
  }

  private getDisplayText(): ResourceStr {
    if (this.textSliderMode) {
      const timeText = this.selected === 0 ? '关闭' : TimeUtil.convertSSToMMSS(this.selected);
      return `${this.message}：${timeText}`;
    }
    return this.message;
  }
}