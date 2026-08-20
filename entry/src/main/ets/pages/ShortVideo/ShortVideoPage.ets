import { window } from '@kit.ArkUI'
import { BusinessError } from '@kit.BasicServicesKit'
import { ShortVideoItem } from '../../component/ShortVideo/ShortVideoItem'
import NavigationAddress, { ShortVideoParams } from '../../common/NavigationCommon'
import { ShortVideoPlayerManager } from '../../controller/ShortVideo/ShortVideoPlayerManager'
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import { PathUtils } from '../../utils/PathUtils'
import { WindowUtil } from '../../utils/WindowUtil'
import PermissionUtil from '../../utils/PermissionUtil'
import PiPWindowUtil from '../../utils/PiPWindowUtil'
import { Setting } from '../../utils/ObservedUtil'
import ToolsUtil from '../../utils/ToolsUtil'
import { PlaybackSpeedListComponent } from '../../component/PlayerComponent/PlaybackSpeedComponent'
import TimeUtil from '../../utils/TimeUtil'
import VideoInfoUtil from '../../utils/VideoInfoUtil'
import { SwipingPlayTimePanelBuilder } from '../../component/PlayerComponent/SwipingPlayTimePanelBuilder'
import VideoOperateUtil from '../../utils/VideoOperateUtil'

@ComponentV2
export struct ShortVideoPage {
  @Consumer('pathStack') pathStack: NavPathStack = new NavPathStack()
  @Local items: VideoMetadata[] = []
  @Local currentIndex: number = 0
  @Local ready: boolean = false
  @Local seekingTime: number = 0
  @Local isSeeking: boolean = false
  private manager: ShortVideoPlayerManager = new ShortVideoPlayerManager()
  private skipHistory: boolean = false
  private disposed: boolean = false
  private swiperController: SwiperController = new SwiperController()
  @Local containerWidth: number = 0
  @Local containerHeight: number = 0

  aboutToAppear(): void {
    this.disposed = false
    PermissionUtil.applyContinuousTask()
    WindowUtil.setKeepScreenStatus(PathUtils.appContext!, true)
    WindowUtil.setBarState(PathUtils.appContext!, false, false)
    WindowUtil.getWindow().then((windowClass: window.Window | undefined) => {
      windowClass?.setPreferredOrientation(window.Orientation.AUTO_ROTATION_RESTRICTED)
        .catch((_error: BusinessError) => {
        })
    }).catch((_error: BusinessError) => {
    })
  }

  async aboutToDisappear(): Promise<void> {
    await this.dispose()
    PermissionUtil.applyStopContinuousTask()
    WindowUtil.setKeepScreenStatus(PathUtils.appContext!, false)
    WindowUtil.recoveryBarColor()
    WindowUtil.getWindow().then((windowClass: window.Window | undefined) => {
      windowClass?.setPreferredOrientation(window.Orientation.AUTO_ROTATION_RESTRICTED)
        .catch((_error: BusinessError) => {
        })
    }).catch((_error: BusinessError) => {
    })
  }

  @Builder
  PlaybackSpeedMenuBuilder() {
    PlaybackSpeedListComponent({
      selectedSpeed: this.manager.selectedSpeed,
      onSpeedChange: (speed: number) => this.manager.selectSpeed(speed)
    })
  }

  @Builder
  BottomControls() {
    Column() {
      Row({ space: 8 }) {
        Text(VideoInfoUtil.getVideoTitle(this.items[this.currentIndex]))
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)

        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.rectangle_portrait_filled_on_rectangle_portrait'))
            .fontSize(21)
            .fontColor([Color.White])
        }
        .width(40)
        .height(40)
        .backgroundColor('#55000000')
        .onClick(() => this.openPip())

        Button({ type: ButtonType.Circle, stateEffect: true }) {
          Text(`${this.manager.selectedSpeed}x`)
            .fontSize(13)
            .fontColor(Color.White)
            .maxLines(1)
        }
        .width(40)
        .height(40)
        .backgroundColor('#55000000')
        .bindMenu(this.PlaybackSpeedMenuBuilder, {
          placement: Placement.TopRight,
          showInSubWindow: false,
          backgroundBlurStyle: BlurStyle.COMPONENT_THIN
        })

        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.fullscreen'))
            .fontSize(21)
            .fontColor([Color.White])
        }
        .width(40)
        .height(40)
        .backgroundColor('#55000000')
        .onClick(() => this.toggleFullScreen())
      }
      .width('100%')

      Text(`${TimeUtil.convertMSToHHMMSS(this.isSeeking ? this.seekingTime :
        (this.manager.onSwiping ? this.manager.swipingTime : (this.manager.currentPlayer?.currentTime ?? 0)))} / ${
        TimeUtil.convertMSToHHMMSS(
        this.manager.currentPlayer?.duration || this.items[this.currentIndex]?.time || 0)}`)
        .fontSize(12)
        .fontColor('#CCFFFFFF')
        .margin({ top: 6, bottom: 8 })
        .width('100%')

      Slider({
        value: this.isSeeking ? this.seekingTime : (this.manager.currentPlayer?.currentTime ?? 0),
        min: 0,
        max: Math.max(this.manager.currentPlayer?.duration || this.items[this.currentIndex]?.time || 0, 1),
        style: SliderStyle.NONE
      })
        .trackThickness(4)
        .selectedColor(Color.White)
        .blockColor(Color.White)
        .onChange((value: number, mode: SliderChangeMode) => {
          this.seekingTime = value
          this.isSeeking = mode !== SliderChangeMode.End
          if (mode === SliderChangeMode.End) {
            this.manager.seek(this.currentIndex, value)
          }
        })
        .width('100%')
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 28, bottom: 22 })
    .linearGradient({
      angle: 180,
      colors: [[Color.Transparent, 0], ['#90000000', 0.75]]
    })
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Bottom }) {
        if (this.ready && this.items.length > 0) {
          Swiper(this.swiperController) {
            Repeat<VideoMetadata>(this.items)
              .each((repeatItem: RepeatItem<VideoMetadata>) => {
                ShortVideoItem({
                  item: repeatItem.item,
                  index: repeatItem.index,
                  currentIndex: this.currentIndex,
                  manager: this.manager
                })
              })
              .key((item: VideoMetadata) => item.date)
              .virtualScroll()
          }
          .index(this.currentIndex)
          .vertical(true)
          .loop(false)
          .indicator(false)
          .cachedCount(3)
          .duration(300)
          .curve(Curve.Ease)
          .onChange((index: number) => {
            this.currentIndex = index
            this.isSeeking = false
            this.manager.activate(index)
          })
          .width('100%')
          .height('100%')
        } else if (this.ready) {
          Text('暂无可播放视频')
            .fontSize(17)
            .fontColor(Color.White)
            .alignSelf(ItemAlign.Center)
        }

        if (this.ready && this.items.length > 0) {
          this.BottomControls()
        }

        if (this.manager.onSwiping && this.manager.currentPlayer) {
          Row() {
            SwipingPlayTimePanelBuilder({
              isSliderPlayTimeChange: false,
              playTime: this.manager.swipingTime,
              totalTime: this.manager.currentPlayer.duration,
              pixelMap: null
            })
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .hitTestBehavior(HitTestMode.Transparent)
        }

        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(20)
            .fontColor([Color.White])
        }
        .width(40)
        .height(40)
        .backgroundColor('#55000000')
        .position({ x: 14, y: 14 })
        .onClick(() => this.pathStack.pop())
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Black)
      .onAreaChange((_oldValue: Area, newValue: Area) => {
        this.containerWidth = Math.floor(new Number(newValue.width).valueOf())
        this.containerHeight = Math.floor(new Number(newValue.height).valueOf())
      })
    }
    .hideTitleBar(true)
    .onReady(() => {
      const paramsList = this.pathStack.getParamByName(NavigationAddress.SHORT_VIDEO) as ShortVideoParams[]
      const params = paramsList[0]
      if (!params) {
        this.ready = true
        return
      }
      this.items = params.metadataList
      this.currentIndex = Math.max(0, Math.min(params.initialIndex, Math.max(this.items.length - 1, 0)))
      this.skipHistory = params.skipHistory
      this.manager.configure(this.items, this.skipHistory, (completedIndex: number) => {
        if (completedIndex < this.items.length - 1) {
          this.swiperController.changeIndex(completedIndex + 1, true)
        }
      })
      this.ready = true
      this.manager.activate(this.currentIndex)
    })
    .onHidden(() => {
      this.manager.saveCurrentHistory()
      if (!Setting.allowBackgroundPlay && !PiPWindowUtil.pipOpenState) {
        this.manager.pauseAll()
      }
    })
    .onShown(async () => {
      if (PiPWindowUtil.pipOpenState) {
        await PiPWindowUtil.stopPip()
      }
      if (this.ready) {
        this.manager.activate(this.currentIndex)
      }
    })
    .onWillDisappear(() => {
      this.manager.saveCurrentHistory()
      if (!Setting.allowBackgroundPlay && !PiPWindowUtil.pipOpenState) {
        this.manager.pauseAll()
      }
    })
  }

  private async toggleFullScreen(): Promise<void> {
    VideoOperateUtil.fullScreenOrRotateScreen(this.containerWidth, this.containerHeight,
      WindowUtil.getWindow())
  }

  private async openPip(): Promise<void> {
    if (!await this.manager.startPip()) {
      ToolsUtil.showToast('暂时无法进入小窗，请稍后重试')
      return
    }
    WindowUtil.minimizeClick(PathUtils.appContext!)
  }

  private async dispose(): Promise<void> {
    if (this.disposed) {
      return
    }
    this.disposed = true
    await this.manager.releaseAll()
  }
}
