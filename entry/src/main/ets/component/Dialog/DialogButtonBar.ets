@Builder
export function DialogButtonBar(onCancel: () => void, onConfirm: () => void) {
  Row({ space: 20 }) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row({ space: 5 }) {
        SymbolGlyph($r('sys.symbol.xmark')).fontSize(18).fontColor([$r('app.color.text_color')])
        Text($r('app.string.cancel'))
          .fontSize(18)
          .fontColor($r('app.color.text_color'))
          .fontWeight(FontWeight.Medium)
      }.alignItems(VerticalAlign.Center).padding({ left: 12, right: 12 })
    }
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
    .backgroundColor($r('sys.color.button_background_color_transparent'))
    .borderRadius(16)
    .height(40)
    .onClick(() => onCancel())

    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row({ space: 5 }) {
        SymbolGlyph($r('sys.symbol.checkmark')).fontSize(18).fontColor([$r('app.color.text_color')])
        Text($r('app.string.sure')).fontSize(18).fontColor($r('app.color.text_color')).fontWeight(FontWeight.Medium)
      }.alignItems(VerticalAlign.Center).padding({ left: 12, right: 12 })
    }
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
    .backgroundColor($r('sys.color.button_background_color_transparent'))
    .borderRadius(16)
    .height(40)
    .onClick(() => onConfirm())
  }
  .width('100%')
  .justifyContent(FlexAlign.SpaceEvenly)
  .margin({ bottom: 10 })
}
