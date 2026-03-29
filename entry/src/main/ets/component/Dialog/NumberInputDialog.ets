@CustomDialog
export struct NumberInputDialog {
  confirm?: (name: number) => void
  controller?: CustomDialogController
  name: string | undefined = undefined
  title: string = ''
  input: number = 0
  placeholderColor: string = ''

  build() {
    Column({ space: 8 }) { // 减小容器间距
      // 紧凑的标题
      Text(this.title)
        .fontSize(20)
        .fontColor($r('app.color.text_color'))
        .fontWeight(FontWeight.Bold)
        .margin({ top: 0, bottom: 5 }) // 去除上边距，增加下边距

      // 输入框和按钮在同一行
      Row() {
        // 输入框占主要宽度
        TextInput({ placeholder: this.placeholderColor })
          .keyboardAppearance(KeyboardAppearance.IMMERSIVE)
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
          .onChange((input: string) => this.input = parseInt(input))
          .inputFilter('^[-+]?\\d+$')
          .type(InputType.Number)
          .enableAutoFill(true)
          .id('input')
          .height(36)  // 稍微降低高度
          .layoutWeight(1)
          .onAppear(() => {
            focusControl.requestFocus('input')
          })
          .maxLength(10)
          .maxLines(1)
          .enterKeyType(EnterKeyType.Done)

        // 按钮容器 - 紧凑排列
        Row({ space: 6 }) { // 进一步减小按钮间距
          Button({ type: ButtonType.Normal, stateEffect: true }) {
            SymbolGlyph($r('sys.symbol.xmark'))
              .fontSize(16)
              .fontColor([$r('app.color.text_color')])
          }
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
          .backgroundColor($r('sys.color.titlebar_icon_background_color'))
          .borderRadius(16)
          .width(36) // 稍微降低宽度
          .height(36) // 稍微降低高度
          .onClick(() => this.controller?.close())

          Button({ type: ButtonType.Normal, stateEffect: true }) {
            SymbolGlyph($r('sys.symbol.checkmark'))
              .fontSize(16)
              .fontColor([$r('app.color.text_color')])
          }
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
          .backgroundColor($r('sys.color.titlebar_icon_background_color'))
          .borderRadius(16)
          .width(36) // 稍微降低宽度
          .height(36) // 稍微降低高度
          .onClick(() => {
            this.controller?.close()
            if (this.confirm) {
              this.confirm(this.input)
            }
          })
        }
        .margin({ left: 8 }) // 减小输入框与按钮的间距
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