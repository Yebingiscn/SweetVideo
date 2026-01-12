import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import { fileUri } from '@kit.CoreFileKit'
import { PathUtils } from '../../utils/PathUtils'
import { ImageFancyModifier } from '../../common/AttributeModifierConfig'
import { PlayerSideBarSource } from '../../utils/DataUtil'
import VideoInfoUtil from '../../utils/VideoInfoUtil'
import { VideoInfoBuilder } from '../VideoItemComponent/VideoInfoBuilder'
import { XAnimation } from '../../utils/AnimationUtil'
import { SafeHeight } from '../../utils/ObservedUtil'

@Component
export struct PlayerSideBarComponent {
  @State playerSideBarSource: PlayerSideBarSource = new PlayerSideBarSource([])
  @Link @Watch('onSideBarVisibleChange') sideBarStatusTmp: Visibility
  @State videoMetadata: VideoMetadata[] = []
  @Prop nowPlaying: VideoMetadata | undefined
  @Link sideBarStatus: boolean
  private listScroller: Scroller = new Scroller()
  onItemClick = (_item: VideoMetadata) => {
  }

  aboutToAppear(): void {
    this.playerSideBarSource = new PlayerSideBarSource(this.videoMetadata)
  }

  build() {
    List({ scroller: this.listScroller, space: 10 }) {
      LazyForEach(this.playerSideBarSource, (item: VideoMetadata, index: number) => {
        ListItem() {
          VideoItemBuilder({
            item: item,
            nowPlaying: this.nowPlaying
          })
        }
        .padding({ top: index === 0 ? 10 : 0 })
        .borderRadius(16)
        .onClick(() => {
          if (this.sideBarStatusTmp === Visibility.Hidden) {
            return
          }
          this.nowPlaying?.date === item.date ? this.closeSideBar() : this.onItemClick(item)
        })
        .width('100%')
        .height('auto')
        .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.9 })
      }, (item: VideoMetadata) => item.date)
    }
    .clip(false)
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true }) // 滚动边缘效果
    .chainAnimation(true)
    .scrollBar(BarState.Off)
    .onAppear(() => {
      this.onSideBarVisibleChange()
    })
    .gesture(SwipeGesture({ direction: SwipeDirection.Horizontal }).onAction((event: GestureEvent) => {
      if (event) {
        this.closeSideBar()
      }
    }))
    .visibility(this.sideBarStatusTmp)
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.start_window_background'))
    .padding({
      left: 10,
      right: 5,
      top: SafeHeight.topSafeHeight,
    })
    .transition(TransitionEffect.translate({ x: 300 }).animation(XAnimation.getAnimationCurve()))
    .borderRadius(16)
    .cachedCount(6)
  }

  onSideBarVisibleChange() {
    if (this.sideBarStatusTmp === Visibility.Visible) {
      setTimeout(() => {
        const targetIndex = this.videoMetadata.findIndex(
          item => item?.date === this.nowPlaying?.date
        )
        if (targetIndex >= 0) {
          this.listScroller.scrollToIndex(targetIndex, false)
        }
      }, 50)
    }
  }

  private closeSideBar() {
    this.sideBarStatusTmp = Visibility.Hidden
    setTimeout(() => {
      this.sideBarStatus = false
    }, 250)
  }
}

class VideoItemValue {
  item: VideoMetadata | undefined = undefined
  nowPlaying?: VideoMetadata | undefined = undefined
  longPressPreview?: boolean = false
}

@Builder
export function VideoItemBuilder(videoItemValue: VideoItemValue) {
  Row() {
    Image(fileUri.getUriFromPath(PathUtils.coverPath + videoItemValue.item?.date))
      .attributeModifier(new ImageFancyModifier(16, 80, 120))
    Column() {
      Row() {
        Text(VideoInfoUtil.getVideoTitle(videoItemValue.item!))
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .maxLines(4)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .margin({ left: 5 })
          .wordBreak(WordBreak.BREAK_ALL)
          .fontColor(videoItemValue.nowPlaying && videoItemValue.nowPlaying?.date === videoItemValue.item?.date ?
            $r('sys.color.white') : $r('app.color.text_color'))
      }

      VideoInfoBuilder({ item: videoItemValue.item, showProgress: false, nowPlaying: videoItemValue.nowPlaying })
    }.alignItems(HorizontalAlign.Start)
    .padding({ left: 15, right: 15 })
    .layoutWeight(1)
  }
  .backgroundColor(
    videoItemValue.longPressPreview
      ? $r('app.color.start_window_background_blur')
      : videoItemValue.nowPlaying && videoItemValue.nowPlaying?.date === videoItemValue.item?.date
      ? $r('app.color.main_color')
      : $r('app.color.start_window_background')
  )
  .justifyContent(FlexAlign.Center)
  .width('100%')
  .borderRadius(16)
}