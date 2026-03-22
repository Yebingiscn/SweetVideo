import { VideoMetadata } from '../../interfaces/VideoMetadataInterface';

@Builder
export function VideoItemPreviewBuilder(item: VideoMetadata) {
  Column() {
    // 封面图区域：固定 16:9 宽高比
    Image(fileUri.getUriFromPath(PathUtils.coverPath + item.date))
      .attributeModifier(new ImageFancyModifier({
        topLeft: 16,
        topRight: 16,
        bottomLeft: 16,
        bottomRight: 16
      }, '', ''))
      .width('100%')
      .height('auto')
      .aspectRatio(16 / 9)
      .objectFit(ImageFit.Cover)
      .clip(true)
    // 标题区域
    Text(VideoInfoUtil.getVideoTitle(item))
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
    VideoInfoBuilder({ item: item, showProgress: true })
  }
  .width('100%')
  .height('auto')
  .backgroundColor($r('app.color.start_window_background'))
  .borderRadius(16)
  .padding({ bottom: 25 })
}