import { VideoMetadata } from '../../interfaces/VideoMetadataInterface';
import DataSyncUtil from '../../utils/DataSyncUtil';
import { PathUtils } from '../../utils/PathUtils';
import TimeUtil from '../../utils/TimeUtil';
import VideoInfoUtil from '../../utils/VideoInfoUtil';

// 视频详情弹窗
@CustomDialog
export struct VideoDetailDialog {
  controller?: CustomDialogController
  private metadata?: VideoMetadata

  aboutToAppear(): void {
    const metadata = JSON.parse(DataSyncUtil.editingVideo) as VideoMetadata
    this.metadata = metadata
  }

  build() {
    Column({ space: 25 }) {
      Text('详情')
        .fontSize(25)
        .fontColor($r('app.color.text_color'))
        .fontWeight(FontWeight.Bold)
        .margin({ top: 10 })
      Scroll() {
        Column() {
          Column({ space: 15 }) {
            this.buildDetailItem('视频格式：', String(this.metadata?.format))
          }.width('100%')

          Column({ space: 15 }) {
            this.buildDetailItem('视频分辨率：',
              VideoInfoUtil.videoWidthAndHeightFormat(this.metadata?.size.toString()!) === '0 x 0' ?
              PathUtils.appContext!.resourceManager.getStringSync($r('app.string.unknown_resolution').id) :
              VideoInfoUtil.videoWidthAndHeightFormat(this.metadata?.size.toString()!))
          }.width('100%')

          Column({ space: 15 }) {
            this.buildDetailItem('视频大小：', String(this.metadata?.video_size))
          }.width('100%')

          Column({ space: 15 }) {
            this.buildDetailItem('上次播放时间：', TimeUtil.convertMSToMMSS(this.metadata?.last_play))
          }.width('100%')

          Column({ space: 15 }) {
            this.buildDetailItem('视频路径：', this.metadata?.uri)
          }.width('100%')
        }
      }.scrollable(ScrollDirection.Vertical) // 启用垂直滚动
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring) // 滚动边缘效果
      Button({ type: ButtonType.Normal, stateEffect: true }) {
        Text($r('app.string.cancel'))
          .fontSize(18)
          .fontColor($r('app.color.text_color'))
      }
      .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
      .backgroundColor($r('sys.color.button_background_color_transparent'))
      .borderRadius(8)
      .height(60)
      .width(80)
      .onClick(() => this.controller?.close())
      .margin({ bottom: 10 })

    }.padding(20)
  }

  // 新增详情项构建方法
  @Builder
  private buildDetailItem(label: string | Resource, value: string | number | undefined) {
    Row() {
      Text(label)
        .fontSize(15)
        .fontColor($r('app.color.text_color'))
        .flexShrink(0)
        .width(85)
        .textAlign(TextAlign.Start)

      Text(value?.toString() || '--')
        .fontSize(15)
        .fontColor($r('app.color.text_color'))
        .maxLines(8)
        .wordBreak(WordBreak.BREAK_ALL)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('70%')
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceBetween)
    .padding({ top: 8, bottom: 8 })
  }
}