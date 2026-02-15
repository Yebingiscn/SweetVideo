import NavigationAddress, { PlayerParams } from '../../common/NavigationCommon'
import { MpvController } from '../../controller/MpvController/MpvController'
import { PlayerControllerFactory } from '../../controller/PlayerControllerFactory'
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import { Privacy, Setting } from '../../utils/ObservedUtil'
import { PathUtils } from '../../utils/PathUtils'
import VideoOperateUtil from '../../utils/VideoOperateUtil'
import { WindowUtil } from '../../utils/WindowUtil'
import { KeyCode } from '@kit.InputKit'
import PermissionUtil from '../../utils/PermissionUtil'
import { fileIo as fs } from '@kit.CoreFileKit'
import { XAnimation } from '../../utils/AnimationUtil'
import { FastForwardPanelBuilder } from '../../component/PlayerComponent/FastForwardPanelBuilder'
import { SwipingPlayTimePanelBuilder } from '../../component/PlayerComponent/SwipingPlayTimePanelBuilder'
import { VolumeSwipingPanelBuilder } from '../../component/PlayerComponent/VolumeSwipingPanelBuilder'
import { BrightnessSwipingBuilder } from '../../component/PlayerComponent/BrightnessSwipingBuilder'
import { LockVideoBarComponent } from '../../component/PlayerComponent/LockVideoBarComponent'
import { AIAsr } from '../../component/PlayerComponent/AIAsrComponent'
import { GestureComponent } from '../../component/PlayerComponent/GestureComponent'
import VideoInfoUtil from '../../utils/VideoInfoUtil'
import ToolsUtil from '../../utils/ToolsUtil'
import { VideoSliderComponent } from '../../component/PlayerComponent/VideoSliderComponent'
import { AVCastPickerBuilder } from '../../component/PlayerComponent/AVCastPickerBuilder'
import { ButtonFancyModifier } from '../../common/AttributeModifierConfig'
import AVSessionUtil from '../../utils/AVSessionUtil'
import { AVCastPicker } from '@kit.AVSessionKit'
import { audio } from '@kit.AudioKit'
import { window } from '@kit.ArkUI'
import { AudioTrackComponent } from '../../component/PlayerComponent/AudioTrackComponent'
import { SubtitlePanelComponent } from '../../component/PlayerComponent/SubtitlePanelComponent'
import { Subtitle3DMode } from '../../common/enum/SubtitleMode'
import { VideoTopComponent } from '../../component/PlayerComponent/VideoTopComponent'
import { PlaybackSpeedMenuComponent } from '../../component/PlayerComponent/PlaybackSpeedComponent'
import { XComponents } from '../../component/PlayerComponent/XComponents'
import { VideoLayoutComponent } from '../../component/PlayerComponent/VideoLayoutComponent'
import {
  LEFT_ZONE_DIVISION,
  MAX_SCALE_FACTOR,
  MAX_WIDTH_MULTIPLIER,
  MIN_SCALE_FACTOR,
  MIN_WIDTH_MULTIPLIER,
  NO_BLUR_AMOUNT,
  PINCH_SCALE_SENSITIVITY,
  PRIVACY_BACKGROUND_BLUR_AMOUNT,
  RIGHT_ZONE_DIVISION,
  SCREEN_DIVISIONS,
  SCREEN_HALF_DIVIDER,
  SWIPE_THRESHOLD,
  VERTICAL_PAN_SENSITIVITY,
  VOLUME_PAN_MULTIPLIER,
  VOLUME_STEP
} from '../../common/Constants'

@Component
export struct MpvPlayer {
  xComponentController: XComponentController = new XComponentController()
  @State subtitleVisibility: Visibility = Visibility.Visible
  @State lockRotation: boolean = false
  @Consume('pathStack') pathStack: NavPathStack
  @Provide('MpvPlayer') mpv: MpvController = PlayerControllerFactory.createMpvController()
  @State @Watch('setScreen') showControl: boolean = false
  @State longPress: boolean = false
  @State isLock: boolean = false
  @State onSwiping: boolean = false
  @State isSliderPlayTimeChange: boolean = false
  @State onSwipingBrightness: boolean = false
  @State lockVisibility: boolean = false
  @State isAIAsrShown: boolean = false
  @State currentSpeedIndex: number = 0
  @State sideBarStatus: boolean = false
  @State sideBarStatusTmp: Visibility = Visibility.Hidden
  @State screenBrightness: number = 0
  @State audioTrackSelect: number = 0
  @State subtitle3DMode: Subtitle3DMode = Subtitle3DMode.DISABLED

  async aboutToAppear(): Promise<void> {
    this.mpv.prepare()
    PermissionUtil.applyContinuousTask()
    this.setScreen()
    try {
      await (await this.mpv.windowClass)?.setPreferredOrientation(window.Orientation.AUTO_ROTATION_RESTRICTED)
      WindowUtil.setKeepScreenStatus(PathUtils.appContext!, true)
    } catch (error) {
      console.error('setPreferredOrientation error:' + error)
    }
    WindowUtil.enableLandscapeMultiWindow(this.mpv.windowClass)
    this.screenBrightness = await VideoOperateUtil.getScreenBrightness()
    let groupId: number = audio.DEFAULT_VOLUME_GROUP_ID
    let audioManager = audio.getAudioManager()
    this.mpv.audioVolumeManager = audioManager.getVolumeManager()
    let volumeList = await VideoOperateUtil.getVolume(this.mpv.audioVolumeManager, groupId)
    this.mpv.volume = volumeList.get('volume')!
    this.mpv.volumeActually = this.mpv.volume
    let changeVolumeByVolumeButton = false
    let swipingVoiceTimer: number | null = null
    try {
      this.mpv.audioVolumeManager.on('volumeChange', (volumeEvent: audio.VolumeEvent) => {
        clearTimeout(swipingVoiceTimer)
        if (!this.mpv.onSwipingVoice) { // 这里复用手势音量调节提示
          this.mpv.onSwipingVoice = !this.mpv.onSwipingVoice
          changeVolumeByVolumeButton = true
        }
        this.mpv.volumeActually = volumeEvent.volume
        ToolsUtil.startVibration()
        swipingVoiceTimer = setTimeout(() => {
          if (changeVolumeByVolumeButton) {
            this.mpv.onSwipingVoice = !this.mpv.onSwipingVoice
            changeVolumeByVolumeButton = false
          }
        }, 800)
      })
    } catch (error) {
      console.error('volumeChange error:' + error)
    }
  }

  aboutToDisappear(): void {
    VideoOperateUtil.setBrightness(-1)
    try {
      this.mpv.audioVolumeManager?.off('volumeChange')
      ToolsUtil.addLogger("取消音量变化监听完成", false, this.pathStack)
    } catch (error) {
      ToolsUtil.addLogger(`音量监听取消错误 ${error}`, true, this.pathStack)
    }
  }

  build() {
    NavDestination() {
      Stack() {
        XComponents({
          playAreaHeight: this.mpv.playAreaHeight,
          playAreaWidth: this.mpv.playAreaWidth,
          playTime: this.mpv.playTime,
          xComponentController: this.xComponentController,
          xComponentId: 'xcomponentId',
          libraryName: 'mpvnative',
          choosePlayer: NavigationAddress.MPV_PLAYER,
          angle: this.mpv.angle,
          screenHeight: this.mpv.screenHeight,
          screenWidth: this.mpv.screenWidth,
          showControl: this.showControl,
          subtitle3DMode: this.subtitle3DMode,
          subtitleVisibility: this.subtitleVisibility,
          onXComponentLoad: async () => {
            await PermissionUtil.activatePermission(this.mpv.nowPlaying?.uri)
            try {
              const file = fs.openSync(this.mpv!.nowPlaying!.uri)
              this.mpv.init(file.path, 0)
              await this.mpv.initAVSession()
            } catch (error) {
              console.error('uri error:' + error)
            }
          },
          onKeyCodeEscape: () => {
            VideoOperateUtil.fullScreenOrRotateScreen(this.mpv.screenWidth, this.mpv.screenHeight,
              this.mpv.windowClass)
          },
          onKeyCodeLeft: () => {
            this.mpv.backForward()
          },
          onKeyCodeRight: () => {
            this.mpv.fastForward()
          },
          onKeyCodeSpace: () => {
            this.mpv.togglePlayback()
          },
          onKeyCodeUpAndDown: (event: KeyEvent) => {
            this.mpv.volume = this.mpv.volumeActually
            const newVolume = VideoOperateUtil.changeVolume(this.mpv.volume,
              event.keyCode === KeyCode.KEYCODE_DPAD_UP ? VOLUME_STEP : -VOLUME_STEP)
            this.mpv.volume = newVolume
            this.mpv.volumeActually = newVolume
            VideoOperateUtil.lastVolume = newVolume
          },
        })

        if (this.showControl && !this.isLock) {
          VideoLayoutComponent({
            screenHeight: this.mpv.screenHeight,
            screenWidth: this.mpv.screenWidth,
            showControl: this.showControl,
            VideoTop: () => {
              this.VideoTop()
            },
            VideoButtons: () => {
              this.VideoButtons()
            },
            VideoSlider: () => {
              this.VideoSlider()
            },
          })
        }

        if (this.longPress) {
          FastForwardPanelBuilder({
            speed: this.mpv.speed,
            location: this.mpv.playAreaHeight,
          })
        }

        if (this.onSwiping) {
          SwipingPlayTimePanelBuilder({
            isSliderPlayTimeChange: this.isSliderPlayTimeChange,
            playTime: this.mpv.playTime,
            totalTime: this.mpv.nowPlaying!.time,
            pixelMap: null,
            player: NavigationAddress.MPV_PLAYER
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
            screenHeight: this.mpv.screenHeight,
            screenWidth: this.mpv.screenWidth,
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
            const zoneWidth = this.mpv.screenWidth / SCREEN_DIVISIONS // 屏幕五分之一宽度
            if (tapX < zoneWidth * LEFT_ZONE_DIVISION) { // 左侧1/5区域：回退
              this.mpv.backForward()
              return
            }
            if (tapX > zoneWidth * RIGHT_ZONE_DIVISION) { // 右侧1/5区域：快进
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
            VideoOperateUtil.leftSideSwipe = tapX < this.mpv.screenWidth / SCREEN_HALF_DIVIDER
            VideoOperateUtil.screenBrightnessTmp = this.mpv.screenBrightness
            this.mpv.volume = this.mpv.volumeActually
            VideoOperateUtil.lastVolume = this.mpv.volume // 记录起始音量
          },
          onVerticalPanUpdate: (offsetY: number) => {
            const deltaYScale = offsetY / this.mpv.screenHeight * VERTICAL_PAN_SENSITIVITY
            if (VideoOperateUtil.leftSideSwipe) {
              this.onSwipingBrightness = true
              this.mpv.screenBrightness = VideoOperateUtil.calNewBrightness(deltaYScale)
              VideoOperateUtil.setBrightness(this.mpv.screenBrightness)
            } else {
              this.mpv.onSwipingVoice = true
              const newVolume = VideoOperateUtil.lastVolume - deltaYScale * VOLUME_PAN_MULTIPLIER
              this.mpv.volume =
                Math.min(Math.max(newVolume, VideoOperateUtil.minVolume), VideoOperateUtil.maxVolume)
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
            const timePerPixel = VideoOperateUtil.getTimePixel(this.mpv.screenWidth, this.mpv.nowPlaying?.time!)
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
            const adjustedScale = 1 + (rawScale - 1) * PINCH_SCALE_SENSITIVITY // 计算调整后的缩放比例
            const clampedScale = Math.min(Math.max(adjustedScale, MIN_SCALE_FACTOR), MAX_SCALE_FACTOR)
            const scaledWidth = this.mpv.playAreaWidth * clampedScale // 计算缩放后的播放区域宽度
            const maxAllowed = VideoInfoUtil.playAreaWidth * MAX_WIDTH_MULTIPLIER
            const minAllowed = VideoInfoUtil.playAreaWidth * MIN_WIDTH_MULTIPLIER
            if (scaledWidth > maxAllowed || scaledWidth < minAllowed) { // 检查缩放是否超出允许范围
              return
            }
            this.mpv.playAreaWidth = scaledWidth
            this.mpv.playAreaHeight = this.mpv.playAreaHeight * clampedScale
            XAnimation.runWithAnimation(() => {
              this.mpv.playAreaWidth = this.mpv.playAreaWidth
              this.mpv.playAreaHeight = this.mpv.playAreaHeight
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
            this.mpv.speed = VideoOperateUtil.lastSpeed
            this.mpv.updatePlaybackSpeed(this.mpv.speed)
          },
          onLongPressPanStart: (tapX: number) => {
            VideoOperateUtil.longPressStartX = tapX
          },
          onLongPressPanUpdate: (tapX: number) => {
            if (this.longPress) { // 长按状态下的滑动处理
              const deltaX = tapX - VideoOperateUtil.longPressStartX
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
            y: this.mpv.screenWidth > this.mpv.screenHeight ? this.mpv.screenHeight / 2 - 40 :
              this.mpv.screenHeight / 2 - 100
          })
      }.onAreaChange(async (_oldValue: Area, newValue: Area) => {
        this.mpv.screenWidth = Math.floor(new Number(newValue.width).valueOf())
        this.mpv.screenHeight = Math.floor(new Number(newValue.height).valueOf())
        await this.mpv.setRotation()
      })
      .height('100%')
      .width('100%')
      .backgroundColor($r('sys.color.black'))
    }
    .onReady(() => {
      const playerParams: PlayerParams =
        this.pathStack.getParamByName(NavigationAddress.MPV_PLAYER)[0] as PlayerParams
      try {
        this.mpv.nowPlaying = playerParams.metadata as VideoMetadata
        this.mpv.videoMetaDataList = playerParams.metadata_list as VideoMetadata[]
      } catch (e) {
        console.error(e)
      }
    })
    .onWillDisappear(async () => {
      if (this.mpv.videoMetaDataList.length > 0 && this.mpv.playTime > 0) {
        VideoOperateUtil.saveVideoTime(this.mpv.playTime, this.mpv.nowPlaying!, this.mpv.videoMetaDataList,
          PathUtils.appContext!)
      }
      PermissionUtil.applyStopContinuousTask()
      WindowUtil.setKeepScreenStatus(PathUtils.appContext!, false)
      WindowUtil.setBarState(PathUtils.appContext!, true, true)
      try {
        await this.mpv.avSession?.stopCasting()
      } catch (error) {
        console.error('stop cast fail')
      }
      try {
        await (await this.mpv.windowClass)?.setPreferredOrientation(window.Orientation.AUTO_ROTATION_RESTRICTED)
      } catch (error) {
        console.error('setPreferredOrientation' + error)
      }
    })
    .onBackPressed(() => {
      if (this.showControl && !Setting.allowPlayBackExist) {
        this.showControl = false
        this.lockVisibility = false
        return true
      } else {
        this.exitVideo()
        return false
      }
    })
    .hideTitleBar(true)
    .blur(Privacy.isPrivacyBackground ? PRIVACY_BACKGROUND_BLUR_AMOUNT : NO_BLUR_AMOUNT)
  }

  closeSideBar(_arg0: boolean) {
    throw new Error('Method not implemented.')
  }

  setScreen() {
    WindowUtil.setBarState(PathUtils.appContext!, this.showControl, this.showControl)
  }

  @Builder
  VideoTop() {
    VideoTopComponent({
      videoTitle: this.mpv.nowPlaying?.title,
      subTitleVisibility: this.subtitleVisibility,
      subtitleSelected: this.mpv.subtitleSelected,
      isAIAsrShown: this.isAIAsrShown,
      screenExtendSelectedText: this.mpv.selectedText,
      screenWidth: this.mpv.screenWidth,
      screenHeight: this.mpv.screenHeight,
      audioTrackMenuBuilder: () => {
        this.AudioTrackMenuBuilder()
      },
      subtitlePanelComponent: () => {
        this.SubtitleMenuBuilder()
      },
      lockRotation: this.lockRotation,
      playAreaHeight: this.mpv.playAreaHeight,
      playAreaWidth: this.mpv.playAreaWidth,
      onExitVideoClick: () => {
        ToolsUtil.addLogger("点击退出视频按钮", false, this.pathStack)
        this.exitVideo()
      },
      onLockRotationClick: async () => {
        this.lockRotation = !this.lockRotation
        ToolsUtil.addLogger(`锁定旋转状态切换为：${this.lockRotation}`, false, this.pathStack)
        const orientation = this.lockRotation ?
          (this.mpv.screenWidth > this.mpv.screenHeight ? window.Orientation.AUTO_ROTATION_LANDSCAPE_RESTRICTED
            : window.Orientation.AUTO_ROTATION_PORTRAIT_RESTRICTED)
          : window.Orientation.AUTO_ROTATION_RESTRICTED
        try {
          XAnimation.runWithAnimation(async () => {
            await (await this.mpv.windowClass)?.setPreferredOrientation(orientation)
            ToolsUtil.addLogger("窗口方向设置成功", false, this.pathStack)
          })
        } catch (error) {
          ToolsUtil.addLogger(`屏幕旋转异常: ${error.code}:${error.message}`, true, this.pathStack)
        }
        const toastMessage = this.lockRotation
          ? ToolsUtil.getStringResource($r('app.string.open_rotation_lock').id)
          : ToolsUtil.getStringResource($r('app.string.close_rotation_lock').id)
        ToolsUtil.showToast(toastMessage)
        ToolsUtil.addLogger(`显示旋转锁定提示：${toastMessage}`, false, this.pathStack)
      },
      onSpecificVideoProportions: (playAreaSize: number[]) => {
        this.mpv.playAreaWidth = playAreaSize[0]
        this.mpv.playAreaHeight = playAreaSize[1]
      },
      onOriginalRatio: () => {
        this.mpv.playAreaHeight = this.mpv.playAreaHeight
        this.mpv.playAreaWidth = this.mpv.playAreaWidth
      },
      onStretchedToFullScreen: () => {
        this.mpv.playAreaHeight = this.mpv.screenHeight
        this.mpv.playAreaWidth = this.mpv.screenWidth
      },
      onFullScreenByWidth: () => {
        this.mpv.playAreaWidth = this.mpv.screenWidth
        this.mpv.playAreaHeight = (VideoInfoUtil.playAreaHeight / VideoInfoUtil.playAreaWidth) * this.mpv.screenWidth
      },
      onFullScreenByHeight: () => {
        this.mpv.playAreaHeight = this.mpv.screenHeight
        this.mpv.playAreaWidth = (VideoInfoUtil.playAreaWidth / VideoInfoUtil.playAreaHeight) * this.mpv.screenHeight
      },
      onUniformScale: (scale: number) => {
        this.mpv.playAreaHeight = scale * VideoInfoUtil.playAreaHeight
        this.mpv.playAreaWidth = scale * VideoInfoUtil.playAreaWidth
      },
      onSelectedTextChange: (text: string) => {
        this.mpv.selectedText = text
      },
    })
  }

  exitVideo() {
    this.mpv.release()
    this.pathStack.pop()
  }

  @Builder
  VideoButtons() {
    GridRow({ columns: 14, gutter: 5 }) {
      GridCol() {
        Button({ type: ButtonType.Circle, stateEffect: true }) { // 播放按钮
          SymbolGlyph(this.mpv.playing ? $r('sys.symbol.pause_fill') : $r('sys.symbol.play_fill'))
            .fontSize(27)
            .fontColor(['#f0f0f0'])
            .symbolEffect(new ReplaceSymbolEffect(EffectScope.WHOLE), Number(this.mpv.playing))
        }
        .attributeModifier(new ButtonFancyModifier(40, 40))
        .backgroundColor('#50000000')
        .onClick(() => {
          ToolsUtil.startVibration()
          this.mpv.togglePlayback()
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
          VideoOperateUtil.fullScreenOrRotateScreen(this.mpv.screenWidth, this.mpv.screenHeight, this.mpv.windowClass)
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
        Button({ type: ButtonType.Circle, stateEffect: true }) { // 倍速调整按钮
          Text(`${this.mpv.speed}x`)
            .fontSize(18)
            .fontColor($r('sys.color.white'))
            .minFontSize(8)
            .maxFontSize(18)
            .maxLines(1)
            .padding(5)
        }
        .attributeModifier(new ButtonFancyModifier(40, 40))
        .backgroundColor('#50000000')
        .bindMenu(this.PlaybackSpeedMenuBuilder,
          { backgroundBlurStyle: BlurStyle.COMPONENT_ULTRA_THIN })
      }.span({ xs: 2, sm: 2, md: 2 })
    }.width('95%')
  }

  @Builder
  VideoSlider() {
    VideoSliderComponent({
      playTime: this.mpv.playTime,
      totalTime: this.mpv.nowPlaying?.time,
      screenWidth: this.mpv.screenWidth,
      screenHeight: this.mpv.screenHeight,
      playSpeed: this.mpv.speed,
      onSliderChange: (value: number) => {
        this.onSwiping = true
        this.isSliderPlayTimeChange = true
        this.mpv.playTime = value
      },
      onSliderTouch: (event: TouchEvent) => {
        if (event.type == TouchType.Up) {
          this.mpv.seekTime(this.mpv.playTime)
          this.isSliderPlayTimeChange = false
          this.onSwiping = false
        }
      }
    })
  }

  @Builder
  AudioTrackMenuBuilder() {
    AudioTrackComponent({
      audioTrack: this.mpv.audioTrack,
      audioTrackSelected: this.audioTrackSelect,
      onSelect: (index: number) => {
        ToolsUtil.addLogger(`选择音频轨道，索引：${index}`, false, this.pathStack)
        this.mpv?.selectAudioTrack(this.mpv?.audioTrack[index]?.id)
        this.audioTrackSelect = index
      }
    })
  }

  @Builder
  SubtitleMenuBuilder() {
    SubtitlePanelComponent({
      subTitleVisibility: this.subtitleVisibility,
      isAIAsrShown: this.isAIAsrShown,
      subtitle3DMode: this.subtitle3DMode,
      subtitleSelected: this.mpv.subtitleSelected,
      innerSubtitleData: this.mpv.subtitleTrack,
      mpv: this.mpv
    })
  }

  @Builder
  AVCastPickerBuilderBridge() { // 桥接AVCastPickerBuilder避免crash
    AVCastPickerBuilder()
  }

  @Builder
  PlaybackSpeedMenuBuilder() {
    PlaybackSpeedMenuComponent({
      speed: this.mpv.speed,
      player: NavigationAddress.MPV_PLAYER,
      onSpeedChange: (speed: number) => {
        this.mpv.updatePlaybackSpeed(speed)
      }
    })
  }
}

