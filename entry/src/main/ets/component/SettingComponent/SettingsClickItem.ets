import {
  SettingsItemModifier,
  SettingsTitleModifier,
  SymbolGlyphFancyModifier
} from '../../common/AttributeModifierConfig'

@ComponentV2
export struct SettingsClickItem {
  @Param symbol: Resource | undefined = undefined
  @Param message: ResourceStr = ''
  @Param tag: ResourceStr | undefined = undefined
  @Param showArrow: boolean = true
  @Event onPress: () => void = () => {
  }
  @Event onLongPress: () => void = () => {
  }

  build() {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Flex({ justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Center }) {
        Row({ space: 10 }) {
          if (this.symbol) {
            SymbolGlyph(this.symbol)
              .attributeModifier(new SymbolGlyphFancyModifier(22, '', ''))
              .visibility(this.symbol ? Visibility.Visible : Visibility.None)
          }
          Text(this.message)
            .attributeModifier(new SettingsTitleModifier())
            .constraintSize({ maxWidth: '85%' })
            .textOverflow({ overflow: TextOverflow.MARQUEE })
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
    .attributeModifier(new SettingsItemModifier())
    .height(55)
  }
}