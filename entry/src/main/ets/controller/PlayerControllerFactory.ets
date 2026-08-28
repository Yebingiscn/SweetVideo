import { media } from '@kit.MediaKit'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import { AVPlayerController } from './AVPlayerController/AVPlayerController'
import { MpvController } from './MpvController/MpvController'
import { SweetRepeatMode } from '../common/enum/SweetRepeatMode'
import { Subtitle3DMode, SubtitleMode } from '../common/enum/SubtitleMode'
import { avSession as avSessionManager } from '@kit.AVSessionKit'
import { window } from '@kit.ArkUI'
import { AudioTrack, SubtitleTrack } from '../interfaces/AudioTrackInterface'
import { MpvAudioTrack, MpvChapter, MpvSubtitleTrack } from './MpvController/MpvTypes'
import { PlayerEngine } from '../common/NavigationCommon'

export type PlayerEngineSwitchHandler =
  (targetEngine: string, reason: string, resumePlayback?: boolean) => Promise<void>

export interface PlayerControllerInterface {
  surfaceId: string | null
  avSession: avSessionManager.AVSession | undefined
  nowPlaying: VideoMetadata | undefined
  videoMetaDataList: VideoMetadata[]
  initialPlayTime: number | undefined
  initialPlaying: boolean | undefined
  skipHistory: boolean
  selectedText: string | undefined
  playAreaHeight: number
  playAreaWidth: number
  screenWidth: number
  screenHeight: number
  speed: number
  repeatMode: SweetRepeatMode
  volume: number
  volumeActually: number
  screenBrightness: number
  onSwipingVoice: boolean
  onSwipingBrightness: boolean
  onSwiping: boolean
  isSliderPlayTimeChange: boolean
  playTime: number
  playing: boolean
  subtitle: string
  showControl: boolean
  lockVisibility: boolean
  isLock: boolean
  longPress: boolean
  speedLocked: boolean
  isZoomed: boolean
  isGesturing: boolean
  scaleFactor: number
  translateX: number
  translateY: number
  angle: number
  pixelMap: PixelMap | null
  audioTrackSelected: number
  abCircleStatus: boolean
  subtitleSelected: SubtitleMode
  subtitleTrackSelected: number
  secondarySubtitleTrackSelected: number
  audioTrack: AudioTrack[] | MpvAudioTrack[]
  chapterList: MpvChapter[]
  volumeLoudnessGain: number
  subtitlePosition: number
  subtitleSize: number
  audioChannelMode: number
  subtitleTrack: SubtitleTrack[] | MpvSubtitleTrack[]
  networkPlaybackActive: boolean
  networkSpeedText: string
  networkBufferPercent: number
  networkCacheDuration: number
  networkBuffering: boolean

  backForward(): void

  fastForward(): void

  prepare(): void

  play(): void

  pause(): void

  reset(): Promise<void>

  release(): Promise<void>

  dispose(): Promise<void>

  init(): Promise<void>

  create(): Promise<void>

  seekTime(seekTime: number): void

  togglePlayback(): void

  videoStartPlayTime(seekMode: number): void

  getAudioTrackList(): Promise<void>

  selectAudioTrack(trackId: number): void

  selectAudioTrackByIndex(index: number): void

  getAudioTrackCount(): number

  initAVSession(): Promise<void>

  setSessionListener(): void

  setRotation(): void

  onScreenDoubleClick(tapX: number): void

  getSubtitleTrackList(): Promise<void>

  selectSubtitleTrack(trackId: number): void

  selectExternalSubtitleTrack(): void

  selectSecondarySubtitleTrack(trackId: number): void

  initVolumeAndBrightness(): Promise<void>


  getData(): Promise<void>

  setPlayerCallback(pathStack: NavPathStack, xComponentController?: XComponentController,
    windowClass?: Promise<window.Window | undefined>): void

  updatePlaybackSpeed(speed: number): void

  playAdjacentVideo(repeatMode: SweetRepeatMode,
    direction: 'previous' | 'next'): VideoMetadata | undefined

  setExternalSubtitle(nowPlaying: VideoMetadata): void

  playNextVideoProcess(pathStack: NavPathStack, windowClass?: Promise<window.Window | undefined>,
    xComponentController?: XComponentController, overrideRepeatMode?: SweetRepeatMode): Promise<void>

  playChooseVideo(item: VideoMetadata, pathStack: NavPathStack,
    windowClass?: Promise<window.Window | undefined>, xComponentController?: XComponentController): Promise<void>

  refreshExternalSubtitlePreview(offset: number): void

  setSubtitleOffset(offsetMillis: number): void

  setSubtitle3DMode(mode: Subtitle3DMode): void

  supportsSubtitle3D(): boolean

  refreshExternalSubtitleByPlaybackTime(isAdjustingSubtitleOffset: boolean, subtitleVisibility: Visibility): void

  getAdjacentSubtitleOffset(direction: 'prev' | 'next', currentOffset: number): number | undefined

  saveSubtitlePreferenceForCurrentVideo(subtitleVisibility: Visibility, isAIAsrShown: boolean,
    subtitle3DMode: Subtitle3DMode): void

  cancelSubscribe(): void

  getFrameByTime(time: number, isFirstFrame: boolean): void

  setLoudnessGain(loudnessGain: number): void

  setSubtitlePosition(position: number): void

  setSubtitleSize(size: number): void

  setAudioChannelMode(mode: number): void

  isMpvPlayer(): boolean

  getWindowClass(): Promise<window.Window | undefined> | undefined

  prepareIfNeeded(): void

  onPlayerReady(): void

  savePlayerSpeed(context: Context): void

  onDisappearSaveSubtitlePreference(subtitleVisibility: Visibility, isAIAsrShown: boolean,
    subtitle3DMode: Subtitle3DMode): void

  onDisappearCleanup(): void

  // 兼容旧调用；新页面生命周期统一使用 dispose()。
  onDisappearRelease(): Promise<void>

  onSurfaceLoad(xComponentController: XComponentController, pathStack: NavPathStack,
    windowClass?: Promise<window.Window | undefined>): Promise<void>

  onOsdSurfaceLoad(surfaceId: string, surfaceWidth: number, surfaceHeight: number): void

  onOsdSurfaceDestroy(surfaceId: string): void

  restoreSpeedAfterLongPress(lastSpeed: number): void

  restoreSystemBars(windowClass?: Promise<window.Window | undefined>): Promise<void>

  onWillDisappearCleanup(): void

  // 兼容旧调用；新页面生命周期统一使用 dispose()。
  onWillDisappearRelease(windowClass?: Promise<window.Window | undefined>): Promise<void>

  hasChapterSupport(): boolean


  onMetricsEvent(callback: (info: Array<media.AVMetricsEvent>) => void): void

  offMetricsEvent(callback?: (info: Array<media.AVMetricsEvent>) => void): void

  seekToChapter(chapterIndex: number): void

  resetAspectRatio(): void

  stretchToFullScreen(): void

  exitPlayback(timeout: number): Promise<void>

  toggleListenVideo(): void

  getXComponentId(): string | undefined

  getLibraryName(): string | undefined

  getOsdVisibility(): boolean

  setEngineSwitchHandler(handler: PlayerEngineSwitchHandler | undefined): void

  requestEngineSwitch(targetEngine: string, reason: string, resumePlayback?: boolean): Promise<void>
}

// 真正的工厂 controller
export class PlayerControllerFactory {
  static createController(playerEngine: string): PlayerControllerInterface {
    return playerEngine === PlayerEngine.MPV_PLAYER ?
      PlayerControllerFactory.createMpvController() :
      PlayerControllerFactory.createAVPlayerController()
  }

  static createAVPlayerController(): AVPlayerController {
    return new AVPlayerController()
  }

  static createMpvController(): MpvController {
    return new MpvController()
  }
}
