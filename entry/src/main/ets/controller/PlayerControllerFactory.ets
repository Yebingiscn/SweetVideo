import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import { AVPlayerController } from './AVPlayerController/AVPlayerController'
import { MpvController } from './MpvController/MpvController'
import { SweetRepeatMode } from '../common/enum/SweetRepeatMode'
import { Subtitle3DMode, SubtitleMode } from '../common/enum/SubtitleMode'
import { avSession as avSessionManager } from '@kit.AVSessionKit'
import { window } from '@kit.ArkUI'
import { AudioTrack, SubtitleTrack } from '../interfaces/AudioTrackInterface'
import { MpvAudioTrack, MpvChapter, MpvSubtitleTrack } from './MpvController/MpvTypes'

export interface PlayerControllerInterface {
  surfaceId: string | null
  avSession: avSessionManager.AVSession | undefined
  nowPlaying: VideoMetadata | undefined
  videoMetaDataList: VideoMetadata[]
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
  isZoomed: boolean
  isGesturing: boolean
  translateX: number
  translateY: number
  angle: number
  pixelMap: PixelMap | null
  audioTrackSelected: number
  abCircleStatus: boolean
  subtitleSelected: SubtitleMode
  subtitleTrackSelected: number
  audioTrack: AudioTrack[] | MpvAudioTrack[]
  chapterList: MpvChapter[]
  volumeLoudnessGain: number
  audioChannelMode: number
  subtitleTrack: SubtitleTrack[] | MpvSubtitleTrack[]

  backForward(): void

  fastForward(): void

  prepare(): void

  play(): void

  pause(): void

  reset(): void

  release(): void

  init(): void

  create(): void

  seekTime(seekTime: number): void

  togglePlayback(): void

  videoStartPlayTime(seekMode: number): void

  getAudioTrackList(): void

  selectAudioTrack(trackId: number): void

  selectAudioTrackByIndex(index: number): void

  getAudioTrackCount(): number

  initAVSession(): Promise<void>

  setSessionListener(): void

  setRotation(): void

  onScreenDoubleClick(tapX: number): void

  getSubtitleTrackList(): void

  selectSubtitleTrack(trackId: number): void

  initVolumeAndBrightness(): Promise<void>


  getData(): void

  setPlayerCallback(pathStack: NavPathStack, xComponentController?: XComponentController,
    windowClass?: Promise<window.Window | undefined>): void

  updatePlaybackSpeed(speed: number): void

  playNextVideo(repeatMode: SweetRepeatMode): VideoMetadata | undefined

  setExternalSubtitle(nowPlaying: VideoMetadata): void

  playNextVideoProcess(pathStack: NavPathStack, windowClass?: Promise<window.Window | undefined>,
    xComponentController?: XComponentController): void

  playChooseVideo(item: VideoMetadata, pathStack: NavPathStack,
    windowClass?: Promise<window.Window | undefined>, xComponentController?: XComponentController): void

  refreshExternalSubtitlePreview(offset: number): void

  refreshExternalSubtitleByPlaybackTime(isAdjustingSubtitleOffset: boolean, subtitleVisibility: Visibility): void

  getAdjacentSubtitleOffset(direction: 'prev' | 'next', currentOffset: number): number | undefined

  saveSubtitlePreferenceForCurrentVideo(subtitleVisibility: Visibility, isAIAsrShown: boolean,
    subtitle3DMode: Subtitle3DMode): void

  cancelSubscribe(): void

  getFrameByTime(time: number, isFirstFrame: boolean): void

  setLoudnessGain(loudnessGain: number): void

  setAudioChannelMode(mode: number): void

  isMpvPlayer(): boolean

  getWindowClass(): Promise<window.Window | undefined> | undefined

  prepareIfNeeded(): void

  onPlayerReady(): void

  savePlayerSpeed(context: Context): void

  onDisappearSaveSubtitlePreference(subtitleVisibility: Visibility, isAIAsrShown: boolean,
    subtitle3DMode: Subtitle3DMode): void

  onDisappearCleanup(): void

  onDisappearRelease(): Promise<void>

  onSurfaceLoad(xComponentController: XComponentController, pathStack: NavPathStack,
    windowClass?: Promise<window.Window | undefined>): Promise<void>

  onOsdSurfaceLoad(surfaceId: string): void

  restoreSpeedAfterLongPress(lastSpeed: number): void

  restoreSystemBars(windowClass?: Promise<window.Window | undefined>): Promise<void>

  onWillDisappearCleanup(): void

  onWillDisappearRelease(windowClass?: Promise<window.Window | undefined>): Promise<void>

  hasChapterSupport(): boolean

  seekToChapter(chapterIndex: number): void

  resetAspectRatio(): void

  stretchToFullScreen(): void

  exitPlayback(timeout: number): Promise<void>

  toggleListenVideo(): void

  getXComponentId(): string | undefined

  getLibraryName(): string | undefined

  getOsdVisibility(): boolean
}

// 真正的工厂 controller
export class PlayerControllerFactory {
  static createAVPlayerController(): AVPlayerController {
    return new AVPlayerController()
  }

  static createMpvController(): MpvController {
    return new MpvController()
  }
}