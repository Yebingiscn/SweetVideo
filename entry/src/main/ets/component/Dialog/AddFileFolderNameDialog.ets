import { DIALOG_TITLE_FONT_SIZE } from '../../common/Constants'
import { FileFolder } from '../../interfaces/FileFolderInterface'
import FileFolderUtil from '../../utils/FileFolderUtil'
import { PathUtils } from '../../utils/PathUtils'
import { DialogButtonBar } from './DialogButtonBar'

@CustomDialog
export struct AddFileFolderNameDialog {
  controller?: CustomDialogController = undefined
  file_folder_name: string | undefined = undefined
  onFolderAdded?: (folders: FileFolder[]) => void

  build() {
    Column({ space: 25 }) {
      Text('输入新文件夹名')
        .fontSize(DIALOG_TITLE_FONT_SIZE)
        .fontColor($r('app.color.text_color'))
        .fontWeight(FontWeight.Bold)
        .margin({ top: 10 })
      TextInput()
        .keyboardAppearance(KeyboardAppearance.IMMERSIVE)
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
        .onChange((input: string) => this.file_folder_name = input)
        .id('input_name')
        .onAppear(() => {
          focusControl.requestFocus('input_name')
        })

      DialogButtonBar(
        () => {
          this.controller?.close()
        },
        async () => {
          if (!this.file_folder_name || this.file_folder_name.trim() == '') {
            return
          }
          const updatedFolders = await FileFolderUtil.createNewFolder(PathUtils.appContext!, this.file_folder_name)
          if (this.onFolderAdded) {
            this.onFolderAdded(updatedFolders)
          }
          this.controller?.close()
        }
      )
    }.padding(20)
  }
}
