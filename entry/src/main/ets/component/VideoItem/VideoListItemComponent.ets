import { PathUtils } from '../../utils/PathUtils';
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface';
import { fileUri, fileIo as fs } from '@kit.CoreFileKit';
import { ImageFancyModifier } from '../../utils/AttributeModifierUtil';
import VideoInfoUtil from '../../utils/VideoInfoUtil';
import DataSyncUtil, { OOBEVersion } from '../../utils/DataSyncUtil';
import { VideoInfoComponent } from '../../component/VideoInfoComponent';

@Component
export default struct VideoListItem {
  @Prop item: VideoMetadata
  @Prop video_meta_data_list: VideoMetadata[]
  @Prop index: number
  @Prop multipleChooseState: Visibility
  @Prop itemMultipleChoose: boolean

  build() {
    Column() {
      Row() {
        Image(fileUri.getUriFromPath(PathUtils.coverPath + this.item.date))
          .attributeModifier(new ImageFancyModifier(10, 60, 90))
        Column() {
          Row() {
            Text(VideoInfoUtil.getVideoTitle(this.video_meta_data_list, this.item))
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .maxLines(3)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width(this.multipleChooseState === Visibility.None ? '90%' : '75%')
              .wordBreak(WordBreak.BREAK_ALL)
            Checkbox({ name: 'check_box: ' + this.index, group: 'checkboxGroup' })
              .width(30)
              .height(30)
              .select(this.itemMultipleChoose)
              .selectedColor($r('app.color.main_color'))
              .shape(CheckBoxShape.CIRCLE)
              .visibility(this.multipleChooseState)
              .onChange((value: boolean) => {
                if (!this.itemMultipleChoose || !value) {
                  if (this.item) {
                    const delSet = new Set(DataSyncUtil.delMultipleList as VideoMetadata[]);
                    value ? delSet.add(this.item) : delSet.delete(this.item);
                    DataSyncUtil.delMultipleList = Array.from(delSet);
                  }
                }
              })
          }

          VideoInfoComponent({ item: this.item })
            .reuseId(this.item.date)
        }.alignItems(HorizontalAlign.Start).padding({ left: 15, right: 15 }).width('90%')
      }.justifyContent(FlexAlign.Center)
    }
    .height(100)
    .justifyContent(FlexAlign.SpaceEvenly)
  }
}