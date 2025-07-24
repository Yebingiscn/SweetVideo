import { VideoMetadata } from '../../interfaces/VideoMetadataInterface';
import { ImageFancyModifier } from '../../utils/AttributeModifierUtil';
import { media } from '@kit.MediaKit';
import VideoInfoUtil from '../../utils/VideoInfoUtil';
import TimeUtil from '../../utils/TimeUtil';

@Component
@Reusable
  // 启用组件复用
export struct VideoInfoComponent {
  @Prop item: VideoMetadata | undefined = undefined


  build() {
    Row() {
      // HDR类型图标
      if (this.item?.hdr_type === media.HdrType.AV_HDR_TYPE_VIVID) {
        Image($r("app.media.hdr_vivid_icon"))
          .attributeModifier(new ImageFancyModifier(10, 65, 25))
      }
      // 分辨率显示逻辑
      else {
        if (VideoInfoUtil.videoWidthAndHeightFormat(this.item!.size.toString()).includes('HD')) {
          Text(VideoInfoUtil.videoWidthAndHeightFormat(this.item!.size.toString()))
            .fontWeight(FontWeight.Bold)
            .fontSize(10)
            .opacity(0.8)
            .backgroundColor('rgba(255, 189, 0, 0.4)')
            .padding(5)
            .borderRadius(10)
        } else if (VideoInfoUtil.videoWidthAndHeightFormat(this.item!.size.toString()) === '0 x 0') {
          Text($r('app.string.unknown_resolution'))
            .fontSize(10)
            .opacity(0.8)
            .backgroundColor('#808080')
            .padding(5)
            .borderRadius(10)
        } else {
          Text(VideoInfoUtil.videoWidthAndHeightFormat(this.item!.size.toString()))
            .fontSize(15)
            .opacity(0.8)
        }
      }
      // 时长显示
      Text("  " + TimeUtil.convertMSToMMSS(this.item!.time))
        .fontSize(15)
        .opacity(0.8)
    }
    .justifyContent(FlexAlign.Start)
    .padding({ top: 5 }).width('100%')
  }
}