@CustomDialog
export struct NumberInputDialog {
  confirm?: (name: number) => void
  controller?: CustomDialogController
  name: string | undefined = undefined
  title: string = ''
  input: number = 0
  placeholderColor: string = ''

  build() {
    Column({ space: 8 }) {
      Text(this.title)
        .fontSize(20)
        .fontColor($r('app.color.text_color'))
        .fontWeight(FontWeight.Bold)
        .margin({ top: 0, bottom: 5 })

      Row() {
        TextInput({ placeholder: this.placeholderColor })
          .keyboardAppearance(KeyboardAppearance.IMMERSIVE)
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
          .onChange((input: string) => this.input = parseInt(input))
          .inputFilter('^[-+]?\\d+$')
          .type(InputType.Number)
          .enableAutoFill(true)
          .id('input')
          .height(36)
          .borderRadius(16)
          .layoutWeight(1)
          .onAppear(() => {
            focusControl.requestFocus('input')
          })
          .maxLength(10)
          .maxLines(1)
          .enterKeyType(EnterKeyType.Done)

        Row({ space: 6 }) {
          Button({ type: ButtonType.Normal, stateEffect: true }) {
            SymbolGlyph($r('sys.symbol.xmark'))
              .fontSize(16)
              .fontColor([$r('app.color.text_color')])
          }
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
          .backgroundColor($r('sys.color.titlebar_icon_background_color'))
          .borderRadius(16)
          .width(36)
          .height(36)
          .onClick(() => this.controller?.close())

          Button({ type: ButtonType.Normal, stateEffect: true }) {
            SymbolGlyph($r('sys.symbol.checkmark'))
              .fontSize(16)
              .fontColor([$r('app.color.text_color')])
          }
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
          .backgroundColor($r('sys.color.titlebar_icon_background_color'))
          .borderRadius(16)
          .width(36)
          .height(36)
          .onClick(() => {
            this.controller?.close()
            if (this.confirm) {
              this.confirm(this.input)
            }
          })
        }
        .margin({ left: 8 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .padding({
      top: 10,
      bottom: 10,
      left: 15,
      right: 15
    }) // 减少垂直内边距
  }
}
