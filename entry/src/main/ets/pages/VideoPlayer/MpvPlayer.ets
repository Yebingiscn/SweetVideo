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
import { XAnimation } from '../../utils/AnimationUtil'
import { FastForwardPanelBuilder } from '../../component/PlayerComponent/FastForwardPanelBuilder'
import { SwipingPlayTimePanelBuilder } from '../../component/PlayerComponent/SwipingPlayTimePanelBuilder'
import { VolumeSwipingPanelBuilder } from '../../component/PlayerComponent/VolumeSwipingPanelBuilder'
import { BrightnessSwipingBuilder } from '../../component/PlayerComponent/BrightnessSwipingBuilder'
import { LockVideoBarComponent } from '../../component/PlayerComponent/LockVideoBarComponent'
import { GestureComponent } from '../../component/PlayerComponent/GestureComponent'
import VideoInfoUtil from '../../utils/VideoInfoUtil'
import ToolsUtil from '../../utils/ToolsUtil'
import { window } from '@kit.ArkUI'
import { Subtitle3DMode } from '../../common/enum/SubtitleMode'
import { XComponents } from '../../component/PlayerComponent/XComponents'
import { VideoLayoutComponent } from '../../component/PlayerComponent/VideoLayoutComponent'
import {
  DEFAULT_ANGLE,
  MAX_SCALE_FACTOR,
  MAX_WIDTH_MULTIPLIER,
  MIN_SCALE_FACTOR,
  MIN_WIDTH_MULTIPLIER,
  MIRRORED_ANGLE,
  NO_BLUR_AMOUNT,
  PINCH_SCALE_SENSITIVITY,
  PRIVACY_BACKGROUND_BLUR_AMOUNT,
  SCREEN_HALF_DIVIDER,
  SWIPE_THRESHOLD,
  VERTICAL_PAN_SENSITIVITY,
  VOLUME_PAN_MULTIPLIER,
  VOLUME_STEP
} from '../../common/Constants'
import { AISubtitleComponent } from '../../component/PlayerComponent/AIAsrComponent'
import { PlayerSideBarComponent } from '../../component/PlayerComponent/PlayerSideBarComponent'
import PiPWindowUtil from '../../utils/PiPWindowUtil'
import { AudioTrackComponent } from '../../component/PlayerComponent/AudioTrackComponent'
import { AVCastPickerBuilder } from '../../component/PlayerComponent/AVCastPickerBuilder'
import { PlaybackSpeedMenuComponent } from '../../component/PlayerComponent/PlaybackSpeedComponent'
import { SubtitlePanelComponent } from '../../component/PlayerComponent/SubtitlePanelComponent'
import { VideoButtonsComponent } from '../../component/PlayerComponent/VideoButtonsComponent'
import { VideoSettingComponent } from '../../component/PlayerComponent/VideoSettingComponent'
import { VideoSliderComponent } from '../../component/PlayerComponent/VideoSliderComponent'
import { VideoTopComponent } from '../../component/PlayerComponent/VideoTopComponent'
import { RepeatMode } from '../../common/enum/RepeatMode'
import { DefaultDialogShadow } from '../../common/AttributeModifierConfig'
import { NumberInputDialog } from '../../component/Dialog/NumberInputDialog'

@Component
export struct MpvPlayer {
  xComponentController: XComponentController = new XComponentController()
  osdXController: XComponentController = new XComponentController()
  @State subtitleVisibility: Visibility = Visibility.Visible
  @State lockRotation: boolean = false
  @Consume('pathStack') pathStack: NavPathStack
  @Provide('player') mpv: MpvController = PlayerControllerFactory.createMpvController()
  personalScreenExtendDialog: CustomDialogController = new CustomDialogController({
    builder: NumberInputDialog({
      title: '自定义屏幕拓展比例',
      placeholderColor: '输入范围：50-150',
      confirm: (input: number) => {
        if (input && input <= 150 && input >= 50) {
          this.mpv.playAreaHeight = input / 100 * VideoInfoUtil.playAreaHeight
          this.mpv.playAreaWidth = input / 100 * VideoInfoUtil.playAreaWidth
        } else {
          ToolsUtil.showToast('输入错误')
        }
      },
    }), cornerRadius: 20, shadow: DefaultDialogShadow
  })
  @State @Watch('setScreen') showControl: boolean = false
  @State isAIAsrShown: boolean = false
  @State currentSpeedIndex: number = 0
  @State sideBarStatus: boolean = false
  @State sideBarStatusTmp: Visibility = Visibility.Hidden
  @State subtitle3DMode: Subtitle3DMode = Subtitle3DMode.DISABLED
  @State exitVideoTime: number = 0

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
    this.mpv.initVolumeAndBrightness()
  }

  aboutToDisappear(): void {
    VideoOperateUtil.setBrightness(-1)
    WindowUtil.recoveryBarColor()
    try {
      this.mpv.audioVolumeManager?.off('streamVolumeChange')
      this.mpv.audioVolumeManager = null
      ToolsUtil.addLogger("取消音量变化监听完成", false, this.pathStack)
    } catch (error) {
      ToolsUtil.addLogger(`音量监听取消错误 ${error}`, true, this.pathStack)
    }
  }

  build() {
    NavDestination() {
      SideBarContainer(SideBarContainerType.Overlay) {
        PlayerSideBarComponent({
          sideBarStatusTmp: this.sideBarStatusTmp,
          sideBarStatus: this.sideBarStatus,
          onItemClick: async (item: VideoMetadata) => {
            this.mpv.playChooseVideo(item)
            this.closeSideBar(true)
          }
        })
        Stack() {
          XComponents({
            xComponentController: this.xComponentController,
            xComponentId: 'xcomponentId',
            libraryName: 'mpvnative',
            choosePlayer: NavigationAddress.MPV_PLAYER,
            showControl: this.showControl,
            subtitle3DMode: this.subtitle3DMode,
            subtitleVisibility: this.subtitleVisibility,
            osdXController: this.osdXController,
            osdVisibility: this.mpv.osdVisibility,
            onXComponentLoad: async () => {
              await PermissionUtil.activatePermission(this.mpv.nowPlaying?.uri)
              try {
                this.mpv.init(this.mpv.nowPlaying!.uri, 0)
                await this.mpv.initAVSession()
                PiPWindowUtil.createPipController(this.xComponentController, this.mpv)
                this.mpv.surfaceId = this.xComponentController.getXComponentSurfaceId()
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

          if (this.showControl && !this.mpv.isLock) {
            VideoLayoutComponent({
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

          if (this.mpv.longPress) {
            FastForwardPanelBuilder({
              speed: this.mpv.speed,
              location: this.mpv.playAreaHeight,
            })
          }

          if (this.mpv.onSwiping) {
            SwipingPlayTimePanelBuilder({
              isSliderPlayTimeChange: this.mpv.isSliderPlayTimeChange,
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
          if (this.mpv.onSwipingBrightness) {
            BrightnessSwipingBuilder({ screenBrightness: this.mpv.screenBrightness })
          }
          if (this.mpv.lockVisibility) {
            LockVideoBarComponent({
              onLockClick: () => {
                this.mpv.isLock = !this.mpv.isLock
                this.showControl = true
              }
            })
          }
          GestureComponent({
            showControl: this.showControl,
            onDoubleClickAction: (tapX: number) => {
              this.mpv.onScreenDoubleClick(tapX)
            },
            onSingleClickAction: () => {
              if (this.sideBarStatus) {
                this.closeSideBar(true)
              } else {
                this.mpv.lockVisibility = !this.mpv.lockVisibility
                XAnimation.runWithAnimation(() => {
                  if (this.mpv.isLock) {
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
                this.mpv.onSwipingBrightness = true
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
              this.mpv.onSwiping = false
              this.mpv.onSwipingVoice = false
              this.mpv.onSwipingBrightness = false
            },
            onHorizonPanStart: () => {
              VideoOperateUtil.lastPlayTime = this.mpv.playTime
              this.mpv.onSwiping = true
            },
            onHorizonPanUpdate: (offsetX: number) => {
              const timePerPixel = VideoOperateUtil.getTimePixel(this.mpv.screenWidth, this.mpv.nowPlaying?.time!)
              this.mpv.playTime = Math.max(0,
                Math.min(VideoOperateUtil.lastPlayTime + (offsetX * timePerPixel), this.mpv.nowPlaying?.time!))
            },
            onHorizonPanEnd: () => {
              this.mpv.seekTime(this.mpv.playTime)
              this.mpv.onSwiping = false
            },
            onPinchStart: (fingerDistance: number) => {
              VideoOperateUtil.initPinchDistance = fingerDistance
              this.mpv.translateX = 0
              this.mpv.translateY = 0
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
              this.mpv.isZoomed = clampedScale !== 1
              XAnimation.runWithAnimation(() => {
                this.mpv.playAreaWidth = this.mpv.playAreaWidth
                this.mpv.playAreaHeight = this.mpv.playAreaHeight
              })
            },
            onPinchEnd: () => {
              this.mpv.isZoomed = this.mpv.playAreaWidth !== VideoInfoUtil.playAreaWidth
            },
            onLongPressAction: () => {
              if (this.mpv.playing) {
                this.mpv.longPress = true
                VideoOperateUtil.lastSpeed = this.mpv.speed
                this.mpv.updatePlaybackSpeed(Setting.longPressSpeed)
                this.currentSpeedIndex = VideoInfoUtil.videoSpeedListAll.indexOf(Setting.longPressSpeed)
              }
            },
            onLongPressEnd: () => {
              this.mpv.longPress = false
              this.mpv.speed = VideoOperateUtil.lastSpeed
              this.mpv.updatePlaybackSpeed(this.mpv.speed)
            },
            onLongPressPanStart: (tapX: number) => {
              VideoOperateUtil.longPressStartX = tapX
            },
            onLongPressPanUpdate: (tapX: number) => {
              if (this.mpv.longPress) { // 长按状态下的滑动处理
                const deltaX = tapX - VideoOperateUtil.longPressStartX
                if (Math.abs(deltaX) <= SWIPE_THRESHOLD) { // 未达到滑动阈值则直接返回
                  return
                }
                const direction = Math.sign(deltaX)
                const newIndex = this.currentSpeedIndex + direction // 计算新速度索引并限制在有效范围内
                const clampedIndex = Math.max(0, Math.min(newIndex, VideoInfoUtil.videoSpeedListAll.length - 1))
                if (clampedIndex === this.currentSpeedIndex) { // 索引变化时才更新播放速度
                  return
                }
                this.currentSpeedIndex = clampedIndex
                this.mpv.updatePlaybackSpeed(VideoInfoUtil.videoSpeedListAll[this.currentSpeedIndex])
                VideoOperateUtil.longPressStartX = tapX // 重置起始点实现分档切换效果
              }
            },
            onPanMoveStart: (event: GestureEvent) => {
              VideoOperateUtil.panStartX = event.fingerList[0]?.localX || 0
              VideoOperateUtil.panStartY = event.fingerList[0]?.localY || 0
            },
            onPanMoveUpdate: (event: GestureEvent) => {
              const currentX = event.fingerList[0]?.localX || 0
              const currentY = event.fingerList[0]?.localY || 0
              const deltaX = currentX - VideoOperateUtil.panStartX
              const deltaY = currentY - VideoOperateUtil.panStartY
              this.mpv.translateX += deltaX
              this.mpv.translateY += deltaY
              VideoOperateUtil.panStartX = currentX
              VideoOperateUtil.panStartY = currentY
            },
            onPanMoveEnd: () => {
              // 可选：添加边界检查或回弹效果
            }
          })
            .hitTestBehavior(HitTestMode.Transparent)

          AISubtitleComponent({
            isAIAsrShown: this.isAIAsrShown,
            showControl: this.showControl
          })
        }.onAreaChange(async (_oldValue: Area, newValue: Area) => {
          this.mpv.screenWidth = Math.floor(new Number(newValue.width).valueOf())
          this.mpv.screenHeight = Math.floor(new Number(newValue.height).valueOf())
          this.mpv.setRotation()
        })
        .height('100%')
        .width('100%')
        .backgroundColor($r('sys.color.black'))
      }
      .showControlButton(false)
      .onChange((value: boolean) => {
        this.sideBarStatus = value
      })
      .sideBarWidth(300)
      .showSideBar(this.sideBarStatus)
      .sideBarPosition(SideBarPosition.End)
      .divider({ strokeWidth: 0 })
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
      this.exitVideo(false)
      if (this.mpv.videoMetaDataList.length > 0 && this.mpv.playTime > 0) {
        VideoOperateUtil.saveVideoTime(this.mpv.playTime, this.mpv.nowPlaying!, this.mpv.videoMetaDataList,
          PathUtils.appContext!)
      }
      PermissionUtil.applyStopContinuousTask()
      WindowUtil.setKeepScreenStatus(PathUtils.appContext!, false)
      WindowUtil.setBarState(PathUtils.appContext!, true, true)
      PiPWindowUtil.destroyPipController()
      try {
        await (await this.mpv.windowClass)?.setPreferredOrientation(window.Orientation.AUTO_ROTATION_RESTRICTED)
        await this.mpv.avSession?.stopCasting()
      } catch (error) {
        ToolsUtil.addLogger(`onWillDisappear中发生错误：${error}`, true, this.pathStack)
      }
    })
    .onBackPressed(() => {
      if (this.sideBarStatus) {
        this.closeSideBar(true)
        return true
      }
      if (this.showControl && !Setting.allowPlayBackExist) {
        this.showControl = false
        this.mpv.lockVisibility = false
        return true
      } else {
        return false
      }
    })
    .hideTitleBar(true)
    .blur(Privacy.isPrivacyBackground ? PRIVACY_BACKGROUND_BLUR_AMOUNT : NO_BLUR_AMOUNT)
  }

  closeSideBar(isPlayAnimation: boolean) {
    this.sideBarStatusTmp = Visibility.Hidden
    isPlayAnimation ? setTimeout(() => {
      this.sideBarStatus = false
    }, 400) : this.sideBarStatus = false
  }

  setScreen() {
    WindowUtil.setBarState(PathUtils.appContext!, this.showControl, this.showControl)
  }

  @Builder
  VideoTop() {
    VideoTopComponent({
      subTitleVisibility: this.subtitleVisibility,
      audioTrackMenuBuilder: () => {
        this.AudioTrackMenuBuilder()
      },
      subtitlePanelComponent: () => {
        this.SubtitleMenuBuilder()
      },
      lockRotation: this.lockRotation,
      onExitVideoClick: () => {
        this.exitVideo(true)
        ToolsUtil.addLogger("点击退出视频按钮", false, this.pathStack)
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
        this.mpv.isZoomed = false
        this.mpv.translateX = 0
        this.mpv.translateY = 0
      },
      onOriginalRatio: () => {
        this.mpv.setKeepAspectStatus(true)
        this.mpv.playAreaHeight = VideoInfoUtil.playAreaHeight
        this.mpv.playAreaWidth = VideoInfoUtil.playAreaWidth
        this.mpv.isZoomed = false
        this.mpv.translateX = 0
        this.mpv.translateY = 0
      },
      onStretchedToFullScreen: () => {
        this.mpv.setKeepAspectStatus(false)
        this.mpv.playAreaHeight = this.mpv.screenHeight
        this.mpv.playAreaWidth = this.mpv.screenWidth
        this.mpv.isZoomed = false
        this.mpv.translateX = 0
        this.mpv.translateY = 0
      },
      onFullScreenByWidth: () => {
        this.mpv.playAreaWidth = this.mpv.screenWidth
        this.mpv.playAreaHeight = (VideoInfoUtil.playAreaHeight / VideoInfoUtil.playAreaWidth) * this.mpv.screenWidth
        this.mpv.isZoomed = false
        this.mpv.translateX = 0
        this.mpv.translateY = 0
      },
      onFullScreenByHeight: () => {
        this.mpv.playAreaHeight = this.mpv.screenHeight
        this.mpv.playAreaWidth = (VideoInfoUtil.playAreaWidth / VideoInfoUtil.playAreaHeight) * this.mpv.screenHeight
        this.mpv.isZoomed = false
        this.mpv.translateX = 0
        this.mpv.translateY = 0
      },
      onUniformScale: (scale: number) => {
        this.mpv.playAreaHeight = scale * VideoInfoUtil.playAreaHeight
        this.mpv.playAreaWidth = scale * VideoInfoUtil.playAreaWidth
        this.mpv.isZoomed = false
        this.mpv.translateX = 0
        this.mpv.translateY = 0
      },
      onSelectedTextChange: (text: string) => {
        this.mpv.selectedText = text
      },
      pipStateChange: () => {
        PiPWindowUtil.enableAutoStart()
        this.mpv.pipOpenState = true
      },
      onOpenPersonalScreenExtend: () => {
        this.personalScreenExtendDialog.open()
      }
    })
  }

  exitVideo(shouldPop: boolean = true) {
    this.mpv.release()
    if (shouldPop) {
      this.pathStack.pop()
    }
  }

  @Builder
  VideoButtons() {
    VideoButtonsComponent({
      AVCastPickerBuilderBridge: this.AVCastPickerBuilderBridge,
      videoSettingBuilder: () => {
        this.VideoSettingBuilder()
      },
      playbackSpeedMenu: () => {
        this.PlaybackSpeedMenuBuilder()
      },
      sideBarStatusTmp: this.sideBarStatusTmp,
      sideBarStatus: this.sideBarStatus,
      onScreenRotationOrFullScreenClick: async () => {
        VideoOperateUtil.fullScreenOrRotateScreen(this.mpv.screenWidth, this.mpv.screenHeight, this.mpv.windowClass)
      },
      onTogglePlaybackClick: () => {
        this.mpv.togglePlayback()
      },
      onPlayNextVideoClick: () => {
        this.mpv.playNextVideoProcess(this.pathStack)
        ToolsUtil.addLogger("播放下一个视频请求已发送", false, this.pathStack)
      },
      onSideBaClose: () => {
        this.closeSideBar(true)
      },
      onChangeRepeatMode: (repeatMode: RepeatMode) => {
        this.mpv.repeatMode = repeatMode
      }
    })
  }

  @Builder
  VideoSettingBuilder() {
    VideoSettingComponent({
      exitVideoTime: this.exitVideoTime,
      forward_80_s: (time: number) => {
        ToolsUtil.addLogger(`执行快进80秒操作，目标时间：${time}`, false, this.pathStack)
        this.mpv.seekTime(time)
      },
      closeAfter15min: (_time: number) => {
        ToolsUtil.showToast('功能暂不可用')

      },
      closeAfter30min: (_time: number) => {
        ToolsUtil.showToast('功能暂不可用')
      },
      closeAfter60min: (_time: number) => {
        ToolsUtil.showToast('功能暂不可用')
      },
      toggleListenVideo: () => {
        ToolsUtil.showToast('功能暂不可用')
      },
      captureScreen: () => {
        console.error('test' + this.mpv.surfaceId)
        if (this.mpv.surfaceId) {
          console.error('test')
          VideoOperateUtil.saveCaptureScreenToAlbum(this.mpv.surfaceId)
        }
      },
      updateStarTime: (time: number) => {
        this.mpv.nowPlaying!.start_time = time
      },
      updateEndTime: (time: number) => {
        this.mpv.nowPlaying!.end_time = time
      },
      updatePointATime: (time: number) => {
        this.mpv.nowPlaying!.pointA = time
      },
      updatePointBTime: (time: number) => {
        this.mpv.nowPlaying!.pointB = time
      },
      onScreenMirror: () => {
        this.mpv.angle === DEFAULT_ANGLE ? this.mpv.angle = MIRRORED_ANGLE : this.mpv.angle = DEFAULT_ANGLE
      },
      setRepeatModeToOnce: () => {
        this.mpv.repeatMode = RepeatMode.ONCE
      },
    })
  }

  @Builder
  VideoSlider() {
    VideoSliderComponent({
      onSliderChange: (value: number) => {
        this.mpv.onSwiping = true
        this.mpv.isSliderPlayTimeChange = true
        this.mpv.playTime = value
      },
      onSliderTouch: (event: TouchEvent) => {
        if (event.type == TouchType.Up) {
          this.mpv.seekTime(this.mpv.playTime)
          this.mpv.isSliderPlayTimeChange = false
          this.mpv.onSwiping = false
        }
      }
    })
  }

  @Builder
  AudioTrackMenuBuilder() {
    AudioTrackComponent({
      onSelect: (index: number) => {
        ToolsUtil.addLogger(`选择音频轨道，索引：${index}`, false, this.pathStack)
        this.mpv?.selectAudioTrack(this.mpv?.audioTrack[index]?.id)
        this.mpv.audioTrackSelected = index
      }
    })
  }

  @Builder
  SubtitleMenuBuilder() {
    SubtitlePanelComponent({
      subtitleVisibility: this.subtitleVisibility,
      isAIAsrShown: this.isAIAsrShown,
      subtitle3DMode: this.subtitle3DMode,
    })
  }

  @Builder
  AVCastPickerBuilderBridge() { // 桥接AVCastPickerBuilder避免crash
    AVCastPickerBuilder()
  }

  @Builder
  PlaybackSpeedMenuBuilder() {
    PlaybackSpeedMenuComponent({
      onSpeedChange: (speed: number) => {
        this.mpv.updatePlaybackSpeed(speed)
      }
    })
  }
}

