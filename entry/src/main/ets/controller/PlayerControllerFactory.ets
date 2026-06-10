import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import { AVPlayerController } from './AVPlayerController/AVPlayerController'
import { MpvController } from './MpvController/MpvController'
import { SweetRepeatMode } from '../common/enum/SweetRepeatMode'
import { window } from '@kit.ArkUI'

// 产品接口 interface
export interface PlayerControllerInterface {
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

  initAVSession(): Promise<void>

  setSessionListener(): void

  setRotation(): void

  onScreenDoubleClick(tapX: number): void

  getSubtitleTrackList(): void

  selectSubtitleTrack(trackId: number): void

  initVolumeAndBrightness(): Promise<void>

  getData(): void

  setPlayerCallback(pathStack: NavPathStack): void

  updatePlaybackSpeed(speed: number): void

  playNextVideo(repeatMode: SweetRepeatMode): VideoMetadata | undefined

  setExternalSubtitle(nowPlaying: VideoMetadata): void

  playNextVideoProcess(pathStack: NavPathStack, windowClass?: Promise<window.Window | undefined>,
    xComponentController?: XComponentController): void

  playChooseVideo(item: VideoMetadata, pathStack: NavPathStack,
    windowClass?: Promise<window.Window | undefined>, xComponentController?: XComponentController): void
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