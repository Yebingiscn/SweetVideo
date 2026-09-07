import { ButtonFancyModifier } from '../../common/AttributeModifierConfig'

@Builder
export function DialogButtonBar(onCancel: () => void, onConfirm: () => void) {
  Row({ space: 12 }) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Text($r('app.string.cancel'))
        .fontSize(16)
        .fontColor($r('app.color.text_color'))
        .fontWeight(FontWeight.Medium)
    }
    .attributeModifier(new ButtonFancyModifier('', 44))
    .backgroundColor($r('sys.color.button_background_color_transparent'))
    .layoutWeight(1)
    .onClick(() => onCancel())

    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Text($r('app.string.sure'))
        .fontSize(16)
        .fontColor(Color.White)
        .fontWeight(FontWeight.Medium)
    }
    .attributeModifier(new ButtonFancyModifier('', 44))
    .backgroundColor($r('app.color.main_color'))
    .layoutWeight(1)
    .onClick(() => onConfirm())
  }
  .width('100%')
  .justifyContent(FlexAlign.SpaceEvenly)
}
