import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import DataSyncUtil from '../../utils/DataSyncUtil'
import { DeletedVideosDataSource } from '../../utils/DataUtil'

@CustomDialog
export struct DeletedVideosDialog {
  @State deletedVideosDataSource: DeletedVideosDataSource = new DeletedVideosDataSource([])
  controller?: CustomDialogController
  private metadata: VideoMetadata[] = []

  aboutToAppear(): void {
    const metadata = DataSyncUtil.deletedVideos as VideoMetadata[]
    this.metadata = metadata
    this.deletedVideosDataSource = new DeletedVideosDataSource(this.metadata)
    DataSyncUtil.deletedVideos.length = 0
  }

  build() {
    Column() {
      // 标题区域增强视觉层次
      Column() {
        Text('已失效视频')
          .fontSize(25)
          .fontColor($r('app.color.text_color'))
          .fontWeight(FontWeight.Bold)
        Text(`视频已失效，请重新导入，共 ${this.deletedVideosDataSource.totalCount()} 项`)
          .fontSize(14)
          .fontColor($r('app.color.text_color'))
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .padding({ bottom: 12 })

      // 列表区域优化
      List({ space: 8 }) {
        LazyForEach(this.deletedVideosDataSource, (item: VideoMetadata) => {
          ListItem() {
            Text(item?.title)
              .fontSize(14)
              .fontColor($r('app.color.text_color'))
              .margin({ bottom: 4 })
              .width('100%')
          }.reuseId(item?.title)
        }, (item: VideoMetadata) => item.uri)
      }
      .cachedCount(12)
      .width('auto')
      .height('auto')
      .divider({ strokeWidth: 0 })
      .scrollBar(BarState.Off) // 动态显示滚动条
      .edgeEffect(EdgeEffect.Spring)
      .layoutWeight(1) // 确保列表区域自动扩展

      // 按钮区域增强可见性
      Button({ type: ButtonType.Capsule, stateEffect: true }) {
        Text($r('app.string.cancel'))
          .fontSize(18)
          .fontColor($r('app.color.text_color'))
      }
      .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
      .backgroundColor($r('sys.color.button_background_color_transparent'))
      .borderRadius(8)
      .height(60)
      .width(80)
      .margin({ bottom: 10 })
      .onClick(() => {
        this.controller?.close()
      })
    }
    .padding(20)
  }
}