import { FileFolder } from '../../interfaces/FileFolderInterface'
import { FileFolderDataSource } from '../../utils/DataUtil'
import { MenuModifier, SymbolGlyphModifier } from '@kit.ArkUI'
import DataSyncUtil from '../../utils/DataSyncUtil'
import { VideoListController } from '../VideoItemComponent/VideoItemComponent'
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import FileFolderUtil from '../../utils/FileFolderUtil'
import { PathUtils } from '../../utils/PathUtils'
import { FolderOperator } from '../../database/VideoMetaData'


@Component
export struct FileFolderMenu {
  @Consume fileFolderSource: FileFolderDataSource
  @Consume videoListController: VideoListController
  @Prop video_item: VideoMetadata

  build() {
    Menu() {
      LazyForEach(this.fileFolderSource, (item: FileFolder) => {
        if (item.name !== this.videoListController.folder.name) {
          MenuItem({ symbolStartIcon: new SymbolGlyphModifier($r("sys.symbol.folder")), content: item.name })
            .onClick(async () => {
              //批量删除
              let folders: FileFolder[] = []
              if (DataSyncUtil.delMultipleList.length > 0) {
                DataSyncUtil.delMultipleList.forEach(video => {
                  DataSyncUtil.editingVideo = JSON.stringify(video);
                  folders = FileFolderUtil.addVideoInFileFolder(PathUtils.appContext!, video,
                    this.videoListController.folder.date,
                    item.date, this.videoListController.videoDataSource)
                });
                DataSyncUtil.delMultipleList = []
                this.videoListController.closeMultipleChoose()
              } else if (this.videoListController.multipleChooseState === Visibility.None) { //非批量操作
                folders = FileFolderUtil.addVideoInFileFolder(PathUtils.appContext!, this.video_item,
                  this.videoListController.folder.date, item.date, this.videoListController.videoDataSource)
              }
              this.fileFolderSource.updateData(folders)
              this.videoListController.videoDataSource.updateData(FolderOperator.getFolderByName(this.videoListController.folder.name)
                .video_list)
              this.videoListController.updateData(this.videoListController.videoDataSource,
                this.videoListController.folder)
            })
        }
      }, (item: FileFolder) => item.date)
    }.attributeModifier(new MenuModifier())
  }
}