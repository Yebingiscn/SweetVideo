import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import TimeUtil from '../../utils/TimeUtil'
import ToolsUtil from '../../utils/ToolsUtil'
import VideoInfoUtil from '../../utils/VideoInfoUtil'
import { DIALOG_TITLE_FONT_SIZE } from '../../common/Constants'
import { SweetAgentComponent } from '../common/SweetAgentComponent'

@Builder
export function VideoDetailSheetBuilder(metadata?: VideoMetadata) {
  Column({ space: 10 }) {
    Text($r('app.string.menu_detail'))
      .fontSize(DIALOG_TITLE_FONT_SIZE)
      .fontColor($r('app.color.text_color'))
      .fontWeight(FontWeight.Bold)
      .margin({ top: 5 })
    SweetAgentComponent(
      {
        queryText: VideoInfoUtil.hasVideoTrack(metadata) ? ToolsUtil.getStringResourceArgs2($r('app.string.ai_query_video').id, metadata?.title ?? '', metadata?.format ?? '') :
          ToolsUtil.getStringResourceArgs2($r('app.string.ai_query_audio').id, metadata?.title ?? '', metadata?.format ?? ''),
        title: ToolsUtil.getStringResource($r('app.string.ask_xiaoyi').id)
      })

    List() {
      ListItem() {
        Row() {
          Text(VideoInfoUtil.hasVideoTrack(metadata) ? $r('app.string.detail_video_name') : $r('app.string.detail_audio_name'))
            .fontSize(15)
            .fontColor($r('app.color.text_color'))
            .flexShrink(0)
            .width(105)

          Text(ToolsUtil.safeDecodeURI(metadata?.title))
            .fontSize(15)
            .fontColor($r('app.color.text_color'))
            .maxLines(8)
            .wordBreak(WordBreak.BREAK_ALL)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ top: 8, bottom: 8 })
      }

      if (metadata?.artist) {
        ListItem() {
          Row() {
            Text($r('app.string.detail_artist'))
              .fontSize(15)
              .fontColor($r('app.color.text_color'))
              .flexShrink(0)
              .width(105)

            Text(metadata.artist)
              .fontSize(15)
              .fontColor($r('app.color.text_color'))
              .maxLines(8)
              .wordBreak(WordBreak.BREAK_ALL)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
          }
          .width('100%')
          .padding({ top: 8, bottom: 8 })
        }
      }

      if (metadata?.album) {
        ListItem() {
          Row() {
            Text($r('app.string.detail_album'))
              .fontSize(15)
              .fontColor($r('app.color.text_color'))
              .flexShrink(0)
              .width(105)

            Text(metadata.album)
              .fontSize(15)
              .fontColor($r('app.color.text_color'))
              .maxLines(8)
              .wordBreak(WordBreak.BREAK_ALL)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
          }
          .width('100%')
          .padding({ top: 8, bottom: 8 })
        }
      }

      ListItem() {
        Row() {
          Text($r('app.string.detail_format'))
            .fontSize(15)
            .fontColor($r('app.color.text_color'))
            .flexShrink(0)
            .width(105)

          Text(String(metadata?.format))
            .fontSize(15)
            .fontColor($r('app.color.text_color'))
            .maxLines(8)
            .wordBreak(WordBreak.BREAK_ALL)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ top: 8, bottom: 8 })
      }

      if (VideoInfoUtil.hasVideoTrack(metadata)) {
        ListItem() {
          Row() {
            Text($r('app.string.detail_resolution'))
              .fontSize(15)
              .fontColor($r('app.color.text_color'))
              .flexShrink(0)
              .width(105)

            Text(VideoInfoUtil.videoWidthAndHeightFormat(
              VideoInfoUtil.getDisplayResolution(metadata).toString()) === '0 x 0' ?
              ToolsUtil.getStringResource($r('app.string.unknown_resolution').id) :
              VideoInfoUtil.videoWidthAndHeightFormat(
                VideoInfoUtil.getDisplayResolution(metadata).toString(), true))
              .fontSize(15)
              .fontColor($r('app.color.text_color'))
              .maxLines(8)
              .wordBreak(WordBreak.BREAK_ALL)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
          }
          .width('100%')
          .padding({ top: 8, bottom: 8 })
        }
      } else {
        ListItem() {
          Row() {
            Text($r('app.string.detail_audio_quality'))
              .fontSize(15)
              .fontColor($r('app.color.text_color'))
              .flexShrink(0)
              .width(105)

            Text(VideoInfoUtil.getAudioQualityDetail(metadata))
              .fontSize(15)
              .fontColor($r('app.color.text_color'))
              .maxLines(8)
              .wordBreak(WordBreak.BREAK_ALL)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
          }
          .width('100%')
          .padding({ top: 8, bottom: 8 })
        }
      }

      ListItem() {
        Row() {
          Text($r('app.string.detail_frame_rate'))
            .fontSize(15)
            .fontColor($r('app.color.text_color'))
            .flexShrink(0)
            .width(105)

          Text(`${metadata?.frame_rate ?? ToolsUtil.getStringResource($r('app.string.unknown').id)} fps`)
            .fontSize(15)
            .fontColor($r('app.color.text_color'))
            .maxLines(8)
            .wordBreak(WordBreak.BREAK_ALL)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ top: 8, bottom: 8 })
      }

      ListItem() {
        Row() {
          Text($r('app.string.detail_duration'))
            .fontSize(15)
            .fontColor($r('app.color.text_color'))
            .flexShrink(0)
            .width(105)

          Text(String(TimeUtil.convertMSToHHMMSS(metadata?.time)))
            .fontSize(15)
            .fontColor($r('app.color.text_color'))
            .maxLines(8)
            .wordBreak(WordBreak.BREAK_ALL)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ top: 8, bottom: 8 })
      }

      ListItem() {
        Row() {
          Text($r('app.string.detail_size'))
            .fontSize(15)
            .fontColor($r('app.color.text_color'))
            .flexShrink(0)
            .width(105)

          Text(String(metadata?.video_size))
            .fontSize(15)
            .fontColor($r('app.color.text_color'))
            .maxLines(8)
            .wordBreak(WordBreak.BREAK_ALL)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ top: 8, bottom: 8 })
      }

      ListItem() {
        Row() {
          Text($r('app.string.detail_last_position'))
            .fontSize(15)
            .fontColor($r('app.color.text_color'))
            .flexShrink(0)
            .width(105)

          Text(TimeUtil.convertMSToHHMMSS(metadata?.last_play))
            .fontSize(15)
            .fontColor($r('app.color.text_color'))
            .maxLines(8)
            .wordBreak(WordBreak.BREAK_ALL)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ top: 8, bottom: 8 })
      }

      if (metadata?.last_played_at && metadata.last_played_at > 0) {
        ListItem() {
          Row() {
            Text($r('app.string.recent_play'))
              .fontSize(15)
              .fontColor($r('app.color.text_color'))
              .flexShrink(0)
              .width(105)

            Text(TimeUtil.formatDateTime(metadata.last_played_at))
              .fontSize(15)
              .fontColor($r('app.color.text_color'))
              .maxLines(8)
              .wordBreak(WordBreak.BREAK_ALL)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
          }
          .width('100%')
          .padding({ top: 8, bottom: 8 })
        }
      }

      ListItem() {
        Row() {
          Text($r('app.string.detail_intro_time'))
            .fontSize(15)
            .fontColor($r('app.color.text_color'))
            .flexShrink(0)
            .width(105)

          Text(TimeUtil.convertMSToHHMMSS(metadata?.start_time))
            .fontSize(15)
            .fontColor($r('app.color.text_color'))
            .maxLines(8)
            .wordBreak(WordBreak.BREAK_ALL)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ top: 8, bottom: 8 })
      }

      ListItem() {
        Row() {
          Text($r('app.string.detail_outro_time'))
            .fontSize(15)
            .fontColor($r('app.color.text_color'))
            .flexShrink(0)
            .width(105)

          Text(TimeUtil.convertMSToHHMMSS(metadata?.end_time))
            .fontSize(15)
            .fontColor($r('app.color.text_color'))
            .maxLines(8)
            .wordBreak(WordBreak.BREAK_ALL)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ top: 8, bottom: 8 })
      }

      ListItem() {
        Row() {
          Text($r('app.string.detail_path'))
            .fontSize(15)
            .fontColor($r('app.color.text_color'))
            .flexShrink(0)
            .width(105)

          Text(ToolsUtil.safeDecodeURI(metadata?.uri))
            .fontSize(15)
            .fontColor($r('app.color.text_color'))
            .maxLines(8)
            .wordBreak(WordBreak.BREAK_ALL)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ top: 8, bottom: 8 })
      }

      ListItem() {
        Row() {
          Text($r('app.string.detail_external_subtitle'))
            .fontSize(15)
            .fontColor($r('app.color.text_color'))
            .flexShrink(0)
            .width(105)

          Text(metadata?.external_subtitle_format || $r('app.string.no_subtitle'))
            .fontSize(15)
            .fontColor($r('app.color.text_color'))
            .maxLines(8)
            .wordBreak(WordBreak.BREAK_ALL)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ top: 8, bottom: 8 })
      }

      ListItem() {
        Row() {
          Text($r('app.string.detail_loop_a'))
            .fontSize(15)
            .fontColor($r('app.color.text_color'))
            .flexShrink(0)
            .width(105)

          Text(TimeUtil.convertMSToHHMMSS(metadata?.pointA))
            .fontSize(15)
            .fontColor($r('app.color.text_color'))
            .maxLines(8)
            .wordBreak(WordBreak.BREAK_ALL)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ top: 8, bottom: 8 })
      }

      ListItem() {
        Row() {
          Text($r('app.string.detail_loop_b'))
            .fontSize(15)
            .fontColor($r('app.color.text_color'))
            .flexShrink(0)
            .width(105)

          Text(TimeUtil.convertMSToHHMMSS(metadata?.pointB))
            .fontSize(15)
            .fontColor($r('app.color.text_color'))
            .maxLines(8)
            .wordBreak(WordBreak.BREAK_ALL)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ top: 8, bottom: 8 })
      }
    }
    .height('100%')
    .width('100%')
    .layoutWeight(1)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }
  .width('100%')
  .height('100%')
  .padding({
    left: 20,
    right: 20,
    top: 10,
    bottom: 10
  })
}
