import { PlayerControllerInterface } from '../PlayerControllerFactory';
import * as mpv from 'libmpvnative.so';
import { Setting } from '../../utils/ObservedUtil';
import { VideoStartTimeMode } from '../../common/enum/VideoStartTimeMode';
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface';

@Observed
export class MpvController implements PlayerControllerInterface {
  @Track mpvHandle: number | null = null
  surfaceId: string | null = null
  @Track playTime: number = 0
  @Track playing: boolean = false
  @Track nowPlaying: VideoMetadata | undefined = undefined
  @Track videoMetaDataList: VideoMetadata[] = []
  @Track speed: number = 1.0
  @Track volume: number = 0
  @Track volumeActually: number = 0
  @Track screenBrightness: number = 0
  @Track onSwipingVoice: boolean = false

  create(): void {
    if (this.mpvHandle) {
      console.error('[MpvPlayer] MPV already created, skipping')
      return
    }
    console.error('[MpvPlayer] Creating mpv instance')
    try {
      this.mpvHandle = mpv.create()
      console.error('[MpvPlayer] Create returned:', this.mpvHandle, 'type:', typeof this.mpvHandle)
      if (!this.mpvHandle) {
        console.error('[MpvPlayer] Failed to create mpv instance - handle is null/undefined')
      } else {
        console.error('[MpvPlayer] MPV instance created:', this.mpvHandle)
        //  this.applyUserAgent()
      }
    } catch {
      console.error('[MpvPlayer] Exception during create')
    }
  }

  init(surfaceId: string, url: string, startPosition?: number): void {
    this.setSurface(surfaceId)
    this.setupGL()
    this.startRenderLoop()
    // 传递起始位置给 native（参考 mpv-android）
    if (startPosition !== undefined && startPosition > 0) {
      mpv.loadVideo(this.mpvHandle, url, startPosition)
    } else {
      mpv.loadVideo(this.mpvHandle, url)
    }
    this.playing = true
    console.error('[MpvPlayer] load video success')
  }

  backForward(): void {
    if (!this.mpvHandle) {
      return
    }
    mpv.seek(this.mpvHandle, this.playTime - Number(Setting.fastForwardSeconds) * 1000, true)
  }

  fastForward(): void {
    if (!this.mpvHandle) {
      return
    }
    mpv.seek(this.mpvHandle, this.playTime + Number(Setting.fastForwardSeconds) * 1000, true)
  }

  prepare(): void {
    throw new Error("Method not implemented.");
  }

  play(): void {
    if (!this.mpvHandle) {
      return
    }
    this.playing = true
    mpv.play(this.mpvHandle)
  }

  pause(): void {
    if (!this.mpvHandle) {
      return
    }
    this.playing = false
    mpv.pause(this.mpvHandle)
  }

  reset(): void {
    throw new Error("Method not implemented.");
  }

  release(): void {
    if (!this.mpvHandle) {
      return
    }
    mpv.destroy(this.mpvHandle)
    mpv.destroyGL()
  }

  seekTime(seekTime: number): void {
    if (!this.mpvHandle) {
      return
    }
    mpv.seek(this.mpvHandle, seekTime, true)
  }

  getPlayAreaWidth(): number {
    return mpv.getVideoWidth(this.mpvHandle)
  }

  getPlayAreaHeight(): number {
    return mpv.getVideoHeight(this.mpvHandle)
  }

  togglePlayback(): void {
    this.playing ? this.pause() : this.play()
  }

  updatePlaybackSpeed(speed: number) {
    mpv.setSpeed(this.mpvHandle, speed)
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
    if (!this.mpvHandle) {
      console.error('[MpvPlayer] Cannot setup GL: mpv not created')
      return
    }
    console.error('[MpvPlayer] Setting up OpenGL rendering')
    try {
      mpv.setupGL(this.mpvHandle)
      console.error('[MpvPlayer] setupGL completed')
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
    console.error('[MpvPlayer] Setting up EVENT-DRIVEN rendering')

    // 注册事件驱动的渲染回调
    // 每次调用都会重新注册，这是为了确保回调正确设置
    if (this.mpvHandle) {
      try {
        mpv.setRenderCallback(this.mpvHandle, () => {
          // MPV 通知有新帧，立即渲染
          if (this.mpvHandle) {
            try {
              mpv.render(this.mpvHandle)
              this.playTime = mpv.getCurrentPosition(this.mpvHandle)
            } catch (e) {
              // Ignore render errors
            }
          }
        })
        console.error('[MpvPlayer] ✅ Event-driven render callback registered')
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
    console.error('[MpvPlayer] Setting surface:', surfaceId)
    this.surfaceId = surfaceId
    mpv.initSurface(surfaceId)
  }
}