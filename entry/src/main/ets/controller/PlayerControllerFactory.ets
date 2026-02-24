import { AVPlayerController } from './AVPlayerController'
import { MpvController } from './MpvController/MpvController'

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

  initAVSession(): void

  setSessionListener(): void

  setRotation(): void

  onScreenDoubleClick(tapX: number): void
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