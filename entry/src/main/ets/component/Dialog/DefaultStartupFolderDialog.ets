import { FileFolder } from '../../interfaces/FileFolderInterface'
import FileFolderUtil from '../../utils/FileFolderUtil'
import { PathUtils } from '../../utils/PathUtils'
import Preferences from '../../database/Preferences'
import { DialogButtonBar } from './DialogButtonBar'

@CustomDialog
export struct DefaultStartupFolderDialog {
  controller?: CustomDialogController = undefined
  @State selectedFolderDate: string = ''
  onFolderSelected?: (folderDate: string) => void

  aboutToAppear(): void {
    const savedDate = Preferences.getDefaultStartupFolder(PathUtils.appContext!)
    if (savedDate !== '' && savedDate !== '__stream__') {
      const folders = Preferences.getFileFolder(PathUtils.appContext!)
      if (!folders.some(f => f.date === savedDate)) {
        Preferences.saveDefaultStartupFolder(PathUtils.appContext!, '')
        this.selectedFolderDate = ''
        return
      }
    }
    this.selectedFolderDate = savedDate
  }

  build() {
    Column({ space: 20 }) {
      Text('选择默认启动页面')
        .fontSize(20)
        .fontColor($r('app.color.text_color'))
        .fontWeight(FontWeight.Bold)

      List({ space: 4 }) {
        ListItem() {
          Row({ space: 10 }) {
            Radio({ value: '__default__', group: 'default_startup_folder' })
              .radioStyle({
                checkedBackgroundColor: $r('app.color.main_color')
              })
              .checked(this.selectedFolderDate === '')
              .onChange((isChecked: boolean) => {
                if (isChecked) {
                  this.selectedFolderDate = ''
                }
              })
            Text('默认（首页）')
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
            this.selectedFolderDate = ''
          })
        }

        ListItem() {
          Row({ space: 10 }) {
            Radio({ value: '__stream__', group: 'default_startup_folder' })
              .radioStyle({
                checkedBackgroundColor: $r('app.color.main_color')
              })
              .checked(this.selectedFolderDate === '__stream__')
              .onChange((isChecked: boolean) => {
                if (isChecked) {
                  this.selectedFolderDate = '__stream__'
                }
              })
            Text('串流页')
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
            this.selectedFolderDate = '__stream__'
          })
        }

        Repeat<FileFolder>(FileFolderUtil.flattenTree(Preferences.getFileFolder(PathUtils.appContext!)))
          .each((repeatItem: RepeatItem<FileFolder>) => {
            ListItem() {
              Row({ space: 10 }) {
                if (FileFolderUtil.getFolderDepth(PathUtils.appContext!, repeatItem.item.date) > 0) {
                  Row().width(FileFolderUtil.getFolderDepth(PathUtils.appContext!, repeatItem.item.date) * 12)
                }
                Radio({ value: repeatItem.item.date, group: 'default_startup_folder' })
                  .radioStyle({
                    checkedBackgroundColor: $r('app.color.main_color')
                  })
                  .checked(this.selectedFolderDate === repeatItem.item.date)
                  .onChange((isChecked: boolean) => {
                    if (isChecked) {
                      this.selectedFolderDate = repeatItem.item.date
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
                this.selectedFolderDate = repeatItem.item.date
              })
            }
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
          Preferences.saveDefaultStartupFolder(PathUtils.appContext!, this.selectedFolderDate)
          if (this.onFolderSelected) {
            this.onFolderSelected(this.selectedFolderDate)
          }
          this.controller?.close()
        }
      )
    }.padding(20)
  }
}