import { FileFolder } from '../../interfaces/FileFolderInterface'
import FolderDirectory from '../../utils/FolderDirectory'
import FolderHierarchy from '../../utils/FolderHierarchy'
import { DialogButtonBar } from './DialogButtonBar'

// 只选择目标，不访问普通媒体库或隐私数据；调用方负责提交移动。
@CustomDialog
export struct FolderPickerDialog {
  controller?: CustomDialogController
  title: ResourceStr = $r('app.string.move_to_folder')
  folders: FileFolder[] = []
  excludedDates: string[] = []
  initialDate: string = ''
  @State selectedDate: string = ''
  onConfirm?: (date: string) => void

  aboutToAppear(): void {
    this.selectedDate = this.initialDate
  }

  @Builder
  FolderChoiceBuilder(folder?: FileFolder) {
    Row({ space: 10 }) {
      Radio({ value: folder?.date ?? '', group: 'folder_picker' })
        .radioStyle({ checkedBackgroundColor: $r('app.color.main_color') })
        .checked(this.selectedDate === (folder?.date ?? ''))
        .onChange((checked: boolean) => {
          if (checked) this.selectedDate = folder?.date ?? ''
        })
      SymbolGlyph($r('sys.symbol.folder'))
        .fontSize(20)
        .fontColor([$r('app.color.text_color')])
      Text(folder?.name ?? $r('app.string.root_folder'))
        .fontSize(14)
        .fontColor($r('app.color.text_color'))
        .maxLines(2)
        .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 12 + (folder ? Math.max(0,
      FolderDirectory.forLibrary(this.folders).path(folder.date).length - 1) * 12 : 0),
      right: 12, top: 10, bottom: 10 })
    .borderRadius(12)
    .onClick(() => this.selectedDate = folder?.date ?? '')
  }

  build() {
    Column({ space: 20 }) {
      Text(this.title)
        .fontSize(20)
        .fontColor($r('app.color.text_color'))
        .fontWeight(FontWeight.Bold)
      List({ space: 4 }) {
        ListItem() {
          this.FolderChoiceBuilder()
        }
        Repeat<FileFolder>(FolderHierarchy.flatten(this.folders).filter(folder =>
          !this.excludedDates.includes(folder.date)))
          .each((entry: RepeatItem<FileFolder>) => {
            ListItem() {
              this.FolderChoiceBuilder(entry.item)
            }
          })
          .key((folder: FileFolder) => folder.date)
          .virtualScroll()
      }
      .scrollBar(BarState.Off)
      .height(240)
      .width('100%')
      DialogButtonBar(
        (): void => { this.controller?.close() },
        (): void => {
          this.controller?.close()
          this.onConfirm?.(this.selectedDate)
        }
      )
    }.padding(20)
  }
}
