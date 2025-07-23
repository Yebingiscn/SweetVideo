import { PathUtils } from '../../utils/PathUtils';
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface';
import { fileUri } from '@kit.CoreFileKit';
import { ImageFancyModifier } from '../../utils/AttributeModifierUtil';
import VideoInfoUtil from '../../utils/VideoInfoUtil';
import DataSyncUtil from '../../utils/DataSyncUtil';
import { VideoListController } from './VideoItemComponent';
import { VideoInfoComponent } from './VideoInfoComponent';

@Reusable
@Component
export default struct VideoListItem {
  @Prop item: VideoMetadata
  @Prop index: number
  @Consume videoListController: VideoListController

  // 实现组件复用回调
  aboutToReuse(params: Record<string, Object>): void {
    this.item = params.item as VideoMetadata;
  }

  build() {
    Column() {
      Row() {
        Image(fileUri.getUriFromPath(PathUtils.coverPath + this.item.date))
          .attributeModifier(new ImageFancyModifier(10, 64, 96))
        Column() {
          Row() {
            Text(VideoInfoUtil.getVideoTitle(this.videoListController.videoDataSource.getAllData(), this.item))
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .maxLines(3)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('75%')// .width(this.videoListController.multipleChooseState === Visibility.None ? '90%' : '75%')
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

          VideoInfoComponent({ item: this.item })
        }.alignItems(HorizontalAlign.Start).padding({ left: 15, right: 15 }).width('90%')
      }.justifyContent(FlexAlign.Center)
    }
    .height('auto')
    .justifyContent(FlexAlign.SpaceEvenly)
  }
}