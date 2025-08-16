import { VideoMetadata } from '../../interfaces/VideoMetadataInterface';
import { ImageFancyModifier } from '../../utils/AttributeModifierUtil';
import { media } from '@kit.MediaKit';
import VideoInfoUtil from '../../utils/VideoInfoUtil';
import TimeUtil from '../../utils/TimeUtil';

@Component
@Reusable
export struct VideoInfoComponent {
  @Prop item: VideoMetadata | undefined = undefined

  build() {
    Row() {
      // HDR类型图标
      if (this.item?.hdr_type === media.HdrType.AV_HDR_TYPE_VIVID) {
        Image($r("app.media.hdr_vivid_icon"))
          .attributeModifier(new ImageFancyModifier(8, 65, 25))
          .height(22) // 统一高度
      }
      // 分辨率显示逻辑
      else {
        if (VideoInfoUtil.videoWidthAndHeightFormat(this.item!.size.toString()).includes('HD')) {
          Text(VideoInfoUtil.videoWidthAndHeightFormat(this.item!.size.toString()))
            .height(22)// 统一高度
            .fontWeight(FontWeight.Bold)
            .fontSize(10)
            .opacity(0.8)
            .backgroundColor('#de9e44')
            .fontColor($r('sys.color.black'))
            .padding(5)
            .borderRadius(8)
        } else if (VideoInfoUtil.videoWidthAndHeightFormat(this.item!.size.toString()) === '0 x 0') {
          Text($r('app.string.unknown_resolution'))
            .height(22)// 统一高度
            .fontSize(10)
            .opacity(0.8)
            .backgroundColor('#c1b2a3')
            .fontColor($r('sys.color.black'))
            .padding(5)
            .borderRadius(8)
        } else {
          Text(VideoInfoUtil.videoWidthAndHeightFormat(this.item!.size.toString()))
            .fontSize(15)
            .opacity(0.8)
        }
      }

      Text("  " + TimeUtil.convertMSToHHMMSS(this.item!.time))
        .fontSize(15)
        .opacity(0.8)

      Progress({ value: this.item?.last_play, total: this.item?.time, type: ProgressType.Ring })
        .width(30).color($r('app.color.main_color')).height(30)
        .style({ strokeWidth: 5, shadow: true, enableSmoothEffect: true })
    }
    .justifyContent(FlexAlign.Start)
    .width('100%')
    .height(32) // 固定行高
    .padding({ top: 5, right: 10 })
  }
}