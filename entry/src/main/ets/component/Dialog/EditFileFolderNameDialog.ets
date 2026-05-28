
@CustomDialog
export struct EditFileFolderNameDialog {
  confirm?: (name: string | undefined) => void
  controller?: CustomDialogController
  file_folder_name: string | undefined = undefined

  aboutToAppear(): void {
    let tmp = DataSyncUtil.editingFolder as FileFolder
    this.file_folder_name = tmp?.name
  }

  build() {
    Column({ space: 25 }) {
      Text('修改新文件夹名')
        .fontSize(DIALOG_TITLE_FONT_SIZE)
        .fontColor($r('app.color.text_color'))
        .fontWeight(FontWeight.Bold)
        .margin({ top: 10 })
      TextInput({ text: this.file_folder_name })
        .keyboardAppearance(KeyboardAppearance.IMMERSIVE)
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
        .onChange((input: string) => this.file_folder_name = input)
        .id('new_folder_name')
        .onAppear(() => {
          focusControl.requestFocus('new_folder_name')
        })

      DialogButtonBar(
        () => {
          this.controller?.close()
        },
        () => {
          this.controller?.close()
          if (this.confirm) {
            this.confirm(this.file_folder_name)
          }
        }
      )
    }.padding(20)
  }
}
