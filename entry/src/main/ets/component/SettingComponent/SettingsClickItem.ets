
@ComponentV2
export struct SettingsClickItem {
  @Param symbol: Resource | undefined = undefined
  @Param message: ResourceStr = ''
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
          } else {
            Stack()
          }
          Text(this.message)
            .attributeModifier(new SettingsTitleModifier())
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
    .attributeModifier(new SettingsItemModifier())
    .height(55)
  }
}