import { SymbolGlyphFancyModifier } from '../../utils/AttributeModifierUtil';
import TimeUtil from '../../utils/TimeUtil';
import ToolsUtil from '../../utils/ToolsUtil';

@Component
export struct SettingSliderItem {
  @State symbol: Resource | undefined = undefined
  @State message: ResourceStr = ''
  @Prop selected: number = 0
  onChangeComplete = (_value: number) => {

  }

  build() {
    Flex({ justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Center }) {
      Row({ space: 10 }) {
        SymbolGlyph(this.symbol)
          .attributeModifier(new SymbolGlyphFancyModifier(22, '', ''))
        Text(this.message + ':')
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.MARQUEE })
        Text(this.selected === 0 ? '不跳过' : TimeUtil.convertSSToMMSS(this.selected))
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .width('100%') // 宽度充满父容器
      }
      .width('100%')
      .margin({ bottom: 10 }) // 与下部分间距

      Slider({
        value: this.selected,
        min: 0,
        max: 300,
        style: SliderStyle.InSet
      }).onChange((value) => {
        this.selected = value
        ToolsUtil.startVibration()
      })
        .onTouch((event) => {
          if (event.type == TouchType.Up) {
            this.onChangeComplete(this.selected)
          }
        })
        .selectedColor($r('app.color.main_color'))
    }
    .align(Alignment.Center)
    .backgroundColor($r('app.color.start_window_background_blur'))
    .height(65)
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