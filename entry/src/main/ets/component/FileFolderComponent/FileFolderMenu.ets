import { FileFolderDataSource } from '../../utils/DataUtil'
import { VideoListController } from '../../controller/VideoListController'
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import { FileFolder } from '../../interfaces/FileFolderInterface'
import { DefaultDialogShadow, MenuFancyModifier } from '../../common/AttributeModifierConfig'
import { FolderOperator } from '../../database/VideoMetaData'
import DataSyncUtil from '../../utils/DataSyncUtil'
import FileFolderUtil from '../../utils/FileFolderUtil'
import { PathUtils } from '../../utils/PathUtils'
import VideoUtils from '../../utils/VideoUtil'
import { AddFileFolderNameDialog } from '../Dialog/AddFileFolderNameDialog'
import { SymbolGlyphModifier } from '@kit.ArkUI'
import ToolsUtil from '../../utils/ToolsUtil'
import { salmonLogger } from 'salmonlogger'


@ComponentV2
export struct FileFolderMenu {
  @Consumer() fileFolderSource: FileFolderDataSource = new FileFolderDataSource([])
  @Consumer() file_folder_list: FileFolder[] = []
  @Consumer() videoListController: VideoListController = new VideoListController()
  @Param video_item: VideoMetadata | undefined = undefined
  addFileFolderNameDialogController?: CustomDialogController

  aboutToAppear(): void {
    this.addFileFolderNameDialogController = new CustomDialogController({
      builder: AddFileFolderNameDialog({
        onFolderAdded: (folders: FileFolder[]) => {
          this.file_folder_list = folders
        }
      }), cornerRadius: 20, shadow: DefaultDialogShadow
    })
  }

  build() {
    Menu() {
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.folder_badge_plus')),
        content: $r('app.string.add_folder')
      }).onClick(() => {
        this.addFileFolderNameDialogController?.open()
      })
      Repeat<FileFolder>(FileFolderUtil.flattenTree(this.file_folder_list))
        .each((repeatItem: RepeatItem<FileFolder>) => {
          if (repeatItem.item.date !== this.videoListController.folder.date) {
            MenuItem(
              {
                symbolStartIcon: new SymbolGlyphModifier($r("sys.symbol.folder")),
                content: repeatItem.item.name
              })
              .onClick(() => {
                const videos = DataSyncUtil.delMultipleList.length > 0 ? DataSyncUtil.delMultipleList : [this.video_item!]
                let folders: FileFolder[]
                try {
                  folders = FileFolderUtil.transferVideosToFileFolder(PathUtils.appContext!, videos,
                    this.videoListController.folder.date, repeatItem.item.date)
                } catch (_error) {
                  salmonLogger.addLog('FileFolderMenu', 'Could not move the selected videos', true)
                  ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.library_operation_failed').id))
                  return
                }
                this.file_folder_list = folders
                this.videoListController.videoDataSource.updateData(
                  FolderOperator.getFolderByDate(this.videoListController.folder.date)!
                    .video_list)
                this.videoListController.updateData(this.videoListController.videoDataSource,
                  this.videoListController.folder)

                VideoUtils.refresh(this.videoListController, this.fileFolderSource, this.videoListController.folder)
                this.videoListController.closeMultipleChoose()
              })
          }
        })
        .key((item: FileFolder) => item.date + item.name + item.video_list.toString())
    }.attributeModifier(new MenuFancyModifier())
  }
}
