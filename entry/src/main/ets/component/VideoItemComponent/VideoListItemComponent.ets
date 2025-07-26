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
  @State choose: boolean = false

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
              .layoutWeight(1)
              .wordBreak(WordBreak.BREAK_ALL)
            Checkbox({ name: 'check_box: ' + this.index, group: 'checkboxGroup' })
              .width('10%')
              .height(30)
              .select(this.choose)
              .selectedColor($r('app.color.main_color'))
              .shape(CheckBoxShape.CIRCLE)
              .visibility(this.videoListController.multipleChooseState)
          }

          VideoInfoComponent({ item: this.item })
        }.alignItems(HorizontalAlign.Start).padding({ left: 15, right: 15 }).width('90%')
      }.justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height('auto')
    .justifyContent(FlexAlign.SpaceEvenly)
    .zIndex(2)
    .gesture(TapGesture({ count: 1 })
      .onAction((event: GestureEvent) => {
        if (this.choose) {
          DataSyncUtil.delMultipleList = DataSyncUtil.delMultipleList.filter(item => item.date !== this.item.date)
          this.choose = false
        } else {
          DataSyncUtil.delMultipleList.push(this.item)
          this.choose = true
        }
      })
    )
  }
}