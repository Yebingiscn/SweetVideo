import {
  DeviceChangeReason,
  IjkMediaPlayer,
  InterruptEvent,
  InterruptHintType,
  OnBufferingUpdateListener,
  OnCompletionListener,
  OnErrorListener,
  OnInfoListener,
  OnPreparedListener,
  OnSeekCompleteListener,
  OnTimedTextListener,
  OnVideoSizeChangedListener
} from '@ohos/ijkplayer'
import ToolsUtil from '../../utils/ToolsUtil'
import { window } from '@kit.ArkUI'
import { audio } from '@kit.AudioKit'
import PermissionUtil from '../../utils/PermissionUtil'
import AVSessionUtil from '../../utils/AVSessionUtil'
import { AVCastPicker, avSession as avSessionManager } from '@kit.AVSessionKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import VideoOperateUtil from '../../utils/VideoOperateUtil'
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import { PlayStatus } from '../../common/enum/PlayStatus'
import VideoInfoUtil from '../../utils/VideoInfoUtil'
import { KeyCode } from '@kit.InputKit'
import { PathUtils } from '../../utils/PathUtils'
import { ButtonFancyModifier, SymbolGlyphFancyModifier } from '../../common/AttributeModifierConfig'
import { AVCastPickerBuilder } from '../../component/PlayerComponent/AVCastPickerBuilder'
import { VideoSliderComponent } from '../../component/PlayerComponent/VideoSliderComponent'
import { GestureComponent } from '../../component/PlayerComponent/GestureComponent'
import { VideoStartTimeMode } from '../../common/enum/VideoStartTimeMode'
import NavigationAddress, { PlayerParams } from '../../common/NavigationCommon'
import { WindowUtil } from '../../utils/WindowUtil'
import { XAnimation } from '../../utils/AnimationUtil'
import { AIAsr } from '../../component/PlayerComponent/AIAsrComponent'
import { BrightnessSwipingBuilder } from '../../component/PlayerComponent/BrightnessSwipingBuilder'
import { FastForwardPanelBuilder } from '../../component/PlayerComponent/FastForwardPanelBuilder'
import { VolumeSwipingPanelBuilder } from '../../component/PlayerComponent/VolumeSwipingPanelBuilder'

import { SwipingPlayTimePanelBuilder } from '../../component/PlayerComponent/SwipingPlayTimePanelBuilder'
import { Privacy, SafeHeight, Setting } from '../../utils/ObservedUtil'

@Component
export struct FFMpegPlayer { // FFMpeg播放器页
  avSession: avSessionManager.AVSession | undefined = undefined
  @State play_area_height: number = 1
  @State play_area_width: number = 1
  @State screenWidth: number = 0
  @State screenHeight: number = 0
  @State play_time: number = 0
  @State playing: boolean = false
  @State mContext: object | undefined = undefined
  @State updateProgressTimer: number = 0
  @State mDestroyPage: boolean = false
  @State slideEnable: boolean = false
  @State loadingVisible: Visibility = Visibility.None
  @State replayVisible: Visibility = Visibility.None
  @State volume: number = 1.0
  @State playSpeed: number = 1
  nowPlaying: VideoMetadata | undefined = undefined
  @State video_url: string = ''
  @State total_time: number = 0
  @State currentSpeedIndex: number = 0
  @State onSwipingVoice: boolean = false
  @State onSwipingBrightness: boolean = false
  @State screenBrightness: number = 0
  @State volumeTmp: number = 0
  @State isLock: boolean = false
  @State isAIAsrShown: boolean = false
  @State isSliderPlayTimeChange: boolean = false
  windowClass = WindowUtil.getWindow()
  xComponentController: XComponentController = new XComponentController()
  @State @Watch('setScreen') showControl: boolean = false
  @State onSwiping: boolean = false
  @State longPress: boolean = false
  @State last_speed: number = 1
  @State isHorizontalSwiping: boolean = false
  @State videoMetaData: VideoMetadata[] = []
  @State volumeActually: number = 0
  @Consume('pathStack') pathStack: NavPathStack
  private CONTROL_PlayStatus = PlayStatus.INIT
  private mIjkMediaPlayer: IjkMediaPlayer | null = null
  private audioVolumeManager: audio.AudioVolumeManager | null = null

  build() {
    NavDestination() {
      Stack() {
        Stack() { //播放器
          XComponent({
            type: XComponentType.SURFACE,
            controller: this.xComponentController,
            id: 'xcomponentId',
            libraryname: 'ijkplayer_napi'
          }).focusable(true)
            .defaultFocus(true)
            .onLoad(async (event?: object) => {
              if (!!event) {
                this.initDelayPlay(event)
                await PermissionUtil.activatePermission(this.nowPlaying?.uri)
                try {
                  const file = fs.openSync(this.nowPlaying?.uri)
                  this.video_url = file.path
                } catch (error) {
                  console.error('uri error:' + error)
                }
              }
            })
        }
        .onKeyEvent((event?: KeyEvent) => {
          if (!event || event.type !== KeyType.Down) {
            return
          }
          if (event.keyCode === KeyCode.KEYCODE_SPACE) {
            this.togglePlayState()
          }
          if (event.keyCode === KeyCode.KEYCODE_ESCAPE) {
            VideoOperateUtil.fullScreenOrRotateScreen(this.screenWidth, this.screenHeight, this.windowClass)
          }
          if (event.keyCode === KeyCode.KEYCODE_DPAD_RIGHT) {
            this.mIjkMediaPlayer?.seekTo(String(this.play_time + Number(Setting.fastForwardSeconds) * 1000))
          }
          if (event.keyCode === KeyCode.KEYCODE_DPAD_LEFT) {
            this.mIjkMediaPlayer?.seekTo(String(this.play_time - Number(Setting.fastForwardSeconds) * 1000))
          }
          if (event.keyCode === KeyCode.KEYCODE_DPAD_UP || event.keyCode === KeyCode.KEYCODE_DPAD_DOWN) {
            this.volume = this.volumeActually
            const newVolume = VideoOperateUtil.changeVolume(this.volume,
              event.keyCode === KeyCode.KEYCODE_DPAD_UP ? 0.5 : -0.5)
            this.volume = newVolume
            this.volumeActually = newVolume
            VideoOperateUtil.lastVolume = newVolume
          }
        })
        .width(this.play_area_width)
        .height(this.play_area_height)
        .animation({ duration: this.play_time > 300 ? 300 : 0, curve: Curve.Ease })

        if (this.showControl) {
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
              .padding(1)
            }.height('100%').width('100%')
          }
        }

        if (this.onSwiping) {
          SwipingPlayTimePanelBuilder({
            isSliderPlayTimeChange: this.isSliderPlayTimeChange,
            playTime: this.play_time,
            totalTime: this.total_time,
            pixelMap: null,
            player: NavigationAddress.FFMPEG_PLAYER
          })
        }

        VolumeSwipingPanelBuilder({
          videoVolume: this.volume,
          videoVolumeShow: this.volumeActually,
          onSwipingVoice: this.onSwipingVoice
        })

        if (this.onSwipingBrightness) {
          BrightnessSwipingBuilder({ screenBrightness: this.screenBrightness })
        }
        if (this.longPress) {
          FastForwardPanelBuilder({ speed: this.playSpeed, location: this.play_area_height })
        }
        GestureComponent({
          showControl: this.showControl,
          isLock: this.isLock,
          onDoubleClickAction: (tapX: number) => {
            if (!Setting.allowDoubleFastForward) { // 非快进模式直接切换播放状态
              this.togglePlayState()
              return
            }
            const zoneWidth = this.screenWidth / 5 // 计算区域分割宽度
            if (tapX < zoneWidth) { // 左侧区域：回退
              this.mIjkMediaPlayer?.seekTo(String(this.play_time - Number(Setting.fastForwardSeconds) * 1000))
              return
            }
            if (tapX > zoneWidth * 4) { // 右侧区域：快进
              this.mIjkMediaPlayer?.seekTo(String(this.play_time + Number(Setting.fastForwardSeconds) * 1000))
              return
            }
            this.togglePlayState() // 中间区域：播放/暂停切换
          },
          onSingleClickAction: () => {
            XAnimation.runWithAnimation(async () => {
              this.showControl = !this.showControl
            })
          },
          onVerticalPanStart: (tapX: number) => {
            VideoOperateUtil.leftSideSwipe = tapX < this.screenWidth / 2
            VideoOperateUtil.screenBrightnessTmp = this.screenBrightness
            this.volume = this.volumeActually
            VideoOperateUtil.lastVolume = this.volume // 记录起始音量
          },
          onVerticalPanUpdate: (offsetY: number) => {
            const deltaYScale = offsetY / this.screenHeight * 2.5
            if (VideoOperateUtil.leftSideSwipe) {
              this.onSwipingBrightness = true
              this.screenBrightness = VideoOperateUtil.calNewBrightness(deltaYScale)
              VideoOperateUtil.setBrightness(this.screenBrightness)
            } else {
              this.onSwipingVoice = true
              const newVolume = (VideoOperateUtil.lastVolume - deltaYScale * 20)
              this.volume =
                Math.min(Math.max(newVolume, -10), VideoOperateUtil.maxVolume)
            }
          },
          onVerticalPanEnd: () => {
            this.onSwiping = false
            this.onSwipingVoice = false
            this.onSwipingBrightness = false
          },
          onHorizonPanStart: () => {
            VideoOperateUtil.lastPlayTime = this.play_time
            this.onSwiping = true
          },
          onHorizonPanUpdate: async (offsetX: number) => {
            const timePerPixel = VideoOperateUtil.getTimePixel(this.screenWidth, this.nowPlaying?.time!) * 1.5
            this.play_time = Math.max(0,
              Math.min(VideoOperateUtil.lastPlayTime + (offsetX * timePerPixel),
                this.nowPlaying?.time!))
          },
          onHorizonPanEnd: () => {
            this.mIjkMediaPlayer?.seekTo(String(this.play_time))
            this.onSwiping = false
          },
          onPinchStart: (fingerDistance: number) => {
            VideoOperateUtil.initPinchDistance = fingerDistance
          },
          onPinchUpdate: (fingerDistance: number) => {
            const rawScale = fingerDistance / VideoOperateUtil.initPinchDistance
            const adjustedScale = 1 + (rawScale - 1) * 0.007
            const clampedScale = Math.min(Math.max(adjustedScale, 0.5), 2.0)
            const scaledWidth = this.play_area_width * clampedScale // 计算缩放后的播放区域宽度
            const maxAllowed = VideoInfoUtil.playAreaWidth * 3.0
            const minAllowed = VideoInfoUtil.playAreaWidth * 0.5
            if (scaledWidth > maxAllowed || scaledWidth < minAllowed) { // 检查缩放是否超出允许范围
              return
            }
            this.play_area_width = scaledWidth
            this.play_area_height = this.play_area_height * clampedScale
            XAnimation.runWithAnimation(() => {
              this.play_area_width = this.play_area_width
              this.play_area_height = this.play_area_height
            })
          },
          onLongPressAction: () => {
            if (this.playing) {
              this.longPress = true
              this.last_speed = this.playSpeed
              this.playSpeed = Setting.longPressSpeed
              this.mIjkMediaPlayer?.setSpeed(this.playSpeed + '')
              this.currentSpeedIndex =
                VideoInfoUtil.getVideoSpeedList(NavigationAddress.FFMPEG_PLAYER).indexOf(Setting.longPressSpeed)
            }
          },
          onLongPressEnd: () => {
            this.longPress = false
            this.playSpeed = this.last_speed
            this.mIjkMediaPlayer?.setSpeed(this.last_speed + '')
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
                Math.min(newIndex, VideoInfoUtil.getVideoSpeedList(NavigationAddress.FFMPEG_PLAYER).length - 1))
              if (clampedIndex === this.currentSpeedIndex) { // 如果速度没有变化则直接返回
                return
              }
              this.currentSpeedIndex = clampedIndex
              this.playSpeed =
                VideoInfoUtil.getVideoSpeedList(NavigationAddress.FFMPEG_PLAYER)[this.currentSpeedIndex]
              this.mIjkMediaPlayer?.setSpeed(this.playSpeed + '')
              VideoOperateUtil.longPressStartX = tapX // 重置起始点实现分档切换效果
            }
          }
        })

        AIAsr({
          isShown: this.isAIAsrShown
        })
          .visibility(this.showControl ? Visibility.None : Visibility.Visible)
          .width('80%').height(80)
          .offset({
            x: 0,
            y: this.screenWidth > this.screenHeight ? this.screenHeight / 2 - 40 : this.screenHeight / 2 - 100
          })
      }
      .onAreaChange((_oldValue: Area, newValue: Area) => {
        this.screenWidth = Math.floor(new Number(newValue.width).valueOf())
        this.screenHeight = Math.floor(new Number(newValue.height).valueOf())
        this.getVideoSize()
      })
      .height('100%')
      .width('100%')
      .backgroundColor($r('sys.color.black'))
    }
    .onReady(() => {
      const playerParams: PlayerParams =
        this.pathStack.getParamByName(NavigationAddress.FFMPEG_PLAYER)[0] as PlayerParams
      try {
        this.nowPlaying = playerParams.metadata as VideoMetadata
        this.videoMetaData = playerParams.metadata_list as VideoMetadata[]
      } catch (e) {
        console.error(e)
      }
    })
    .onBackPressed(() => {
      if (this.showControl && !Setting.allowPlayBackExist) {
        this.showControl = false
        return true
      } else {
        return false
      }
    })
    .onWillDisappear(async () => {
      if (this.videoMetaData.length > 0 && this.play_time > 0) {
        VideoOperateUtil.saveVideoTime(this.play_time, this.nowPlaying!, this.videoMetaData,
          PathUtils.appContext!)
      }
      PermissionUtil.applyStopContinuousTask()
      WindowUtil.setKeepScreenStatus(PathUtils.appContext!, false)
      WindowUtil.setBarState(PathUtils.appContext!, true, true)
      try {
        await (await this.windowClass)?.setPreferredOrientation(window.Orientation.AUTO_ROTATION_RESTRICTED)
      } catch (error) {
        console.error('setPreferredOrientation' + error)
      }
      this.mDestroyPage = true
      this.mIjkMediaPlayer?.setScreenOnWhilePlaying(false)
      if (this.CONTROL_PlayStatus != PlayStatus.INIT) {
        this.stop()
      }
      this.mIjkMediaPlayer?.off('audioInterrupt')
      this.mIjkMediaPlayer?.off('deviceChange')
    })
    .hideTitleBar(true)
    .blur(Privacy.isPrivacyBackground ? 1000 : 0)
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
      Text(String(this.nowPlaying?.title).slice(0, this.nowPlaying?.title.lastIndexOf('.')))
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.MARQUEE })
        .fontColor($r('sys.color.white'))
        .layoutWeight(1) // 关键布局属性
    }
  }

  @Builder
  VideoSlider() {
    VideoSliderComponent({
      playTime: this.play_time,
      totalTime: this.total_time,
      screenHeight: this.screenHeight,
      screenWidth: this.screenWidth,
      playSpeed: this.playSpeed,
      onSliderChange: (value: number) => {
        this.isSliderPlayTimeChange = true
        this.onSwiping = true
        this.play_time = value
        this.mDestroyPage = false
      },
      onSliderTouch: (event: TouchEvent) => {
        if (event.type == TouchType.Up) {
          let seekValue = this.play_time
          this.mIjkMediaPlayer?.seekTo(seekValue + "")
          this.setProgress()
          this.onSwiping = false
          this.isSliderPlayTimeChange = false
        }
      }
    })
  }

  @Builder
  VideoButtons() {
    GridRow({ columns: 14, gutter: 5 }) {
      GridCol() {
        Button({ type: ButtonType.Circle, stateEffect: true }) { // 播放按钮
          SymbolGlyph(this.playing ? $r('sys.symbol.pause_fill') : $r('sys.symbol.play_fill'))
            .fontSize(27)
            .fontColor(['#f0f0f0'])
            .symbolEffect(new ReplaceSymbolEffect(EffectScope.WHOLE), Number(this.playing))
        }
        .attributeModifier(new ButtonFancyModifier(40, 40))
        .backgroundColor('#50000000')
        .onClick(() => {
          ToolsUtil.startVibration()
          this.togglePlayState()
        })
      }.span({ xs: 2, sm: 2, md: 2 })

      GridCol() {
        Button({ type: ButtonType.Circle, stateEffect: true }) { // 全屏按钮
          SymbolGlyph($r('sys.symbol.screen_rotation'))
            .fontSize(23)
            .fontColor(['#f0f0f0'])
        }
        .attributeModifier(new ButtonFancyModifier(40, 40))
        .backgroundColor('#50000000')
        .onClick(async () => {
          VideoOperateUtil.fullScreenOrRotateScreen(this.screenWidth, this.screenHeight, this.windowClass)
        })
      }.span({ xs: 2, sm: 2, md: 2 })

      GridCol() { // 投播
        AVCastPicker({
          normalColor: Color.White,
          onStateChange: AVSessionUtil.castOnStateChange,
          customPicker: () => this.AVCastPickerBuilderBridge()
        })
          .width(23)
          .height(23)
          .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
      }.span({ xs: 2, sm: 2, md: 2 })

      GridCol() {
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph(this.isAIAsrShown ?
            $r('sys.symbol.textformat_size_square_fill') : $r('sys.symbol.textformat_size_square'))
            .attributeModifier(new SymbolGlyphFancyModifier(30, '', ''))
            .fontColor(['#f0f0f0'])
        }
        .attributeModifier(new ButtonFancyModifier(40, 40))
        .backgroundColor('#50000000')
        .onClick(() => {
          this.isAIAsrShown = !this.isAIAsrShown
        })
      }.span({ xs: 2, sm: 2, md: 2 })
    }.width('95%')
  }

  @Builder
  AVCastPickerBuilderBridge() { // 桥接AVCastPickerBuilder避免crash
    AVCastPickerBuilder()
  }

  async aboutToAppear() {
    this.mIjkMediaPlayer = IjkMediaPlayer.getInstance()
    PermissionUtil.applyContinuousTask()
    this.setScreen()
    let groupId: number = audio.DEFAULT_VOLUME_GROUP_ID
    let audioManager = audio.getAudioManager()
    this.audioVolumeManager = audioManager.getVolumeManager()
    let volumeList = await VideoOperateUtil.getVolume(this.audioVolumeManager, groupId)
    this.volume = volumeList.get('volume')!
    try {
      await (await this.windowClass)?.setPreferredOrientation(window.Orientation.AUTO_ROTATION_RESTRICTED)
      WindowUtil.setKeepScreenStatus(PathUtils.appContext!, true)
    } catch (error) {
      console.error('setPreferredOrientation error:' + error)
    }
    WindowUtil.enableLandscapeMultiWindow(this.windowClass)
    let event: Callback<InterruptEvent> = (event) => {
      if (event.hintType === InterruptHintType.INTERRUPT_HINT_PAUSE) {
        this.pause()
      } else if (event.hintType === InterruptHintType.INTERRUPT_HINT_RESUME) {
        this.startPlayOrResumePlay()
      } else if (event.hintType === InterruptHintType.INTERRUPT_HINT_STOP) {
        this.pause()
      }
    }
    this.mIjkMediaPlayer?.on('audioInterrupt', event)
    let deviceChangeEvent: Callback<InterruptEvent> = (event) => {
      if (event.reason === DeviceChangeReason.REASON_OLD_DEVICE_UNAVAILABLE) { // 音频设备断开连接
        this.pause()
      }
    }
    this.mIjkMediaPlayer?.on('deviceChange', deviceChangeEvent)
    this.screenBrightness = await VideoOperateUtil.getScreenBrightness()
    this.volumeActually = this.volume
    try {
      this.audioVolumeManager.on('volumeChange', (volumeEvent: audio.VolumeEvent) => {
        let changeVolumeByVolumeButton = false
        if (!this.onSwipingVoice) { // 这里复用手势音量调节提示
          this.onSwipingVoice = !this.onSwipingVoice
          changeVolumeByVolumeButton = true
        }
        this.volumeActually = volumeEvent.volume
        ToolsUtil.startVibration()
        setTimeout(() => {
          if (changeVolumeByVolumeButton) {
            this.onSwipingVoice = !this.onSwipingVoice
          }
        }, 800)
      })
    } catch (error) {
      console.error('volumeChange error:' + error)
    }
    this.isAIAsrShown = true
  }

  async aboutToDisappear() {
    this.mIjkMediaPlayer = null
    VideoOperateUtil.setBrightness(-1)
    try {
      this.audioVolumeManager?.off('volumeChange')
    } catch (error) {
      console.error('volumeChange error:' + error)
    }
    this.audioVolumeManager = null
  }

  async setSessionListener() {
    try {
      this.avSession?.on('play', () => {
        this.startPlayOrResumePlay()
      })
      this.avSession?.on('pause', () => {
        this.pause()
      })
      this.avSession?.on('seek', (position: number) => {
        this.mDestroyPage = false
        let seekValue = position
        this.mIjkMediaPlayer?.seekTo(seekValue + "")
        this.setProgress()
      })
    } catch (error) {
      console.error('set av session state error')
    }
  }

  setScreen() {
    WindowUtil.setBarState(PathUtils.appContext!, this.showControl, this.showControl)
  }

  videoStartPlayTime(seekMode: number) {
    switch (seekMode) {
      case VideoStartTimeMode.SEEK_TO_LAST_PLAY_TIME:
        this.mIjkMediaPlayer?.seekTo(String(this.nowPlaying?.last_play) || '0')
        break
      case VideoStartTimeMode.SEEK_TO_START_TIME:
        this.mIjkMediaPlayer?.seekTo(String(this.nowPlaying?.start_time) || '0')
        break
      case VideoStartTimeMode.SEEK_TO_INTRO_TIME:
        this.mIjkMediaPlayer?.seekTo(String(this.play_time + Number(Setting.skipIntroTime) * 1000))
        break
      default:
        return
    }
  }

  private initDelayPlay(context: object) {
    this.mContext = context
    let that = this
    setTimeout(() => {
      that.startPlayOrResumePlay()
    }, 150)
  }

  private togglePlayState() {
    this.playing ? this.pause() : this.startPlayOrResumePlay()
  }

  private async startPlayOrResumePlay() {
    this.playing = true
    this.mDestroyPage = false
    if (this.CONTROL_PlayStatus == PlayStatus.INIT) {
      this.stopProgressTask()
      this.startProgressTask()
      this.play()
      setTimeout(() => {
        this.videoStartPlayTime(VideoOperateUtil.getVideoStartPlayTimeMode(this.nowPlaying!))
      }, 600)
    }
    if (this.CONTROL_PlayStatus == PlayStatus.PAUSE) {
      this.mIjkMediaPlayer?.start()
      this.setProgress()
    }
    if (!this.avSession && Setting.allowBackgroundPlay) {
      this.avSession = await AVSessionUtil.getAVSession()
      await this.setSessionListener()
      AVSessionUtil.setSessionInfo(this.nowPlaying!)
      AVSessionUtil.updatePlaybackSessionState(this.playing, this.play_time)
    }
    AVSessionUtil.updatePlaybackSessionState(this.playing, this.play_time)
  }

  private startProgressTask() {
    let that = this
    this.updateProgressTimer = setInterval(() => {
      if (!that.mDestroyPage) {
        that.setProgress()
      }
    }, 300)
  }

  private stopProgressTask() {
    clearInterval(this.updateProgressTimer)
  }

  private setProgress() { //设置进度条
    let position = this.mIjkMediaPlayer?.getCurrentPosition()!
    let duration = this.mIjkMediaPlayer?.getDuration()!
    let pos = 0
    this.total_time = duration
    if (duration > 0) {
      this.slideEnable = true
      let curPercent = position / duration
      pos = curPercent * 100
      if (pos > (this.total_time || 0)) {
        this.play_time = this.total_time || 0
      } else {
        this.play_time = pos
      }
    }
    if (position > duration) {
      position = duration
    }
    this.play_time = position
    if (this.nowPlaying?.time === 0) {
      this.nowPlaying.time = this.total_time // 若系统无法识别视频时长，则由 FFMpeg API 提供以保存记忆时间
      VideoOperateUtil.saveVideoTotalTime(PathUtils.appContext!, this.nowPlaying)
    }
  }

  private showRePlay() {
    this.loadingVisible = Visibility.None
    this.replayVisible = Visibility.Visible
  }

  private play() {
    let that = this
    //设置XComponent回调的context
    if (!!this.mContext) {
      this.mIjkMediaPlayer?.setContext(this.mContext, 'xcomponentId')
    }
    if (this.CONTROL_PlayStatus == PlayStatus.INIT) {
      this.mIjkMediaPlayer?.reset()
    }
    this.CONTROL_PlayStatus = PlayStatus.PLAY
    //设置debug模式
    this.mIjkMediaPlayer?.setDebug(false)
    //初始化配置
    this.mIjkMediaPlayer?.native_setup()
    // 初始化配置后需要重新设置音频流音量，否则音量为默认值1.0
    this.mIjkMediaPlayer?.setVolume('1.0', '1.0')
    //设置视频源
    this.mIjkMediaPlayer?.setDataSource(this.video_url)
    //使用精确寻帧 例如，拖动播放后，会寻找最近的关键帧进行播放，很有可能关键帧的位置不是拖动后的位置，而是较前的位置.可以设置这个参数来解决问题
    this.mIjkMediaPlayer?.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "enable-accurate-seek", "1")
    //预读数据的缓冲区大小
    this.mIjkMediaPlayer?.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "max-buffer-size", '943718400')
    this.mIjkMediaPlayer?.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "min-frames", "120")
    this.mIjkMediaPlayer?.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "start-on-prepared", "1")
    this.mIjkMediaPlayer?.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "videotoolbox", "1") // 用硬件解码
    this.mIjkMediaPlayer?.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "packet-buffering", "1")
    this.mIjkMediaPlayer?.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "framedrop", "5")
    this.mIjkMediaPlayer?.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "mediacodec-all-videos", "1")
    this.mIjkMediaPlayer?.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "mediacodec-hevc", "0")
    this.mIjkMediaPlayer?.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "mediacodec-sync", "1")
    this.mIjkMediaPlayer?.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "mediacodec-auto-rotate", "1")
    this.mIjkMediaPlayer?.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "mediacodec-handle-resolution-change", "1")
    this.mIjkMediaPlayer?.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "skip_loop_filter", "48L")
    this.mIjkMediaPlayer?.setOption(IjkMediaPlayer.OPT_CATEGORY_FORMAT, "analyzeduration", "100")
    this.mIjkMediaPlayer?.setOption(IjkMediaPlayer.OPT_CATEGORY_FORMAT, "analyzemaxduration", '100L')
    this.mIjkMediaPlayer?.setOption(IjkMediaPlayer.OPT_CATEGORY_FORMAT, "lush_packets", '1L')
    // 重置错误状态
    this.mIjkMediaPlayer?.setOption(IjkMediaPlayer.OPT_CATEGORY_FORMAT, "skip_clear", "0")
    // 使用相对安全模式
    this.mIjkMediaPlayer?.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "seek-at-start", "1")
    // 屏幕常亮
    this.mIjkMediaPlayer?.setScreenOnWhilePlaying(true)
    // 变速播放
    this.mIjkMediaPlayer?.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "soundtouch", "1")
    this.mIjkMediaPlayer?.setSpeed(this.playSpeed + '')
    //是否开启循环播放
    this.mIjkMediaPlayer?.setLoopCount(true)
    let mOnVideoSizeChangedListener: OnVideoSizeChangedListener = {
      onVideoSizeChanged: (width: number, height: number, sar_num: number, sar_den: number) => {
        console.log('video size: ' + sar_num + ':' + sar_den)
        if (height === 0) {
          return
        }
        const aspectRatioNow = width / height
        const screenAspectRatio = this.screenWidth / this.screenHeight
        if (aspectRatioNow > screenAspectRatio) {
          this.play_area_width = this.screenWidth
          this.play_area_height = this.play_area_width * (height / width)
        } else {
          this.play_area_height = this.screenHeight
          this.play_area_width = this.play_area_height * (width / height)
        }
        that.getVideoSize()
      }
    }
    this.mIjkMediaPlayer?.setOnVideoSizeChangedListener(mOnVideoSizeChangedListener)
    let mOnPreparedListener: OnPreparedListener = {
      onPrepared: () => {
      }
    }
    this.mIjkMediaPlayer?.setOnPreparedListener(mOnPreparedListener)

    let mOnTimedTextListener: OnTimedTextListener = {
      onTimedText: () => {
      }
    }
    this.mIjkMediaPlayer?.setOnTimedTextListener(mOnTimedTextListener)
    // 播完之后
    let mOnCompletionListener: OnCompletionListener = {
      onCompletion: () => {
        that.showRePlay()
        that.play_time = this.mIjkMediaPlayer?.getDuration()!
        that.slideEnable = false
        that.stop()
      }
    }
    this.mIjkMediaPlayer?.setOnCompletionListener(mOnCompletionListener)
    let mOnBufferingUpdateListener: OnBufferingUpdateListener = {
      onBufferingUpdate: (percent: number) => {
        let MediaInfo = this.mIjkMediaPlayer?.getMediaInfo()
        let VideoWidth = this.mIjkMediaPlayer?.getVideoWidth()
        let VideoHeight = this.mIjkMediaPlayer?.getVideoHeight()
        let VideoSarNum = this.mIjkMediaPlayer?.getVideoSarNum()
        let VideoSarDen = this.mIjkMediaPlayer?.getVideoSarDen()
        let AudioSessionId = this.mIjkMediaPlayer?.getAudioSessionId()
        let Looping = this.mIjkMediaPlayer?.isLooping()
        console.log('video_info: percent=' + percent + 'MediaInfo=' + MediaInfo + 'VideoWidth=' + VideoWidth +
          'VideoHeight=' + VideoHeight + 'VideoSarNum=' + VideoSarNum + 'VideoSarDen=' + VideoSarDen +
          'AudioSessionId=' + AudioSessionId + 'Looping=' + Looping)
      }
    }
    this.mIjkMediaPlayer?.setOnBufferingUpdateListener(mOnBufferingUpdateListener)
    let mOnSeekCompleteListener: OnSeekCompleteListener = {
      onSeekComplete: () => {
        that.startPlayOrResumePlay()
      }
    }
    this.mIjkMediaPlayer?.setOnSeekCompleteListener(mOnSeekCompleteListener)

    let mOnInfoListener: OnInfoListener = {
      onInfo: (what: number, extra: number) => {
        console.log("OnInfoListener-->go:" + what + "===" + extra)
      }
    }
    this.mIjkMediaPlayer?.setOnInfoListener(mOnInfoListener)

    let mOnErrorListener: OnErrorListener = {
      onError: (_what: number, _extra: number) => {
        this.stopProgressTask()
        VideoOperateUtil.playErrorExecute(this.pathStack, this.videoMetaData, this.nowPlaying?.date!,
          NavigationAddress.RED_PLAYER)
      }
    }
    this.mIjkMediaPlayer?.setOnErrorListener(mOnErrorListener)
    this.mIjkMediaPlayer?.setMessageListener()
    this.mIjkMediaPlayer?.prepareAsync()
    this.mIjkMediaPlayer?.start()
  }

  private pause() {
    this.playing = false
    this.mIjkMediaPlayer?.pause()
    this.setProgress()
    this.mDestroyPage = true
    this.CONTROL_PlayStatus = PlayStatus.PAUSE
    AVSessionUtil.updatePlaybackSessionState(this.playing, this.play_time)
  }

  private stop() {
    AVSessionUtil.updatePlaybackSessionState(this.playing, this.play_time)
    this.CONTROL_PlayStatus = PlayStatus.INIT
    this.mIjkMediaPlayer?.stop()
    this.mIjkMediaPlayer?.release()
    this.stopProgressTask()
    this.mIjkMediaPlayer = null
  }

  private getVideoSize() {
    let VideoWidth = this.mIjkMediaPlayer?.getVideoWidth()!
    let VideoHeight = this.mIjkMediaPlayer?.getVideoHeight()!
    if (this.nowPlaying?.size[0] === 0 && VideoWidth !== 0) {
      this.nowPlaying.size[0] = VideoWidth
      this.nowPlaying.size[1] = VideoHeight
      VideoOperateUtil.saveVideoWeightAndHeight(PathUtils.appContext!, this.nowPlaying)
    }
    const aspectRatioNow = VideoWidth / VideoHeight
    const screenAspectRatio = this.screenWidth / this.screenHeight
    if (aspectRatioNow > screenAspectRatio) {
      this.play_area_width = this.screenWidth
      this.play_area_height = this.play_area_width * (VideoHeight / VideoWidth)
    } else {
      this.play_area_height = this.screenHeight
      this.play_area_width = this.play_area_height * (VideoWidth / VideoHeight)
    }
  }
}