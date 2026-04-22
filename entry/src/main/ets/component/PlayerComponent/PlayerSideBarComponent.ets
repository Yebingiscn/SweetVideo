import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import { PlayerSideBarSource } from '../../utils/DataUtil'
import { AVPlayerController } from '../../controller/AVPlayerController'
import { MpvController } from '../../controller/MpvController/MpvController'
import { ImageFancyModifier } from '../../common/AttributeModifierConfig'
import { CoverLayoutMode } from '../../common/enum/DisplayMode'
import { XAnimation } from '../../utils/AnimationUtil'
import { SafeHeight, Setting } from '../../utils/ObservedUtil'
import { PathUtils } from '../../utils/PathUtils'
import VideoInfoUtil from '../../utils/VideoInfoUtil'
import { VideoInfoBuilder } from '../VideoItemComponent/VideoInfoBuilder'
import { fileUri } from '@kit.CoreFileKit'

@ComponentV2
export struct PlayerSideBarComponent {
  @Local playerSideBarSource: PlayerSideBarSource = new PlayerSideBarSource([])
  @Param sideBarStatusTmp: Visibility = Visibility.Hidden
  @Event onSideBarStatusTmpChange: (v: Visibility) => void = () => {}
  @Local _sideBarStatusTmp: Visibility = Visibility.Hidden
  @Consumer('player') player: AVPlayerController | MpvController = new AVPlayerController()
  @Param sideBarStatus: boolean = false
  @Event onSideBarStatusChange: (v: boolean) => void = () => {}
  @Local _sideBarStatus: boolean = false
  private listScroller: Scroller = new Scroller()
  @Event onItemClick: (_item: VideoMetadata) => void = () => {
  }

  aboutToAppear(): void {
    this.playerSideBarSource = new PlayerSideBarSource(this.player.videoMetaDataList)
    this._sideBarStatusTmp = this.sideBarStatusTmp
    this._sideBarStatus = this.sideBarStatus
  }

  @Monitor('sideBarStatusTmp')
  onSideBarStatusTmpMonitor() {
    this._sideBarStatusTmp = this.sideBarStatusTmp
  }

  @Monitor('sideBarStatus')
  onSideBarStatusMonitor() {
    this._sideBarStatus = this.sideBarStatus
  }

  build() {
    List({ scroller: this.listScroller, space: 10 }) {
      LazyForEach(this.playerSideBarSource, (item: VideoMetadata, index: number) => {
        ListItem() {
          VideoItemBuilder({
            item: item,
            nowPlaying: this.player.nowPlaying,
            showProgress: false
          })
        }
        .padding({ top: index === 0 ? 10 : 0 })
        .borderRadius(16)
        .onClick(() => {
          if (this._sideBarStatusTmp === Visibility.Hidden) {
            return
          }
          this.player.nowPlaying?.date === item.date ? this.closeSideBar() : this.onItemClick(item)
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
    .visibility(this._sideBarStatusTmp)
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

  @Monitor('_sideBarStatusTmp')
  onSideBarVisibleChange() {
    if (this._sideBarStatusTmp === Visibility.Visible) {
      setTimeout(() => {
        const targetIndex = this.player.videoMetaDataList.findIndex(
          item => item?.date === this.player.nowPlaying?.date
        )
        if (targetIndex >= 0) {
          this.listScroller.scrollToIndex(targetIndex, false)
        }
      }, 50)
    }
  }

  private closeSideBar() {
    this._sideBarStatusTmp = Visibility.Hidden
    this.onSideBarStatusTmpChange(Visibility.Hidden)
    setTimeout(() => {
      this._sideBarStatus = false
      this.onSideBarStatusChange(false)
    }, 250)
  }
}

class VideoItemValue {
  item: VideoMetadata | undefined = undefined
  nowPlaying?: VideoMetadata | undefined = undefined
  longPressPreview?: boolean = false
  showProgress: boolean = false
}

@Builder
export function VideoItemBuilder(videoItemValue: VideoItemValue) {
  Row() {
    Image(fileUri.getUriFromPath(PathUtils.coverPath + videoItemValue.item?.date))
      .attributeModifier(new ImageFancyModifier(16, Setting.coverLayout === CoverLayoutMode.VERTICAL_PLATE ? 65 : 100,
        Setting.coverLayout === CoverLayoutMode.VERTICAL_PLATE ? 100 : 65))
    Column() {
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

      VideoInfoBuilder({
        item: videoItemValue.item,
        showProgress: videoItemValue.showProgress,
        nowPlaying: videoItemValue.nowPlaying
      })
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