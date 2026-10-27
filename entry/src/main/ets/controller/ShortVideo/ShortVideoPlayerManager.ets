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
import { PlaybackPolicyController } from '../PlaybackPolicyController'
import { PlaybackPolicyCallbacks, PlaybackPolicyHost } from '../PlaybackPolicyInterface'
import { salmonLogger } from 'salmonlogger'

/** 适配当前短视频，不让相邻预加载项或进度预览成为策略的数据源。 */
class ShortVideoPolicyHost implements PlaybackPolicyHost {
  readonly player: ShortVideoPlayer
  private manager: ShortVideoPlayerManager

  constructor(player: ShortVideoPlayer, manager: ShortVideoPlayerManager) {
    this.player = player
    this.manager = manager
  }

  get nowPlaying(): VideoMetadata {
    return this.player.item
  }

  get playbackPositionMs(): number {
    return this.player.playbackPositionMs
  }

  get durationMs(): number {
    return this.player.duration
  }

  get repeatMode(): SweetRepeatMode {
    return this.manager.repeatMode
  }

  get playing(): boolean {
    return this.player.state === 'playing'
  }

  get onSwiping(): boolean {
    return this.manager.onSwiping
  }

  get isSliderPlayTimeChange(): boolean {
    return this.manager.isProgressSeeking
  }

  get initialPlayTime(): number | undefined {
    return undefined
  }

  get playbackPolicy(): PlaybackPolicyCallbacks | undefined {
    return this.player.playbackPolicy
  }

  set playbackPolicy(callbacks: PlaybackPolicyCallbacks | undefined) {
    this.player.playbackPolicy = callbacks
  }

  seekTime(positionMs: number): void {
    this.player.seek(positionMs)
  }

  play(): void {
    this.player.resumeAfterPolicySeek()
  }

  pause(): void {
    void this.player.pause()
  }

  setABLoop(_pointAMs?: number, _pointBMs?: number): boolean {
    return false
  }

  finishAtEnding(): void {
    void this.player.finishAtEnding()
  }
}

@ObservedV2
export class ShortVideoPlayerManager implements PiPPlayerController {
  readonly policy: PlaybackPolicyController = new PlaybackPolicyController()
  private policyHost: ShortVideoPolicyHost | undefined = undefined
  private closing: boolean = false
  private pipTask: Promise<boolean> | undefined = undefined
  @Trace seekStartTime: number = 0
  @Trace selectedSpeed: number = 1
  @Trace onSwiping: boolean = false
  @Trace swipingTime: number = 0
  @Trace repeatMode: SweetRepeatMode = SweetRepeatMode.LIST
  @Trace currentIndex: number = -1
  @Trace currentTime: number = 0
  @Trace duration: number = 0
  @Trace showControl: boolean = true
  @Trace playbackItems: VideoMetadata[] = []
  private players: Map<number, ShortVideoPlayer> = new Map()
  private surfaceControllers: Map<number, XComponentController> = new Map()
  private items: VideoMetadata[] = []
  private itemIndices: Map<string, number> = new Map()
  private generation: number = 0
  private skipHistory: boolean = false
  private avSession: avSession.AVSession | undefined = undefined
  private sessionMetadataIndex: number = -1
  private lastSessionPosition: number = -1
  private lastSessionPlaying: boolean = false
  private progressSeeking: boolean = false
  private onCompleted: (index: number) => void = (_index: number) => {
  }

  get nowPlaying(): VideoMetadata | undefined {
    return this.items[this.currentIndex]
  }

  get isClosing(): boolean {
    return this.closing || this.policy.isClosing
  }

  get isProgressSeeking(): boolean {
    return this.progressSeeking
  }

  get playing(): boolean {
    return this.players.get(this.currentIndex)?.state === 'playing'
  }

  get currentPlayer(): ShortVideoPlayer | undefined {
    return this.players.get(this.currentIndex)
  }

  configure(items: VideoMetadata[], skipHistory: boolean, onCompleted: (index: number) => void,
    initialIndex: number = 0): void {
    this.items = items.slice()
    this.itemIndices.clear()
    this.items.forEach((item: VideoMetadata, index: number) => this.itemIndices.set(item.date, index))
    this.skipHistory = skipHistory
    this.onCompleted = onCompleted
    const savedSpeed = parseFloat(Preferences.getVideoSpeed(PathUtils.appContext!).replace('x', ''))
    this.selectedSpeed = VideoInfoUtil.videoSpeedListAll.includes(savedSpeed) ? savedSpeed : 1
    this.repeatMode = Preferences.getRepeatModeState(PathUtils.appContext!)
    this.rebuildPlaybackQueue(this.items[initialIndex])
    AVSessionUtil.applyAudioConcurrencyMode()
  }

  getItemIndex(item: VideoMetadata | undefined): number {
    return item ? this.itemIndices.get(item.date) ?? -1 : -1
  }

  getSwiperIndex(index: number): number {
    const item = this.items[index]
    return item ? this.playbackItems.findIndex((entry: VideoMetadata) => entry.date === item.date) : -1
  }

  getPlaybackIndex(swiperIndex: number): number {
    return this.getItemIndex(this.playbackItems[swiperIndex])
  }

  getOrCreate(index: number): ShortVideoPlayer | undefined {
    if (this.isClosing || index < 0 || index >= this.items.length) {
      return undefined
    }
    let player = this.players.get(index)
    if (!player) {
      player = new ShortVideoPlayer(this.items[index], this.skipHistory, () => this.handleCompleted(index),
        (playing: boolean, currentTime: number) => this.handlePlaybackStateChanged(index, playing, currentTime))
      player.setPlaybackRate(this.selectedSpeed)
      this.players.set(index, player)
      // Repeat 可以保留 Surface，而播放器已被缓存回收；重建时恢复现有绑定。
      const surfaceId = this.surfaceControllers.get(index)?.getXComponentSurfaceId()
      if (surfaceId) {
        player.bindSurface(surfaceId)
      }
    }
    return player
  }

  bindSurface(index: number, surfaceId: string, controller: XComponentController): void {
    if (this.isClosing) {
      return
    }
    const oldIndices = Array.from(this.surfaceControllers.keys())
    oldIndices.forEach((oldIndex: number) => {
      if (oldIndex !== index && this.surfaceControllers.get(oldIndex) === controller) {
        this.surfaceControllers.delete(oldIndex)
        this.releasePlayer(oldIndex)
      }
    })
    this.surfaceControllers.set(index, controller)
    const player = this.getOrCreate(index)
    player?.bindSurface(surfaceId)
    if (index === this.currentIndex) {
      if (player) {
        this.bindPolicy(player)
      }
      player?.setActive(true)
    } else if (this.currentIndex >= 0 && this.indexDistance(index, this.currentIndex) <= 1) {
      player?.prepare().catch(() => {
      })
    }
  }

  unbindSurface(controller: XComponentController): void {
    // 以 Controller 身份清理，避免复用节点的旧销毁回调删除新节点的绑定。
    const indices = Array.from(this.surfaceControllers.keys())
    indices.forEach((index: number) => {
      if (this.surfaceControllers.get(index) === controller) {
        this.surfaceControllers.delete(index)
        this.releasePlayer(index)
      }
    })
  }

  async activate(index: number): Promise<void> {
    if (this.isClosing || this.policy.sleepTimer.checkDeadline() || index < 0 || index >= this.items.length) {
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
    if (target) {
      this.bindPolicy(target)
    }
    this.currentTime = target?.currentTime || 0
    this.duration = target?.duration || this.items[index]?.time || 0
    const oldPlayer = this.players.get(oldIndex)
    if (oldPlayer && oldIndex !== index) {
      oldPlayer.setPlaybackRate(this.selectedSpeed)
      const deactivateTask: Promise<void> = oldPlayer.setActive(false)
      await deactivateTask
    }
    if (generation !== this.generation || this.isClosing) {
      return
    }
    if (oldIndex !== index || target?.state !== 'playing') {
      await target?.setActive(true)
    }
    if (generation !== this.generation || this.isClosing) {
      return
    }
    await this.updateBackgroundSession(index).catch((error: Error) => {
      salmonLogger.addLog('ShortVideoPlayerManager', `更新后台播放会话失败: ${error.message}`, true)
    })
    if (generation !== this.generation || this.isClosing) {
      return
    }
    this.preload(this.adjacentIndex(index, -1))
    this.preload(this.adjacentIndex(index, 1))
    await this.trim(index)
  }

  play(): void {
    if (this.isClosing || this.policy.sleepTimer.checkDeadline()) {
      return
    }
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
    player.playbackPolicy?.onSeekStart()
    this.seekStartTime = player.currentTime
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
      Math.min(this.seekStartTime + offsetX * timePerPixel, player.duration))
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
    player.playbackPolicy?.onSeekStart()
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
    if (this.pipTask) {
      return await this.pipTask
    }
    const task = this.startPipInternal()
    this.pipTask = task
    try {
      return await task
    } finally {
      if (this.pipTask === task) {
        this.pipTask = undefined
      }
    }
  }

  private async startPipInternal(): Promise<boolean> {
    if (this.isClosing || this.policy.sleepTimer.checkDeadline()) {
      return false
    }
    const generation = this.generation
    const index = this.currentIndex
    const controller = this.surfaceControllers.get(this.currentIndex)
    if (!controller || !this.nowPlaying) {
      return false
    }
    await PiPWindowUtil.createPipController(controller, this)
    if (this.isClosing || generation !== this.generation || index !== this.currentIndex) {
      if (PiPWindowUtil.playerController === this) {
        await PiPWindowUtil.destroyPipController()
      }
      return false
    }
    PiPWindowUtil.updateContentSize()
    await PiPWindowUtil.startPip()
    if (this.isClosing || generation !== this.generation || index !== this.currentIndex) {
      if (PiPWindowUtil.playerController === this) {
        await PiPWindowUtil.destroyPipController()
      }
      return false
    }
    return PiPWindowUtil.pipOpenState
  }

  async toggle(index: number): Promise<void> {
    if (this.isClosing || this.policy.sleepTimer.checkDeadline() || index !== this.currentIndex) {
      return
    }
    return this.players.get(index)?.toggle()
  }

  onScreenDoubleClick(index: number, tapX: number, screenWidth: number): void {
    handleScreenDoubleClick(tapX, screenWidth,
      () => this.toggle(index),
      () => this.backForward(),
      () => this.fastForward())
  }

  seek(index: number, position: number): void {
    if (this.isClosing || this.policy.sleepTimer.checkDeadline() || index !== this.currentIndex) {
      return
    }
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
    if (this.isClosing) {
      return
    }
    if (!VideoInfoUtil.videoSpeedListAll.includes(speed)) {
      return
    }
    this.selectedSpeed = speed
    this.players.get(this.currentIndex)?.setPlaybackRate(speed)
    AVSessionUtil.updatePlaybackSessionState(this.playing, this.currentTime, this.repeatMode, speed)
  }

  selectRepeatMode(repeatMode: SweetRepeatMode): void {
    if (this.isClosing) {
      return
    }
    if (repeatMode === this.repeatMode) {
      return
    }
    const rebuildQueue = repeatMode === SweetRepeatMode.RANDOM || this.repeatMode === SweetRepeatMode.RANDOM
    this.repeatMode = repeatMode
    if (rebuildQueue) {
      this.rebuildPlaybackQueue(this.nowPlaying)
    }
  }

  beginLongPress(index: number): void {
    if (this.isClosing) {
      return
    }
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
    this.beginClosing()
    AVSessionUtil.unbindPlayer(this)
    this.policy.dispose()
    try {
      await this.pipTask
    } catch (error) {
      salmonLogger.addLog('ShortVideoPlayerManager', `等待小窗创建结束失败: ${error}`, true)
    }
    ++this.generation
    try {
      Preferences.saveVideoSpeed(PathUtils.appContext!, `${this.selectedSpeed}x`)
      Preferences.saveRepeatModeState(PathUtils.appContext!, this.repeatMode)
    } catch (error) {
      salmonLogger.addLog('ShortVideoPlayerManager', `保存播放偏好失败: ${error}`, true)
    }
    try {
      if (PiPWindowUtil.playerController === this) {
        await PiPWindowUtil.destroyPipController()
      }
    } catch (error) {
      salmonLogger.addLog('ShortVideoPlayerManager', `关闭小窗失败: ${error}`, true)
    }
    const players = Array.from(this.players.values())
    this.players.clear()
    this.surfaceControllers.clear()
    this.avSession = undefined
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
    if (this.isClosing || index !== this.currentIndex) {
      return
    }
    // 随机模式已打乱 Swiper 队列，自动切换与上滑必须沿同一条队列前进。
    const nextItem = VideoOperateUtil.computeAdjacentVideo(this.playbackItems, this.items[index],
      this.repeatMode === SweetRepeatMode.RANDOM ? SweetRepeatMode.LIST : this.repeatMode, 'next')
    if (!nextItem) {
      return
    }
    const nextIndex = this.getItemIndex(nextItem)
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
    if (this.isClosing || index !== this.currentIndex) {
      return
    }
    const item = this.items[index]
    if (!this.progressSeeking && !this.onSwiping) {
      this.currentTime = currentTime
    }
    this.duration = this.players.get(index)?.duration || item?.time || 0
    if (item) {
      AppStorage.setOrCreate('nowPlayingData',
        [this.players.get(index)?.playbackPositionMs ?? 0, item, this.skipHistory])
    }
    const playbackStateChanged = playing !== this.lastSessionPlaying
    if (playbackStateChanged || this.lastSessionPosition < 0) {
      this.lastSessionPlaying = playing
      this.lastSessionPosition = currentTime
      AVSessionUtil.updatePlaybackSessionState(playing, currentTime, this.repeatMode, this.selectedSpeed)
    }
  }

  private async updateBackgroundSession(index: number): Promise<void> {
    const generation = this.generation
    if (this.isClosing || !Setting.allowBackgroundPlay) {
      return
    }
    if (!this.avSession || this.avSession !== AVSessionUtil.avSession) {
      const session = await AVSessionUtil.getAVSession()
      if (this.isClosing || generation !== this.generation || index !== this.currentIndex) {
        return
      }
      if (this.avSession !== session) {
        this.sessionMetadataIndex = -1
      }
      this.avSession = session
      if (!session) {
        return
      }
    }
    if (this.isClosing || generation !== this.generation || index !== this.currentIndex) {
      return
    }
    if (!AVSessionUtil.isPlayerBound(this.avSession, this)) {
      if (!this.setSessionListeners()) {
        return
      }
      this.sessionMetadataIndex = -1
    }
    if (this.sessionMetadataIndex !== index) {
      await AVSessionUtil.setSessionInfo(this.items[index], () => this.players.get(index)?.playbackPositionMs ?? 0, this)
      if (this.isClosing || generation !== this.generation || index !== this.currentIndex ||
        !AVSessionUtil.isPlayerBound(this.avSession, this)) {
        return
      }
      this.sessionMetadataIndex = index
    }
    if (this.isClosing || generation !== this.generation || index !== this.currentIndex ||
      !AVSessionUtil.isPlayerBound(this.avSession, this)) {
      return
    }
    const player = this.players.get(index)
    AVSessionUtil.updatePlaybackSessionState(player?.state === 'playing', player?.currentTime || 0,
      this.repeatMode, this.selectedSpeed)
  }

  private setSessionListeners(): boolean {
    return AVSessionUtil.bindPlayer(this.avSession, this, {
      play: () => this.play(),
      pause: () => this.pause(),
      seek: (position: number) => this.seek(this.currentIndex, position),
      fastForward: () => this.fastForward(),
      rewind: () => this.backForward(),
      outputDeviceChange: () => this.pause(),
      setLoopMode: (mode: avSession.LoopMode) => {
        this.selectRepeatMode(AVSessionUtil.getRepeatModeFromAvSession(mode))
        Preferences.saveRepeatModeState(PathUtils.appContext!, this.repeatMode)
        AVSessionUtil.updatePlaybackSessionState(this.playing, this.currentPlayer?.currentTime || 0,
          this.repeatMode, this.selectedSpeed)
      }
    })
  }

  private preload(index: number): void {
    const player = this.players.get(index)
    player?.prepare().catch(() => {
    })
  }

  private isLoopingList(): boolean {
    return this.repeatMode === SweetRepeatMode.LIST || this.repeatMode === SweetRepeatMode.RANDOM
  }

  private rebuildPlaybackQueue(anchor: VideoMetadata | undefined): void {
    const anchorPosition = Math.max(0, this.getSwiperIndex(this.getItemIndex(anchor)))
    const queue = this.items.slice()
    if (this.repeatMode === SweetRepeatMode.RANDOM) {
      for (let index = queue.length - 1; index > 0; index--) {
        const randomIndex = Math.floor(Math.random() * (index + 1))
        const item = queue[index]
        queue[index] = queue[randomIndex]
        queue[randomIndex] = item
      }
      // 切换随机模式时保留当前视频的位置和播放器，不跳播或重建正在播放的 Surface。
      const shuffledAnchor = queue.findIndex((item: VideoMetadata) => item.date === anchor?.date)
      if (shuffledAnchor >= 0) {
        const item = queue[anchorPosition]
        queue[anchorPosition] = queue[shuffledAnchor]
        queue[shuffledAnchor] = item
      }
    }
    this.playbackItems = queue
  }

  private adjacentIndex(index: number, direction: number): number {
    const position = this.getSwiperIndex(index)
    if (position < 0) {
      return -1
    }
    const next = position + direction
    const target = this.isLoopingList() && this.playbackItems.length > 0 ?
      (next + this.playbackItems.length) % this.playbackItems.length : next
    return this.getPlaybackIndex(target)
  }

  private indexDistance(index: number, center: number): number {
    const position = this.getSwiperIndex(index)
    const centerPosition = this.getSwiperIndex(center)
    if (position < 0 || centerPosition < 0) {
      return this.items.length
    }
    const distance = Math.abs(position - centerPosition)
    return this.isLoopingList() ? Math.min(distance, this.playbackItems.length - distance) : distance
  }

  private releasePlayer(index: number): Promise<void> {
    const player = this.players.get(index)
    if (player && this.policyHost?.player === player) {
      this.policy.detachPlayer(this.policyHost)
      this.policyHost = undefined
    }
    this.players.delete(index)
    return player?.release(this.skipHistory) ?? Promise.resolve()
  }

  private async trim(center: number): Promise<void> {
    const releaseTasks: Promise<void>[] = []
    const indices = Array.from(this.players.keys())
    for (const index of indices) {
      const player = this.players.get(index)
      if (player && this.indexDistance(index, center) > 3) {
        // Surface 由列表项的 onDestroy/复用管理，不能随播放器缓存一起清掉。
        releaseTasks.push(this.releasePlayer(index))
      }
    }
    await Promise.all(releaseTasks)
  }

  private bindPolicy(player: ShortVideoPlayer): void {
    if (this.isClosing || this.policyHost?.player === player) {
      return
    }
    this.policyHost = new ShortVideoPolicyHost(player, this)
    this.policy.bindPlayer(this.policyHost)
  }

  beginClosing(): void {
    if (this.closing) {
      return
    }
    this.closing = true
    AVSessionUtil.unbindPlayer(this)
    ++this.generation
    this.policy.beginClosing()
    // 取消 active 意图，异步 prepared/play 回调不能在退出时恢复声音。
    this.players.forEach((player: ShortVideoPlayer) => {
      void player.setActive(false)
    })
  }
}
