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
import Preferences from '../../database/Preferences'
import { PlaybackPolicyCallbacks } from '../PlaybackPolicyInterface'

const TAG = 'ShortVideoPlayer'

export type ShortVideoState = 'idle' | 'preparing' | 'prepared' | 'playing' | 'paused' | 'completed' |
  'error' | 'released'

@ObservedV2
export class ShortVideoPlayer {
  private smbPlayback: NetworkPlayback = new NetworkPlayback()
  readonly item: VideoMetadata
  @Trace state: ShortVideoState = 'idle'
  @Trace activating: boolean = false
  @Trace currentTime: number = 0
  @Trace playbackPositionMs: number = 0
  @Trace duration: number = 0
  @Trace errorMessage: string = ''
  @Trace playbackRate: number = 1
  @Trace videoWidth: number = 0
  @Trace videoHeight: number = 0
  @Trace audioCoverUri: string = ''
  playbackPolicy: PlaybackPolicyCallbacks | undefined = undefined
  private player: NativeAVPlayer | undefined = undefined
  private surfaceId: string = ''
  private prepareTask: Promise<void> | undefined = undefined
  private playTask: Promise<void> | undefined = undefined
  private playTaskVersion: number = -1
  private pauseTask: Promise<void> | undefined = undefined
  // 命令返回与 playing 回调不是同一时刻，回调到来前也不能重复起播。
  private playRequested: boolean = false
  private preparedResolver: (() => void) | undefined = undefined
  private preparedRejecter: ((reason: Error) => void) | undefined = undefined
  private active: boolean = false
  private activationVersion: number = 0
  private hasBeenActive: boolean = false
  private disposed: boolean = false
  private skipHistory: boolean = false
  private lastSavedTime: number = -1
  private readyPolicy: PlaybackPolicyCallbacks | undefined = undefined
  private readyPlayer: NativeAVPlayer | undefined = undefined
  private policyHandledReady: boolean = false
  private playbackEnded: boolean = false
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

  get isActive(): boolean {
    return this.active && !this.disposed
  }

  get playing(): boolean {
    return this.isActive && this.state === 'playing'
  }

  get playbackFailed(): boolean {
    return this.isActive && !this.activating && this.state === 'error'
  }

  private isCurrentActivation(version: number, player?: NativeAVPlayer): boolean {
    return this.active && !this.disposed && version === this.activationVersion &&
      (player === undefined || this.player === player)
  }

  async finishAtEnding(): Promise<void> {
    const player = this.player
    if (!this.active || this.disposed || !player) { return }
    const pauseTask = this.pause()
    const activationVersion = this.activationVersion
    await pauseTask
    if (!this.active || this.disposed || this.player !== player || activationVersion !== this.activationVersion) { return }
    this.playbackEnded = true
    this.state = 'completed'
    this.saveHistory()
    this.onPlaybackStateChanged(false, this.currentTime)
    this.onCompleted()
  }

  /** 激活已预加载的播放器时，也需要让同一会话策略接管起播位置。 */
  notifyPolicyReady(): boolean {
    const player = this.player
    const policy = this.playbackPolicy
    if (!this.active || this.disposed || !player || !policy ||
      (this.state !== 'prepared' && this.state !== 'paused' && this.state !== 'playing' &&
        this.state !== 'completed')) {
      return false
    }
    if (this.readyPlayer === player && this.readyPolicy === policy) {
      return this.policyHandledReady
    }
    this.readyPlayer = player
    this.readyPolicy = policy
    this.policyHandledReady = false
    const handled = policy.onReady()
    if (!this.disposed && this.active && this.player === player && this.playbackPolicy === policy) {
      this.policyHandledReady = handled
    }
    return handled
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
    if (this.active !== active) { this.activationVersion++ }
    this.active = active
    if (!active) {
      this.readyPlayer = undefined
      this.readyPolicy = undefined
      this.policyHandledReady = false
      const pauseTask = this.pause()
      const version = this.activationVersion
      await pauseTask
      if (this.disposed || this.active || version !== this.activationVersion) {
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
    const version = this.activationVersion
    if (this.playTask && this.playTaskVersion === version) {
      return this.playTask
    }
    if (this.state === 'playing' && !this.playbackEnded && !this.pauseTask) {
      return
    }
    this.activating = true
    // Surface 尚未创建时保留准备状态，绑定后由同一激活入口继续。
    if (!this.surfaceId) {
      return
    }
    const task = this.playWhenReady(version, this.playTask)
    this.playTask = task
    this.playTaskVersion = version
    try {
      await task
    } finally {
      if (this.playTask === task) {
        this.playTask = undefined
      }
      if (this.isCurrentActivation(version)) {
        this.activating = this.playRequested
      }
    }
  }

  private async playWhenReady(version: number, previousTask?: Promise<void>): Promise<void> {
    // 快速切走再切回时，先让旧请求收尾，再启动当前这轮，不能复用旧轮结果。
    if (previousTask) {
      await previousTask
    }
    if (!this.isCurrentActivation(version)) {
      return
    }
    try {
      await this.prepare()
      const player = this.player
      if (!player || !this.isCurrentActivation(version, player)) {
        return
      }
      this.notifyPolicyReady()
      if (!this.isCurrentActivation(version, player)) {
        return
      }
      if (this.state === 'completed') {
        this.resetToBeginning()
      }
      await this.requestPlay(player, version, 'activate')
    } catch (error) {
      if (this.isCurrentActivation(version) && this.state !== 'error') {
        this.fail(error)
      }
    }
  }

  private async requestPlay(player: NativeAVPlayer, version: number, source: string): Promise<void> {
    const pauseTask = this.pauseTask
    if (pauseTask) {
      await pauseTask
    }
    if (!this.isCurrentActivation(version, player) || this.playRequested ||
      (this.state === 'playing' && !this.playbackEnded)) {
      return
    }
    const requestedState = player.state
    this.playRequested = true
    this.playbackEnded = false
    try {
      await player.play()
    } catch (error) {
      const current = this.isCurrentActivation(version, player)
      salmonLogger.addLog(TAG,
        `play request failed: item=${this.item.date}, source=${source}, state=${requestedState}->${player.state}, ` +
          `activation=${version}/${this.activationVersion}, active=${this.active}, current=${current}, ${error}`, true)
      if (!current) {
        return
      }
      this.playRequested = false
      // 已确认在播放的实例，不应被随后返回的命令拒绝覆盖为媒体错误。
      if (player.state !== 'playing') {
        this.fail(error, player)
      }
    }
  }

  /** EOF 策略已完成定位，不复用尚未结束的首次 playTask，也不重置到片头。 */
  resumeAfterPolicySeek(): void {
    const player = this.player
    if (!this.active || this.disposed || !player) {
      return
    }
    this.playbackEnded = false
    void this.requestPlay(player, this.activationVersion, 'policy')
  }

  async toggle(): Promise<void> {
    if (!this.player || !this.active || this.disposed) {
      return
    }
    if (this.state === 'playing' || this.playRequested || this.activating) {
      await this.pause()
    } else {
      await this.setActive(true)
    }
  }

  seek(position: number): void {
    if (!this.active || this.disposed || !this.player || this.duration <= 0 || !Number.isFinite(position)) {
      return
    }
    const player = this.player
    const target = Math.max(0, Math.min(position, this.duration))
    this.playbackPolicy?.onSeek(target)
    if (!this.active || this.disposed || this.player !== player) {
      return
    }
    this.currentTime = target
    this.onPlaybackStateChanged(this.state === 'playing', target)
    try {
      player.seek(target, media.SeekMode.SEEK_CLOSEST)
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
    // 暂停也结束当前起播意图，避免旧 prepare/play 在暂停后继续生效。
    this.activationVersion++
    this.activating = false
    const player = this.player
    const shouldPause = this.playRequested || this.state === 'playing'
    this.playRequested = false
    if (this.pauseTask) {
      return this.pauseTask
    }
    if (!player || !shouldPause) {
      return
    }
    const task = this.pauseInternal(player)
    this.pauseTask = task
    try {
      await task
    } finally {
      if (this.pauseTask === task) {
        this.pauseTask = undefined
      }
    }
  }

  private async pauseInternal(player: NativeAVPlayer): Promise<void> {
    try {
      await player.pause()
      if (!this.disposed && this.player === player && player.state !== 'error') {
        this.state = 'paused'
      }
    } catch (error) {
      salmonLogger.addLog(TAG, `pause failed: ${error}`, true)
    }
  }

  saveHistory(skipHistory: boolean = this.skipHistory): void {
    const position = this.playbackPositionMs
    if (!this.hasBeenActive || skipHistory || !Number.isFinite(position) || position <= 0 ||
      position === this.lastSavedTime) {
      return
    }
    try {
      MediaLibraryService.saveVideoPlayTimeIfNeed(position, this.item, false, PathUtils.appContext!)
      this.lastSavedTime = position
    } catch (_error) {
      salmonLogger.addLog(TAG, `保存播放记录失败: videoId=${this.item.date}`, true)
    }
  }

  async release(skipHistory: boolean = false): Promise<void> {
    if (this.disposed) {
      return
    }
    this.disposed = true
    this.activationVersion++
    this.activating = false
    this.playRequested = false
    this.playbackPolicy = undefined
    this.readyPlayer = undefined
    this.readyPolicy = undefined
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
      const oldPlayer = this.player
      this.player = undefined
      if (oldPlayer) {
        this.unregisterCallbacks(oldPlayer)
        await oldPlayer.release()
      }
      if (this.disposed) return
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
        await player.setUrlSource(url, this.smbPlayback.headers(this.item.network_http_headers, this.item.network_custom_headers, this.item.network_user_agent))
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
          player.setLoudnessGain(Preferences.getLoudnessGain(PathUtils.appContext!)).catch(() => {
            salmonLogger.addLog(TAG, '恢复响度失败', true)
          })
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
          const wasActive = this.active
          const policyHandledReady = this.active && this.playbackPolicy ? this.notifyPolicyReady() : false
          if (!this.disposed && this.player === player && (!wasActive || this.active) && !policyHandledReady) {
            this.seekToRememberedPosition(player)
          }
          this.preparedResolver?.()
          this.clearPrepareCallbacks()
          break
        case 'playing':
          this.playRequested = false
          this.activating = false
          this.errorMessage = ''
          this.state = 'playing'
          this.playbackEnded = false
          if (this.active) {
            this.onPlaybackStateChanged(true, this.currentTime)
          }
          if (this.playbackRate !== 1) {
            this.setPlaybackRate(this.playbackRate)
          }
          if (!this.active && !this.pauseTask) {
            void this.pause()
          }
          break
        case 'paused':
          this.state = 'paused'
          if (this.active) {
            this.onPlaybackStateChanged(false, this.currentTime)
          }
          break
        case 'completed':
          this.playRequested = false
          this.activating = false
          this.playbackEnded = true
          if (!this.active) {
            return
          }
          if (this.playbackPolicy?.onCompleted() || !this.active || this.disposed || this.player !== player) {
            return
          }
          this.state = 'completed'
          this.currentTime = this.duration || this.item.time
          this.playbackPositionMs = this.currentTime
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
      if (!Number.isFinite(time) || time < 0) {
        return
      }
      this.playbackPositionMs = time
      this.currentTime = time
      if (!this.active) {
        return
      }
      this.playbackPolicy?.onPosition(time)
      if (!this.active || this.disposed || this.player !== player) {
        return
      }
      this.onPlaybackStateChanged(this.state === 'playing', this.currentTime)
    })
    player.on('seekDone', (position: number) => {
      if (this.disposed || this.player !== player || !Number.isFinite(position) || position < 0) {
        return
      }
      this.playbackPositionMs = position
      this.currentTime = position
      if (!this.active) {
        return
      }
      this.playbackPolicy?.onSeekDone(position)
      if (!this.active || this.disposed || this.player !== player) {
        return
      }
      this.onPlaybackStateChanged(this.state === 'playing', position)
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
      player.off('seekDone')
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
    return totalTime > 0 && this.playbackPositionMs > totalTime * 0.95
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
    this.playRequested = false
    if (!this.playTask) {
      this.activating = false
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
