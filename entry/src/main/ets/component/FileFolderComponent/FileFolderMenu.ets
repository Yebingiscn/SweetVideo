import { FileFolder } from '../../interfaces/FileFolderInterface'
import { FileFolderDataSource } from '../../utils/DataUtil'
import { MenuModifier, SymbolGlyphModifier } from '@kit.ArkUI'
import DataSyncUtil from '../../utils/DataSyncUtil'
import { VideoListController } from '../VideoItemComponent/VideoItemComponent'
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import FileFolderUtil from '../../utils/FileFolderUtil'
import { PathUtils } from '../../utils/PathUtils'
import { FolderOperator } from '../../database/VideoMetaData'
import { addFileFolderNameDialog } from '../Dialog/AddFileFolderNameDialog'
import { DefaultDialogShadow } from '../../common/DefaultDialogShadow'


@Component
export struct FileFolderMenu {
  @Consume fileFolderSource: FileFolderDataSource
  @Consume videoListController: VideoListController
  @Prop video_item: VideoMetadata
  addFileFolderNameDialogController: CustomDialogController = new CustomDialogController({
    builder: addFileFolderNameDialog(), cornerRadius: 20, shadow: DefaultDialogShadow
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
                folders = FileFolderUtil.addVideosInFileFolder(PathUtils.appContext!, DataSyncUtil.delMultipleList,
                  this.videoListController.folder.date, item.date)
                this.videoListController.closeMultipleChoose()
              } else { //非批量操作
                folders = FileFolderUtil.addVideosInFileFolder(PathUtils.appContext!, [this.video_item],
                  this.videoListController.folder.date, item.date)
                // 处理用户多选但是没有选择而是直接移动的情况
                if (this.videoListController.multipleChooseState === Visibility.Visible) {
                  this.videoListController.closeMultipleChoose()
                }
                // TODO: 这里有个问题没解决：此处移除当前文件夹最后一个视频是，页面提示词未出现
                // 以下是临时解决方案
                this.videoListController.multipleChooseState = Visibility.Hidden
                this.videoListController.closeMultipleChoose()
              }
              this.fileFolderSource.updateData(folders)
              this.videoListController.videoDataSource.updateData(FolderOperator.getFolderByName(this.videoListController.folder.name)
                .video_list)
              this.videoListController.updateData(this.videoListController.videoDataSource,
                this.videoListController.folder)
            })
        }
      }, (item: FileFolder) => item.date + item.name + item.video_list.toString())
    }.attributeModifier(new MenuModifier())
  }
}