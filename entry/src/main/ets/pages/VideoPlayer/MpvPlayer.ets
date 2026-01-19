import NavigationAddress, { PlayerParams } from '../../common/NavigationCommon'
import { MpvController } from '../../controller/MpvController/MpvController'
import { PlayerControllerFactory } from '../../controller/PlayerControllerFactory'
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import { Privacy, SafeHeight, Setting } from '../../utils/ObservedUtil'
import { PathUtils } from '../../utils/PathUtils'
import VideoOperateUtil from '../../utils/VideoOperateUtil'
import { WindowUtil } from '../../utils/WindowUtil'
import { KeyCode } from '@kit.InputKit'
import PermissionUtil from '../../utils/PermissionUtil'
import { fileIo as fs } from '@kit.CoreFileKit'
import { XAnimation } from '../../utils/AnimationUtil'
import { JSON } from '@kit.ArkTS'
import { FastForwardPanelBuilder } from '../../component/PlayerComponent/FastForwardPanelBuilder'
import { SwipingPlayTimePanelBuilder } from '../../component/PlayerComponent/SwipingPlayTimePanelBuilder'
import { VolumeSwipingPanelBuilder } from '../../component/PlayerComponent/VolumeSwipingPanelBuilder'
import { BrightnessSwipingBuilder } from '../../component/PlayerComponent/BrightnessSwipingBuilder'
import { LockVideoBarComponent } from '../../component/PlayerComponent/LockVideoBarComponent'
import { AIAsr } from '../../component/PlayerComponent/AIAsrComponent'
import { GestureComponent } from '../../component/PlayerComponent/GestureComponent'
import VideoInfoUtil from '../../utils/VideoInfoUtil'

@Component
export struct MpvPlayer {
  xComponentController: XComponentController = new XComponentController()
  @Consume('pathStack') pathStack: NavPathStack
  @Provide('MpvPlayer') mpv: MpvController = PlayerControllerFactory.createMpvController()
  @State @Watch('setScreen') showControl: boolean = false
  @State screenWidth: number = 0
  @State screenHeight: number = 0
  @State playAreaHeight: number = 0
  @State playAreaWidth: number = 0
  @State longPress: boolean = false
  @State isLock: boolean = false
  @State onSwiping: boolean = false
  @State isSliderPlayTimeChange: boolean = false
  @State onSwipingBrightness: boolean = false
  @State lockVisibility: boolean = false
  @State isAIAsrShown: boolean = false
  @State currentSpeedIndex: number = 0
  @State sideBarStatus: boolean = false

  async aboutToAppear(): Promise<void> {
    this.mpv.create()
  }

  build() {
    NavDestination() {
      Stack() {
        Stack() {
          Stack() { //播放器
            XComponent({
              type: XComponentType.SURFACE,
              controller: this.xComponentController,
              id: 'xcomponentId',
              libraryname: 'mpvnative'
            }).focusable(true)
              .defaultFocus(true)
              .onLoad(async () => {
                await PermissionUtil.activatePermission(this.mpv.nowPlaying?.uri)
                try {
                  const file = fs.openSync(this.mpv!.nowPlaying!.uri)
                  this.mpv.init(this.xComponentController.getXComponentSurfaceId(), file.path, 0)
                } catch (error) {
                  console.error('uri error:' + error)
                }
              })
          }
        }.onKeyEvent((event?: KeyEvent) => {
          if (!event || event.type !== KeyType.Down) {
            return
          }
          if (event.keyCode === KeyCode.KEYCODE_SPACE) {
            this.mpv.togglePlayback()
          }
          if (event.keyCode === KeyCode.KEYCODE_ESCAPE) {
            this.pathStack.pop()
          }
          if (event.keyCode === KeyCode.KEYCODE_DPAD_RIGHT) {
            this.mpv.fastForward()
          }
          if (event.keyCode === KeyCode.KEYCODE_DPAD_LEFT) {
            this.mpv.backForward()
          }
        })
        .width(this.playAreaWidth)
        .height(this.playAreaHeight)
        .animation({ duration: this.mpv.playTime > 300 ? 300 : 0, curve: Curve.Ease })

        if (this.showControl && !this.isLock) {
          Stack() {
            Flex({
              justifyContent: FlexAlign.SpaceBetween,
              alignItems: ItemAlign.Center,
              direction: FlexDirection.Column
            }) { //顶栏
              Flex({ justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Center }) {
                this.VideoTop()
              }
              .height(85)
              .transition(XAnimation.getAnimation('up', 0, false))
              .width('100%')
              .backgroundColor('#36ffffff')
              .padding({
                left: (this.screenHeight > this.screenWidth ? 5 : 5),
                right: 20,
                top: (this.showControl ? SafeHeight.topSafeHeight : 0),
                bottom: 0
              })

              Stack() { //底栏
                if (this.screenHeight > this.screenWidth) {
                  Column({ space: 15 }) {
                    this.VideoButtons()
                    this.VideoSlider()
                  }
                } else {
                  Row({ space: 15 }) {
                    Column() {
                      this.VideoSlider()
                      this.VideoButtons()
                    }
                  }
                }
              }
              .transition(XAnimation.getAnimation('bottom', 0, false))
              .backgroundColor($r('sys.color.mask_fourth'))
              .height(this.screenHeight > this.screenWidth ? 180 : 110)
              .width('100%')
            }.height('100%').width('100%')
          }
        }

        if (this.longPress) {
          FastForwardPanelBuilder({
            speed: this.mpv.speed,
            location: this.playAreaHeight,
          })
        }

        if (this.onSwiping) {
          SwipingPlayTimePanelBuilder({
            isSliderPlayTimeChange: this.isSliderPlayTimeChange,
            playTime: this.mpv.playTime,
            totalTime: this.mpv.nowPlaying!.time,
            pixelMap: null,
            player: NavigationAddress.AV_PLAYER
          })
        }

        VolumeSwipingPanelBuilder({
          videoVolume: this.mpv.volume,
          videoVolumeShow: this.mpv.volumeActually,
          onSwipingVoice: this.mpv.onSwipingVoice
        })
        if (this.onSwipingBrightness) {
          BrightnessSwipingBuilder({ screenBrightness: this.mpv.screenBrightness })
        }
        if (this.lockVisibility) {
          LockVideoBarComponent({
            isLock: this.isLock,
            screenHeight: this.screenHeight,
            screenWidth: this.screenWidth,
            showControl: this.showControl,
          })
        }
        GestureComponent({
          showControl: this.showControl,
          isLock: this.isLock,
          onDoubleClickAction: (tapX: number) => {
            if (!Setting.allowDoubleFastForward) { // 非双击快进模式时执行暂停
              this.mpv.togglePlayback()
              return
            }
            const zoneWidth = this.screenWidth / 5 // 屏幕五分之一宽度
            if (tapX < zoneWidth) { // 左侧1/5区域：回退
              this.mpv.backForward()
              return
            }
            if (tapX > zoneWidth * 4) { // 右侧1/5区域：快进
              this.mpv.fastForward()
              return
            }
            this.mpv.togglePlayback()
          },
          onSingleClickAction: () => {
            if (this.sideBarStatus) {
              this.closeSideBar(true)
            } else {
              this.lockVisibility = !this.lockVisibility
              XAnimation.runWithAnimation(() => {
                if (this.isLock) {
                  this.showControl = false
                } else {
                  this.showControl = !this.showControl
                }
              })
            }
          },
          onVerticalPanStart: (tapX: number) => {
            VideoOperateUtil.leftSideSwipe = tapX < this.screenWidth / 2
            VideoOperateUtil.screenBrightnessTmp = this.mpv.screenBrightness
            this.mpv.volume = this.mpv.volumeActually
            VideoOperateUtil.lastVolume = this.mpv.volume // 记录起始音量
          },
          onVerticalPanUpdate: (offsetY: number) => {
            const deltaYScale = offsetY / this.screenHeight * 2.5
            if (VideoOperateUtil.leftSideSwipe) {
              this.onSwipingBrightness = true
              this.mpv.screenBrightness = VideoOperateUtil.calNewBrightness(deltaYScale)
              VideoOperateUtil.setBrightness(this.mpv.screenBrightness)
            } else {
              this.mpv.onSwipingVoice = true
              const newVolume = VideoOperateUtil.lastVolume - deltaYScale * 20
              this.mpv.volume =
                Math.min(Math.max(newVolume, VideoOperateUtil.min_volume), VideoOperateUtil.max_volume)
            }
          },
          onVerticalPanEnd: () => {
            this.onSwiping = false
            this.mpv.onSwipingVoice = false
            this.onSwipingBrightness = false
          },
          onHorizonPanStart: () => {
            VideoOperateUtil.lastPlayTime = this.mpv.playTime
            this.onSwiping = true
          },
          onHorizonPanUpdate: (offsetX: number) => {
            const timePerPixel = VideoOperateUtil.getTimePixel(this.screenWidth, this.mpv.nowPlaying?.time!)
            this.mpv.playTime = Math.max(0,
              Math.min(VideoOperateUtil.lastPlayTime + (offsetX * timePerPixel), this.mpv.nowPlaying?.time!))
          },
          onHorizonPanEnd: () => {
            this.mpv.seekTime(this.mpv.playTime)
            this.onSwiping = false
          },
          onPinchStart: (fingerDistance: number) => {
            VideoOperateUtil.initPinchDistance = fingerDistance
          },
          onPinchUpdate: (fingerDistance: number) => {
            const rawScale = fingerDistance / VideoOperateUtil.initPinchDistance
            const adjustedScale = 1 + (rawScale - 1) * 0.007 // 计算调整后的缩放比例
            const clampedScale = Math.min(Math.max(adjustedScale, 0.5), 2.0)
            const scaledWidth = this.playAreaWidth * clampedScale // 计算缩放后的播放区域宽度
            const maxAllowed = VideoInfoUtil.playAreaWidth * 3.0
            const minAllowed = VideoInfoUtil.playAreaWidth * 0.5
            if (scaledWidth > maxAllowed || scaledWidth < minAllowed) { // 检查缩放是否超出允许范围
              return
            }
            this.playAreaWidth = scaledWidth
            this.playAreaHeight = this.playAreaHeight * clampedScale
            XAnimation.runWithAnimation(() => {
              this.playAreaWidth = this.playAreaWidth
              this.playAreaHeight = this.playAreaHeight
            })
          },
          onLongPressAction: () => {
            if (this.mpv.playing) {
              this.longPress = true
              VideoOperateUtil.lastSpeed = this.mpv.speed
              this.mpv.updatePlaybackSpeed(Setting.longPressSpeed)
              this.currentSpeedIndex =
                VideoInfoUtil.getVideoSpeedList(NavigationAddress.AV_PLAYER).indexOf(Setting.longPressSpeed)
            }
          },
          onLongPressEnd: () => {
            this.longPress = false
            //   this.mpv.updatePlaybackSpeed(VideoOperateUtil.lastSpeed)
          },
          onLongPressPanStart: (tapX: number) => {
            VideoOperateUtil.longPressStartX = tapX
          },
          onLongPressPanUpdate: (tapX: number) => {
            if (this.longPress) { // 长按状态下的滑动处理
              const deltaX = tapX - VideoOperateUtil.longPressStartX
              const SWIPE_THRESHOLD = 15
              if (Math.abs(deltaX) <= SWIPE_THRESHOLD) { // 未达到滑动阈值则直接返回
                return
              }
              const direction = Math.sign(deltaX)
              const newIndex = this.currentSpeedIndex + direction // 计算新速度索引并限制在有效范围内
              const clampedIndex = Math.max(0,
                Math.min(newIndex, VideoInfoUtil.getVideoSpeedList(NavigationAddress.AV_PLAYER).length - 1))
              if (clampedIndex === this.currentSpeedIndex) { // 索引变化时才更新播放速度
                return
              }
              this.currentSpeedIndex = clampedIndex
              this.mpv.updatePlaybackSpeed(VideoInfoUtil.getVideoSpeedList(NavigationAddress.AV_PLAYER)[this.currentSpeedIndex])
              VideoOperateUtil.longPressStartX = tapX // 重置起始点实现分档切换效果
            }
          }
        })
          .hitTestBehavior(HitTestMode.Transparent)

        AIAsr({
          isShown: this.isAIAsrShown
        })
          .visibility(this.showControl ? Visibility.None : Visibility.Visible)
          .width('80%').height(80)
          .offset({
            x: 0,
            y: this.screenWidth > this.screenHeight ? this.screenHeight / 2 - 40 : this.screenHeight / 2 - 100
          })
      }.onAreaChange(async (_oldValue: Area, newValue: Area) => {
        this.screenWidth = Math.floor(new Number(newValue.width).valueOf())
        this.screenHeight = Math.floor(new Number(newValue.height).valueOf())
        this.getVideoSize()
      })
      .height('100%')
      .width('100%')
      .backgroundColor($r('sys.color.black'))
    }.onReady(async () => {
      const playerParams: PlayerParams =
        this.pathStack.getParamByName(NavigationAddress.MPV_PLAYER)[0] as PlayerParams
      try {
        this.mpv.nowPlaying = playerParams.metadata as VideoMetadata
        this.mpv.videoMetaDataList = playerParams.metadata_list as VideoMetadata[]
        console.error('test' + JSON.stringify(this.mpv.nowPlaying))
      } catch (e) {
        console.error(e)
      }
    }).onBackPressed(() => {
      if (this.showControl && !Setting.allowPlayBackExist) {
        this.showControl = false
        return true
      } else {
        return false
      }
    }).hideTitleBar(true)
    .blur(Privacy.isPrivacyBackground ? 1000 : 0)
  }

  closeSideBar(arg0: boolean) {
    throw new Error('Method not implemented.')
  }

  getVideoSize() {
    let VideoWidth = this.mpv.getPlayAreaWidth() === 0 ? 2000 : this.mpv.getPlayAreaWidth()
    let VideoHeight = this.mpv.getPlayAreaHeight() === 0 ? 2000 : this.mpv.getPlayAreaHeight()
    console.error('test' + VideoWidth + ' ' + VideoHeight)
    if (this.mpv.nowPlaying?.size[0] === 0 && VideoWidth !== 0) {
      this.mpv.nowPlaying.size[0] = VideoWidth
      this.mpv.nowPlaying.size[1] = VideoHeight
      VideoOperateUtil.saveVideoWeightAndHeight(PathUtils.appContext!, this.mpv.nowPlaying)
    }
    const aspectRatioNow = VideoWidth / VideoHeight
    const screenAspectRatio = this.screenWidth / this.screenHeight
    if (aspectRatioNow > screenAspectRatio) {
      this.playAreaWidth = this.screenWidth
      this.playAreaHeight = this.playAreaWidth * (VideoHeight / VideoWidth)
    } else {
      this.playAreaHeight = this.screenHeight
      this.playAreaWidth = this.playAreaHeight * (VideoWidth / VideoHeight)
    }
  }

  setScreen() {
    WindowUtil.setBarState(PathUtils.appContext!, this.showControl, this.showControl)
  }

  @Builder
  VideoTop() {
    Row({ space: 8 }) {
      SymbolGlyph($r('sys.symbol.chevron_left'))// 返回图标
        .fontSize(40)
        .fontColor(['#f0f0f0'])
        .onClick(() => {
          this.pathStack.pop()
        })
        .padding({ right: 10 })
        .margin({ left: 15 })
      Text(String(this.mpv.nowPlaying?.title).slice(0, this.mpv.nowPlaying?.title.lastIndexOf('.')))
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.MARQUEE })
        .fontColor($r('sys.color.white'))
        .layoutWeight(1) // 关键布局属性
    }
  }

  @Builder
  VideoButtons() {
  }

  @Builder
  VideoSlider() {
  }
}

