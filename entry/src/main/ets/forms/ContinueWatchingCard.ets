import { VideoFormItem } from './VideoFormItem'

const cardStorage = new LocalStorage()

@Entry(cardStorage)
@Component
struct ContinueWatchingCard {
  @LocalStorageProp('items') items: VideoFormItem[] = []
  @LocalStorageProp('dimension') dimension: number = 2

  private openApp(mediaId: string = ''): void {
    postCardAction(this, {
      action: 'router',
      abilityName: 'EntryAbility',
      params: { videoFormAction: mediaId ? 'play' : 'home', videoFormMediaId: mediaId }
    })
  }

  build() {
    Stack() {
      if (this.items.length === 0) {
        Column({ space: 8 }) {
          Image($r('app.media.sweet_video'))
            .width(64)
            .height(64)
            .objectFit(ImageFit.Contain)
          Text($r('app.string.video_form_empty'))
            .fontSize(14)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(2)
            .textAlign(TextAlign.Center)
        }.width('100%').height('100%').justifyContent(FlexAlign.Center).padding(12)
          .onClick(() => this.openApp())
      } else if (this.dimension === 3) {
        Row({ space: 6 }) {
          Repeat(this.items)
            .each((ri: RepeatItem<VideoFormItem>) => {
              Column() {
                Image(ri.item.cover ? `memory://${ri.item.cover}` : $r('app.media.sweet_video_alt'))
                  .width('100%')
                  .layoutWeight(1)
                  .objectFit(ri.item.cover ? ImageFit.Cover : ImageFit.Contain)
                  .backgroundColor($r('sys.color.comp_background_secondary'))
                  .borderRadius(8).clip(true)
                Text(ri.item.title)
                  .fontSize(11)
                  .fontColor($r('sys.color.font_primary'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .textAlign(TextAlign.Center)
                  .width('100%')
                  .margin({ top: 4 })
              }
              .width('32%')
              .onClick(() => this.openApp(ri.item.mediaId))
            })
            .key((item: VideoFormItem) => `${item.mediaId}:${item.cover}:${item.title}`)
        }
        .width('100%').height('100%')
        .padding(10)

      } else {
        Stack({ alignContent: Alignment.BottomStart }) {
          Image(this.items[0].cover ? `memory://${this.items[0].cover}` : $r('app.media.sweet_video_alt'))
            .width('100%').height('100%')
            .objectFit(this.items[0].cover ? ImageFit.Cover : ImageFit.Contain)
            .backgroundColor($r('sys.color.comp_background_secondary'))
          Column() {
            Text(this.items[0].title)
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
          }
          .width('100%')
          .padding({ top: 28, bottom: 12, left: 12, right: 12 })
          .linearGradient({ angle: 180, colors: [['#00000000', 0], ['#B3000000', 1]] })
        }.width('100%').height('100%')
          .onClick(() => this.openApp(this.items[0].mediaId))

      }
    }
    .width('100%')
    .height('100%')
    .clip(true)
    .backgroundColor($r('sys.color.comp_background_primary'))
  }
}
