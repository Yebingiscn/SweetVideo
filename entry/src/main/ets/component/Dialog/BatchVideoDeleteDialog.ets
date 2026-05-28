import { DeleteType } from '../../common/enum/DeleteType'
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'

@CustomDialog
export struct BatchVideoDeleteDialog {
  confirm?: (deleteType: DeleteType) => void
  controller?: CustomDialogController
  @State videoList: VideoMetadata[] = []
  @State deleteOption: 'soft' | 'hard' | 'recent' = 'soft'

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

      Text(this.getMsg())
        .fontSize(14)
        .fontColor($r('app.color.text_color'))
        .opacity(0.7)
        .textAlign(TextAlign.Start)
        .lineHeight(20)

      DeleteOptionsGroup({
        deleteOption: this.deleteOption,
        permanentDeleteVisibility: this.getPermanentDeleteVisibility(),
        moveToRecentVisibility: this.getMoveToRecentVisibility(),
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
