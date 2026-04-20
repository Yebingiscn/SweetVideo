import { SymbolGlyphFancyModifier } from '../../common/AttributeModifierConfig'

class BrightnessValue {
  screenBrightness: number = 100
  playAreaHeight: number = 0
}

@Builder
export function BrightnessSwipingBuilder(brightnessValue: BrightnessValue) {
  Row() {
    SymbolGlyph($r('sys.symbol.sun_max'))
      .attributeModifier(new SymbolGlyphFancyModifier(23, '', ''))
      .fontColor(['#f0f0f0'])
      .rotate({ angle: brightnessValue.screenBrightness * 360 })
      .animation({ duration: 300, curve: Curve.Smooth })
    Slider({
      value: brightnessValue.screenBrightness,
      min: 0,
      max: 1,
      step: 0.1,
      style: SliderStyle.NONE,
      direction: Axis.Horizontal,
      reverse: false
    })
      .trackBorderRadius(16)
      .selectedColor($r('app.color.main_color'))
      .enableHapticFeedback(true)
      .width(160)
      .height(40)
      .trackThickness(40)
      .selectedBorderRadius(16)
      .padding({ left: 5 })
  }
  .offset({
    x: 0,
    y: -brightnessValue.playAreaHeight / 2.5
  })
  .borderRadius(16)
  .backgroundColor('#30000000')
  .backdropBlur(100)
  .padding(5)
}