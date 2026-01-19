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

  seekTime(seekTime: number): void

  togglePlayback(): void

  videoStartPlayTime(seekMode: number): void
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