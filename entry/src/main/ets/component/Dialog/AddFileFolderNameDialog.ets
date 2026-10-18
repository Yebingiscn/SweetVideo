import { FileFolder } from '../../interfaces/FileFolderInterface'
import FileFolderUtil from '../../utils/FileFolderUtil'
import { PathUtils } from '../../utils/PathUtils'
import Preferences from '../../database/Preferences'
import { DialogButtonBar } from './DialogButtonBar'
import FolderDirectory from '../../utils/FolderDirectory'

@CustomDialog
export struct AddFileFolderNameDialog {
  controller?: CustomDialogController = undefined
  file_folder_name: string | undefined = undefined
  @State selected_parent_date: string | null = null
  onFolderAdded?: (folders: FileFolder[]) => void
  foldersOverride?: FileFolder[]
  initialParentDate?: string | null
  onCreateFolder?: (name: string, parentDate: string | null) => void

  aboutToAppear(): void {
    if (this.initialParentDate !== undefined) this.selected_parent_date = this.initialParentDate
  }

  // CustomDialog 使用普通方法，避免 getter 在 ArkUI 转换后丢失。
  private getFolders(): FileFolder[] {
    return this.foldersOverride ?? Preferences.getFileFolder(PathUtils.appContext!)
  }

  private folderDepth(date: string): number {
    return Math.max(0, FolderDirectory.forLibrary(this.getFolders()).path(date).length - 1)
  }

  build() {
    Column({ space: 20 }) {
      Text($r('app.string.new_folder'))
        .fontSize(20)
        .fontColor($r('app.color.text_color'))
        .fontWeight(FontWeight.Bold)

      TextInput({ placeholder: $r('app.string.folder_name_placeholder') })
        .keyboardAppearance(KeyboardAppearance.IMMERSIVE)
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
        .borderRadius(16)
        .height(44)
        .onChange((input: string) => this.file_folder_name = input)
        .id('input_name')
        .onAppear(() => {
          focusControl.requestFocus('input_name')
        })

      List({ space: 4 }) {
        ListItem() {
          Row({ space: 10 }) {
            Radio({ value: '__root__', group: 'parent_folder' })
              .radioStyle({
                checkedBackgroundColor: $r('app.color.main_color')
              })
              .checked(this.selected_parent_date === null)
              .onChange((isChecked: boolean) => {
                if (isChecked) {
                  this.selected_parent_date = null
                }
              })
            Text($r('app.string.root_folder'))
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

        Repeat<FileFolder>(FileFolderUtil.flattenTree(this.getFolders()))
          .each((repeatItem: RepeatItem<FileFolder>) => {
            ListItem() {
              Row({ space: 10 }) {
                if (this.folderDepth(repeatItem.item.date) > 0) {
                  Row().width(this.folderDepth(repeatItem.item.date) * 12)
                }
                Radio({ value: repeatItem.item.date, group: 'parent_folder' })
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
          })
          .key((item: FileFolder) => item.date)
          .virtualScroll()
      }.scrollBar(BarState.Off)
      .height(150)
      .width('100%')

      DialogButtonBar(
        () => {
          this.controller?.close()
        },
        () => {
          if (!this.file_folder_name || this.file_folder_name.trim() == '') {
            return
          }
          if (this.onCreateFolder) {
            this.onCreateFolder(this.file_folder_name.trim(), this.selected_parent_date)
          } else {
            const updatedFolders =
              FileFolderUtil.createNewFolder(PathUtils.appContext!, this.file_folder_name,
                this.selected_parent_date)
            this.onFolderAdded?.(updatedFolders)
          }
          this.controller?.close()
        }
      )
    }.padding(20)
  }
}
