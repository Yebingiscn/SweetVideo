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
      const width = this.player.getVideoWidth();
      const height = this.player.getVideoHeight();
      if (width === 0 || height === 0) {
        return
      }
      this.redPlayerStateHolder.url = this.player.getUrl();
      this.redPlayerStateHolder.videoCodec = this.player.getVideoCodecInfo();
      this.redPlayerStateHolder.audioCodec = this.player.getAudioCodecInfo();
      const screen = display.getDefaultDisplaySync();
      const screenWidth = screen.width;
      const screenHeight = screen.height;
      const videoRatio = width / height;
      const screenRatio = screenWidth / screenHeight;
      if (videoRatio > screenRatio) {
        this.redPlayerStateHolder.videoViewWidth = `${Math.round(screenWidth)}px`;
        this.redPlayerStateHolder.videoViewHeight = `${Math.round(screenWidth / videoRatio)}px`;
      } else {
        this.redPlayerStateHolder.videoViewHeight = `${Math.round(screenHeight)}px`;
        this.redPlayerStateHolder.videoViewWidth = `${Math.round(screenHeight * videoRatio)}px`;
      }
      const viewWidth = parseFloat(this.redPlayerStateHolder.videoViewWidth);
      const viewHeight = parseFloat(this.redPlayerStateHolder.videoViewHeight);
      this.redPlayerStateHolder.videoWidth = viewWidth;
      this.redPlayerStateHolder.videoHeight = viewHeight;
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