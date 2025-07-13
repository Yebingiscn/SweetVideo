import { ButtonFancyModifier, SymbolGlyphFancyModifier } from '../../utils/AttributeModifierUtil'
import VideoOperateUtil from '../../utils/VideoOperateUtil'

@Component
export struct BrightnessButtonComponent {
  @Prop screenBrightness: number
  onChange = (value: number) => {
    console.log('brightness change: ' + value)
  }

  build() {
    Flex({ direction: FlexDirection.Column, justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center }) {
      Stack() {
        Column() {
          Button({ type: ButtonType.Circle, stateEffect: true }) {
            SymbolGlyph($r('sys.symbol.sun_max'))
              .attributeModifier(new SymbolGlyphFancyModifier(23, '', ''))
              .fontColor(['#f0f0f0'])
          }
          .attributeModifier(new ButtonFancyModifier(80, 40))
          .backgroundColor('#50000000')
          .backdropBlur(150)
          .onClick(() => {
            VideoOperateUtil.setBrightness(-1)
          })

          Slider({
            value: this.screenBrightness,
            min: 0,
            max: 1,
            step: 0.1,
            style: SliderStyle.NONE,
            direction: Axis.Vertical,
            reverse: true
          })
            .width(40)
            .height(160)
            .selectedColor('#e0e0e0')
            .trackColor(Color.Black)
            .trackThickness(40)
            .onChange((value) => {
              this.onChange(value)
              VideoOperateUtil.setBrightness(value)
            })
        }
      }.width(40)
    }
  }
}