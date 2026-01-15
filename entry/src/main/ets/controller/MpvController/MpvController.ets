import { PlayerControllerInterface } from '../PlayerControllerFactory';
import * as mpv from 'libmpvnative.so';
import { Setting } from '../../utils/ObservedUtil';
import { VideoStartTimeMode } from '../../common/enum/VideoStartTimeMode';
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface';

@Observed
export class MPVController implements PlayerControllerInterface {
  mpvId: number | null = null
  surfaceId: string | null = null
  @Track playTime: number = 0
  @Track playing: boolean = false
  @Track nowPlaying: VideoMetadata | undefined = undefined

  create(): void {
    if (this.mpvId) {
      console.log('[MpvPlayer] MPV already created, skipping')
      return
    }
    console.log('[MpvPlayer] Creating mpv instance')
    try {
      this.mpvId = mpv.create()
      console.log('[MpvPlayer] Create returned:', this.mpvId, 'type:', typeof this.mpvId)
      if (!this.mpvId) {
        console.error('[MpvPlayer] Failed to create mpv instance - handle is null/undefined')
      } else {
        console.log('[MpvPlayer] MPV instance created:', this.mpvId)
        //  this.applyUserAgent()
      }
    } catch {
      console.error('[MpvPlayer] Exception during create')
    }
  }

  backForward(): void {
    if (!this.mpvId) {
      return
    }
    mpv.seek(this.mpvId, this.playTime - Number(Setting.fastForwardSeconds) * 1000, true)
  }

  fastForward(): void {
    if (!this.mpvId) {
      return
    }
    mpv.seek(this.mpvId, this.playTime + Number(Setting.fastForwardSeconds) * 1000, true)
  }

  prepare(): void {
    throw new Error("Method not implemented.");
  }

  play(): void {
    if (!this.mpvId) {
      return
    }
    mpv.play(this.mpvId)
  }

  pause(): void {
    if (!this.mpvId) {
      return
    }
    mpv.pause(this.mpvId)
  }

  reset(): void {
    throw new Error("Method not implemented.");
  }

  release(): void {
    if (!this.mpvId) {
      return
    }
    mpv.destroy(this.mpvId)
    mpv.destroyGL()
  }

  seekTime(seekTime: number): void {
    if (!this.mpvId) {
      return
    }
    mpv.seek(this.mpvId, seekTime, true)
  }

  togglePlayback(): void {
    this.playing ? this.pause() : this.play()
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
      default:
        return
    }
  }

  /**
   * 设置 OpenGL 渲染
   */
  setupGL(): void {
    if (!this.mpvId) {
      console.error('[MpvPlayer] Cannot setup GL: mpv not created')
      return
    }
    console.log('[MpvPlayer] Setting up OpenGL rendering')
    try {
      mpv.setupGL(this.mpvId)
      console.log('[MpvPlayer] setupGL completed')
    } catch {
      console.error('[MpvPlayer] Exception during setupGL')
    }
  }

  /**
   * 启动渲染 - 纯事件驱动模式
   * MPV 通过 mpv_update 回调自动触发渲染，完全无需定时器
   * 注意：这个方法可以被多次调用，setRenderCallback 会覆盖之前的回调
   */
  private startRenderLoop(): void {
    console.log('[MpvPlayer] Setting up EVENT-DRIVEN rendering')

    // 注册事件驱动的渲染回调
    // 每次调用都会重新注册，这是为了确保回调正确设置
    if (this.mpvId) {
      try {
        mpv.setRenderCallback(this.mpvId, () => {
          // MPV 通知有新帧，立即渲染
          if (this.mpvId) {
            try {
              mpv.render(this.mpvId)
            } catch (e) {
              // Ignore render errors
            }
          }
        })
        console.log('[MpvPlayer] ✅ Event-driven render callback registered')
      } catch (e) {
        console.error('[MpvPlayer] ❌ Failed to set render callback:', e)
      }
    }
  }

  /**
   * 停止渲染 - 事件驱动模式下无需操作
   * MPV 暂停时会自动停止触发 mpv_update 回调
   */
  private stopRenderLoop(): void {
    // 纯事件驱动模式，无需清理
    // MPV 暂停后自动不再触发回调，恢复后自动继续
  }

  /**
   * 设置渲染表面（内部方法）
   */
  private setSurface(surfaceId: string): void {
    console.log('[MpvPlayer] Setting surface:', surfaceId)
    this.surfaceId = surfaceId
    mpv.initSurface(surfaceId)
  }
}