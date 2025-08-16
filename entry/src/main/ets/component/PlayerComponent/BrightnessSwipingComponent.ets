import { SymbolGlyphFancyModifier } from '../../utils/AttributeModifierUtil'

@Component
export struct BrightnessSwipingComponent {
  @Prop screenBrightness: number

  build() {
    Stack() { //亮度提示
      Column() {
        SymbolGlyph($r('sys.symbol.sun_max'))
          .attributeModifier(new SymbolGlyphFancyModifier(23, '', ''))
          .fontColor(['#f0f0f0'])
        Slider({
          value: this.screenBrightness,
          min: 0,
          max: 1,
          step: 0.1,
          style: SliderStyle.NONE,
          direction: Axis.Horizontal,
          reverse: false
        })
          .width(60)
          .height(30)
          .selectedColor($r('app.color.main_color'))
          .trackColor(Color.Black)
          .trackThickness(40)
      }
    }
    .padding({
      left: 25,
      right: 25,
      top: 10,
      bottom: 10
    })
    .borderRadius(1000)
    .backgroundColor('#30000000')
    .backdropBlur(100)
    .animation({ duration: 300, curve: Curve.Smooth })
  }
}