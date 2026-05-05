import { DeleteType } from '../../common/enum/DeleteType'
import { VideoSource } from '../../common/enum/VideoSource'
import DataSyncUtil from '../../utils/DataSyncUtil'
import SelectFileUtil from '../../utils/SelectFileUtil'
import ToolsUtil from '../../utils/ToolsUtil'

function itemUri() {
  const item = DataSyncUtil.editingVideo
  return item!.uri
}

@CustomDialog
export struct VideoDeleteDialog {
  confirm?: (deleteType: DeleteType) => void
  controller?: CustomDialogController
  @State deleteOption: 'soft' | 'hard' | 'recent' = 'soft'
  @State permanentDeleteVisibility: boolean = false
  @State moveToRecentVisibility: boolean = false
  private uri: string = itemUri()

  aboutToAppear(): void {
    this.permanentDeleteVisibility = this.getPermanentDeleteVisibility()
    this.moveToRecentVisibility = this.getMoveToRecentVisibility()
    if (this.moveToRecentVisibility) {
      this.deleteOption = 'recent'
    }
  }

  build() {
    Column({ space: 20 }) {
      Text('删除确认')
        .fontSize(20)
        .fontColor($r('app.color.text_color'))
        .fontWeight(FontWeight.Medium)

      Text(this.getMsg())
        .fontSize(15)
        .fontColor($r('app.color.text_color'))
        .opacity(0.85)
        .textAlign(TextAlign.Start)
        .lineHeight(22)

      Column({ space: 12 }) {
        Row() {
          Radio({ value: 'soft', group: 'deleteOptionsGroup' })
            .checked(this.deleteOption === 'soft')
            .onChange((checked: boolean) => {
              if (checked) {
                this.deleteOption = 'soft'
              }
            })
            .width(20)
            .height(20)
          Column() {
            Text('仅从列表移除')
              .fontSize(15)
              .fontColor($r('app.color.text_color'))
              .fontWeight(FontWeight.Medium)
            Text('文件保留在设备中，仅从应用列表移除')
              .fontSize(12)
              .fontColor($r('app.color.text_color'))
              .opacity(0.6)
          }
          .alignItems(HorizontalAlign.Start)
          .margin({ left: 8 })
        }
        .width('100%')

        if (this.permanentDeleteVisibility) {
          Row() {
            Radio({ value: 'hard', group: 'deleteOptionsGroup' })
              .checked(this.deleteOption === 'hard')
              .onChange((checked: boolean) => {
                if (checked) {
                  this.deleteOption = 'hard'
                }
              })
              .width(20)
              .height(20)
            Column() {
              Text('彻底删除文件')
                .fontSize(15)
                .fontColor(this.deleteOption === 'hard' ? '#FF4D4F' : $r('app.color.text_color'))
                .fontWeight(FontWeight.Medium)
              Text('文件将从设备中永久删除，不可恢复')
                .fontSize(12)
                .fontColor('#FF4D4F')
                .opacity(0.8)
            }
            .alignItems(HorizontalAlign.Start)
            .margin({ left: 8 })
          }
          .width('100%')
        }

        if (this.moveToRecentVisibility) {
          Row() {
            Radio({ value: 'recent', group: 'deleteOptionsGroup' })
              .checked(this.deleteOption === 'recent')
              .onChange((checked: boolean) => {
                if (checked) {
                  this.deleteOption = 'recent'
                }
              })
              .width(20)
              .height(20)
            Column() {
              Text('移至最近删除')
                .fontSize(15)
                .fontColor($r('app.color.text_color'))
                .fontWeight(FontWeight.Medium)
              Text('文件可在30天内从系统最近删除中恢复')
                .fontSize(12)
                .fontColor($r('app.color.text_color'))
                .opacity(0.6)
            }
            .alignItems(HorizontalAlign.Start)
            .margin({ left: 8 })
          }
          .width('100%')
        }
      }
      .width('100%')
      .padding({ left: 8, right: 8 })

      Flex({ justifyContent: FlexAlign.SpaceAround }) {
        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Row({ space: 5 }) {
            SymbolGlyph($r('sys.symbol.xmark')).fontSize(16).fontColor([$r('app.color.text_color')])
            Text($r('app.string.cancel'))
              .fontSize(15)
              .fontColor($r('app.color.text_color'))
              .fontWeight(FontWeight.Medium)
          }.alignItems(VerticalAlign.Center).padding({ left: 12, right: 12 })
        }
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
        .backgroundColor($r('sys.color.button_background_color_transparent'))
        .borderRadius(12)
        .height(36)
        .onClick(() => this.controller?.close())

        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Row({ space: 5 }) {
            SymbolGlyph($r('sys.symbol.trash_fill'))
              .fontSize(16)
              .fontColor(this.deleteOption === 'hard' ? ['#FF4D4F'] : [$r('app.color.text_color')])
            Text($r('app.string.sure'))
              .fontSize(15)
              .fontColor(this.deleteOption === 'hard' ? '#FF4D4F' : $r('app.color.text_color'))
              .fontWeight(FontWeight.Medium)
          }.alignItems(VerticalAlign.Center).padding({ left: 12, right: 12 })
        }
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
        .backgroundColor(this.deleteOption === 'hard' ? 'rgba(255, 77, 79, 0.15)' :
          $r('sys.color.button_background_color_transparent'))
        .borderRadius(12)
        .height(36)
        .onClick(() => {
          this.controller?.close()
          let deleteType = DeleteType.SOFT
          if (this.deleteOption === 'hard') {
            deleteType = DeleteType.HARD
          } else if (this.deleteOption === 'recent') {
            deleteType = DeleteType.RECENT
          }
          this.confirm?.(deleteType)
        })
      }.margin({ bottom: 5 })
    }.padding(20)
    .width('85%')
  }

  private getMsg(): ResourceStr {
    switch (this.deleteOption) {
      case 'hard':
        return $r('app.string.hard_del_confirm')
      case 'recent':
        return $r('app.string.recent_del_confirm')
      default:
        return $r('app.string.soft_del_confirm')
    }
  }

  private getPermanentDeleteVisibility() {
    if (SelectFileUtil.isPathFromSource(this.uri, VideoSource.SWEET_VIDEO_DOWNLOAD_FILE)) {
      return true
    } else {
      return false
    }
  }

  private getMoveToRecentVisibility() {
    if (SelectFileUtil.isPathFromSource(this.uri, VideoSource.PHOTO_SELECT_OPTION)) {
      return false
    } else {
      return true
    }
  }
}