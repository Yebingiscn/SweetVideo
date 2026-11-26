import { ImageFancyModifier } from '../../common/AttributeModifierConfig';
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface';
import { PathUtils } from '../../utils/PathUtils';
import VideoInfoUtil from '../../utils/VideoInfoUtil';
import { VideoInfoBuilder } from './VideoInfoBuilder';

@Builder
export function VideoItemPreviewBuilder(item: VideoMetadata) {
  Column() {
    // 标题和媒体信息优先占用空间，封面填满剩余高度。
    Image(PathUtils.coverUri(item.date))
      .attributeModifier(new ImageFancyModifier({
        topLeft: 12,
        topRight: 12,
        bottomLeft: 0,
        bottomRight: 0
      }, '', ''))
      .width('100%')
      .layoutWeight(1)
      .objectFit(ImageFit.Cover)
      .clip(true)
    // 标题区域
    Text(VideoInfoUtil.getVideoTitle(item?.title))
      .fontSize(15)
      .fontWeight(FontWeight.Bold)
      .maxLines(5)
      .textAlign(TextAlign.Start)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .wordBreak(WordBreak.BREAK_ALL)
      .padding({ left: 5, right: 5, top: 10 })
      .width('100%')
      .height('auto')
    // 视频信息
    VideoInfoBuilder({ item: item })
  }
  .width('100%')
  .height(256)
  .padding({ bottom: 12 })
  .constraintSize({ maxWidth: 360 })
  .backgroundColor($r('app.color.start_window_background'))
  .borderRadius(12)
}
