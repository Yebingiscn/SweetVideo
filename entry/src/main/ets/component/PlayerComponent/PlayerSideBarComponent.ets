import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import { PlayerSideBarSource } from '../../utils/DataUtil'
import { PlayerControllerFactory, PlayerControllerInterface } from '../../controller/PlayerControllerFactory'
import { ImageFancyModifier } from '../../common/AttributeModifierConfig'
import { CoverLayoutMode } from '../../common/enum/DisplayMode'
import { XAnimation } from '../../utils/AnimationUtil'
import { SafeHeight, Setting } from '../../utils/ObservedUtil'
import { PathUtils } from '../../utils/PathUtils'
import VideoInfoUtil from '../../utils/VideoInfoUtil'
import { VideoInfoBuilder } from '../VideoItemComponent/VideoInfoBuilder'

@ComponentV2
export struct PlayerSideBarComponent {
  @Local playerSideBarSource: PlayerSideBarSource = new PlayerSideBarSource([])
  @Param sideBarStatusTmp: Visibility = Visibility.Hidden
  @Local _sideBarStatusTmp: Visibility = Visibility.Hidden
  @Consumer('player') player: PlayerControllerInterface =
    PlayerControllerFactory.createAVPlayerController() as PlayerControllerInterface
  @Param sideBarStatus: boolean = false
  @Local _sideBarStatus: boolean = false
  private listScroller: Scroller = new Scroller()
  @Event onSideBarStatusTmpChange: (v: Visibility) => void = () => {
  }
  @Event onSideBarStatusChange: (v: boolean) => void = () => {
  }
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
    List({ scroller: this.listScroller, space: 6 }) {
      Repeat<VideoMetadata>(this.playerSideBarSource.data)
        .each((repeatItem: RepeatItem<VideoMetadata>) => {
          ListItem() {
            VideoItemBuilder({
              item: repeatItem.item,
              nowPlaying: this.player.nowPlaying,
            })
          }
          .padding({ top: repeatItem.index === 0 ? 6 : 0 })
          .borderRadius(16)
          .onClick(() => {
            if (this._sideBarStatusTmp === Visibility.Hidden) {
              return
            }
            this.player.nowPlaying?.date === repeatItem.item.date ? this.closeSideBar() :
              this.onItemClick(repeatItem.item)
          })
          .width('100%')
          .height('auto')
          .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.9 })
        })
        .key((item: VideoMetadata, _index: number) => item.date)
        .virtualScroll()
    }
    .backgroundImage(
      Setting.backgroundDropBlur > 0 && Setting.backgroundBlurImageSrc.length > 0 ? Setting.backgroundBlurImageSrc :
        Setting.backgroundImageSrc, ImageRepeat.NoRepeat)
    .backgroundImageSize(ImageSize.Cover)
    .backgroundImagePosition(Alignment.Center)
    .clip(true)
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
    .backgroundColor(Setting.backgroundImageSrc.length > 0 ? '' : $r('app.color.sidebar_background_color'))
    .padding({
      left: 8,
      right: 8,
    })
    .contentStartOffset(SafeHeight.topSafeHeight)
    .transition(TransitionEffect.translate({ x: 300 })
      .combine(TransitionEffect.OPACITY)
      .animation(XAnimation.getAnimationCurve()))
    .borderRadius(16)
  }

  @Monitor('_sideBarStatusTmp')
  onSideBarVisibleChange() {
    if (this._sideBarStatusTmp === Visibility.Visible) {
      this.playerSideBarSource.updateData(this.player.videoMetaDataList)
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
}

@Builder
export function VideoItemBuilder(videoItemValue: VideoItemValue) {
  Row() {
    Image(PathUtils.coverUri(videoItemValue.item?.date ?? ''))
      .attributeModifier(new ImageFancyModifier(12, Setting.coverLayout === CoverLayoutMode.VERTICAL_PLATE ? 85 : 110,
        Setting.coverLayout === CoverLayoutMode.VERTICAL_PLATE ? 110 : 85))
    Column() {
      Text(VideoInfoUtil.getVideoTitle(videoItemValue.item!))
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .margin({ left: 5 })
        .wordBreak(WordBreak.BREAK_ALL)
        .fontColor(videoItemValue.nowPlaying && videoItemValue.nowPlaying?.date === videoItemValue.item?.date ?
          $r('sys.color.white') : $r('app.color.text_color'))

      VideoInfoBuilder({
        item: videoItemValue.item,
        nowPlaying: videoItemValue.nowPlaying
      })
    }.alignItems(HorizontalAlign.Start)
    .padding({ left: 12, right: 12 })
    .layoutWeight(1)
  }
  .backdropBlur(Setting.listItemBackgroundBlur ? 150 : 0)
  .backgroundColor(Setting.listItemBackgroundBlur ? undefined : (
    videoItemValue.nowPlaying && videoItemValue.nowPlaying?.date === videoItemValue.item?.date
      ? $r('app.color.main_color')
      : $r('app.color.list_item_background'))
  )
  .justifyContent(FlexAlign.Center)
  .width('100%')
  .borderRadius(12)
  .shadow(
    videoItemValue.nowPlaying && videoItemValue.nowPlaying?.date === videoItemValue.item?.date
      ? {
      radius: 8,
      color: '#3315559a',
      offsetX: 0,
      offsetY: 2
    }
      : {
      radius: 4,
      color: $r('app.color.shadow_color'),
      offsetX: 0,
      offsetY: 1
    }
  )
}