import { ShadowModifier } from '../utils/AttributeModifierUtil';

@Component
export struct SearchComponent {
  @Link searchValue: string;
  controller: SearchController | undefined = undefined;
  @Prop placeholder: ResourceStr;
  onChange = () => {
  }
  onSubmit = (value: string) => {
    console.log(value)
  }
  onEditChange = ((isEditing: boolean) => {
    console.log(isEditing + '')
  })

  build() {
    Search({
      controller: this.controller,
      placeholder: this.placeholder,
      value: $$this.searchValue
    })
      .layoutWeight(1)
      .height(40)
      .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
      .animation({ duration: 300, curve: Curve.Ease })
      .attributeModifier(new ShadowModifier())
      .onChange(() => {
        this.onChange()
      })
      .onSubmit((value: string) => {
        this.onSubmit(value)
      })
      .onEditChange((isEditing: boolean) => {
        this.onEditChange(isEditing)
      })
      .zIndex(1)
  }
}