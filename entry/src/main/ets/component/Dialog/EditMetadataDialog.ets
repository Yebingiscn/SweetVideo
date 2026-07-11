import { DIALOG_TITLE_FONT_SIZE } from '../../common/Constants'
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import DataSyncUtil from '../../utils/DataSyncUtil'
import { DialogButtonBar } from './DialogButtonBar'

@CustomDialog
export struct EditMetadataDialog {
  confirm?: (name: string | undefined) => void
  controller?: CustomDialogController
  name: string | undefined = undefined

  aboutToAppear(): void {
    let videoMetadata = DataSyncUtil.editingVideo as VideoMetadata
    this.name = videoMetadata?.title
  }

  build() {
    Column({ space: 25 }) {
      Text($r('app.string.rename'))
        .fontSize(DIALOG_TITLE_FONT_SIZE)
        .fontColor($r('app.color.text_color'))
        .fontWeight(FontWeight.Bold)
        .margin({ top: 10 })

      TextInput({ text: this.name?.slice(0, this.name?.lastIndexOf('.')) })
        .id('change_name')
        .keyboardAppearance(KeyboardAppearance.IMMERSIVE)
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
        .onChange((input: string) => this.name = input + "." + this.name?.split('.')[this.name?.split('.').length - 1])
        .borderRadius(16)
        .onAppear(() => {
          focusControl.requestFocus('change_name')
        })
        .enableAutoSpacing(true)
        .enterKeyType(EnterKeyType.Done)

      DialogButtonBar(
        () => {
          this.controller?.close()
        },
        () => {
          this.controller?.close()
          if (this.confirm) {
            this.confirm(this.name)
          }
        }
      )
    }
    .padding(20)
  }
}