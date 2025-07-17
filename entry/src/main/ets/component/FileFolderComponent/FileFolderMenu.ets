import { FileFolder } from '../../interfaces/FileFolderInterface'
import { FileFolderDataSource } from '../../utils/DataUtil'
import { MenuModifier, SymbolGlyphModifier } from '@kit.ArkUI'
import DataSyncUtil from '../../utils/DataSyncUtil'
import { VideoListController } from '../VideoItemComponent/VideoItemComponent'
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'


@Component
export struct FileFolderMenu {
  @Consume fileFolderSource: FileFolderDataSource
  @Consume videoListController: VideoListController
  @Prop video_item: VideoMetadata

  build() {
    Menu() {
      LazyForEach(this.fileFolderSource, (item: FileFolder) => {
        MenuItem({ symbolStartIcon: new SymbolGlyphModifier($r("sys.symbol.folder")), content: item.name })
          .onClick(async () => {
            //批量删除
            if (DataSyncUtil.delMultipleList.length > 0) {
              for (let i = 0; i < DataSyncUtil.delMultipleList.length; i++) {
                  await this.fileFolderSource.addVideoToFileFolder(DataSyncUtil.delMultipleList[i], item,
                  this.videoListController.videoDataSource)
              }
              DataSyncUtil.delMultipleList = []
              this.videoListController.closeMultipleChoose()
            } else if (this.videoListController.multipleChooseState === Visibility.None) { //非批量操作
              await this.fileFolderSource.addVideoToFileFolder(this.video_item, item,
                this.videoListController.videoDataSource)
            }
            this.videoListController.updateData(this.videoListController.videoDataSource, item)
          })
      }, (item: FileFolder) => item.date)
    }.attributeModifier(new MenuModifier())
  }
}