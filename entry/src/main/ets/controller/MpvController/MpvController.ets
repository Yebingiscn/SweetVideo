import { MpvPlaybackEffects } from './MpvPlaybackEffects'
import { MpvSubtitleController } from './MpvSubtitleController'
import { NetworkPlayback } from '../../utils/NetworkPlayback'
import { AudioPauseGuard } from '../../utils/AudioPauseGuard'
import { media } from '@kit.MediaKit'
import { PlayerControllerInterface, PlayerEngineSwitchHandler } from '../PlayerControllerFactory'
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import { Subtitle3DMode, SubtitleMode } from '../../common/enum/SubtitleMode'
import { MpvAudioChannelMode, MpvAudioTrack, MpvChapter, MpvDecodingMethod, MpvSubtitleTrack } from './MpvTypes'
import { MpvPlayerState } from './MpvPlayerState'
import { avSession, avSession as avSessionManager } from '@kit.AVSessionKit'
import { audio } from '@kit.AudioKit'
import { WindowUtil } from '../../utils/WindowUtil'
import { SweetRepeatMode } from '../../common/enum/SweetRepeatMode'
import { BaseListener } from '../../utils/BaseEventUtil'
import {
  command as mpvCommand,
  getAudioType as mpvGetAudioType,
  getChapterList as mpvGetChapterList,
  getDuration as mpvGetDuration,
  getVideoHdrType as mpvGetVideoHdrType,
  getVideoHeight as mpvGetVideoHeight,
  getVideoWidth as mpvGetVideoWidth,
  pause as mpvPause,
  play as mpvPlay,
  registerBufferingStateCallback as mpvRegisterBufferingStateCallback,
  registerMediaLoadCallback as mpvRegisterMediaLoadCallback,
  registerNetworkStateCallback as mpvRegisterNetworkStateCallback,
  registerPauseStateCallback as mpvRegisterPauseStateCallback,
  registerPlaybackCompleteCallback as mpvRegisterPlaybackCompleteCallback,
  registerSurfaceModeErrorCallback as mpvRegisterSurfaceModeErrorCallback,
  registerTimeUpdateCallback as mpvRegisterTimeUpdateCallback,
  registerVideoSizeChangedCallback as mpvRegisterVideoSizeChangedCallback,
  seek as mpvSeek,
  setBlurayDevice as mpvSetBlurayDevice,
  setDecodeType as mpvSetDecodeType,
  setDvdDevice as mpvSetDvdDevice,
  setGpuApi as mpvSetGpuApi,
  setHwdecMode as mpvSetHwdecMode,
  setKeepAspect as mpvSetKeepAspect,
  setOsdLevel as mpvSetOsdLevel,
  setOsdSurface as mpvSetOsdSurface,
  setSdrToHdr as mpvSetSdrToHdr,
  setSpeed as mpvSetSpeed,
  setSuperResolution as mpvSetSuperResolution,
  unregisterBufferingStateCallback as mpvUnregisterBufferingStateCallback,
  unregisterMediaLoadCallback as mpvUnregisterMediaLoadCallback,
  unregisterNetworkStateCallback as mpvUnregisterNetworkStateCallback,
  unregisterPauseStateCallback as mpvUnregisterPauseStateCallback,
  unregisterPlaybackCompleteCallback as mpvUnregisterPlaybackCompleteCallback,
  unregisterSurfaceModeErrorCallback as mpvUnregisterSurfaceModeErrorCallback,
  unregisterTimeUpdateCallback as mpvUnregisterTimeUpdateCallback,
  unregisterVideoSizeChangedCallback as mpvUnregisterVideoSizeChangedCallback
} from 'libmpvnative.so'
import { display, window } from '@kit.ArkUI'
import { hdrCapability } from '@kit.ArkGraphics2D'
import { salmonLogger } from 'salmonlogger'
import { handleScreenDoubleClick } from '../../common/GestureUtil'
import { VideoStartTimeMode } from '../../common/enum/VideoStartTimeMode'
import Preferences from '../../database/Preferences'
import AVSessionUtil from '../../utils/AVSessionUtil'
import IsoFileUtil, { IsoFileType } from '../../utils/IsoFileUtil'
import { Setting } from '../../utils/ObservedUtil'
import { PathUtils } from '../../utils/PathUtils'
import PermissionUtil from '../../utils/PermissionUtil'
import PiPWindowUtil from '../../utils/PiPWindowUtil'
import PrivacySpaceUtil from '../../utils/PrivacySpaceUtil'
import SubtitleUtil from '../../utils/SubtitleUtil'
import { ThrottleUtil } from '../../utils/DebounceUtil'
import ToolsUtil from '../../utils/ToolsUtil'
import VideoInfoUtil from '../../utils/VideoInfoUtil'
import VideoOperateUtil from '../../utils/VideoOperateUtil'
import { fileUri } from '@kit.CoreFileKit'
import { MpvPlayerEngineAdapter } from '../engine/MpvPlayerEngineAdapter'
import { AudioEffectConfig } from '../../interfaces/AudioEffectInterface'
import { MpvAudioController } from './MpvAudioController'
import { MpvDecodingRecovery } from './MpvDecodingRecovery'
import MediaLibraryService from '../../utils/MediaLibraryService'
import { framePreviewSession } from '../../utils/FFmpegThumbnailUtil'

const TAG = 'MpvController'

interface MpvCommandResult {
  success: boolean
  code: number
  error?: string
}

@ObservedV2
export class MpvController implements PlayerControllerInterface {
  readonly subtitleController: MpvSubtitleController = new MpvSubtitleController(this,
    (): number | null => this.mpvHandle,
    (): number => this.postLoadTaskGeneration,
    (): boolean => this.engineAdapter.isMediaLoaded())
  private smbPlayback: NetworkPlayback = new NetworkPlayback()
  windowClass = WindowUtil.getWindow()
  surfaceId: string | null = null
  osdSurfaceId: string | null = null
  @Trace playTime: number = 0
  @Trace playbackPositionMs: number = 0
  @Trace playing: boolean = false
  @Trace networkPlaybackActive: boolean = false
  @Trace networkSpeedText: string = '0 KB/s'
  @Trace networkBufferPercent: number = 0
  @Trace networkCacheDuration: number = 0
  @Trace networkBuffering: boolean = false
  @Trace nowPlaying: VideoMetadata | undefined = undefined
  initialPlayTime: number | undefined = undefined
  initialPlaying: boolean | undefined = undefined
  @Trace videoMetaDataList: VideoMetadata[] = []
  @Trace speed: number = 1.0
  @Trace volume: number = 0
  @Trace volumeActually: number = 0
  @Trace audioTrack: MpvAudioTrack[] = []
  @Trace externalAudioImporting: boolean = false
  @Trace externalAudioOffsetMs: number = 0
  @Trace subtitleTrack: MpvSubtitleTrack[] = []
  @Trace subtitleTrackSelected: number = -1
  @Trace secondarySubtitleTrackSelected: number = -1
  @Trace screenBrightness: number = 0
  @Trace onSwipingVoice: boolean = false
  volumeGestureActive: boolean = false
  private swipingVoiceTimer: number = 0
  @Trace subtitleSelected: SubtitleMode = SubtitleMode.NONE
  @Trace screenWidth: number = 0
  @Trace screenHeight: number = 0
  @Trace playAreaHeight: number = 0
  @Trace playAreaWidth: number = 0
  @Trace angle: number = 0
  @Trace repeatMode: SweetRepeatMode = SweetRepeatMode.LIST
  @Trace selectedText: string | undefined = '原始比例'
  @Trace onSwiping: boolean = false
  @Trace onSwipingBrightness: boolean = false
  @Trace isSliderPlayTimeChange: boolean = false
  @Trace audioTrackSelected: number = 0
  @Trace volumeLoudnessGain: number = 0
  @Trace subtitlePosition: number = Setting.subtitlePosition
  @Trace superResolutionState: boolean = Setting.superResolutionState
  @Trace subtitleSize: number = Number(Setting.subtitleSize)
  @Trace audioChannelMode: MpvAudioChannelMode = MpvAudioChannelMode.STEREO
  audioEffectConfig: AudioEffectConfig = new AudioEffectConfig()
  @Trace chapterList: MpvChapter[] = []

  @Trace longPress: boolean = false
  @Trace speedLocked: boolean = false
  @Trace isLock: boolean = false
  @Trace abCircleStatus: boolean = false
  @Trace osdVisibility: boolean = false
  @Trace debugInfoVisible: boolean = false
  @Trace isZoomed: boolean = false
  @Trace isGesturing: boolean = false
  @Trace scaleFactor: number = 1
  @Trace translateX: number = 0
  @Trace translateY: number = 0
  @Trace subtitle: string = ''
  @Trace showControl: boolean = false
  skipHistory: boolean = false
  @Trace pixelMap: PixelMap | null = null
  @Trace audioCoverUri: string = ''
  avSession: avSessionManager.AVSession | undefined = undefined
  audioVolumeManager: audio.AudioVolumeManager | null = null
  @Trace playerState: MpvPlayerState = MpvPlayerState.IDLE
  private osdSurfaceWidth: number = 0
  private osdSurfaceHeight: number = 0
  private engineAdapter: MpvPlayerEngineAdapter = new MpvPlayerEngineAdapter()
  private decodingRecovery: MpvDecodingRecovery = new MpvDecodingRecovery(this, this.engineAdapter,
    () => ({ activeAutoDeinterlace: this.activeAutoDeinterlace, activeHwdecMode: this.activeHwdecMode,
      initialStartHandledByLoad: this.initialStartHandledByLoad, resumeAfterBuffering: this.resumeAfterBuffering }),
    () => this.playerState, (state: MpvPlayerState) => this.transitionTo(state),
    (mode: 'buffer_hw' | 'buffer_sw', message: string, time?: number, playing?: boolean, media?: VideoMetadata) => {
      this.switchDecodingMode(mode, message, time, playing, media)
    })
  readonly audioController: MpvAudioController = new MpvAudioController(this, this.engineAdapter,
    () => this.postLoadTaskGeneration, () => this.playRequestGeneration)
  private isSkippingEnding: boolean = false
  private lastAppStorageUpdateTime: number = 0
  private audioSessionManager: audio.AudioSessionManager | null = null
  private audioPauseGuard: AudioPauseGuard = new AudioPauseGuard()
  private outputDeviceListenerRegistered: boolean = false
  private userListener: BaseListener<number> | null = null
  private playbackCallbackRegistered: boolean = false
  private timeUpdateCallbackRegistered: boolean = false
  private videoSizeCallbackRegistered: boolean = false
  private surfaceModeErrorCallbackRegistered: boolean = false
  private bufferingStateCallbackRegistered: boolean = false
  private mediaLoadCallbackRegistered: boolean = false
  private networkStateCallbackRegistered: boolean = false
  private pauseStateCallbackRegistered: boolean = false
  private audioInterruptRegistered: boolean = false
  private resumeAfterBuffering: boolean = false
  private stateChangeResolvers: Map<string, ((value: void) => void)> = new Map()
  private playbackEffects: MpvPlaybackEffects = new MpvPlaybackEffects()
  private smartRotationTimer: number = 0
  private postLoadMetadataTimer: number = 0
  private postLoadTaskGeneration: number = 0
  private shaderTimer: number = 0
  private playRequestGeneration: number = 0
  private pendingCompletionRequestId: number = 0
  private currentPathStack: NavPathStack | null = null
  private activeHwdecMode: MpvDecodingMethod = MpvDecodingMethod.HARDWARE_SURFACE
  private activeAutoDeinterlace: boolean = false
  @Trace usbExclusiveActive: boolean = false
  private postLoadTasksExecuted: boolean = false
  private initialStartHandledByLoad: boolean = false
  private initialSmartRotationRequested: boolean = false
  private smartRotationAllowed: boolean = true
  private engineSwitchHandler: PlayerEngineSwitchHandler | undefined = undefined

  private get mpvHandle(): number | null {
    return this.engineAdapter.handle
  }

  waitForState(targetState: MpvPlayerState, timeoutMs: number = 10000): Promise<void> {
    if (this.playerState === targetState) {
      return Promise.resolve()
    }
    return new Promise<void>((resolve, reject) => {
      const key = MpvPlayerState[targetState]
      this.stateChangeResolvers.set(key, resolve)
      setTimeout(() => {
        if (this.stateChangeResolvers.has(key)) {
          this.stateChangeResolvers.delete(key)
          reject(new Error(`等待状态${key}超时`))
        }
      }, timeoutMs)
    })
  }

  isInState(state: MpvPlayerState): boolean {
    return this.playerState === state
  }

  async playChooseVideo(item: VideoMetadata, pathStack: NavPathStack,
    _windowClass?: Promise<window.Window | undefined>, _xComponentController?: XComponentController) {
    framePreviewSession.cancelRequests(this)
    salmonLogger.addLog(TAG, "开始播放选择的视频", false)
    if (!this.skipHistory) {
      MediaLibraryService.saveVideoTime(this.playTime, this.nowPlaying!, PathUtils.appContext!)
    }

    // 普通切集复用当前 MPV 实例，并由 loadfile replace 完成媒体切换。
    // 完整 reset 会停止事件线程、销毁并重建 MPV，导致 Surface 在新首帧前长时间黑屏。
    // 解码模式确实发生变化时，init() 仍会按原逻辑重建实例。
    this.cancelSmartRotationTimer()
    const requestGeneration = ++this.playRequestGeneration
    this.audioPauseGuard.cancel()
    this.audioController.usbSession.cancelPendingOpen()
    this.engineAdapter.invalidateLoad()
    this.pendingCompletionRequestId = 0
    this.transitionTo(MpvPlayerState.LOADING)
    this.playTime = 0
    this.pixelMap = null
    this.audioCoverUri = ''
    this.isSkippingEnding = false
    this.audioChannelMode = MpvAudioChannelMode.STEREO
    // 更新播放列表数据，确保使用最新的数据
    if (!PrivacySpaceUtil.getPrivacyMode()) {
      const findResult = Preferences.findVideoByDate(PathUtils.appContext!, item.date)
      const latestItem = findResult[0]
      const videoList = findResult[1]
      if (latestItem && videoList.length > 0) {
        this.videoMetaDataList = videoList
        this.nowPlaying = latestItem
      } else {
        this.nowPlaying = item as VideoMetadata
      }
      salmonLogger.addLog(TAG, "更新播放列表数据完成", false)
    } else {
      this.nowPlaying = item as VideoMetadata
    }
    salmonLogger.addLog(TAG, "设置当前播放视频完成", false)

    try {
      await PermissionUtil.activatePermission(item.uri)
      if (requestGeneration !== this.playRequestGeneration) {
        return
      }
      await this.prepareInitialSmartRotation()
      if (requestGeneration !== this.playRequestGeneration) {
        return
      }
      await this.init(item.uri, pathStack)
      if (requestGeneration !== this.playRequestGeneration || this.isInState(MpvPlayerState.ERROR)) {
        return
      }
      await this.initAVSession()
      salmonLogger.addLog(TAG, "播放选择视频流程完成", false)
    } catch (error) {
      if (requestGeneration === this.playRequestGeneration) {
        this.handleLoadFailure(`播放准备失败: ${error}`)
      }
    }
  }

  async playNextVideoProcess(pathStack: NavPathStack, _windowClass?: Promise<window.Window | undefined>,
    _xComponentController?: XComponentController, overrideRepeatMode?: SweetRepeatMode) {
    salmonLogger.addLog(pathStack?.getAllPathName()[0] ?? TAG, "开始播放下一个视频流程", false)
    const effectiveRepeatMode = overrideRepeatMode ?? this.repeatMode
    const nextItem = this.playAdjacentVideo(effectiveRepeatMode, 'next')
    salmonLogger.addLog(pathStack?.getAllPathName()[0] ?? TAG, "获取下一个视频项完成", false)
    if (nextItem) {
      salmonLogger.addLog(pathStack?.getAllPathName()[0] ?? TAG, "存在下一个视频，开始播放", false)
      await this.playChooseVideo(nextItem, pathStack)
    } else {
      salmonLogger.addLog(pathStack?.getAllPathName()[0] ?? TAG, "无下一个视频，播放结束", false)
      ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.play_finished_auto_exit').id))
      pathStack.pop()
    }
    salmonLogger.addLog(pathStack?.getAllPathName()[0] ?? TAG, "播放下一个视频前置流程完成", false)
  }

  async playPreviousVideoProcess(pathStack: NavPathStack, _windowClass?: Promise<window.Window | undefined>,
    _xComponentController?: XComponentController, overrideRepeatMode?: SweetRepeatMode): Promise<void> {
    salmonLogger.addLog(pathStack?.getAllPathName()[0] ?? TAG, "开始播放上一个视频前置流程", false)
    const effectiveRepeatMode = overrideRepeatMode ?? this.repeatMode
    const previousItem = this.playAdjacentVideo(effectiveRepeatMode, 'previous')
    if (previousItem) {
      await this.playChooseVideo(previousItem, pathStack)
    } else {
      ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.no_previous_item').id))
    }
    salmonLogger.addLog(pathStack?.getAllPathName()[0] ?? TAG, "播放上一个视频前置流程完成", false)
  }

  playAdjacentVideo(repeatMode: SweetRepeatMode,
    direction: 'previous' | 'next'): VideoMetadata | undefined {
    return VideoOperateUtil.computeAdjacentVideo(this.videoMetaDataList, this.nowPlaying, repeatMode, direction)
  }

  async create(): Promise<void> {
    // ArkTS 控制器是 OSD 调试状态的唯一数据源。原生层的 OSD 等级是
    // 进程级全局状态，因此每次进入 MPV 都要显式覆盖，避免继承旧控制器的调试等级。
    this.applyDebugInfoVisibility()
    if (this.mpvHandle) {
      salmonLogger.addLog(TAG, '[MpvPlayer] MPV already created, skipping', true)
      return
    }

    try {
      this.applyDecodeType()
      this.engineAdapter.create()
      if (!this.mpvHandle) {
        salmonLogger.addLog(TAG, '[MpvPlayer] Failed to create mpv instance - handle is null/undefined', true)
        this.transitionTo(MpvPlayerState.ERROR)
      } else {
        salmonLogger.addLog(TAG, '[MpvPlayer] MPV instance created:' + this.mpvHandle, false)
        this.activeHwdecMode = this.computeDecodeType()
        this.transitionTo(MpvPlayerState.IDLE)
      }
    } catch {
      salmonLogger.addLog(TAG, '[MpvPlayer] Exception during create', true)
      ToolsUtil.showToast("MPV 创建失败")
      this.transitionTo(MpvPlayerState.ERROR)
    }
  }


  async init(url?: string, pathStack?: NavPathStack): Promise<void> {
    const requestGeneration = this.playRequestGeneration
    this.cancelSmartRotationTimer()
    this.engineAdapter.invalidateLoad()
    this.pendingCompletionRequestId = 0
    this.applyDebugInfoVisibility()
    this.decodingRecovery.cancelDecodingModeVerification()
    const requiredMode = this.computeDecodeType()
    this.activeAutoDeinterlace = Setting.mpvAutoDeinterlace
    this.audioController.updatePreferences(() => this.cleanupMpvInstance())
    if (this.mpvHandle && !this.engineAdapter.isAlive()) {
      salmonLogger.addLog(TAG, '[MpvController] 核心已关闭，重建后再加载；正常 EOF 继续复用实例', true)
      this.cleanupMpvInstance()
    }
    if (this.mpvHandle && requiredMode !== this.activeHwdecMode) {
      salmonLogger.addLog(TAG,
        `[MpvController] Decode mode mismatch: active=${this.activeHwdecMode}, required=${requiredMode}, recreating instance`,
        true)
      this.transitionTo(MpvPlayerState.SWITCHING_MODE)
      this.cleanupMpvInstance()
      this.cancelDecodingModeTimers()
    }
    this.applyDecodeType()
    if (!this.mpvHandle) {
      this.engineAdapter.create()
      if (!this.mpvHandle) {
        salmonLogger.addLog(TAG, '[MpvPlayer] Failed to create mpv instance during init', true)
        this.transitionTo(MpvPlayerState.ERROR)
        return
      }
      salmonLogger.addLog(TAG, '[MpvPlayer] MPV instance created:' + this.mpvHandle, false)
    }
    this.activeHwdecMode = requiredMode
    this.transitionTo(MpvPlayerState.LOADING)
    await this.smbPlayback.resolve(url!)
    if (requestGeneration !== this.playRequestGeneration) return
    const playUrl = this.preparePlayUrl(url!)
    this.configureNetworkStateSubscription(url!)
    const initialStartPositionMs = this.consumeInitialStartPositionMs()
    this.initialStartHandledByLoad = initialStartPositionMs !== undefined
    const startPositionSeconds = initialStartPositionMs !== undefined && initialStartPositionMs > 0 ?
      initialStartPositionMs / 1000 : undefined
    const initialSubtitleTrackId = this.getInitialSubtitleTrackId()
    // Surface decode failures can happen immediately after load. Register first so
    // native load/fallback notifications cannot be lost during decoder startup.
    this.setPlayerCallback(pathStack!)
    this.registerPlaybackCompleteListener(pathStack!)
    await this.getData()
    if (requestGeneration !== this.playRequestGeneration) {
      return
    }
    try {
      try {
        await this.audioController.prepareUsbOutput(requestGeneration)
      } catch (error) {
        if (requestGeneration !== this.playRequestGeneration) return
        salmonLogger.addLog(TAG, `[MpvController] USB 不可用，改用普通音频输出: ${error}`, true)
        this.restoreOrdinaryAudioOutput()
        this.configureNetworkStateSubscription(url!)
        this.setPlayerCallback(pathStack!)
        this.registerPlaybackCompleteListener(pathStack!)
        await this.getData()
      }
      if (requestGeneration !== this.playRequestGeneration) return
      this.applyAutoDeinterlace()
      if (!this.audioController.applyAudioPassthrough(this.speed, this.audioEffectConfig.effect)) {
        throw new Error(ToolsUtil.getStringResource($r('app.string.set_audio_output_mode_failed').id))
      }
      this.audioController.applyAudioCoverMode()
      this.engineAdapter.load(playUrl, startPositionSeconds, initialSubtitleTrackId,
        this.nowPlaying?.network_user_agent, this.smbPlayback.headers(this.nowPlaying?.network_http_headers))
    } catch (error) {
      if (requestGeneration !== this.playRequestGeneration) return
      this.handleLoadFailure(`loadfile 失败: ${error}`)
      return
    }
    this.subtitleController.applySubtitleStyle()

    if (!ToolsUtil.isNetworkUrl(url!)) {
      framePreviewSession.prepare(url!)
    }

    // Metadata and shaders start only after this file's FILE_LOADED event.
  }

  private scheduleShader(generation: number): void {
    const shaderMode = Setting.mpvShaderMode
    if (shaderMode > 0) {
      this.shaderTimer = setTimeout(() => {
        this.shaderTimer = 0
        if (generation !== this.postLoadTaskGeneration || !this.engineAdapter.isMediaLoaded() ||
          !this.engineAdapter.isAlive()) {
          return
        }
        salmonLogger.addLog(TAG, `[MpvController] applying shader mode=${shaderMode}`, false)
        this.playbackEffects.applyShaderMode(shaderMode, this.mpvHandle)
      }, 3000) as number
    }
  }

  setOsdSurface(surfaceId: string, surfaceWidth: number, surfaceHeight: number): void {
    mpvSetOsdSurface(surfaceId, surfaceWidth, surfaceHeight)
  }

  // 尺寸变化只重建 EGL window surface；字幕上传始终限制在 libass 小位图范围内。
  syncOsdSurfaceSize(): void {
    if (!this.osdSurfaceId || this.osdSurfaceWidth <= 0 || this.osdSurfaceHeight <= 0) {
      return
    }
    this.setOsdSurface(this.osdSurfaceId, this.osdSurfaceWidth, this.osdSurfaceHeight)
  }

  setPlayerCallback(pathStack: NavPathStack, _xComponentController?: XComponentController,
    _windowClass?: Promise<window.Window | undefined>) {
    this.currentPathStack = pathStack
    this.userListener = new BaseListener<number>()
    this.userListener.on('timeUpdate', (duration: number) => {
      const now = Date.now()
      if (now - this.lastAppStorageUpdateTime >= 200) {
        this.lastAppStorageUpdateTime = now
        AppStorage.setOrCreate('nowPlayingData',
          [this.playTime, this.nowPlaying!, this.skipHistory])
      }
      if (this.showControl) {
        if (VideoOperateUtil.autoHideTimerId === -1) {
          VideoOperateUtil.scheduleControlAutoHide(() => {

            this.showControl = false
          })
        }
      }
      // 片尾跳过逻辑保留
      const totalTime = this.nowPlaying?.time ?? 0
      const startTime = this.nowPlaying?.start_time
      const endTime = VideoInfoUtil.getEndingPosition(this.nowPlaying)
      const skipIntroMs = Number(Setting.skipIntroTime) * 1000
      const skipOutroSeconds = Number(Setting.skipOutroTime)
      const skipOutroMs = skipOutroSeconds * 1000
      // 单视频片尾跳过：片尾<=总时长 且 片尾>片头（片头+片尾<=总时长）
      if (endTime != null && endTime > 0 && (totalTime <= 0 || endTime <= totalTime)
        && (startTime == null || startTime <= 0 || endTime > startTime)
        && duration >= endTime && this.repeatMode !== SweetRepeatMode.SINGLE
        && !this.isSkippingEnding) {
        this.isSkippingEnding = true
        salmonLogger.addLog(TAG,
          `检测到视频片尾，准备播放下一个视频，满足条件为: endTime: ${endTime}, repeatMode: ${this.repeatMode}, duration: ${duration}`,
          false)
        this.playNextVideoProcess(pathStack).catch((error: Error) => {
          salmonLogger.addLog(TAG, `play next video failed: ${error.message}`, true)
        })
        this.userListener?.clear()
        this.userListener = null
        this.setPlayerCallback(pathStack)
        ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.skipped_video_ending').id))
      }
      // 全局片尾跳过：片尾<=总时长 且 片头+片尾<=总时长
      if (skipOutroSeconds > 0 && (endTime == null || endTime === 0)) {
        if (totalTime > 0 && skipOutroMs <= totalTime && skipIntroMs + skipOutroMs <= totalTime
          && duration >= totalTime - skipOutroMs && this.repeatMode !== SweetRepeatMode.SINGLE
          && !this.isSkippingEnding) {
          this.isSkippingEnding = true
          salmonLogger.addLog(TAG,
            `检测到视频片尾（全局），准备播放下一个视频，满足条件为: skipOutroTime: ${skipOutroSeconds}s, totalTime: ${totalTime}, duration: ${duration}`,
            false)
          this.playNextVideoProcess(pathStack).catch((error: Error) => {
            salmonLogger.addLog(TAG, `play next video failed: ${error.message}`, true)
          })
          this.userListener?.clear()
          this.userListener = null
          this.setPlayerCallback(pathStack)
          ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.skipped_outro').id))
        }
      }
      if (this.abCircleStatus && this.playing) {
        if (this.nowPlaying?.pointA !== undefined && this.nowPlaying?.pointB !== undefined) {
          const pointA = this.nowPlaying.pointA
          const pointB = this.nowPlaying.pointB
          const playTime = this.playTime
          if (playTime < pointA || playTime > pointB) {
            this.seekTime(pointA)
          }
        }
      }
    })
  }

  // OSD 始终按 XComponent 的实际 Surface 像素尺寸渲染，避免 4K/8K

  async getData(): Promise<void> {
    this.registerMediaLoadCallback()
    this.registerTimeUpdateCallback()
    this.registerVideoSizeChangedCallback()
    this.registerSurfaceModeErrorCallback()
    this.registerBufferingStateCallback()
    this.registerPauseStateCallback()
  }

  backForward(): void {
    if (!this.mpvHandle) {
      return
    }
    this.seekTime(this.playTime - Number(Setting.fastForwardSeconds) * 1000)
  }

  fastForward(): void {
    if (!this.mpvHandle) {
      return
    }
    this.seekTime(this.playTime + Number(Setting.fastForwardSeconds) * 1000)
  }

  prepare(): void {
    this.smartRotationAllowed = true
    this.create().catch(() => {
      salmonLogger.addLog(TAG, 'prepare create failed', true)
    })
  }

  play(): void {
    this.audioPauseGuard.cancel()
    if (!this.mpvHandle || !this.engineAdapter.isAlive()) {
      return
    }
    if (!this.engineAdapter.isMediaLoaded()) {
      if (this.isInState(MpvPlayerState.LOADING)) {
        this.initialPlaying = true
      }
      return
    }
    PiPWindowUtil.enableAutoStart()
    this.transitionTo(MpvPlayerState.PLAYING)
    mpvPlay(this.mpvHandle)
    AVSessionUtil.updatePlaybackSessionState(this.playing, this.playTime, this.repeatMode, this.speed)
    this.reactivateAudioSessionIfNeeded()
  }

  pause(): void {
    this.audioPauseGuard.cancel()
    this.pausePlayback()
  }

  private pausePlayback(): void {
    this.resumeAfterBuffering = false
    if (!this.mpvHandle || !this.engineAdapter.isAlive()) {
      return
    }
    if (!this.engineAdapter.isMediaLoaded()) {
      if (this.isInState(MpvPlayerState.LOADING)) {
        this.initialPlaying = false
      }
      return
    }
    PiPWindowUtil.disableAutoStart()
    this.transitionTo(MpvPlayerState.PAUSED)
    mpvPause(this.mpvHandle)
    MediaLibraryService.saveVideoPlayTimeIfNeed(this.playTime, this.nowPlaying,
      this.skipHistory, PathUtils.appContext!)
    AVSessionUtil.updatePlaybackSessionState(this.playing, this.playTime, this.repeatMode, this.speed)
  }

  async reset(): Promise<void> {
    this.audioPauseGuard.cancel()
    this.engineAdapter.reset()
    await this.getData()
  }

  async release(): Promise<void> {
    framePreviewSession.cancelRequests(this)
    this.audioPauseGuard.cancel()
    this.smbPlayback.close()
    this.clearSessionNavigationListeners()
    this.currentPathStack = null
    this.playRequestGeneration++
    this.engineAdapter.invalidateLoad()
    this.pendingCompletionRequestId = 0
    this.transitionTo(MpvPlayerState.RELEASING)
    this.cancelDecodingModeTimers()
    this.cancelSubscribe()
    if (!this.engineAdapter.isCreated()) {
      await this.engineAdapter.release()
      this.audioController.releaseOutput()
      this.transitionTo(MpvPlayerState.IDLE)
      return
    }
    await this.engineAdapter.release(() => {
      this.unregisterNativeCallbacks()
      this.userListener?.off('timeUpdate')
    })
    this.audioController.releaseOutput()
    this.transitionTo(MpvPlayerState.IDLE)
  }

  cancelSubscribe(): void {
    this.audioPauseGuard.cancel()
    AppStorage.delete('nowPlayingData')
    try {
      this.audioVolumeManager?.off('streamVolumeChange')
      this.audioVolumeManager = null
    } catch (error) {
      salmonLogger.addLog(TAG, `取消音量监听错误 ${error}`, true)
    }
    try {
      this.audioSessionManager?.off('audioSessionDeactivated')
      this.audioSessionManager?.off('audioSessionStateChanged')
      if (this.outputDeviceListenerRegistered) {
        this.audioSessionManager?.off('currentOutputDeviceChanged')
        this.outputDeviceListenerRegistered = false
      }
      this.audioSessionManager = null
      this.audioInterruptRegistered = false
    } catch (error) {
      salmonLogger.addLog(TAG, `取消音频中断监听错误 ${error}`, true)
    }
  }

  seekTime(seekTime: number): void {
    if (!this.mpvHandle) {
      return
    }
    const target = Math.max(0, seekTime)
    mpvSeek(this.mpvHandle, target / 1000, true)
    AVSessionUtil.updatePlaybackSessionState(this.playing, target, this.repeatMode, this.speed)
  }

  getPlayAreaWidth(): number {
    return mpvGetVideoWidth(this.mpvHandle)
  }

  getPlayAreaHeight(): number {
    return mpvGetVideoHeight(this.mpvHandle)
  }

  togglePlayback(): void {
    this.playing ? this.pause() : this.play()
  }

  updatePlaybackSpeed(speed: number) {
    if (this.usbExclusiveActive && speed !== 1) {
      this.speed = 1
      ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.usb_no_speed_change').id)); return
    }
    if (!this.audioController.applyAudioPassthrough(speed === 1 ? this.speed : speed, this.audioEffectConfig.effect)) {
      ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.audio_output_switch_kept_speed').id))
      return
    }
    const result = mpvSetSpeed(this.mpvHandle, speed)
    if (!result) {
      this.audioController.applyAudioPassthrough(this.speed, this.audioEffectConfig.effect)
      ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.playback_speed_update_failed').id))
      return
    }
    this.speed = result.speed
    this.audioController.applyAudioPassthrough(this.speed, this.audioEffectConfig.effect)
    if (!result.success) ToolsUtil.showToast(result.error || '系统未接受该播放速度，已保持原速度')
    AVSessionUtil.updatePlaybackSessionState(this.playing, this.playTime, this.repeatMode, this.speed)
  }

  getDuration(): number {
    const totalTime = mpvGetDuration(this.mpvHandle) as number
    if (totalTime === 0) {
      return this.nowPlaying!.time
    }
    if (this.nowPlaying?.time === 0 || this.nowPlaying?.time !== totalTime) {
      this.nowPlaying!.time = totalTime
      MediaLibraryService.saveData(PathUtils.appContext!, this.nowPlaying!, { totalTime: this.nowPlaying!.time })
    }
    return totalTime
  }

  videoStartPlayTime(seekMode: number): void {
    switch (seekMode) {
      case VideoStartTimeMode.SEEK_TO_LAST_PLAY_TIME:
        this.seekTime(this.nowPlaying?.last_play || 0)
        break
      case VideoStartTimeMode.SEEK_TO_START_TIME:
        this.seekTime(this.nowPlaying?.start_time || 0)
        break
      case VideoStartTimeMode.SEEK_TO_INTRO_TIME:
        this.seekTime(this.playTime + Number(Setting.skipIntroTime) * 1000)
        break
      case VideoStartTimeMode.SEEK_TO_BEGINNING:
        this.seekTime(0)
        break
      default:
        return
    }
  }

  getChapterListFromMpv() {
    if (!this.mpvHandle) {
      this.chapterList = []
      return
    }
    const chapters = mpvGetChapterList(this.mpvHandle) as MpvChapter[]
    this.chapterList = chapters || []
  }

  seekToChapter(chapterIndex: number): void {
    if (!this.mpvHandle || chapterIndex < 0 || chapterIndex >= this.chapterList.length) {
      return
    }
    const timeSeconds = this.chapterList[chapterIndex].time
    this.seekTime(timeSeconds * 1000)
  }

  toggleDebugInfo() {
    this.debugInfoVisible = !this.debugInfoVisible
    // 0 才是完全关闭；等级 1 仍会显示时间/进度 OSD。
    this.applyDebugInfoVisibility()
  }

  setRotation() {
    // 这里需要有个默认值，否则会视频宽高为0，导致视频无法播放
    const decodedWidth = this.getPlayAreaWidth()
    const decodedHeight = this.getPlayAreaHeight()
    const metadataWidth = this.nowPlaying?.size[0] ?? 0
    const metadataHeight = this.nowPlaying?.size[1] ?? 0
    const hasDecodedSize = decodedWidth > 0 && decodedHeight > 0
    const hasMetadataSize = metadataWidth > 1 && metadataHeight > 1
    const VideoWidth = hasDecodedSize ? decodedWidth : (hasMetadataSize ? metadataWidth : this.screenWidth)
    const VideoHeight = hasDecodedSize ? decodedHeight : (hasMetadataSize ? metadataHeight : this.screenHeight)
    if (VideoWidth <= 0 || VideoHeight <= 0 || this.screenWidth <= 0 || this.screenHeight <= 0) {
      return
    }
    const aspectRatioNow = VideoWidth / VideoHeight
    const screenAspectRatio = this.screenWidth / this.screenHeight
    if (aspectRatioNow > screenAspectRatio) {
      this.playAreaWidth = this.screenWidth
      this.playAreaHeight = this.playAreaWidth * (VideoHeight / VideoWidth)
    } else {
      this.playAreaHeight = this.screenHeight
      this.playAreaWidth = this.playAreaHeight * (VideoWidth / VideoHeight)
    }
    if (this.windowClass) {
      this.playAreaWidth > this.playAreaHeight ? WindowUtil.enableLandscapeMultiWindow(this.windowClass) :
        WindowUtil.disableLandscapeMultiWindow(this.windowClass)
      VideoInfoUtil.saveOriginalVideoWidthAndHeight(this.playAreaWidth, this.playAreaHeight)
    }
    if (this.nowPlaying && VideoInfoUtil.hasVideoTrack(this.nowPlaying) &&
      this.nowPlaying.size[0] <= 1 && hasDecodedSize) {
      this.nowPlaying!.size[0] = VideoWidth
      this.nowPlaying!.size[1] = VideoHeight
      MediaLibraryService.saveData(PathUtils.appContext!, this.nowPlaying, { size: this.nowPlaying.size })
    }
    this.applyScreenExtend()
    this.subtitleController.applySubtitleStyle()
    PiPWindowUtil.updateContentSize()
  }

  setKeepAspectStatus(keepAspect: boolean) {
    mpvSetKeepAspect(this.mpvHandle, keepAspect)
  }

  setSessionListener() {
    this.clearSessionNavigationListeners()
    try {
      this.avSession?.on('play', () => {
        this.play()
      })
      this.avSession?.on('pause', () => {
        this.pause()
      })
      this.avSession?.on('seek', (position: number) => {
        this.seekTime(position)
      })
      this.avSession?.on('fastForward', () => {
        this.fastForward()
      })
      this.avSession?.on('rewind', () => {
        this.backForward()
      })
      this.avSession?.on('outputDeviceChange', (state: avSession.ConnectionState,
        device: avSession.OutputDeviceInfo) => {
        if (state === avSession.ConnectionState.STATE_CONNECTED &&
          device.devices.some(item => item.castCategory === avSession.AVCastCategory.CATEGORY_REMOTE)) {
          this.pause()
        }
      })
      this.avSession?.on('setLoopMode', (mode: avSession.LoopMode) => {
        this.repeatMode = AVSessionUtil.getRepeatModeFromAvSession(mode)
        this.repeatMode = VideoOperateUtil.getRepeatMode(this.repeatMode)
        AVSessionUtil.updatePlaybackSessionState(this.playing, this.playTime, this.repeatMode, this.speed)
      })
      this.avSession?.on('playNext', () => {
        this.playAdjacentVideoFromSession('next')
      })
      this.avSession?.on('playPrevious', () => {
        this.playAdjacentVideoFromSession('previous')
      })
    } catch (error) {
      salmonLogger.addLog(TAG, 'set avSession state error', true)
    }
  }

  private clearSessionNavigationListeners(): void {
    try {
      this.avSession?.off('playNext')
    } catch (_error) {
    }
    try {
      this.avSession?.off('playPrevious')
    } catch (_error) {
    }
  }

  private playAdjacentVideoFromSession(direction: 'previous' | 'next'): void {
    const pathStack = this.currentPathStack
    if (!pathStack) {
      salmonLogger.addLog(TAG, `无法响应系统${direction === 'next' ? '下一首' : '上一首'}：播放页上下文未就绪`, true)
      return
    }
    const repeatMode = VideoOperateUtil.getManualNavigationRepeatMode(this.repeatMode)
    const task = direction === 'next' ?
      this.playNextVideoProcess(pathStack, this.windowClass, undefined, repeatMode) :
      this.playPreviousVideoProcess(pathStack, this.windowClass, undefined, repeatMode)
    task.catch((error: Error) => {
      salmonLogger.addLog(TAG,
        `系统${direction === 'next' ? '下一首' : '上一首'}执行失败：${error.message}`, true)
    })
  }

  async initAVSession() {
    AVSessionUtil.applyAudioConcurrencyMode()
    this.registerAudioInterruptListener()
    this.avSession = await AVSessionUtil.getAVSession()
    if (!this.avSession || !this.nowPlaying) {
      salmonLogger.addLog(TAG, 'AVSession初始化失败：session或视频数据不可用', true)
      return
    }
    this.setSessionListener()
    await AVSessionUtil.setSessionInfo(this.nowPlaying)
    const initialPosition = this.playTime > 0 ? this.playTime :
      (this.nowPlaying.last_play || 0)
    AVSessionUtil.updatePlaybackSessionState(this.playing, initialPosition, this.repeatMode, this.speed)
  }

  async initVolumeAndBrightness() {
    let audioManager = audio.getAudioManager()
    this.audioVolumeManager = audioManager.getVolumeManager()
    let volumeList = VideoOperateUtil.getVolume()
    if (this.volume === 0) {
      this.volume = volumeList.get('volume')!
      this.volumeActually = this.volume
    }
    try {
      this.audioVolumeManager.off('streamVolumeChange')
    } catch (_error) {
    }
    clearTimeout(this.swipingVoiceTimer)
    try {
      this.audioVolumeManager.on('streamVolumeChange', audio.StreamUsage.STREAM_USAGE_MOVIE,
        (streamVolumeEvent: audio.StreamVolumeEvent) => {
          clearTimeout(this.swipingVoiceTimer)
          this.onSwipingVoice = true
          this.volumeActually = streamVolumeEvent.volume
          ToolsUtil.startVibration()
          this.swipingVoiceTimer = setTimeout(() => {
            this.swipingVoiceTimer = 0
            if (!this.volumeGestureActive) {
              this.onSwipingVoice = false
            }
          }, 800)
        })
    } catch (error) {
      salmonLogger.addLog(TAG, 'volumeChange error', true)
    }
    if (this.screenBrightness === 0) {
      this.screenBrightness = await VideoOperateUtil.getScreenBrightness()
    }
  }

  onScreenDoubleClick(tapX: number): void {
    handleScreenDoubleClick(tapX, this.screenWidth,
      (): void => this.togglePlayback(),
      (): void => this.backForward(),
      (): void => this.fastForward())
  }

  getAdjacentSubtitleOffset(direction: 'prev' | 'next', currentOffset: number): number | undefined {
    return VideoOperateUtil.getAdjacentSubtitleOffset(this.playTime, currentOffset, direction)
  }

  hasInnerSubtitleTrack(): boolean {
    return this.subtitleTrack.length > 0
  }

  hasExternalSubtitle(): boolean {
    return (this.nowPlaying?.external_subtitle_format?.length ?? 0) > 0
  }

  saveSubtitlePreferenceForCurrentVideo(
    subtitleVisibility: Visibility,
    isAIAsrShown: boolean,
    subtitle3DMode: Subtitle3DMode
  ): void {
    MediaLibraryService.saveSubtitlePreference(
      this.nowPlaying, this.subtitleSelected, this.subtitleTrackSelected,
      subtitleVisibility, isAIAsrShown, subtitle3DMode
    )
  }

  cancelSmartRotationTimer() {
    framePreviewSession.cancelRequests(this)
    if (this.shaderTimer) {
      clearTimeout(this.shaderTimer)
      this.shaderTimer = 0
    }
    if (this.smartRotationTimer) {
      clearTimeout(this.smartRotationTimer)
      this.smartRotationTimer = 0
    }
    if (this.postLoadMetadataTimer) {
      clearTimeout(this.postLoadMetadataTimer)
      this.postLoadMetadataTimer = 0
    }
    this.postLoadTaskGeneration++
    this.audioController.resetMedia()
    this.postLoadTasksExecuted = false
    this.userListener?.off('videoSizeReady')
  }

  isMpvPlayer(): boolean {
    return true
  }

  getWindowClass(): Promise<window.Window | undefined> | undefined {
    return this.windowClass
  }

  prepareIfNeeded(): void {
    this.prepare()
  }

  onPlayerReady(): void {
    WindowUtil.enableLandscapeMultiWindow(this.windowClass)
    this.initVolumeAndBrightness().catch((err: Error) => {
      salmonLogger.addLog(TAG, 'initVolumeAndBrightness failed: ' + err, true)
    })
  }

  savePlayerSpeed(context: Context): void {
    Preferences.saveVideoSpeed(context, this.speed + 'x')
  }

  onDisappearSaveSubtitlePreference(_subtitleVisibility: Visibility, _isAIAsrShown: boolean,
    _subtitle3DMode: Subtitle3DMode): void {
  }

  onDisappearCleanup(): void {
    AppStorage.delete('nowPlayingData')
  }

  async dispose(): Promise<void> {
    await this.release()
    try {
      this.audioVolumeManager?.off('streamVolumeChange')
      this.audioVolumeManager = null
    } catch (error) {
      salmonLogger.addLog(TAG, `音量监听取消错误 ${error}`, true)
    }
    try {
      this.audioSessionManager?.off('audioSessionDeactivated')
      this.audioSessionManager?.off('audioSessionStateChanged')
      if (this.outputDeviceListenerRegistered) {
        this.audioSessionManager?.off('currentOutputDeviceChanged')
        this.outputDeviceListenerRegistered = false
      }
      this.audioSessionManager = null
      this.audioInterruptRegistered = false
    } catch (error) {
      salmonLogger.addLog(TAG, `音频中断监听取消错误 ${error}`, true)
    }
  }

  async onDisappearRelease(): Promise<void> {
    await this.dispose()
  }

  async onSurfaceLoad(xComponentController: XComponentController, pathStack: NavPathStack,
    _windowClass?: Promise<window.Window | undefined>): Promise<void> {
    const requestGeneration = ++this.playRequestGeneration
    this.audioController.usbSession.cancelPendingOpen()
    const uri = this.nowPlaying?.uri
    if (!uri) return
    try {
      this.surfaceId = xComponentController.getXComponentSurfaceId()
      await PermissionUtil.activatePermission(uri)
      if (requestGeneration !== this.playRequestGeneration) return
      await this.prepareInitialSmartRotation()
      if (requestGeneration !== this.playRequestGeneration) return
      await this.init(uri, pathStack)
      if (requestGeneration !== this.playRequestGeneration || this.isInState(MpvPlayerState.ERROR)) return
      await this.initAVSession()
      if (requestGeneration !== this.playRequestGeneration) return
      await PiPWindowUtil.createPipController(xComponentController, this)
    } catch (error) {
      if (requestGeneration !== this.playRequestGeneration) return
      this.handleLoadFailure(`播放准备失败: ${error}`)
    }
  }

  onOsdSurfaceLoad(surfaceId: string, surfaceWidth: number, surfaceHeight: number): void {
    this.osdSurfaceId = surfaceId
    this.osdSurfaceWidth = surfaceWidth
    this.osdSurfaceHeight = surfaceHeight
    this.syncOsdSurfaceSize()
  }

  onOsdSurfaceDestroy(surfaceId: string): void {
    // XComponent 重建时旧 onDestroy 可能晚于新 onLoad，不能清掉新 Surface。
    if (this.osdSurfaceId !== surfaceId) {
      return
    }
    this.clearOsdSurfaceBinding()
  }

  private clearOsdSurfaceBinding(): void {
    if (!this.osdSurfaceId && this.osdSurfaceWidth === 0 && this.osdSurfaceHeight === 0) {
      return
    }
    this.osdSurfaceId = null
    this.osdSurfaceWidth = 0
    this.osdSurfaceHeight = 0
    this.setOsdSurface('0', 0, 0)
  }

  setSubtitlePosition(position: number): void {
    this.subtitlePosition = Math.max(5, Math.min(100, Math.round(position)))
    this.subtitleController.applySubtitleStyle()
  }

  setSubtitleSize(size: number): void {
    this.subtitleSize = Math.max(14, Math.min(48, Math.round(size)))
    this.subtitleController.applySubtitleStyle()
  }

  restoreSpeedAfterLongPress(lastSpeed: number): void {
    this.speed = lastSpeed
    this.updatePlaybackSpeed(this.speed)
  }

  async restoreSystemBars(_windowClass?: Promise<window.Window | undefined>): Promise<void> {
    WindowUtil.setBarState(PathUtils.appContext!, true, true)
  }

  onWillDisappearCleanup(): void {
    clearTimeout(this.swipingVoiceTimer)
    this.swipingVoiceTimer = 0
    this.volumeGestureActive = false
    this.onSwipingVoice = false
    this.smartRotationAllowed = false
    this.cancelSmartRotationTimer()
    this.userListener?.off('videoSizeReady')
  }

  async onWillDisappearRelease(_windowClass?: Promise<window.Window | undefined>): Promise<void> {
    await this.dispose()
  }

  hasChapterSupport(): boolean {
    return true
  }

  onMetricsEvent(_callback: (info: Array<media.AVMetricsEvent>) => void): void {
  }

  offMetricsEvent(_callback?: (info: Array<media.AVMetricsEvent>) => void): void {
  }

  resetAspectRatio(): void {
    this.setKeepAspectStatus(true)
  }

  stretchToFullScreen(): void {
    this.setKeepAspectStatus(false)
  }

  async exitPlayback(_timeout: number): Promise<void> {
    await this.release()
  }

  toggleListenVideo(): void {
  }

  getXComponentId(): string | undefined {
    return 'xcomponentId'
  }

  getLibraryName(): string | undefined {
    return 'mpvnative'
  }

  getOsdVisibility(): boolean {
    return this.osdVisibility
  }

  setEngineSwitchHandler(handler: PlayerEngineSwitchHandler | undefined): void {
    this.engineSwitchHandler = handler
  }

  async requestEngineSwitch(targetEngine: string, reason: string, resumePlayback?: boolean): Promise<void> {
    if (!this.engineSwitchHandler) {
      salmonLogger.addLog(TAG, `Ignore engine switch without handler: ${reason}`, true)
      return
    }
    await this.engineSwitchHandler(targetEngine, reason, resumePlayback)
  }



  private applyDebugInfoVisibility(): void {
    mpvSetOsdLevel(this.debugInfoVisible ? 3 : 0)
  }

  private preparePlayUrl(url: string): string {
    if (ToolsUtil.isNetworkUrl(url)) {
      return this.smbPlayback.current(url)
    }

    const localPath = new fileUri.FileUri(url).path
    if (!IsoFileUtil.isIsoFile(url)) {
      return localPath
    }

    const isoType = IsoFileUtil.detectIsoTypeSync(url)
    if (isoType === IsoFileType.DVD) {
      const configured = mpvSetDvdDevice(this.mpvHandle, localPath)
      salmonLogger.addLog(TAG,
        `[DiscRouting] type=DVD, device=${localPath}, configured=${configured}, protocol=dvd://`,
        !configured)
      return 'dvd://'
    }

    const configured = mpvSetBlurayDevice(this.mpvHandle, localPath)
    const detectedType = isoType === IsoFileType.BLURAY ? 'BLURAY' : 'UNKNOWN(default BLURAY)'
    salmonLogger.addLog(TAG,
      `[DiscRouting] type=${detectedType}, device=${localPath}, configured=${configured}, protocol=bd://longest`,
      !configured || isoType === IsoFileType.UNKNOWN)
    return 'bd://longest'
  }

  private consumeInitialStartPositionMs(): number | undefined {
    if (this.initialPlayTime !== undefined) {
      const resumeTime = Math.max(0, this.initialPlayTime)
      this.initialPlayTime = undefined
      salmonLogger.addLog(TAG, `切换引擎时由 loadfile 恢复播放进度: ${resumeTime}`, false)
      return resumeTime
    }

    const mode = VideoOperateUtil.getVideoStartPlayTimeMode(this.nowPlaying!)
    switch (mode) {
      case VideoStartTimeMode.SEEK_TO_LAST_PLAY_TIME:
        return Math.max(0, this.nowPlaying?.last_play || 0)
      case VideoStartTimeMode.SEEK_TO_START_TIME:
        return Math.max(0, this.nowPlaying?.start_time || 0)
      case VideoStartTimeMode.SEEK_TO_INTRO_TIME:
        return Math.max(0, Number(Setting.skipIntroTime) * 1000)
      case VideoStartTimeMode.SEEK_TO_BEGINNING:
        return 0
      default:
        return undefined
    }
  }

  private getInitialSubtitleTrackId(): number | undefined {
    if (!this.nowPlaying || !SubtitleUtil.hasSubtitlePreferenceMetadata(this.nowPlaying)) {
      return undefined
    }
    if (this.nowPlaying.subtitle_mode === SubtitleMode.INNER_SUBTITLE &&
      this.nowPlaying.subtitle_track_id !== undefined && this.nowPlaying.subtitle_track_id >= 0) {
      return this.nowPlaying.subtitle_track_id
    }
    return -1
  }

  private async prepareInitialSmartRotation(): Promise<void> {
    const requestGeneration = this.playRequestGeneration
    this.initialSmartRotationRequested = false
    const videoWidth = this.nowPlaying?.size[0] || 0
    const videoHeight = this.nowPlaying?.size[1] || 0
    if (!this.smartRotationAllowed || !Setting.smartRotation || videoWidth <= videoHeight ||
      this.screenWidth <= 0 || this.screenHeight <= this.screenWidth) {
      return
    }

    const proportion = this.screenHeight / this.screenWidth
    const orientation = proportion > (16 / 10) ? window.Orientation.AUTO_ROTATION_LANDSCAPE
      : window.Orientation.AUTO_ROTATION_RESTRICTED
    try {
      const targetWindow = await this.windowClass
      if (!targetWindow || !this.smartRotationAllowed || requestGeneration !== this.playRequestGeneration) {
        return
      }
      await targetWindow.setPreferredOrientation(orientation)
      if (requestGeneration !== this.playRequestGeneration) {
        return
      }
      this.initialSmartRotationRequested = true
      salmonLogger.addLog(TAG, '已在 loadfile 前请求智能横屏', false)
    } catch (error) {
      salmonLogger.addLog(TAG, `起播前设置窗口方向失败: ${error}`, true)
    }
  }

  private schedulePostLoadTasks() {
    if (this.postLoadMetadataTimer) {
      clearTimeout(this.postLoadMetadataTimer)
      this.postLoadMetadataTimer = 0
    }
    const generation = ++this.postLoadTaskGeneration
    this.postLoadTasksExecuted = false
    this.userListener?.on('videoSizeReady', (_data: number) => {
      if (this.postLoadTasksExecuted) {
        return
      }
      this.executePostLoadTasks(generation)
    })
    this.smartRotationTimer = setTimeout(() => {
      if (!this.postLoadTasksExecuted) {
        this.executePostLoadTasks(generation)
      }
    }, 0) as number
    this.scheduleShader(generation)
  }

  private async executePostLoadTasks(generation: number) {
    if (generation !== this.postLoadTaskGeneration || this.postLoadTasksExecuted || !this.smartRotationAllowed ||
      !this.engineAdapter.isMediaLoaded()) {
      return
    }
    this.postLoadTasksExecuted = true
    clearTimeout(this.smartRotationTimer)
    this.userListener?.off('videoSizeReady')

    if (!this.smartRotationAllowed || !this.mpvHandle || this.isInState(MpvPlayerState.RELEASING) ||
      this.isInState(MpvPlayerState.IDLE)) {
      return
    }
    this.setRotation()
    if (this.speed !== 1) {
      this.updatePlaybackSpeed(this.speed)
    }
    // Create the transparent OSD Surface before synchronous native metadata
    // queries. On 4K files getAudioTracks alone can occupy the ArkUI thread
    // for hundreds of milliseconds and used to delay both rotation and OSD.
    if (this.activeHwdecMode === MpvDecodingMethod.HARDWARE_SURFACE && !this.osdVisibility) {
      this.osdVisibility = true
    }
    if (!this.initialStartHandledByLoad) {
      const mpvSeekMode = VideoOperateUtil.getVideoStartPlayTimeMode(this.nowPlaying!)
      this.videoStartPlayTime(mpvSeekMode)
    }
    this.initialStartHandledByLoad = false
    this.nowPlaying!.time = this.getDuration()
    if (this.smartRotationAllowed && !this.initialSmartRotationRequested && Setting.smartRotation &&
      this.playAreaWidth > this.playAreaHeight &&
      this.screenHeight > this.screenWidth) {
      salmonLogger.addLog(TAG, "智能旋转条件满足，开始设置方向", false)
      const proportion =
        Math.max(this.screenWidth, this.screenHeight) / Math.min(this.screenWidth, this.screenHeight)
      const orientation = proportion > (16 / 10) ? window.Orientation.AUTO_ROTATION_LANDSCAPE
        : window.Orientation.AUTO_ROTATION_RESTRICTED;
      const targetWindow = await this.windowClass
      if (generation !== this.postLoadTaskGeneration || !this.smartRotationAllowed) {
        return
      }
      targetWindow?.setPreferredOrientation(orientation)?.catch(() => {
        salmonLogger.addLog(TAG, "设置窗口方向失败", true)
      })
    }
    if (generation !== this.postLoadTaskGeneration || !this.engineAdapter.isMediaLoaded()) {
      return
    }
    this.onSwiping = false
    this.isSliderPlayTimeChange = false
    if (this.initialPlaying === false) {
      this.pause()
    }
    this.initialPlaying = undefined

    // Yield a render turn so the resized video/OSD Surfaces can be committed
    // before track, HDR and external-subtitle enumeration blocks ArkUI.
    this.postLoadMetadataTimer = setTimeout(() => {
      this.postLoadMetadataTimer = 0
      this.executeDeferredPostLoadMetadata(generation).catch((error: Error) => {
        salmonLogger.addLog(TAG, `[MpvController] Deferred post-load metadata failed: ${error.message}`, true)
      })
    }, 100) as number
  }

  private async executeDeferredPostLoadMetadata(generation: number): Promise<void> {
    if (generation !== this.postLoadTaskGeneration || !this.smartRotationAllowed || !this.mpvHandle ||
      !this.engineAdapter.isMediaLoaded() ||
      this.isInState(MpvPlayerState.RELEASING) || this.isInState(MpvPlayerState.IDLE)) {
      return
    }
    this.decodingRecovery.checkDolbyVisionAndSwitch()
    if (generation !== this.postLoadTaskGeneration || !this.engineAdapter.isMediaLoaded()) {
      return
    }
    this.detectAndUpdateHdrType()
    await Promise.all([
      this.audioController.getAudioTrackList(),
      this.subtitleController.getSubtitleTrackList()
    ])
    if (generation !== this.postLoadTaskGeneration || !this.mpvHandle) {
      return
    }
    this.getChapterListFromMpv()
    await this.subtitleController.setExternalSubtitle(this.nowPlaying!)
    if (generation === this.postLoadTaskGeneration) await this.audioController.restoreExternalAudio(generation)
  }

  private applyScreenExtend() {
    const size = VideoOperateUtil.calcScreenExtendSize(this.selectedText, this.screenWidth, this.screenHeight)
    if (size) {
      this.playAreaWidth = size[0]
      this.playAreaHeight = size[1]
    }
  }

  private transitionTo(newState: MpvPlayerState): void {
    const oldState = this.playerState
    if (oldState === newState) {
      return
    }
    salmonLogger.addLog(TAG, `播放器状态转换: ${MpvPlayerState[oldState]} -> ${MpvPlayerState[newState]}`, false)
    this.playerState = newState
    this.playing = newState === MpvPlayerState.PLAYING
    const key = MpvPlayerState[newState]
    const resolver = this.stateChangeResolvers.get(key)
    if (resolver) {
      resolver()
      this.stateChangeResolvers.delete(key)
    }
  }

  private computeDecodeType(): MpvDecodingMethod {
    let decodeType = Setting.mpvDecodingMethod
    if (this.nowPlaying && VideoInfoUtil.hasVideoTrack(this.nowPlaying) && Setting.mpvAutoDeinterlace) {
      // OHCodec Surface/GPU frames cannot reliably reach the software bwdif filter.
      // Keep the user's decoder preference intact for when this option is disabled.
      decodeType = MpvDecodingMethod.SOFTWARE
    }
    return decodeType
  }

  private applyAutoDeinterlace(): void {
    if (!this.mpvHandle) {
      throw new Error('MPV core is not created')
    }
    // Apply on every load, including reused instances and fallback recreation.
    const mode = this.activeAutoDeinterlace ? 'auto' : 'no'
    const result = mpvCommand(this.mpvHandle, ['set', 'options/deinterlace', mode]) as MpvCommandResult
    if (!result || !result.success) {
      throw new Error(`设置自动去交错失败: ${result?.error ?? 'unknown error'}`)
    }
  }

  private restoreOrdinaryAudioOutput(preserveDecodeMode: boolean = false): void {
    // Destroy the old AO before releasing its USB descriptor. A fresh core also
    // removes partially applied USB/opaque DSD options and restores PCM defaults.
    this.cleanupMpvInstance()
    this.audioController.releaseOutput()
    if (!preserveDecodeMode) this.applyDecodeType()
    this.engineAdapter.create()
    if (!this.mpvHandle) throw new Error(ToolsUtil.getStringResource($r('app.string.audio_core_create_failed').id))
    if (!preserveDecodeMode) this.activeHwdecMode = this.computeDecodeType()
  }

  private applyDecodeType(): void {
    const decodeType = this.computeDecodeType()
    this.applySuperResolution()
    mpvSetGpuApi(Setting.mpvGpuApi)
    this.applySdrToHdr(decodeType)
    switch (decodeType) {
      case MpvDecodingMethod.HARDWARE_SURFACE:
        mpvSetDecodeType(0)
        mpvSetHwdecMode(1)
        break
      case MpvDecodingMethod.SOFTWARE:
        mpvSetDecodeType(1)
        mpvSetHwdecMode(0)
        break
      case MpvDecodingMethod.HARDWARE_BUFFER:
        mpvSetDecodeType(0)
        mpvSetHwdecMode(0)
        break
      default:
        mpvSetDecodeType(1)
        mpvSetHwdecMode(0)
    }
  }

  private registerTimeUpdateCallback() {
    if (this.timeUpdateCallbackRegistered) {
      return
    }
    try {
      mpvRegisterTimeUpdateCallback((timeMs: number) => {
        if (!this.engineAdapter.isMediaLoaded()) {
          return
        }
        this.playbackPositionMs = timeMs
        const generation = this.postLoadTaskGeneration
        if (!this.onSwiping) {
          ThrottleUtil.throttle('playTime', () => {
            if (generation === this.postLoadTaskGeneration && this.engineAdapter.isMediaLoaded()) {
              this.playTime = timeMs
            }
          }, 100)
        }
        this.userListener?.emit('timeUpdate', this.playTime)
        if (this.subtitleController.is3DActive() &&
          this.subtitleSelected === SubtitleMode.INNER_SUBTITLE) {
          ThrottleUtil.throttle('mpv3DSubtitleText', () => {
            if (generation === this.postLoadTaskGeneration && this.engineAdapter.isMediaLoaded()) {
              this.subtitleController.refreshMpv3DSubtitleText()
            }
          }, 100)
        }
      })
      this.timeUpdateCallbackRegistered = true
    } catch (error) {
      salmonLogger.addLog(TAG, 'Failed to register time update callback', error)
    }
  }

  // 注册视频尺寸变化回调
  private registerVideoSizeChangedCallback() {
    if (this.videoSizeCallbackRegistered) {
      return
    }
    try {
      mpvRegisterVideoSizeChangedCallback(() => {
        if (!this.engineAdapter.isMediaLoaded()) {
          return
        }
        this.decodingRecovery.completeDecodingModeVerificationOnVideoSize()
        if (!this.smartRotationAllowed) {
          return
        }
        salmonLogger.addLog(TAG, '[MpvController] Video size changed, syncing OSD surface size')
        this.userListener?.emit('videoSizeReady', 0)
        if (this.postLoadTasksExecuted) {
          this.setRotation()
          if (!this.initialSmartRotationRequested && Setting.smartRotation &&
            this.playAreaWidth > this.playAreaHeight &&
            this.screenHeight > this.screenWidth) {
            const proportion =
              Math.max(this.screenWidth, this.screenHeight) / Math.min(this.screenWidth, this.screenHeight)
            const orientation = proportion > (16 / 10) ? window.Orientation.AUTO_ROTATION_LANDSCAPE
              : window.Orientation.AUTO_ROTATION_RESTRICTED
            const generation = this.postLoadTaskGeneration
            this.windowClass?.then(w => {
              if (generation === this.postLoadTaskGeneration && this.smartRotationAllowed) {
                w?.setPreferredOrientation(orientation)?.catch(() => {
                })
              }
            })
          }
        }
      })
      this.videoSizeCallbackRegistered = true
    } catch (error) {
      salmonLogger.addLog(TAG, 'Failed to register video size changed callback', error)
    }
  }

  // 注册播放完成监听器
  private registerPlaybackCompleteListener(pathStack: NavPathStack) {
    this.currentPathStack = pathStack
    // 避免重复注册回调
    if (this.playbackCallbackRegistered) {
      salmonLogger.addLog(TAG, "播放完成监听器已注册，跳过重复注册", false)
      return
    }

    try {
      mpvRegisterPlaybackCompleteCallback((requestId: number) => {
        this.handlePlaybackComplete(requestId)
      })
      this.playbackCallbackRegistered = true
      salmonLogger.addLog(TAG, "播放完成监听器注册成功", false)
    } catch (error) {
      salmonLogger.addLog(TAG, "播放完成监听器注册失败: " + JSON.stringify(error), true)
    }
  }

  private handlePlaybackComplete(requestId: number): void {
    if (!this.engineAdapter.acceptsEvent(requestId) || this.isInState(MpvPlayerState.RELEASING) ||
      this.isInState(MpvPlayerState.IDLE) || this.isInState(MpvPlayerState.ERROR) ||
      this.isInState(MpvPlayerState.COMPLETED)) {
      return
    }
    if (!this.engineAdapter.isMediaLoaded()) {
      // Different N-API callback queues need not dispatch FILE_LOADED before
      // EOF for very short clips. Consume it once the matching load arrives.
      this.pendingCompletionRequestId = requestId
      return
    }
    this.pendingCompletionRequestId = 0
    const duration = this.getDuration()
    if (duration > 0 && this.playTime < duration * 0.95) {
      salmonLogger.addLog(TAG, `[MpvController] EOF position differs from duration: request=${requestId}, ` +
        `position=${this.playTime}, duration=${duration}; trusting native EOF`, true)
    }
    // Native END_FILE reason=ERROR/STOP never reaches this callback. Throttled
    // progress or imprecise duration must not strand a genuine EOF on screen.
    salmonLogger.addLog(TAG, `收到播放完成事件 request=${requestId}，准备播放下一个视频`, false)
    this.transitionTo(MpvPlayerState.COMPLETED)
    this.playTime = duration || this.nowPlaying?.time || this.playTime
    if (!this.skipHistory && this.nowPlaying) {
      MediaLibraryService.saveVideoTime(this.playTime, this.nowPlaying, PathUtils.appContext!)
    }
    const pathStack = this.currentPathStack
    if (pathStack) {
      this.playNextVideoProcess(pathStack).catch((error: Error) => {
        salmonLogger.addLog(TAG, `play next video failed: ${error.message}`, true)
      })
    }
  }

  setSuperResolutionState(enable: boolean): void {
    try {
      mpvSetSuperResolution(enable && !Setting.mpvSdrToHdr)
      this.superResolutionState = enable
      Setting.superResolutionState = enable
      Preferences.saveSuperResolutionState(PathUtils.appContext!, enable)
    } catch (error) {
      salmonLogger.addLog(TAG, `[SuperResolution] Failed to change setting: ${error}`, true)
      ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.set_super_resolution_failed').id))
    }
  }

  private applySuperResolution(): void {
    this.superResolutionState = Setting.superResolutionState
    try {
      mpvSetSuperResolution(this.superResolutionState && !Setting.mpvSdrToHdr)
    } catch (error) {
      this.superResolutionState = false
      salmonLogger.addLog(TAG, `[SuperResolution] Unavailable: ${error}`, true)
    }
  }

  private applySdrToHdr(decodeType: MpvDecodingMethod): void {
    let hdrMode = 0
    if (Setting.mpvSdrToHdr && decodeType !== MpvDecodingMethod.HARDWARE_SURFACE) {
      try {
        const activeDisplay = display.getDefaultDisplaySync()
        if (activeDisplay.hdrFormats.includes(hdrCapability.HDRFormat.VIDEO_HDR10)) {
          hdrMode = 1
        } else if (activeDisplay.hdrFormats.includes(hdrCapability.HDRFormat.VIDEO_HLG)) {
          hdrMode = 2
        }
      } catch (error) {
        salmonLogger.addLog(TAG, `[MpvController] SDR to HDR capability query failed: ${error}`, true)
        hdrMode = 0
      }
      if (hdrMode === 0) {
        salmonLogger.addLog(TAG, '[MpvController] SDR to HDR unavailable; keeping SDR output', false)
      }
    }
    mpvSetSdrToHdr(hdrMode)
  }

  // 注册Surface模式错误回调
  private registerSurfaceModeErrorCallback() {
    if (this.surfaceModeErrorCallbackRegistered) {
      return
    }
    try {
      mpvRegisterSurfaceModeErrorCallback((errorMessage: string) => {
        if (this.isInState(MpvPlayerState.RELEASING) || this.isInState(MpvPlayerState.IDLE)) {
          salmonLogger.addLog(TAG, '[MpvController] Instance released, ignoring surface mode error', true)
          return
        }
        if (!errorMessage || errorMessage.trim().length === 0) {
          salmonLogger.addLog(TAG, '[MpvController] Empty surface mode error, ignoring', true)
          return
        }
        salmonLogger.addLog(TAG, '[MpvController] Surface mode error detected: ' + errorMessage, true)
        this.decodingRecovery.switchToBufferMode(errorMessage)
      })
      this.surfaceModeErrorCallbackRegistered = true
    } catch (error) {
      salmonLogger.addLog(TAG, 'Failed to register surface mode error callback', error)
    }
  }

  private registerBufferingStateCallback() {
    if (this.bufferingStateCallbackRegistered) {
      return
    }
    try {
      mpvRegisterBufferingStateCallback((buffering: boolean) => {
        if (!this.engineAdapter.isMediaLoaded() ||
          this.isInState(MpvPlayerState.RELEASING) || this.isInState(MpvPlayerState.IDLE)) {
          return
        }
        if (buffering) {
          if (!this.isInState(MpvPlayerState.BUFFERING)) {
            this.resumeAfterBuffering = this.isInState(MpvPlayerState.PLAYING)
          }
          this.transitionTo(MpvPlayerState.BUFFERING)
        } else if (this.isInState(MpvPlayerState.BUFFERING)) {
          const targetState = this.resumeAfterBuffering ? MpvPlayerState.PLAYING : MpvPlayerState.PAUSED
          this.resumeAfterBuffering = false
          this.transitionTo(targetState)
        }
      })
      this.bufferingStateCallbackRegistered = true
    } catch (error) {
      salmonLogger.addLog(TAG, 'Failed to register buffering state callback', error)
    }
  }

  private registerPauseStateCallback(): void {
    if (this.pauseStateCallbackRegistered) {
      return
    }
    try {
      mpvRegisterPauseStateCallback((paused: boolean) => {
        if (!this.engineAdapter.isMediaLoaded() ||
          this.isInState(MpvPlayerState.RELEASING) || this.isInState(MpvPlayerState.IDLE)) {
          return
        }
        let stateChanged = false
        if (paused && this.isInState(MpvPlayerState.PLAYING)) {
          salmonLogger.addLog(TAG, '[MpvController] mpv pause property changed to true (external interruption)', false)
          this.transitionTo(MpvPlayerState.PAUSED)
          stateChanged = true
        } else if (!paused && this.isInState(MpvPlayerState.PAUSED)) {
          this.transitionTo(MpvPlayerState.PLAYING)
          stateChanged = true
        }
        if (stateChanged) {
          AVSessionUtil.updatePlaybackSessionState(this.playing, this.playTime,
            this.repeatMode, this.speed)
        }
      })
      this.pauseStateCallbackRegistered = true
    } catch (error) {
      salmonLogger.addLog(TAG, 'Failed to register pause state callback', error)
    }
  }

  private handleLoadFailure(message: string): void {
    this.cancelDecodingModeTimers()
    this.engineAdapter.invalidateLoad()
    this.pendingCompletionRequestId = 0
    salmonLogger.addLog(TAG, `[MpvController] ${message}`, true)
    this.transitionTo(MpvPlayerState.ERROR)
    AVSessionUtil.updatePlaybackSessionState(false, this.playTime, this.repeatMode, this.speed)
    ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.video_load_failed_logged').id))
  }

  private registerMediaLoadCallback(): void {
    if (this.mediaLoadCallbackRegistered) {
      return
    }
    try {
      mpvRegisterMediaLoadCallback((loaded: boolean, errorCode: number, requestId: number) => {
        if (!this.engineAdapter.acceptsEvent(requestId) ||
          this.isInState(MpvPlayerState.RELEASING) || this.isInState(MpvPlayerState.IDLE)) {
          return
        }
        if (!loaded || !this.engineAdapter.isAlive()) {
          this.handleLoadFailure(`MPV 加载/播放失败 request=${requestId}, errorCode=${errorCode}, ` +
            `coreAlive=${this.engineAdapter.isAlive()}`)
          return
        }

        this.engineAdapter.markLoaded(requestId)
        salmonLogger.addLog(TAG, `[MpvController] MPV file loaded request=${requestId}`, false)
        // loadfile replace 后再明确同步一次播放状态，避免 EOF 状态残留。
        if (this.isInState(MpvPlayerState.LOADING)) {
          if (this.initialPlaying === false) {
            mpvPause(this.mpvHandle)
            this.transitionTo(MpvPlayerState.PAUSED)
          } else {
            mpvPlay(this.mpvHandle)
            this.transitionTo(MpvPlayerState.PLAYING)
          }
          AVSessionUtil.updatePlaybackSessionState(this.playing, this.playTime, this.repeatMode, this.speed)
        } else if (this.isInState(MpvPlayerState.SWITCHING_MODE)) {
          // 解码模式切换仍由验证流程决定最终状态，但新文件必须先开始解码。
          mpvPlay(this.mpvHandle)
          this.decodingRecovery.completeDecodingModeVerificationOnVideoSize()
        }
        // Both initial load and decoder recreation need geometry, subtitles and HDR setup.
        this.schedulePostLoadTasks()
        if (this.pendingCompletionRequestId === requestId) {
          this.handlePlaybackComplete(requestId)
        }
      })
      this.mediaLoadCallbackRegistered = true
    } catch (error) {
      salmonLogger.addLog(TAG, `Failed to register media load callback: ${error}`, true)
    }
  }

  private registerAudioInterruptListener(): void {
    if (this.audioInterruptRegistered) {
      return
    }
    try {
      const sessionManager = audio.getAudioManager().getSessionManager()
      this.audioSessionManager = sessionManager
      sessionManager.on('audioSessionDeactivated', (deactivatedEvent: audio.AudioSessionDeactivatedEvent) => {
        if (this.audioSessionManager !== sessionManager ||
          this.isInState(MpvPlayerState.RELEASING) || this.isInState(MpvPlayerState.IDLE)) {
          return
        }
        salmonLogger.addLog(TAG,
          `[MpvController] AudioSession deactivated, reason: ${deactivatedEvent.reason}, pausing`, false)
        // 会话被停用不代表可自动恢复；等待用户再次播放。
        this.pause()
      })
      sessionManager.on('audioSessionStateChanged', (stateChangedEvent: audio.AudioSessionStateChangedEvent) => {
        if (this.audioSessionManager !== sessionManager ||
          this.isInState(MpvPlayerState.RELEASING) || this.isInState(MpvPlayerState.IDLE)) {
          return
        }
        switch (stateChangedEvent.stateChangeHint) {
          case audio.AudioSessionStateChangeHint.AUDIO_SESSION_STATE_CHANGE_HINT_RESUME:
            if (this.isInState(MpvPlayerState.PAUSED)) {
              const token = this.audioPauseGuard.beginResume()
              if (token < 0) {
                break
              }
              salmonLogger.addLog(TAG, '[MpvController] AudioSession focus restored, reactivating and resuming', false)
              const strategy: audio.AudioSessionStrategy = {
                concurrencyMode: Setting.allowConcurrentPlay ?
                  audio.AudioConcurrencyMode.CONCURRENCY_MIX_WITH_OTHERS :
                  audio.AudioConcurrencyMode.CONCURRENCY_DEFAULT
              }
              sessionManager.activateAudioSession(strategy).then(() => {
                if (this.audioSessionManager === sessionManager &&
                  this.isInState(MpvPlayerState.PAUSED) && this.audioPauseGuard.completeResume(token)) {
                  this.play()
                } else {
                  this.audioPauseGuard.resumeFailed(token)
                }
              }).catch((err: BusinessError) => {
                this.audioPauseGuard.resumeFailed(token)
                salmonLogger.addLog(TAG, `reactivateAudioSession error: ${err.code} ${err.message}`, true)
              })
            }
            break
          case audio.AudioSessionStateChangeHint.AUDIO_SESSION_STATE_CHANGE_HINT_PAUSE:
            this.audioPauseGuard.interrupt(this.decodingRecovery.getPlaybackIntentForModeSwitch(), true)
            this.pausePlayback()
            break
          case audio.AudioSessionStateChangeHint.AUDIO_SESSION_STATE_CHANGE_HINT_STOP:
          case audio.AudioSessionStateChangeHint.AUDIO_SESSION_STATE_CHANGE_HINT_TIME_OUT_STOP:
            salmonLogger.addLog(TAG,
              `[MpvController] AudioSession state changed: ${stateChangedEvent.stateChangeHint}, pausing`, false)
            this.pause()
            break
          case audio.AudioSessionStateChangeHint.AUDIO_SESSION_STATE_CHANGE_HINT_DUCK:
          case audio.AudioSessionStateChangeHint.AUDIO_SESSION_STATE_CHANGE_HINT_UNDUCK:
            salmonLogger.addLog(TAG,
              `[MpvController] AudioSession state changed: ${stateChangedEvent.stateChangeHint}`, false)
            break
          default:
            break
        }
      })
      // 监听当前音频流路由，不能用全局设备连接事件或投播事件代替。
      if (canIUse('SystemCapability.Multimedia.Audio.Core')) {
        try {
          sessionManager.on('currentOutputDeviceChanged', (event: audio.CurrentOutputDeviceChangedEvent) => {
            if (this.audioSessionManager !== sessionManager ||
              this.isInState(MpvPlayerState.RELEASING) || this.isInState(MpvPlayerState.IDLE)) {
              return
            }
            if (event.changeReason === audio.AudioStreamDeviceChangeReason.REASON_OLD_DEVICE_UNAVAILABLE) {
              this.audioPauseGuard.cancel()
              if (this.playing || this.isInState(MpvPlayerState.LOADING) ||
                this.isInState(MpvPlayerState.BUFFERING)) {
                salmonLogger.addLog(TAG, '[MpvController] Audio output device unavailable, pausing', false)
                this.pause()
              }
            }
          })
          this.outputDeviceListenerRegistered = true
        } catch (error) {
          salmonLogger.addLog(TAG, `Failed to register audio output device listener: ${error}`, true)
        }
      }
      this.audioInterruptRegistered = true
    } catch (error) {
      salmonLogger.addLog(TAG, 'Failed to register audio interrupt listener', error)
    }
  }

  private reactivateAudioSessionIfNeeded(): void {
    if (!this.audioSessionManager) {
      return
    }
    if (!this.audioSessionManager.isAudioSessionActivated()) {
      const strategy: audio.AudioSessionStrategy = {
        concurrencyMode: Setting.allowConcurrentPlay ?
          audio.AudioConcurrencyMode.CONCURRENCY_MIX_WITH_OTHERS :
          audio.AudioConcurrencyMode.CONCURRENCY_DEFAULT
      }
      this.audioSessionManager.activateAudioSession(strategy).then(() => {
        salmonLogger.addLog(TAG, '[MpvController] AudioSession reactivated on play', false)
      }).catch((err: BusinessError) => {
        salmonLogger.addLog(TAG, `reactivateAudioSession error: ${err.code} ${err.message}`, true)
      })
    }
  }

  // 统一的模式切换方法
  private switchDecodingMode(
    targetMode: 'buffer_hw' | 'buffer_sw',
    errorMessage: string,
    currentTime?: number,
    wasPlaying?: boolean,
    currentVideo?: VideoMetadata
  ) {
    if (this.activeAutoDeinterlace) {
      targetMode = 'buffer_sw'
    }
    if (this.isInState(MpvPlayerState.RELEASING) || this.isInState(MpvPlayerState.IDLE)) {
      salmonLogger.addLog(TAG, '[MpvController] Instance released, aborting decoding mode switch', true)
      return
    }
    // A Buffer-HW failure is detected while this state is still active. Allow
    // that internal continuation to advance to Buffer-SW instead of treating it
    // as an unrelated re-entrant request.
    if (this.isInState(MpvPlayerState.SWITCHING_MODE) && targetMode !== 'buffer_sw') {
      salmonLogger.addLog(TAG, '[MpvController] Already switching mode, skipping')
      return
    }
    this.decodingRecovery.cancelDecodingModeVerification()

    const savedTime = currentTime ?? 0
    const savedPlaying = wasPlaying ?? this.decodingRecovery.getPlaybackIntentForModeSwitch()
    this.initialPlaying = undefined

    this.transitionTo(MpvPlayerState.SWITCHING_MODE)

    const modeName = targetMode === 'buffer_hw' ? 'Buffer硬件解码' : '软件解码'
    salmonLogger.addLog(TAG,
      `[MpvController] Switching to ${modeName} mode, resumePlayback=${savedPlaying}: ${errorMessage}`, true)
    ToolsUtil.showToast(`正在切换到${modeName}模式...`)
    const savedVideo = currentVideo ?? this.nowPlaying

    this.cleanupMpvInstance()
    mpvSetGpuApi(Setting.mpvGpuApi)
    this.applySuperResolution()

    if (targetMode === 'buffer_hw') {
      mpvSetDecodeType(0)
      mpvSetHwdecMode(0)
    } else {
      mpvSetDecodeType(1)
      mpvSetHwdecMode(0)
    }
    this.applySdrToHdr(targetMode === 'buffer_hw' ?
      MpvDecodingMethod.HARDWARE_BUFFER : MpvDecodingMethod.SOFTWARE)

    this.engineAdapter.create()
    if (!this.mpvHandle) {
      salmonLogger.addLog(TAG, `[MpvController] Failed to create MPV instance in ${modeName} mode`, true)

      if (targetMode === 'buffer_hw') {
        this.switchDecodingMode('buffer_sw', 'Buffer硬件解码创建失败', savedTime, savedPlaying, savedVideo)
      } else {
        ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.switch_mode_failed').id))
        this.transitionTo(MpvPlayerState.ERROR)
      }
      return
    }

    this.activeHwdecMode = targetMode === 'buffer_hw' ? MpvDecodingMethod.HARDWARE_BUFFER : MpvDecodingMethod.SOFTWARE

    if (savedVideo) {
      try {
        this.audioController.configureUsbOutput(this.audioController.usbSession.descriptor)
      } catch (error) {
        salmonLogger.addLog(TAG, `[MpvController] 解码切换时 USB 不可用，改用普通音频输出: ${error}`, true)
        try {
          // Retain the newly selected decoder, including Surface -> Buffer fallback.
          this.restoreOrdinaryAudioOutput(true)
        } catch (restoreError) {
          this.handleLoadFailure(`普通音频核心重建失败: ${restoreError}`)
          return
        }
      }
      this.configureNetworkStateSubscription(savedVideo.uri)
      const reloadUrl = this.preparePlayUrl(savedVideo.uri)
      this.registerSurfaceModeErrorCallback()
      const reloadStartSeconds = savedTime > 0 ? savedTime / 1000 : undefined
      // Zero is also an intentional resume position; do not restore last_play again.
      this.initialStartHandledByLoad = true
      this.registerVideoSizeChangedCallback()
      this.decodingRecovery.startDecodingModeVerification(targetMode, savedTime, savedPlaying, savedVideo, modeName)
      this.getData().catch(() => {
        salmonLogger.addLog(TAG, 'reload callbacks failed', true)
      })
      if (this.currentPathStack) {
        this.registerPlaybackCompleteListener(this.currentPathStack)
      }
      try {
        this.applyAutoDeinterlace()
        if (!this.audioController.applyAudioPassthrough(this.speed, this.audioEffectConfig.effect)) {
          throw new Error(ToolsUtil.getStringResource($r('app.string.set_audio_output_mode_failed').id))
        }
        this.audioController.applyAudioCoverMode()
        this.engineAdapter.load(reloadUrl, reloadStartSeconds, this.getInitialSubtitleTrackId(),
          savedVideo.network_user_agent, this.smbPlayback.headers(savedVideo.network_http_headers))
      } catch (error) {
        this.handleLoadFailure(`${modeName}重新加载失败: ${error}`)
        return
      }
      this.subtitleController.applySubtitleStyle()

    } else {
      this.transitionTo(MpvPlayerState.IDLE)
    }
  }

  private configureNetworkStateSubscription(url: string): void {
    this.networkPlaybackActive = ToolsUtil.isNetworkUrl(url)
    this.networkSpeedText = '0 KB/s'
    this.networkBufferPercent = 0
    this.networkCacheDuration = 0
    this.networkBuffering = false

    if (!this.networkPlaybackActive) {
      if (this.networkStateCallbackRegistered) {
        this.unregisterNativeCallback(() => mpvUnregisterNetworkStateCallback(), 'networkState')
        this.networkStateCallbackRegistered = false
      }
      return
    }
    if (this.networkStateCallbackRegistered) {
      return
    }
    try {
      mpvRegisterNetworkStateCallback((state) => {
        if (!this.networkPlaybackActive || this.isInState(MpvPlayerState.RELEASING) ||
          this.isInState(MpvPlayerState.IDLE)) {
          return
        }
        this.networkSpeedText = state.speedStr
        this.networkBufferPercent = state.bufferPercent
        this.networkCacheDuration = state.cacheDuration
        this.networkBuffering = state.buffering
        this.decodingRecovery.handleDecodingModeNetworkState(state.speed, state.bufferPercent, state.cacheDuration, state.buffering)
      })
      this.networkStateCallbackRegistered = true
    } catch (error) {
      salmonLogger.addLog(TAG, 'Failed to register network state callback: ' + JSON.stringify(error), true)
    }
  }

  // 清理MPV实例
  private cleanupMpvInstance(): void {
    this.cancelSmartRotationTimer()
    this.pendingCompletionRequestId = 0
    // 先发布空 generation，让 VO 放弃旧 EGLSurface，再销毁 mpv/ArkUI Surface。
    this.clearOsdSurfaceBinding()
    if (this.mpvHandle) {
      try {
        this.engineAdapter.destroy(() => this.unregisterNativeCallbacks())
      } catch (error) {
        salmonLogger.addLog(TAG, '[MpvController] Error during cleanup: ' + JSON.stringify(error), true)
      }
    }

    // 重置回调注册标志
    this.osdVisibility = false
    this.playTime = 0
    this.subtitleController.reset()
    this.playbackCallbackRegistered = false
    this.timeUpdateCallbackRegistered = false
    this.videoSizeCallbackRegistered = false
    this.surfaceModeErrorCallbackRegistered = false
    this.bufferingStateCallbackRegistered = false
    this.mediaLoadCallbackRegistered = false
    this.networkStateCallbackRegistered = false
    this.networkPlaybackActive = false
    this.networkSpeedText = '0 KB/s'
    this.networkBufferPercent = 0
    this.networkCacheDuration = 0
    this.networkBuffering = false
    this.pauseStateCallbackRegistered = false
  }

  private unregisterNativeCallbacks(): void {
    this.unregisterNativeCallback(() => mpvUnregisterPlaybackCompleteCallback(), 'playbackComplete')
    this.unregisterNativeCallback(() => mpvUnregisterTimeUpdateCallback(), 'timeUpdate')
    this.unregisterNativeCallback(() => mpvUnregisterVideoSizeChangedCallback(), 'videoSizeChanged')
    this.unregisterNativeCallback(() => mpvUnregisterSurfaceModeErrorCallback(), 'surfaceModeError')
    this.unregisterNativeCallback(() => mpvUnregisterBufferingStateCallback(), 'bufferingState')
    this.unregisterNativeCallback(() => mpvUnregisterMediaLoadCallback(), 'mediaLoad')
    this.unregisterNativeCallback(() => mpvUnregisterNetworkStateCallback(), 'networkState')
    this.unregisterNativeCallback(() => mpvUnregisterPauseStateCallback(), 'pauseState')
    this.playbackCallbackRegistered = false
    this.timeUpdateCallbackRegistered = false
    this.videoSizeCallbackRegistered = false
    this.surfaceModeErrorCallbackRegistered = false
    this.bufferingStateCallbackRegistered = false
    this.mediaLoadCallbackRegistered = false
    this.networkStateCallbackRegistered = false
  }

  private unregisterNativeCallback(action: () => void, callbackName: string): void {
    try {
      action()
    } catch (error) {
      salmonLogger.addLog(TAG, `Failed to unregister ${callbackName}: ${error}`, true)
    }
  }

  private cancelDecodingModeTimers() {
    this.decodingRecovery.cancelDecodingModeVerification()
    this.cancelSmartRotationTimer()
  }

  private detectAndUpdateHdrType() {
    if (!this.mpvHandle || !this.nowPlaying) {
      return
    }
    if (this.nowPlaying.hdr_type === 1) {
      return
    }
    try {
      const detectedVideoHdr: number = mpvGetVideoHdrType(this.mpvHandle)
      if (detectedVideoHdr !== 0 && detectedVideoHdr !== this.nowPlaying.hdr_type) {
        this.nowPlaying.hdr_type = detectedVideoHdr
        MediaLibraryService.saveData(PathUtils.appContext!, this.nowPlaying, { hdrType: detectedVideoHdr })
      } else if (detectedVideoHdr === 0 && this.nowPlaying.hdr_type === 0) {
        setTimeout(() => {
          if (!this.mpvHandle || !this.nowPlaying) {
            return
          }
          try {
            const retryHdr: number = mpvGetVideoHdrType(this.mpvHandle)
            if (retryHdr !== 0 && retryHdr !== this.nowPlaying.hdr_type) {
              this.nowPlaying.hdr_type = retryHdr
              MediaLibraryService.saveData(PathUtils.appContext!, this.nowPlaying, { hdrType: retryHdr })
            }
          } catch (error) {
            salmonLogger.addLog(TAG, '[MpvController] Failed to retry detect video HDR type: ' + JSON.stringify(error),
              true)
          }
        }, 1500)
      }
    } catch (error) {
      salmonLogger.addLog(TAG, '[MpvController] Failed to detect video HDR type: ' + JSON.stringify(error), true)
    }
    try {
      const detectedAudio: number = mpvGetAudioType(this.mpvHandle)
      if (this.nowPlaying.audio_type !== 3) {
        if (detectedAudio !== 0 && detectedAudio !== this.nowPlaying.audio_type) {
          this.nowPlaying.audio_type = detectedAudio
          MediaLibraryService.saveData(PathUtils.appContext!, this.nowPlaying, { audioType: detectedAudio })
        } else if (detectedAudio === 0 && this.nowPlaying.audio_type === 0) {
          setTimeout(() => {
            if (!this.mpvHandle || !this.nowPlaying || this.nowPlaying.audio_type === 3) {
              return
            }
            try {
              const retryAudio: number = mpvGetAudioType(this.mpvHandle)
              if (retryAudio !== 0 && retryAudio !== this.nowPlaying.audio_type) {
                this.nowPlaying.audio_type = retryAudio
                MediaLibraryService.saveData(PathUtils.appContext!, this.nowPlaying, { audioType: retryAudio })
              }
            } catch (error) {
              salmonLogger.addLog(TAG, '[MpvController] Failed to retry detect audio type: ' + JSON.stringify(error),
                true)
            }
          }, 1500)
        }
      }
    } catch (error) {
      salmonLogger.addLog(TAG, '[MpvController] Failed to detect audio type: ' + JSON.stringify(error), true)
    }

  }
}
