import VideoInfoUtil from '../../utils/VideoInfoUtil'
import { PlayerControllerFactory, PlayerControllerInterface } from '../../controller/PlayerControllerFactory'

@ComponentV2
export struct PlaybackSpeedMenuComponent {
  @Consumer('player') player: PlayerControllerInterface =
    PlayerControllerFactory.createAVPlayerController() as PlayerControllerInterface
  private speedList: number[] = VideoInfoUtil.videoSpeedListAll
  private scroller: Scroller = new Scroller()
  @Event onSpeedChange: (_speed: number) => void = () => {
  }

  aboutToAppear(): void {
    setTimeout(() => {
      const currentIndex = this.speedList.findIndex(speed => speed === this.player.speed)
      if (currentIndex >= 0) {
        this.scroller.scrollToIndex(currentIndex)
      }
    }, 50)
  }

  build() {
    List({ space: 2, scroller: this.scroller }) {
      Repeat<number>(this.speedList)
        .each((repeatItem: RepeatItem<number>) => {
          ListItem() {
            Row() {
              Text(`${repeatItem.item}x`)
                .fontSize(16)
                .height(36)
                .layoutWeight(1)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.MARQUEE })
                .textAlign(TextAlign.Center)
                .fontColor(repeatItem.item === this.player.speed ? $r('sys.color.white') :
                  $r('app.color.text_color'))
            }
            .width('100%')
            .padding({
              left: 8,
              right: 8,
              top: 4,
              bottom: 4
            })
            .backgroundColor(repeatItem.item === this.player.speed ? $r('app.color.main_color') : Color.Transparent)
            .borderRadius(16)
            .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
            .onClick(() => {
              this.onSpeedChange(repeatItem.item)
            })
          }
        })
        .key((item: number, _index: number) => item.toString()).virtualScroll()
    }
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .chainAnimation(true)
    .scrollBar(BarState.Off)
    .width(100)
    .height('50%')
  }
}