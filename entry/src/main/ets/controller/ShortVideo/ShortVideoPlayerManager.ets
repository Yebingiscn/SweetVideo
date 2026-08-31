import { avSession } from '@kit.AVSessionKit'
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import Preferences from '../../database/Preferences'
import AVSessionUtil from '../../utils/AVSessionUtil'
import { Setting } from '../../utils/ObservedUtil'
import { PathUtils } from '../../utils/PathUtils'
import PiPWindowUtil, { PiPPlayerController } from '../../utils/PiPWindowUtil'
import VideoInfoUtil from '../../utils/VideoInfoUtil'
import VideoOperateUtil from '../../utils/VideoOperateUtil'
import { ShortVideoPlayer } from './ShortVideoPlayer'
import { SweetRepeatMode } from '../../common/enum/SweetRepeatMode'
import { handleScreenDoubleClick } from '../../common/GestureUtil'

@ObservedV2
export class ShortVideoPlayerManager implements PiPPlayerController {
  @Trace selectedSpeed: number = 1
  @Trace onSwiping: boolean = false
  @Trace swipingTime: number = 0
  @Trace repeatMode: SweetRepeatMode = SweetRepeatMode.LIST
  @Trace currentIndex: number = -1
  @Trace currentTime: number = 0
  @Trace duration: number = 0
  @Trace showControl: boolean = true
  private players: Map<number, ShortVideoPlayer> = new Map()
  private surfaceControllers: Map<number, XComponentController> = new Map()
  private items: VideoMetadata[] = []
  private generation: number = 0
  private skipHistory: boolean = false
  private avSession: avSession.AVSession | undefined = undefined
  private sessionListenersRegistered: boolean = false
  private sessionMetadataIndex: number = -1
  private lastSessionPosition: number = -1
  private lastSessionPlaying: boolean = false
  private progressSeeking: boolean = false
  private onCompleted: (index: number) => void = (_index: number) => {
  }

  get nowPlaying(): VideoMetadata | undefined {
    return this.items[this.currentIndex]
  }

  get playing(): boolean {
    return this.players.get(this.currentIndex)?.state === 'playing'
  }

  get currentPlayer(): ShortVideoPlayer | undefined {
    return this.players.get(this.currentIndex)
  }

  configure(items: VideoMetadata[], skipHistory: boolean, onCompleted: (index: number) => void): void {
    this.items = items
    this.skipHistory = skipHistory
    this.onCompleted = onCompleted
    const savedSpeed = parseFloat(Preferences.getVideoSpeed(PathUtils.appContext!).replace('x', ''))
    this.selectedSpeed = VideoInfoUtil.videoSpeedListAll.includes(savedSpeed) ? savedSpeed : 1
    this.repeatMode = Preferences.getRepeatModeState(PathUtils.appContext!)
    AVSessionUtil.applyAudioConcurrencyMode()
  }

  getOrCreate(index: number): ShortVideoPlayer | undefined {
    if (index < 0 || index >= this.items.length) {
      return undefined
    }
    let player = this.players.get(index)
    if (!player) {
      player = new ShortVideoPlayer(this.items[index], this.skipHistory, () => this.handleCompleted(index),
        (playing: boolean, currentTime: number) => this.handlePlaybackStateChanged(index, playing, currentTime))
      player.setPlaybackRate(this.selectedSpeed)
      this.players.set(index, player)
    }
    return player
  }

  bindSurface(index: number, surfaceId: string, controller: XComponentController): void {
    const oldIndices = Array.from(this.surfaceControllers.keys())
    oldIndices.forEach((oldIndex: number) => {
      if (oldIndex !== index && this.surfaceControllers.get(oldIndex) === controller) {
        this.surfaceControllers.delete(oldIndex)
      }
    })
    this.surfaceControllers.set(index, controller)
    const player = this.getOrCreate(index)
    player?.bindSurface(surfaceId)
    if (index === this.currentIndex) {
      player?.setActive(true)
    } else if (Math.abs(index - this.currentIndex) <= 1) {
      player?.prepare().catch(() => {
      })
    }
  }

  async activate(index: number): Promise<void> {
    if (index < 0 || index >= this.items.length) {
      return
    }
    this.onSwiping = false
    this.swipingTime = 0
    this.progressSeeking = false
    const generation = ++this.generation
    const oldIndex = this.currentIndex
    const target = this.getOrCreate(index)
    target?.setPlaybackRate(this.selectedSpeed)
    this.currentIndex = index
    this.currentTime = target?.currentTime || 0
    this.duration = target?.duration || this.items[index]?.time || 0
    const oldPlayer = this.players.get(oldIndex)
    if (oldPlayer && oldIndex !== index) {
      oldPlayer.setPlaybackRate(this.selectedSpeed)
      const deactivateTask: Promise<void> = oldPlayer.setActive(false)
      await deactivateTask
    }
    if (oldIndex !== index || target?.state !== 'playing') {
      await target?.setActive(true)
    }
    if (generation !== this.generation) {
      return
    }
    await this.updateBackgroundSession(index)
    this.preload(index - 1)
    this.preload(index + 1)
    await this.trim(index)
  }

  play(): void {
    this.players.get(this.currentIndex)?.setActive(true)
  }

  pause(): void {
    this.players.get(this.currentIndex)?.pause()
  }

  fastForward(): void {
    const player = this.players.get(this.currentIndex)
    if (player) {
      this.seek(this.currentIndex, player.currentTime + Number(Setting.fastForwardSeconds) * 1000)
    }
  }

  backForward(): void {
    const player = this.players.get(this.currentIndex)
    if (player) {
      this.seek(this.currentIndex, player.currentTime - Number(Setting.fastForwardSeconds) * 1000)
    }
  }

  beginHorizontalSeek(index: number): void {
    if (index !== this.currentIndex) {
      return
    }
    const player = this.players.get(index)
    if (!player || player.duration <= 0) {
      return
    }
    VideoOperateUtil.lastPlayTime = player.currentTime
    this.swipingTime = player.currentTime
    this.currentTime = player.currentTime
    this.onSwiping = true
  }

  updateHorizontalSeek(index: number, offsetX: number, screenWidth: number): void {
    if (!this.onSwiping || index !== this.currentIndex || screenWidth <= 0) {
      return
    }
    const player = this.players.get(index)
    if (!player || player.duration <= 0) {
      return
    }
    const timePerPixel = VideoOperateUtil.getTimePixel(screenWidth, player.duration)
    this.swipingTime = Math.max(0,
      Math.min(VideoOperateUtil.lastPlayTime + offsetX * timePerPixel, player.duration))
    this.currentTime = this.swipingTime
  }

  endHorizontalSeek(index: number): void {
    if (!this.onSwiping || index !== this.currentIndex) {
      return
    }
    const target = this.swipingTime
    this.onSwiping = false
    this.seek(index, target)
  }

  beginProgressSeek(): void {
    const player = this.players.get(this.currentIndex)
    if (!player || player.duration <= 0) {
      return
    }
    this.progressSeeking = true
    this.currentTime = player.currentTime
  }

  previewProgressSeek(position: number): void {
    if (!this.progressSeeking || this.duration <= 0) {
      return
    }
    this.currentTime = Math.max(0, Math.min(position, this.duration))
  }

  endProgressSeek(): void {
    if (!this.progressSeeking) {
      return
    }
    const target = this.currentTime
    this.progressSeeking = false
    this.seek(this.currentIndex, target)
  }

  async startPip(): Promise<boolean> {
    const controller = this.surfaceControllers.get(this.currentIndex)
    if (!controller || !this.nowPlaying) {
      return false
    }
    await PiPWindowUtil.createPipController(controller, this)
    PiPWindowUtil.updateContentSize()
    await PiPWindowUtil.startPip()
    return PiPWindowUtil.pipOpenState
  }

  async toggle(index: number): Promise<void> {
    return this.players.get(index)?.toggle()
  }

  onScreenDoubleClick(index: number, tapX: number, screenWidth: number): void {
    handleScreenDoubleClick(tapX, screenWidth,
      () => this.toggle(index),
      () => this.backForward(),
      () => this.fastForward())
  }

  seek(index: number, position: number): void {
    const player = this.players.get(index)
    if (!player) {
      return
    }
    const target = Math.max(0, player.duration > 0 ? Math.min(position, player.duration) : position)
    player.seek(target)
    if (index === this.currentIndex) {
      this.lastSessionPosition = target
      AVSessionUtil.updatePlaybackSessionState(this.playing, target, this.repeatMode, this.selectedSpeed)
    }
  }

  selectSpeed(speed: number): void {
    if (!VideoInfoUtil.videoSpeedListAll.includes(speed)) {
      return
    }
    this.selectedSpeed = speed
    this.players.get(this.currentIndex)?.setPlaybackRate(speed)
    AVSessionUtil.updatePlaybackSessionState(this.playing, this.currentTime, this.repeatMode, speed)
  }

  selectRepeatMode(repeatMode: SweetRepeatMode): void {
    this.repeatMode = repeatMode
  }

  beginLongPress(index: number): void {
    if (index === this.currentIndex) {
      this.players.get(index)?.setPlaybackRate(Setting.longPressSpeed)
      AVSessionUtil.updatePlaybackSessionState(this.playing, this.currentTime,
        this.repeatMode, Setting.longPressSpeed)
    }
  }

  endLongPress(index: number): void {
    this.players.get(index)?.setPlaybackRate(this.selectedSpeed)
    if (index === this.currentIndex) {
      AVSessionUtil.updatePlaybackSessionState(this.playing, this.currentTime,
        this.repeatMode, this.selectedSpeed)
    }
  }

  saveCurrentHistory(): void {
    this.players.get(this.currentIndex)?.saveHistory(this.skipHistory)
  }

  async pauseAll(): Promise<void> {
    const players = Array.from(this.players.values())
    players.forEach(player => player.setPlaybackRate(this.selectedSpeed))
    await Promise.all(players.map(player => player.pause()))
    this.saveCurrentHistory()
  }

  async releaseAll(): Promise<void> {
    ++this.generation
    Preferences.saveVideoSpeed(PathUtils.appContext!, `${this.selectedSpeed}x`)
    Preferences.saveRepeatModeState(PathUtils.appContext!, this.repeatMode)
    await PiPWindowUtil.destroyPipController()
    const players = Array.from(this.players.values())
    this.players.clear()
    this.surfaceControllers.clear()
    this.avSession = undefined
    this.sessionListenersRegistered = false
    this.sessionMetadataIndex = -1
    this.lastSessionPosition = -1
    this.lastSessionPlaying = false
    this.onSwiping = false
    this.swipingTime = 0
    this.progressSeeking = false
    this.currentTime = 0
    this.duration = 0
    this.showControl = false
    AppStorage.delete('nowPlayingData')
    await Promise.all(players.map(player => player.release(this.skipHistory)))
  }

  private handleCompleted(index: number): void {
    if (index !== this.currentIndex) {
      return
    }
    const nextItem = VideoOperateUtil.computeAdjacentVideo(this.items, this.items[index], this.repeatMode, 'next')
    if (!nextItem) {
      return
    }
    const nextIndex = this.items.findIndex((item: VideoMetadata) => item.date === nextItem.date)
    if (nextIndex < 0) {
      return
    }
    if (nextIndex === index) {
      this.players.get(index)?.setActive(true)
      return
    }
    this.onCompleted(nextIndex)
  }

  private handlePlaybackStateChanged(index: number, playing: boolean, currentTime: number): void {
    if (index !== this.currentIndex) {
      return
    }
    const item = this.items[index]
    if (!this.progressSeeking && !this.onSwiping) {
      this.currentTime = currentTime
    }
    this.duration = this.players.get(index)?.duration || item?.time || 0
    if (item) {
      AppStorage.setOrCreate('nowPlayingData', [currentTime, item, this.skipHistory])
    }
    const playbackStateChanged = playing !== this.lastSessionPlaying
    if (playbackStateChanged || this.lastSessionPosition < 0) {
      this.lastSessionPlaying = playing
      this.lastSessionPosition = currentTime
      AVSessionUtil.updatePlaybackSessionState(playing, currentTime, this.repeatMode, this.selectedSpeed)
    }
  }

  private async updateBackgroundSession(index: number): Promise<void> {
    if (!Setting.allowBackgroundPlay) {
      return
    }
    if (!this.avSession) {
      this.avSession = await AVSessionUtil.getAVSession()
    }
    if (!this.sessionListenersRegistered) {
      this.setSessionListeners()
    }
    if (this.sessionMetadataIndex !== index) {
      this.sessionMetadataIndex = index
      await AVSessionUtil.setSessionInfo(this.items[index])
    }
    const player = this.players.get(index)
    AVSessionUtil.updatePlaybackSessionState(player?.state === 'playing', player?.currentTime || 0,
      this.repeatMode, this.selectedSpeed)
  }

  private setSessionListeners(): void {
    try {
      this.avSession?.on('play', () => this.play())
      this.avSession?.on('pause', () => this.pause())
      this.avSession?.on('seek', (position: number) => this.seek(this.currentIndex, position))
      this.avSession?.on('fastForward', () => this.fastForward())
      this.avSession?.on('rewind', () => this.backForward())
      this.avSession?.on('outputDeviceChange', () => this.pause())
      this.avSession?.on('setLoopMode', (mode: avSession.LoopMode) => {
        this.repeatMode = AVSessionUtil.getRepeatModeFromAvSession(mode)
        Preferences.saveRepeatModeState(PathUtils.appContext!, this.repeatMode)
        AVSessionUtil.updatePlaybackSessionState(this.playing, this.currentPlayer?.currentTime || 0,
          this.repeatMode, this.selectedSpeed)
      })
      this.sessionListenersRegistered = true
    } catch (_error) {
      this.sessionListenersRegistered = false
    }
  }

  private preload(index: number): void {
    const player = this.players.get(index)
    player?.prepare().catch(() => {
    })
  }

  private async trim(center: number): Promise<void> {
    const releaseTasks: Promise<void>[] = []
    const indices = Array.from(this.players.keys())
    for (const index of indices) {
      const player = this.players.get(index)
      if (player && Math.abs(index - center) > 3) {
        this.players.delete(index)
        this.surfaceControllers.delete(index)
        releaseTasks.push(player.release(this.skipHistory))
      }
    }
    await Promise.all(releaseTasks)
  }
}
