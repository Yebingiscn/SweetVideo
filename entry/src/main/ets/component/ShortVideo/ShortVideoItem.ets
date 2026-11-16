import { ShortVideoPlayer } from '../../controller/ShortVideo/ShortVideoPlayer'
import { ShortVideoPlayerManager } from '../../controller/ShortVideo/ShortVideoPlayerManager'
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import { PathUtils } from '../../utils/PathUtils'
import { FastForwardPanelBuilder } from '../PlayerComponent/FastForwardPanelBuilder'
import { AudioCoverBuilder } from '../PlayerComponent/AudioCoverBuilder'
import { GestureComponent } from '../PlayerComponent/GestureComponent'


@ComponentV2
export struct ShortVideoItem {
  @Param @Require item: VideoMetadata
  @Param index: number = 0
  @Param currentIndex: number = 0
  @Param isSwitching: boolean = false
  @Param manager: ShortVideoPlayerManager = new ShortVideoPlayerManager()
  @Event onSingleTap: () => void = () => {
  }
  @Event onDoubleTap: (_tapX: number) => void = () => {
  }
  @Event onPlayWithMpv: () => void = () => {
  }
  @Local player: ShortVideoPlayer | undefined = undefined
  @Local containerWidth: number = 0
  @Local containerHeight: number = 0
  private xComponentController: XComponentController = new XComponentController()
  private longPressIndex: number = -1
  private seekIndex: number = -1

  aboutToAppear(): void {
    this.bindPlayer()
  }

  aboutToDisappear(): void {
    this.cancelGestures()
  }

  @Monitor('index')
  onIndexChanged(): void {
    this.cancelGestures()
    this.bindPlayer()
  }

  @Monitor('currentIndex', 'isSwitching')
  onCurrentIndexChanged(): void {
    if (this.index === this.currentIndex && !this.isSwitching) {
      // 同一个索引再次进入时，Repeat 未必重新触发 aboutToAppear/onLoad。
      this.bindPlayer()
    } else {
      this.cancelGestures()
    }
  }

  private beginLongPress(): void {
    if (this.manager.isClosing || this.isSwitching || this.index !== this.currentIndex ||
      this.player?.state !== 'playing') {
      return
    }
    this.longPressIndex = this.index
    this.manager.beginLongPress(this.longPressIndex)
  }

  private endLongPress(): void {
    const index = this.longPressIndex
    this.longPressIndex = -1
    if (index >= 0 && !this.manager.isClosing) {
      this.manager.endLongPress(index)
    }
  }

  private cancelLongPress(): void {
    const index = this.longPressIndex
    this.longPressIndex = -1
    if (index >= 0 && !this.manager.isClosing) {
      this.manager.cancelLongPress(index)
    }
  }

  private beginHorizontalSeek(): void {
    if (this.manager.isClosing || this.isSwitching || this.index !== this.currentIndex) {
      return
    }
    this.manager.beginHorizontalSeek(this.index)
    if (this.manager.onSwiping && this.index === this.currentIndex) {
      this.seekIndex = this.index
    }
  }

  private endHorizontalSeek(): void {
    const index = this.seekIndex
    this.seekIndex = -1
    if (index >= 0) {
      this.manager.endHorizontalSeek(index)
    }
  }

  private cancelHorizontalSeek(): void {
    const index = this.seekIndex
    this.seekIndex = -1
    if (index >= 0) {
      this.manager.cancelHorizontalSeek(index)
    }
  }

  private cancelGestures(): void {
    this.cancelLongPress()
    this.cancelHorizontalSeek()
  }

  private bindPlayer(): void {
    this.player = this.manager.getOrCreate(this.index)
    const surfaceId = this.xComponentController.getXComponentSurfaceId()
    if (surfaceId) {
      this.manager.bindSurface(this.index, surfaceId, this.xComponentController)
    }
  }

  private videoAreaWidth(): number {
    const videoWidth = this.player?.videoWidth || this.item.size[0] || 0
    const videoHeight = this.player?.videoHeight || this.item.size[1] || 0
    if (this.containerWidth <= 0 || this.containerHeight <= 0 || videoWidth <= 0 || videoHeight <= 0) {
      return Math.max(this.containerWidth, 1)
    }
    const videoRatio = videoWidth / videoHeight
    const containerRatio = this.containerWidth / this.containerHeight
    return videoRatio > containerRatio ? this.containerWidth : this.containerHeight * videoRatio
  }

  private videoAreaHeight(): number {
    const videoWidth = this.player?.videoWidth || this.item.size[0] || 0
    const videoHeight = this.player?.videoHeight || this.item.size[1] || 0
    if (this.containerWidth <= 0 || this.containerHeight <= 0 || videoWidth <= 0 || videoHeight <= 0) {
      return Math.max(this.containerHeight, 1)
    }
    const videoRatio = videoWidth / videoHeight
    const containerRatio = this.containerWidth / this.containerHeight
    return videoRatio > containerRatio ? this.containerWidth / videoRatio : this.containerHeight
  }

  @Builder
  private VideoContent() {
    Image(PathUtils.coverUri(this.item.date))
      .dynamicRangeMode(DynamicRangeMode.CONSTRAINT)
      .width(this.videoAreaWidth())
      .height(this.videoAreaHeight())
      .objectFit(ImageFit.Contain)

    XComponent({
      type: XComponentType.SURFACE,
      controller: this.xComponentController,
      id: `short_video_surface_${this.item.date}`
    })
      .width(this.videoAreaWidth())
      .height(this.videoAreaHeight())
      .onLoad(() => {
        this.bindPlayer()
      })
      .onDestroy(() => {
        this.cancelGestures()
        this.manager.unbindSurface(this.xComponentController)
        this.player = undefined
      })

    AudioCoverBuilder({ coverUri: this.player?.audioCoverUri ?? '' })
  }

  @Builder
  private PlaybackOverlays() {
    if (this.player?.state === 'preparing' || this.player?.activating) {
      LoadingProgress()
        .width(42)
        .height(42)
        .color(Color.White)
        .hitTestBehavior(HitTestMode.None)
    }

    if (!this.isSwitching && this.index === this.currentIndex &&
      this.player === this.manager.currentPlayer && this.player?.playbackFailed) {
      Column({ space: 10 }) {
        Text('!')
          .fontSize(40)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
        Text($r('app.string.avplayer_cannot_play'))
          .fontSize(16)
          .fontColor(Color.White)
        Button($r('app.string.switch_to_mpv_player'), { type: ButtonType.Capsule })
          .fontSize(14)
          .fontColor(Color.Black)
          .backgroundColor(Color.White)
          .margin({ top: 6, bottom: 6 })
          .onClick(() => this.onPlayWithMpv())
        Text($r('app.string.swipe_up_to_switch'))
          .fontSize(13)
          .fontColor('#B3FFFFFF')
      }
    }

    if (this.player?.state === 'paused') {
      SymbolGlyph($r('sys.symbol.play_fill'))
        .fontSize(52)
        .fontColor([Color.White])
        .opacity(0.85)
        .hitTestBehavior(HitTestMode.None)
    }

    if (this.index === this.currentIndex &&
      (this.manager.gestureState.longPress || this.manager.gestureState.speedLocked)) {
      FastForwardPanelBuilder({
        speed: this.manager.playbackSpeed,
        location: this.containerHeight,
        speedLocked: this.manager.gestureState.speedLocked,
      })
    }

  }

  @Builder
  private GestureLayer() {
    GestureComponent({
      player: this.manager.gestureState,
      gestureSurfaceId: `short_video_smart_gesture_${this.item.date}`,
      gestureEnabled: this.index === this.currentIndex && !this.isSwitching && !this.manager.isClosing,
      smartGestureEnabled: this.index === this.currentIndex,
      extendedGestures: false,
      touchAreaHeight: '100%',
      onSingleClickAction: () => {
        if (this.index === this.currentIndex && !this.manager.isClosing) {
          this.onSingleTap()
        }
      },
      onDoubleClickAction: (tapX: number) => {
        if (this.index === this.currentIndex && !this.manager.isClosing) {
          this.onDoubleTap(tapX)
        }
      },
      onLongPressAction: () => this.beginLongPress(),
      onLongPressEnd: () => this.endLongPress(),
      onLongPressCancel: () => this.cancelLongPress(),
      onLongPressPanStart: (offsetX: number, offsetY: number) => {
        this.manager.onLongPressPanStart(this.longPressIndex, offsetX, offsetY)
      },
      onLongPressPanUpdate: (offsetX: number, offsetY: number) => {
        this.manager.onLongPressPanUpdate(this.longPressIndex, offsetX, offsetY)
      },
      onHorizonPanStart: () => this.beginHorizontalSeek(),
      onHorizonPanUpdate: (offsetX: number) => {
        this.manager.updateHorizontalSeek(this.seekIndex, offsetX, this.containerWidth)
      },
      onHorizonPanEnd: () => this.endHorizontalSeek(),
      onHorizonPanCancel: () => this.cancelHorizontalSeek()
    })
      .hitTestBehavior(HitTestMode.Transparent)
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      this.VideoContent()
      this.GestureLayer()
      this.PlaybackOverlays()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      this.containerWidth = Number(newValue.width)
      this.containerHeight = Number(newValue.height)
      this.manager.gestureState.screenWidth = this.containerWidth
    })
  }
}
