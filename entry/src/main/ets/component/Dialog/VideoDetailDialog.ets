import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import TimeUtil from '../../utils/TimeUtil'
import ToolsUtil from '../../utils/ToolsUtil'
import VideoInfoUtil from '../../utils/VideoInfoUtil'
import { DIALOG_TITLE_FONT_SIZE } from '../../common/Constants'
import { SweetAgentComponent } from '../common/SweetAgentComponent'

@Builder
export function VideoDetailSheetBuilder(metadata?: VideoMetadata) {
  Column({ space: 10 }) {
    Text('详情')
      .fontSize(DIALOG_TITLE_FONT_SIZE)
      .fontColor($r('app.color.text_color'))
      .fontWeight(FontWeight.Bold)
      .margin({ top: 5 })
    SweetAgentComponent(
      {
        queryText: VideoInfoUtil.hasVideoTrack(metadata) ? `介绍下视频：${metadata?.title}，格式：${metadata?.format}` :
          `介绍下音频：${metadata?.title}，格式：${metadata?.format}`,
        title: '问问小艺了解更多'
      })

    List() {
      ListItem() {
        Row() {
          Text(VideoInfoUtil.hasVideoTrack(metadata) ? '视频名称：' : '音频名称：')
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
            Text('歌手：')
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
            Text('专辑：')
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
          Text('格式：')
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
            Text('分辨率：')
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
            Text('音频品质：')
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
          Text('帧数：')
            .fontSize(15)
            .fontColor($r('app.color.text_color'))
            .flexShrink(0)
            .width(105)

          Text(`${metadata?.frame_rate ?? '未知'} fps`)
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
          Text('时长：')
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
          Text('大小：')
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
          Text('上次播放进度：')
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
            Text('最近播放：')
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
          Text('片头时间：')
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
          Text('片尾时间：')
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
          Text('路径：')
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
          Text('外挂字幕：')
            .fontSize(15)
            .fontColor($r('app.color.text_color'))
            .flexShrink(0)
            .width(105)

          Text(metadata?.external_subtitle_format || '无字幕')
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
          Text('循环A点')
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
          Text('循环B点')
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
