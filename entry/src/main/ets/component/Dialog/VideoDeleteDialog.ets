import { DeleteType } from '../../common/enum/DeleteType'
import { VideoSource } from '../../common/enum/VideoSource'
import { DIALOG_TITLE_FONT_SIZE } from '../../common/Constants'
import DataSyncUtil from '../../utils/DataSyncUtil'
import SelectFileUtil from '../../utils/SelectFileUtil'
import { DeleteOptionsGroup } from './DeleteOptionsGroup'

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

      DeleteOptionsGroup({
        deleteOption: this.deleteOption,
        permanentDeleteVisibility: this.permanentDeleteVisibility,
        moveToRecentVisibility: this.moveToRecentVisibility,
        onOptionChange: (option: 'soft' | 'hard' | 'recent') => {
          this.deleteOption = option
        },
        onConfirm: (deleteType: DeleteType) => {
          this.controller?.close()
          this.confirm?.(deleteType)
        },
        onCancel: () => {
          this.controller?.close()
        }
      })
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

  private getPermanentDeleteVisibility(): boolean {
    return SelectFileUtil.isPathFromSource(this.uri, VideoSource.SWEET_VIDEO_DOWNLOAD_FILE)
  }

  private getMoveToRecentVisibility(): boolean {
    return !SelectFileUtil.isPathFromSource(this.uri, VideoSource.PHOTO_SELECT_OPTION)
  }
}
