import { VideoMetadataFromPlayer } from '../../interfaces/VideoMetadataFromPlayerInterface'
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import { fileUri } from '@kit.CoreFileKit'
import { PathUtils } from '../../utils/PathUtils'
import { ImageFancyModifier } from '../../utils/AttributeModifierUtil'
import { PlayerSideBarSource } from '../../utils/DataUtil'
import VideoInfoUtil from '../../utils/VideoInfoUtil'

@Component
export struct PlayerSideBarComponent {
  @State playerSideBarSource: PlayerSideBarSource = new PlayerSideBarSource([])
  @Link sideBarStatusTmp: Visibility
  @Prop video_meta_data: VideoMetadata[]
  @Link now_playing: VideoMetadataFromPlayer | undefined
  @Link sideBarStatus: boolean
  @StorageProp('topSafeHeight') topSafeHeight: number = 0;
  private listScroller: Scroller = new Scroller();
  onItemClick = (_item: VideoMetadata) => {
  }

  aboutToAppear(): void {
    this.playerSideBarSource = new PlayerSideBarSource(this.video_meta_data)
  }

  build() {
    List({ scroller: this.listScroller, space: 10 }) {
      LazyForEach(this.playerSideBarSource, (item: VideoMetadata, index: number) => {
        ListItem() {
          ListView({
            item: item,
            now_playing: this.now_playing
          })
            .onClick(() => {
              if (this.sideBarStatusTmp === Visibility.Hidden) {
                return
              }
              if (this.now_playing?.date !== item.date) {
                this.onItemClick(item)
              }
              console.error('test' + this.now_playing?.title)
            })
            .width('100%')
            .height('auto')
            .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.9 })
        }.padding({ top: index === 0 ? 10 : 0 })
      }, (item: VideoMetadata) => item.date + this.now_playing?.date)
    }
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true }) // 滚动边缘效果
    .chainAnimation(true)
    .scrollBar(BarState.Off)
    .onAppear(() => {
      this.listScroller.scrollToIndex(this.video_meta_data.findIndex(item => item?.date)!)
    })
    .gesture(SwipeGesture({ direction: SwipeDirection.Horizontal }).onAction((event: GestureEvent) => {
      if (event) {
        this.sideBarStatusTmp = Visibility.Hidden
        setTimeout(() => {
          this.sideBarStatus = false
        }, 250)
      }
    }))
    .visibility(this.sideBarStatusTmp)
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.start_window_background'))
    .padding({ left: 10, right: 10 })
    .margin({ top: this.topSafeHeight })
    .transition(TransitionEffect.translate({ x: 250 }).animation({ duration: 300, curve: Curve.Friction }))
    .borderRadius(20)
    .cachedCount(3)
  }
}

@Reusable
@Component
export struct ListView {
  @Prop item: VideoMetadata | undefined = undefined
  @Prop now_playing: VideoMetadataFromPlayer | undefined

  build() {
    Row() {
      Image(fileUri.getUriFromPath(PathUtils.coverPath + this.item?.date))
        .attributeModifier(new ImageFancyModifier(10, 64, 96))
        .margin({ left: 5 })
      Text(VideoInfoUtil.getVideoTitle(this.item!))
        .fontSize(15)
        .fontColor(this.now_playing && this.now_playing?.date === this.item?.date ? $r('app.color.main_color') :
        $r('app.color.text_color'))
        .fontWeight(FontWeight.Medium)
        .maxLines(4)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('65%')
        .margin({ left: 5 })
        .wordBreak(WordBreak.BREAK_ALL)
    }
  }
}