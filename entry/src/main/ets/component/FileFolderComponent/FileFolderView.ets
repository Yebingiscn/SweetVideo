import { FileFolder } from '../../interfaces/FileFolderInterface'
import { FileFolderDataSource, VideoDataSource } from '../../utils/DataUtil'
import { SideBarController } from '../SideBarComponent/SideBar'
import { VideoListController } from '../VideoItemComponent/VideoItemComponent'
import { MenuModifier, SymbolGlyphModifier } from '@kit.ArkUI'
import DataSyncUtil from '../../utils/DataSyncUtil'
import { PathUtils } from '../../utils/PathUtils'
import FileFolderUtil from '../../utils/FileFolderUtil'
import ToolsUtil from '../../utils/ToolsUtil'
import { editFileFolderNameDialog } from '../../component/Dialog/EditFileFolderNameDialog'
import { DefaultDialogShadow } from '../../common/DefaultDialogShadow'
import { FileFolderListComponent } from './FileFolderListComponent'

@Component
export struct FileFolderView {
  @Consume fileFolderSource: FileFolderDataSource
  @Consume videoListController: VideoListController
  @Consume sideBarController: SideBarController
  @State fileFolderList: FileFolder[] = this.fileFolderSource.getAllData()
  editFileFolderNameDialogController: CustomDialogController = new CustomDialogController({
    builder: editFileFolderNameDialog({
      confirm: async (file_folder: string | undefined) => {
        if (!file_folder || file_folder.trim() == '') {
          return
        }
        this.fileFolderList =
          await FileFolderUtil.changeFileFolderName(PathUtils.appContext!,
            JSON.parse(DataSyncUtil.editingVideo) as FileFolder,
            file_folder)
        this.fileFolderSource.updateData(this.fileFolderList)
      }
    }), cornerRadius: 20, shadow: DefaultDialogShadow
  })

  build() {
    List() {
      LazyForEach(this.fileFolderSource, (item: FileFolder) => {
        ListItem() {
          FileFolderListComponent({
            folder: item
          })
        }
        .onClick(() => {
          const video_list = item.video_list || []
          this.videoListController.updateData(new VideoDataSource(video_list), item)
          this.sideBarController.closeSideBar(true)
        })
        .bindContextMenu(this.FileFolderSelectMenu(item), ResponseType.LongPress)
        .bindContextMenu(this.FileFolderSelectMenu(item), ResponseType.RightClick)
        .height(60)
      }, (item: FileFolder) => item.date)
    }
    .borderRadius(16)
    .width('100%')
    .height('auto')
    .align(Alignment.Start)
    .margin({ top: 10 })
    .backgroundColor($r('app.color.start_window_background_blur'))
    .cachedCount(2)
  }

  @Builder
  FileFolderSelectMenu(file_folder: FileFolder) {
    Menu() {
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r("sys.symbol.trash_fill")),
        content: $r('app.string.delete')
      })
        .onClick(async () => {
          DataSyncUtil.delMultipleList = Array.from(file_folder.video_list);
          const deletePromises = DataSyncUtil.delMultipleList.map(item => {
            return new Promise<void>((resolve, reject) => {
              DataSyncUtil.editingVideo = JSON.stringify(item);
              this.videoListController.videoDataSource.deleteItem(resolve, reject);
              this.videoListController.closeMultipleChoose()
            });
          });
          await Promise.all(deletePromises)
          this.fileFolderSource.deleteData(this.fileFolderList.findIndex(i => i.date === file_folder.date))
          this.fileFolderList = FileFolderUtil.deleteFileFolder(PathUtils.appContext!, file_folder)
          this.videoListController.videoDataSource.refreshData(this.videoListController.folder)
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.rename')),
        content: $r('app.string.edit')
      }).onClick(() => {
        DataSyncUtil.editingVideo = JSON.stringify(file_folder);
        this.editFileFolderNameDialogController.open()
      })
    }.attributeModifier(new MenuModifier).onAppear(() => {
      ToolsUtil.startVibration()
    })
  }
}