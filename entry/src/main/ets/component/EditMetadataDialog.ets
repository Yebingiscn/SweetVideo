import DataSyncUtil from '../utils/DataSyncUtil';
import { VideoMetadata } from '../utils/VideoInfoUtil';

@CustomDialog
export struct editMetadataDialog { //编辑元数据弹窗
  confirm?: (name: string | undefined) => void
  controller?: CustomDialogController
  name: string | undefined = undefined

  aboutToAppear(): void {
    let tmp = JSON.parse(DataSyncUtil.editing_video) as VideoMetadata
    this.name = tmp.title
  }

  build() {
    Column({ space: 25 }) {
      Text($r('app.string.rename'))
        .fontSize(25)
        .fontColor($r('app.color.text_color'))
        .fontWeight(FontWeight.Bold)
        .margin({ top: 10 })
      TextInput({ text: this.name?.slice(0, this.name?.lastIndexOf('.')) })
        .id('change_name')
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
        .onChange((input: string) => this.name = input + "." + this.name?.split('.')[this.name?.split('.').length - 1])
        .onAppear(() => {
          focusControl.requestFocus('change_name')
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
        .backgroundColor('#00000000')
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
        .backgroundColor('#00000000')
        .borderRadius(8)
        .height(40)
        .onClick(() => {
          this.controller?.close()
          if (this.confirm) {
            this.confirm(this.name)
          }
        })
      }.margin({ bottom: 10 })
    }.padding(20)
  }
}