import { media } from '@kit.MediaKit'
import { fileIo } from '@kit.CoreFileKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { salmonLogger } from 'salmonlogger'
import { VideoStartTimeMode } from '../../common/enum/VideoStartTimeMode'
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import { Setting } from '../../utils/ObservedUtil'
import AVSessionUtil from '../../utils/AVSessionUtil'
import { PathUtils } from '../../utils/PathUtils'
import PermissionUtil from '../../utils/PermissionUtil'
import ToolsUtil from '../../utils/ToolsUtil'
import VideoOperateUtil from '../../utils/VideoOperateUtil'

const TAG = 'ShortVideoPlayer'

export type ShortVideoState = 'idle' | 'preparing' | 'prepared' | 'playing' | 'paused' | 'completed' |
  'error' | 'released'

@ObservedV2
export class ShortVideoPlayer {
  readonly item: VideoMetadata
  @Trace state: ShortVideoState = 'idle'
  @Trace currentTime: number = 0
  @Trace duration: number = 0
  @Trace errorMessage: string = ''
  @Trace playbackRate: number = 1
  @Trace videoWidth: number = 0
  @Trace videoHeight: number = 0
  private player: media.AVPlayer | undefined = undefined
  private surfaceId: string = ''
  private prepareTask: Promise<void> | undefined = undefined
  private playTask: Promise<void> | undefined = undefined
  private preparedResolver: (() => void) | undefined = undefined
  private preparedRejecter: ((reason: Error) => void) | undefined = undefined
  private active: boolean = false
  private hasBeenActive: boolean = false
  private disposed: boolean = false
  private skipHistory: boolean = false
  private lastSavedTime: number = -1
  private onCompleted: () => void = () => {
  }
  private onPlaybackStateChanged: (playing: boolean, currentTime: number) => void =
    (_playing: boolean, _currentTime: number) => {
    }

  constructor(item: VideoMetadata, skipHistory: boolean, onCompleted: () => void,
    onPlaybackStateChanged: (playing: boolean, currentTime: number) => void) {
    this.item = item
    this.duration = item.time
    this.videoWidth = item.size[0] || 0
    this.videoHeight = item.size[1] || 0
    this.skipHistory = skipHistory
    this.onCompleted = onCompleted
    this.onPlaybackStateChanged = onPlaybackStateChanged
  }

  bindSurface(surfaceId: string): void {
    this.surfaceId = surfaceId
    if (this.player) {
      try {
        this.player.surfaceId = surfaceId
      } catch (_error) {
      }
    }
  }

  async prepare(): Promise<void> {
    if (!this.surfaceId) {
      return
    }
    if (this.disposed || this.state === 'prepared' || this.state === 'playing' || this.state === 'paused' ||
      this.state === 'completed') {
      return
    }
    if (this.prepareTask) {
      return this.prepareTask
    }
    const task = this.prepareInternal()
    this.prepareTask = task
    try {
      await task
    } finally {
      if (this.prepareTask === task) {
        this.prepareTask = undefined
      }
    }
  }

  async setActive(active: boolean): Promise<void> {
    this.active = active
    if (!active) {
      await this.pause()
      const restartFromBeginning = this.hasReachedWatchedThreshold()
      this.saveHistory()
      if (restartFromBeginning) {
        this.resetToBeginning()
      }
      return
    }
    this.hasBeenActive = true
    if (this.playTask) {
      return this.playTask
    }
    const task = this.playWhenReady()
    this.playTask = task
    try {
      await task
    } catch (error) {
      this.fail(error)
    } finally {
      if (this.playTask === task) {
        this.playTask = undefined
      }
    }
  }

  private async playWhenReady(): Promise<void> {
    await this.prepare()
    if (!this.active || this.disposed || !this.player || this.state === 'playing') {
      return
    }
    if (this.state === 'completed') {
      this.resetToBeginning()
    }
    try {
      await this.player.play()
    } catch (error) {
      this.fail(error)
    }
  }

  async toggle(): Promise<void> {
    if (!this.player || !this.active) {
      return
    }
    try {
      if (this.state === 'playing') {
        await this.player.pause()
      } else {
        if (this.state === 'completed') {
          this.resetToBeginning()
        }
        await this.player.play()
      }
    } catch (error) {
      this.fail(error)
    }
  }

  seek(position: number): void {
    if (!this.player || this.duration <= 0) {
      return
    }
    const target = Math.max(0, Math.min(position, this.duration))
    this.currentTime = target
    this.onPlaybackStateChanged(this.state === 'playing', target)
    try {
      this.player.seek(target, media.SeekMode.SEEK_CLOSEST)
    } catch (error) {
      salmonLogger.addLog(TAG, `seek failed: ${error}`, true)
    }
  }

  setPlaybackRate(rate: number): void {
    this.playbackRate = rate
    if (!this.player || this.state !== 'playing') {
      return
    }
    try {
      this.player.setPlaybackRate(rate)
    } catch (error) {
      salmonLogger.addLog(TAG, `set playback rate failed: ${error}`, true)
    }
  }

  async pause(): Promise<void> {
    if (!this.player || this.state !== 'playing') {
      return
    }
    try {
      await this.player.pause()
    } catch (error) {
      salmonLogger.addLog(TAG, `pause failed: ${error}`, true)
    }
  }

  saveHistory(skipHistory: boolean = this.skipHistory): void {
    if (!this.hasBeenActive || skipHistory || this.currentTime <= 0 || this.currentTime === this.lastSavedTime) {
      return
    }
    VideoOperateUtil.saveVideoPlayTimeIfNeed(this.currentTime, this.item, false, PathUtils.appContext!)
    this.lastSavedTime = this.currentTime
  }

  async release(skipHistory: boolean = false): Promise<void> {
    if (this.disposed) {
      return
    }
    this.disposed = true
    this.active = false
    this.saveHistory(skipHistory)
    const player = this.player
    this.player = undefined
    if (!player) {
      this.state = 'released'
      return
    }
    this.unregisterCallbacks(player)
    try {
      await player.release()
    } catch (error) {
      salmonLogger.addLog(TAG, `release failed: ${error}`, true)
    }
    this.state = 'released'
  }

  private async prepareInternal(): Promise<void> {
    this.state = 'preparing'
    try {
      const player = await media.createAVPlayer()
      if (this.disposed) {
        await player.release()
        return
      }
      this.player = player
      player.audioInterruptMode = AVSessionUtil.getInterruptMode()
      this.registerCallbacks(player)
      const prepared = new Promise<void>((resolve, reject) => {
        this.preparedResolver = resolve
        this.preparedRejecter = reject
      })
      const permissionGranted = await PermissionUtil.activatePermission(this.item.uri)
      if (!permissionGranted) {
        throw new Error('无法读取视频文件')
      }
      if (ToolsUtil.isNetworkUrl(this.item.uri)) {
        player.url = this.item.uri
      } else {
        player.fdSrc = fileIo.openSync(this.item.uri, fileIo.OpenMode.READ_ONLY)
      }
      await prepared
    } catch (error) {
      this.fail(error)
      throw new Error(this.errorMessage)
    }
  }

  private registerCallbacks(player: media.AVPlayer): void {
    player.on('stateChange', async (state: string) => {
      if (this.disposed || this.player !== player) {
        return
      }
      switch (state) {
        case 'initialized':
          player.surfaceId = this.surfaceId
          player.setPlaybackStrategy({
            preferredBufferDurationForPlaying: 20,
            showFirstFrameOnPrepare: true,
            preferredHdr: true
          }).catch(() => {
          })
          player.prepare().catch((error: BusinessError) => this.fail(error))
          break
        case 'prepared':
          this.state = 'prepared'
          this.duration = player.duration || this.item.time
          this.videoWidth = player.width || this.item.size[0] || 0
          this.videoHeight = player.height || this.item.size[1] || 0
          if (this.duration > 0 && this.item.time === 0) {
            this.item.time = this.duration
          }
          this.seekToRememberedPosition(player)
          this.preparedResolver?.()
          this.clearPrepareCallbacks()
          break
        case 'playing':
          this.state = 'playing'
          this.onPlaybackStateChanged(true, this.currentTime)
          if (this.playbackRate !== 1) {
            player.setPlaybackRate(this.playbackRate)
          }
          if (!this.active) {
            player.pause().catch(() => {
            })
          }
          break
        case 'paused':
          this.state = 'paused'
          this.onPlaybackStateChanged(false, this.currentTime)
          break
        case 'completed':
          this.state = 'completed'
          this.currentTime = this.duration || this.item.time
          this.onPlaybackStateChanged(false, this.currentTime)
          this.saveHistory()
          this.onCompleted()
          break
        case 'error':
          this.fail(new Error('AVPlayer 无法播放该视频'))
          break
        case 'released':
          this.state = 'released'
          break
        default:
          break
      }
    })
    player.on('timeUpdate', (time: number) => {
      this.currentTime = time
      this.onPlaybackStateChanged(this.state === 'playing', time)
    })
    player.on('error', (error: BusinessError) => {
      this.fail(error)
    })
  }

  private unregisterCallbacks(player: media.AVPlayer): void {
    try {
      player.off('stateChange')
      player.off('timeUpdate')
      player.off('error')
    } catch (_error) {
    }
  }

  private seekToRememberedPosition(player: media.AVPlayer): void {
    const mode = VideoOperateUtil.getVideoStartPlayTimeMode(this.item, false)
    let position = 0
    switch (mode) {
      case VideoStartTimeMode.SEEK_TO_LAST_PLAY_TIME:
        position = this.item.last_play || 0
        break
      case VideoStartTimeMode.SEEK_TO_START_TIME:
        position = this.item.start_time || 0
        break
      case VideoStartTimeMode.SEEK_TO_INTRO_TIME:
        position = Number(Setting.skipIntroTime) * 1000
        break
      default:
        position = 0
    }
    this.currentTime = position
    if (position > 0) {
      player.seek(position, media.SeekMode.SEEK_CLOSEST)
    }
  }

  private hasReachedWatchedThreshold(): boolean {
    const totalTime = this.duration || this.item.time
    return totalTime > 0 && this.currentTime > totalTime * 0.95
  }

  private resetToBeginning(): void {
    this.currentTime = 0
    this.lastSavedTime = -1
    this.onPlaybackStateChanged(false, 0)
    try {
      this.player?.seek(0, media.SeekMode.SEEK_CLOSEST)
    } catch (error) {
      salmonLogger.addLog(TAG, `reset to beginning failed: ${error}`, true)
    }
  }

  private fail(error: Object): void {
    this.state = 'error'
    this.onPlaybackStateChanged(false, this.currentTime)
    this.errorMessage = `${error}`
    this.preparedRejecter?.(new Error(this.errorMessage))
    this.clearPrepareCallbacks()
    salmonLogger.addLog(TAG, `playback failed: ${this.item.uri}, ${this.errorMessage}`, true)
  }

  private clearPrepareCallbacks(): void {
    this.preparedResolver = undefined
    this.preparedRejecter = undefined
  }
}
