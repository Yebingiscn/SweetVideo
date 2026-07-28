import { DIALOG_TITLE_FONT_SIZE } from '../../common/Constants'
import { DialogButtonBar } from './DialogButtonBar'
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import { FileFolder } from '../../interfaces/FileFolderInterface'
import DataSyncUtil from '../../utils/DataSyncUtil'

@CustomDialog
export struct RenameDialog {
  controller?: CustomDialogController
  @Prop title: ResourceStr = '重命名'
  @Prop preserveExtension: boolean = false
  @Prop renameTarget: 'video' | 'folder' = 'video'
  @State name: string = ''
  onConfirm?: (name: string) => void
  private initialName: string = ''
  private extension: string = ''

  aboutToAppear(): void {
    if (this.renameTarget === 'folder') {
      this.initialName = (DataSyncUtil.editingFolder as FileFolder)?.name ?? ''
    } else {
      this.initialName = (DataSyncUtil.editingVideo as VideoMetadata)?.title ?? ''
    }
    if (this.preserveExtension) {
      const lastDotIndex = this.initialName.lastIndexOf('.')
      if (lastDotIndex > 0) {
        this.name = this.initialName.slice(0, lastDotIndex)
        this.extension = this.initialName.slice(lastDotIndex)
      } else {
        this.name = this.initialName
        this.extension = ''
      }
    } else {
      this.name = this.initialName
    }
  }

  build() {
    Column({ space: 25 }) {
      Text(this.title)
        .fontSize(DIALOG_TITLE_FONT_SIZE)
        .fontColor($r('app.color.text_color'))
        .fontWeight(FontWeight.Bold)
        .margin({ top: 10 })

      TextArea({ text: this.name })
        .keyboardAppearance(KeyboardAppearance.IMMERSIVE)
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
        .borderRadius(16)
        .onChange((input: string) => {
          this.name = input
        })
        .enableAutoSpacing(this.preserveExtension)
        .enterKeyType(EnterKeyType.Done)
        .onAppear(() => {
          focusControl.requestFocus('rename_dialog_input')
        })
        .id('rename_dialog_input')

      DialogButtonBar(
        () => {
          this.controller?.close()
        },
        () => {
          if (!this.name?.trim()) {
            return
          }
          if (this.onConfirm) {
            const finalName = this.preserveExtension
              ? this.name.trim() + this.extension
              : this.name.trim()
            this.onConfirm(finalName)
          }
          this.controller?.close()
        }
      )
    }.padding(20)
  }
}
