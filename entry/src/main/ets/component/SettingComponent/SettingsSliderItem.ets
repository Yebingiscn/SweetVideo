import { SettingsTitleModifier, SymbolGlyphFancyModifier } from '../../common/AttributeModifierConfig'
import TimeUtil from '../../utils/TimeUtil'

@ComponentV2
export struct SettingsSliderItem {
  @Param symbol: Resource | undefined = undefined
  @Param message: ResourceStr = ''
  @Param tag: ResourceStr | undefined = undefined
  @Param selected: number = 0
  @Local _selected: number = 0
  @Param textSliderMode: boolean = false
  @Param min: number = 0
  @Param max: number = 300
  @Param zeroText: ResourceStr = '关闭'
  @Param valueSuffix: ResourceStr = ''
  @Event onChangeComplete: (_value: number) => void = () => {
  }
  @Event onChange: (_value: number) => void = () => {
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
          .attributeModifier(new SettingsTitleModifier())
          .constraintSize({ maxWidth: 160 })
        if (this.tag) {
          Text(this.tag)
            .fontSize(12)
            .fontColor(Color.White)
            .backgroundColor($r('app.color.main_color'))
            .borderRadius(6)
            .padding({
              left: 4,
              right: 4,
              top: 1,
              bottom: 1
            })
        }
      }

      Slider({
        value: this._selected,
        min: this.min,
        max: this.max,
        style: SliderStyle.InSet
      })
        .onChange((value) => {
          this._selected = value
          this.onChange(value)
        })
        .onTouch((event) => {
          if (event.type == TouchType.Up) {
            this.onChangeComplete(this._selected)
          }
        })
        .selectedColor($r('app.color.main_color'))
        .layoutWeight(1)
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
      const timeText = this._selected === 0 ? this.zeroText : TimeUtil.convertSSToMMSS(this._selected);
      return `${this.message}：${timeText}`;
    }
    if (typeof this.valueSuffix === 'string' && this.valueSuffix.length > 0) {
      const valueText = this._selected === 0 ? this.zeroText : `${this._selected}${this.valueSuffix}`;
      return `${this.message}：${valueText}`;
    }
    return this.message;
  }
}
