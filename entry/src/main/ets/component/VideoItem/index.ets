import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import VideoCardItem from './VideoCardItemComponent'
import VideoListItem from './VideoListItemComponent'



@Component
export default struct VideoItem {
  @Prop item: VideoMetadata
  @Prop video_meta_data_list: VideoMetadata[]
  @Prop index: number
  @Prop multipleChooseState: Visibility
  @Prop itemMultipleChoose: boolean
  @StorageLink('is_list_display') is_list_display: boolean = false

  build() {
    Row() {
      if (this.is_list_display) {
        VideoListItem({
          item: this.item,
          video_meta_data_list: this.video_meta_data_list,
          index: this.index,
          multipleChooseState: this.multipleChooseState,
          itemMultipleChoose: this.itemMultipleChoose
        })
      } else {
        VideoCardItem({
          item: this.item,
          video_meta_data_list: this.video_meta_data_list,
          index: this.index,
          multipleChooseState: this.multipleChooseState,
          itemMultipleChoose: this.itemMultipleChoose
        })
      }
    }
    .padding({
      left: 10,
      right: 10,
      top: 5,
      bottom: 5
    })
  }
}