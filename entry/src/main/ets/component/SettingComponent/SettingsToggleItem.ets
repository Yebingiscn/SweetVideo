import {
  SettingsItemModifier,
  SettingsTitleModifier,
  SymbolGlyphFancyModifier
} from '../../common/AttributeModifierConfig'
import ToolsUtil from '../../utils/ToolsUtil'

@ComponentV2
export struct SettingsToggleItem {
  @Param symbol: Resource | undefined = undefined
  @Param symbol1: Resource | undefined = undefined
  @Param message: ResourceStr = ''
  @Param tag: ResourceStr | undefined = undefined
  @Param enable: boolean = false
  @Param itemEnabled: boolean = true
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
          .textOverflow({ overflow: TextOverflow.MARQUEE })
          .constraintSize({ maxWidth: this.tag ? '70%' : '100%' })
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

      Toggle({ type: ToggleType.Switch, isOn: this._enable })
        .onChange((checked: boolean) => {
          this._enable = checked
          this.onChange(checked)
        })
        .enabled(this.itemEnabled)
        .selectedColor($r('app.color.main_color'))
        .width(45)
        .height(27)
    }
    .align(Alignment.Center)
    .attributeModifier(new SettingsItemModifier())
    .height(55)
    .onClick(() => {
      if (!this.itemEnabled) {
        ToolsUtil.showToast('这个是vip功能')
      }
    })
  }
}
