import { PlaybackRangeDialog, PlaybackRangeMode, PlaybackRangeValues } from '../../component/PlayerComponent/PlaybackRangeDialog'
import { playbackPolicyMarkers } from '../../component/PlayerComponent/PlaybackPolicyMarkers'
import MediaLibraryService from '../../utils/MediaLibraryService'
import { BaseGestureHandlingProposal, PageSwitchActionProposal, window } from '@kit.ArkUI'
import { Available, BusinessError, deviceInfo, SuppressWarnings, SuppressWarningsType } from '@kit.BasicServicesKit'
import { ShortVideoItem } from '../../component/ShortVideo/ShortVideoItem'
import NavigationAddress, { PlayerEngine, PlayerParams, ShortVideoParams } from '../../common/NavigationCommon'
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
  PlaybackProgressSliderBuilder
} from '../../component/PlayerComponent/PlaybackProgressComponent'
import { ButtonFancyModifier, DefaultDialogShadow } from '../../common/AttributeModifierConfig'
import { PlaybackPolicyMenuComponent } from '../../component/PlayerComponent/PlaybackPolicyMenuComponent'
import { NumberInputDialog } from '../../component/Dialog/NumberInputDialog'
import TimeUtil from '../../utils/TimeUtil'
import { XAnimation } from '../../utils/AnimationUtil'
import { AUTO_HIDE_SHOW_CONTROL_TIME } from '../../common/Constants'
import { MediaSmartGestureSession, SHORT_VIDEO_SMART_SWIPER_ID } from '../../utils/MediaSmartGestureUtil'
import { salmonLogger } from 'salmonlogger'
import KnockShareUtil, { KNOCK_SHARE_VIDEO_PLAYER_OWNER, KnockCoordinate } from '../../utils/KnockShareUtil'

@ComponentV2
export struct ShortVideoPage {
  @Consumer('pathStack') pathStack: NavPathStack = new NavPathStack()
  @Local items: VideoMetadata[] = []
  @Local currentIndex: number = 0
  @Local ready: boolean = false
  @Local manager: ShortVideoPlayerManager = new ShortVideoPlayerManager()
  @Local containerWidth: number = 0
  @Local containerHeight: number = 0
  @Local isSwiperAnimating: boolean = false
  private skipHistory: boolean = false
  private disposed: boolean = false
  @Available({ minApiVersion: 'HarmonyOS 26.0.0' }) private smartGestures: MediaSmartGestureSession =
    new MediaSmartGestureSession({
      canHandle: (): boolean => this.ready && !this.disposed && this.items.length > 0 &&
        !PiPWindowUtil.pipOpenState && !this.isSwiperAnimating && !this.isSpeedMenuOpen &&
        !this.isPolicyMenuOpen && !this.isTimerDialogOpen && !this.isRangeDialogOpen &&
        !this.isProgressSeeking && !this.manager.onSwiping && !this.smartTapPending,
      onTap: (): void => {
        void this.togglePlaybackFromSmartGesture()
      },
      onSlide: (): BaseGestureHandlingProposal | undefined => this.createSmartSwipeProposal()
    })
  private disposeTask: Promise<void> | undefined = undefined
  private switchingToMpv: boolean = false
  private swiperController: SwiperController = new SwiperController()
  private showControlTimer: number = 0
  private isSpeedMenuOpen: boolean = false
  private isPolicyMenuOpen: boolean = false
  private isTimerDialogOpen: boolean = false
  private isRangeDialogOpen: boolean = false
  private isProgressSeeking: boolean = false
  private smartTapPending: boolean = false
  private pageParams: ShortVideoParams | undefined = undefined
  private sleepTimerDialog: CustomDialogController = new CustomDialogController({
    builder: NumberInputDialog({
      title: ToolsUtil.getStringResource($r('app.string.timer_custom_minutes').id),
      placeholderColor: ToolsUtil.getStringResource($r('app.string.timer_minutes_range').id),
      confirm: (minutes: number): void => {
        if (!Number.isInteger(minutes) || minutes < 1 || minutes > 1440) {
          ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.timer_minutes_range').id))
          return
        }
        if (this.disposed || this.manager.isClosing) { return }
        this.manager.policy.sleepTimer.start(minutes * 60000)
        ToolsUtil.showToast(ToolsUtil.getStringResourceArgs($r('app.string.timer_set_minutes').id, minutes))
      }
    }), cornerRadius: 20, shadow: DefaultDialogShadow,
    onWillAppear: () => { this.isTimerDialogOpen = true; this.clearShowControlTimer() },
    onDidDisappear: () => { this.isTimerDialogOpen = false; if (!this.disposed) { this.showControls() } }
  })

  private rangeMode: PlaybackRangeMode = 'ab'
  private rangeMediaKey: string = ''
  private rangeDuration: number = 0
  private rangeEditorDialog: CustomDialogController = new CustomDialogController({
    builder: PlaybackRangeDialog({
      options: {
        mode: this.rangeMode,
        getDuration: (): number => this.rangeDuration,
        getCurrentPosition: (): number => this.rangeMediaKey === this.currentRangeMediaKey() ?
          (this.manager.currentPlayer?.playbackPositionMs ?? 0) : Number.NaN,
        getRange: (): PlaybackRangeValues => this.rangeMode === 'ab' ?
          { start: this.manager.policy.abLoop.pointA, end: this.manager.policy.abLoop.pointB } :
          { start: this.manager.policy.openingEnding.startTime, end: this.manager.policy.openingEnding.endTime },
        onSave: (start: number, end: number): boolean => this.saveEditedRange(start, end),
        onClear: (): boolean => this.saveEditedRange(0, 0)
      }
    }), cornerRadius: 20, shadow: DefaultDialogShadow,
    onWillAppear: () => { this.isRangeDialogOpen = true; this.clearShowControlTimer() },
    onDidDisappear: () => { this.isRangeDialogOpen = false; if (!this.disposed) { this.showControls() } }
  })

  @SuppressWarnings({ rules: [SuppressWarningsType.SYSCAP] })
  aboutToAppear(): void {
    this.disposed = false
    this.pageParams = this.readShortVideoParams()
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

  @SuppressWarnings({ rules: [SuppressWarningsType.SYSCAP] })
  async aboutToDisappear(): Promise<void> {
    await this.dispose()
  }

  @Builder
  PlaybackSpeedMenuBuilder() {
    PlaybackSpeedListComponent({
      selectedSpeed: this.manager.selectedSpeed,
      onSpeedChange: (speed: number) => this.manager.selectSpeed(speed)
    })
  }

  @Builder
  PlaybackPolicyMenuBuilder() {
    PlaybackPolicyMenuComponent({
      sleepTimer: this.manager.policy.sleepTimer,
      abLoop: this.manager.policy.abLoop,
      openingEnding: this.manager.policy.openingEnding,
      onEditRange: (mode: PlaybackRangeMode): void => this.openRangeEditor(mode),
      onSetIntro: (): void => this.saveOpeningEndingPoint('start'),
      onSetOutro: (): void => this.saveOpeningEndingPoint('end'),
      onClearOpeningEnding: (): void => this.saveOpeningEndingPoint('clear'),
      onStartTimer: (durationMs: number) => this.manager.policy.sleepTimer.start(durationMs),
      onCancelTimer: () => this.manager.policy.sleepTimer.cancel(),
      onEndCurrent: () => this.manager.policy.stopAfterCurrent(),
      onCustomTimer: (): void => { this.sleepTimerDialog.open() },
      onSetPointA: () => this.saveAbPoint('A'),
      onSetPointB: () => this.saveAbPoint('B'),
      onClearAbLoop: () => this.saveAbPoint('clear'),
      onABCircleStatusClick: (): void => {
        if (!this.manager.policy.toggleAbLoop()) {
          ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.ab_loop_invalid_range').id))
        }
      }
    })
  }

  @Builder
  BottomControls() {
    Column() {
      Row({ space: 8 }) {
        Text(VideoInfoUtil.getVideoTitle(this.items[this.currentIndex]?.title))
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)

        Button({ type: ButtonType.Circle, stateEffect: false }) {
          SymbolGlyph($r('sys.symbol.rectangle_portrait_filled_on_rectangle_portrait'))
            .fontSize(21)
            .fontColor([Color.White])
        }
        .width(40)
        .height(40)
        .backgroundColor(Color.Transparent)
        .onClick(() => this.openPip())

        Button({ type: ButtonType.Circle, stateEffect: false }) {
          Text(`${this.manager.selectedSpeed}x`)
            .fontSize(13)
            .fontColor(Color.White)
            .maxLines(1)
        }
        .width(40)
        .height(40)
        .backgroundColor(Color.Transparent)
        .bindMenu(this.PlaybackSpeedMenuBuilder, {
          placement: Placement.TopRight,
          showInSubWindow: false,
          onAppear: () => { this.isSpeedMenuOpen = true; this.clearShowControlTimer() },
          onDisappear: () => { this.isSpeedMenuOpen = false; if (!this.disposed) { this.showControls() } }
        })

        RepeatModeButtonComponent({
          repeatMode: this.manager.repeatMode,
          playing: this.manager.playing,
          playTime: this.manager.currentTime,
          compact: true,
          onRepeatModeChange: (repeatMode) => this.manager.selectRepeatMode(repeatMode)
        })

        Button({ type: ButtonType.Circle, stateEffect: false }) {
          SymbolGlyph($r('sys.symbol.gearshape'))
            .fontSize(21)
            .fontColor([Color.White])
        }
        .width(40)
        .height(40)
        .backgroundColor(Color.Transparent)
        .bindMenu(this.PlaybackPolicyMenuBuilder, {
          placement: Placement.TopRight,
          showInSubWindow: false,
          onAppear: () => { this.isPolicyMenuOpen = true; this.clearShowControlTimer() },
          onDisappear: () => { this.isPolicyMenuOpen = false; if (!this.disposed) { this.showControls() } }
        })

        Button({ type: ButtonType.Circle, stateEffect: false }) {
          SymbolGlyph($r('sys.symbol.fullscreen'))
            .fontSize(21)
            .fontColor([Color.White])
        }
        .width(40)
        .height(40)
        .backgroundColor(Color.Transparent)
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

      PlaybackProgressSliderBuilder({
        playTime: this.manager.currentTime,
        totalTime: this.manager.duration,
        markers: playbackPolicyMarkers(this.manager.policy),
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
            Repeat<VideoMetadata>(this.manager.playbackItems)
              .each((repeatItem: RepeatItem<VideoMetadata>) => {
                ShortVideoItem({
                  item: repeatItem.item,
                  index: this.manager.getItemIndex(repeatItem.item),
                  currentIndex: this.currentIndex,
                  isSwitching: this.isSwiperAnimating,
                  manager: this.manager,
                  onPlayWithMpv: () => this.openFailedVideoWithMpv(repeatItem.item),
                  onSingleTap: () => this.toggleShowControl(),
                  onDoubleTap: (tapX: number) => this.manager.onScreenDoubleClick(
                    this.manager.getItemIndex(repeatItem.item), tapX,
                    this.containerWidth)
                })
              })
              .key((item: VideoMetadata) => item.date)
              .virtualScroll()
          }
          .id(SHORT_VIDEO_SMART_SWIPER_ID)
          .index(Math.max(0, this.manager.getSwiperIndex(this.currentIndex)))
          .vertical(true)
          .loop(this.shouldLoopSwiper())
          .indicator(false)
          .cachedCount(3)
          .duration(300)
          .curve(Curve.Ease)
          .onAnimationStart(() => this.isSwiperAnimating = true)
          .onAnimationEnd(() => this.isSwiperAnimating = false)
          .onChange((index: number) => {
            if (this.disposed || this.switchingToMpv) {
              return
            }
            const playbackIndex = this.manager.getPlaybackIndex(index)
            if (playbackIndex >= 0) {
              this.manager.activate(playbackIndex)
              this.currentIndex = playbackIndex
            }
          })
          .width('100%')
          .height('100%')
        } else if (this.ready) {
          Text($r('app.string.no_playable_video'))
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
              seekStartTime: this.manager.seekStartTime,
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
          Button({ type: ButtonType.Circle, stateEffect: false }) {
            SymbolGlyph($r('sys.symbol.xmark'))
              .fontSize(22)
              .fontColor(['#f0f0f0'])
              .opacity(0.8)
          }
          .attributeModifier(new ButtonFancyModifier(40, 40))
          .backgroundColor(Color.Transparent)
          .position({ x: 14, y: 14 + SafeHeight.topSafeHeight })
          .transition(XAnimation.getAnimation('up', 0, false))
          .onClick(() => this.closePage())
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
    .onBackPressed(() => {
      this.closePage()
      return true
    })
    .onReady(() => {
      if (this.disposed) {
        return
      }
      const params = this.pageParams ?? this.readShortVideoParams()
      if (!params) {
        this.ready = true
        this.showControls()
        return
      }
      this.items = params.metadataList
      this.currentIndex = Math.max(0, Math.min(params.initialIndex, Math.max(this.items.length - 1, 0)))
      this.skipHistory = params.skipHistory
      this.manager.policy.sleepTimer.onExpired = (): void => this.closePage()
      this.manager.policy.onAbLoopFailed = (): void => {
        if (!this.disposed) {
          ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.ab_loop_seek_failed').id))
        }
      }
      this.manager.configure(this.items, this.skipHistory, (targetIndex: number) => {
        if (!this.disposed && !this.switchingToMpv) {
          this.swiperController.changeIndex(this.manager.getSwiperIndex(targetIndex), true)
        }
      }, this.currentIndex)
      this.ready = true
      this.manager.activate(this.currentIndex)
      this.showControls()
    })
    .onHidden(() => {
      if (deviceInfo.apiAvailable('26.0.0')) {
        this.smartGestures.hide()
      }
      this.isSwiperAnimating = false
      this.isProgressSeeking = false
      this.manager.saveCurrentHistory()
      if (!Setting.allowBackgroundPlay && !PiPWindowUtil.pipOpenState) {
        this.manager.pauseAll()
      }
    })
    .onShown(async () => {
      if (this.disposed || this.switchingToMpv || this.manager.isClosing ||
        this.manager.policy.sleepTimer.checkDeadline()) {
        return
      }
      if (deviceInfo.apiAvailable('26.0.0')) {
        this.smartGestures.show(this.getUIContext())
      }
      if (PiPWindowUtil.pipOpenState) {
        await PiPWindowUtil.stopPip()
      }
      if (this.ready && !this.disposed && !this.switchingToMpv) {
        this.manager.activate(this.currentIndex)
      }
    })
    .onWillDisappear(() => {
      this.manager.beginClosing()
      if (deviceInfo.apiAvailable('26.0.0')) {
        this.smartGestures.hide()
      }
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
    if (this.disposed || this.manager.isClosing) { return }
    this.clearShowControlTimer()
    this.updateShowControl(true)
    this.showControlTimer = setTimeout(() => {
      this.showControlTimer = 0
      if (this.isPolicyMenuOpen || this.isTimerDialogOpen || this.isRangeDialogOpen || this.isSpeedMenuOpen) { return }
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
      ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.float_window_unavailable').id))
      return
    }
    WindowUtil.minimizeClick(PathUtils.appContext!)
  }

  private async openFailedVideoWithMpv(item: VideoMetadata): Promise<void> {
    if (this.disposed || this.switchingToMpv || this.isSwiperAnimating ||
      this.items[this.currentIndex]?.date !== item.date || this.manager.currentPlayer?.state !== 'error') {
      return
    }
    this.switchingToMpv = true
    const params = new PlayerParams(item, this.items.slice(), undefined, this.skipHistory, PlayerEngine.MPV_PLAYER)
    const shortVideoParams = this.readShortVideoParams()
    try {
      MediaLibraryService.saveLastPlayVideoIndex(this.items, item.date)
      this.ready = false
      // 先完成旧页面清理，避免其延迟回调关闭新播放器的会话、屏幕常亮或系统栏。
      await this.dispose()
      const paths = this.pathStack.getAllPathName()
      if (paths[paths.length - 1] !== NavigationAddress.SHORT_VIDEO ||
        this.readShortVideoParams() !== shortVideoParams) {
        return
      }
      WindowUtil.setBarColor('#FFFFFF')
      this.pathStack.replacePathByName(NavigationAddress.VIDEO_PLAYER, params, false)
    } catch (_) {
      salmonLogger.addLog('ShortVideoPage', '切换到 MPV 播放器失败', true)
      ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.switch_player_engine_failed').id))
    } finally {
      this.switchingToMpv = false
    }
  }

  private dispose(): Promise<void> {
    if (!this.disposeTask) {
      this.disposed = true
      this.manager.beginClosing()
      this.rangeEditorDialog.close()
      this.clearShowControlTimer()
      this.disposeTask = this.releasePage()
    }
    return this.disposeTask
  }

  @SuppressWarnings({ rules: [SuppressWarningsType.SYSCAP] })
  private async releasePage(): Promise<void> {
    if (deviceInfo.apiAvailable('26.0.0')) {
      this.smartGestures.hide()
    }
    KnockShareUtil.clearShareProvider(KNOCK_SHARE_VIDEO_PLAYER_OWNER)
    try {
      await this.manager.releaseAll()
    } finally {
      PermissionUtil.applyStopContinuousTask()
      WindowUtil.setKeepScreenStatus(PathUtils.appContext!, false)
      WindowUtil.setBarState(PathUtils.appContext!, true, true)
      WindowUtil.recoveryBarColor()
      try {
        const windowClass = await WindowUtil.getWindow()
        await windowClass?.setPreferredOrientation(window.Orientation.AUTO_ROTATION_RESTRICTED)
      } catch (_error) {
      }
    }
  }

  private readShortVideoParams(): ShortVideoParams | undefined {
    const paramsList = this.pathStack.getParamByName(NavigationAddress.SHORT_VIDEO) as ShortVideoParams[]
    return paramsList.length > 0 ? paramsList[paramsList.length - 1] : undefined
  }

  private closePage(): void {
    if (this.disposed || this.switchingToMpv) { return }
    try {
      MediaLibraryService.saveLastPlayVideoIndex(this.items, this.items[this.currentIndex]?.date)
    } catch (error) {
      salmonLogger.addLog('ShortVideoPage', `保存播放索引失败: ${error}`, true)
    }
    const routeIndex = this.pathStack.size() - 1
    const params = this.readShortVideoParams()
    void this.dispose().catch((error: Error) => {
      salmonLogger.addLog('ShortVideoPage', `退出短视频失败: ${error.message}`, true)
    }).then((): void => {
      if (this.pathStack.size() - 1 === routeIndex &&
        this.pathStack.getAllPathName()[routeIndex] === NavigationAddress.SHORT_VIDEO &&
        this.readShortVideoParams() === params) { this.pathStack.pop() }
    })
  }

  private saveAbPoint(point: 'A' | 'B' | 'clear'): void {
    try {
      if (!this.manager.policy.saveAbPoint(PathUtils.appContext!, point)) {
        ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.ab_loop_invalid_range').id))
        return
      }
      const loop = this.manager.policy.abLoop
      ToolsUtil.showToast(point === 'clear' ?
        ToolsUtil.getStringResource($r('app.string.cancel_ab_time_success').id) :
        ToolsUtil.getStringResourceArgs(point === 'A' ? $r('app.string.set_point_a_time').id :
          $r('app.string.set_point_b_time').id, TimeUtil.convertMSToHHMMSS(point === 'A' ? loop.pointA : loop.pointB)))
    } catch (error) {
      salmonLogger.addLog('ShortVideoPage', `保存 AB 点位失败: ${error}`, true)
      ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.ab_loop_save_failed').id))
    }
  }
  private currentRangeMediaKey(): string {
    const media = this.manager.nowPlaying
    return media ? media.date + '|' + media.uri : ''
  }

  private openRangeEditor(mode: PlaybackRangeMode): void {
    if (this.disposed || this.manager.isClosing) { return }
    this.manager.policy.refresh()
    if (this.manager.policy.sleepTimer.checkDeadline() || this.disposed || this.manager.isClosing) { return }
    this.rangeMode = mode
    this.rangeMediaKey = this.currentRangeMediaKey()
    this.rangeDuration = this.manager.policy.abLoop.durationMs
    this.rangeEditorDialog.open()
  }

  private saveEditedRange(start: number, end: number): boolean {
    if (this.disposed || this.manager.isClosing || this.rangeMediaKey !== this.currentRangeMediaKey()) { return false }
    try {
      return this.rangeMode === 'ab' ? this.manager.policy.saveAbRange(PathUtils.appContext!, start, end) :
        this.manager.policy.saveOpeningEnding(PathUtils.appContext!, start, end)
    } catch (error) {
      salmonLogger.addLog('PlaybackRange', `保存区间失败: ${error}`, true)
      return false
    }
  }

  private saveOpeningEndingPoint(point: 'start' | 'end' | 'clear'): void {
    try {
      if (!this.manager.policy.saveOpeningEndingPoint(PathUtils.appContext!, point)) {
        ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.range_invalid').id))
        return
      }
      ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.save_success').id))
    } catch (error) {
      salmonLogger.addLog('PlaybackRange', `保存片头片尾失败: ${error}`, true)
      ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.range_save_failed').id))
    }
  }

}
