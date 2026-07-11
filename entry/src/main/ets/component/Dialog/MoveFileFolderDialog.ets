import { FileFolder } from '../../interfaces/FileFolderInterface'
import FileFolderUtil from '../../utils/FileFolderUtil'
import { PathUtils } from '../../utils/PathUtils'
import Preferences from '../../database/Preferences'
import DataSyncUtil from '../../utils/DataSyncUtil'
import { DialogButtonBar } from './DialogButtonBar'

@CustomDialog
export struct MoveFileFolderDialog {
  controller?: CustomDialogController = undefined
  @State selected_parent_date: string | null = null
  onFolderMoved?: (folders: FileFolder[]) => void

  build() {
    Column({ space: 20 }) {
      Text($r('app.string.move_folder'))
        .fontSize(20)
        .fontColor($r('app.color.text_color'))
        .fontWeight(FontWeight.Bold)

      List({ space: 4 }) {
        ListItem() {
          Row({ space: 10 }) {
            Radio({ value: '__root__', group: 'move_parent_folder' })
              .radioStyle({
                checkedBackgroundColor: $r('app.color.main_color')
              })
              .checked(this.selected_parent_date === null)
              .onChange((isChecked: boolean) => {
                if (isChecked) {
                  this.selected_parent_date = null
                }
              })
            Text('根目录')
              .fontSize(14)
              .fontColor($r('app.color.text_color'))
          }
          .width('100%')
          .padding({
            left: 12,
            right: 12,
            top: 8,
            bottom: 8
          })
          .borderRadius(12)
          .onClick(() => {
            this.selected_parent_date = null
          })
        }

        Repeat<FileFolder>(FileFolderUtil.flattenTree(Preferences.getFileFolder(PathUtils.appContext!)))
          .each((repeatItem: RepeatItem<FileFolder>) => {
            ListItem() {
              Row({ space: 10 }) {
                if (FileFolderUtil.getFolderDepth(PathUtils.appContext!, repeatItem.item.date) > 0) {
                  Row().width(FileFolderUtil.getFolderDepth(PathUtils.appContext!, repeatItem.item.date) * 12)
                }
                Radio({ value: repeatItem.item.date, group: 'move_parent_folder' })
                  .radioStyle({
                    checkedBackgroundColor: $r('app.color.main_color')
                  })
                  .checked(this.selected_parent_date === repeatItem.item.date)
                  .onChange((isChecked: boolean) => {
                    if (isChecked) {
                      this.selected_parent_date = repeatItem.item.date
                    }
                  })
                Text(repeatItem.item.name)
                  .fontSize(14)
                  .fontColor($r('app.color.text_color'))
              }
              .width('100%')
              .padding({
                left: 12,
                right: 12,
                top: 8,
                bottom: 8
              })
              .borderRadius(12)
              .onClick(() => {
                this.selected_parent_date = repeatItem.item.date
              })
            }
            .visibility(repeatItem.item.date === DataSyncUtil.movingFolderDate ||
              this.isDescendant(DataSyncUtil.movingFolderDate, repeatItem.item.date,
                Preferences.getFileFolder(PathUtils.appContext!)) ?
              Visibility.None : Visibility.Visible)
          })
          .key((item: FileFolder) => item.date)
      }.scrollBar(BarState.Off)
      .height(200)
      .width('100%')

      DialogButtonBar(
        () => {
          this.controller?.close()
        },
        () => {
          const updatedFolders =
            FileFolderUtil.moveFileFolder(PathUtils.appContext!, DataSyncUtil.movingFolderDate,
              this.selected_parent_date)
          if (this.onFolderMoved) {
            this.onFolderMoved(updatedFolders)
          }
          this.controller?.close()
        }
      )
    }.padding(20)
  }

  private isDescendant(folderDate: string, checkDate: string, folders: FileFolder[]): boolean {
    const children = folders.filter(f => f.parent_date === folderDate)
    for (const child of children) {
      if (child.date === checkDate) {
        return true
      }
      if (this.isDescendant(child.date, checkDate, folders)) {
        return true
      }
    }
    return false
  }
}
