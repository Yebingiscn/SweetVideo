import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import TimeUtil from '../../utils/TimeUtil'
import VideoInfoUtil from '../../utils/VideoInfoUtil'
import { media } from '@kit.MediaKit'

class VideoInfoBuilderParams {
  item: VideoMetadata | undefined = undefined
  nowPlaying?: VideoMetadata | undefined = undefined
}

@Builder
export function VideoInfoBuilder(params: VideoInfoBuilderParams) {
  Row() {
    if (params.item?.hdr_type === media.HdrType.AV_HDR_TYPE_VIVID) {
      Row() {
        SymbolGlyph($r('sys.symbol.hdr'))
          .fontSize(14)
          .fontColor([$r('sys.color.white')])

        Text('HDR Vivid')
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.white'))  // 文字固定黑色，确保高对比
          .margin({ left: 2 }) // 图标与文字间距
      }
      .padding({
        left: 5,
        right: 5,
        top: 2,
        bottom: 2
      })
      .linearGradient({
        direction: GradientDirection.Right, // 渐变方向
        repeating: false,
        colors: [['#ef2f4e', 0.0], ['#d53b61', 0.3], ['#954e89', 0.5], ['#4766bd', 0.7],
          ['#1677dc', 0.9]]
      })
      .borderRadius(8)
      .alignItems(VerticalAlign.Center)
      .width('auto')
      .height(22)
    } else if (VideoInfoUtil.videoWidthAndHeightFormat(params.item!.size.toString()).includes('HD')) {
      Text(VideoInfoUtil.videoWidthAndHeightFormat(params.item!.size.toString()) +
        (params.item!.frame_rate >= 60 ? ` ${params.item!.frame_rate} fps` : ''))
        .height(22)
        .fontWeight(FontWeight.Bold)
        .fontSize(10)
        .opacity(0.8)
        .backgroundColor('#de9e44')
        .fontColor($r('sys.color.black'))
        .padding({
          left: 5,
          right: 5,
          top: 2,
          bottom: 2
        })
        .borderRadius(8)
        .textAlign(TextAlign.Center)
    } else if (VideoInfoUtil.videoWidthAndHeightFormat(params.item!.size.toString()) === '0 x 0') {
      Text($r('app.string.unknown_resolution'))
        .height(22)
        .fontSize(10)
        .opacity(0.8)
        .backgroundColor('#c1b2a3')
        .fontColor($r('sys.color.black'))
        .padding({
          left: 5,
          right: 5,
          top: 2,
          bottom: 2
        })
        .borderRadius(8)
        .textAlign(TextAlign.Center)
    } else {
      Text(VideoInfoUtil.videoWidthAndHeightFormat(params.item!.size.toString()))
        .fontSize(15)
        .opacity(0.8)
        .fontColor(params.nowPlaying && params.nowPlaying?.date === params.item?.date ?
          $r('sys.color.white') : $r('app.color.text_color'))
    }

    Text("  " + TimeUtil.convertMSToHHMMSS(params.item!.time))
      .fontSize(15)
      .opacity(0.8)
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .fontColor(params.nowPlaying && params.nowPlaying?.date === params.item?.date ?
        $r('sys.color.white') : $r('app.color.text_color'))

    Progress({ value: params.item?.last_play, total: params.item?.time, type: ProgressType.Ring })
      .width(30)
      .height(30)
      .flexShrink(0)
      .color($r('app.color.main_color'))
      .style({ strokeWidth: 5, shadow: true, enableSmoothEffect: true })
  }
  .justifyContent(FlexAlign.Start)
  .alignItems(VerticalAlign.Center)
  .width('100%')
  .height('auto')
  .padding({
    right: 10,
    left: 5,
    top: 4,
    bottom: 4
  })
}