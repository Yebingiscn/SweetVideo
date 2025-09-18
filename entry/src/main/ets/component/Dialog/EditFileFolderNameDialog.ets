import { FileFolder } from '../../interfaces/FileFolderInterface'
import DataSyncUtil from '../../utils/DataSyncUtil'

// 重命名文件夹弹窗
@CustomDialog
export struct EditFileFolderNameDialog {
  confirm?: (name: string | undefined) => void
  controller?: CustomDialogController
  file_folder_name: string | undefined = undefined

  aboutToAppear(): void {
    let tmp = JSON.parse(DataSyncUtil.editingVideo) as FileFolder
    this.file_folder_name = tmp.name
  }

  build() {
    Column({ space: 25 }) {
      Text('修改新文件夹名')
        .fontSize(25)
        .fontColor($r('app.color.text_color'))
        .fontWeight(FontWeight.Bold)
        .margin({ top: 10 })
      TextInput({ text: this.file_folder_name })
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
        .backgroundColor($r('sys.color.titlebar_icon_background_color'))
        .borderRadius(8)
        .height(40)
        .onClick(() => this.controller?.close())

        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Row({ space: 5 }) {
            SymbolGlyph($r('sys.symbol.checkmark')).fontSize(18).fontColor([$r('app.color.text_color')])
            Text($r('app.string.sure')).fontSize(18).fontColor($r('app.color.text_color')).fontWeight(FontWeight.Medium)
          }.alignItems(VerticalAlign.Center).padding({ left: 12, right: 12 })
        }
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
        .backgroundColor($r('sys.color.titlebar_icon_background_color'))
        .borderRadius(8)
        .height(40)
        .onClick(() => {
          this.controller?.close()
          if (this.confirm) {
            this.confirm(this.file_folder_name)
          }
        })
      }.margin({ bottom: 10 })
    }.padding(20)
  }
}