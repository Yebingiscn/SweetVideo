import { PlayerEngine } from '../common/NavigationCommon'
import { SubtitleMode } from '../common/enum/SubtitleMode'
import { SweetRepeatMode } from '../common/enum/SweetRepeatMode'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import { PlayerControllerFactory, PlayerControllerInterface } from './PlayerControllerFactory'
import { salmonLogger } from 'salmonlogger'

const TAG = 'PlaybackSessionController'
const ENGINE_SWITCH_RELEASE_TIMEOUT = 1500

class PlaybackSessionSnapshot {
  nowPlaying: VideoMetadata | undefined = undefined
  videoMetaDataList: VideoMetadata[] = []
  playTime: number = 0
  playing: boolean = true
  skipHistory: boolean = false
  speed: number = 1
  repeatMode: SweetRepeatMode = SweetRepeatMode.LIST
  selectedText: string | undefined = undefined
  subtitleSelected: SubtitleMode = SubtitleMode.NONE
  screenWidth: number = 0
  screenHeight: number = 0
  playAreaWidth: number = 0
  playAreaHeight: number = 0
  angle: number = 0
  scaleFactor: number = 1
  translateX: number = 0
  translateY: number = 0
  showControl: boolean = false
  lockVisibility: boolean = false
  isLock: boolean = false

  static capture(player: PlayerControllerInterface, resumePlayback?: boolean): PlaybackSessionSnapshot {
    const snapshot = new PlaybackSessionSnapshot()
    snapshot.nowPlaying = player.nowPlaying
    snapshot.videoMetaDataList = player.videoMetaDataList
    snapshot.playTime = player.playTime
    snapshot.playing = resumePlayback ?? player.playing
    snapshot.skipHistory = player.skipHistory
    snapshot.speed = player.speed
    snapshot.repeatMode = player.repeatMode
    snapshot.selectedText = player.selectedText
    snapshot.subtitleSelected = player.subtitleSelected
    snapshot.screenWidth = player.screenWidth
    snapshot.screenHeight = player.screenHeight
    snapshot.playAreaWidth = player.playAreaWidth
    snapshot.playAreaHeight = player.playAreaHeight
    snapshot.angle = player.angle
    snapshot.scaleFactor = player.scaleFactor
    snapshot.translateX = player.translateX
    snapshot.translateY = player.translateY
    snapshot.showControl = player.showControl
    snapshot.lockVisibility = player.lockVisibility
    snapshot.isLock = player.isLock
    return snapshot
  }

  apply(player: PlayerControllerInterface): void {
    player.nowPlaying = this.nowPlaying
    player.videoMetaDataList = this.videoMetaDataList
    player.playTime = this.playTime
    player.initialPlayTime = this.playTime
    player.initialPlaying = this.playing
    player.skipHistory = this.skipHistory
    player.speed = this.speed
    player.repeatMode = this.repeatMode
    player.selectedText = this.selectedText
    player.subtitleSelected = this.subtitleSelected
    player.screenWidth = this.screenWidth
    player.screenHeight = this.screenHeight
    player.playAreaWidth = this.playAreaWidth
    player.playAreaHeight = this.playAreaHeight
    player.angle = this.angle
    player.scaleFactor = this.scaleFactor
    player.translateX = this.translateX
    player.translateY = this.translateY
    player.showControl = this.showControl
    player.lockVisibility = this.lockVisibility
    player.isLock = this.isLock
  }
}

export class PlaybackSessionController {
  private switchTask: Promise<PlayerControllerInterface> | undefined = undefined

  async switchEngine(currentPlayer: PlayerControllerInterface, targetEngine: string,
    resumePlayback?: boolean): Promise<PlayerControllerInterface> {
    if (this.isTargetEngine(currentPlayer, targetEngine)) {
      return currentPlayer
    }
    if (this.switchTask) {
      return await this.switchTask
    }
    const task = this.performSwitch(currentPlayer, targetEngine, resumePlayback)
    this.switchTask = task
    try {
      return await task
    } finally {
      if (this.switchTask === task) {
        this.switchTask = undefined
      }
    }
  }

  private async performSwitch(currentPlayer: PlayerControllerInterface, targetEngine: string,
    resumePlayback?: boolean): Promise<PlayerControllerInterface> {
    const snapshot = PlaybackSessionSnapshot.capture(currentPlayer, resumePlayback)
    currentPlayer.setEngineSwitchHandler(undefined)
    await this.releaseCurrentPlayer(currentPlayer)

    const nextPlayer = PlayerControllerFactory.createController(targetEngine)
    snapshot.apply(nextPlayer)
    return nextPlayer
  }

  private async releaseCurrentPlayer(currentPlayer: PlayerControllerInterface): Promise<void> {
    let releaseFinished = false
    const releaseTask = currentPlayer.release().then(() => {
      releaseFinished = true
    }).catch((error: Error) => {
      releaseFinished = true
      salmonLogger.addLog(TAG, `旧播放引擎释放失败: ${error.message}`, true)
    })
    await Promise.race([
      releaseTask,
      new Promise<void>((resolve) => {
        setTimeout(resolve, ENGINE_SWITCH_RELEASE_TIMEOUT)
      })
    ])
    if (!releaseFinished) {
      salmonLogger.addLog(TAG,
        `旧播放引擎释放超过${ENGINE_SWITCH_RELEASE_TIMEOUT}ms，继续切换，新引擎不再等待`, true)
    }
  }

  private isTargetEngine(player: PlayerControllerInterface, targetEngine: string): boolean {
    return targetEngine === PlayerEngine.MPV_PLAYER ? player.isMpvPlayer() : !player.isMpvPlayer()
  }
}
