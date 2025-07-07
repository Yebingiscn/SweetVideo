import {
  IMediaPlayer,
  IMediaPlayerStateListener,
  PlayerCoreType,
  RedPlayerDataSource,
  RedPlayerFactory
} from '@rte-xhs/redplayer';
import display from '@ohos.display';
import RedPlayerStateHolder from '../common/RedPlayerStateHolder';

export default class RedPlayerControllerUtil implements IMediaPlayerStateListener {
  static TAG = "RedPlayerControllerUtil"
  redPlayerStateHolder: RedPlayerStateHolder
  dataSource: RedPlayerDataSource | undefined
  private player: IMediaPlayer | null = null

  constructor(redStateHolder: RedPlayerStateHolder) {
    this.redPlayerStateHolder = redStateHolder
  }

  public createMediaPlayer(coreType: PlayerCoreType) {
    return RedPlayerFactory.createMediaPlayer(this, coreType).then((player) => {
      this.player = player
    })
  }

  public setDataSource(dataSource: RedPlayerDataSource): Promise<void> | undefined {
    this.dataSource = dataSource
    return this.player?.setDataSource(dataSource)
  }

  public setSurfaceId(id: string) {
    this.player?.setSurfaceId(id)
  }

  public prepare(): Promise<void> | undefined {
    return this.player?.prepare()
  }

  public start() {
    this.player?.start()
  }

  public pause() {
    this.player?.pause()
  }

  public stop() {
    this.player?.stop()
  }

  public release() {
    this.player?.release()
  }

  public seek(time: number) {
    if (this.dataSource?.isLive != true) {
      this.player?.seek(time)
      console.log(RedPlayerControllerUtil.TAG + " seek " + time)
    }
  }

  public setSpeed(speed: number) {
    this.player?.setSpeed(speed)
    console.log(RedPlayerControllerUtil.TAG + " setSpeed " + speed)
  }

  public setVolume(volume: number) {
    this.player?.setVolume(volume)
  }

  onPlayerCreated() {
  }

  onInitialized() {
  }

  onPrepared() {
    if (this.redPlayerStateHolder && this.player) {
      this.redPlayerStateHolder.videoDuration = this.player.getVideoDuration()
      this.getVideoSize()
    }
    if (this.dataSource && this.dataSource.isAutoStart) {
      this.redPlayerStateHolder.isStart = true
    }
    console.log("onPrepared " + "video width * height:" + this.player?.getVideoWidth() + " * " +
    this.player?.getVideoHeight())
  }

  public getVideoSize() {
    if (this.redPlayerStateHolder && this.player) {
      let width = this.player.getVideoWidth()
      let height = this.player.getVideoHeight()
      this.redPlayerStateHolder.videoWidth = width
      this.redPlayerStateHolder.videoHeight = height
      this.redPlayerStateHolder.url = this.player.getUrl()
      this.redPlayerStateHolder.videoCodec = this.player.getVideoCodecInfo()
      this.redPlayerStateHolder.audioCodec = this.player.getAudioCodecInfo()

      let screenWidth = display.getDefaultDisplaySync().width
      let screenHeight = display.getDefaultDisplaySync().height

      this.redPlayerStateHolder.videoViewHeight = this.player.getVideoHeight()
      let videoRatio = width / height
      let screenRatio = screenWidth / screenHeight
      if (videoRatio > screenRatio) {
        this.redPlayerStateHolder.videoWidth = screenWidth
        this.redPlayerStateHolder.videoHeight = this.redPlayerStateHolder.videoWidth * (height / height)
        this.redPlayerStateHolder.videoViewWidth = screenWidth + 'px'
        this.redPlayerStateHolder.videoViewHeight = screenWidth / videoRatio + 'px'
      } else {
        this.redPlayerStateHolder.videoHeight = screenHeight
        this.redPlayerStateHolder.videoWidth = this.redPlayerStateHolder.videoHeight * (width / height)
        this.redPlayerStateHolder.videoViewHeight = screenHeight + 'px'
        this.redPlayerStateHolder.videoViewWidth = screenHeight * videoRatio + 'px'
      }
    }
  }

  onStarted() {
    console.log(RedPlayerControllerUtil.TAG + " onStarted ")
    this.redPlayerStateHolder.isStart = true
  }

  onFirstFrameRendered() {
    console.log(RedPlayerControllerUtil.TAG + " onFirstFrameRendered ")
  }

  onPositionUpdated(time: number) {
    console.log(RedPlayerControllerUtil.TAG + " onPositionUpdated " + time)
    if (this.redPlayerStateHolder) {
      this.redPlayerStateHolder.videoPosition = time
    }
  }

  onPaused() {
    console.log(RedPlayerControllerUtil.TAG + " onPaused ")
    this.redPlayerStateHolder.isStart = false
  }

  onStopped() {
    console.log(RedPlayerControllerUtil.TAG + " onStopped ")
    this.redPlayerStateHolder.isStart = false
  }

  onCompleted() {
    console.log(RedPlayerControllerUtil.TAG + " onCompleted ")
    if (this.dataSource && this.dataSource.isAutoLoop) {
      this.redPlayerStateHolder.isStart = false
    }
  }

  onReleased() {
    console.log(RedPlayerControllerUtil.TAG + " onReleased ")
    this.redPlayerStateHolder.isStart = false
  }

  onError(reason: string) {
    console.log(RedPlayerControllerUtil.TAG + " onError " + reason)
  }

  onSeekDone(): void {
    console.log(RedPlayerControllerUtil.TAG + " onSeekDone ")
  }

  onBufferingStart(): void {
    console.log(RedPlayerControllerUtil.TAG + " onBufferingStart ")
  }

  onBufferingEnd(): void {
    console.log(RedPlayerControllerUtil.TAG + " onBufferingEnd ")
  }
}