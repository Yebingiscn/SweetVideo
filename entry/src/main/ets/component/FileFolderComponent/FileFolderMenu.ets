import { FileFolder } from '../../interfaces/FileFolderInterface'
import { FileFolderDataSource } from '../../utils/DataUtil'
import { SymbolGlyphModifier } from '@kit.ArkUI'
import DataSyncUtil from '../../utils/DataSyncUtil'
import { VideoListController } from '../VideoItemComponent/VideoItemComponent'
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import FileFolderUtil from '../../utils/FileFolderUtil'
import { PathUtils } from '../../utils/PathUtils'
import { FolderOperator } from '../../database/VideoMetaData'
import { AddFileFolderNameDialog } from '../Dialog/AddFileFolderNameDialog'
import { DefaultDialogShadow } from '../../common/DefaultDialogShadow'
import VideoUtils from '../../utils/VideoUtil'
import { MenuFancyModifier } from '../../utils/AttributeModifierUtil'


@Component
export struct FileFolderMenu {
  @Consume fileFolderSource: FileFolderDataSource
  @Consume videoListController: VideoListController
  @Prop video_item: VideoMetadata
  addFileFolderNameDialogController: CustomDialogController = new CustomDialogController({
    builder: AddFileFolderNameDialog(), cornerRadius: 20, shadow: DefaultDialogShadow
  })

  build() {
    Menu() {
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.folder_badge_plus')),
        content: '添加文件夹'
      }).onClick(() => {
        this.addFileFolderNameDialogController.open()
      })
      LazyForEach(this.fileFolderSource, (item: FileFolder) => {
        if (item.date !== this.videoListController.folder.date) {
          MenuItem({ symbolStartIcon: new SymbolGlyphModifier($r("sys.symbol.folder")), content: item.name })
            .onClick(async () => {
              //批量移动
              let folders: FileFolder[] = []
              if (DataSyncUtil.delMultipleList.length > 0) {
                folders = FileFolderUtil.transferVideosToFileFolder(PathUtils.appContext!, DataSyncUtil.delMultipleList,
                  this.videoListController.folder.date, item.date)
              } else { //非批量操作
                folders = FileFolderUtil.transferVideosToFileFolder(PathUtils.appContext!, [this.video_item],
                  this.videoListController.folder.date, item.date)
              }
              this.fileFolderSource.updateData(folders)
              this.videoListController.videoDataSource.updateData(FolderOperator.getFolderByName(this.videoListController.folder.name)
                .video_list)
              this.videoListController.updateData(this.videoListController.videoDataSource,
                this.videoListController.folder)

              VideoUtils.refresh(this.videoListController, this.fileFolderSource, this.videoListController.folder)
              this.videoListController.closeMultipleChoose()
            })
        }
      }, (item: FileFolder) => item.date + item.name + item.video_list.toString())
    }.attributeModifier(new MenuFancyModifier())
  }
}