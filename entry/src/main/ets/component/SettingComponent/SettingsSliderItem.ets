import { SymbolGlyphFancyModifier } from '../../common/AttributeModifierConfig'
import TimeUtil from '../../utils/TimeUtil'

@ComponentV2
export struct SettingsSliderItem {
  @Param symbol: Resource | undefined = undefined
  @Param message: ResourceStr = ''
  @Param selected: number = 0
  @Local _selected: number = 0
  @Param textSliderMode: boolean = false
  @Event onChangeComplete: (_value: number) => void = () => {
  }

  aboutToAppear(): void {
    this._selected = this.selected
  }

  @Monitor('selected')
  onSelectedMonitor() {
    this._selected = this.selected
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
        value: this._selected,
        min: 0,
        max: 300,
        style: SliderStyle.InSet
      })
        .onChange((value) => {
          this._selected = value
        })
        .onTouch((event) => {
          if (event.type == TouchType.Up) {
            this.onChangeComplete(this._selected)
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
      const timeText = this._selected === 0 ? '关闭' : TimeUtil.convertSSToMMSS(this._selected);
      return `${this.message}：${timeText}`;
    }
    return this.message;
  }
}
