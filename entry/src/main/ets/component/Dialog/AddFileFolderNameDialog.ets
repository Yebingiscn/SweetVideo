import { FileFolderDataSource } from '../../utils/DataUtil'
import FileFolderUtil from '../../utils/FileFolderUtil'
import { PathUtils } from '../../utils/PathUtils'
import { FileFolder } from '../../interfaces/FileFolderInterface'

// 添加文件夹弹窗
@CustomDialog
export struct AddFileFolderNameDialog { //编辑元数据弹窗
  controller?: CustomDialogController
  file_folder_name: string | undefined = undefined
  fileFolderSource: FileFolderDataSource = new FileFolderDataSource([])
  // 添加成功后回调，用于刷新UI
  onFolderAdded?: (folders: FileFolder[]) => void

  build() {
    Column({ space: 25 }) {
      Text('输入新文件夹名')
        .fontSize(25)
        .fontColor($r('app.color.text_color'))
        .fontWeight(FontWeight.Bold)
        .margin({ top: 10 })
      TextInput()
        .keyboardAppearance(KeyboardAppearance.IMMERSIVE)// 设置搜索框沉浸模式
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
        .onChange((input: string) => this.file_folder_name = input)
        .id('input_name')
        .onAppear(() => {
          focusControl.requestFocus('input_name')
        })

      Flex({ justifyContent: FlexAlign.SpaceAround }) {
        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Row({ space: 5 }) {
            SymbolGlyph($r('sys.symbol.xmark')).fontSize(18).fontColor([$r('app.color.text_color')])
            Text($r('app.string.cancel'))
              .fontSize(18)
              .fontColor($r('app.color.text_color'))
              .fontWeight(FontWeight.Medium)
          }.alignItems(VerticalAlign.Center).padding({ left: 12, right: 12 })
        }
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
        .backgroundColor($r('sys.color.button_background_color_transparent'))
        .borderRadius(16)
        .height(40)
        .onClick(() => this.controller?.close())

        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Row({ space: 5 }) {
            SymbolGlyph($r('sys.symbol.checkmark')).fontSize(18).fontColor([$r('app.color.text_color')])
            Text($r('app.string.sure')).fontSize(18).fontColor($r('app.color.text_color')).fontWeight(FontWeight.Medium)
          }.alignItems(VerticalAlign.Center).padding({ left: 12, right: 12 })
        }
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
        .backgroundColor($r('sys.color.button_background_color_transparent'))
        .borderRadius(16)
        .height(40)
        .enabled(this.file_folder_name?.trim() != '')
        .onClick(async () => {
          if (!this.file_folder_name || this.file_folder_name.trim() == '') {
            return
          }
          const updatedFolders = await FileFolderUtil.createNewFolder(PathUtils.appContext!, this.file_folder_name, this.fileFolderSource)
          // 回调通知父组件更新文件夹列表
          if (this.onFolderAdded) {
            this.onFolderAdded(updatedFolders)
          }
          this.controller?.close()
        })
      }.margin({ bottom: 10 })
    }.padding(20)
  }
}