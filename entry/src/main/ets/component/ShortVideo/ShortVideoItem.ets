import { ShortVideoPlayer } from '../../controller/ShortVideo/ShortVideoPlayer'
import { ShortVideoPlayerManager } from '../../controller/ShortVideo/ShortVideoPlayerManager'
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import { PathUtils } from '../../utils/PathUtils'
import { Setting } from '../../utils/ObservedUtil'
import { FastForwardPanelBuilder } from '../PlayerComponent/FastForwardPanelBuilder'

@ComponentV2
export struct ShortVideoItem {
  @Param @Require item: VideoMetadata
  @Param index: number = 0
  @Param currentIndex: number = 0
  @Param manager: ShortVideoPlayerManager = new ShortVideoPlayerManager()
  @Local player: ShortVideoPlayer | undefined = undefined
  @Local isLongPressing: boolean = false
  @Local containerWidth: number = 0
  @Local containerHeight: number = 0
  private xComponentController: XComponentController = new XComponentController()

  aboutToAppear(): void {
    this.bindPlayer()
  }

  @Monitor('index')
  onIndexChanged(): void {
    this.bindPlayer()
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

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Image(PathUtils.coverUri(this.item.date))
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
          const surfaceId = this.xComponentController.getXComponentSurfaceId()
          if (surfaceId) {
            this.manager.bindSurface(this.index, surfaceId, this.xComponentController)
          }
        })

      if (this.player?.state === 'preparing') {
        LoadingProgress()
          .width(42)
          .height(42)
          .color(Color.White)
      }

      if (this.player?.state === 'error') {
        Column({ space: 10 }) {
          Text('!')
            .fontSize(40)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
          Text('AVPlayer 无法播放该视频')
            .fontSize(16)
            .fontColor(Color.White)
          Text('可继续上滑切换视频')
            .fontSize(13)
            .fontColor('#B3FFFFFF')
        }
      }

      if (this.player?.state === 'paused') {
        SymbolGlyph($r('sys.symbol.play_fill'))
          .fontSize(52)
          .fontColor([Color.White])
          .opacity(0.85)
      }

      if (this.isLongPressing) {
        FastForwardPanelBuilder({
          speed: this.player?.playbackRate || Setting.longPressSpeed,
          location: this.containerHeight,
          speedLocked: false
        })
      }

    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      this.containerWidth = Number(newValue.width)
      this.containerHeight = Number(newValue.height)
    })
    .gesture(GestureGroup(GestureMode.Exclusive,
      TapGesture({ count: 1 })
        .onAction(() => {
          if (this.index === this.currentIndex) {
            this.manager.toggle(this.index)
          }
        }),
      LongPressGesture({ repeat: false })
        .onAction(() => {
          if (this.index !== this.currentIndex || this.player?.state !== 'playing') {
            return
          }
          this.isLongPressing = true
          this.manager.beginLongPress(this.index)
        })
        .onActionEnd(() => {
          if (!this.isLongPressing) {
            return
          }
          this.isLongPressing = false
          this.manager.endLongPress(this.index)
        }),
      PanGesture({ fingers: 1, direction: PanDirection.Horizontal })
        .onActionStart(() => this.manager.beginHorizontalSeek(this.index))
        .onActionUpdate((event: GestureEvent) => {
          this.manager.updateHorizontalSeek(this.index, event.offsetX, this.containerWidth)
        })
        .onActionEnd(() => this.manager.endHorizontalSeek(this.index))))
  }
}
