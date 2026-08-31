import { window, BaseGestureHandlingProposal, PageSwitchActionProposal } from '@kit.ArkUI'
import { BusinessError, SuppressWarnings, SuppressWarningsType } from '@kit.BasicServicesKit'
import { ShortVideoItem } from '../../component/ShortVideo/ShortVideoItem'
import NavigationAddress, { ShortVideoParams } from '../../common/NavigationCommon'
import { ShortVideoPlayerManager } from '../../controller/ShortVideo/ShortVideoPlayerManager'
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import { PathUtils } from '../../utils/PathUtils'
import { WindowUtil } from '../../utils/WindowUtil'
import PermissionUtil from '../../utils/PermissionUtil'
import PiPWindowUtil from '../../utils/PiPWindowUtil'
import { SafeHeight, Setting } from '../../utils/ObservedUtil'
import ToolsUtil from '../../utils/ToolsUtil'
import { PlaybackSpeedListComponent } from '../../component/PlayerComponent/PlaybackSpeedComponent'
import VideoInfoUtil from '../../utils/VideoInfoUtil'
import { SwipingPlayTimePanelBuilder } from '../../component/PlayerComponent/SwipingPlayTimePanelBuilder'
import VideoOperateUtil from '../../utils/VideoOperateUtil'
import { RepeatModeButtonComponent } from '../../component/PlayerComponent/RepeatModeButtonComponent'
import { SweetRepeatMode } from '../../common/enum/SweetRepeatMode'
import {
  AnimatedPlaybackTimeBuilder,
  PlaybackProgressSliderComponent
} from '../../component/PlayerComponent/PlaybackProgressComponent'
import { ButtonFancyModifier } from '../../common/AttributeModifierConfig'
import { XAnimation } from '../../utils/AnimationUtil'
import { AUTO_HIDE_SHOW_CONTROL_TIME } from '../../common/Constants'
import { MediaSmartGestureSession, SHORT_VIDEO_SMART_SWIPER_ID } from '../../utils/MediaSmartGestureUtil'
import { salmonLogger } from 'salmonlogger'
import KnockShareUtil, {
  KNOCK_SHARE_VIDEO_PLAYER_OWNER,
  KnockCoordinate
} from '../../utils/KnockShareUtil'

@ComponentV2
export struct ShortVideoPage {
  @Consumer('pathStack') pathStack: NavPathStack = new NavPathStack()
  @Local items: VideoMetadata[] = []
  @Local currentIndex: number = 0
  @Local ready: boolean = false
  @Local manager: ShortVideoPlayerManager = new ShortVideoPlayerManager()
  @Local containerWidth: number = 0
  @Local containerHeight: number = 0
  private skipHistory: boolean = false
  private disposed: boolean = false
  private swiperController: SwiperController = new SwiperController()
  private showControlTimer: number = 0
  private isSwiperAnimating: boolean = false
  private isSpeedMenuOpen: boolean = false
  private isProgressSeeking: boolean = false
  private smartTapPending: boolean = false
  private smartGestures: MediaSmartGestureSession = new MediaSmartGestureSession({
    canHandle: (): boolean => this.ready && !this.disposed && this.items.length > 0 &&
      !PiPWindowUtil.pipOpenState && !this.isSwiperAnimating && !this.isSpeedMenuOpen &&
      !this.isProgressSeeking && !this.manager.onSwiping && !this.smartTapPending,
    onTap: (): void => {
      void this.togglePlaybackFromSmartGesture()
    },
    onSlide: (): BaseGestureHandlingProposal | undefined => this.createSmartSwipeProposal()
  })

  aboutToAppear(): void {
    this.disposed = false
    KnockShareUtil.setShareProvider(KNOCK_SHARE_VIDEO_PLAYER_OWNER,
      (_coordinate: KnockCoordinate | undefined): VideoMetadata[] => {
        const currentVideo = this.items[this.currentIndex]
        return currentVideo ? [currentVideo] : []
      })
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
    this.smartGestures.hide()
    KnockShareUtil.clearShareProvider(KNOCK_SHARE_VIDEO_PLAYER_OWNER)
    await this.dispose()
    PermissionUtil.applyStopContinuousTask()
    WindowUtil.setKeepScreenStatus(PathUtils.appContext!, false)
    WindowUtil.setBarState(PathUtils.appContext!, true, true)
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
          backgroundBlurStyle: BlurStyle.COMPONENT_THIN,
          onAppear: () => this.isSpeedMenuOpen = true,
          onDisappear: () => this.isSpeedMenuOpen = false
        })

        RepeatModeButtonComponent({
          repeatMode: this.manager.repeatMode,
          playing: this.manager.playing,
          playTime: this.manager.currentTime,
          compact: true,
          onRepeatModeChange: (repeatMode) => this.manager.selectRepeatMode(repeatMode)
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

      Row() {
        AnimatedPlaybackTimeBuilder({
          playTime: this.manager.currentTime,
          totalTime: this.manager.duration,
          fontSize: 12,
          fontColor: '#CCFFFFFF'
        })
      }
      .margin({ top: 6, bottom: 8 })
      .width('100%')

      PlaybackProgressSliderComponent({
        playTime: this.manager.currentTime,
        totalTime: this.manager.duration,
        onSliderChange: (value: number) => this.manager.previewProgressSeek(value),
        onSliderTouch: (event: TouchEvent) => {
          if (event.type === TouchType.Down) {
            this.isProgressSeeking = true
            this.manager.beginProgressSeek()
          } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
            this.isProgressSeeking = false
            this.manager.endProgressSeek()
          }
        }
      })
        .width('100%')
    }
    .width('100%')
    .padding({
      left: 16,
      right: 16,
      top: 28,
      bottom: SafeHeight.bottomSafeHeight === 0 ? 22 : SafeHeight.bottomSafeHeight
    })
    .linearGradient({
      angle: 180,
      colors: [[Color.Transparent, 0], ['#90000000', 0.75]]
    })
    .transition(XAnimation.getAnimation('bottom', 0, false))
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
                  manager: this.manager,
                  onSingleTap: () => this.toggleShowControl(),
                  onDoubleTap: (tapX: number) => this.manager.onScreenDoubleClick(repeatItem.index, tapX,
                    this.containerWidth)
                })
              })
              .key((item: VideoMetadata) => item.date)
              .virtualScroll()
          }
          .id(SHORT_VIDEO_SMART_SWIPER_ID)
          .index(this.currentIndex)
          .vertical(true)
          .loop(this.shouldLoopSwiper())
          .indicator(false)
          .cachedCount(3)
          .duration(300)
          .curve(Curve.Ease)
          .onAnimationStart(() => this.isSwiperAnimating = true)
          .onAnimationEnd(() => this.isSwiperAnimating = false)
          .onChange((index: number) => {
            this.manager.activate(index)
            this.currentIndex = index
          })
          .width('100%')
          .height('100%')
        } else if (this.ready) {
          Text('暂无可播放视频')
            .fontSize(17)
            .fontColor(Color.White)
            .alignSelf(ItemAlign.Center)
        }

        if (this.manager.showControl && this.ready && this.items.length > 0) {
          this.BottomControls()
        }

        if (this.manager.onSwiping && this.manager.duration > 0) {
          Row() {
            SwipingPlayTimePanelBuilder({
              isSliderPlayTimeChange: false,
              playTime: this.manager.swipingTime,
              totalTime: this.manager.duration,
              pixelMap: null
            })
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .hitTestBehavior(HitTestMode.Transparent)
        }

        if (this.manager.showControl) {
          Button({ type: ButtonType.Circle, stateEffect: true }) {
            SymbolGlyph($r('sys.symbol.xmark'))
              .fontSize(22)
              .fontColor(['#f0f0f0'])
              .opacity(0.8)
          }
          .backgroundBlurStyle(BlurStyle.BACKGROUND_THIN)
          .attributeModifier(new ButtonFancyModifier(40, 40))
          .backgroundColor('#50000000')
          .position({ x: 14, y: 14 + SafeHeight.topSafeHeight })
          .transition(XAnimation.getAnimation('up', 0, false))
          .onClick(() => this.pathStack.pop())
        }
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
        this.showControls()
        return
      }
      this.items = params.metadataList
      this.currentIndex = Math.max(0, Math.min(params.initialIndex, Math.max(this.items.length - 1, 0)))
      this.skipHistory = params.skipHistory
      this.manager.configure(this.items, this.skipHistory, (targetIndex: number) => {
        this.swiperController.changeIndex(targetIndex, true)
      })
      this.ready = true
      this.manager.activate(this.currentIndex)
      this.showControls()
    })
    .onHidden(() => {
      this.smartGestures.hide()
      this.isSwiperAnimating = false
      this.isProgressSeeking = false
      this.manager.saveCurrentHistory()
      if (!Setting.allowBackgroundPlay && !PiPWindowUtil.pipOpenState) {
        this.manager.pauseAll()
      }
    })
    .onShown(async () => {
      if (!this.disposed) {
        this.smartGestures.show(this.getUIContext())
      }
      if (PiPWindowUtil.pipOpenState) {
        await PiPWindowUtil.stopPip()
      }
      if (this.ready) {
        this.manager.activate(this.currentIndex)
      }
    })
    .onWillDisappear(() => {
      this.smartGestures.hide()
      this.manager.saveCurrentHistory()
      if (!Setting.allowBackgroundPlay && !PiPWindowUtil.pipOpenState) {
        this.manager.pauseAll()
      }
    })
  }

  private async togglePlaybackFromSmartGesture(): Promise<void> {
    const player = this.manager.currentPlayer
    if (!player || (player.state !== 'playing' && player.state !== 'paused' &&
      player.state !== 'prepared' && player.state !== 'completed')) {
      return
    }
    this.smartTapPending = true
    try {
      await this.manager.toggle(this.currentIndex)
    } catch (error) {
      salmonLogger.addLog('ShortVideoPage', `智慧手势切换播放状态失败: ${error}`, true)
    } finally {
      this.smartTapPending = false
    }
  }

  @SuppressWarnings({ rules: [SuppressWarningsType.COMPATIBILITY] })
  private createSmartSwipeProposal(): BaseGestureHandlingProposal | undefined {
    if (!MediaSmartGestureSession.isSupported() || this.items.length < 2 ||
      (!this.shouldLoopSwiper() && this.currentIndex >= this.items.length - 1)) {
      return undefined
    }
    const node = this.getUIContext().getFrameNodeById(SHORT_VIDEO_SMART_SWIPER_ID)
    // Let Swiper.onChange activate the new player exactly once. Do not also call
    // showNext()/manager.activate(), which would duplicate the system action.
    return node ? new PageSwitchActionProposal(node, 1) : undefined
  }

  private shouldLoopSwiper(): boolean {
    return this.manager.repeatMode === SweetRepeatMode.LIST ||
      this.manager.repeatMode === SweetRepeatMode.RANDOM
  }

  private toggleShowControl(): void {
    if (this.manager.showControl) {
      this.clearShowControlTimer()
      this.updateShowControl(false)
      return
    }
    this.showControls()
  }

  private showControls(): void {
    this.clearShowControlTimer()
    this.updateShowControl(true)
    this.showControlTimer = setTimeout(() => {
      this.showControlTimer = 0
      this.updateShowControl(false)
    }, AUTO_HIDE_SHOW_CONTROL_TIME)
  }

  private updateShowControl(showControl: boolean): void {
    XAnimation.runWithAnimation(() => this.manager.showControl = showControl)
    WindowUtil.setBarState(PathUtils.appContext!, showControl, showControl)
  }

  private clearShowControlTimer(): void {
    if (this.showControlTimer !== 0) {
      clearTimeout(this.showControlTimer)
      this.showControlTimer = 0
    }
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
    this.clearShowControlTimer()
    await this.manager.releaseAll()
  }
}
