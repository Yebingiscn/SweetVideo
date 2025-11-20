import { DeleteType } from '../../common/enum/DeleteType';
import { VideoSource } from '../../common/enum/VideoSource';
import DataSyncUtil from '../../utils/DataSyncUtil';
import SelectFileUtil from '../../utils/SelectFileUtil';

function itemUri() {
  const item = DataSyncUtil.editingVideo
  return item!.uri
}

@CustomDialog
export struct VideoDeleteDialog {
  confirm?: (deleteType: DeleteType) => void
  controller?: CustomDialogController
  @State isPermanentDelete: boolean = false
  @State isMoveToRecent: boolean = false
  @State permanentDeleteVisibility: boolean = false
  @State moveToRecentVisibility: boolean = false
  @State msg: ResourceStr = this.generateMessage();
  private uri: string = itemUri()

  aboutToAppear(): void {
    this.permanentDeleteVisibility = this.getPermanentDeleteVisibility()
    this.moveToRecentVisibility = this.getMoveToRecentVisibility()
  }

  build() {
    Column({ space: 25 }) {
      Text(this.msg)
        .fontSize(25)
        .fontColor($r('app.color.text_color'))
        .fontWeight(FontWeight.Bold)
        .margin({ top: 10 })

      if (this.moveToRecentVisibility) {
        Flex({ justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center }) {
          if (this.permanentDeleteVisibility) {
            Row() {
              Checkbox({ name: 'permanentDelete', group: 'deleteOptionsGroup' })
                .selectedColor($r('app.color.main_color'))
                .shape(CheckBoxShape.CIRCLE)
                .onChange((checked: boolean) => {
                  if (checked) {
                    this.isMoveToRecent = false
                    this.msg = $r('app.string.hard_del_confirm')
                  } else if (!this.isMoveToRecent) {
                    this.msg = $r('app.string.soft_del_confirm')
                  }
                })
                .select($$this.isPermanentDelete)
                .width(25)
                .height(25)
              Text('永久删除')
                .fontSize(18)
                .fontColor($r('app.color.text_color'))
                .fontWeight(FontWeight.Medium)
            }
          }

          Row() {
            Checkbox({ name: 'moveToRecent', group: 'deleteOptionsGroup' })
              .selectedColor($r('app.color.main_color'))
              .shape(CheckBoxShape.CIRCLE)
              .onChange((checked: boolean) => {
                if (checked) {
                  this.isPermanentDelete = false
                  this.msg = $r('app.string.recent_del_confirm')
                } else if (!this.isPermanentDelete) {
                  this.msg = $r('app.string.soft_del_confirm')
                }
              })
              .select($$this.isMoveToRecent)
              .width(25)
              .height(25)
            Text('移动到最近删除')
              .fontSize(18)
              .fontColor($r('app.color.text_color'))
              .fontWeight(FontWeight.Medium)
          }
        }
      }

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
        .onClick(() => {
          this.controller?.close()
          let deleteType = DeleteType.SOFT
          if (this.isPermanentDelete) {
            deleteType = DeleteType.HARD
          } else if (this.isMoveToRecent) {
            deleteType = DeleteType.RECENT
          }
          this.confirm?.(deleteType)
        })
      }.margin({ bottom: 10 })
    }.padding(20)
  }

  private getPermanentDeleteVisibility() { // V2 时可用 @Computed
    if (SelectFileUtil.isPathFromSource(this.uri, VideoSource.SWEET_VIDEO_DOWNLOAD_FILE)) {
      return true
    } else {
      this.isPermanentDelete = false
      return false
    }
  }

  private getMoveToRecentVisibility() { // V2 时可用 @Computed
    if (SelectFileUtil.isPathFromSource(this.uri, VideoSource.PHOTO_SELECT_OPTION)) {
      this.isMoveToRecent = false
      return false
    } else {
      return true
    }
  }

  private generateMessage() { // V2 时可用 @Computed
    if (this.isPermanentDelete) {
      return $r('app.string.hard_del_confirm')
    } else if (this.isMoveToRecent) {
      return $r('app.string.recent_del_confirm')
    } else {
      return $r('app.string.soft_del_confirm')
    }
  }
}