import { SleepTimerController } from './SleepTimerController'
import { AbLoopController } from './AbLoopController'
import { PlaybackPolicyCallbacks, PlaybackPolicyHost } from './PlaybackPolicyInterface'
import { Setting } from '../utils/ObservedUtil'
import MediaLibraryService from '../utils/MediaLibraryService'
import { PlaybackOpeningEndingRange } from './PlaybackOpeningEndingRange'
import { SweetRepeatMode } from '../common/enum/SweetRepeatMode'

/** 普通与短视频共用；只依赖当前播放项，不持有播放列表或原生内核。 */
@ObservedV2
export class PlaybackPolicyController {
  readonly sleepTimer: SleepTimerController = new SleepTimerController()
  readonly abLoop: AbLoopController = new AbLoopController()
  readonly openingEnding: PlaybackOpeningEndingRange = new PlaybackOpeningEndingRange()
  onAbLoopFailed: () => void = (): void => {}
  private policyPlayer: PlaybackPolicyHost | undefined = undefined
  private policySeeking: boolean = false
  private playerReady: boolean = false
  private nativeLoopApplied: boolean = false
  private nativeLoopNeedsRestore: boolean = false
  private abSeekTimer: number | undefined = undefined
  private abSeekVersion: number = 0
  private pendingEofResume: boolean = false
  private closing: boolean = false
  private endingHandled: boolean = false

  get isClosing(): boolean { return this.closing }

  refresh(): void {
    if (this.policyPlayer) { this.syncMedia(this.policyPlayer) }
  }

  bindPlayer(player: PlaybackPolicyHost): void {
    if (this.isClosing) { return }
    if (this.policyPlayer && this.policyPlayer !== player) {
      this.detachPlayer(this.policyPlayer)
    }
    this.policyPlayer = player
    this.playerReady = false
    this.syncMedia(player)
    const callbacks: PlaybackPolicyCallbacks = {
      onPosition: (positionMs: number): boolean => this.onPosition(player, positionMs),
      onCompleted: (): boolean => this.onCompleted(player),
      onSeek: (targetMs: number): void => {
        if (!this.isActive(player) || this.policySeeking) { return }
        this.syncMedia(player)
        if (this.sleepTimer.checkDeadline() || this.isClosing) { return }
        this.abLoop.onUserSeekCommitted(targetMs)
        this.cancelAbSeekTimer()
        this.clearNativeLoop(player)
        this.nativeLoopNeedsRestore = this.abLoop.enabled
        if (this.abLoop.enabled) {
          this.abLoop.markSeekPending()
          this.scheduleAbSeekTimeout(player)
        }
      },
      onSeekStart: (): void => {
        if (!this.isActive(player) || !this.abLoop.enabled) { return }
        this.abLoop.onUserSeekStarted()
        this.cancelAbSeekTimer()
        this.clearNativeLoop(player)
        this.nativeLoopNeedsRestore = true
      },
      onMediaChanged: (): void => {
        if (!this.isActive(player)) { return }
        this.clearNativeLoop(player)
        this.cancelAbSeekTimer()
        this.nativeLoopNeedsRestore = false
        this.playerReady = false
        this.syncMedia(player)
      },
      onSeekDone: (positionMs: number): void => {
        if (!this.isActive(player)) { return }
        this.abLoop.seekDone(positionMs)
        this.restoreNativeAfterSeek(player, positionMs)
      },
      onReady: (initialPositionMs?: number): boolean => {
        if (!this.isActive(player)) { return true }
        this.syncMedia(player)
        if (this.sleepTimer.checkDeadline() || this.isClosing) { return true }
        this.playerReady = true
        this.endingHandled = false
        this.applyNativeLoop(player)
        if (!this.abLoop.enabled) { return false }
        const position = initialPositionMs ?? player.initialPlayTime ?? player.playbackPositionMs
        this.abLoop.markSeekPending()
        this.seekForLoop(player, position >= this.abLoop.pointA && position < this.abLoop.pointB ?
          position : this.abLoop.pointA)
        return true
      }
    }
    player.playbackPolicy = callbacks
  }

  /** 元数据监视器与引擎回调共用，手动切片立即取消“播完本集”。 */
  syncMedia(player: PlaybackPolicyHost): void {
    if (!this.isActive(player)) { return }
    const metadata = player.nowPlaying
    const baseKey = metadata?.date ?? metadata?.uri ?? ''
    const key = metadata?.bluray_title_id !== undefined ? `${baseKey}:bd:${metadata.bluray_title_id}` : baseKey
    const changed = key !== this.abLoop.mediaKey
    if (changed) {
      this.clearNativeLoop(player)
      this.cancelAbSeekTimer()
      this.nativeLoopNeedsRestore = false
      this.playerReady = false
      this.endingHandled = false
    }
    const duration = player.durationMs !== undefined && player.durationMs > 0 ? player.durationMs :
      (metadata && metadata.time > 0 ? metadata.time : (changed ? 0 : this.abLoop.durationMs))
    const pointA = metadata?.pointA ?? 0
    const pointB = metadata?.pointB ?? 0
    if (changed || pointA !== this.abLoop.pointA || pointB !== this.abLoop.pointB ||
      duration !== this.abLoop.durationMs) {
      this.abLoop.bindMedia(key, pointA, pointB, duration)
    }
    if (changed) { this.sleepTimer.onMediaChanged(key) }
    this.openingEnding.bind(metadata, duration, Number(Setting.skipIntroTime) * 1000,
      Number(Setting.skipOutroTime) * 1000)
  }

  stopAfterCurrent(): void {
    const player = this.policyPlayer
    if (!player || this.isClosing) { return }
    this.syncMedia(player)
    if (this.sleepTimer.checkDeadline() || this.isClosing) { return }
    this.abLoop.disable()
    this.cancelAbSeekTimer()
    this.nativeLoopNeedsRestore = false
    this.clearNativeLoop(player)
    this.sleepTimer.stopAfterCurrent(this.abLoop.mediaKey)
  }

  toggleAbLoop(): boolean {
    const player = this.policyPlayer
    if (!player || this.isClosing) { return false }
    this.syncMedia(player)
    if (this.sleepTimer.checkDeadline() || this.isClosing) { return false }
    if (this.abLoop.enabled) {
      this.abLoop.disable()
      this.cancelAbSeekTimer()
      this.nativeLoopNeedsRestore = false
      this.clearNativeLoop(player)
      return true
    }
    if (!this.abLoop.enable(player.playbackPositionMs)) { return false }
    if (this.sleepTimer.mode === 'end-current') { this.sleepTimer.cancel() }
    this.applyNativeLoop(player)
    if (this.playerReady && (player.playbackPositionMs < this.abLoop.pointA ||
      player.playbackPositionMs >= this.abLoop.pointB)) {
      this.seekLoopStart(player)
    }
    return true
  }

  saveAbPoint(context: Context, point: 'A' | 'B' | 'clear'): boolean {
    const player = this.policyPlayer
    if (!player || this.isClosing || !player.nowPlaying) { return false }
    this.syncMedia(player)
    if (this.sleepTimer.checkDeadline() || this.isClosing) { return false }
    const position = player.playbackPositionMs
    if (point !== 'clear' && (!Number.isFinite(position) || position < 0 ||
      this.abLoop.durationMs <= 0 || position > this.abLoop.durationMs)) { return false }
    const pointA = point === 'clear' ? 0 : (point === 'A' ? position : this.abLoop.pointA)
    const pointB = point === 'clear' ? 0 : (point === 'B' ? position : this.abLoop.pointB)
    // 一次保存两个点，失败时不先更新界面或循环状态。
    MediaLibraryService.saveData(context, player.nowPlaying, { pointA: pointA, pointB: pointB })
    player.nowPlaying.pointA = pointA
    player.nowPlaying.pointB = pointB
    if (point === 'clear') { this.abLoop.clear() }
    else if (point === 'A') { this.abLoop.setA(pointA) }
    else { this.abLoop.setB(pointB) }
    this.cancelAbSeekTimer()
    this.nativeLoopNeedsRestore = false
    this.applyNativeLoop(player)
    if (this.abLoop.enabled && this.playerReady && (position < pointA || position >= pointB)) {
      this.seekLoopStart(player)
    }
    return true
  }

  saveAbRange(context: Context, start: number, end: number): boolean {
    const player = this.policyPlayer
    if (!player || this.isClosing || !player.nowPlaying) { return false }
    this.syncMedia(player)
    if (this.sleepTimer.checkDeadline() || this.isClosing ||
      (!(start === 0 && end === 0) && !PlaybackOpeningEndingRange.valid(start, end, this.abLoop.durationMs, false))) {
      return false
    }
    MediaLibraryService.saveData(context, player.nowPlaying, { pointA: start, pointB: end })
    player.nowPlaying.pointA = start
    player.nowPlaying.pointB = end
    this.abLoop.setRange(start, end)
    this.cancelAbSeekTimer()
    this.nativeLoopNeedsRestore = false
    this.applyNativeLoop(player)
    if (this.abLoop.enabled && this.playerReady && (player.playbackPositionMs < start ||
      player.playbackPositionMs >= end)) { this.seekLoopStart(player) }
    return true
  }

  saveOpeningEnding(context: Context, start: number, end: number): boolean {
    const player = this.policyPlayer
    if (!player || this.isClosing || !player.nowPlaying) { return false }
    this.syncMedia(player)
    if (this.sleepTimer.checkDeadline() || this.isClosing ||
      (!(start === 0 && end === 0) && !PlaybackOpeningEndingRange.valid(start, end, this.abLoop.durationMs, true))) {
      return false
    }
    MediaLibraryService.saveData(context, player.nowPlaying, { startTime: start, endTime: end })
    player.nowPlaying.start_time = start
    player.nowPlaying.end_time = end
    player.nowPlaying.end_time_is_duration = false
    this.syncMedia(player)
    return true
  }

  saveOpeningEndingPoint(context: Context, point: 'start' | 'end' | 'clear'): boolean {
    const player = this.policyPlayer
    if (!player || this.isClosing) { return false }
    this.syncMedia(player)
    if (point === 'clear') { return this.saveOpeningEnding(context, 0, 0) }
    return this.saveOpeningEnding(context,
      point === 'start' ? player.playbackPositionMs : this.openingEnding.startTime,
      point === 'end' ? player.playbackPositionMs : this.openingEnding.endTime)
  }

  private isActive(player: PlaybackPolicyHost): boolean {
    return this.policyPlayer === player && !this.isClosing
  }

  private onPosition(player: PlaybackPolicyHost, positionMs: number): boolean {
    if (!this.isActive(player)) { return true }
    this.syncMedia(player)
    if (this.sleepTimer.checkDeadline() || this.isClosing) { return true }
    const duration = this.abLoop.durationMs
    // 单项列表循环/手动重播可能复用同一个播放器和媒体，收到回到正文的位置才开启下一轮片尾处理。
    if (this.endingHandled && positionMs < this.openingEnding.outroStartMs) { this.endingHandled = false }
    const effectiveEnd = this.openingEnding.outroStartMs || duration
    if (player.playing && effectiveEnd > 0 && positionMs >= effectiveEnd &&
      this.sleepTimer.consumeMediaEnd(this.abLoop.mediaKey)) { return true }
    const wasPending = this.abLoop.enabled && this.abLoop.isSeekPending
    const target = this.abLoop.onPosition(positionMs, player.playing,
      player.onSwiping || player.isSliderPlayTimeChange)
    if (wasPending && !this.abLoop.enabled) {
      this.failAbSeek(player)
      return true
    }
    if (target !== undefined) { this.seekForLoop(player, target) }
    this.restoreNativeAfterSeek(player, positionMs)
    if (!this.abLoop.enabled && this.nativeLoopApplied) { this.clearNativeLoop(player) }
    if (!this.abLoop.enabled && player.finishAtEnding && player.playing && !player.onSwiping &&
      !player.isSliderPlayTimeChange && player.repeatMode !== SweetRepeatMode.SINGLE &&
      this.openingEnding.outroStartMs > 0 && positionMs >= this.openingEnding.outroStartMs && !this.endingHandled) {
      this.endingHandled = true
      player.finishAtEnding()
    }
    return this.abLoop.enabled || player.finishAtEnding !== undefined
  }

  private onCompleted(player: PlaybackPolicyHost): boolean {
    if (!this.isActive(player)) { return true }
    this.syncMedia(player)
    if (this.sleepTimer.checkDeadline() || this.isClosing ||
      this.sleepTimer.consumeMediaEnd(this.abLoop.mediaKey)) { return true }
    if (this.endingHandled) { return true }
    const wasPending = this.abLoop.enabled && this.abLoop.isSeekPending
    const target = this.abLoop.onCompleted()
    if (wasPending && !this.abLoop.enabled) {
      this.failAbSeek(player)
      return true
    }
    if (target !== undefined) {
      this.seekForLoop(player, target)
    }
    // timeUpdate(B) 可能已先提交 seek；completed 仍须恢复播放，且只提交一次。
    if (this.abLoop.enabled && this.abLoop.isSeekPending && !this.pendingEofResume) {
      this.pendingEofResume = true
      player.play()
    }
    // pending seek 期间也消费完成事件，不能误写“已看完”或切片。
    return this.abLoop.enabled
  }

  private seekLoopStart(player: PlaybackPolicyHost): void {
    this.abLoop.markSeekPending()
    this.seekForLoop(player, this.abLoop.pointA)
  }

  private seekForLoop(player: PlaybackPolicyHost, positionMs: number): void {
    this.policySeeking = true
    try {
      player.seekTime(positionMs)
      this.scheduleAbSeekTimeout(player)
    }
    finally { this.policySeeking = false }
  }

  private restoreNativeAfterSeek(player: PlaybackPolicyHost, positionMs: number): void {
    if (!this.abLoop.isSeekPending) { this.cancelAbSeekTimer() }
    if (this.nativeLoopNeedsRestore && this.abLoop.enabled && !this.abLoop.isSeekPending &&
      !player.onSwiping && !player.isSliderPlayTimeChange && positionMs >= this.abLoop.pointA &&
      positionMs < this.abLoop.pointB) {
      this.nativeLoopNeedsRestore = false
      this.applyNativeLoop(player)
    }
  }

  private scheduleAbSeekTimeout(player: PlaybackPolicyHost): void {
    this.cancelAbSeekTimer()
    if (!this.abLoop.isSeekPending) { return }
    const mediaKey = this.abLoop.mediaKey
    const version = this.abSeekVersion
    this.abSeekTimer = setTimeout((): void => {
      if (version !== this.abSeekVersion) { return }
      this.abSeekTimer = undefined
      if (!this.isActive(player) || this.abLoop.mediaKey !== mediaKey || !this.abLoop.isSeekPending) { return }
      // EOF 后可能再无进度回调，仍须结束无响应的跳转，避免卡在“循环中”。
      this.failAbSeek(player)
    }, 5000)
  }

  private failAbSeek(player: PlaybackPolicyHost): void {
    this.cancelAbSeekTimer()
    this.abLoop.disable()
    this.nativeLoopNeedsRestore = false
    this.clearNativeLoop(player)
    player.pause()
    this.onAbLoopFailed()
  }

  private cancelAbSeekTimer(): void {
    this.abSeekVersion++
    this.pendingEofResume = false
    if (this.abSeekTimer !== undefined) {
      clearTimeout(this.abSeekTimer)
      this.abSeekTimer = undefined
    }
  }

  private applyNativeLoop(player: PlaybackPolicyHost): void {
    if (this.playerReady && this.abLoop.enabled) {
      this.nativeLoopApplied = player.setABLoop(this.abLoop.pointA, this.abLoop.pointB)
      this.abLoop.setNativeLoopActive(this.nativeLoopApplied)
    } else {
      this.clearNativeLoop(player)
    }
  }

  private clearNativeLoop(player: PlaybackPolicyHost): void {
    if (this.nativeLoopApplied) { player.setABLoop() }
    this.nativeLoopApplied = false
    this.abLoop.setNativeLoopActive(false)
  }

  detachPlayer(player: PlaybackPolicyHost): void {
    this.clearNativeLoop(player)
    this.cancelAbSeekTimer()
    this.nativeLoopNeedsRestore = false
    // 已入队的旧回调仍会命中 isActive，但不会操作新播放器。
    this.policyPlayer = undefined
    this.playerReady = false
  }

  beginClosing(): void {
    this.closing = true
    this.sleepTimer.cancel()
    this.abLoop.disable()
    this.cancelAbSeekTimer()
    this.nativeLoopNeedsRestore = false
    if (this.policyPlayer) { this.clearNativeLoop(this.policyPlayer) }
  }

  dispose(): void {
    this.beginClosing()
    this.sleepTimer.dispose()
    if (this.policyPlayer) { this.policyPlayer.playbackPolicy = undefined }
    this.policyPlayer = undefined
  }
}

