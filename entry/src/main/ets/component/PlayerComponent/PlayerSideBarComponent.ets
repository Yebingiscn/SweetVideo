import { VideoMetadataFromPlayer } from '../../interfaces/VideoMetadataFromPlayerInterface'
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import { fileUri } from '@kit.CoreFileKit'
import { PathUtils } from '../../utils/PathUtils'
import { ImageFancyModifier } from '../../utils/AttributeModifierUtil'
import { PlayerSideBarSource } from '../../utils/DataUtil'
import VideoInfoUtil from '../../utils/VideoInfoUtil'
import { VideoInfoBuilder } from '../VideoItemComponent/VideoInfoBuilder'
import { XAnimation } from '../../utils/AnimationUtil'

@Component
export struct PlayerSideBarComponent {
  @State playerSideBarSource: PlayerSideBarSource = new PlayerSideBarSource([])
  @Link @Watch('onSideBarVisibleChange') sideBarStatusTmp: Visibility
  @State video_meta_data: VideoMetadata[] = []
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
            .backgroundColor(this.now_playing && this.now_playing?.date === item?.date ?
              $r('app.color.main_color') : '')
            .borderRadius(16)
            .onClick(() => {
              if (this.sideBarStatusTmp === Visibility.Hidden) {
                return
              }
              this.now_playing?.date === item.date ? this.closeSideBar() : this.onItemClick(item)
            })
            .width('100%')
            .height('auto')
            .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.9 })
        }.padding({ top: index === 0 ? 10 : 0 })
      }, (item: VideoMetadata) => item.date + this.now_playing?.date)
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
    .padding({ left: 5, right: 5 })
    .margin({ top: this.topSafeHeight })
    .transition(TransitionEffect.translate({ x: 300 }).animation(XAnimation.getAnimationCurve()))
    .borderRadius(16)
    .cachedCount(3)
  }

  onSideBarVisibleChange() {
    if (this.sideBarStatusTmp === Visibility.Visible) {
      setTimeout(() => {
        const targetIndex = this.video_meta_data.findIndex(
          item => item?.date === this.now_playing?.date
        );
        if (targetIndex >= 0) {
          this.listScroller.scrollToIndex(targetIndex, false);
        }
      }, 50); // 添加短暂延迟确保DOM更新
    }
  }

  private closeSideBar() {
    this.sideBarStatusTmp = Visibility.Hidden
    setTimeout(() => {
      this.sideBarStatus = false
    }, 250)
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
        .attributeModifier(new ImageFancyModifier(16, 80, 120))
      Column() {
        Row() {
          Text(VideoInfoUtil.getVideoTitle(this.item!))
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .maxLines(4)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .margin({ left: 5 })
            .wordBreak(WordBreak.BREAK_ALL)
            .fontColor(this.now_playing && this.now_playing?.date === this.item?.date ?
              $r('sys.color.white') : $r('app.color.text_color'))
        }

        VideoInfoBuilder({ item: this.item, showProgress: false })
      }.alignItems(HorizontalAlign.Start)
      .padding({ left: 15, right: 15 })
      .layoutWeight(1)
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .opacity(0.8)
    .borderRadius(16)
  }
}