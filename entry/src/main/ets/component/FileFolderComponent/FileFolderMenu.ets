import { FileFolderDataSource } from '../../utils/DataUtil'
import { VideoListController } from '../VideoItemComponent/VideoItemComponent'
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import { AddFileFolderNameDialog } from '../Dialog/AddFileFolderNameDialog'
import { DefaultDialogShadow, MenuFancyModifier } from '../../common/AttributeModifierConfig'
import { FolderOperator } from '../../database/VideoMetaData'
import { FileFolder } from '../../interfaces/FileFolderInterface'
import DataSyncUtil from '../../utils/DataSyncUtil'
import FileFolderUtil from '../../utils/FileFolderUtil'
import { PathUtils } from '../../utils/PathUtils'
import VideoUtils from '../../utils/VideoUtil'
import { SymbolGlyphModifier } from '@kit.ArkUI'


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
        content: '添加文件夹'
      }).onClick(() => {
        this.addFileFolderNameDialogController?.open()
      })
      Repeat<FileFolder>(this.fileFolderSource.data)
        .each((repeatItem: RepeatItem<FileFolder>) => {
          if (repeatItem.item.date !== this.videoListController.folder.date) {
            MenuItem(
              { symbolStartIcon: new SymbolGlyphModifier($r("sys.symbol.folder")), content: repeatItem.item.name })
              .onClick(async () => {
                let folders: FileFolder[] = []
                if (DataSyncUtil.delMultipleList.length > 0) {
                  folders =
                    FileFolderUtil.transferVideosToFileFolder(PathUtils.appContext!, DataSyncUtil.delMultipleList,
                      this.videoListController.folder.date, repeatItem.item.date)
                } else {
                  folders = FileFolderUtil.transferVideosToFileFolder(PathUtils.appContext!, [this.video_item!],
                    this.videoListController.folder.date, repeatItem.item.date)
                }
                this.file_folder_list = folders
                this.videoListController.videoDataSource.updateData(
                  FolderOperator.getFolderByName(this.videoListController.folder.name)
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