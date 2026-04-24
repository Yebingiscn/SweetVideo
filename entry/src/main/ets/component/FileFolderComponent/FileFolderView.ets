import { FileFolder } from '../../interfaces/FileFolderInterface'
import { FileFolderDataSource, VideoDataSource } from '../../utils/DataUtil'
import { SideBarController } from '../SideBarComponent/SideBar'
import { VideoListController } from '../VideoItemComponent/VideoItemComponent'
import { SymbolGlyphModifier } from '@kit.ArkUI'
import DataSyncUtil from '../../utils/DataSyncUtil'
import { PathUtils } from '../../utils/PathUtils'
import FileFolderUtil from '../../utils/FileFolderUtil'
import ToolsUtil from '../../utils/ToolsUtil'
import { EditFileFolderNameDialog } from '../../component/Dialog/EditFileFolderNameDialog'
import { FileFolderListBuilder } from './FileFolderListComponent'
import { DeleteType } from '../../common/enum/DeleteType'
import { DefaultDialogShadow, MenuFancyModifier } from '../../common/AttributeModifierConfig'
import { InfoConfirmDialog } from '../../component/Dialog/InfoConfirmDialog'

@ComponentV2
export struct FileFolderView {
  @Consumer() fileFolderSource: FileFolderDataSource = new FileFolderDataSource([])
  editFileFolderNameDialogController: CustomDialogController = new CustomDialogController({
    builder: EditFileFolderNameDialog({
      confirm: async (file_folder: string | undefined) => {
        if (!file_folder || file_folder.trim() == '') {
          return
        }
        await FileFolderUtil.changeFileFolderName(PathUtils.appContext!,
          DataSyncUtil.editingFolder!,
          file_folder, this.fileFolderSource)
      }
    }), cornerRadius: 20, shadow: DefaultDialogShadow
  })
  @Local fileFolderList: FileFolder[] = this.fileFolderSource.getAllData()
  @Consumer() videoListController: VideoListController = new VideoListController()
  @Consumer() sideBarController: SideBarController = new SideBarController()
  @Local folderDeleteConfirmText: ResourceStr = ''
  delConfirmDialog: CustomDialogController = new CustomDialogController({
    builder: InfoConfirmDialog({
      textInfo: this.folderDeleteConfirmText,
      confirm: async () => {
        const folderToDelete = DataSyncUtil.editingFolder
        if (!folderToDelete) {
          return
        }
        const videosToDelete = Array.from(folderToDelete.video_list)
        const deletePromises = videosToDelete.map(async item => {
          await this.videoListController.videoDataSource.deleteItem(DeleteType.SOFT, item)
        })
        await Promise.all(deletePromises)
        this.fileFolderSource.deleteData(this.fileFolderList.findIndex(i => i.date === folderToDelete.date))
        this.fileFolderList = FileFolderUtil.deleteFileFolder(PathUtils.appContext!, folderToDelete)
        this.videoListController.videoDataSource.refreshData(this.videoListController.folder)
      }
    }), cornerRadius: 20, shadow: DefaultDialogShadow
  })

  build() {
    List() {
      LazyForEach(this.fileFolderSource, (item: FileFolder) => {
        ListItem() {
          FileFolderListBuilder({
            folder: item,
            videoListController: this.videoListController
          })
        }
        .onClick(() => {
          const video_list = item.video_list || []
          this.videoListController.updateData(new VideoDataSource(video_list), item)
          this.sideBarController.close(true)
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
        .onClick(() => {
          DataSyncUtil.editingFolder = file_folder
          this.folderDeleteConfirmText = `确定要删除文件夹 "${file_folder.name}" 吗？\n其中包含 ${file_folder.video_list.length} 个视频。`
          this.delConfirmDialog.open()
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.rename')),
        content: $r('app.string.edit')
      }).onClick(() => {
        DataSyncUtil.editingFolder = file_folder
        this.editFileFolderNameDialogController.open()
      })
    }.attributeModifier(new MenuFancyModifier).onAppear(() => {
      ToolsUtil.startVibration()
    })
  }
}