
@CustomDialog
export struct InfoConfirmDialog {
  confirm?: () => void
  controller?: CustomDialogController
  textInfo: ResourceStr = ''

  build() {
    Column({ space: 25 }) {
      Text(this.textInfo)
        .fontSize(DIALOG_TITLE_FONT_SIZE)
        .fontColor($r('app.color.text_color'))
        .fontWeight(FontWeight.Bold)
        .margin({ top: 10 })

      DialogButtonBar(
        () => {
          this.controller?.close()
        },
        () => {
          this.controller?.close()
          if (this.confirm) {
            this.confirm()
          }
        }
      )
    }.padding(20)
  }
}
