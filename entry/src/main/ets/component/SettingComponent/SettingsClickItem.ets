import { SymbolGlyphFancyModifier } from '../../utils/AttributeModifierUtil'

@Component
export struct SettingsClickItem {
  @State symbol: Resource | undefined = undefined
  @State message: ResourceStr = ''
  @Prop showArrow: boolean = true
  onPress = () => {
  }
  onLongPress = () => {
  }

  build() {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Flex({ justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Center }) {
        Row({ space: 10 }) {
          if (this.symbol) {
            SymbolGlyph(this.symbol)
              .attributeModifier(new SymbolGlyphFancyModifier(22, '', ''))
              .visibility(this.symbol ? Visibility.Visible : Visibility.None)
          } else {
            Stack()
          }
          Text(this.message)
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.MARQUEE })
            .layoutWeight(1)
        }.layoutWeight(1)

        if (this.showArrow) {
          SymbolGlyph($r('sys.symbol.chevron_right'))
            .attributeModifier(new SymbolGlyphFancyModifier(22, '', ''))
            .margin(5)
        }

      }.align(Alignment.Center)

    }
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
    .onClick(() => {
      this.onPress()
    })
    .gesture(LongPressGesture().onAction(() => {
      this.onLongPress()
    }))
    .backgroundColor($r('app.color.start_window_background_blur'))
    .height(55)
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