import { DIALOG_TITLE_FONT_SIZE } from '../../common/Constants'
import { DialogButtonBar } from './DialogButtonBar'
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import { FileFolder } from '../../interfaces/FileFolderInterface'
import DataSyncUtil from '../../utils/DataSyncUtil'
import VideoInfoUtil from '../../utils/VideoInfoUtil'
import ToolsUtil from '../../utils/ToolsUtil'
import { salmonLogger } from 'salmonlogger'

@CustomDialog
export struct RenameDialog {
  controller?: CustomDialogController
  @Prop title: ResourceStr = $r('app.string.rename')
  @Prop preserveExtension: boolean = false
  @Prop renameTarget: 'video' | 'folder' = 'video'
  @State name: string = ''
  onConfirm?: (name: string) => void | Promise<void>
  private initialName: string = ''
  private extension: string = ''

  aboutToAppear(): void {
    if (this.renameTarget === 'folder') {
      this.initialName = (DataSyncUtil.editingFolder as FileFolder)?.name ?? ''
    } else {
      this.initialName = (DataSyncUtil.editingVideo as VideoMetadata)?.title ?? ''
    }
    if (this.preserveExtension) {
      const parts = VideoInfoUtil.splitFileName(this.initialName)
      this.name = parts.stem
      this.extension = parts.ext
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
        .height(96)
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
        async () => {
          if (!this.name?.trim()) {
            return
          }
          if (this.onConfirm) {
            const finalName = this.preserveExtension
              ? this.name.trim() + this.extension
              : this.name.trim()
            try {
              await this.onConfirm(finalName)
            } catch (_error) {
              salmonLogger.addLog('RenameDialog', 'Could not save the name', true)
              ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.library_operation_failed').id))
              return
            }
          }
          this.controller?.close()
        }
      )
    }.padding(20)
  }
}
