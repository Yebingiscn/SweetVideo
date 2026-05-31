import {
  SymbolGlyphFancyModifier,
  SettingsTitleModifier,
  SettingsItemModifier
} from "../../common/AttributeModifierConfig"

@ComponentV2
export struct SettingsToggleItem {
  @Param symbol: Resource | undefined = undefined
  @Param symbol1: Resource | undefined = undefined
  @Param message: ResourceStr = ''
  @Param enable: boolean = false
  @Local _enable: boolean = false
  @Event onChange: (_checked: boolean) => void = () => {
  }

  aboutToAppear(): void {
    this._enable = this.enable
  }

  @Monitor('enable')
  onEnableMonitor() {
    this._enable = this.enable
  }

  build() {
    Flex({ justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Center }) {
      Row({ space: 10 }) {
        SymbolGlyph(this._enable && this.symbol1 ? this.symbol1 : this.symbol)
          .attributeModifier(new SymbolGlyphFancyModifier(22, '', ''))
          .symbolEffect(new ReplaceSymbolEffect(EffectScope.WHOLE), Number(this._enable))
        Text(this.message)
          .attributeModifier(new SettingsTitleModifier())
          .layoutWeight(1)
      }.layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn: this._enable })
        .onChange((checked: boolean) => {
          this._enable = checked
          this.onChange(checked)
        })
        .selectedColor($r('app.color.main_color'))
        .width(45)
        .height(27)
    }
    .align(Alignment.Center)
    .attributeModifier(new SettingsItemModifier())
    .height(55)
  }
}
