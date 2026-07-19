import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import TimeUtil from '../../utils/TimeUtil'
import VideoInfoUtil from '../../utils/VideoInfoUtil'
import { AUDIO_TYPE, VIDEO_HDR_TYPE } from '../../common/enum/HDR_TYPE'
import { GradientTagBuilder, SolidColorTagBuilder } from '../common/MediaTagBuilder'

class VideoInfoBuilderParams {
  item: VideoMetadata | undefined = undefined
  nowPlaying?: VideoMetadata | undefined = undefined
}

@Builder
export function VideoInfoBuilder(params: VideoInfoBuilderParams) {
  Column() {
    Row() {
      if (params.item?.hdr_type === VIDEO_HDR_TYPE.HDR_VIVID) {
        GradientTagBuilder({ symbol: $r('sys.symbol.hdr'), label: 'HDR Vivid' })
      } else if (params.item?.hdr_type === VIDEO_HDR_TYPE.DOLBY_VISION) {
        SolidColorTagBuilder({ symbol: $r('sys.symbol.dolby_fill'), label: 'DOLBY VISION', symbolSize: 16 })
      } else if (params.item?.hdr_type === VIDEO_HDR_TYPE.HDR10) {
        SolidColorTagBuilder({
          label: 'HDR 10',
          textColor: $r('sys.color.black'),
          bgColor: '#de9e44',
          opacity: 0.9
        })
      }

      if (params.item?.audio_type === AUDIO_TYPE.AUDIO_VIVID) {
        GradientTagBuilder({ symbol: $r('sys.symbol.hdr'), label: 'AUDIO Vivid' })

      } else if (params.item?.audio_type === AUDIO_TYPE.DOLBY_AUDIO) {
        SolidColorTagBuilder({
          symbol: $r('sys.symbol.dolby_fill'),
          label: 'DOLBY AUDIO',
          symbolSize: 16,

        })
      } else if (params.item?.audio_type === AUDIO_TYPE.DTS) {
        SolidColorTagBuilder({ symbol: $r('sys.symbol.dts_circle'), label: 'DTS', bgColor: '#dd403d' })
      }

      if (!params.item?.hdr_type && !params.item?.audio_type) {
        if (VideoInfoUtil.videoWidthAndHeightFormat(params.item!.size.toString()).includes('HD')) {
          SolidColorTagBuilder({
            label: VideoInfoUtil.videoWidthAndHeightFormat(params.item!.size.toString()) +
              (params.item!.frame_rate >= 60 ? ` ${params.item!.frame_rate} fps` : ''),
            textColor: $r('sys.color.black'),
            bgColor: '#de9e44',
            opacity: 0.9
          })
        } else if (VideoInfoUtil.videoWidthAndHeightFormat(params.item!.size.toString()) === '0 x 0') {
          SolidColorTagBuilder({
            label: $r('app.string.unknown_resolution'),
            textColor: $r('sys.color.black'),
            bgColor: '#c1b2a3',
            opacity: 0.9
          })
        } else {
          Text(VideoInfoUtil.videoWidthAndHeightFormat(params.item!.size.toString()))
            .fontSize(15)
            .opacity(0.8)
            .fontColor(params.nowPlaying && params.nowPlaying?.date === params.item?.date ?
              $r('sys.color.white') : $r('app.color.text_color'))
        }
      }
    }
    .width('100%')
    .height('auto')
    .padding({
      right: 10,
      left: 5,
      top: 4,
      bottom: 0
    })

    Row() {
      Text(params.item?.format)
        .fontSize(15)
        .opacity(0.8)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .fontColor(params.nowPlaying && params.nowPlaying?.date === params.item?.date ?
          $r('sys.color.white') : $r('app.color.text_color'))
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
      top: 0,
      bottom: 4
    })
  }
}
