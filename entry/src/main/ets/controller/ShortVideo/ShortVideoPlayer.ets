import MediaLibraryService from '../../utils/MediaLibraryService'
import { NetworkPlayback } from '../../utils/NetworkPlayback'
import { media } from '@kit.MediaKit'

import { NativeAVPlayer } from '../engine/NativeAVPlayer'
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
import VideoInfoUtil from '../../utils/VideoInfoUtil'

const TAG = 'ShortVideoPlayer'

export type ShortVideoState = 'idle' | 'preparing' | 'prepared' | 'playing' | 'paused' | 'completed' |
  'error' | 'released'

@ObservedV2
export class ShortVideoPlayer {
  private smbPlayback: NetworkPlayback = new NetworkPlayback()
  readonly item: VideoMetadata
  @Trace state: ShortVideoState = 'idle'
  @Trace currentTime: number = 0
  @Trace duration: number = 0
  @Trace errorMessage: string = ''
  @Trace playbackRate: number = 1
  @Trace videoWidth: number = 0
  @Trace videoHeight: number = 0
  @Trace audioCoverUri: string = ''
  private player: NativeAVPlayer | undefined = undefined
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
    if (this.surfaceId === surfaceId) {
      return
    }
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
    if (this.disposed) {
      return
    }
    this.active = active
    if (!active) {
      await this.pause()
      if (this.disposed || this.active) {
        return
      }
      const restartFromBeginning = this.hasReachedWatchedThreshold()
      this.saveHistory()
      if (restartFromBeginning) {
        this.resetToBeginning()
      }
      return
    }
    this.hasBeenActive = true
    // The page can become active before Swiper has created its XComponent surface.
    // Do not leave behind a completed play task in that case; bindSurface() will retry.
    if (!this.surfaceId) {
      return
    }
    if (this.playTask) {
      return this.playTask
    }
    const task = this.playWhenReady()
    this.playTask = task
    try {
      await task
    } catch (error) {
      if (this.active) {
        this.fail(error)
      }
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
    const player = this.player
    try {
      await player.play()
    } catch (error) {
      if (this.active) {
        this.fail(error, player)
      }
    }
  }

  async toggle(): Promise<void> {
    if (!this.player || !this.active || this.disposed) {
      return
    }
    const player = this.player
    try {
      if (this.state === 'playing') {
        await player.pause()
      } else {
        if (this.state === 'completed') {
          this.resetToBeginning()
        }
        await player.play()
      }
    } catch (error) {
      if (this.active) {
        this.fail(error, player)
      }
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
    const player = this.player
    player.setPlaybackRate(rate).catch((error: BusinessError) => {
      if (!this.disposed && this.player === player) {
        salmonLogger.addLog(TAG, `set playback rate failed: ${error}`, true)
      }
    })
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
    MediaLibraryService.saveVideoPlayTimeIfNeed(this.currentTime, this.item, false, PathUtils.appContext!)
    this.lastSavedTime = this.currentTime
  }

  async release(skipHistory: boolean = false): Promise<void> {
    if (this.disposed) {
      return
    }
    this.disposed = true
    this.state = 'released'
    this.audioCoverUri = ''
    this.smbPlayback.close()
    this.preparedResolver?.()
    this.clearPrepareCallbacks()
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
    this.errorMessage = ''
    try {
      const player = await NativeAVPlayer.create()
      if (this.disposed) {
        await player.release()
        return
      }
      this.player = player
      this.registerCallbacks(player)
      const url = await this.smbPlayback.resolve(this.item.uri)
      if (this.disposed) return
      const prepared = new Promise<void>((resolve, reject) => {
        this.preparedResolver = resolve
        this.preparedRejecter = reject
      })
      // 源设置/权限检查还在等待时，也可能提前收到准备失败回调。
      prepared.catch(() => {
      })
      const permissionGranted = await PermissionUtil.activatePermission(this.item.uri)
      if (!permissionGranted) {
        throw new Error(ToolsUtil.getStringResource($r('app.string.cannot_read_video_file').id))
      }
      if (this.disposed) {
        return
      }
      this.audioCoverUri = VideoInfoUtil.getCachedAudioCoverUri(this.item)
      if (ToolsUtil.isNetworkUrl(this.item.uri)) {
        await player.setUrlSource(url, this.smbPlayback.headers(this.item.network_http_headers))
      } else {
        const file = fileIo.openSync(this.item.uri, fileIo.OpenMode.READ_ONLY)
        try {
          await player.setFdSource(file.fd)
        } finally {
          fileIo.closeSync(file)
        }
      }
      await prepared
    } catch (error) {
      if (this.disposed) return
      this.fail(error)
      throw new Error(this.errorMessage)
    }
  }

  private registerCallbacks(player: NativeAVPlayer): void {
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
          player.prepare().catch((error: BusinessError) => this.fail(error, player))
          break
        case 'prepared':
          this.state = 'prepared'
          try {
            player.audioInterruptMode = AVSessionUtil.getInterruptMode()
          } catch (error) {
            salmonLogger.addLog(TAG, `set audio interrupt mode failed: ${error}`, true)
          }
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
            this.setPlaybackRate(this.playbackRate)
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
      if (this.disposed || this.player !== player) {
        return
      }
      this.currentTime = time
      this.onPlaybackStateChanged(this.state === 'playing', time)
    })
    player.on('error', (error: BusinessError) => {
      if (this.disposed || this.player !== player) {
        return
      }
      this.fail(error)
    })
  }

  private unregisterCallbacks(player: NativeAVPlayer): void {
    try {
      player.off('stateChange')
      player.off('timeUpdate')
      player.off('error')
    } catch (_error) {
    }
  }

  private seekToRememberedPosition(player: NativeAVPlayer): void {
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

  private fail(error: Object, player?: NativeAVPlayer): void {
    if (this.disposed || (player !== undefined && this.player !== player)) {
      return
    }
    this.state = 'error'
    this.onPlaybackStateChanged(false, this.currentTime)
    this.errorMessage = `${error}`
    this.preparedRejecter?.(new Error(this.errorMessage))
    this.clearPrepareCallbacks()
    salmonLogger.addLog(TAG, `playback failed: item=${this.item.date}, ${this.errorMessage}`, true)
  }

  private clearPrepareCallbacks(): void {
    this.preparedResolver = undefined
    this.preparedRejecter = undefined
  }
}
