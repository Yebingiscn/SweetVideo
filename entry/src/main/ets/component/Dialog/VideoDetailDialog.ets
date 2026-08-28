import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import DataSyncUtil from '../../utils/DataSyncUtil'
import TimeUtil from '../../utils/TimeUtil'
import ToolsUtil from '../../utils/ToolsUtil'
import VideoInfoUtil from '../../utils/VideoInfoUtil'
import { DIALOG_TITLE_FONT_SIZE } from '../../common/Constants'
import { SweetAgentComponent } from '../common/SweetAgentComponent'

// 视频详情弹窗
@CustomDialog
export struct VideoDetailDialog {
  controller?: CustomDialogController
  private metadata?: VideoMetadata

  aboutToAppear(): void {
    const metadata = DataSyncUtil.editingVideo as VideoMetadata
    this.metadata = metadata
  }

  build() {
    Column({ space: 10 }) {
      Text('详情')
        .fontSize(DIALOG_TITLE_FONT_SIZE)
        .fontColor($r('app.color.text_color'))
        .fontWeight(FontWeight.Bold)
        .margin({ top: 5 })

      SweetAgentComponent({ queryText: `介绍下音视频：${this.metadata?.title}`, title: '问问小艺了解更多' })

      List() {
        ListItem() {
          Row() {
            this.buildDetailItem('视频名称：', ToolsUtil.safeDecodeURI(this.metadata?.title))
          }
        }

        ListItem() {
          this.buildDetailItem('视频格式：', String(this.metadata?.format))
        }

        ListItem() {
          this.buildDetailItem('视频分辨率：',
            VideoInfoUtil.videoWidthAndHeightFormat(
              VideoInfoUtil.getDisplayResolution(this.metadata).toString()) === '0 x 0' ?
              ToolsUtil.getStringResource($r('app.string.unknown_resolution').id) :
              VideoInfoUtil.videoWidthAndHeightFormat(
                VideoInfoUtil.getDisplayResolution(this.metadata).toString(), true))
        }

        ListItem() {
          this.buildDetailItem('视频帧数：', `${this.metadata?.frame_rate ?? '未知'} fps`)
        }

        ListItem() {
          this.buildDetailItem('视频时长：', String(TimeUtil.convertMSToHHMMSS(this.metadata?.time)))
        }

        ListItem() {
          this.buildDetailItem('视频大小：', String(this.metadata?.video_size))
        }

        ListItem() {
          this.buildDetailItem('上次播放时间：', TimeUtil.convertMSToHHMMSS(this.metadata?.last_play))
        }

        ListItem() {
          this.buildDetailItem('片头时间：', TimeUtil.convertMSToHHMMSS(this.metadata?.start_time))
        }

        ListItem() {
          this.buildDetailItem('片尾时间：', TimeUtil.convertMSToHHMMSS(this.metadata?.end_time))
        }

        ListItem() {
          this.buildDetailItem('视频路径：', ToolsUtil.safeDecodeURI(this.metadata?.uri))
        }

        ListItem() {
          this.buildDetailItem('外挂字幕：', this.metadata?.external_subtitle_format || '无字幕')
        }

        ListItem() {
          this.buildDetailItem('循环A点', TimeUtil.convertMSToHHMMSS(this.metadata?.pointA))
        }

        ListItem() {
          this.buildDetailItem('循环B点', TimeUtil.convertMSToHHMMSS(this.metadata?.pointB))
        }
      }
      .width('100%')
      .height('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring) // 滚动边缘效果

      Button({ type: ButtonType.Normal, stateEffect: true }) {
        Text($r('app.string.cancel'))
          .fontSize(18)
          .fontColor($r('app.color.text_color'))
      }
      .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
      .backgroundColor($r('sys.color.button_background_color_transparent'))
      .borderRadius(16)
      .height(50)
      .width(120)
      .onClick(() => this.controller?.close())
      .margin({ top: 5, bottom: 5 })
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

  @Builder
  private buildDetailItem(label: string | Resource, value: string | number | undefined) {
    Row() {
      Text(label)
        .fontSize(15)
        .fontColor($r('app.color.text_color'))
        .flexShrink(0)
        .width(85)

      Text(value?.toString() || '--')
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
