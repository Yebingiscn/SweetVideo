import { SearchShadowModifier } from "../../common/AttributeModifierConfig"

@ComponentV2
export struct SearchComponent {
  @Param searchValue: string = ''
  @Event onSearchValueChange: (value: string) => void = () => {}
  @Param controller: SearchController | undefined = undefined
  @Event onChange: () => void = () => {
  }
  @Event onSubmit: (_value: string) => void = () => {
  }
  @Event onEditChange: (_isEditing: boolean) => void = () => {
  }
  @Event onSearchFocus: () => void = () => {
  }

  build() {
    Search({
      controller: this.controller,
      placeholder: $r('app.string.search_placeholder'),
      value: this.searchValue
    })
      .layoutWeight(1)
      .height(40)
      .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
      .animation({ duration: 300, curve: Curve.Ease })
      .attributeModifier(new SearchShadowModifier())
      .keyboardAppearance(KeyboardAppearance.IMMERSIVE)// 设置搜索框沉浸模式
      .onChange((value: string) => {
        this.onSearchValueChange(value)
        this.onChange()
      })
      .onSubmit((value: string) => {
        this.onSubmit(value)
      })
      .onEditChange((isEditing: boolean) => {
        this.onEditChange(isEditing)
      })
      .onFocus(() => {
        this.onSearchFocus()
      })
  }
}
