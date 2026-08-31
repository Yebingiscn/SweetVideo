import { media } from '@kit.MediaKit'
import { salmonLogger } from 'salmonlogger'
import { EngineReleaseHook, PlayerEngineAdapter } from './PlayerEngineAdapter'

const TAG = 'AVPlayerEngineAdapter'

export class AVPlayerEngineAdapter implements PlayerEngineAdapter {
  private nativePlayer: media.AVPlayer | undefined = undefined
  private releaseTask: Promise<void> | undefined = undefined
  private resetTask: Promise<void> | undefined = undefined
  private resetTarget: media.AVPlayer | undefined = undefined

  get player(): media.AVPlayer | undefined {
    return this.nativePlayer
  }

  isCreated(): boolean {
    return this.nativePlayer !== undefined
  }

  isReleasing(): boolean {
    return this.releaseTask !== undefined
  }

  isCurrent(player: media.AVPlayer): boolean {
    return this.nativePlayer === player
  }

  async create(): Promise<media.AVPlayer | undefined> {
    if (this.releaseTask) {
      const releaseTask: Promise<void> = this.releaseTask
      await releaseTask
    }
    if (!this.nativePlayer) {
      try {
        this.nativePlayer = await media.createAVPlayer()
      } catch (error) {
        salmonLogger.addLog(TAG, `create error: ${error}`, true)
        throw new Error(`AVPlayer create failed: ${error}`)
      }
    }
    return this.nativePlayer
  }

  waitForReset(player: media.AVPlayer): Promise<void> {
    if (this.resetTask && this.resetTarget === player) {
      return this.resetTask
    }
    return Promise.resolve()
  }

  async reset(): Promise<void> {
    if (this.releaseTask) {
      return this.releaseTask
    }
    const player = this.nativePlayer
    if (!player) {
      return
    }
    await this.resetPlayer(player, 'reset error')
  }

  async release(beforeNativeRelease?: EngineReleaseHook): Promise<void> {
    if (this.releaseTask) {
      return this.releaseTask
    }
    const player = this.nativePlayer
    if (!player) {
      return
    }
    this.nativePlayer = undefined
    const task = this.releasePlayer(player, beforeNativeRelease)
    this.releaseTask = task
    try {
      await task
    } finally {
      if (this.releaseTask === task) {
        this.releaseTask = undefined
      }
    }
  }

  private async resetPlayer(player: media.AVPlayer, errorMessage: string): Promise<void> {
    if (this.resetTask && this.resetTarget === player) {
      return this.resetTask
    }
    if (this.resetTask) {
      const resetTask: Promise<void> = this.resetTask
      await resetTask
    }
    const task = player.reset().catch(() => {
      salmonLogger.addLog(TAG, errorMessage, true)
    })
    this.resetTask = task
    this.resetTarget = player
    try {
      await task
    } finally {
      if (this.resetTask === task) {
        this.resetTask = undefined
        this.resetTarget = undefined
      }
    }
  }

  private async releasePlayer(player: media.AVPlayer, beforeNativeRelease?: EngineReleaseHook): Promise<void> {
    // Let release() publish releaseTask before any reset or release hook runs.
    await Promise.resolve()
    if (this.resetTask && this.resetTarget === player) {
      await this.waitForReset(player)
      this.runReleaseHook(beforeNativeRelease)
    } else {
      this.runReleaseHook(beforeNativeRelease)
      await this.resetPlayer(player, 'release reset error')
    }
    try {
      await player.release()
    } catch (error) {
      salmonLogger.addLog(TAG, `release error: ${error}`, true)
    }
  }

  private runReleaseHook(beforeNativeRelease?: EngineReleaseHook): void {
    try {
      beforeNativeRelease?.()
    } catch (error) {
      salmonLogger.addLog(TAG, `before release hook error: ${error}`, true)
    }
  }
}
