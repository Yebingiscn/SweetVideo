@Builder
export function DialogButtonBar(onCancel: () => void, onConfirm: () => void) {
  Row({ space: 12 }) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Text($r('app.string.cancel'))
        .fontSize(16)
        .fontColor($r('app.color.text_color'))
        .fontWeight(FontWeight.Medium)
    }
    .backgroundColor($r('sys.color.button_background_color_transparent'))
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
    .borderRadius(16)
    .height(44)
    .layoutWeight(1)
    .onClick(() => onCancel())

    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Text($r('app.string.sure'))
        .fontSize(16)
        .fontColor(Color.White)
        .fontWeight(FontWeight.Medium)
    }
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
    .backgroundColor($r('app.color.main_color'))
    .borderRadius(16)
    .height(44)
    .layoutWeight(1)
    .onClick(() => onConfirm())
  }
  .width('100%')
  .justifyContent(FlexAlign.SpaceEvenly)
}
