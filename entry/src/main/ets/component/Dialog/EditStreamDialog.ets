import { DIALOG_TITLE_FONT_SIZE } from '../../common/Constants'
import { DialogButtonBar } from './DialogButtonBar'
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import DataSyncUtil from '../../utils/DataSyncUtil'
import SmbUtil from '../../utils/SmbUtil'
import ToolsUtil from '../../utils/ToolsUtil'

@CustomDialog
export struct EditStreamDialog {
  controller?: CustomDialogController
  @State streamName: string = ''
  @State streamUrl: string = ''
  @State saving: boolean = false
  onConfirm?: (name: string, url: string) => void
  private originalUri: string = ''
  private displayedUri: string = ''

  aboutToAppear(): void {
    const stream = DataSyncUtil.editingVideo as VideoMetadata
    if (stream) {
      this.streamName = stream.title ?? ''
      this.originalUri = stream.uri ?? ''
      this.displayedUri = SmbUtil.displayUri(this.originalUri)
      this.streamUrl = this.displayedUri
    }
  }

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
        async () => {
          if (this.saving) {
            return
          }
          this.controller?.close()
        },
        async () => {
          if (!this.streamName.trim() || !this.streamUrl.trim()) {
            return
          }
          this.saving = true
          try {
            const value = this.streamUrl.trim()
            const url = value === this.displayedUri ? this.originalUri : await SmbUtil.prepareUri(value)
            this.onConfirm?.(this.streamName.trim(), url)
            this.controller?.close()
          } catch (error) {
            ToolsUtil.showToast(error instanceof Error ? error.message : 'SMB 地址无效')
          } finally {
            this.saving = false
          }
        }
      )
    }.padding(20).enabled(!this.saving)
  }
}
