import { DeleteType } from '../../common/enum/DeleteType'
import { VideoSource } from '../../common/enum/VideoSource'
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import SelectFileUtil from '../../utils/SelectFileUtil'
import ToolsUtil from '../../utils/ToolsUtil'

@CustomDialog
export struct BatchVideoDeleteDialog {
  confirm?: (deleteType: DeleteType) => void
  controller?: CustomDialogController
  @State videoList: VideoMetadata[] = []
  @State isPermanentDelete: boolean = false
  @State isMoveToRecent: boolean = false
  @State msg: ResourceStr = ToolsUtil.getDeleteDialogMessage(this.isPermanentDelete, this.isMoveToRecent)

  build() {
    Column({ space: 20 }) {
      Text('删除确认')
        .fontSize(20)
        .fontColor($r('app.color.text_color'))
        .fontWeight(FontWeight.Medium)

      Text(this.getDeleteCountText())
        .fontSize(15)
        .fontColor($r('app.color.text_color'))
        .opacity(0.85)
        .textAlign(TextAlign.Start)
        .lineHeight(22)

      Text(this.msg)
        .fontSize(14)
        .fontColor($r('app.color.text_color'))
        .opacity(0.7)
        .textAlign(TextAlign.Start)
        .lineHeight(20)

      if (this.getMoveToRecentVisibility()) {
        Column({ space: 12 }) {
          if (this.getPermanentDeleteVisibility()) {
            Row() {
              Checkbox({ name: 'permanentDelete', group: 'deleteOptionsGroup' })
                .selectedColor('#FF4D4F')
                .shape(CheckBoxShape.CIRCLE)
                .onChange((checked: boolean) => {
                  if (checked) {
                    this.isMoveToRecent = false
                    this.msg = $r('app.string.hard_del_confirm')
                  } else if (!this.isMoveToRecent) {
                    this.msg = $r('app.string.soft_del_confirm')
                  }
                })
                .select(this.isPermanentDelete!!)
                .width(20)
                .height(20)
              Column() {
                Text('彻底删除文件')
                  .fontSize(15)
                  .fontColor(this.isPermanentDelete ? '#FF4D4F' : $r('app.color.text_color'))
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
              .select(this.isMoveToRecent!!)
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
        .width('100%')
        .padding({ left: 8, right: 8 })
      }

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
              .fontColor(this.isPermanentDelete ? ['#FF4D4F'] : [$r('app.color.text_color')])
            Text($r('app.string.sure'))
              .fontSize(15)
              .fontColor(this.isPermanentDelete ? '#FF4D4F' : $r('app.color.text_color'))
              .fontWeight(FontWeight.Medium)
          }.alignItems(VerticalAlign.Center).padding({ left: 12, right: 12 })
        }
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
        .backgroundColor(this.isPermanentDelete ? 'rgba(255, 77, 79, 0.15)' :
          $r('sys.color.button_background_color_transparent'))
        .borderRadius(12)
        .height(36)
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
      }.margin({ bottom: 5 })
    }.padding(20)
    .width('85%')
  }

  private getPermanentDeleteVisibility(): boolean {
    for (let i = 0; i < this.videoList.length; i++) {
      if (!SelectFileUtil.isPathFromSource(this.videoList[i].uri, VideoSource.SWEET_VIDEO_DOWNLOAD_FILE)) {
        return false
      }
    }
    return true
  }

  private getMoveToRecentVisibility(): boolean {
    for (let i = 0; i < this.videoList.length; i++) {
      if (SelectFileUtil.isPathFromSource(this.videoList[i].uri, VideoSource.PHOTO_SELECT_OPTION)) {
        return false
      }
    }
    return true
  }

  private getDeleteCountText(): string {
    return `确定要删除选中的 ${this.videoList.length} 个视频吗？`
  }
}
