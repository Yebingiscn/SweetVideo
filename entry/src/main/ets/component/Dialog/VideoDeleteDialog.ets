import { DeleteType } from "../../common/enum/deleteType"
import { VideoMetadata } from "../../interfaces/VideoMetadataInterface";
import DataSyncUtil from '../../utils/DataSyncUtil';

function itemUri() {
  const item = JSON.parse(DataSyncUtil.editingVideo) as VideoMetadata
  return item.uri
}

@CustomDialog
export struct VideoDeleteDialog {
  confirm?: (deleteType: DeleteType) => void
  controller?: CustomDialogController
  @State cb1: boolean = true
  @State cb2: boolean = false
  private uri: string = itemUri()
  private cb1VisGen() { // V2 时可用 @Computed
    if (this.uri.startsWith("/storage/Users/currentUser/")) {
      return Visibility.Visible
    } else {
      this.cb1 = false
      return Visibility.None
    }
  }
  @State cb1Vis: Visibility = this.cb1VisGen()
  private cb2VisGen() { // V2 时可用 @Computed
    if (this.uri.startsWith("file://media/")) {
      this.cb2 = false
      return Visibility.None
    } else {
      return Visibility.Visible
    }
  }
  @State cb2Vis: Visibility = this.cb2VisGen()

  private msgGen() { // V2 时可用 @Computed
    if (this.cb1) {
      return $r('app.string.hard_del_confirm')
    } else if (this.cb2){
      return $r('app.string.recent_del_confirm')
    } else {
      return $r('app.string.soft_del_confirm')
    }
  }
  @State msg: ResourceStr = this.msgGen();


  build() {
    Column({ space: 25 }) {
      Text(this.msg)
        .fontSize(25)
        .fontColor($r('app.color.text_color'))
        .fontWeight(FontWeight.Bold)
        .margin({ top: 10 })

      Flex({ justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center }) {
        Row(){
          Checkbox({ name: 'cb1', group: 'cbg' })
            .selectedColor($r('app.color.main_color'))
            .shape(CheckBoxShape.CIRCLE)
            .onChange((checked: boolean) => {
              if (checked) {
                this.cb2 = false
                this.msg = $r('app.string.hard_del_confirm')
              } else if (!this.cb2) {
                this.msg = $r('app.string.soft_del_confirm')
              }
            })
            .select($$this.cb1)
            .width(30)
            .height(30)
          Text('永久删除')
            .fontSize(18)
            .fontColor($r('app.color.text_color'))
            .fontWeight(FontWeight.Medium)
        }
        .visibility(this.cb1Vis)
        Row(){
          Checkbox({ name: 'cb2', group: 'cbg' })
            .selectedColor($r('app.color.main_color'))
            .shape(CheckBoxShape.CIRCLE)
            .onChange((checked: boolean) => {
              if (checked) {
                this.cb1 = false
                this.msg = $r('app.string.recent_del_confirm')
              } else if (!this.cb1){
                this.msg = $r('app.string.soft_del_confirm')
              }
            })
            .select($$this.cb2)
            .width(30)
            .height(30)
          Text('移动到最近删除')
            .fontSize(18)
            .fontColor($r('app.color.text_color'))
            .fontWeight(FontWeight.Medium)
        }
      }
      .visibility(this.cb2Vis)

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
        .backgroundColor($r('sys.color.button_background_color_transparent'))
        .borderRadius(8)
        .height(40)
        .onClick(() => {
          this.controller?.close()

          let deleteType = DeleteType.SOFT
          if (this.cb1) {
            deleteType = DeleteType.HARD
          } else if (this.cb2) {
            deleteType = DeleteType.RECENT
          }
          this.confirm?.(deleteType)
        })
      }.margin({ bottom: 10 })
    }.padding(20)
  }
}