import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import DataSyncUtil from '../../utils/DataSyncUtil'
import { DeletedVideosDataSource } from '../../utils/DataUtil'

@CustomDialog
export struct DeletedVideosDialog {
  deletedVideosDataSource: DeletedVideosDataSource = new DeletedVideosDataSource([])
  controller?: CustomDialogController
  private metadata: VideoMetadata[] = []

  aboutToAppear(): void {
    this.metadata = DataSyncUtil.deletedVideos as VideoMetadata[]
    this.deletedVideosDataSource = new DeletedVideosDataSource(this.metadata)
    DataSyncUtil.deletedVideos.length = 0
  }

  build() {
    Column({ space: 10 }) {
      Text('已失效视频')
        .fontSize(25)
        .fontColor($r('app.color.text_color'))
        .fontWeight(FontWeight.Bold)
        .margin({ top: 5 })

      Text(`视频已失效，请重新导入，共 ${this.deletedVideosDataSource.totalCount()} 项`)
        .fontSize(14)
        .fontColor($r('app.color.text_color'))

      List({ space: 8 }) {
        LazyForEach(this.deletedVideosDataSource, (item: VideoMetadata) => {
          ListItem() {
            Text(item?.title)
              .fontSize(14)
              .fontColor($r('app.color.text_color'))
              .padding({ top: 8, bottom: 8 })
              .width('100%')
          }.reuseId(item?.title)
        }, (item: VideoMetadata) => item.uri)
      }
      .cachedCount(12)
      .width('100%')
      .height('100%')
      .layoutWeight(1)
      .divider({ strokeWidth: 0 })
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)

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
      .onClick(() => {
        this.controller?.close()
      })
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
}