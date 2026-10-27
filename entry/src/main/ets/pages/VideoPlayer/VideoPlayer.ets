import BluRayDirectory from '../../utils/BluRayDirectory'
import { PlaybackRangeDialog, PlaybackRangeMode, PlaybackRangeValues } from '../../component/PlayerComponent/PlaybackRangeDialog'
import { playbackPolicyMarkers } from '../../component/PlayerComponent/PlaybackPolicyMarkers'
import { PlayerGestureController } from '../../controller/PlayerGestureController'
import { PlayerViewportState } from '../../controller/PlayerViewportState'
import { AppForegroundState } from '../../utils/AppForegroundState'
import { PlayerControlAutoHide } from '../../controller/PlayerControlAutoHide'
import { HiCar } from '../../utils/HiCarUtil'
import { framePreviewSession } from '../../utils/FFmpegThumbnailUtil'
import MediaLibraryService from '../../utils/MediaLibraryService'
import TimeUtil from '../../utils/TimeUtil'
import { DanmakuSession } from '../../utils/DanmakuSession'
import { DanmakuOverlay } from '../../component/PlayerComponent/DanmakuOverlay'
import { DanmakuMenuComponent } from '../../component/PlayerComponent/DanmakuMenuBuilder'
import PermissionUtil from '../../utils/PermissionUtil'
import { BaseGestureHandlingProposal, UIUtils, window } from '@kit.ArkUI'
import { KeyCode, pointer } from '@kit.InputKit'
import { KeyboardShortcuts, ShortcutAction } from '../../utils/KeyboardShortcuts'
import ToolsUtil from '../../utils/ToolsUtil'
import VideoInfoUtil from '../../utils/VideoInfoUtil'
import VideoOperateUtil from '../../utils/VideoOperateUtil'
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import { PathUtils } from '../../utils/PathUtils'
import { PlayerSideBarComponent } from '../../component/PlayerComponent/PlayerSideBarComponent'
import { LockVideoBarComponent } from '../../component/PlayerComponent/LockVideoBarComponent'
import { GestureComponent } from '../../component/PlayerComponent/GestureComponent'
import NavigationAddress, { PlayerEngine, PlayerParams } from '../../common/NavigationCommon'
import WantProcessUtil from '../../utils/WantProcessUtil'
import { WindowUtil } from '../../utils/WindowUtil'
import { XAnimation } from '../../utils/AnimationUtil'
import { Subtitle3DMode, SubtitleMode } from '../../common/enum/SubtitleMode'
import { SubtitleManager } from '../../utils/SubtitleManager'
import { FastForwardPanelBuilder } from '../../component/PlayerComponent/FastForwardPanelBuilder'
import { SwipingPanelBuilder } from '../../component/PlayerComponent/SwipingPanelBuilder'
import { SwipingPlayTimePanelBuilder } from '../../component/PlayerComponent/SwipingPlayTimePanelBuilder'
import { SubtitleDisplayBuilder } from '../../component/PlayerComponent/SubtitleDisplayBuilder'
import { Pc, Privacy, Setting } from '../../utils/ObservedUtil'
import { AVPlayerController } from '../../controller/AVPlayerController/AVPlayerController'
import { MpvController } from '../../controller/MpvController/MpvController'
import { MpvPlayerState } from '../../controller/MpvController/MpvPlayerState'
import { PlayerControllerFactory, PlayerControllerInterface } from '../../controller/PlayerControllerFactory'
import { PlaybackSessionController } from '../../controller/PlaybackSessionController'
import { XComponents } from '../../component/PlayerComponent/XComponents'
import { VideoLayoutComponent } from '../../component/PlayerComponent/VideoLayoutComponent'
import {
  AUTO_HIDE_SHOW_CONTROL_TIME,
  DEFAULT_ANGLE,
  MIRRORED_ANGLE,
  NO_BLUR_AMOUNT,
  PRIVACY_BACKGROUND_BLUR_AMOUNT,
  VOLUME_STEP
} from '../../common/Constants'
import PiPWindowUtil from '../../utils/PiPWindowUtil'
import { DefaultDialogShadow } from '../../common/AttributeModifierConfig'
import { NumberInputDialog } from '../../component/Dialog/NumberInputDialog'
import { AudioEffectDialog } from '../../component/Dialog/AudioEffectDialog'
import { SubtitleOffsetDialog } from '../../component/Dialog/SubtitleOffsetDialog'
import SubtitleUtil from '../../utils/SubtitleUtil'
import { SweetRepeatMode } from '../../common/enum/SweetRepeatMode'
import { AudioTrackComponent } from '../../component/PlayerComponent/AudioTrackComponent'
import { VideoTrackComponent } from '../../component/PlayerComponent/VideoTrackComponent'
import { AVCastPickerBuilder } from '../../component/PlayerComponent/AVCastPickerBuilder'
import { ChapterListComponent } from '../../component/PlayerComponent/ChapterListComponent'
import { PlaybackSpeedMenuComponent } from '../../component/PlayerComponent/PlaybackSpeedComponent'
import { SubtitlePanelComponent } from '../../component/PlayerComponent/SubtitlePanelComponent'
import { VideoButtonsComponent } from '../../component/PlayerComponent/VideoButtonsComponent'
import { VideoSettingComponent } from '../../component/PlayerComponent/VideoSettingComponent'
import { VideoSliderComponent } from '../../component/PlayerComponent/VideoSliderComponent'
import { VideoTopComponent } from '../../component/PlayerComponent/VideoTopComponent'
import Preferences from '../../database/Preferences'
import PlaybackExitCoordinator from '../../utils/PlaybackExitCoordinator'
import { salmonLogger } from 'salmonlogger'
import { AISubtitleComponent } from '../../component/PlayerComponent/AIAsrComponent'
import AVSessionUtil from '../../utils/AVSessionUtil'
import { Available, deviceInfo, SuppressWarnings, SuppressWarningsType } from '@kit.BasicServicesKit'
import { MediaSmartGestureSession } from '../../utils/MediaSmartGestureUtil'
import { motion } from '@kit.MultimodalAwarenessKit'
import IntellectualGripPostureUtil from '../../utils/IntellectualGripPostureUtil'
import KnockShareUtil, { KNOCK_SHARE_VIDEO_PLAYER_OWNER, KnockCoordinate } from '../../utils/KnockShareUtil'
import { AudioEffectConfig } from '../../interfaces/AudioEffectInterface'

const TAG = 'VideoPlayer'
const AUTO_LISTEN_VIDEO_FOREGROUND_FALLBACK_MS = 150

type PlayerType = PlayerControllerInterface

@ComponentV2
export struct VideoPlayer {
  @Param @Once initialPlayerEngine: string = PlayerEngine.AV_PLAYER
  @Local danmakuPageVisible: boolean = false
  @Local importingSubtitle: boolean = false
  @Local playerType: string = this.initialPlayerEngine
  @Local autoListenVideoEnabled: boolean = false
  @Local player: PlayerType = PlayerControllerFactory.createController(this.initialPlayerEngine)
  subtitleManager: SubtitleManager = new SubtitleManager(this.player)
  audioEffectDialog: CustomDialogController = new CustomDialogController({
    builder: AudioEffectDialog({
      isSystemPlayer: (): boolean => this.player instanceof AVPlayerController,
      getCurrentConfig: (): AudioEffectConfig => {
        if (this.player instanceof MpvController || this.player instanceof AVPlayerController) {
          return AudioEffectConfig.copy(this.player.audioEffectConfig)
        }
        return new AudioEffectConfig()
      },
      onApply: async (config: AudioEffectConfig, silent?: boolean): Promise<boolean> => {
        const player = this.player
        if (!(player instanceof MpvController) && !(player instanceof AVPlayerController)) {
          return false
        }
        if (config.effect === 'hoa-space-render' && !deviceInfo.apiAvailable('26.0.0')) {
          throw new Error(ToolsUtil.getStringResource($r('app.string.hoa_needs_harmony7').id))
        }
        const applied = player instanceof MpvController ?
          player.audioController.applyAudioEffect(config) : await player.applyAudioEffect(config)
        if (!silent) {
          ToolsUtil.showToast(applied ? ToolsUtil.getStringResource($r('app.string.audio_effect_applied').id) :
            ToolsUtil.getStringResource($r('app.string.audio_effect_apply_failed_mpv').id))
        }
        return applied
      }
    }), cornerRadius: 20, shadow: DefaultDialogShadow,
    onWillAppear: () => this.onKeyboardOverlay('audio-dialog', true),
    onDidDisappear: () => this.onKeyboardOverlay('audio-dialog', false)
  })
  personalScreenExtendDialog: CustomDialogController = new CustomDialogController({
    builder: NumberInputDialog({
      title: ToolsUtil.getStringResource($r('app.string.custom_screen_ratio').id),
      placeholderColor: ToolsUtil.getStringResource($r('app.string.custom_ratio_range').id),
      confirm: (input: number): void => {
        if (input && input <= 150 && input >= 50) {
          this.player.selectedText = `自定义比例:${input}`
          Preferences.saveScreenExtend(PathUtils.appContext!, this.player.selectedText)
          this.player.playAreaHeight = input / 100 * VideoInfoUtil.playAreaHeight
          this.player.playAreaWidth = input / 100 * VideoInfoUtil.playAreaWidth
          this.player.scaleFactor = 1

        } else {
          ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.custom_ratio_invalid').id))
        }
      },
    }), cornerRadius: 20, shadow: DefaultDialogShadow,
    onWillAppear: () => this.onKeyboardOverlay('aspect-dialog', true),
    onDidDisappear: () => this.onKeyboardOverlay('aspect-dialog', false)
  })
  @Local isPlayerConfigured: boolean = false
  private sleepTimerDialog: CustomDialogController = new CustomDialogController({
    builder: NumberInputDialog({
      title: ToolsUtil.getStringResource($r('app.string.timer_custom_minutes').id),
      placeholderColor: ToolsUtil.getStringResource($r('app.string.timer_minutes_range').id),
      confirm: (minutes: number): void => {
        if (!Number.isInteger(minutes) || minutes < 1 || minutes > 1440) {
          ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.timer_minutes_range').id))
          return
        }
        if (this.isPageDisappearing || this.playbackSession.isClosing) { return }
        this.playbackSession.sleepTimer.start(minutes * 60000)
        ToolsUtil.showToast(ToolsUtil.getStringResourceArgs($r('app.string.timer_set_minutes').id, minutes))
      }
    }), cornerRadius: 20, shadow: DefaultDialogShadow,
    onWillAppear: () => this.onKeyboardOverlay('sleep-timer', true),
    onDidDisappear: () => this.onKeyboardOverlay('sleep-timer', false)
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
          this.player.playbackPositionMs : Number.NaN,
        getRange: (): PlaybackRangeValues => this.rangeMode === 'ab' ?
          { start: this.playbackSession.policy.abLoop.pointA, end: this.playbackSession.policy.abLoop.pointB } :
          { start: this.playbackSession.policy.openingEnding.startTime, end: this.playbackSession.policy.openingEnding.endTime },
        onSave: (start: number, end: number): boolean => this.saveEditedRange(start, end),
        onClear: (): boolean => this.saveEditedRange(0, 0)
      }
    }), cornerRadius: 20, shadow: DefaultDialogShadow,
    onWillAppear: () => { this.onKeyboardOverlay('playback-range', true) },
    onDidDisappear: () => { this.onKeyboardOverlay('playback-range', false) }
  })

  @Local subtitlePreferenceRestored: boolean = false
  xComponentController: XComponentController = new XComponentController()
  osdXController: XComponentController = new XComponentController()
  windowClass: Promise<window.Window | undefined> = WindowUtil.getWindow()
  @Local sideBarStatusTmp: Visibility = Visibility.Hidden
  @Local sideBarStatus: boolean = false
  @Consumer('pathStack') pathStack: NavPathStack = new NavPathStack()
  @Local isAdjustingSubtitleOffset: boolean = false
  @Local lockRotation: boolean = false
  @Local playerExitTransitionEnabled: boolean = false
  @Local danmaku: DanmakuSession = new DanmakuSession()
  private containerWidth: number = 0
  private containerHeight: number = 0
  private gestures: PlayerGestureController = new PlayerGestureController(this.player)
  @Local playbackSession: PlaybackSessionController = new PlaybackSessionController()
  private isPageDisappearing: boolean = false
  private playerExitToken: number | undefined = undefined
  private waitingForPreviousExit: boolean = false
  private exitProgressSave: Promise<void> | undefined = undefined
  private backgroundViewport: PlayerViewportState = new PlayerViewportState()
  private playerDestinationShown: boolean = false
  private appForegroundSubscription: number = 0
  private appBackgrounded: boolean = false
  private controlTouches: Set<number> = new Set<number>()
  private controlsIdle: PlayerControlAutoHide = new PlayerControlAutoHide(AUTO_HIDE_SHOW_CONTROL_TIME,
    () => this.canAutoHideControls(), () => { this.player.showControl = false })
  private keyboard: KeyboardShortcuts = new KeyboardShortcuts()
  private keyboardBusy: boolean = false
  private keyboardSeekTime: number | undefined = undefined
  private keyboardSeekAt: number = 0
  private keyboardSeekDate: string = ''
  private keyboardVolume: number = 1
  private keyboardSubtitleMode: SubtitleMode = SubtitleMode.NONE
  private keyboardSubtitleDate: string = ''
  private keyboardOverlays: Set<string> = new Set()
  @Local keyboardSubtitleMenuVisible: boolean = false

  private canAutoHideControls(): boolean {
    return this.playerDestinationShown && !this.isPageDisappearing && !this.playbackSession.isDisposed &&
      this.player.showControl && !this.sideBarStatus && !this.importingSubtitle &&
      !this.isAdjustingSubtitleOffset && !this.player.onSwiping && !this.player.isSliderPlayTimeChange &&
      !this.player.isGesturing && !this.player.longPress && !this.player.onSwipingVoice &&
      !this.player.onSwipingBrightness
  }

  @Monitor('sideBarStatus', 'importingSubtitle', 'isAdjustingSubtitleOffset',
    'player.onSwiping', 'player.isSliderPlayTimeChange', 'player.isGesturing', 'player.longPress',
    'player.onSwipingVoice', 'player.onSwipingBrightness')
  onControlInteractionStateChanged(): void {
    this.controlsIdle.refresh()
  }

  private onControlTouch(event: TouchEvent): void {
    if (event.type === TouchType.Cancel) {
      this.controlTouches.clear()
    } else if (event.type === TouchType.Down) {
      event.changedTouches.forEach(touch => this.controlTouches.add(touch.id))
    } else if (event.type === TouchType.Up) {
      event.changedTouches.forEach(touch => this.controlTouches.delete(touch.id))
    }
    this.controlsIdle.setHeld('touch', this.controlTouches.size > 0)
  }
  @Local holdingHand: motion.HoldingHandStatus | null = null
  private holdingHandCallback: Callback<motion.HoldingHandStatus> = (status: motion.HoldingHandStatus): void => {
    if (!this.playerDestinationShown || this.isPageDisappearing || !Setting.gripPostureEnabled) {
      return
    }
    if (status === motion.HoldingHandStatus.LEFT_HAND_HELD ||
      status === motion.HoldingHandStatus.RIGHT_HAND_HELD) {
      this.holdingHand = status
    }
  }
  private playerReadyToStart: boolean = false
  @Available({ minApiVersion: 'HarmonyOS 26.0.0' }) private smartGestures: MediaSmartGestureSession =
    new MediaSmartGestureSession({
      canHandle: (): boolean => this.isPlayerConfigured && !this.isPageDisappearing &&
        !this.playbackSession.isDisposed && !this.playbackSession.isSwitching && !this.player.isLock &&
        !PiPWindowUtil.pipOpenState && !this.sideBarStatus && !this.isAdjustingSubtitleOffset &&
        !this.player.onSwiping && !this.player.isSliderPlayTimeChange && !this.player.longPress &&
        !this.player.isGesturing && !this.player.onSwipingVoice && !this.player.onSwipingBrightness,
      onTap: (): void => {
        this.player.togglePlayback()
      },
      onSlide: (): BaseGestureHandlingProposal | undefined => {
        this.player.fastForward()
        return undefined
      }
    })
  private pageParams: PlayerParams | undefined = undefined
  private subtitleOffsetPreviewBase: number = 0
  private subtitleOffsetShouldResumePlayback: boolean = false
  private isAdjustingMpvSubtitleOffset: boolean = false
  subtitleTimestampInputDialog: CustomDialogController = new CustomDialogController({
    builder: SubtitleOffsetDialog({
      getCurrentValue: (): number => SubtitleUtil.offsetMillis,
      onOffsetPreview: (offset: number): void => {
        this.player.subtitleController.setSubtitleOffset(offset)
      },
      onCloseButton: (): void => {
        this.cancelSubtitleOffsetSession()
        this.subtitleTimestampInputDialog.close()
      },
      onPrevSubtitle: (currentOffset: number): number | undefined => {
        return this.player.getAdjacentSubtitleOffset('prev', currentOffset)
      },
      onNextSubtitle: (currentOffset: number): number | undefined => {
        return this.player.getAdjacentSubtitleOffset('next', currentOffset)
      },
      showSubtitleNavigation: (): boolean => !this.isAdjustingMpvSubtitleOffset,
      confirm: (input: number): void => {
        if (Number.isNaN(input)) {
          ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.subtitle_offset_empty').id))
          this.cancelSubtitleOffsetSession()
          this.subtitleTimestampInputDialog.close()
        } else if (Math.abs(input) <= 50000) {
          SubtitleUtil.offsetMillis = input
          this.player.subtitleController.setSubtitleOffset(input)
          this.finishSubtitleOffsetSession()
          this.subtitleManager.savePreference()
          this.subtitleTimestampInputDialog.close()
        } else {
          ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.subtitle_offset_range').id))
        }
      },
    }),
    cornerRadius: 20,
    shadow: DefaultDialogShadow,
    onWillAppear: () => this.onKeyboardOverlay('subtitle-offset-dialog', true),
    onDidDisappear: () => this.onKeyboardOverlay('subtitle-offset-dialog', false),
    maskColor: '#00000000',
    cancel: (): void => {
      this.cancelSubtitleOffsetSession()
    }
  })
  private autoListenVideoSession: number = 0
  private autoListenVideoWindowResumedSession: number = 0
  private autoListenVideoRestoreTimer: number = 0
  private autoListenVideoRestoreInFlightSession: number = 0
  private observedWindowStage: window.WindowStage | undefined = undefined
  private windowStageEventCallback: ((event: window.WindowStageEventType) => void) | undefined = undefined
  private monitoredPlayer: PlayerControllerInterface | undefined = undefined
  private playerMonitorVersion: number = 0
  private subtitleSelectedMonitorCallback: ((mon: IMonitor) => void) | undefined = undefined
  private danmakuMediaMonitorCallback: ((mon: IMonitor) => void) | undefined = undefined

  @Monitor('danmaku.enabled', 'danmaku.items', 'danmakuPageVisible', 'isPlayerConfigured', 'player')
  syncDanmakuVrrPolicy(): void {
    if (this.player instanceof MpvController) {
      // An enabled but empty/hidden overlay does not need to suppress VRR.
      this.player.setDanmakuVisible(this.danmakuPageVisible &&
        !PiPWindowUtil.pipOpenState && this.danmaku.enabled && this.danmaku.items.length > 0)
    }
  }

  @Monitor('player.showControl')
  onShowControlMonitor(_mon: IMonitor) {
    this.controlsIdle.refresh()
    if (!Pc.pcMode || this.isPageDisappearing || this.playbackSession.isDisposed) {
      return
    }
    if (canIUse("SystemCapability.MultimodalInput.Input.Pointer")) {
      pointer.setPointerVisible(this.player.showControl).catch(() => {
        salmonLogger.addLog(TAG, `setPointerVisible failed`, true)
      })
    }
  }

  onSubtitleSelectedMonitor(_mon: IMonitor) {
    this.subtitleManager.syncFromPlayer()
  }

  @SuppressWarnings({ rules: [SuppressWarningsType.SYSCAP] })
  aboutToAppear(): void {
    this.isPageDisappearing = false
    this.playerDestinationShown = false
    this.playerReadyToStart = false
    this.playerExitTransitionEnabled = false
    this.appBackgrounded = false
    this.observeAppForeground()
    this.pageParams = this.readPlayerParams()
    KnockShareUtil.setShareProvider(KNOCK_SHARE_VIDEO_PLAYER_OWNER,
      (_coordinate: KnockCoordinate | undefined): VideoMetadata[] => {
        return this.player.nowPlaying ? [this.player.nowPlaying] : []
      })
    salmonLogger.addLog(TAG, "开始执行aboutToAppear方法", false)
    PermissionUtil.applyContinuousTask()
    // 退出时已恢复自动方向；入场不再异步重置，避免覆盖引擎的智能横屏请求。
    WindowUtil.setKeepScreenStatus(PathUtils.appContext!, true)
    salmonLogger.addLog(TAG, "aboutToAppear方法执行完成", false)
  }

  async aboutToDisappear(): Promise<void> {
    this.beginPlayerExit()
    this.playerDestinationShown = false
    this.stopHoldingHandSubscription()
    this.playerReadyToStart = false
    this.danmakuPageVisible = false
    this.danmaku.dispose()
    this.isPageDisappearing = true
    this.stopAutoListenVideoRestoreObservation()
    if (deviceInfo.apiAvailable('26.0.0')) {
      this.smartGestures.hide()
    }
    KnockShareUtil.clearShareProvider(KNOCK_SHARE_VIDEO_PLAYER_OWNER)
    this.player.onWillDisappearCleanup()
    this.controlsIdle.stop()
    this.controlTouches.clear()
    try {
      await this.restoreAutomaticOrientation()
      salmonLogger.addLog(TAG, "开始执行aboutToDisappear方法", false)
      try {
        VideoOperateUtil.setBrightness(-1)
        WindowUtil.recoveryBarColor()
        if (Pc.pcMode && canIUse("SystemCapability.MultimodalInput.Input.Pointer")) {
          pointer.setPointerVisible(true).catch(() => {
            salmonLogger.addLog(TAG, 'restore pointer visible failed', true)
          })
        }
      } catch (error) {
        salmonLogger.addLog(TAG, `恢复播放页窗口状态失败: ${error}`, true)
      }
      try {
        Preferences.saveRepeatModeState(PathUtils.appContext!, this.player.repeatMode)
        this.player.onDisappearSaveSubtitlePreference(this.subtitleManager.subtitleVisibility,
          this.subtitleManager.isAIAsrShown, this.subtitleManager.subtitle3DMode)
        MediaLibraryService.saveLastPlayVideoIndex(this.player.videoMetaDataList, this.player.nowPlaying?.date)
        await this.exitProgressSave
        await Preferences.flushPending(PathUtils.appContext!)
      } catch (error) {
        salmonLogger.addLog(TAG, `保存退出播放记录失败: ${error}`, true)
      }
      this.player.onDisappearCleanup()
      this.gestures.reset()
      this.backgroundViewport.clear()
      this.unregisterPlayerMonitors(this.player)
      try {
        await AVSessionUtil.stopCastingIfActive()
      } catch (error) {
        salmonLogger.addLog(TAG, `停止投屏失败: ${error}`, true)
      } finally {
        PermissionUtil.applyStopContinuousTask()
      }
      await PiPWindowUtil.destroyPipController()
      WindowUtil.disableLandscapeMultiWindow(this.getWindowClass())
      WindowUtil.setKeepScreenStatus(PathUtils.appContext!, false)
      await this.player.restoreSystemBars(this.windowClass)
    } catch (error) {
      salmonLogger.addLog(TAG, `播放页退出清理失败: ${error}`, true)
    } finally {
      try {
        await this.playbackSession.dispose(() => this.player)
      } catch (error) {
        salmonLogger.addLog(TAG, `释放播放会话失败: ${error}`, true)
      } finally {
        if (this.playerExitToken !== undefined) PlaybackExitCoordinator.finishExit(this.playerExitToken)
        this.playerExitToken = undefined
      }
    }
    salmonLogger.addLog(TAG, "播放页退出清理结束", false)
    salmonLogger.addLog(TAG, "aboutToDisappear方法执行完成", false)
  }

  closeSideBar(isPlayAnimation: boolean) {
    this.sideBarStatusTmp = Visibility.Hidden
    isPlayAnimation ? setTimeout(() => {
      this.sideBarStatus = false
    }, 400) : this.sideBarStatus = false
  }

  private onKeyboardOverlay(name: string, visible: boolean): void {
    this.controlsIdle.setHeld(name, visible)
    if (visible) {
      this.keyboardOverlays.add(name)
      // 弹层可能消费抬键事件；由弹层自身接管暂停计时，避免关闭后控制栏一直不消失。
      for (const code of this.keyboard.heldKeyCodes) this.controlsIdle.setHeld('key-' + code, false)
    }
    else {
      this.keyboardOverlays.delete(name)
      this.keyboard.reset()
    }
  }

  private handlePlayerShortcut(event: KeyEvent, surfaceFocused: boolean): boolean {
    if (!this.playerDestinationShown || !this.isPlayerConfigured || this.isPageDisappearing ||
      this.playbackSession.isDisposed || this.playbackSession.isSwitching || this.importingSubtitle ||
      this.isAdjustingSubtitleOffset || this.keyboardOverlays.size > 0) return false
    const action = KeyboardShortcuts.player(event, surfaceFocused)
    if (action === undefined || (this.player.isLock && action !== ShortcutAction.ESCAPE)) return false
    if (this.keyboardBusy || !this.keyboard.accept(action)) return true
    this.controlsIdle.activity()
    this.keyboardBusy = true
    this.executePlayerShortcut(action).catch((error: Error) => {
      salmonLogger.addLog(TAG, '播放快捷键失败: ' + error.message, true)
    }).finally(() => { this.keyboardBusy = false })
    event.stopPropagation()
    return true
  }

  private captureCurrentFrame(): void {
    const player = this.player
    const metadata = player.nowPlaying
    const requestId = VideoOperateUtil.nextCaptureRequestId()
    salmonLogger.addLog(TAG, `[Screenshot#${requestId}] click: engine=${player.isMpvPlayer() ? 'mpv' : 'avplayer'}, ` +
      `hasMedia=${metadata !== undefined}, configured=${this.isPlayerConfigured}, exiting=${this.isPageDisappearing}`, false)
    if (!metadata || !this.isPlayerConfigured || this.isPageDisappearing) {
      salmonLogger.addLog(TAG, `[Screenshot#${requestId}] ignored: reason=player_not_ready`, false)
      return
    }
    const date = metadata.date
    void VideoOperateUtil.saveCaptureScreenToAlbum(metadata.uri, player.playbackPositionMs,
      () => !this.isPageDisappearing && this.player === player && this.player.nowPlaying?.date === date, requestId)
  }

  private async executePlayerShortcut(action: ShortcutAction): Promise<void> {
    switch (action) {
      case ShortcutAction.PLAY_PAUSE:
        this.player.togglePlayback()
        break
      case ShortcutAction.SEEK_BACK:
      case ShortcutAction.SEEK_FORWARD:
      case ShortcutAction.SEEK_BACK_SMALL:
      case ShortcutAction.SEEK_FORWARD_SMALL:
        this.seekFromKeyboard(action)
        break
      case ShortcutAction.VOLUME_UP:
      case ShortcutAction.VOLUME_DOWN:
        this.setKeyboardVolume(VideoOperateUtil.changeVolume(this.player.volumeActually,
          action === ShortcutAction.VOLUME_UP ? VOLUME_STEP : -VOLUME_STEP))
        break
      case ShortcutAction.BRIGHTNESS_UP:
      case ShortcutAction.BRIGHTNESS_DOWN:
        this.gestures.adjustBrightness(action === ShortcutAction.BRIGHTNESS_UP ? 0.05 : -0.05)
        break
      case ShortcutAction.MUTE:
        if (this.player.volumeActually > 0) {
          this.keyboardVolume = this.player.volumeActually
          this.setKeyboardVolume(0)
        } else this.setKeyboardVolume(VideoOperateUtil.changeVolume(this.keyboardVolume, 0))
        break
      case ShortcutAction.FULLSCREEN:
        await VideoOperateUtil.fullScreenOrRotateScreen(this.player.screenWidth, this.player.screenHeight, this.getWindowClass())
        break
      case ShortcutAction.ESCAPE:
        if (this.sideBarStatus) {
          this.closeSideBar(false)
          this.getUIContext().getFocusController().requestFocus('player_surface_focus')
        } else {
          await WindowUtil.exitFullScreen(this.getWindowClass(), this.player.screenWidth, this.player.screenHeight)
        }
        break
      case ShortcutAction.BACK:
        if (this.sideBarStatus) this.closeSideBar(false)
        else this.exitVideo(0)
        break
      case ShortcutAction.PREVIOUS:
        await this.playPreviousFromControl()
        break
      case ShortcutAction.NEXT:
        await this.playNextFromControl()
        break
      case ShortcutAction.SPEED_DOWN:
      case ShortcutAction.SPEED_UP:
        const speeds = VideoInfoUtil.videoSpeedListAll
        const requestedSpeed = this.player.getRequestedPlaybackSpeed?.() ?? this.player.speed
        const faster = speeds.find(speed => speed > requestedSpeed + 0.001)
        const slower = speeds.slice().reverse().find(speed => speed < requestedSpeed - 0.001)
        this.player.updatePlaybackSpeed((action === ShortcutAction.SPEED_UP ? faster : slower) ?? requestedSpeed)
        break
      case ShortcutAction.SPEED_RESET:
        this.player.updatePlaybackSpeed(1)
        break
      case ShortcutAction.SUBTITLE:
        this.toggleKeyboardSubtitle()
        break
      case ShortcutAction.SUBTITLE_MENU:
        this.player.showControl = true
        this.keyboardSubtitleMenuVisible = true
        break
      case ShortcutAction.PLAYLIST:
        if (this.sideBarStatus) this.closeSideBar(false)
        else {
          this.sideBarStatusTmp = Visibility.Visible
          this.sideBarStatus = true
        }
        break
    }
  }

  private setKeyboardVolume(volume: number): void {
    this.player.volume = volume
    this.player.volumeActually = volume
  }

  private seekFromKeyboard(action: ShortcutAction): void {
    const now = Date.now()
    const date = this.player.nowPlaying?.date ?? ''
    if (this.keyboardSeekTime === undefined || now - this.keyboardSeekAt > 300 || this.keyboardSeekDate !== date) {
      this.keyboardSeekTime = this.player.playbackPositionMs
    }
    this.keyboardSeekDate = date
    this.keyboardSeekAt = now
    const small = action === ShortcutAction.SEEK_BACK_SMALL || action === ShortcutAction.SEEK_FORWARD_SMALL
    const backward = action === ShortcutAction.SEEK_BACK || action === ShortcutAction.SEEK_BACK_SMALL
    const step = (small ? 1 : Number(Setting.fastForwardSeconds)) * 1000 * (backward ? -1 : 1)
    const duration = this.player.nowPlaying?.time ?? 0
    this.keyboardSeekTime = Math.max(0, Math.min(duration > 0 ? duration : Number.MAX_SAFE_INTEGER, this.keyboardSeekTime + step))
    this.player.seekTime(this.keyboardSeekTime)
  }

  private toggleKeyboardSubtitle(): void {
    const date = this.player.nowPlaying?.date ?? ''
    if (this.keyboardSubtitleDate !== date) {
      this.keyboardSubtitleDate = date
      this.keyboardSubtitleMode = SubtitleMode.NONE
    }
    if (this.subtitleManager.isAnySubtitleActive) {
      this.keyboardSubtitleMode = this.subtitleManager.subtitleMode
      this.subtitleManager.switchToNone()
    } else if (this.keyboardSubtitleMode === SubtitleMode.AI_SUBTITLE) this.subtitleManager.switchToAI()
    else if (this.keyboardSubtitleMode === SubtitleMode.EXTERNAL_SUBTITLE ||
      (this.keyboardSubtitleMode === SubtitleMode.NONE && this.player.nowPlaying?.external_subtitle_format)) {
      this.subtitleManager.switchToExternal()
    } else if (this.player.subtitleTrack.length > 0) this.subtitleManager.switchToInner()
  }

  private stopHoldingHandSubscription(): void {
    IntellectualGripPostureUtil.destroyHoldingHandStatus(this.holdingHandCallback)
  }

  @SuppressWarnings({ rules: [SuppressWarningsType.SYSCAP] })
  build() {
    NavDestination() {
      SideBarContainer(SideBarContainerType.Overlay) {
        PlayerSideBarComponent({
          player: this.player,
          sideBarStatusTmp: this.sideBarStatusTmp,
          onSideBarStatusTmpChange: (v: Visibility) => {
            this.sideBarStatusTmp = v
          },
          sideBarStatus: this.sideBarStatus,
          onSideBarStatusChange: (v: boolean) => {
            this.sideBarStatus = v
          },
          onItemClick: async (item: VideoMetadata) => {
            await this.player.playChooseVideo(item, this.pathStack, this.windowClass, this.xComponentController)
            this.player.setPlayerCallback(this.pathStack, this.xComponentController, this.windowClass)
            this.closeSideBar(true)
          }
        })

        Stack() {
          if (this.isPlayerConfigured) {
            XComponents({
              player: this.player,
              xComponentController: this.xComponentController,
              xComponentId: this.player.getXComponentId(),
              libraryName: this.player.getLibraryName(),
              choosePlayer: this.player.isMpvPlayer() ? PlayerEngine.MPV_PLAYER : PlayerEngine.AV_PLAYER,
              barState: this.player.showControl,
              osdXController: this.player.isMpvPlayer() ? this.osdXController : undefined,
              osdVisibility: this.player.getOsdVisibility(),
              onXComponentLoad: async (surfaceController: XComponentController | undefined,
                surfaceEngine: string) => {
                if (this.isPageDisappearing) {
                  return
                }
                const surfacePlayer = this.player
                const currentEngine =
                  surfacePlayer.isMpvPlayer() ? PlayerEngine.MPV_PLAYER : PlayerEngine.AV_PLAYER
                if (!surfaceController || currentEngine !== surfaceEngine) {
                  return
                }
                if (this.isPageDisappearing) {
                  return
                }
                await surfacePlayer.onSurfaceLoad(surfaceController, this.pathStack, this.windowClass)
              },
              onPlayerKey: (event: KeyEvent): boolean => this.handlePlayerShortcut(event, true),
              onPlayerFocus: () => this.controlsIdle.setHeld('keyboard-navigation', false),
              onOsdSurfaceLoad: (surfaceId: string, surfaceWidth: number, surfaceHeight: number) => {
                this.player.onOsdSurfaceLoad(surfaceId, surfaceWidth, surfaceHeight)
              },
              onOsdSurfaceDestroy: (surfaceId: string) => {
                this.player.onOsdSurfaceDestroy(surfaceId)
              },
            })
          }

          if (this.isPlayerConfigured && this.danmaku.enabled && this.danmaku.items.length > 0) {
            DanmakuOverlay({
              session: this.danmaku,
              mediaKey: this.danmakuMediaKey(),
              playbackTime: this.player.playbackPositionMs,
              playing: this.player.playing,
              buffering: this.player.networkBuffering,
              seeking: this.player.onSwiping || this.player.isSliderPlayTimeChange,
              speed: this.player.speed,
              visible: this.danmakuPageVisible && !PiPWindowUtil.pipOpenState
            })
          }

          if (this.player.showControl && !this.player.isLock) {
            VideoLayoutComponent({
              player: this.player,
              VideoTop: () => {
                this.VideoTop()
              },
              VideoButtons: () => {
                this.VideoButtons()
              },
              VideoSlider: () => {
                this.VideoSlider()
              },
            })
          }

          if (this.player.longPress) {
            FastForwardPanelBuilder({
              speed: this.player.speed,
              location: VideoInfoUtil.playAreaHeight,
              speedLocked: this.player.speedLocked,
            })
          }
          if (this.player.onSwiping) {
            SwipingPlayTimePanelBuilder({
              seekStartTime: this.gestures.seekStartTime,
              isSliderPlayTimeChange: this.player.isSliderPlayTimeChange,
              playTime: this.player.playTime,
              totalTime: this.player.nowPlaying!.time,
              pixelMap: this.player.pixelMap,
            })
          }

          SwipingPanelBuilder({
            videoVolume: this.player.volume,
            videoVolumeShow: this.player.volumeActually,
            onSwipingVoice: this.player.onSwipingVoice,
            onSwipingBrightness: this.player.onSwipingBrightness,
            screenBrightness: this.player.screenBrightness,
            playAreaHeight: VideoInfoUtil.playAreaHeight
          })
          if (this.player.showControl && !HiCar.enabled) {
            LockVideoBarComponent({
              player: this.player,
              buttonsOnLeft: IntellectualGripPostureUtil.isLeftHoldHand(this.holdingHand),
              onLockClick: () => {
                this.player.isLock = !this.player.isLock
                this.player.showControl = true
              },
              onCaptureScreen: () => {
                this.captureCurrentFrame()
              }
            })
          }
          GestureComponent({
            player: this.player,
            onDoubleClickAction: (tapX: number) => {
              this.player.onScreenDoubleClick(tapX)
            },
            onSingleClickAction: () => {
              if (this.sideBarStatus) {
                this.closeSideBar(true)
              } else {
                XAnimation.runWithAnimation(() => {
                  this.player.showControl = !this.player.showControl
                })
              }
            },
            onVerticalPanStart: (tapX: number) => this.gestures.onVerticalPanStart(tapX),
            onVerticalPanUpdate: (offsetY: number) => this.gestures.onVerticalPanUpdate(offsetY),
            onVerticalPanEnd: () => this.gestures.onVerticalPanEnd(),
            onVerticalPanCancel: () => this.gestures.onVerticalPanCancel(),
            onHorizonPanStart: () => this.gestures.onHorizonPanStart(),
            onHorizonPanUpdate: (offsetX: number) => this.gestures.onHorizonPanUpdate(offsetX),
            onHorizonPanEnd: () => this.gestures.onHorizonPanEnd(),
            onHorizonPanCancel: () => this.gestures.onHorizonPanCancel(),
            onPinchStart: (event: GestureEvent) => this.gestures.onPinchStart(event),
            onPinchUpdate: (event: GestureEvent) => this.gestures.onPinchUpdate(event),
            onPinchEnd: () => this.gestures.onPinchEnd(),
            onLongPressAction: () => this.gestures.onLongPressAction(),
            onLongPressEnd: () => this.gestures.onLongPressEnd(),
            onLongPressPanStart: (tapX: number) => this.gestures.onLongPressPanStart(tapX),
            onLongPressPanUpdate: (tapX: number) => this.gestures.onLongPressPanUpdate(tapX),
            onLongPressVerticalPanUpdate: (offsetY: number) => this.gestures.onLongPressVerticalPanUpdate(offsetY),
            onPanMoveStart: (event: GestureEvent) => this.gestures.onPanMoveStart(event),
            onPanMoveUpdate: (event: GestureEvent) => this.gestures.onPanMoveUpdate(event),
            onPanMoveEnd: () => this.gestures.onPanMoveEnd(),
            onScrollAxisBegin: (isLeftSide: boolean) => this.gestures.onScrollAxisBegin(isLeftSide),
            onScrollAxisUpdate: (axisValue: number, isLeftSide: boolean) => this.gestures.onScrollAxisUpdate(axisValue,
              isLeftSide),
            onScrollAxisEnd: () => this.gestures.onScrollAxisEnd()
          })
            .hitTestBehavior(HitTestMode.Transparent)

          SubtitleDisplayBuilder({
            subtitle: this.player.subtitle,
            screenWidth: this.player.screenWidth,
            screenHeight: this.player.screenHeight,
            showControl: this.player.showControl,
            subTitleVisibility: this.subtitleManager.subtitleVisibility,
            subtitle3DMode: this.subtitleManager.effective3DMode,
            subtitlePosition: this.player.subtitlePosition,
            subtitleSize: this.player.subtitleSize,
            areaWidth: this.player.playAreaWidth,
            areaHeight: this.player.playAreaHeight,
            angle: this.player.angle,
            scaleFactor: this.player.scaleFactor,
            translateX: this.player.translateX,
            translateY: this.player.translateY,
            animDuration: this.player.playTime > 300 ? 300 : 0
          })

          AISubtitleComponent({
            isAIAsrShown: this.subtitleManager.isAIAsrShown,
            showControl: this.player.showControl,
            screenHeight: this.player.screenHeight,
            screenWidth: this.player.screenWidth
          })

        }
        .onAreaChange((_oldValue: Area, newValue: Area) => {
          const width = Math.floor(new Number(newValue.width).valueOf())
          const height = Math.floor(new Number(newValue.height).valueOf())
          if (!Number.isFinite(width) || !Number.isFinite(height) || width <= 0 || height <= 0) return
          this.containerWidth = width
          this.containerHeight = height
          PlayerViewportState.resize(this.player, width, height)
        })
        .height('100%')
        .width('100%')
        .backgroundColor($r('sys.color.black'))
        .onMouse((event: MouseEvent) => {
          if (Pc.pcMode && event.action === MouseAction.Move && !this.player.showControl) {
            this.player.showControl = true
          }
          if (event.action === MouseAction.Move) this.controlsIdle.setHeld('keyboard-navigation', false)
          if (event.action === MouseAction.Press) this.controlsIdle.setHeld('mouse', true)
          else if (event.action === MouseAction.Release) this.controlsIdle.setHeld('mouse', false)
          else this.controlsIdle.activity()
        })
      }
      .showControlButton(false)
      .onChange((value: boolean) => {
        this.sideBarStatus = value
      })
      .sideBarWidth(300)
      .showSideBar(this.sideBarStatus)
      .sideBarPosition(SideBarPosition.End)
      .divider({ strokeWidth: 0 })
    }
    // 进入播放页不使用入场动画；返回继续使用默认退场动画。
    .systemTransition(this.playerExitTransitionEnabled ? NavigationSystemTransitionType.DEFAULT :
      NavigationSystemTransitionType.NONE)
    .onReady(() => {
      if (this.isPageDisappearing) {
        return
      }
      this.playbackSession.beginClosing()
      this.rangeEditorDialog.close()
      const session = new PlaybackSessionController()
      this.playbackSession = session
      session.sleepTimer.onExpired = (): void => {
        if (this.playbackSession === session) { this.exitVideo(0) }
      }
      session.onAbLoopFailed = (): void => {
        if (this.playbackSession === session && !this.isPageDisappearing) {
          ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.ab_loop_seek_failed').id))
        }
      }
      this.isPlayerConfigured = false
      const playerParams = this.pageParams ?? this.readPlayerParams()
      if (!playerParams) {
        return
      }
      try {
        this.playerType = playerParams.playerType ?? PlayerEngine.AV_PLAYER
        if (this.player.isMpvPlayer() !== (this.playerType === PlayerEngine.MPV_PLAYER)) {
          this.unregisterPlayerMonitors(this.player)
          this.player = PlayerControllerFactory.createController(this.playerType)
          this.gestures = new PlayerGestureController(this.player)
          this.subtitleManager = new SubtitleManager(this.player)
        }

        this.bindEngineSwitchHandler(this.player)
        this.registerPlayerMonitors(this.player)
        const metadata = playerParams.metadata as VideoMetadata
        this.player.nowPlaying = metadata
        this.playbackSession.bindPlayer(this.player)
        if (playerParams.resumeFromCard) {
          const position = Number.isFinite(metadata.last_play) ? Math.max(0, metadata.last_play) : 0
          this.player.initialPlayTime = metadata.time > 0 && position >= metadata.time * 0.95 ? 0 : position
        }
        if (playerParams.metadata_list) {
          this.player.videoMetaDataList = playerParams.metadata_list as VideoMetadata[]
        } else if (playerParams!.folder_date) {
          setTimeout(() => {
            const folders = Preferences.getFileFolder(PathUtils.appContext!)
            const folder = folders.find(f => f.date === playerParams!.folder_date)
            if (folder) {
              this.player.videoMetaDataList = folder.video_list
            }
          }, 0)
        }
        this.player.skipHistory = playerParams.skipHistory
        this.player.repeatMode = Preferences.getRepeatModeState(PathUtils.appContext!)
        const videoSpeed = Preferences.getVideoSpeed(PathUtils.appContext!)
        this.player.speed = parseFloat(videoSpeed?.replace('x', '') || '1')
        this.player.selectedText = Preferences.getScreenExtend(PathUtils.appContext!)
        this.restoreSubtitlePreference()
        if (this.isPageDisappearing) {
          this.player.onWillDisappearCleanup()
          return
        }
        this.playerReadyToStart = true
        this.startPlayerAfterDestinationShown()
      } catch (e) {
        salmonLogger.addLog(TAG, e, true)
      }
    })
    .onBackPressed(() => {
      if (!this.isPlayerConfigured) {
        return false
      }
      if (this.sideBarStatus) {
        this.closeSideBar(true)
        return true
      }
      if (this.player.showControl && !Setting.allowPlayBackExist) {
        this.player.showControl = false

        return true
      }
      return false
    })
    .onShown(() => {
      if (this.playbackSession.sleepTimer.checkDeadline() || this.playbackSession.isClosing ||
        this.isPageDisappearing) { return }
      this.keyboard.reset()
      this.playerExitTransitionEnabled = true
      this.playerDestinationShown = true
      this.controlsIdle.start()
      IntellectualGripPostureUtil.createHoldingHandStatus(this.holdingHandCallback)
      this.startPlayerAfterDestinationShown()
      this.gestures.reset()
      this.player.volumeGestureActive = false
      this.danmakuPageVisible = true
      WantProcessUtil.setCardPlaybackHandler(this.cardPlaybackHandler)
      if (!this.isPageDisappearing) {
        if (deviceInfo.apiAvailable('26.0.0')) {
          this.smartGestures.show(this.getUIContext())
        }
      }
      this.player.onSwiping = false
      this.player.isSliderPlayTimeChange = false
      this.player.onSwipingVoice = false
      this.player.onSwipingBrightness = false
      WindowUtil.setKeepScreenStatus(PathUtils.appContext!, true)
      this.restoreAfterAppBackground()
    })
    .onHidden(() => {
      this.keyboard.reset()
      this.controlsIdle.stop()
      this.controlTouches.clear()
      this.playerDestinationShown = false
      this.stopHoldingHandSubscription()
      this.gestures.reset()
      this.player.volumeGestureActive = false
      this.danmakuPageVisible = false
      if (deviceInfo.apiAvailable('26.0.0')) {
        this.smartGestures.hide()
      }
      salmonLogger.addLog(TAG, "开始执行onHidden生命周期", false)
      this.player.onSwiping = false
      this.player.isSliderPlayTimeChange = false
      this.player.onSwipingVoice = false
      this.player.onSwipingBrightness = false
      if (this.isPageDisappearing) return
      void this.savePlaybackProgress().then(() => Preferences.flushPending(PathUtils.appContext!))
        .catch((error: Error) => salmonLogger.addLog(TAG, `保存页面隐藏播放记录失败: ${error.message}`, true))
    })
    .onWillDisappear(() => {
      this.beginPlayerExit()
      this.playerDestinationShown = false
      this.stopHoldingHandSubscription()
      this.playerReadyToStart = false
      this.danmakuPageVisible = false
      this.danmaku.dispose()
      WantProcessUtil.clearCardPlaybackHandler(this.cardPlaybackHandler)
      this.isPageDisappearing = true
      this.stopAutoListenVideoRestoreObservation()
      if (deviceInfo.apiAvailable('26.0.0')) {
        this.smartGestures.hide()
      }
      this.player.onWillDisappearCleanup()
      // 自动方向在 aboutToDisappear 中恢复，避免窗口旋转打断尚未完成的退场动画。
      salmonLogger.addLog(TAG, "开始执行onWillDisappear生命周期", false)
      // 转场前只停回调和记录位置；保存、会话释放在退场结束后执行。
      PiPWindowUtil.disableAutoStart()
      salmonLogger.addLog(TAG, "onWillDisappear生命周期执行完成", false)
    })
    .hideTitleBar(true)
    .onTouchIntercept((_event: TouchEvent) => {
      this.controlsIdle.setHeld('keyboard-navigation', false)
      this.controlsIdle.activity()
      return HitTestMode.Default // Observe activity without consuming child input.
    })
    .onTouch((event: TouchEvent) => this.onControlTouch(event))
    // 观察按键但不接管派发，让画面、控制栏和输入框继续处理各自的按键。
    .onKeyPreIme((event: KeyEvent): boolean => {
      this.keyboard.observe(event)
      if (event.type === KeyType.Down && event.keyCode === KeyCode.KEYCODE_TAB) {
        this.player.showControl = true
        this.controlsIdle.setHeld('keyboard-navigation', true)
      }
      this.controlsIdle.setHeld('key-' + event.keyCode, event.type === KeyType.Down)
      return false
    })
    .onKeyEvent((event: KeyEvent): boolean => this.handlePlayerShortcut(event, false))
    // 旋转期间内层播放区可能尚未铺满新尺寸，由页面底色覆盖空隙。
    .backgroundColor(Color.Black)
    .expandSafeArea([SafeAreaType.SYSTEM],
      [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM, SafeAreaEdge.START, SafeAreaEdge.END])

    .blur(Privacy.isPrivacyBackground ? PRIVACY_BACKGROUND_BLUR_AMOUNT : NO_BLUR_AMOUNT)
  }

  @SuppressWarnings({ rules: [SuppressWarningsType.SYSCAP] })
  @Builder
  VideoTop() {
    VideoTopComponent({
      player: this.player,
      onControlsOverlay: (name: string, visible: boolean) => this.onKeyboardOverlay(name, visible),
      keyboardSubtitleMenuVisible: this.keyboardSubtitleMenuVisible,
      onKeyboardSubtitleMenuChange: (visible: boolean) => { this.keyboardSubtitleMenuVisible = visible },
      isAnySubtitleActive: this.subtitleManager.isAnySubtitleActive,
      carSettingsMenu: (): void => this.VideoSettingBuilder(),
      carSpeedMenu: (): void => this.PlaybackSpeedMenuBuilder(),
      carNavigationMenu: (): void => this.HiCarNavigationMenu(),
      danmakuMenuBuilder: () => {
        this.DanmakuMenu()
      },
      lockRotation: this.lockRotation,
      audioTrackMenuBuilder: () => {
        this.AudioTrackMenuBuilder()
      },
      videoTrackMenuBuilder: () => {
        this.VideoTrackMenuBuilder()
      },
      subtitlePanelComponent: () => {
        this.SubtitleMenuBuilder()
      },
      chapterMenuBuilder: this.player.hasChapterSupport() ? () => {
        this.ChapterMenuBuilder()
      } : () => {
      },
      onExitVideoClick: () => {
        salmonLogger.addLog(TAG, "点击退出视频按钮", false)
        this.exitVideo(0)
      },
      onLockRotationClick: async () => {
        this.lockRotation = !this.lockRotation
        salmonLogger.addLog(TAG, `锁定旋转状态切换为：${this.lockRotation}`,
          false)
        const orientation = this.lockRotation ?
          (this.player.screenWidth > this.player.screenHeight ? window.Orientation.AUTO_ROTATION_LANDSCAPE_RESTRICTED
            : window.Orientation.AUTO_ROTATION_PORTRAIT_RESTRICTED)
          : window.Orientation.AUTO_ROTATION_RESTRICTED
        try {
          XAnimation.runWithAnimation(async () => {
            await (await this.getWindowClass())?.setPreferredOrientation(orientation)
            salmonLogger.addLog(TAG, "窗口方向设置成功", false)
          })
        } catch (error) {
          salmonLogger.addLog(TAG,
            `屏幕旋转异常: ${error.code}:${error.message}`, true)
        }
        const toastMessage = this.lockRotation
          ? ToolsUtil.getStringResource($r('app.string.open_rotation_lock').id)
          : ToolsUtil.getStringResource($r('app.string.close_rotation_lock').id)
        ToolsUtil.showToast(toastMessage)
      },
      onSpecificVideoProportions: (playAreaSize: number[]) => {
        this.player.playAreaWidth = playAreaSize[0]
        this.player.playAreaHeight = playAreaSize[1]
        this.player.isZoomed = false
        this.player.scaleFactor = 1
        this.player.translateX = 0
        this.player.translateY = 0
      },
      onOriginalRatio: () => {
        this.player.resetAspectRatio()
        this.player.playAreaHeight = VideoInfoUtil.playAreaHeight
        this.player.playAreaWidth = VideoInfoUtil.playAreaWidth
        this.player.isZoomed = false
        this.player.scaleFactor = 1
        this.player.translateX = 0
        this.player.translateY = 0
      },
      onStretchedToFullScreen: () => {
        this.player.stretchToFullScreen()
        this.player.playAreaHeight = this.player.screenHeight
        this.player.playAreaWidth = this.player.screenWidth
        this.player.isZoomed = false
        this.player.scaleFactor = 1
        this.player.translateX = 0
        this.player.translateY = 0
      },
      onFullScreenByWidth: () => {
        this.player.playAreaWidth = this.player.screenWidth
        this.player.playAreaHeight =
          (VideoInfoUtil.playAreaHeight / VideoInfoUtil.playAreaWidth) * this.player.screenWidth
        this.player.isZoomed = false
        this.player.scaleFactor = 1
        this.player.translateX = 0
        this.player.translateY = 0
      },
      onFullScreenByHeight: () => {
        this.player.playAreaHeight = this.player.screenHeight
        this.player.playAreaWidth =
          (VideoInfoUtil.playAreaWidth / VideoInfoUtil.playAreaHeight) * this.player.screenHeight
        this.player.isZoomed = false
        this.player.scaleFactor = 1
        this.player.translateX = 0
        this.player.translateY = 0
      },
      onUniformScale: (scale: number) => {
        this.player.playAreaHeight = scale * VideoInfoUtil.playAreaHeight
        this.player.playAreaWidth = scale * VideoInfoUtil.playAreaWidth
        this.player.isZoomed = false
        this.player.scaleFactor = 1
        this.player.translateX = 0
        this.player.translateY = 0
      },
      onSelectedTextChange: (text: string) => {
        this.player.selectedText = text
        Preferences.saveScreenExtend(PathUtils.appContext!, text)
      },
      pipStateChange: async () => {
        await PiPWindowUtil.startPip()
        WindowUtil.minimizeClick(PathUtils.appContext!)
      },
      onOpenPersonalScreenExtend: () => {
        this.personalScreenExtendDialog.open()
      }
    })
  }

  @Builder
  VideoSlider() {
    VideoSliderComponent({
      player: this.player,
      markers: playbackPolicyMarkers(this.playbackSession.policy),
      onSliderChange: (value: number, mode?: SliderChangeMode) => {
        this.controlsIdle.activity()
        const finished = mode === SliderChangeMode.End || mode === SliderChangeMode.Click
        if (!finished) { this.player.playbackPolicy?.onSeekStart() }
        this.player.isSliderPlayTimeChange = !finished
        this.player.playTime = value
        if (finished) {
          this.player.seekTime(value)
          this.player.onSwiping = false
          this.controlsIdle.refresh()
        } else {
          framePreviewSession.requestFrame(this.player, value, false)
        }
      },
      onSliderTouch: (event: TouchEvent) => {
        if (event.type == TouchType.Down) {
          this.player.playbackPolicy?.onSeekStart()
          this.player.onSwiping = true
          framePreviewSession.requestFrame(this.player, this.player.playTime, true)
        }
        if (event.type == TouchType.Up || event.type == TouchType.Cancel) {
          this.player.isSliderPlayTimeChange = false
          this.player.onSwiping = false
        }
      }
    })
  }

  @Builder
  VideoButtons() {
    VideoButtonsComponent({
      player: this.player,
      onControlsOverlay: (name: string, visible: boolean) => this.onKeyboardOverlay(name, visible),
      AVCastPickerBuilderBridge: this.AVCastPickerBuilderBridge,
      videoSettingBuilder: () => {
        this.VideoSettingBuilder()
      },
      playbackSpeedMenu: () => {
        this.PlaybackSpeedMenuBuilder()
      },
      sideBarStatusTmp: this.sideBarStatusTmp,
      onSideBarStatusTmpChange: (v: Visibility) => {
        this.sideBarStatusTmp = v
      },
      sideBarStatus: this.sideBarStatus,
      onSideBarStatusChange: (v: boolean) => {
        this.sideBarStatus = v
      },
      onScreenRotationOrFullScreenClick: async () => {
        VideoOperateUtil.fullScreenOrRotateScreen(this.player.screenWidth, this.player.screenHeight,
          this.getWindowClass())
      },
      onTogglePlaybackClick: () => {
        this.player.togglePlayback()
      },
      onPlayPreviousVideoClick: async () => this.playPreviousFromControl(),
      onPlayNextVideoClick: async () => this.playNextFromControl(),
      onSideBaClose: () => {
        this.closeSideBar(true)
      }
    })
  }

  private async playPreviousFromControl(): Promise<void> {
        const previousRepeatMode = VideoOperateUtil.getManualNavigationRepeatMode(this.player.repeatMode)
        await this.player.playPreviousVideoProcess(this.pathStack, this.windowClass,
          this.xComponentController, previousRepeatMode)
        salmonLogger.addLog(TAG, '播放上一首视频请求已发送', false)
  }

  private async playNextFromControl(): Promise<void> {
        const nextRepeatMode = VideoOperateUtil.getManualNavigationRepeatMode(this.player.repeatMode)
        await this.player.playNextVideoProcess(this.pathStack, this.windowClass, this.xComponentController, nextRepeatMode)
          .catch((error: Error) => {
            salmonLogger.addLog(TAG, `play next video failed: ${error.message}`, true)
          })
        salmonLogger.addLog(TAG, "播放下一个视频请求已发送", false)
  }

  @Builder
  HiCarNavigationMenu() {
    Menu() {
      MenuItem({ content: $r('app.string.hicar_playlist') }).height(56)
        .onClick(() => {
          this.sideBarStatusTmp = Visibility.Visible
          this.sideBarStatus = true
        })
      MenuItem({ content: $r('app.string.hicar_previous') }).height(56)
        .onClick(async () => this.playPreviousFromControl())
      MenuItem({ content: $r('app.string.hicar_next') }).height(56)
        .onClick(async () => this.playNextFromControl())
    }
  }

  @Builder
  AudioTrackMenuBuilder() {
    AudioTrackComponent({
      player: this.player,
      onSelect: (index: number) => {
        this.player.audioController.selectAudioTrackByIndex(index)
        this.player.audioTrackSelected = index
        if (!(this.player instanceof MpvController) || !this.player.audioTrack[index]?.external) {
          MediaLibraryService.saveAudioTrackPreference(this.player.nowPlaying, index,
            this.player.audioController.getAudioTrackCount())
        }
      },
      onAudioEffects: () => {
        if (this.player instanceof AVPlayerController && !this.player.supportsAudioEffects) {
          ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.system_effect_api26_required').id))
          return
        }
        this.audioEffectDialog.open()
      }
    })
  }

  @Builder
  VideoTrackMenuBuilder() {
    VideoTrackComponent({ player: this.player })
  }

  @Builder
  ChapterMenuBuilder() {
    ChapterListComponent({
      player: this.player,
      onSelect: (index: number) => {
        this.player.seekToChapter(index)
      }
    })
  }

  @Builder
  VideoSettingBuilder() {
    VideoSettingComponent({
      player: this.player,
      sleepTimer: this.playbackSession.sleepTimer,
      abLoop: this.playbackSession.policy.abLoop,
      openingEnding: this.playbackSession.policy.openingEnding,
      onEditRange: (mode: PlaybackRangeMode): void => this.openRangeEditor(mode),
      onSetIntro: (): void => this.saveOpeningEndingPoint('start'),
      onSetOutro: (): void => this.saveOpeningEndingPoint('end'),
      onClearOpeningEnding: (): void => this.saveOpeningEndingPoint('clear'),
      forward_80_s: (time: number) => {
        salmonLogger.addLog(TAG, `执行快进80秒操作，目标时间：${time}`, false)
        this.player.seekTime(time)
      },
      onStartTimer: (time: number) => this.playbackSession.sleepTimer.start(time),
      onCancelTimer: () => this.playbackSession.sleepTimer.cancel(),
      onEndCurrent: () => this.playbackSession.stopAfterCurrent(),
      onCustomTimer: (): void => { this.sleepTimerDialog.open() },
      toggleListenVideo: () => {
        this.player.toggleListenVideo()
      },
      captureScreen: () => {
        this.captureCurrentFrame()
      },
      onSetPointA: () => this.saveAbPoint('A'),
      onSetPointB: () => this.saveAbPoint('B'),
      onClearAbLoop: () => this.saveAbPoint('clear'),
      onScreenMirror: () => {
        this.player.angle === DEFAULT_ANGLE ? this.player.angle = MIRRORED_ANGLE : this.player.angle = DEFAULT_ANGLE
      },
      onABCircleStatusClick: () => {
        if (!this.playbackSession.toggleAbLoop()) {
          ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.ab_loop_invalid_range').id))
        }
      },
      onSwitchPlayerEngine: (targetEngine: string) => {
        this.switchPlayerEngine(targetEngine, 'manual switch').catch(() => {
        })
      },
    })
  }

  @Builder
  DanmakuMenu() {
    DanmakuMenuComponent({
      session: this.danmaku,
      onImport: () => {
        this.danmaku.importFile((): string => this.danmakuMediaKey())
      }
    })
  }

  @Builder
  PlaybackSpeedMenuBuilder() {
    PlaybackSpeedMenuComponent({
      player: this.player,
      onSpeedChange: (speed: number) => {
        this.player.updatePlaybackSpeed(speed)
        this.player.savePlayerSpeed(PathUtils.appContext!)
      }
    })
  }

  @Builder
  SubtitleMenuBuilder() {
    SubtitlePanelComponent({
      player: this.player,
      importingSubtitle: this.importingSubtitle,
      onImportSubtitle: () => {
        this.importPlaybackSubtitle()
      },
      subtitleManager: this.subtitleManager,
      onSubtitleOffsetTime: (useMpvSubtitle: boolean) => {
        if (useMpvSubtitle) {
          this.subtitleManager.switchToInner()
        } else {
          this.subtitleManager.switchToExternal()
        }
        this.isAdjustingMpvSubtitleOffset = useMpvSubtitle
        this.subtitleOffsetShouldResumePlayback = this.player.playing
        if (this.subtitleOffsetShouldResumePlayback) {
          this.player.pause()
        }
        this.subtitleOffsetPreviewBase = SubtitleUtil.offsetMillis
        this.isAdjustingSubtitleOffset = true
        this.player.subtitleController.setSubtitleOffset(this.subtitleOffsetPreviewBase)
        this.subtitleTimestampInputDialog.open()
      },
      onSwitchPlayerEngine: (targetEngine: string) => {
        this.switchPlayerEngine(targetEngine, 'subtitle compatibility').catch(() => {
        })
      },
    })
  }

  @Builder
  AVCastPickerBuilderBridge() {
    AVCastPickerBuilder()
  }

  private danmakuMediaKey(): string {
    const media = this.player.nowPlaying
    return media?.date || ''
  }

  private async importPlaybackSubtitle(): Promise<void> {
    const player = this.player
    const media = player.nowPlaying
    if (!media || this.importingSubtitle || this.isPageDisappearing) {
      return
    }
    this.importingSubtitle = true
    const cancelled = (): boolean => this.isPageDisappearing || this.playbackSession.isDisposed ||
      this.player !== player || this.player.nowPlaying?.date !== media.date
    try {
      const name = await SubtitleUtil.selectExternalSubtitles(PathUtils.subtitlePath, media.date, cancelled)
      if (!name || cancelled()) {
        return
      }
      const format = name.split('.').pop()?.toLowerCase() || ''
      media.external_subtitle_format = format
      MediaLibraryService.saveData(PathUtils.appContext!, media, { externalSubtitleFormat: format })
      await player.subtitleController.setExternalSubtitle(media)
      if (!cancelled()) {
        this.subtitleManager.switchToExternal()
      }
    } catch (error) {
      if (!cancelled()) {
        ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.subtitle_saved_load_failed').id))
        salmonLogger.addLog(TAG, '播放中加载外挂字幕失败', true)
      }
    } finally {
      this.importingSubtitle = false
    }
  }

  private cardPlaybackHandler = (video: VideoMetadata): boolean => {
    if (this.isPageDisappearing || !this.isPlayerConfigured) {
      return false
    }
    if (this.player.nowPlaying?.uri === video.uri && !this.player.skipHistory) {
      this.player.play()
      return true
    }
    this.player.pause()
    return false
  }

  private observeAppForeground(): void {
    this.stopAppForegroundObservation()
    this.appForegroundSubscription = AppForegroundState.subscribe((foreground: boolean): void => {
      this.onAppForegroundChanged(foreground)
    })
  }

  private stopAppForegroundObservation(): void {
    if (this.appForegroundSubscription !== 0) {
      AppForegroundState.unsubscribe(this.appForegroundSubscription)
      this.appForegroundSubscription = 0
    }
    this.appBackgrounded = false
  }

  private onAppForegroundChanged(foreground: boolean): void {
    if (this.isPageDisappearing || this.playbackSession.isClosing || this.playbackSession.isDisposed) return
    if (foreground) {
      this.startPlayerAfterDestinationShown()
      this.restoreAfterAppBackground()
      return
    }
    this.cancelAutoListenVideoRestoreTimer()
    if (!this.isPlayerConfigured) return
    this.appBackgrounded = true
    this.backgroundViewport.capture(this.player)
    salmonLogger.addLog(TAG, '[Lifecycle] Ability entered background; applying playback policy', false)
    void this.savePlaybackProgress().then(() => Preferences.flushPending(PathUtils.appContext!))
      .catch((error: Error) => salmonLogger.addLog(TAG, `保存后台播放记录失败: ${error.message}`, true))
    if (!Setting.allowBackgroundPlay && !PiPWindowUtil.pipOpenState && !PiPWindowUtil.pipStarting) {
      this.stopAutoListenVideoRestoreObservation()
      if (this.player instanceof AVPlayerController) {
        this.player.pauseForBackground()
      } else {
        this.player.pause()
      }
      salmonLogger.addLog(TAG, '后台播放已关闭，应用退后台时暂停播放', false)
      return
    }
    if (Setting.autoListenVideo &&
      (this.player instanceof AVPlayerController || this.player instanceof MpvController) &&
      !PiPWindowUtil.pipOpenState && !PiPWindowUtil.pipStarting && !Setting.autoActivePip &&
      VideoInfoUtil.hasVideoTrack(this.player.nowPlaying) && (this.autoListenVideoEnabled || !this.player.isListenVideo)) {
      this.registerWindowStageEvent()
      this.autoListenVideoSession++
      this.autoListenVideoEnabled = true
      if (!this.player.isListenVideo) {
        this.player.isListenVideo = true
        this.player.setListenVideoStatus().catch((error: Error) => {
          salmonLogger.addLog(TAG, `后台切换只听视频模式失败：${error}`, true)
        })
      }
    }
  }

  private restoreAfterAppBackground(): void {
    if ((!this.appBackgrounded && !this.autoListenVideoEnabled) || !AppForegroundState.isForeground || !this.playerDestinationShown ||
      !this.isPlayerConfigured || this.isPageDisappearing || this.playbackSession.isClosing ||
      this.playbackSession.isDisposed || this.playbackSession.sleepTimer.checkDeadline()) return
    const returningFromBackground = this.appBackgrounded
    this.appBackgrounded = false
    if (returningFromBackground) {
      salmonLogger.addLog(TAG, '[Lifecycle] Ability returned to foreground; restoring playback policy', false)
      if (this.backgroundViewport.restore(this.player)) {
        salmonLogger.addLog(TAG, `[Viewport] foreground: scale=${this.player.scaleFactor}, ` +
          `offset=${this.player.translateX},${this.player.translateY}, aspect=${this.player.selectedText}`, false)
      }
      if (PiPWindowUtil.pipOpenState) {
        PiPWindowUtil.stopPip().then(() => { this.syncDanmakuVrrPolicy() })
      }
    }
    if (this.autoListenVideoEnabled) {
      this.registerWindowStageEvent()
      const restoreDelay = this.autoListenVideoWindowResumedSession === this.autoListenVideoSession ? 0 :
        AUTO_LISTEN_VIDEO_FOREGROUND_FALLBACK_MS
      this.scheduleAutoListenVideoRestore(restoreDelay)
    } else if (returningFromBackground && this.player instanceof AVPlayerController) {
      this.player.syncForegroundPlaybackParameters().catch((error: Error) => {
        salmonLogger.addLog(TAG, `前台恢复播放参数失败: ${error.message}`, true)
      })
    }
    if (returningFromBackground && Setting.autoResumeOnReturn && !this.player.playing && !this.isPageDisappearing &&
      !this.playbackSession.isClosing) this.player.play()
  }

  private registerWindowStageEvent(): boolean {
    const windowStage = VideoOperateUtil.windowStage
    if (!windowStage) {
      return false
    }
    if (this.observedWindowStage === windowStage && this.windowStageEventCallback) {
      return true
    }
    this.unregisterWindowStageEvent()
    const callback = (event: window.WindowStageEventType): void => {
      if (event === window.WindowStageEventType.RESUMED) {
        this.autoListenVideoWindowResumedSession = this.autoListenVideoSession
        this.scheduleAutoListenVideoRestore(0)
      }
    }
    try {
      windowStage.on('windowStageEvent', callback)
      this.observedWindowStage = windowStage
      this.windowStageEventCallback = callback
      return true
    } catch (error) {
      salmonLogger.addLog(TAG, `注册窗口恢复监听失败：${error}`, true)
      return false
    }
  }

  private unregisterWindowStageEvent(): void {
    const windowStage = this.observedWindowStage
    const callback = this.windowStageEventCallback
    this.observedWindowStage = undefined
    this.windowStageEventCallback = undefined
    if (!windowStage || !callback) {
      return
    }
    try {
      windowStage.off('windowStageEvent', callback)
    } catch (error) {
      salmonLogger.addLog(TAG, `取消窗口恢复监听失败：${error}`, true)
    }
  }

  private scheduleAutoListenVideoRestore(delayMs: number): void {
    if (!this.autoListenVideoEnabled || this.isPageDisappearing || !AppForegroundState.isForeground ||
      !this.playerDestinationShown) {
      return
    }
    this.cancelAutoListenVideoRestoreTimer()
    const session = this.autoListenVideoSession
    this.autoListenVideoRestoreTimer = setTimeout(() => {
      this.autoListenVideoRestoreTimer = 0
      this.restoreAutoListenVideo(session).catch((error: Error) => {
        salmonLogger.addLog(TAG, `恢复后台视频画面失败：${error}`, true)
      })
    }, delayMs)
  }

  private async restoreAutoListenVideo(session: number): Promise<void> {
    if (session !== this.autoListenVideoSession || !this.autoListenVideoEnabled ||
      this.isPageDisappearing || !AppForegroundState.isForeground || !this.playerDestinationShown ||
      this.autoListenVideoRestoreInFlightSession === session) {
      return
    }
    const player = this.player
    if (!(player instanceof AVPlayerController) && !(player instanceof MpvController) || !player.isListenVideo) {
      if (session === this.autoListenVideoSession) {
        this.autoListenVideoEnabled = false
      }
      return
    }
    this.autoListenVideoRestoreInFlightSession = session
    try {
      await player.restoreVideoAfterBackground()
    } finally {
      if (this.autoListenVideoRestoreInFlightSession === session) {
        this.autoListenVideoRestoreInFlightSession = 0
      }
      if (session === this.autoListenVideoSession) {
        this.autoListenVideoEnabled = player.isListenVideo
      }
    }
  }

  private cancelAutoListenVideoRestoreTimer(): void {
    if (this.autoListenVideoRestoreTimer !== 0) {
      clearTimeout(this.autoListenVideoRestoreTimer)
      this.autoListenVideoRestoreTimer = 0
    }
  }

  private stopAutoListenVideoRestoreObservation(): void {
    this.autoListenVideoSession++
    this.autoListenVideoEnabled = false
    this.cancelAutoListenVideoRestoreTimer()
    this.unregisterWindowStageEvent()
  }

  private registerPlayerMonitors(p: PlayerControllerInterface): void {
    if (this.monitoredPlayer === p) {
      return
    }
    if (this.monitoredPlayer) {
      this.unregisterPlayerMonitors(this.monitoredPlayer)
    }
    const version = ++this.playerMonitorVersion
    // 捕获页面 this 和本次注册身份，旧播放器已排队的回调不能访问新会话。
    const subtitleCallback = (mon: IMonitor): void => {
      if (version !== this.playerMonitorVersion || this.player !== p ||
        this.isPageDisappearing || this.playbackSession.isDisposed) {
        return
      }
      this.onSubtitleSelectedMonitor(mon)
    }
    const mediaCallback = (_mon: IMonitor): void => {
      if (version === this.playerMonitorVersion && this.player === p &&
        !this.isPageDisappearing && !this.playbackSession.isDisposed) {
        this.playbackSession.syncMedia(p)
        this.danmaku.setMedia(this.danmakuMediaKey())
      }
    }
    try {
      UIUtils.addMonitor(p, 'subtitleSelected', subtitleCallback)
      this.subtitleSelectedMonitorCallback = subtitleCallback
      this.monitoredPlayer = p
    this.syncDanmakuVrrPolicy()
      this.danmakuMediaMonitorCallback = mediaCallback
      UIUtils.addMonitor(p, 'nowPlaying', mediaCallback)
      this.danmaku.setMedia(this.danmakuMediaKey())
      this.playbackSession.syncMedia(p)
    } catch (error) {
      this.playerMonitorVersion++
      salmonLogger.addLog(TAG, `register subtitleSelected monitor error: ${error}`, true)
    }
  }

  private unregisterPlayerMonitors(p: PlayerControllerInterface): void {
    if (this.monitoredPlayer !== p) {
      return
    }
    this.playerMonitorVersion++
    const subtitleCallback = this.subtitleSelectedMonitorCallback
    const mediaCallback = this.danmakuMediaMonitorCallback
    this.monitoredPlayer = undefined
    this.subtitleSelectedMonitorCallback = undefined
    this.danmakuMediaMonitorCallback = undefined
    try {
      if (mediaCallback) {
        UIUtils.clearMonitor(p, 'nowPlaying', mediaCallback)
      }
      if (subtitleCallback) {
        UIUtils.clearMonitor(p, 'subtitleSelected', subtitleCallback)
      }
    } catch (error) {
      salmonLogger.addLog(TAG, `unregister subtitleSelected monitor error: ${error}`, true)
    }
  }

  @SuppressWarnings({ rules: [SuppressWarningsType.SYSCAP] })
  private startPlayerAfterDestinationShown(): void {
    if (!this.playerDestinationShown || !this.playerReadyToStart || this.isPlayerConfigured ||
      !AppForegroundState.isForeground || this.isPageDisappearing || this.playbackSession.isDisposed) {
      return
    }
    if (PlaybackExitCoordinator.isExiting) {
      if (!this.waitingForPreviousExit) {
        this.waitingForPreviousExit = true
        void PlaybackExitCoordinator.waitForExit().then(() => {
          this.waitingForPreviousExit = false
          this.startPlayerAfterDestinationShown()
        })
      }
      return
    }
    try {
      // 页面完整显示后直接创建 Surface、隐藏系统栏及触发智能横屏。
      WindowUtil.setBarState(PathUtils.appContext!, false, false)
      if (Setting.defaultBrightness > 0) {
        this.player.screenBrightness = Setting.defaultBrightness / 100
        VideoOperateUtil.setBrightness(this.player.screenBrightness)
      }
      this.player.onPlayerReady()
      this.isPlayerConfigured = true
      WantProcessUtil.setCardPlaybackHandler(this.cardPlaybackHandler)
    } catch (error) {
      salmonLogger.addLog(TAG, `播放页入场后启动失败：${error}`, true)
    }
  }

  @SuppressWarnings({ rules: [SuppressWarningsType.SYSCAP] })
  private async restoreAutomaticOrientation(): Promise<void> {
    if (HiCar.enabled) { return }
    try {
      await (await this.getWindowClass())?.setPreferredOrientation(window.Orientation.AUTO_ROTATION_RESTRICTED)
    } catch (error) {
      salmonLogger.addLog(TAG, `恢复自动旋转失败：${error}`, true)
    }
  }

  private beginPlayerExit(): void {
    this.stopAppForegroundObservation()
    this.controlsIdle.stop()
    this.controlTouches.clear()
    if (this.playerExitToken !== undefined) return
    this.playerExitToken = PlaybackExitCoordinator.beginExit()
    this.exitProgressSave = this.savePlaybackProgress().catch((error: Error) => {
      salmonLogger.addLog(TAG, `保存退出播放进度失败: ${error.message}`, true)
    })
    this.isPageDisappearing = true
    this.playbackSession.beginClosing()
    this.rangeEditorDialog.close()
    this.player.initialPlaying = false
    this.player.pause()
    this.player.onWillDisappearCleanup()
  }

  private async savePlaybackProgress(): Promise<void> {
    const player = this.player
    if (player instanceof AVPlayerController) {
      await player.savePlaybackProgress()
    } else {
      if (player instanceof MpvController && ![MpvPlayerState.PLAYING, MpvPlayerState.PAUSED,
        MpvPlayerState.COMPLETED].includes(player.playerState) &&
        !(player.playerState === MpvPlayerState.BUFFERING && player.playbackPositionMs > 0)) return
      MediaLibraryService.saveVideoPlayTimeIfNeed(player.playbackPositionMs, player.nowPlaying,
        player.skipHistory, PathUtils.appContext!)
    }
  }

  private bindEngineSwitchHandler(player: PlayerControllerInterface): void {
    player.setEngineSwitchHandler(async (targetEngine: string, reason: string,
      resumePlayback?: boolean): Promise<void> => {
      if (this.player !== player || this.isPageDisappearing) {
        return
      }
      await this.switchPlayerEngine(targetEngine, reason, resumePlayback)
    })
  }

  private async switchPlayerEngine(targetEngine: string, reason: string,
    resumePlayback?: boolean): Promise<void> {
    if (targetEngine === PlayerEngine.AV_PLAYER && BluRayDirectory.isEntry(this.player.nowPlaying?.uri ?? '')) {
      ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.bluray_mpv_required').id))
      return
    }
    const currentEngine = this.player.isMpvPlayer() ? PlayerEngine.MPV_PLAYER : PlayerEngine.AV_PLAYER
    if (currentEngine === targetEngine || this.isPageDisappearing) {
      return
    }
    await this.playbackSession.runTransition(() => this.performEngineSwitch(targetEngine, reason, resumePlayback))
  }

  private async performEngineSwitch(targetEngine: string, reason: string,
    resumePlayback?: boolean): Promise<void> {
    const oldPlayer = this.player
    const subtitleMode = this.subtitleManager.subtitleMode
    const subtitle3DMode = this.subtitleManager.subtitle3DMode
    oldPlayer.saveSubtitlePreferenceForCurrentVideo(this.subtitleManager.subtitleVisibility,
      this.subtitleManager.isAIAsrShown, subtitle3DMode)
    try {
      this.gestures.reset()
      await PiPWindowUtil.destroyPipController()
      await framePreviewSession.release()
      const nextPlayer = await this.playbackSession.switchEngine(oldPlayer, targetEngine, resumePlayback)
      if (this.isPageDisappearing || this.player !== oldPlayer) {
        await nextPlayer.release()
        return
      }

      this.xComponentController = new XComponentController()
      this.osdXController = new XComponentController()
      this.playerType = targetEngine
      this.player = nextPlayer
      this.gestures = new PlayerGestureController(nextPlayer)
      this.playbackSession.bindPlayer(nextPlayer)
      this.bindEngineSwitchHandler(nextPlayer)
      this.unregisterPlayerMonitors(oldPlayer)

      const nextSubtitleManager = new SubtitleManager(nextPlayer)
      nextSubtitleManager.subtitleMode = subtitleMode
      nextSubtitleManager.subtitle3DMode = subtitle3DMode
      nextPlayer.subtitleSelected = subtitleMode
      this.subtitleManager = nextSubtitleManager
      this.registerPlayerMonitors(nextPlayer)
      this.subtitlePreferenceRestored = true
      nextPlayer.onPlayerReady()
      if (this.containerWidth > 0 && this.containerHeight > 0) {
        nextPlayer.screenWidth = this.containerWidth
        nextPlayer.screenHeight = this.containerHeight
        nextPlayer.setRotation()
      }
      salmonLogger.addLog(TAG,
        `原地切换播放引擎完成: ${oldPlayer.isMpvPlayer() ? PlayerEngine.MPV_PLAYER : PlayerEngine.AV_PLAYER}` +
          ` -> ${targetEngine}, reason=${reason}`,
        false)
    } catch (error) {
      salmonLogger.addLog(TAG, `切换播放引擎失败: ${error}`, true)
      ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.switch_player_engine_failed').id))
      throw new Error(
        ToolsUtil.getStringResourceArgs($r('app.string.switch_player_engine_failed_detail').id, String(error)))
    }
  }

  private restoreSubtitlePreference() {
    if (this.subtitlePreferenceRestored) {
      return
    }
    const nowPlaying: VideoMetadata | undefined = this.player.nowPlaying
    if (nowPlaying && SubtitleUtil.hasSubtitlePreferenceMetadata(nowPlaying)) {
      if (nowPlaying.subtitle_3d_mode !== undefined &&
        [Subtitle3DMode.DISABLED, Subtitle3DMode.SIDE_BY_SIDE, Subtitle3DMode.TOP_AND_BOTTOM]
          .includes(nowPlaying.subtitle_3d_mode)) {
        this.subtitleManager.subtitle3DMode = nowPlaying.subtitle_3d_mode as Subtitle3DMode
      }
    }
    this.subtitlePreferenceRestored = true
    this.subtitleManager.syncMpvSubtitleVisibility()
  }

  private getWindowClass(): Promise<window.Window | undefined> {
    return this.player.getWindowClass() ?? this.windowClass
  }

  private exitVideo(timeOut: number): void {
    if (timeOut > 0) {
      this.playbackSession.sleepTimer.start(timeOut)
      return
    }
    if (this.isPageDisappearing || this.playbackSession.isClosing) { return }
    // 先同步封锁恢复与引擎回调，再等待持久化；到期与 EOF 只能退出一次。
    const session = this.playbackSession
    const routeIndex = this.pathStack.size() - 1
    const routeParam = this.pathStack.getParamByIndex(routeIndex) as PlayerParams | undefined
    this.beginPlayerExit()
    void this.finishPlayerExit(session, routeIndex, routeParam)
  }

  private async finishPlayerExit(session: PlaybackSessionController, routeIndex: number,
    routeParam: PlayerParams | undefined): Promise<void> {
    try {
      await this.exitProgressSave
      await Preferences.flushPending(PathUtils.appContext!)
    } catch (error) {
      salmonLogger.addLog(TAG, `退出前保存播放记录失败: ${error}`, true)
    }
    try {
      await session.dispose(() => this.player)
    } catch (error) {
      salmonLogger.addLog(TAG, `退出前停止播放器失败: ${error}`, true)
    }
    if (this.playbackSession === session && this.pathStack.size() - 1 === routeIndex &&
      this.pathStack.getAllPathName()[routeIndex] === NavigationAddress.VIDEO_PLAYER &&
      this.pathStack.getParamByIndex(routeIndex) === routeParam) {
      this.pathStack.pop()
    }
  }

  private saveAbPoint(point: 'A' | 'B' | 'clear'): void {
    try {
      if (!this.playbackSession.saveAbPoint(PathUtils.appContext!, point)) {
        ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.ab_loop_invalid_range').id))
        return
      }
      const loop = this.playbackSession.abLoop
      ToolsUtil.showToast(point === 'clear' ?
        ToolsUtil.getStringResource($r('app.string.cancel_ab_time_success').id) :
        ToolsUtil.getStringResourceArgs(point === 'A' ? $r('app.string.set_point_a_time').id :
          $r('app.string.set_point_b_time').id, TimeUtil.convertMSToHHMMSS(point === 'A' ? loop.pointA : loop.pointB)))
    } catch (error) {
      salmonLogger.addLog(TAG, `保存 AB 点位失败: ${error}`, true)
      ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.ab_loop_save_failed').id))
    }
  }

  private readPlayerParams(): PlayerParams | undefined {
    const paramsList = this.pathStack.getParamByName(NavigationAddress.VIDEO_PLAYER) as PlayerParams[]
    return paramsList.length > 0 ? paramsList[paramsList.length - 1] : undefined
  }

  private resumePlaybackAfterSubtitleOffsetIfNeeded(): void {
    if (this.isPageDisappearing || this.playbackSession.isClosing ||
      this.playbackSession.sleepTimer.checkDeadline()) {
      this.subtitleOffsetShouldResumePlayback = false
      return
    }
    if (!this.subtitleOffsetShouldResumePlayback) {
      return
    }
    this.subtitleOffsetShouldResumePlayback = false
    if (!this.player.playing) {
      this.player.play()
    }
  }

  private finishSubtitleOffsetSession(): void {
    this.isAdjustingSubtitleOffset = false
    this.isAdjustingMpvSubtitleOffset = false
    this.resumePlaybackAfterSubtitleOffsetIfNeeded()
  }

  private cancelSubtitleOffsetSession(): void {
    if (!this.isAdjustingSubtitleOffset) {
      return
    }
    this.player.subtitleController.setSubtitleOffset(this.subtitleOffsetPreviewBase)
    this.finishSubtitleOffsetSession()
  }
  private currentRangeMediaKey(): string {
    const media = this.player.nowPlaying
    return media ? media.date + '|' + media.uri : ''
  }

  private openRangeEditor(mode: PlaybackRangeMode): void {
    if (this.isPageDisappearing || this.playbackSession.isClosing) { return }
    this.playbackSession.policy.refresh()
    if (this.playbackSession.policy.sleepTimer.checkDeadline() || this.isPageDisappearing || this.playbackSession.isClosing) { return }
    this.rangeMode = mode
    this.rangeMediaKey = this.currentRangeMediaKey()
    this.rangeDuration = this.playbackSession.policy.abLoop.durationMs
    this.rangeEditorDialog.open()
  }

  private saveEditedRange(start: number, end: number): boolean {
    if (this.isPageDisappearing || this.playbackSession.isClosing || this.rangeMediaKey !== this.currentRangeMediaKey()) { return false }
    try {
      return this.rangeMode === 'ab' ? this.playbackSession.policy.saveAbRange(PathUtils.appContext!, start, end) :
        this.playbackSession.policy.saveOpeningEnding(PathUtils.appContext!, start, end)
    } catch (error) {
      salmonLogger.addLog('PlaybackRange', `保存区间失败: ${error}`, true)
      return false
    }
  }

  private saveOpeningEndingPoint(point: 'start' | 'end' | 'clear'): void {
    try {
      if (!this.playbackSession.policy.saveOpeningEndingPoint(PathUtils.appContext!, point)) {
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
