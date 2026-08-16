import { DIALOG_TITLE_FONT_SIZE } from '../../common/Constants'
import { DialogButtonBar } from './DialogButtonBar'
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import DataSyncUtil from '../../utils/DataSyncUtil'

@CustomDialog
export struct EditStreamDialog {
  controller?: CustomDialogController
  @State streamName: string = ''
  @State streamUrl: string = ''

  aboutToAppear(): void {
    const stream = DataSyncUtil.editingVideo as VideoMetadata
    if (stream) {
      this.streamName = stream.title ?? ''
      this.streamUrl = stream.uri ?? ''
    }
  }

  onConfirm?: (name: string, url: string) => void

  build() {
    Column({ space: 20 }) {
      Text('编辑串流')
        .fontSize(DIALOG_TITLE_FONT_SIZE)
        .fontColor($r('app.color.text_color'))
        .fontWeight(FontWeight.Bold)
        .margin({ top: 10 })

      TextInput({ placeholder: '名称', text: this.streamName })
        .keyboardAppearance(KeyboardAppearance.IMMERSIVE)
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
        .borderRadius(16)
        .height(44)
        .onChange((input: string) => this.streamName = input)
        .id('edit_stream_name')

      TextArea({ placeholder: '流媒体地址', text: this.streamUrl })
        .keyboardAppearance(KeyboardAppearance.IMMERSIVE)
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
        .borderRadius(16)
        .onChange((input: string) => this.streamUrl = input)

      DialogButtonBar(
        () => {
          this.controller?.close()
        },
        () => {
          if (!this.streamName.trim() || !this.streamUrl.trim()) {
            return
          }
          if (this.onConfirm) {
            this.onConfirm(this.streamName.trim(), this.streamUrl.trim())
          }
          this.controller?.close()
        }
      )
    }.padding(20)
  }
}