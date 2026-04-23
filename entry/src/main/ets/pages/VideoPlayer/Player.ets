import PermissionUtil from '../../utils/PermissionUtil'
import { window } from '@kit.ArkUI'
import ToolsUtil from '../../utils/ToolsUtil'
import VideoInfoUtil from '../../utils/VideoInfoUtil'
import VideoOperateUtil from '../../utils/VideoOperateUtil'
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import Preferences from '../../database/Preferences'
import { PathUtils } from '../../utils/PathUtils'
import SelectFileUtil from '../../utils/SelectFileUtil'
import { PlayerSideBarComponent } from '../../component/PlayerComponent/PlayerSideBarComponent'
import { AVCastPickerBuilder } from '../../component/PlayerComponent/AVCastPickerBuilder'
import { AudioTrackComponent } from '../../component/PlayerComponent/AudioTrackComponent'
import { PlaybackSpeedMenuComponent } from '../../component/PlayerComponent/PlaybackSpeedComponent'
import { LockVideoBarComponent } from '../../component/PlayerComponent/LockVideoBarComponent'
import { VideoSliderComponent } from '../../component/PlayerComponent/VideoSliderComponent'
import { GestureComponent } from '../../component/PlayerComponent/GestureComponent'
import { VideoTopComponent } from '../../component/PlayerComponent/VideoTopComponent'
import { VideoButtonsComponent } from '../../component/PlayerComponent/VideoButtonsComponent'
import { VideoSettingComponent } from '../../component/PlayerComponent/VideoSettingComponent'
import { SweetRepeatMode } from '../../common/enum/SweetRepeatMode'
import NavigationAddress, { PlayerParams } from '../../common/NavigationCommon'
import { WindowUtil } from '../../utils/WindowUtil'
import { KeyCode } from '@kit.InputKit'
import { XAnimation } from '../../utils/AnimationUtil'
import SubtitleUtil from '../../utils/SubtitleUtil'
import { Subtitle3DMode, SubtitleMode } from '../../common/enum/SubtitleMode'
import { AVPlayerController } from '../../controller/AVPlayerController'
import { BrightnessSwipingBuilder } from '../../component/PlayerComponent/BrightnessSwipingBuilder'
import { FastForwardPanelBuilder } from '../../component/PlayerComponent/FastForwardPanelBuilder'
import { VolumeSwipingPanelBuilder } from '../../component/PlayerComponent/VolumeSwipingPanelBuilder'
import { SwipingPlayTimePanelBuilder } from '../../component/PlayerComponent/SwipingPlayTimePanelBuilder'
import { SubtitlePanelComponent } from '../../component/PlayerComponent/SubtitlePanelComponent'
import { SubtitleDisplayBuilder } from '../../component/PlayerComponent/SubtitleDisplayBuilder'
import { Privacy, Setting } from '../../utils/ObservedUtil'
import { PlayerControllerFactory } from '../../controller/PlayerControllerFactory'
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
import PiPWindowUtil from '../../utils/PiPWindowUtil'
import { DefaultDialogShadow } from '../../common/AttributeModifierConfig'
import { NumberInputDialog } from '../../component/Dialog/NumberInputDialog'
import { SubtitleOffsetDialog } from '../../component/Dialog/SubtitleOffsetDialog'

@ComponentV2
export struct Player { // 播放页
  @Provider('player') player: AVPlayerController = PlayerControllerFactory.createAVPlayerController()
  personalScreenExtendDialog: CustomDialogController = new CustomDialogController({
    builder: NumberInputDialog({
      title: '自定义屏幕拓展比例',
      placeholderColor: '输入范围：50-150',
      confirm: (input: number) => {
        if (input && input <= 150 && input >= 50) {
          this.player.playAreaHeight = input / 100 * VideoInfoUtil.playAreaHeight
          this.player.playAreaWidth = input / 100 * VideoInfoUtil.playAreaWidth
        } else {
          ToolsUtil.showToast('输入错误，输入范围在50-150之间')
        }
      },
    }), cornerRadius: 20, shadow: DefaultDialogShadow
  })
  @Local lockRotation: boolean = false
  xComponentController: XComponentController = new XComponentController()
  windowClass = WindowUtil.getWindow()
  @Local sideBarStatusTmp: Visibility = Visibility.Hidden
  @Local sideBarStatus: boolean = false
  @Local isAIAsrShown: boolean = false
  @Local currentSpeedIndex: number = 0
  @Local subtitleVisibility: Visibility = Visibility.Visible
  @Local subtitle3DMode: Subtitle3DMode = Subtitle3DMode.DISABLED
  @Consumer('pathStack') pathStack: NavPathStack = new NavPathStack()
  @Local exitVideoTime: number = 0
  @Local isAdjustingSubtitleOffset: boolean = false
  subtitleTimestampInputDialog: CustomDialogController = new CustomDialogController({
    builder: SubtitleOffsetDialog({
      getCurrentValue: () => SubtitleUtil.offsetMillis,
      onOffsetPreview: (offset: number) => {
        this.refreshExternalSubtitlePreview(offset)
      },
      onCloseButton: () => {
        this.cancelSubtitleOffsetSession()
        this.subtitleTimestampInputDialog.close()
      },
      onPrevSubtitle: (currentOffset: number) => {
        return this.getAdjacentSubtitleOffset('prev', currentOffset)
      },
      onNextSubtitle: (currentOffset: number) => {
        return this.getAdjacentSubtitleOffset('next', currentOffset)
      },
      confirm: (input: number) => {
        if (Number.isNaN(input)) {
          ToolsUtil.showToast('未输入偏移')
          this.cancelSubtitleOffsetSession()
          this.subtitleTimestampInputDialog.close()
        } else if (Math.abs(input) <= 50000) {
          SubtitleUtil.offsetMillis = input
          this.refreshExternalSubtitlePreview(input)
          this.finishSubtitleOffsetSession()
          this.saveSubtitlePreferenceForCurrentVideo()
          this.subtitleTimestampInputDialog.close()
        } else {
          ToolsUtil.showToast('输入错误：请输入 -50000 到 50000 的整数')
        }
      },
    }),
    cornerRadius: 20,
    shadow: DefaultDialogShadow,
    maskColor: '#00000000',
    cancel: () => {
      this.cancelSubtitleOffsetSession()
    }
  })
  private subtitleOffsetPreviewBase: number = 0
  private subtitleOffsetShouldResumePlayback: boolean = false
  private isApplyingSubtitleMetadata: boolean = false

  async aboutToAppear(): Promise<void> {
    ToolsUtil.addLogger("开始执行aboutToAppear方法", false, this.pathStack)
    PermissionUtil.applyContinuousTask()
    try {
      await (await this.windowClass)?.setPreferredOrientation(window.Orientation.AUTO_ROTATION_RESTRICTED)
      WindowUtil.setKeepScreenStatus(PathUtils.appContext!, true)
      this.player.repeatMode = Preferences.getRepeatModeState(PathUtils.appContext!)
      const videoSpeed = Preferences.getVideoSpeed(PathUtils.appContext!)
      this.player.speed = parseFloat(videoSpeed?.replace('x', '') || '1')
      WindowUtil.setBarState(PathUtils.appContext!, false, false)
    } catch (error) {
      ToolsUtil.addLogger(`播放错误 ${error}`, true, this.pathStack)
    }
    ToolsUtil.addLogger("aboutToAppear方法执行完成", false, this.pathStack)
  }

  async aboutToDisappear(): Promise<void> {
    ToolsUtil.addLogger("开始执行aboutToDisappear方法", false, this.pathStack)
    VideoOperateUtil.setBrightness(-1)
    WindowUtil.recoveryBarColor()
    Preferences.saveVideoSpeed(PathUtils.appContext!,
      (VideoInfoUtil.videoSpeedListAll.includes(this.player.speed) ? this.player.speed : 1) + 'x')
    Preferences.saveRepeatModeState(PathUtils.appContext!, this.player.repeatMode)
    this.saveSubtitlePreferenceForCurrentVideo()
    WindowUtil.setBarState(PathUtils.appContext!, true, true)
    clearTimeout(this.exitVideoTime)
    this.player.cancelSubscribe()
    AppStorage.delete('nowPlayingData')
    try {
      this.player.audioVolumeManager?.off('streamVolumeChange')
      this.player.audioVolumeManager = null
      ToolsUtil.addLogger("取消音量变化监听完成", false, this.pathStack)
    } catch (error) {
      ToolsUtil.addLogger(`音量监听取消错误 ${error}`, true, this.pathStack)
    }
    this.player.release()
    ToolsUtil.addLogger("释放播放器资源完成", false, this.pathStack)
    ToolsUtil.addLogger("aboutToDisappear方法执行完成", false, this.pathStack)
  }

  closeSideBar(isPlayAnimation: boolean) {
    this.sideBarStatusTmp = Visibility.Hidden
    isPlayAnimation ? setTimeout(() => {
      this.sideBarStatus = false
    }, 400) : this.sideBarStatus = false
  }

  build() {
    NavDestination() {
      SideBarContainer(SideBarContainerType.Overlay) {
        PlayerSideBarComponent({
          sideBarStatusTmp: this.sideBarStatusTmp,
          onSideBarStatusTmpChange: (v: Visibility) => {
            this.sideBarStatusTmp = v
          },
          sideBarStatus: this.sideBarStatus,
          onSideBarStatusChange: (v: boolean) => {
            this.sideBarStatus = v
          },
          onItemClick: (item: VideoMetadata) => {
            this.player.playChooseVideo(item, this.pathStack, this.windowClass)
            this.player.setPlayerCallback(this.pathStack, this.xComponentController, this.windowClass)
            this.closeSideBar(true)
          }
        })

        Stack() {
          XComponents({
            xComponentController: this.xComponentController,
            subtitle: this.player.subtitle,
            choosePlayer: NavigationAddress.AV_PLAYER,
            hideSubtitle: this.isOffsetSubtitleOverlayActive(),
            subtitleVisibility: this.subtitleVisibility,
            subtitle3DMode: this.subtitle3DMode,
            barState: this.player.showControl,
            onXComponentLoad: async () => {
              this.player.surfaceID = this.xComponentController.getXComponentSurfaceId()
              await this.player.init()
              this.player.setPlayerCallback(this.pathStack, this.xComponentController, this.windowClass)
              await this.player.getData(this.pathStack, this.windowClass)
              PiPWindowUtil.createPipController(this.xComponentController, this.player)
            },
            onKeyCodeSpace: () => {
              this.player.togglePlayback()
            },
            onKeyCodeEscape: () => {
              VideoOperateUtil.fullScreenOrRotateScreen(this.player.screenWidth, this.player.screenHeight,
                this.windowClass)
            },
            onKeyCodeLeft: () => {
              this.player.backForward()
            },
            onKeyCodeRight: () => {
              this.player.fastForward()
            },
            onKeyCodeUpAndDown: (event: KeyEvent) => {
              this.player.volume = this.player.volumeActually
              const newVolume = VideoOperateUtil.changeVolume(this.player.volume,
                event.keyCode === KeyCode.KEYCODE_DPAD_UP ? VOLUME_STEP : -VOLUME_STEP)
              this.player.volume = newVolume
              this.player.volumeActually = newVolume
              VideoOperateUtil.lastVolume = newVolume
            },
          })

          if (this.player.showControl && !this.player.isLock) {
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

          if (this.player.longPress) {
            FastForwardPanelBuilder({
              speed: this.player.speed,
              location: VideoInfoUtil.playAreaHeight,
            })
          }
          if (this.player.onSwiping) {
            SwipingPlayTimePanelBuilder({
              isSliderPlayTimeChange: this.player.isSliderPlayTimeChange,
              playTime: this.player.playTime,
              totalTime: this.player.nowPlaying!.time,
              pixelMap: this.player.pixelMap,
              player: NavigationAddress.AV_PLAYER
            })
          }

          VolumeSwipingPanelBuilder({
            videoVolume: this.player.volume,
            videoVolumeShow: this.player.volumeActually,
            onSwipingVoice: this.player.onSwipingVoice,
            playAreaHeight: VideoInfoUtil.playAreaHeight
          })

          if (this.player.onSwipingBrightness) {
            BrightnessSwipingBuilder({
              screenBrightness: this.player.screenBrightness,
              playAreaHeight: VideoInfoUtil.playAreaHeight
            })
          }
          if (this.player.lockVisibility) {
            LockVideoBarComponent({
              onLockClick: () => {
                this.player.isLock = !this.player.isLock
                this.player.showControl = true
              }
            })
          }
          GestureComponent({
            onDoubleClickAction: (tapX: number) => {
              this.player.onScreenDoubleClick(tapX)
            },
            onSingleClickAction: () => {
              if (this.sideBarStatus) {
                this.closeSideBar(true)
              } else {
                this.player.lockVisibility = !this.player.lockVisibility
                XAnimation.runWithAnimation(() => {
                  if (this.player.isLock) {
                    this.player.showControl = false
                  } else {
                    this.player.showControl = !this.player.showControl
                  }
                })
              }
            },
            onVerticalPanStart: (tapX: number) => {
              VideoOperateUtil.leftSideSwipe = tapX < this.player.screenWidth / SCREEN_HALF_DIVIDER
              VideoOperateUtil.screenBrightnessTmp = this.player.screenBrightness
              this.player.volume = this.player.volumeActually
              VideoOperateUtil.lastVolume = this.player.volume // 记录起始音量
            },
            onVerticalPanUpdate: (offsetY: number) => {
              const deltaYScale = offsetY / this.player.screenHeight * VERTICAL_PAN_SENSITIVITY
              if (VideoOperateUtil.leftSideSwipe) {
                this.player.onSwipingBrightness = true
                this.player.screenBrightness = VideoOperateUtil.calNewBrightness(deltaYScale)
                VideoOperateUtil.setBrightness(this.player.screenBrightness)
              } else {
                this.player.onSwipingVoice = true
                const newVolume = VideoOperateUtil.lastVolume - deltaYScale * VOLUME_PAN_MULTIPLIER
                this.player.volume =
                  Math.min(Math.max(newVolume, VideoOperateUtil.minVolume), VideoOperateUtil.maxVolume)
              }
            },
            onVerticalPanEnd: () => {
              this.player.onSwiping = false
              this.player.onSwipingVoice = false
              this.player.onSwipingBrightness = false
            },
            onHorizonPanStart: () => {
              VideoOperateUtil.lastPlayTime = this.player.playTime
              this.player.onSwiping = true
              this.player.pixelMap = null
              this.player.getFrameByTime(this.player.playTime, true)
            },
            onHorizonPanUpdate: (offsetX: number) => {
              const timePerPixel = VideoOperateUtil.getTimePixel(this.player.screenWidth, this.player.nowPlaying?.time!)
              this.player.playTime = Math.max(0,
                Math.min(VideoOperateUtil.lastPlayTime + (offsetX * timePerPixel), this.player.nowPlaying?.time!))
              this.player.getFrameByTime(this.player.playTime, false)
            },
            onHorizonPanEnd: () => {
              this.player.seekTime(this.player.playTime)
              this.player.onSwiping = false
            },
            onPinchStart: (fingerDistance: number) => {
              VideoOperateUtil.initPinchDistance = fingerDistance
              this.player.translateX = 0
              this.player.translateY = 0
            },
            onPinchUpdate: (fingerDistance: number) => {
              const rawScale = fingerDistance / VideoOperateUtil.initPinchDistance
              const adjustedScale = 1 + (rawScale - 1) * PINCH_SCALE_SENSITIVITY // 计算调整后的缩放比例
              const clampedScale = Math.min(Math.max(adjustedScale, MIN_SCALE_FACTOR), MAX_SCALE_FACTOR)
              const scaledWidth = this.player.playAreaWidth * clampedScale // 计算缩放后的播放区域宽度
              const maxAllowed = VideoInfoUtil.playAreaWidth * MAX_WIDTH_MULTIPLIER
              const minAllowed = VideoInfoUtil.playAreaWidth * MIN_WIDTH_MULTIPLIER
              if (scaledWidth > maxAllowed || scaledWidth < minAllowed) { // 检查缩放是否超出允许范围
                return
              }
              this.player.playAreaWidth = scaledWidth
              this.player.playAreaHeight = this.player.playAreaHeight * clampedScale
              this.player.isZoomed = clampedScale !== 1
              XAnimation.runWithAnimation(() => {
                this.player.playAreaWidth = this.player.playAreaWidth
                this.player.playAreaHeight = this.player.playAreaHeight
              })
            },
            onPinchEnd: () => {
              this.player.isZoomed = this.player.playAreaWidth !== VideoInfoUtil.playAreaWidth
            },
            onLongPressAction: () => {
              if (this.player.playing) {
                VideoOperateUtil.lastSpeed = this.player.speed
                this.player.updatePlaybackSpeed(Setting.longPressSpeed)
                this.player.longPress = true
                this.currentSpeedIndex = VideoInfoUtil.videoSpeedListAll.indexOf(Setting.longPressSpeed)
              }
            },
            onLongPressEnd: () => {
              this.player.longPress = false
              this.player.updatePlaybackSpeed(VideoOperateUtil.lastSpeed)
            },
            onLongPressPanStart: (tapX: number) => {
              VideoOperateUtil.longPressStartX = tapX
            },
            onLongPressPanUpdate: (tapX: number) => {
              if (this.player.longPress) { // 长按状态下的滑动处理
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
                this.player.updatePlaybackSpeed(VideoInfoUtil.videoSpeedListAll[this.currentSpeedIndex])
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
              this.player.translateX += deltaX
              this.player.translateY += deltaY
              VideoOperateUtil.panStartX = currentX
              VideoOperateUtil.panStartY = currentY
            }
          })
            .hitTestBehavior(HitTestMode.Transparent)

          if (this.isOffsetSubtitleOverlayActive()) {
            Stack() {
              SubtitleDisplayBuilder({
                subtitle: this.player.subtitle,
                screenWidth: this.player.screenWidth,
                screenHeight: this.player.screenHeight,
                showControl: this.player.showControl,
                subTitleVisibility: this.subtitleVisibility,
                subtitle3DMode: this.subtitle3DMode
              })
            }
            .width(this.player.playAreaWidth)
            .height(this.player.playAreaHeight)
            .animation({ duration: this.player.playTime > 300 ? 300 : 0, curve: Curve.Ease })
            .rotate({ y: 2, angle: this.player.angle, perspective: 200 })
            .translate({ x: this.player.translateX, y: this.player.translateY })
            .hitTestBehavior(HitTestMode.Transparent)
            .zIndex(1000)
          }

          AISubtitleComponent({
            isAIAsrShown: this.isAIAsrShown,
            player: this.player,
          })
        }.onAreaChange((_oldValue: Area, newValue: Area) => {
          this.player.screenWidth = Math.floor(new Number(newValue.width).valueOf())
          this.player.screenHeight = Math.floor(new Number(newValue.height).valueOf())
          this.player.setRotation()
        }).backgroundColor($r('sys.color.black'))
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
      const playerParams: PlayerParams = this.pathStack.getParamByName(NavigationAddress.AV_PLAYER)[0] as PlayerParams
      try {
        this.player.nowPlaying = playerParams.metadata as VideoMetadata
        this.player.videoMetaDataList = playerParams.metadata_list as VideoMetadata[]
      } catch (e) {
        ToolsUtil.addLogger(e, true, this.pathStack)
      }
    })
    .onBackPressed(() => {
      if (this.sideBarStatus) {
        this.closeSideBar(true)
        return true
      }
      if (this.player.showControl && !Setting.allowPlayBackExist) {
        this.player.showControl = false
        this.player.lockVisibility = false
        return true
      } else {
        return false
      }
    })
    .onShown(() => {
      if (PiPWindowUtil.pipOpenState) {
        PiPWindowUtil.stopPip()
      }
    })
    .onWillDisappear(async () => {
      ToolsUtil.addLogger("开始执行onWillDisappear生命周期", false, this.pathStack)
      this.saveSubtitlePreferenceForCurrentVideo()
      VideoOperateUtil.saveLastPlayVideoIndex(this.player.videoMetaDataList, this.player.nowPlaying?.date)
      if (this.player.videoMetaDataList.length > 0 && this.player.playTime > 0) {
        VideoOperateUtil.saveVideoTime(this.player.playTime, this.player.nowPlaying!, this.player.videoMetaDataList,
          PathUtils.appContext!)
        ToolsUtil.addLogger("保存视频播放时间完成", false, this.pathStack)
      }
      PermissionUtil.applyStopContinuousTask()
      PiPWindowUtil.destroyPipController()
      try {
        WindowUtil.setKeepScreenStatus(PathUtils.appContext!, false)
        if (canIUse('SystemCapability.Window.SessionManager')) {
          await (await this.windowClass)?.setSpecificSystemBarEnabled('status', true)
          await (await this.windowClass)?.setSpecificSystemBarEnabled('navigationIndicator', true)
          ToolsUtil.addLogger("恢复系统栏显示完成", false, this.pathStack)
        }
        await (await this.windowClass)?.setPreferredOrientation(window.Orientation.AUTO_ROTATION_RESTRICTED)
        await this.player?.avSession?.stopCasting()
        await VideoOperateUtil.releaseAVImageGenerator()
        this.player.release()
      } catch (error) {
        ToolsUtil.addLogger(`onWillDisappear中发生错误：${error}`, true, this.pathStack)
      }
      ToolsUtil.addLogger("onWillDisappear生命周期执行完成", false, this.pathStack)
    })
    .hideTitleBar(true)
    .blur(Privacy.isPrivacyBackground ? PRIVACY_BACKGROUND_BLUR_AMOUNT : NO_BLUR_AMOUNT)
  }

  exitVideo(timeOut: number) {
    ToolsUtil.addLogger("开始设置退出视频定时器", false, this.pathStack)
    this.exitVideoTime = setTimeout(() => {
      ToolsUtil.addLogger("退出视频定时器触发" + timeOut, false, this.pathStack)
      ToolsUtil.showToast(timeOut > 0 ? '到设定的时间了，已自动退出' : '已退出')
      this.player.reset()
      ToolsUtil.addLogger("重置播放器完成", false, this.pathStack)
      this.pathStack.pop()
    }, timeOut)
    ToolsUtil.addLogger(`退出视频定时器设置完成，超时时间：${timeOut}`, false, this.pathStack)
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
        ToolsUtil.addLogger("点击退出视频按钮", false, this.pathStack)
        this.exitVideo(0)
      },
      onLockRotationClick: async () => {
        this.lockRotation = !this.lockRotation
        ToolsUtil.addLogger(`锁定旋转状态切换为：${this.lockRotation}`, false, this.pathStack)
        const orientation = this.lockRotation ?
          (this.player.screenWidth > this.player.screenHeight ? window.Orientation.AUTO_ROTATION_LANDSCAPE_RESTRICTED
            : window.Orientation.AUTO_ROTATION_PORTRAIT_RESTRICTED)
          : window.Orientation.AUTO_ROTATION_RESTRICTED
        try {
          XAnimation.runWithAnimation(async () => {
            await (await this.windowClass)?.setPreferredOrientation(orientation)
            ToolsUtil.addLogger("窗口方向设置成功", false, this.pathStack)
          })
        } catch (error) {
          ToolsUtil.addLogger(`屏幕旋转异常: ${error.code}:${error.message}`, true, this.pathStack)
        }
        const toastMessage = this.lockRotation
          ? ToolsUtil.getStringResource($r('app.string.open_rotation_lock').id)
          : ToolsUtil.getStringResource($r('app.string.close_rotation_lock').id)
        ToolsUtil.showToast(toastMessage)
      },
      onSpecificVideoProportions: (playAreaSize: number[]) => {
        this.player.playAreaWidth = playAreaSize[0]
        this.player.playAreaHeight = playAreaSize[1]
        this.player.isZoomed = false
        this.player.translateX = 0
        this.player.translateY = 0
      },
      onOriginalRatio: () => {
        this.player.playAreaHeight = VideoInfoUtil.playAreaHeight
        this.player.playAreaWidth = VideoInfoUtil.playAreaWidth
        this.player.isZoomed = false
        this.player.translateX = 0
        this.player.translateY = 0
      },
      onStretchedToFullScreen: () => {
        this.player.playAreaHeight = this.player.screenHeight
        this.player.playAreaWidth = this.player.screenWidth
        this.player.isZoomed = false
        this.player.translateX = 0
        this.player.translateY = 0
      },
      onFullScreenByWidth: () => {
        this.player.playAreaWidth = this.player.screenWidth
        this.player.playAreaHeight =
          (VideoInfoUtil.playAreaHeight / VideoInfoUtil.playAreaWidth) * this.player.screenWidth
        this.player.isZoomed = false
        this.player.translateX = 0
        this.player.translateY = 0
      },
      onFullScreenByHeight: () => {
        this.player.playAreaHeight = this.player.screenHeight
        this.player.playAreaWidth =
          (VideoInfoUtil.playAreaWidth / VideoInfoUtil.playAreaHeight) * this.player.screenHeight
        this.player.isZoomed = false
        this.player.translateX = 0
        this.player.translateY = 0
      },
      onUniformScale: (scale: number) => {
        this.player.playAreaHeight = scale * VideoInfoUtil.playAreaHeight
        this.player.playAreaWidth = scale * VideoInfoUtil.playAreaWidth
        this.player.isZoomed = false
        this.player.translateX = 0
        this.player.translateY = 0
      },
      onSelectedTextChange: (text: string) => {
        this.player.selectedText = text
      },
      pipStateChange: () => {
        PiPWindowUtil.startPip()
        WindowUtil.minimizeClick(PathUtils.appContext!)
      },
      onOpenPersonalScreenExtend: () => {
        this.personalScreenExtendDialog.open()
      }
    })
  }

  @Builder
  VideoSlider() {
    VideoSliderComponent({
      onSliderChange: (value: number) => {
        this.player.onSwiping = true
        this.player.isSliderPlayTimeChange = true
        this.player.playTime = value
      },
      onSliderTouch: (event: TouchEvent) => {
        if (event.type == TouchType.Up) {
          this.player.seekTime(this.player.playTime)
          this.player.isSliderPlayTimeChange = false
          this.player.onSwiping = false
        }
      }
    })
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
      onSideBarStatusTmpChange: (v: Visibility) => {
        this.sideBarStatusTmp = v
      },
      sideBarStatus: this.sideBarStatus,
      onSideBarStatusChange: (v: boolean) => {
        this.sideBarStatus = v
      },
      onScreenRotationOrFullScreenClick: async () => {
        VideoOperateUtil.fullScreenOrRotateScreen(this.player.screenWidth, this.player.screenHeight, this.windowClass)
      },
      onTogglePlaybackClick: () => {
        this.player.togglePlayback()
      },
      onPlayNextVideoClick: () => {
        this.player.playNextVideoProcess(this.pathStack, this.windowClass)
        this.player.setPlayerCallback(this.pathStack, this.xComponentController, this.windowClass)
        ToolsUtil.addLogger("播放下一个视频请求已发送", false, this.pathStack)
      },
      onSideBaClose: () => {
        this.closeSideBar(true)
      },
      onChangeRepeatMode: (repeatMode: SweetRepeatMode) => {
        this.player.repeatMode = repeatMode
      }
    })
  }

  @Builder
  AudioTrackMenuBuilder() {
    AudioTrackComponent({
      onSelect: (index: number) => {
        this.player?.selectAudioTrack(this.player?.audioTrack[index]?.index)
        this.player.audioTrackSelected = index
      }
    })
  }

  @Builder
  VideoSettingBuilder() {
    VideoSettingComponent({
      exitVideoTime: this.exitVideoTime,
      forward_80_s: (time: number) => {
        ToolsUtil.addLogger(`执行快进80秒操作，目标时间：${time}`, false, this.pathStack)
        this.player.seekTime(time)
      },
      closeAfter15min: (time: number) => {
        ToolsUtil.addLogger("设置15分钟后关闭播放器", false, this.pathStack)
        this.exitVideo(time)
      },
      closeAfter30min: (time: number) => {
        ToolsUtil.addLogger("设置30分钟后关闭播放器", false, this.pathStack)
        this.exitVideo(time)
      },
      closeAfter60min: (time: number) => {
        ToolsUtil.addLogger("设置60分钟后关闭播放器", false, this.pathStack)
        this.exitVideo(time)
      },
      toggleListenVideo: () => {
        ToolsUtil.addLogger("切换只听视频模式", false, this.pathStack)
        this.player.isListenVideo = !this.player.isListenVideo
        this.player.isListenVideo ? ToolsUtil.showToast('只听视频模式已开启') :
          ToolsUtil.showToast('只听视频模式已关闭')
        this.player.setListenVideoStatus()
      },
      captureScreen: () => {
        VideoOperateUtil.saveCaptureScreenToAlbum(this.player.surfaceID)
      },
      updateStarTime: (time: number) => {
        this.player.nowPlaying!.start_time = time
      },
      updateEndTime: (time: number) => {
        this.player.nowPlaying!.end_time = time
      },
      updatePointATime: (time: number) => {
        this.player.nowPlaying!.pointA = time
      },
      updatePointBTime: (time: number) => {
        this.player.nowPlaying!.pointB = time
      },
      onScreenMirror: () => {
        this.player.angle === DEFAULT_ANGLE ? this.player.angle = MIRRORED_ANGLE : this.player.angle = DEFAULT_ANGLE
      },
      setRepeatModeToOnce: () => {
        this.player.repeatMode = SweetRepeatMode.ONCE
      },
      onABCircleStatusClick: () => {
        this.player.abCircleStatus = !this.player.abCircleStatus
      },
    })
  }

  @Builder
  PlaybackSpeedMenuBuilder() {
    PlaybackSpeedMenuComponent({
      onSpeedChange: (speed: number) => {
        this.player.updatePlaybackSpeed(speed)
      }
    })
  }

  @Builder
  SubtitleMenuBuilder() {
    SubtitlePanelComponent({
      subtitleVisibility: this.subtitleVisibility,
      isAIAsrShown: this.isAIAsrShown,
      subtitle3DMode: this.subtitle3DMode,
      onSubtitle3DModeChange: (v: Subtitle3DMode) => {
        this.subtitle3DMode = v
      },
      onSubtitleOffClick: () => {
        this.turnOffSubtitleDisplay()
      },
      onSubtitleOffsetTime: () => {
        this.activateExternalSubtitle()
        this.subtitleOffsetShouldResumePlayback = this.player.playing
        if (this.subtitleOffsetShouldResumePlayback) {
          this.player.pause()
        }
        this.subtitleOffsetPreviewBase = SubtitleUtil.offsetMillis
        this.isAdjustingSubtitleOffset = true
        this.refreshExternalSubtitlePreview(this.subtitleOffsetPreviewBase)
        this.subtitleTimestampInputDialog.open()
      },
      onInnerSubtitleClick: () => {
        this.subtitleVisibility = Visibility.Visible
        this.isAIAsrShown = false
        this.player.subtitleSelected = SubtitleMode.INNER_SUBTITLE
        this.saveSubtitlePreferenceForCurrentVideo()
      },
      onExternalSubtitleClick: () => {
        this.activateExternalSubtitle()
      },
      onAIAsrClick: () => {
        this.isAIAsrShown = !this.isAIAsrShown
        this.subtitleVisibility = Visibility.None
        this.player.subtitleSelected = SubtitleMode.AI_SUBTITLE
        this.saveSubtitlePreferenceForCurrentVideo()
      },
    })
  }

  @Builder
  AVCastPickerBuilderBridge() { // 桥接AVCastPickerBuilder避免crash
    AVCastPickerBuilder()
  }

  private isOffsetSubtitleOverlayActive(): boolean {
    return this.isAdjustingSubtitleOffset && this.player.subtitleSelected === SubtitleMode.EXTERNAL_SUBTITLE
  }

  private refreshExternalSubtitlePreview(offset: number): void {
    if (this.player.subtitleSelected !== SubtitleMode.EXTERNAL_SUBTITLE) {
      return
    }
    this.player.subtitle = SubtitleUtil.getSubtitlesAtTime(this.player.playTime, offset)
  }

  private refreshExternalSubtitleByPlaybackTime(): void {
    if (this.isAdjustingSubtitleOffset) {
      return
    }
    if (this.player.subtitleSelected !== SubtitleMode.EXTERNAL_SUBTITLE) {
      return
    }
    if (this.subtitleVisibility !== Visibility.Visible) {
      return
    }
    this.player.subtitle = SubtitleUtil.getSubtitlesAtTime(this.player.playTime)
  }

  private resumePlaybackAfterSubtitleOffsetIfNeeded(): void {
    if (!this.subtitleOffsetShouldResumePlayback) {
      return
    }
    this.subtitleOffsetShouldResumePlayback = false
    if (!this.player.playing) {
      this.player.play()
    }
  }

  private finishSubtitleOffsetSession(): void {
    this.isAdjustingSubtitleOffset = false
    this.resumePlaybackAfterSubtitleOffsetIfNeeded()
  }

  private cancelSubtitleOffsetSession(): void {
    if (!this.isAdjustingSubtitleOffset) {
      return
    }
    this.refreshExternalSubtitlePreview(this.subtitleOffsetPreviewBase)
    this.finishSubtitleOffsetSession()
  }

  private getAdjacentSubtitleOffset(direction: 'prev' | 'next', currentOffset: number): number | undefined {
    const targetOffset = SubtitleUtil.getAdjacentSubtitleOffset(this.player.playTime, currentOffset, direction)
    if (targetOffset === undefined) {
      ToolsUtil.showToast(direction === 'prev' ? '没有上一条字幕' : '没有下一条字幕')
      return undefined
    }
    if (Math.abs(targetOffset) > 50000) {
      ToolsUtil.showToast('目标字幕超出偏移范围：-50000 到 50000')
      return undefined
    }
    return Math.round(targetOffset)
  }

  private activateExternalSubtitle(): void {
    this.isAIAsrShown = false
    this.subtitleVisibility = Visibility.Visible
    this.player.subtitleSelected = SubtitleMode.EXTERNAL_SUBTITLE
    this.refreshExternalSubtitleByPlaybackTime()
    this.saveSubtitlePreferenceForCurrentVideo()
  }

  private turnOffSubtitleDisplay(): void {
    this.isAIAsrShown = false
    this.subtitleVisibility = Visibility.None
    this.saveSubtitlePreferenceForCurrentVideo()
  }

  @Monitor('subtitle3DMode')
  private onSubtitle3DModeChanged(): void {
    if (this.isApplyingSubtitleMetadata) {
      return
    }
    this.saveSubtitlePreferenceForCurrentVideo()
  }

  private normalizeSubtitleMode(subtitleMode?: number): SubtitleMode {
    if (subtitleMode === SubtitleMode.EXTERNAL_SUBTITLE || subtitleMode === SubtitleMode.AI_SUBTITLE) {
      return subtitleMode
    }
    return SubtitleMode.INNER_SUBTITLE
  }

  private normalizeSubtitle3DMode(subtitle3DMode?: number): Subtitle3DMode {
    if (subtitle3DMode === Subtitle3DMode.SIDE_BY_SIDE || subtitle3DMode === Subtitle3DMode.TOP_AND_BOTTOM) {
      return subtitle3DMode
    }
    return Subtitle3DMode.DISABLED
  }

  private hasSubtitlePreferenceMetadata(nowPlaying: VideoMetadata): boolean {
    return nowPlaying.subtitle_mode !== undefined ||
      nowPlaying.subtitle_visible !== undefined ||
      nowPlaying.subtitle_ai_asr_shown !== undefined ||
      nowPlaying.subtitle_3d_mode !== undefined ||
      nowPlaying.subtitle_offset_millis !== undefined ||
      nowPlaying.subtitle_track_id !== undefined
  }

  private hasInnerSubtitleTrack(): boolean {
    return this.player.subtitleTrack.length > 0
  }

  private hasExternalSubtitle(): boolean {
    return (this.player.nowPlaying?.external_subtitle_format?.length ?? 0) > 0
  }

  private applySubtitlePreferenceFromMetadata(): void {
    const nowPlaying = this.player.nowPlaying
    if (!nowPlaying) {
      return
    }
    this.isApplyingSubtitleMetadata = true

    if (!this.hasSubtitlePreferenceMetadata(nowPlaying)) {
      this.isAIAsrShown = false
      this.subtitle3DMode = Subtitle3DMode.DISABLED
      SubtitleUtil.offsetMillis = 0

      if (this.hasInnerSubtitleTrack()) {
        this.subtitleVisibility = Visibility.Visible
        this.player.subtitleSelected = SubtitleMode.INNER_SUBTITLE
      } else if (this.hasExternalSubtitle()) {
        this.subtitleVisibility = Visibility.Visible
        this.player.subtitleSelected = SubtitleMode.EXTERNAL_SUBTITLE
        this.refreshExternalSubtitleByPlaybackTime()
      } else {
        this.subtitleVisibility = Visibility.None
        this.player.subtitleSelected = SubtitleMode.INNER_SUBTITLE
      }
      this.isApplyingSubtitleMetadata = false
      this.saveSubtitlePreferenceForCurrentVideo()
      return
    }

    const subtitleMode = this.normalizeSubtitleMode(nowPlaying.subtitle_mode)
    const subtitleVisible = nowPlaying.subtitle_visible ?? true
    const subtitleAIAsrShown = nowPlaying.subtitle_ai_asr_shown ?? false
    const subtitle3DMode = this.normalizeSubtitle3DMode(nowPlaying.subtitle_3d_mode)
    const subtitleTrackId = nowPlaying.subtitle_track_id ?? -1
    let subtitleOffsetMillis = nowPlaying.subtitle_offset_millis ?? 0
    subtitleOffsetMillis = Math.max(-50000, Math.min(50000, Math.round(subtitleOffsetMillis)))

    this.subtitle3DMode = subtitle3DMode
    SubtitleUtil.offsetMillis = subtitleOffsetMillis

    if (subtitleAIAsrShown && canIUse('SystemCapability.AI.AICaption')) {
      this.isAIAsrShown = true
      this.subtitleVisibility = Visibility.None
      this.player.subtitleSelected = SubtitleMode.AI_SUBTITLE
      this.isApplyingSubtitleMetadata = false
      this.saveSubtitlePreferenceForCurrentVideo()
      return
    }

    this.isAIAsrShown = false
    this.subtitleVisibility = subtitleVisible ? Visibility.Visible : Visibility.None
    if (subtitleMode === SubtitleMode.EXTERNAL_SUBTITLE && this.hasExternalSubtitle()) {
      this.player.subtitleSelected = SubtitleMode.EXTERNAL_SUBTITLE
      this.refreshExternalSubtitleByPlaybackTime()
    } else {
      this.player.subtitleSelected = SubtitleMode.INNER_SUBTITLE
      if (subtitleTrackId >= 0) {
        const selectedTrack = this.player.subtitleTrack.find((track) => track.id === subtitleTrackId)
        if (selectedTrack) {
          this.player.selectSubtitleTrack(selectedTrack.id)
        }
      }
    }
    this.isApplyingSubtitleMetadata = false
    this.saveSubtitlePreferenceForCurrentVideo()
  }

  private saveSubtitlePreferenceForCurrentVideo(): void {
    const nowPlaying = this.player.nowPlaying
    const appContext = PathUtils.appContext
    if (!nowPlaying || !appContext) {
      return
    }

    const subtitleMode = this.normalizeSubtitleMode(this.player.subtitleSelected)
    const subtitleVisible = this.subtitleVisibility === Visibility.Visible
    const subtitleAIAsrShown = this.isAIAsrShown
    const subtitle3DMode = this.normalizeSubtitle3DMode(this.subtitle3DMode)
    const subtitleOffsetMillis = Math.max(-50000, Math.min(50000, Math.round(SubtitleUtil.offsetMillis)))
    const subtitleTrackId = this.player.subtitleTrackSelected
    const hasPreferenceChanged =
      nowPlaying.subtitle_mode !== subtitleMode ||
        nowPlaying.subtitle_visible !== subtitleVisible ||
        nowPlaying.subtitle_ai_asr_shown !== subtitleAIAsrShown ||
        nowPlaying.subtitle_3d_mode !== subtitle3DMode ||
        nowPlaying.subtitle_offset_millis !== subtitleOffsetMillis ||
        nowPlaying.subtitle_track_id !== subtitleTrackId

    if (!hasPreferenceChanged) {
      return
    }

    nowPlaying.subtitle_mode = subtitleMode
    nowPlaying.subtitle_visible = subtitleVisible
    nowPlaying.subtitle_ai_asr_shown = subtitleAIAsrShown
    nowPlaying.subtitle_3d_mode = subtitle3DMode
    nowPlaying.subtitle_offset_millis = subtitleOffsetMillis
    nowPlaying.subtitle_track_id = subtitleTrackId

    SelectFileUtil.saveData(appContext, nowPlaying, {
      subtitleMode,
      subtitleVisible,
      subtitleAIAsrShown,
      subtitle3DMode,
      subtitleOffsetMillis,
      subtitleTrackId
    })
  }
}
