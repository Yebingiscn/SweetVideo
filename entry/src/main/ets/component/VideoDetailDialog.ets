import DataSyncUtil from '../utils/DataSyncUtil';
import { VideoMetadata } from '../utils/VideoInfoUtil';

@CustomDialog
export struct VideoDetailDialog { // 修改类名
  controller?: CustomDialogController
  private metadata?: VideoMetadata

  aboutToAppear(): void {
    const metadata = JSON.parse(DataSyncUtil.editing_video) as VideoMetadata
    this.metadata = metadata
  }

  build() {
    Column({ space: 25 }) {
      Text('详情')
        .fontSize(25)
        .fontColor($r('app.color.text_color'))
        .fontWeight(FontWeight.Bold)
        .margin({ top: 10 })

      Column({ space: 15 }) {
        this.buildDetailItem('视频格式：', String(this.metadata?.format))
      }.width('100%')

      Column({ space: 15 }) {
        this.buildDetailItem('视频大小：', String(this.metadata?.video_size))
      }.width('100%')

      Column({ space: 15 }) {
        this.buildDetailItem('视频路径：', this.metadata?.uri)
      }.width('100%')

      Button({ type: ButtonType.Normal, stateEffect: true }) {
        Text($r('app.string.cancel'))
          .fontSize(18)
          .fontColor($r('app.color.text_color'))
      }
      .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
      .backgroundColor('#00000000')
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