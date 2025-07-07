import { PathUtils } from '../../utils/PathUtils';
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface';
import { fileUri, fileIo as fs } from '@kit.CoreFileKit';
import { ImageFancyModifier } from '../../utils/AttributeModifierUtil';
import VideoInfoUtil from '../../utils/VideoInfoUtil';
import DataSyncUtil, { OOBEVersion } from '../../utils/DataSyncUtil';
import { VideoInfoComponent } from '../../component/VideoInfoComponent';
import { VideoListController } from '.';

@Component
export default struct VideoCardItem {
  @Prop item: VideoMetadata
  @Prop index: number
  @Prop videoListController: VideoListController


  build() {
    Column() {
      Image(fileUri.getUriFromPath(PathUtils.coverPath + this.item.date))
        .attributeModifier(new ImageFancyModifier({
          topLeft: 10,
          topRight: 10,
          bottomLeft: 10,
          bottomRight: 10
        }, 60, 200))
        .width('100%')
        .objectFit(ImageFit.Auto)
      Column() {
        Row() {
          Text(VideoInfoUtil.getVideoTitle(this.videoListController.video_meta_data_list, this.item))
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .maxLines(1)// 减少行数以适应卡片布局
            .textAlign(TextAlign.Center)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)// 占据剩余空间
            .wordBreak(WordBreak.BREAK_ALL)
          Checkbox({ name: 'check_box: ' + this.index, group: 'checkboxGroup' })
            .width(30)
            .height(30)
            .select(this.videoListController.itemMultipleChoose)
            .selectedColor($r('app.color.main_color'))
            .shape(CheckBoxShape.CIRCLE)
            .visibility(this.videoListController.multipleChooseState)
            .onChange((value: boolean) => {
              if (!this.videoListController.itemMultipleChoose || !value) {
                if (this.item) {
                  const delSet = new Set(DataSyncUtil.delMultipleList as VideoMetadata[]);
                  value ? delSet.add(this.item) : delSet.delete(this.item);
                  DataSyncUtil.delMultipleList = Array.from(delSet);
                }
              }
            })
        }
        .width('100%')
        .padding({ top: 5 })

        VideoInfoComponent({ item: this.item })
          .reuseId(this.item.date)
      }.padding({ left: 5, right: 5, bottom: 5 })
      .width('100%')
    }
    .width('100%')
    .height('auto')
    .backgroundColor($r('app.color.start_window_background_blur'))
    .borderRadius(10)
  }
}