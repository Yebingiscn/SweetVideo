import { AVPlayerController } from './AVPlayerController'

// 产品接口 interface
export interface PlayerControllerInterface {
  backForward(): void

  fastForward(): void

  prepare(): void

  play(): void

  pause(): void

  release(): void

  seekTime(seekTime: number): void

  togglePlayback(): void

  videoStartPlayTime(seekMode: number): void
}

// 真正的工厂 controller
export class PlayerControllerFactory {
  static createPlayerController(): AVPlayerController {
    return new AVPlayerController();
  }
}