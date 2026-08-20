import { PlayerControllerInterface, PlayerEngineSwitchHandler } from '../PlayerControllerFactory';
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface';
import { Subtitle3DMode, SubtitleMode } from '../../common/enum/SubtitleMode';
import {
  MpvAudioChannelMode,
  MpvAudioTrack,
  MpvChapter,
  MpvDecodingMethod,
  MpvSubtitleTexts,
  MpvSubtitleTrack
} from './MpvTypes';
import { MpvPlayerState } from './MpvPlayerState';
import { avSession, avSession as avSessionManager } from '@kit.AVSessionKit';
import { audio } from '@kit.AudioKit';
import { WindowUtil } from '../../utils/WindowUtil';
import { SweetRepeatMode } from '../../common/enum/SweetRepeatMode';
import { BaseListener } from '../../utils/BaseEventUtil';
import {
  getAudioTracks as mpvGetAudioTracks,
  getAudioType as mpvGetAudioType,
  getChapterList as mpvGetChapterList,
  getCurrentSecondarySubtitleTrack as mpvGetCurrentSecondarySubtitleTrack,
  getCurrentSubtitleTrack as mpvGetCurrentSubtitleTrack,
  getHardwareDecoder as mpvGetHardwareDecoder,
  getSubtitleTexts as mpvGetSubtitleTexts,
  getDolbyVisionProfile as mpvGetDolbyVisionProfile,
  getDuration as mpvGetDuration,
  getSubtitleTracks as mpvGetSubtitleTracks,
  getVideoHdrType as mpvGetVideoHdrType,
  getVideoHeight as mpvGetVideoHeight,
  getVideoWidth as mpvGetVideoWidth,
  loadExternalSubtitle as mpvLoadExternalSubtitle,
  pause as mpvPause,
  play as mpvPlay,
  registerBufferingStateCallback as mpvRegisterBufferingStateCallback,
  registerNetworkStateCallback as mpvRegisterNetworkStateCallback,
  registerPauseStateCallback as mpvRegisterPauseStateCallback,
  registerPlaybackCompleteCallback as mpvRegisterPlaybackCompleteCallback,
  registerSurfaceModeErrorCallback as mpvRegisterSurfaceModeErrorCallback,
  registerTimeUpdateCallback as mpvRegisterTimeUpdateCallback,
  registerVideoSizeChangedCallback as mpvRegisterVideoSizeChangedCallback,
  seek as mpvSeek,
  selectAudio as mpvSelectAudio,
  selectSecondarySubtitle as mpvSelectSecondarySubtitle,
  selectSubtitle as mpvSelectSubtitle,
  setAudioChannel as mpvSetAudioChannel,
  setBlurayDevice as mpvSetBlurayDevice,
  setDecodeType as mpvSetDecodeType,
  setDvdDevice as mpvSetDvdDevice,
  setGlslShaders as mpvSetGlslShaders,
  setGpuApi as mpvSetGpuApi,
  setHwdecMode as mpvSetHwdecMode,
  setKeepAspect as mpvSetKeepAspect,
  setLoudnessGain as mpvSetLoudnessGain,
  setOsdLevel as mpvSetOsdLevel,
  setOsdSurface as mpvSetOsdSurface,
  setSubtitleDelay as mpvSetSubtitleDelay,
  setSubtitleRenderVisibility as mpvSetSubtitleRenderVisibility,
  setSubtitleStyle as mpvSetSubtitleStyle,
  setSpeed as mpvSetSpeed,
  unregisterBufferingStateCallback as mpvUnregisterBufferingStateCallback,
  unregisterNetworkStateCallback as mpvUnregisterNetworkStateCallback,
  unregisterPauseStateCallback as mpvUnregisterPauseStateCallback,
  unregisterPlaybackCompleteCallback as mpvUnregisterPlaybackCompleteCallback,
  unregisterSurfaceModeErrorCallback as mpvUnregisterSurfaceModeErrorCallback,
  unregisterTimeUpdateCallback as mpvUnregisterTimeUpdateCallback,
  unregisterVideoSizeChangedCallback as mpvUnregisterVideoSizeChangedCallback,
} from 'libmpvnative.so';
import { window } from '@kit.ArkUI';
import { salmonLogger } from 'salmonlogger';
import {
  AUTO_HIDE_SHOW_CONTROL_TIME,
  LEFT_ZONE_DIVISION,
  RIGHT_ZONE_DIVISION,
  SCREEN_DIVISIONS,
  SUPPORT_AUDIO_FORMAT
} from '../../common/Constants';
import { VideoStartTimeMode } from '../../common/enum/VideoStartTimeMode';
import Preferences from '../../database/Preferences';
import AVSessionUtil from '../../utils/AVSessionUtil';
import IsoFileUtil, { IsoFileType } from '../../utils/IsoFileUtil';
import { Setting } from '../../utils/ObservedUtil';
import { PathUtils } from '../../utils/PathUtils';
import PermissionUtil from '../../utils/PermissionUtil';
import PiPWindowUtil from '../../utils/PiPWindowUtil';
import PrivacySpaceUtil from '../../utils/PrivacySpaceUtil';
import SelectFileUtil from '../../utils/SelectFileUtil';
import SubtitleUtil from '../../utils/SubtitleUtil';
import SubtitleStyleUtil from '../../utils/SubtitleStyleUtil';
import { ThrottleUtil } from '../../utils/DebounceUtil';
import ToolsUtil from '../../utils/ToolsUtil';
import VideoInfoUtil from '../../utils/VideoInfoUtil';
import VideoOperateUtil from '../../utils/VideoOperateUtil';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { MpvPlayerEngineAdapter } from '../engine/MpvPlayerEngineAdapter';

const TAG = 'MpvController'
const LOCAL_DECODING_MODE_TIMEOUT_MS = 500
const NETWORK_DECODING_MODE_INACTIVITY_TIMEOUT_MS = 15000

class ShaderConfig {
  rawDir: string
  files: string[]

  constructor(rawDir: string, files: string[]) {
    this.rawDir = rawDir
    this.files = files
  }
}

class DecodingModeVerification {
  targetMode: 'buffer_hw' | 'buffer_sw'
  savedTime: number
  savedPlaying: boolean
  savedVideo: VideoMetadata
  modeName: string
  token: number
  isNetworkStream: boolean
  lastNetworkSpeed: number = 0
  lastBufferPercent: number = -1
  lastCacheDuration: number = -1
  lastBuffering: boolean = false

  constructor(targetMode: 'buffer_hw' | 'buffer_sw', savedTime: number, savedPlaying: boolean,
    savedVideo: VideoMetadata, modeName: string, token: number) {
    this.targetMode = targetMode
    this.savedTime = savedTime
    this.savedPlaying = savedPlaying
    this.savedVideo = savedVideo
    this.modeName = modeName
    this.token = token
    this.isNetworkStream = ToolsUtil.isNetworkUrl(savedVideo.uri)
  }
}

@ObservedV2
export class MpvController implements PlayerControllerInterface {
  private static readonly SHADER_MODE_NAMES: string[] = ['关闭', 'Anime4K (动漫)', 'ArtCNN (通用)']
  private static readonly SHADER_CONFIGS: Map<number, ShaderConfig> = new Map<number, ShaderConfig>([
    [1, new ShaderConfig(
      'shaders/Anime4K',
      [
        'Anime4K_Clamp_Highlights.glsl',
        'Anime4K_Restore_CNN_M.glsl',
        'Anime4K_Upscale_CNN_x2_M.glsl',
        'Anime4K_AutoDownscalePre_x2.glsl',
        'Anime4K_AutoDownscalePre_x4.glsl',
      ]
    )],
    [2, new ShaderConfig(
      'shaders/ArtCNN',
      ['ArtCNN_C4F16.glsl']
    )]
  ])
  windowClass = WindowUtil.getWindow()
  surfaceId: string | null = null
  osdSurfaceId: string | null = null
  private osdSurfaceWidth: number = 0
  private osdSurfaceHeight: number = 0
  @Trace playTime: number = 0
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
  @Trace subtitleTrack: MpvSubtitleTrack[] = []
  @Trace subtitleTrackSelected: number = -1
  @Trace secondarySubtitleTrackSelected: number = -1
  private externalSubtitleTrackSelected: number = -1
  private externalSubtitleCodec: string = ''
  @Trace screenBrightness: number = 0
  @Trace onSwipingVoice: boolean = false
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
  @Trace subtitleSize: number = Number(Setting.subtitleSize)
  @Trace audioChannelMode: MpvAudioChannelMode = MpvAudioChannelMode.STEREO
  @Trace chapterList: MpvChapter[] = []
  @Trace lockVisibility: boolean = false
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
  avSession: avSessionManager.AVSession | undefined = undefined
  audioVolumeManager: audio.AudioVolumeManager | null = null
  @Trace playerState: MpvPlayerState = MpvPlayerState.IDLE
  private engineAdapter: MpvPlayerEngineAdapter = new MpvPlayerEngineAdapter()
  private lastSubtitle: string = ''
  private mpvSubtitle3DMode: Subtitle3DMode = Subtitle3DMode.DISABLED
  private isSkippingEnding: boolean = false
  private lastAppStorageUpdateTime: number = 0
  private audioSessionManager: audio.AudioSessionManager | null = null
  private userListener: BaseListener<number> | null = null
  private playbackCallbackRegistered: boolean = false
  private timeUpdateCallbackRegistered: boolean = false
  private videoSizeCallbackRegistered: boolean = false
  private surfaceModeErrorCallbackRegistered: boolean = false
  private bufferingStateCallbackRegistered: boolean = false
  private networkStateCallbackRegistered: boolean = false
  private pauseStateCallbackRegistered: boolean = false
  private audioInterruptRegistered: boolean = false
  private resumeAfterBuffering: boolean = false
  private stateChangeResolvers: Map<string, ((value: void) => void)> = new Map()
  private decodingModeVerifyTimer: number = 0
  private decodingModeVerifyToken: number = 0
  private pendingDecodingModeVerification: DecodingModeVerification | undefined = undefined
  private smartRotationTimer: number = 0
  private currentPathStack: NavPathStack | null = null
  private activeHwdecMode: MpvDecodingMethod = MpvDecodingMethod.HARDWARE_SURFACE
  private lastFrameFetchTime: number = 0
  private readonly FRAME_FETCH_INTERVAL: number = 200
  private lastFrameFetchPlayTime: number = -1
  private pendingFrameTime: number = -1
  private frameFetchTimer: number = 0
  private postLoadTasksExecuted: boolean = false
  private initialStartHandledByLoad: boolean = false
  private initialSmartRotationRequested: boolean = false
  private smartRotationAllowed: boolean = true
  private engineSwitchHandler: PlayerEngineSwitchHandler | undefined = undefined

  private get mpvHandle(): number | null {
    return this.engineAdapter.handle
  }

  static getShaderModeNames(): string[] {
    return MpvController.SHADER_MODE_NAMES
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
    this.osdVisibility = false
    salmonLogger.addLog(TAG, "开始播放选择的视频", false)
    if (!this.skipHistory) {
      VideoOperateUtil.saveVideoTime(this.playTime, this.nowPlaying!, PathUtils.appContext!)
    }

    this.playTime = 0
    this.pixelMap = null
    this.isSkippingEnding = false
    await this.reset()
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

    await PermissionUtil.activatePermission(item.uri)
    await this.prepareInitialSmartRotation()
    await this.init(item.uri, pathStack)
    salmonLogger.addLog(TAG, "获取播放数据完成", false)
    await this.initAVSession()
    salmonLogger.addLog(TAG, "播放选择视频流程完成", false)
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

  playAdjacentVideo(repeatMode: SweetRepeatMode,
    direction: 'previous' | 'next'): VideoMetadata | undefined {
    return VideoOperateUtil.computeAdjacentVideo(this.videoMetaDataList, this.nowPlaying, repeatMode, direction)
  }

  async create(): Promise<void> {
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
        this.activeHwdecMode = Setting.mpvDecodingMethod
        this.transitionTo(MpvPlayerState.IDLE)
      }
    } catch {
      salmonLogger.addLog(TAG, '[MpvPlayer] Exception during create', true)
      ToolsUtil.showToast("MPV 创建失败")
      this.transitionTo(MpvPlayerState.ERROR)
    }
  }

  async getFrameByTime(time: number, isFirstFrame: boolean) {
    if (!Setting.showFrameImgStatus) {
      return
    }
    this.pendingFrameTime = time
    if (isFirstFrame) {
      if (this.frameFetchTimer) {
        clearTimeout(this.frameFetchTimer)
        this.frameFetchTimer = 0
      }
      await this.fetchPendingFrame()
      return
    }
    this.schedulePendingFrameFetch()
  }

  private schedulePendingFrameFetch(): void {
    if (this.pendingFrameTime < 0 || !VideoOperateUtil.updatePix || this.frameFetchTimer) {
      return
    }
    const remaining = this.FRAME_FETCH_INTERVAL - (Date.now() - this.lastFrameFetchTime)
    if (remaining <= 0) {
      this.fetchPendingFrame()
      return
    }
    this.frameFetchTimer = setTimeout(() => {
      this.frameFetchTimer = 0
      this.fetchPendingFrame()
    }, remaining)
  }

  private async fetchPendingFrame(): Promise<void> {
    if (this.pendingFrameTime < 0 || !VideoOperateUtil.updatePix) {
      return
    }
    const time = this.pendingFrameTime
    this.pendingFrameTime = -1
    if (Math.floor(time) === Math.floor(this.lastFrameFetchPlayTime)) {
      this.schedulePendingFrameFetch()
      return
    }
    this.lastFrameFetchTime = Date.now()
    this.lastFrameFetchPlayTime = time
    VideoOperateUtil.updatePix = false
    try {
      const img = await VideoOperateUtil.fetchFrameByTime(time, this.nowPlaying?.size)
      if (img && Math.abs(this.playTime - time) < 3000) {
        this.pixelMap = img
      }
    } catch (error) {
      salmonLogger.addLog(TAG, '获取视频帧失败:' + error, true)
    } finally {
      VideoOperateUtil.updatePix = true
      this.schedulePendingFrameFetch()
    }
  }

  async init(url?: string, pathStack?: NavPathStack): Promise<void> {
    this.cancelDecodingModeVerification()
    const requiredMode = this.computeDecodeType()
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
    const playUrl = this.preparePlayUrl(url!)
    this.configureNetworkStateSubscription(url!)
    const initialStartPositionMs = this.consumeInitialStartPositionMs()
    this.initialStartHandledByLoad = initialStartPositionMs !== undefined
    const startPositionSeconds = initialStartPositionMs !== undefined && initialStartPositionMs > 0 ?
      initialStartPositionMs / 1000 : undefined
    const initialSubtitleTrackId = this.getInitialSubtitleTrackId()
    // Surface decode failures can happen immediately after load. Register first so
    // native fallback notifications cannot be lost during decoder startup.
    this.registerPlaybackCompleteListener(pathStack!)
    this.registerSurfaceModeErrorCallback()
    this.engineAdapter.load(playUrl, startPositionSeconds, initialSubtitleTrackId,
      this.nowPlaying?.network_user_agent)
    this.applySubtitleStyle()

    if (!ToolsUtil.isNetworkUrl(url!)) {
      VideoOperateUtil.getFrameTimePreprocess(url!)
    }

    // 延迟应用 shader，避免编译期间阻塞主线程（shader 编译持有 mpv 核心锁）
    const shaderMode = Setting.mpvShaderMode
    salmonLogger.addLog(TAG, `[MpvController] shader mode=${shaderMode}, will apply=${shaderMode > 0}`, false)
    if (shaderMode > 0) {
      setTimeout(() => {
        salmonLogger.addLog(TAG, `[MpvController] applying shader mode=${shaderMode}`, false)
        this.applyShaderMode(shaderMode)
      }, 3000)
    }

    this.setPlayerCallback(pathStack!)
    await this.getData()

    this.schedulePostLoadTasks()
  }

  setOsdSurface(surfaceId: string, surfaceWidth: number, surfaceHeight: number): void {
    mpvSetOsdSurface(surfaceId, surfaceWidth, surfaceHeight)
  }

  // OSD 始终按 XComponent 的实际 Surface 像素尺寸渲染，避免 4K/8K
  // 视频触发同分辨率 BGRA 全帧绘制和复制。
  syncOsdSurfaceSize(): void {
    if (!this.osdSurfaceId || this.osdSurfaceWidth <= 0 || this.osdSurfaceHeight <= 0) {
      return
    }
    this.setOsdSurface(this.osdSurfaceId, this.osdSurfaceWidth, this.osdSurfaceHeight)
  }

  setPlayerCallback(pathStack: NavPathStack, _xComponentController?: XComponentController,
    _windowClass?: Promise<window.Window | undefined>) {
    this.userListener = new BaseListener<number>()
    this.userListener.on('timeUpdate', (duration: number) => {
      const now = Date.now()
      if (now - this.lastAppStorageUpdateTime >= 200) {
        this.lastAppStorageUpdateTime = now
        AppStorage.setOrCreate('nowPlayingData',
          [this.playTime, this.nowPlaying!, this.skipHistory])
      }
      if (this.showControl) {
        if (!VideoOperateUtil.autoHideTimeout) {
          VideoOperateUtil.autoHideTimeout = true
          setTimeout(() => {
            this.lockVisibility = false
            this.showControl = false
            VideoOperateUtil.autoHideTimeout = false
          }, AUTO_HIDE_SHOW_CONTROL_TIME)
        }
      }
      // 片尾跳过逻辑保留
      const totalTime = this.nowPlaying?.time ?? 0
      const startTime = this.nowPlaying?.start_time
      const endTime = this.nowPlaying?.end_time
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
          ToolsUtil.showToast('已跳过片尾')
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

  async getData(): Promise<void> {
    this.transitionTo(MpvPlayerState.PLAYING)
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
    mpvSeek(this.mpvHandle, (this.playTime - Number(Setting.fastForwardSeconds) * 1000) / 1000, true)
  }

  fastForward(): void {
    if (!this.mpvHandle) {
      return
    }
    mpvSeek(this.mpvHandle, (this.playTime + Number(Setting.fastForwardSeconds) * 1000) / 1000, true)
  }

  prepare(): void {
    this.smartRotationAllowed = true
    this.create().catch(() => {
      salmonLogger.addLog(TAG, 'prepare create failed', true)
    })
  }

  play(): void {
    if (!this.mpvHandle) {
      return
    }
    PiPWindowUtil.enableAutoStart()
    this.transitionTo(MpvPlayerState.PLAYING)
    mpvPlay(this.mpvHandle)
    AVSessionUtil.updatePlaybackSessionState(this.playing, this.playTime, this.repeatMode)
    this.reactivateAudioSessionIfNeeded()
  }

  pause(): void {
    if (!this.mpvHandle) {
      return
    }
    PiPWindowUtil.disableAutoStart()
    this.transitionTo(MpvPlayerState.PAUSED)
    mpvPause(this.mpvHandle)
    AVSessionUtil.updatePlaybackSessionState(this.playing, this.playTime, this.repeatMode)
  }

  async reset(): Promise<void> {
    this.engineAdapter.reset()
    await this.getData()
  }

  async release(): Promise<void> {
    this.transitionTo(MpvPlayerState.RELEASING)
    this.cancelDecodingModeTimers()
    this.cancelSubscribe()
    if (!this.engineAdapter.isCreated()) {
      await this.engineAdapter.release()
      this.transitionTo(MpvPlayerState.IDLE)
      return
    }
    await this.engineAdapter.release(() => {
      this.unregisterNativeCallbacks()
      this.userListener?.off('timeUpdate')
    })
    this.transitionTo(MpvPlayerState.IDLE)
  }

  cancelSubscribe(): void {
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
    mpvSeek(this.mpvHandle, seekTime / 1000, true)
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
    mpvSetSpeed(this.mpvHandle, speed)
    this.speed = speed
  }

  getDuration(): number {
    const totalTime = mpvGetDuration(this.mpvHandle) as number
    if (totalTime === 0) {
      return this.nowPlaying!.time
    }
    if (this.nowPlaying?.time === 0 || this.nowPlaying?.time !== totalTime) {
      this.nowPlaying!.time = totalTime
      VideoOperateUtil.saveVideoTotalTime(PathUtils.appContext!, this.nowPlaying!)
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

  async getAudioTrackList(): Promise<void> {
    const tracks = mpvGetAudioTracks(this.mpvHandle) as MpvAudioTrack[]
    if (!tracks || tracks.length === 0) {
      setTimeout(() => {
        const retryTracks = mpvGetAudioTracks(this.mpvHandle) as MpvAudioTrack[]
        if (retryTracks && retryTracks.length > 0) {
          this.audioTrack = retryTracks
          this.restoreAudioTrackPreference()
          salmonLogger.addLog(TAG, `重试获取音轨成功，共 ${retryTracks.length} 条音轨`, false)
        } else {
          this.audioTrack = retryTracks || []
          salmonLogger.addLog(TAG, "重试获取音轨仍然失败，可能文件没有音轨", false)
        }
      }, 1000)
    } else {
      this.audioTrack = tracks
      this.restoreAudioTrackPreference()
      salmonLogger.addLog(TAG, `获取音轨成功，共 ${tracks.length} 条音轨`, false)
    }
  }

  selectAudioTrack(trackId: number): void {
    mpvSelectAudio(this.mpvHandle, trackId)
    this.resetAudioChannelMode()
  }

  selectAudioTrackByIndex(index: number): void {
    if (index >= 0 && index < this.audioTrack.length) {
      this.selectAudioTrack(this.audioTrack[index].id)
    }
  }

  getAudioTrackCount(): number {
    return this.audioTrack.length
  }

  restoreAudioTrackPreference(): void {
    if (!this.nowPlaying || this.audioTrack.length <= 1) {
      return
    }
    const audioTrackId = this.nowPlaying.audio_track_id
    if (audioTrackId !== undefined && audioTrackId > 0 && audioTrackId < this.audioTrack.length) {
      this.selectAudioTrack(this.audioTrack[audioTrackId].id)
      this.audioTrackSelected = audioTrackId
    }
  }

  setLoudnessGain(loudnessGain: number) {
    this.volumeLoudnessGain = loudnessGain
    if (this.mpvHandle) {
      mpvSetLoudnessGain(this.mpvHandle, loudnessGain)
    }
  }

  setAudioChannelMode(mode: MpvAudioChannelMode) {
    this.audioChannelMode = mode
    if (this.mpvHandle) {
      mpvSetAudioChannel(this.mpvHandle, mode)
    }
  }

  resetAudioChannelMode() {
    this.audioChannelMode = MpvAudioChannelMode.STEREO
    if (this.mpvHandle) {
      mpvSetAudioChannel(this.mpvHandle, MpvAudioChannelMode.STEREO)
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
    mpvSeek(this.mpvHandle, timeSeconds, true)
  }

  applyShaderMode(mode: number) {
    if (!this.mpvHandle) {
      return
    }
    if (mode > 0 && (Setting.mpvDecodingMethod === MpvDecodingMethod.HARDWARE_SURFACE ||
      Setting.mpvDecodingMethod === MpvDecodingMethod.SOFTWARE)) {
      Setting.mpvShaderMode = 0
      mpvSetGlslShaders([])
      return
    }
    if (mode === 0) {
      mpvSetGlslShaders([])
      return
    }
    const config = MpvController.SHADER_CONFIGS.get(mode)
    if (!config) {
      return
    }
    const sandboxDir = PathUtils.sandboxPath + '/shaders/'
    try {
      fileIo.mkdirSync(sandboxDir)
    } catch (_) {
    }
    let shaderPaths: string[] = []
    for (const file of config.files) {
      const targetPath = sandboxDir + file
      try {
        const content = PathUtils.appContext!.resourceManager.getRawFileContentSync(config.rawDir + '/' + file)
        const targetFd =
          fileIo.openSync(targetPath, fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC | fileIo.OpenMode.READ_WRITE)
        fileIo.writeSync(targetFd.fd, content.buffer)
        fileIo.closeSync(targetFd)
        shaderPaths.push(targetPath!)
      } catch (e) {
        salmonLogger.addLog(TAG, `Shader copy failed: ${file} ${e}`, true)
      }
    }
    if (shaderPaths.length > 0) {
      const result = mpvSetGlslShaders(shaderPaths)
      if (result) {
        ToolsUtil.showToast(`已启用${MpvController.SHADER_MODE_NAMES[mode]}`)
      } else {
        ToolsUtil.showToast('Shader 加载失败，请确认使用 Buffer 硬解模式')
      }
    } else {
      ToolsUtil.showToast('Shader 文件拷贝失败')
    }
  }

  toggleDebugInfo() {
    this.debugInfoVisible = !this.debugInfoVisible
    mpvSetOsdLevel(this.debugInfoVisible ? 3 : 1)
  }

  async getSubtitleTrackList(): Promise<void> {
    const allSubtitleTracks = mpvGetSubtitleTracks(this.mpvHandle) as MpvSubtitleTrack[]
    const externalTracks = allSubtitleTracks.filter((track: MpvSubtitleTrack) => track.external)
    if (externalTracks.length > 0) {
      const selectedExternalTrack = externalTracks.find((track: MpvSubtitleTrack) =>
        track.id === this.externalSubtitleTrackSelected) ?? externalTracks[externalTracks.length - 1]
      this.externalSubtitleTrackSelected = selectedExternalTrack.id
      this.externalSubtitleCodec = selectedExternalTrack.codec ?? ''
    } else {
      this.externalSubtitleTrackSelected = -1
      this.externalSubtitleCodec = ''
    }
    this.subtitleTrack = allSubtitleTracks.filter((track: MpvSubtitleTrack) => !track.external)
    if (this.subtitleTrack.length === 0) {
      this.subtitleTrackSelected = -1
      this.secondarySubtitleTrackSelected = -1
      return
    }

    const previousTrackId = this.subtitleTrackSelected
    const currentTrackId = mpvGetCurrentSubtitleTrack(this.mpvHandle)
    const hasCurrentTrack = this.subtitleTrack.some((track) => track.id === currentTrackId)
    const hasPreviousTrack = this.subtitleTrack.some((track) => track.id === previousTrackId)
    this.subtitleTrackSelected = hasCurrentTrack ? currentTrackId :
      (hasPreviousTrack ? previousTrackId : this.subtitleTrack[0].id)
    const currentSecondaryTrackId = mpvGetCurrentSecondarySubtitleTrack(this.mpvHandle)
    const hasCurrentSecondaryTrack = this.subtitleTrack.some((track) =>
      track.id === currentSecondaryTrackId && track.id !== this.subtitleTrackSelected)
    this.secondarySubtitleTrackSelected = hasCurrentSecondaryTrack ? currentSecondaryTrackId : -1
    if (currentSecondaryTrackId >= 0 && !hasCurrentSecondaryTrack) {
      mpvSelectSecondarySubtitle(this.mpvHandle, -1)
    }
  }

  selectSubtitleTrack(trackId: number): void {
    if (trackId >= 0 && trackId === this.secondarySubtitleTrackSelected) {
      this.selectSecondarySubtitleTrack(-1)
    }
    this.subtitleTrackSelected = trackId
    mpvSelectSubtitle(this.mpvHandle, trackId)
    this.applySubtitleStyle()
    this.updateMpvSubtitlePresentation()
  }

  selectExternalSubtitleTrack(): void {
    this.selectSecondarySubtitleTrack(-1)
    mpvSelectSubtitle(this.mpvHandle, this.externalSubtitleTrackSelected)
    this.applySubtitleStyle()
    this.updateMpvSubtitlePresentation()
  }

  selectSecondarySubtitleTrack(trackId: number): void {
    if (trackId >= 0 && trackId === this.subtitleTrackSelected) {
      return
    }
    this.secondarySubtitleTrackSelected = trackId
    mpvSelectSecondarySubtitle(this.mpvHandle, trackId)
    this.applySubtitleStyle()
    this.updateMpvSubtitlePresentation()
  }

  setRotation() {
    // 这里需要有个默认值，否则会视频宽高为0，导致视频无法播放
    let VideoWidth = this.getPlayAreaWidth() === 0 ? 1999 : this.getPlayAreaWidth()
    let VideoHeight = this.getPlayAreaHeight() === 0 ? 1999 : this.getPlayAreaHeight()
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
    if (this.nowPlaying?.size[0] === 0 && VideoWidth !== 0 && VideoHeight !== 1999) {
      this.nowPlaying!.size[0] = VideoWidth
      this.nowPlaying!.size[1] = VideoHeight
      VideoOperateUtil.saveVideoWeightAndHeight(PathUtils.appContext!, this.nowPlaying)
    }
    this.applyScreenExtend()
    this.applySubtitleStyle()
    PiPWindowUtil.updateContentSize()
  }

  setKeepAspectStatus(keepAspect: boolean) {
    mpvSetKeepAspect(this.mpvHandle, keepAspect)
  }

  setSessionListener() {
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
      this.avSession?.on('outputDeviceChange', () => {
        this.pause()
      })
      this.avSession?.on('setLoopMode', (mode: avSession.LoopMode) => {
        this.repeatMode = AVSessionUtil.getRepeatModeFromAvSession(mode)
        this.repeatMode = VideoOperateUtil.getRepeatMode(this.repeatMode)
        AVSessionUtil.updatePlaybackSessionState(this.playing, this.playTime, this.repeatMode)
      })
    } catch (error) {
      salmonLogger.addLog(TAG, 'set avSession state error', true)
    }
  }

  async initAVSession() {
    AVSessionUtil.applyAudioConcurrencyMode()
    this.registerAudioInterruptListener()
    if (Setting.allowBackgroundPlay) {
      this.avSession = await AVSessionUtil.getAVSession()
      this.setSessionListener()
      await AVSessionUtil.setSessionInfo(this.nowPlaying!)
      const initialPosition = this.playTime > 0 ? this.playTime :
        (this.nowPlaying?.last_play || 0)
      AVSessionUtil.updatePlaybackSessionState(this.playing, initialPosition, this.repeatMode)
    }
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
    let swipingVoiceTimer: number | null = null
    let changeVolumeByVolumeButton: boolean = false
    try {
      this.audioVolumeManager.on('streamVolumeChange', audio.StreamUsage.STREAM_USAGE_MOVIE,
        (streamVolumeEvent: audio.StreamVolumeEvent) => {
          clearTimeout(swipingVoiceTimer)
          if (!this.onSwipingVoice) {
            this.onSwipingVoice = !this.onSwipingVoice
            changeVolumeByVolumeButton = true
          }
          this.volumeActually = streamVolumeEvent.volume
          ToolsUtil.startVibration()
          swipingVoiceTimer = setTimeout(() => {
            if (changeVolumeByVolumeButton) {
              this.onSwipingVoice = !this.onSwipingVoice
              changeVolumeByVolumeButton = false
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

  onScreenDoubleClick(tapX: number) {
    if (!Setting.allowDoubleFastForward) { // 非双击快进模式时执行暂停
      this.togglePlayback()
      return
    }
    const zoneWidth = this.screenWidth / SCREEN_DIVISIONS
    if (tapX < zoneWidth * LEFT_ZONE_DIVISION) {
      this.backForward()
      return
    }
    if (tapX > zoneWidth * RIGHT_ZONE_DIVISION) {
      this.fastForward()
      return
    }
    this.togglePlayback()
  }

  async setExternalSubtitle(nowPlaying: VideoMetadata) {
    SubtitleUtil.offsetMillis = nowPlaying.subtitle_offset_millis ?? 0
    let externalSubtitleLoaded = false
    this.externalSubtitleTrackSelected = -1
    this.externalSubtitleCodec = ''
    this.subtitle = ''
    this.lastSubtitle = ''
    if (await SubtitleUtil.isSubtitleExist(PathUtils.subtitlePath!, nowPlaying.date!)) {
      try {
        const existingExternalTrackIds = (mpvGetSubtitleTracks(this.mpvHandle) as MpvSubtitleTrack[])
          .filter((track: MpvSubtitleTrack) => track.external)
          .map((track: MpvSubtitleTrack) => track.id)
        let subtitle = fileIo.openSync(PathUtils.subtitlePath! + nowPlaying.date, fileIo.OpenMode.READ_ONLY)
        externalSubtitleLoaded = mpvLoadExternalSubtitle(this.mpvHandle, {
          path: subtitle.path,
          lang: 'unknown',
          select: false
        })
        try {
          fileIo.closeSync(subtitle)
        } catch (_e) {
        }
        if (externalSubtitleLoaded) {
          const updatedTracks = mpvGetSubtitleTracks(this.mpvHandle) as MpvSubtitleTrack[]
          const addedTrack = updatedTracks.filter((track: MpvSubtitleTrack) => track.external &&
            !existingExternalTrackIds.includes(track.id)).pop()
          if (addedTrack) {
            this.externalSubtitleTrackSelected = addedTrack.id
            this.externalSubtitleCodec = addedTrack.codec ?? ''
          }
          await this.getSubtitleTrackList()
        }
      } catch (_error) {
      }
    }

    const hasPreference = SubtitleUtil.hasSubtitlePreferenceMetadata(nowPlaying)
    if (hasPreference) {
      const preferredMode = nowPlaying.subtitle_mode as SubtitleMode | undefined
      if (preferredMode === SubtitleMode.EXTERNAL_SUBTITLE && !externalSubtitleLoaded) {
        this.subtitleSelected = SubtitleMode.NONE
        this.resetSubtitlePreference(nowPlaying)
        SubtitleUtil.offsetMillis = 0

      } else if (preferredMode !== undefined && preferredMode >= SubtitleMode.NONE) {
        if (preferredMode === SubtitleMode.INNER_SUBTITLE && this.subtitleTrack.length === 0) {
          this.subtitleSelected = SubtitleMode.NONE
        } else {
          if (preferredMode === SubtitleMode.INNER_SUBTITLE && nowPlaying.subtitle_track_id !== undefined &&
            this.subtitleTrack.some((track: MpvSubtitleTrack) => track.id === nowPlaying.subtitle_track_id)) {
            this.subtitleTrackSelected = nowPlaying.subtitle_track_id
            if (mpvGetCurrentSubtitleTrack(this.mpvHandle) !== nowPlaying.subtitle_track_id) {
              mpvSelectSubtitle(this.mpvHandle, nowPlaying.subtitle_track_id)
            }
          }
          if (nowPlaying.subtitle_offset_millis !== undefined) {
            SubtitleUtil.offsetMillis = nowPlaying.subtitle_offset_millis
          }
          this.subtitleSelected = preferredMode
        }
      } else {
        this.subtitleSelected = SubtitleMode.NONE
      }
    } else {
      this.subtitleSelected = externalSubtitleLoaded ? SubtitleMode.EXTERNAL_SUBTITLE : SubtitleMode.NONE
    }
    if (this.subtitleSelected === SubtitleMode.EXTERNAL_SUBTITLE) {
      this.selectExternalSubtitleTrack()
    } else if (this.subtitleSelected === SubtitleMode.INNER_SUBTITLE && this.subtitleTrackSelected >= 0) {
      this.selectSubtitleTrack(this.subtitleTrackSelected)
    } else {
      mpvSelectSubtitle(this.mpvHandle, -1)
      this.selectSecondarySubtitleTrack(-1)
    }
    this.setSubtitleOffset(SubtitleUtil.offsetMillis)
    this.applySubtitleStyle()
    const saved3DMode = nowPlaying.subtitle_3d_mode
    this.setSubtitle3DMode(saved3DMode !== undefined &&
      [Subtitle3DMode.DISABLED, Subtitle3DMode.SIDE_BY_SIDE, Subtitle3DMode.TOP_AND_BOTTOM].includes(saved3DMode) ?
      saved3DMode as Subtitle3DMode : Subtitle3DMode.DISABLED)
  }

  refreshExternalSubtitlePreview(_offset: number): void {
    // MPV applies the delay directly while rendering the external subtitle.
  }

  setSubtitleOffset(offsetMillis: number): void {
    const clampedOffset = Math.max(-50000, Math.min(50000, Math.round(offsetMillis)))
    if (this.mpvHandle) {
      mpvSetSubtitleDelay(this.mpvHandle, clampedOffset)
    }
    this.refreshExternalSubtitlePreview(clampedOffset)
  }

  setSubtitle3DMode(mode: Subtitle3DMode): void {
    const canUseMpv3D = mode !== Subtitle3DMode.DISABLED &&
      this.subtitleSelected === SubtitleMode.INNER_SUBTITLE && this.supportsSubtitle3D()
    this.mpvSubtitle3DMode = canUseMpv3D ? mode : Subtitle3DMode.DISABLED
    this.updateMpvSubtitlePresentation()
  }

  supportsSubtitle3D(): boolean {
    if (this.subtitleSelected === SubtitleMode.EXTERNAL_SUBTITLE) {
      return true
    }
    const primaryTrack = this.subtitleTrack.find((track: MpvSubtitleTrack) =>
      track.id === this.subtitleTrackSelected)
    if (!primaryTrack || this.isBitmapSubtitleTrack(primaryTrack)) {
      return false
    }
    if (this.secondarySubtitleTrackSelected >= 0) {
      const secondaryTrack = this.subtitleTrack.find((track: MpvSubtitleTrack) =>
        track.id === this.secondarySubtitleTrackSelected)
      return secondaryTrack !== undefined && !this.isBitmapSubtitleTrack(secondaryTrack)
    }
    return true
  }

  refreshExternalSubtitleByPlaybackTime(_isAdjustingSubtitleOffset: boolean,
    _subtitleVisibility: Visibility): void {
    // MPV owns cue timing and rendering for external subtitles.
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
    VideoOperateUtil.saveSubtitlePreference(
      this.nowPlaying, this.subtitleSelected, this.subtitleTrackSelected,
      subtitleVisibility, isAIAsrShown, subtitle3DMode
    )
  }

  cancelSmartRotationTimer() {
    if (this.smartRotationTimer) {
      clearTimeout(this.smartRotationTimer)
      this.smartRotationTimer = 0
    }
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
    PermissionUtil.activatePermission(this.nowPlaying?.uri)
    try {
      this.surfaceId = xComponentController.getXComponentSurfaceId()
      await this.prepareInitialSmartRotation()
      await this.init(this.nowPlaying!.uri, pathStack)
      await this.initAVSession()
      await PiPWindowUtil.createPipController(xComponentController, this)
    } catch (error) {
      salmonLogger.addLog(TAG, 'uri error:' + error, true)
    }
  }

  onOsdSurfaceLoad(surfaceId: string, surfaceWidth: number, surfaceHeight: number): void {
    this.osdSurfaceId = surfaceId
    this.osdSurfaceWidth = surfaceWidth
    this.osdSurfaceHeight = surfaceHeight
    this.syncOsdSurfaceSize()
  }

  setSubtitlePosition(position: number): void {
    this.subtitlePosition = Math.max(5, Math.min(100, Math.round(position)))
    this.applySubtitleStyle()
  }

  setSubtitleSize(size: number): void {
    this.subtitleSize = Math.max(14, Math.min(48, Math.round(size)))
    this.applySubtitleStyle()
  }

  restoreSpeedAfterLongPress(lastSpeed: number): void {
    this.speed = lastSpeed
    this.updatePlaybackSpeed(this.speed)
  }

  async restoreSystemBars(_windowClass?: Promise<window.Window | undefined>): Promise<void> {
    WindowUtil.setBarState(PathUtils.appContext!, true, true)
  }

  onWillDisappearCleanup(): void {
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

  private preparePlayUrl(url: string): string {
    if (ToolsUtil.isNetworkUrl(url)) {
      return url
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
      if (!targetWindow || !this.smartRotationAllowed) {
        return
      }
      await targetWindow.setPreferredOrientation(orientation)
      this.initialSmartRotationRequested = true
      salmonLogger.addLog(TAG, '已在 loadfile 前请求智能横屏', false)
    } catch (error) {
      salmonLogger.addLog(TAG, `起播前设置窗口方向失败: ${error}`, true)
    }
  }

  private schedulePostLoadTasks() {
    this.postLoadTasksExecuted = false
    this.userListener?.on('videoSizeReady', (_data: number) => {
      if (this.postLoadTasksExecuted) {
        return
      }
      this.executePostLoadTasks()
    })
    this.smartRotationTimer = setTimeout(() => {
      if (!this.postLoadTasksExecuted) {
        this.executePostLoadTasks()
      }
    }, 1500) as number
  }

  private async executePostLoadTasks() {
    if (this.postLoadTasksExecuted || !this.smartRotationAllowed) {
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
    this.checkDolbyVisionAndSwitch()
    this.detectAndUpdateHdrType()
    await Promise.all([
      this.getAudioTrackList(),
      this.getSubtitleTrackList()
    ])
    this.getChapterListFromMpv()
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
      (await this.windowClass)?.setPreferredOrientation(orientation)?.catch(() => {
        salmonLogger.addLog(TAG, "设置窗口方向失败", true)
      })
    }
    this.onSwiping = false
    this.isSliderPlayTimeChange = false
    if (Setting.mpvDecodingMethod === MpvDecodingMethod.HARDWARE_SURFACE && !this.osdVisibility) {
      this.osdVisibility = true
    }
    await this.setExternalSubtitle(this.nowPlaying!)
    if (this.initialPlaying === false) {
      this.pause()
    }
    this.initialPlaying = undefined
  }

  private applyScreenExtend() {
    const size = VideoOperateUtil.calcScreenExtendSize(this.selectedText, this.screenWidth, this.screenHeight)
    if (size) {
      this.playAreaWidth = size[0]
      this.playAreaHeight = size[1]
    }
  }

  private resetSubtitlePreference(nowPlaying: VideoMetadata): void {
    nowPlaying.subtitle_mode = SubtitleMode.NONE
    nowPlaying.subtitle_visible = false
    nowPlaying.subtitle_ai_asr_shown = false
    nowPlaying.subtitle_3d_mode = Subtitle3DMode.DISABLED
    nowPlaying.subtitle_offset_millis = 0
    nowPlaying.subtitle_track_id = -1
    SelectFileUtil.saveData(PathUtils.appContext!, nowPlaying, {
      subtitleMode: SubtitleMode.NONE,
      subtitleVisible: false,
      subtitleAIAsrShown: false,
      subtitle3DMode: Subtitle3DMode.DISABLED,
      subtitleOffsetMillis: 0,
      subtitleTrackId: -1
    })
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
    if (this.nowPlaying && SUPPORT_AUDIO_FORMAT.includes(this.nowPlaying.format.toLowerCase())) {
      decodeType = MpvDecodingMethod.HARDWARE_BUFFER

    }
    return decodeType
  }

  private applyDecodeType(): void {
    const decodeType = this.computeDecodeType()
    mpvSetGpuApi(Setting.mpvGpuApi)
    if (decodeType === MpvDecodingMethod.HARDWARE_BUFFER &&
      this.nowPlaying && SUPPORT_AUDIO_FORMAT.includes(this.nowPlaying.format.toLowerCase())) {
      salmonLogger.addLog(TAG, '[MpvPlayer] Audio file detected, using Buffer hardware decode mode')
    }
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
        if (!this.onSwiping) {
          ThrottleUtil.throttle('playTime', () => {
            this.playTime = timeMs
          }, 100)
        }
        this.userListener?.emit('timeUpdate', this.playTime)
        ThrottleUtil.throttle('avSessionPosition', () => {
          AVSessionUtil.updatePlaybackSessionState(this.playing, this.playTime, this.repeatMode)
        }, 1000)
        if (this.mpvSubtitle3DMode !== Subtitle3DMode.DISABLED &&
          this.subtitleSelected === SubtitleMode.INNER_SUBTITLE) {
          ThrottleUtil.throttle('mpv3DSubtitleText', () => {
            this.refreshMpv3DSubtitleText()
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
        this.completeDecodingModeVerificationOnVideoSize()
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
            this.windowClass?.then(w => w?.setPreferredOrientation(orientation)?.catch(() => {
            }))
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
      mpvRegisterPlaybackCompleteCallback(() => {
        if (this.isInState(MpvPlayerState.SWITCHING_MODE) || this.isInState(MpvPlayerState.RELEASING)) {
          salmonLogger.addLog(TAG,
            `[MpvController] Ignoring playback complete: state=${this.playerState}, mode switch in progress`,
            true)
          return
        }
        const duration = this.getDuration()
        const minPlayTime = Math.min(duration * 0.5, 5000)
        if (this.playTime < minPlayTime && duration > 0) {
          salmonLogger.addLog(TAG,
            `[MpvController] Ignoring playback complete: playTime=${this.playTime}ms < minPlayTime=${minPlayTime}ms, likely decode error`,
            true)
          return
        }
        if (duration > 0 && this.playTime < duration * 0.95) {
          salmonLogger.addLog(TAG,
            `[MpvController] Ignoring playback complete: playTime=${this.playTime}ms < 95% of duration=${duration}ms, likely premature EOF`,
            true)
          ToolsUtil.showToast('视频文件可能未下载完整或已损坏，请检查文件完整性')
          return
        }
        salmonLogger.addLog(TAG, "收到播放完成事件，准备播放下一个视频", false)
        this.transitionTo(MpvPlayerState.COMPLETED)
        this.playTime = this.nowPlaying?.time || this.playTime
        if (!this.skipHistory) {
          const completedPlayTime = this.nowPlaying!.time || this.playTime
          salmonLogger.addLog(TAG,
            `播放完成，保存进度: playTime=${this.playTime}, totalTime=${this.nowPlaying!.time}, savedTime=${completedPlayTime}`,
            false)
          VideoOperateUtil.saveVideoTime(completedPlayTime, this.nowPlaying!, PathUtils.appContext!)
        }
        this.playNextVideoProcess(pathStack).catch((error: Error) => {
          salmonLogger.addLog(TAG, `play next video failed: ${error.message}`, true)
        })
        this.playbackCallbackRegistered = false
        this.registerPlaybackCompleteListener(pathStack)
      })
      this.playbackCallbackRegistered = true
      salmonLogger.addLog(TAG, "播放完成监听器注册成功", false)
    } catch (error) {
      salmonLogger.addLog(TAG, "播放完成监听器注册失败: " + JSON.stringify(error), true)
    }
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
        this.switchToBufferMode(errorMessage)
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
        if (this.isInState(MpvPlayerState.RELEASING) || this.isInState(MpvPlayerState.IDLE)) {
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
        if (this.isInState(MpvPlayerState.RELEASING) || this.isInState(MpvPlayerState.IDLE)) {
          return
        }
        if (paused && this.isInState(MpvPlayerState.PLAYING)) {
          salmonLogger.addLog(TAG, '[MpvController] mpv pause property changed to true (external interruption)', false)
          this.transitionTo(MpvPlayerState.PAUSED)
        } else if (!paused && this.isInState(MpvPlayerState.PAUSED)) {
          this.transitionTo(MpvPlayerState.PLAYING)
        }
      })
      this.pauseStateCallbackRegistered = true
    } catch (error) {
      salmonLogger.addLog(TAG, 'Failed to register pause state callback', error)
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
        if (this.isInState(MpvPlayerState.RELEASING) || this.isInState(MpvPlayerState.IDLE)) {
          return
        }
        salmonLogger.addLog(TAG,
          `[MpvController] AudioSession deactivated, reason: ${deactivatedEvent.reason}, pausing`, false)
        this.pause()
      })
      sessionManager.on('audioSessionStateChanged', (stateChangedEvent: audio.AudioSessionStateChangedEvent) => {
        if (this.isInState(MpvPlayerState.RELEASING) || this.isInState(MpvPlayerState.IDLE)) {
          return
        }
        switch (stateChangedEvent.stateChangeHint) {
          case audio.AudioSessionStateChangeHint.AUDIO_SESSION_STATE_CHANGE_HINT_RESUME:
            if (this.isInState(MpvPlayerState.PAUSED)) {
              salmonLogger.addLog(TAG, '[MpvController] AudioSession focus restored, reactivating and resuming', false)
              const strategy: audio.AudioSessionStrategy = {
                concurrencyMode: Setting.allowConcurrentPlay ?
                  audio.AudioConcurrencyMode.CONCURRENCY_MIX_WITH_OTHERS :
                  audio.AudioConcurrencyMode.CONCURRENCY_DEFAULT
              }
              sessionManager.activateAudioSession(strategy).then(() => {
                this.play()
              }).catch((err: BusinessError) => {
                salmonLogger.addLog(TAG, `reactivateAudioSession error: ${err.code} ${err.message}`, true)
              })
            }
            break
          case audio.AudioSessionStateChangeHint.AUDIO_SESSION_STATE_CHANGE_HINT_PAUSE:
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
    this.cancelDecodingModeVerification()

    const savedTime = currentTime ?? 0
    const savedPlaying = wasPlaying ?? this.playing

    this.transitionTo(MpvPlayerState.SWITCHING_MODE)

    const modeName = targetMode === 'buffer_hw' ? 'Buffer硬件解码' : '软件解码'
    salmonLogger.addLog(TAG, `[MpvController] Switching to ${modeName} mode due to error: ${errorMessage}`, true)
    ToolsUtil.showToast(`正在切换到${modeName}模式...`)
    const savedVideo = currentVideo ?? this.nowPlaying

    this.cleanupMpvInstance()
    mpvSetGpuApi(Setting.mpvGpuApi)

    if (targetMode === 'buffer_hw') {
      mpvSetDecodeType(0)
      mpvSetHwdecMode(0)
    } else {
      mpvSetDecodeType(1)
      mpvSetHwdecMode(0)
    }

    this.engineAdapter.create()
    if (!this.mpvHandle) {
      salmonLogger.addLog(TAG, `[MpvController] Failed to create MPV instance in ${modeName} mode`, true)

      if (targetMode === 'buffer_hw') {
        this.switchDecodingMode('buffer_sw', 'Buffer硬件解码创建失败', savedTime, savedPlaying, savedVideo)
      } else {
        ToolsUtil.showToast('切换模式失败，请尝试其他视频')
        this.transitionTo(MpvPlayerState.ERROR)
      }
      return
    }

    this.activeHwdecMode = targetMode === 'buffer_hw' ? MpvDecodingMethod.HARDWARE_BUFFER : MpvDecodingMethod.SOFTWARE

    if (savedVideo) {
      this.configureNetworkStateSubscription(savedVideo.uri)
      const reloadUrl = this.preparePlayUrl(savedVideo.uri)
      this.registerSurfaceModeErrorCallback()
      const reloadStartSeconds = savedTime > 0 ? savedTime / 1000 : undefined
      if (reloadStartSeconds !== undefined) {
        this.initialStartHandledByLoad = true
      }
      this.registerVideoSizeChangedCallback()
      this.startDecodingModeVerification(targetMode, savedTime, savedPlaying, savedVideo, modeName)
      this.engineAdapter.load(reloadUrl, reloadStartSeconds, this.getInitialSubtitleTrackId(),
        savedVideo.network_user_agent)
      this.applySubtitleStyle()
      this.getData().catch(() => {
        salmonLogger.addLog(TAG, 'reload callbacks failed', true)
      })

      if (this.currentPathStack) {
        this.registerPlaybackCompleteListener(this.currentPathStack)
      }

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
        this.handleDecodingModeNetworkState(state.speed, state.bufferPercent, state.cacheDuration, state.buffering)
      })
      this.networkStateCallbackRegistered = true
    } catch (error) {
      salmonLogger.addLog(TAG, 'Failed to register network state callback: ' + JSON.stringify(error), true)
    }
  }

  private applySubtitleStyle(): void {
    if (!this.mpvHandle) {
      return
    }
    mpvSetSubtitleStyle(this.mpvHandle,
      SubtitleStyleUtil.getMpvStyle(this.subtitlePosition, this.subtitleSize, this.playAreaHeight,
        this.shouldPreserveCurrentAssStyle(), this.shouldPreserveSecondaryAssStyle()))
  }

  private updateMpvSubtitlePresentation(): void {
    if (!this.mpvHandle) {
      return
    }
    const useArkUi3D = this.mpvSubtitle3DMode !== Subtitle3DMode.DISABLED &&
      this.subtitleSelected === SubtitleMode.INNER_SUBTITLE && this.supportsSubtitle3D()
    if (useArkUi3D) {
      mpvSetSubtitleRenderVisibility(this.mpvHandle, false, false)
      this.refreshMpv3DSubtitleText()
      return
    }

    if (this.mpvSubtitle3DMode !== Subtitle3DMode.DISABLED && !this.supportsSubtitle3D()) {
      this.mpvSubtitle3DMode = Subtitle3DMode.DISABLED
    }
    const showMpvSubtitle = (this.subtitleSelected === SubtitleMode.INNER_SUBTITLE &&
      this.subtitleTrackSelected >= 0) || (this.subtitleSelected === SubtitleMode.EXTERNAL_SUBTITLE &&
      this.externalSubtitleTrackSelected >= 0)
    mpvSetSubtitleRenderVisibility(this.mpvHandle, showMpvSubtitle,
      showMpvSubtitle && this.secondarySubtitleTrackSelected >= 0)
    if (this.subtitleSelected === SubtitleMode.INNER_SUBTITLE ||
      this.subtitleSelected === SubtitleMode.EXTERNAL_SUBTITLE) {
      this.subtitle = ''
      this.lastSubtitle = ''
    }
  }

  private shouldPreserveCurrentAssStyle(): boolean {
    if (this.subtitleSelected === SubtitleMode.EXTERNAL_SUBTITLE) {
      return this.isAssCodec(this.externalSubtitleCodec) ||
        this.isAssCodec(this.nowPlaying?.external_subtitle_format ?? '')
    }
    if (this.subtitleSelected !== SubtitleMode.INNER_SUBTITLE) {
      return false
    }
    const selectedTrack = this.subtitleTrack.find((track: MpvSubtitleTrack) =>
      track.id === this.subtitleTrackSelected)
    return this.isAssCodec(selectedTrack?.codec ?? '')
  }

  private isAssCodec(codec: string): boolean {
    const normalizedCodec = codec.trim().toLowerCase().replace('.', '')
    return normalizedCodec === 'ass' || normalizedCodec === 'ssa'
  }

  private shouldPreserveSecondaryAssStyle(): boolean {
    if (this.subtitleSelected !== SubtitleMode.INNER_SUBTITLE ||
      this.secondarySubtitleTrackSelected < 0) {
      return false
    }
    const selectedTrack = this.subtitleTrack.find((track: MpvSubtitleTrack) =>
      track.id === this.secondarySubtitleTrackSelected)
    return this.isAssCodec(selectedTrack?.codec ?? '')
  }

  private refreshMpv3DSubtitleText(): void {
    if (!this.mpvHandle || this.mpvSubtitle3DMode === Subtitle3DMode.DISABLED) {
      return
    }
    const texts = mpvGetSubtitleTexts(this.mpvHandle) as MpvSubtitleTexts
    const lines: string[] = []
    const secondaryText = texts.secondary?.trim() ?? ''
    const primaryText = texts.primary?.trim() ?? ''
    if (secondaryText.length > 0) {
      lines.push(secondaryText)
    }
    if (primaryText.length > 0) {
      lines.push(primaryText)
    }
    const subtitleText = lines.join('\n')
    if (subtitleText !== this.lastSubtitle) {
      this.lastSubtitle = subtitleText
      this.subtitle = subtitleText
    }
  }

  private isBitmapSubtitleTrack(track: MpvSubtitleTrack): boolean {
    const codec = (track.codec ?? '').toLowerCase()
    return codec.includes('pgs') || codec.includes('dvd_subtitle') ||
      codec.includes('dvb_subtitle') || codec.includes('xsub')
  }

  // 清理MPV实例
  private cleanupMpvInstance() {
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
    this.mpvSubtitle3DMode = Subtitle3DMode.DISABLED
    this.subtitle = ''
    this.lastSubtitle = ''
    this.playbackCallbackRegistered = false
    this.timeUpdateCallbackRegistered = false
    this.videoSizeCallbackRegistered = false
    this.surfaceModeErrorCallbackRegistered = false
    this.bufferingStateCallbackRegistered = false
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
    this.unregisterNativeCallback(() => mpvUnregisterNetworkStateCallback(), 'networkState')
    this.unregisterNativeCallback(() => mpvUnregisterPauseStateCallback(), 'pauseState')
    this.playbackCallbackRegistered = false
    this.timeUpdateCallbackRegistered = false
    this.videoSizeCallbackRegistered = false
    this.surfaceModeErrorCallbackRegistered = false
    this.bufferingStateCallbackRegistered = false
    this.networkStateCallbackRegistered = false
  }

  private unregisterNativeCallback(action: () => void, callbackName: string): void {
    try {
      action()
    } catch (error) {
      salmonLogger.addLog(TAG, `Failed to unregister ${callbackName}: ${error}`, true)
    }
  }

  private startDecodingModeVerification(targetMode: 'buffer_hw' | 'buffer_sw', savedTime: number,
    savedPlaying: boolean, savedVideo: VideoMetadata, modeName: string): void {
    const verification = new DecodingModeVerification(targetMode, savedTime, savedPlaying, savedVideo, modeName,
      this.decodingModeVerifyToken)
    this.pendingDecodingModeVerification = verification
    this.scheduleDecodingModeInactivityTimeout(verification)
    this.completeDecodingModeVerificationOnVideoSize()
  }

  private completeDecodingModeVerificationOnVideoSize(): void {
    const verification = this.pendingDecodingModeVerification
    if (!verification || verification.token !== this.decodingModeVerifyToken ||
      this.getPlayAreaWidth() <= 0 || this.getPlayAreaHeight() <= 0) {
      return
    }
    this.finishDecodingModeVerification(verification)
  }

  private handleDecodingModeNetworkState(speed: number, bufferPercent: number, cacheDuration: number,
    buffering: boolean): void {
    this.completeDecodingModeVerificationOnVideoSize()
    const verification = this.pendingDecodingModeVerification
    if (!verification || !verification.isNetworkStream || verification.token !== this.decodingModeVerifyToken) {
      return
    }
    const hasProgress = speed > 0 || bufferPercent > verification.lastBufferPercent ||
      cacheDuration > verification.lastCacheDuration || buffering !== verification.lastBuffering
    verification.lastNetworkSpeed = speed
    verification.lastBufferPercent = bufferPercent
    verification.lastCacheDuration = cacheDuration
    verification.lastBuffering = buffering
    if (hasProgress) {
      this.scheduleDecodingModeInactivityTimeout(verification)
    }
  }

  private scheduleDecodingModeInactivityTimeout(verification: DecodingModeVerification): void {
    if (this.decodingModeVerifyTimer) {
      clearTimeout(this.decodingModeVerifyTimer)
    }
    const timeout = verification.isNetworkStream ? NETWORK_DECODING_MODE_INACTIVITY_TIMEOUT_MS :
      LOCAL_DECODING_MODE_TIMEOUT_MS
    this.decodingModeVerifyTimer = setTimeout(() => {
      this.decodingModeVerifyTimer = 0
      this.handleDecodingModeInactivityTimeout(verification.token)
    }, timeout)
  }

  private handleDecodingModeInactivityTimeout(verificationToken: number): void {
    const verification = this.pendingDecodingModeVerification
    if (!verification || verification.token !== verificationToken ||
      verificationToken !== this.decodingModeVerifyToken ||
      this.isInState(MpvPlayerState.RELEASING) || this.isInState(MpvPlayerState.IDLE)) {
      return
    }
    if (this.getPlayAreaWidth() > 0 && this.getPlayAreaHeight() > 0) {
      this.finishDecodingModeVerification(verification)
      return
    }
    const isAudioFile = SUPPORT_AUDIO_FORMAT.includes(verification.savedVideo.format.toLowerCase())
    if (isAudioFile) {
      salmonLogger.addLog(TAG,
        `[MpvController] ${verification.modeName} mode: audio file has no video size, treating as success`)
      this.finishDecodingModeVerification(verification)
      return
    }
    if (verification.isNetworkStream) {
      if (verification.targetMode === 'buffer_hw') {
        salmonLogger.addLog(TAG,
          `[MpvController] ${verification.modeName} network stream made no progress; ` +
          'falling back to software decoding without reporting playback failure', true)
        this.switchDecodingMode('buffer_sw', 'Buffer硬件解码串流加载无进展', verification.savedTime,
          verification.savedPlaying, verification.savedVideo)
        return
      }
      salmonLogger.addLog(TAG,
        `[MpvController] ${verification.modeName} network stream made no progress; ` +
        'keeping software playback active and deferring final failure detection to MPV', false)
      this.cancelDecodingModeVerification()
      if (verification.savedPlaying) {
        this.play()
      } else {
        this.transitionTo(MpvPlayerState.PAUSED)
      }
      return
    }
    if (verification.targetMode === 'buffer_hw') {
      this.switchDecodingMode('buffer_sw', 'Buffer硬件解码播放失败', verification.savedTime,
        verification.savedPlaying, verification.savedVideo)
    } else {
      this.cancelDecodingModeVerification()
      ToolsUtil.showToast('播放失败，请尝试其他视频')
      this.transitionTo(MpvPlayerState.ERROR)
    }
  }

  private finishDecodingModeVerification(verification: DecodingModeVerification): void {
    if (verification.token !== this.decodingModeVerifyToken) {
      return
    }
    this.cancelDecodingModeVerification()
    if (verification.savedPlaying) {
      this.play()
    } else {
      this.transitionTo(MpvPlayerState.PAUSED)
    }
    const hardwareDecoder = verification.targetMode === 'buffer_hw' ? mpvGetHardwareDecoder(this.mpvHandle) : 'no'
    if (verification.targetMode === 'buffer_hw' && hardwareDecoder === 'no') {
      ToolsUtil.showToast('当前视频不支持硬件解码，已自动回退到软件解码')
      salmonLogger.addLog(TAG, '[MpvController] Hardware decoding unavailable, fell back to software decoding', true)
    } else {
      ToolsUtil.showToast(`已成功切换到${verification.modeName}模式`)
    }
    salmonLogger.addLog(TAG, `[MpvController] Successfully switched to ${verification.modeName} mode`)
  }

  private cancelDecodingModeTimers() {
    this.cancelDecodingModeVerification()
    this.cancelSmartRotationTimer()
  }

  private cancelDecodingModeVerification(): void {
    if (this.decodingModeVerifyTimer) {
      clearTimeout(this.decodingModeVerifyTimer)
      this.decodingModeVerifyTimer = 0
    }
    this.pendingDecodingModeVerification = undefined
    this.decodingModeVerifyToken++
  }

  private checkDolbyVisionAndSwitch() {
    if (!this.mpvHandle) {
      return
    }
    try {
      const profile = mpvGetDolbyVisionProfile(this.mpvHandle)

      if (profile === 5) {
        salmonLogger.addLog(TAG, '[MpvController] Detected Dolby Vision Profile 5', false)
        if (this.activeHwdecMode !== MpvDecodingMethod.HARDWARE_BUFFER) {
          salmonLogger.addLog(TAG,
            `[MpvController] DV P5 requires Buffer mode, current mode=${this.activeHwdecMode}, switching...`,
            true)
          this.switchDecodingMode('buffer_hw', '检测到杜比视界 Profile 5，切换到Buffer模式', this.playTime)
        }
      }
    } catch (error) {
      salmonLogger.addLog(TAG, '[MpvController] Failed to detect Dolby Vision profile: ' + JSON.stringify(error), true)
    }
  }

  private switchToBufferMode(errorMessage: string) {
    if (this.isInState(MpvPlayerState.RELEASING) || this.isInState(MpvPlayerState.IDLE)) {
      salmonLogger.addLog(TAG, '[MpvController] Instance released, skipping buffer mode switch', true)
      return
    }
    if (this.activeHwdecMode !== MpvDecodingMethod.HARDWARE_SURFACE) {
      salmonLogger.addLog(TAG, '[MpvController] Not in surface mode, skipping switch')
      return
    }

    let resumeTime = this.playTime
    if (resumeTime <= 0 && this.nowPlaying) {
      if (this.initialStartHandledByLoad) {
        const mode = VideoOperateUtil.getVideoStartPlayTimeMode(this.nowPlaying)
        if (mode === VideoStartTimeMode.SEEK_TO_LAST_PLAY_TIME) {
          const lastPlay = this.nowPlaying.last_play
          if (lastPlay && lastPlay > 0) {
            resumeTime = lastPlay
            salmonLogger.addLog(TAG,
              `[MpvController] playTime=0 on surface error, initial start failed, using last_play=${lastPlay}ms`, false)
          } else {
            resumeTime = 0
            salmonLogger.addLog(TAG,
              '[MpvController] playTime=0 on surface error, no last_play, resume from 0', false)
          }
        } else {
          resumeTime = 0
          salmonLogger.addLog(TAG,
            '[MpvController] playTime=0 on surface error, initial start handled but mode not SEEK_TO_LAST_PLAY_TIME, resume from 0',
            false)
        }
      } else {
        const mode = VideoOperateUtil.getVideoStartPlayTimeMode(this.nowPlaying)
        if (mode === VideoStartTimeMode.SEEK_TO_LAST_PLAY_TIME) {
          const lastPlay = this.nowPlaying.last_play
          if (lastPlay && lastPlay > 0) {
            resumeTime = lastPlay
            salmonLogger.addLog(TAG,
              `[MpvController] playTime=0 on surface error, using last_play=${lastPlay}ms as resume position`, false)
          }
        } else if (mode === VideoStartTimeMode.SEEK_TO_BEGINNING) {
          salmonLogger.addLog(TAG,
            '[MpvController] playTime=0 on surface error, video nearly complete, resume from 0', false)
          resumeTime = 0
        } else if (mode === VideoStartTimeMode.SEEK_TO_START_TIME) {
          resumeTime = Math.max(0, this.nowPlaying.start_time || 0)
          salmonLogger.addLog(TAG,
            `[MpvController] playTime=0 on surface error, seeking to start_time=${resumeTime}ms`, false)
        } else if (mode === VideoStartTimeMode.SEEK_TO_INTRO_TIME) {
          resumeTime = Math.max(0, Number(Setting.skipIntroTime) * 1000)
          salmonLogger.addLog(TAG,
            `[MpvController] playTime=0 on surface error, seeking to intro_time=${resumeTime}ms`, false)
        } else {
          resumeTime = 0
          salmonLogger.addLog(TAG,
            '[MpvController] playTime=0 on surface error, no specific start mode, resume from 0', false)
        }
      }
    }
    this.switchDecodingMode('buffer_hw', errorMessage, resumeTime)
  }

  private detectAndUpdateHdrType() {
    if (!this.mpvHandle || !this.nowPlaying) {
      salmonLogger.addLog(TAG, '[MpvController] detectAndUpdateHdrType skipped: no mpvHandle or nowPlaying', true)
      return
    }
    if (this.nowPlaying.hdr_type === 1) {
      salmonLogger.addLog(TAG, '[MpvController] detectAndUpdateHdrType skipped: current is HDR Vivid', false)
      return
    }
    try {
      const detectedVideoHdr: number = mpvGetVideoHdrType(this.mpvHandle)
      salmonLogger.addLog(TAG,
        `[MpvController] detectAndUpdateHdrType: video_hdr=${detectedVideoHdr}, current=${this.nowPlaying.hdr_type}`,
        false)
      if (detectedVideoHdr !== 0 && detectedVideoHdr !== this.nowPlaying.hdr_type) {
        salmonLogger.addLog(TAG,
          `[MpvController] Updating hdr_type from ${this.nowPlaying.hdr_type} to ${detectedVideoHdr}`, false)
        this.nowPlaying.hdr_type = detectedVideoHdr
        VideoOperateUtil.saveVideoHdrType(PathUtils.appContext!, this.nowPlaying, detectedVideoHdr)
      } else if (detectedVideoHdr === 0 && this.nowPlaying.hdr_type === 0) {
        setTimeout(() => {
          if (!this.mpvHandle || !this.nowPlaying) {
            return
          }
          try {
            const retryHdr: number = mpvGetVideoHdrType(this.mpvHandle)
            salmonLogger.addLog(TAG,
              `[MpvController] detectAndUpdateHdrType retry: video_hdr=${retryHdr}`, false)
            if (retryHdr !== 0 && retryHdr !== this.nowPlaying.hdr_type) {
              this.nowPlaying.hdr_type = retryHdr
              VideoOperateUtil.saveVideoHdrType(PathUtils.appContext!, this.nowPlaying, retryHdr)
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
      salmonLogger.addLog(TAG,
        `[MpvController] detectAndUpdateAudioType: audio_type=${detectedAudio}, current=${this.nowPlaying.audio_type}`,
        false)
      if (this.nowPlaying.audio_type === 3) {
        salmonLogger.addLog(TAG, '[MpvController] detectAndUpdateAudioType skipped: current is AUDIO_VIVID', false)
      } else if (detectedAudio !== 0 && detectedAudio !== this.nowPlaying.audio_type) {
        salmonLogger.addLog(TAG,
          `[MpvController] Updating audio_type from ${this.nowPlaying.audio_type} to ${detectedAudio}`, false)
        this.nowPlaying.audio_type = detectedAudio
        VideoOperateUtil.saveVideoAudioType(PathUtils.appContext!, this.nowPlaying, detectedAudio)
      } else if (detectedAudio === 0 && this.nowPlaying.audio_type === 0) {
        setTimeout(() => {
          if (!this.mpvHandle || !this.nowPlaying) {
            return
          }
          if (this.nowPlaying.audio_type === 3) {
            return
          }
          try {
            const retryAudio: number = mpvGetAudioType(this.mpvHandle)
            salmonLogger.addLog(TAG,
              `[MpvController] detectAndUpdateAudioType retry: audio_type=${retryAudio}`, false)
            if (retryAudio !== 0 && retryAudio !== this.nowPlaying.audio_type) {
              this.nowPlaying.audio_type = retryAudio
              VideoOperateUtil.saveVideoAudioType(PathUtils.appContext!, this.nowPlaying, retryAudio)
            }
          } catch (error) {
            salmonLogger.addLog(TAG, '[MpvController] Failed to retry detect audio type: ' + JSON.stringify(error),
              true)
          }
        }, 1500)
      }
    } catch (error) {
      salmonLogger.addLog(TAG, '[MpvController] Failed to detect audio type: ' + JSON.stringify(error), true)
    }

  }
}
