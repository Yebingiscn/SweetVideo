import PermissionUtil from '../../utils/PermissionUtil'
import { window } from '@kit.ArkUI'
import ToolsUtil from '../../utils/ToolsUtil'
import VideoInfoUtil from '../../utils/VideoInfoUtil'
import VideoOperateUtil from '../../utils/VideoOperateUtil'
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import { PathUtils } from '../../utils/PathUtils'
import { PlayerSideBarComponent } from '../../component/PlayerComponent/PlayerSideBarComponent'
import { LockVideoBarComponent } from '../../component/PlayerComponent/LockVideoBarComponent'
import { GestureComponent } from '../../component/PlayerComponent/GestureComponent'
import NavigationAddress, { PlayerParams } from '../../common/NavigationCommon'
import { WindowUtil } from '../../utils/WindowUtil'
import { KeyCode } from '@kit.InputKit'
import { XAnimation } from '../../utils/AnimationUtil'
import { SubtitleMode } from '../../common/enum/SubtitleMode'
import { SubtitleManager } from '../../utils/SubtitleManager'
import { AVPlayerController } from '../../controller/AVPlayerController/AVPlayerController'
import { BrightnessSwipingBuilder } from '../../component/PlayerComponent/BrightnessSwipingBuilder'
import { FastForwardPanelBuilder } from '../../component/PlayerComponent/FastForwardPanelBuilder'
import { VolumeSwipingPanelBuilder } from '../../component/PlayerComponent/VolumeSwipingPanelBuilder'
import { SwipingPlayTimePanelBuilder } from '../../component/PlayerComponent/SwipingPlayTimePanelBuilder'
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
  SCALE_FACTORS,
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
import SubtitleUtil from '../../utils/SubtitleUtil'
import { Subtitle3DMode } from '../../common/enum/SubtitleMode'
import { SweetRepeatMode } from '../../common/enum/SweetRepeatMode'
import { AudioTrackComponent } from '../../component/PlayerComponent/AudioTrackComponent'
import { AVCastPickerBuilder } from '../../component/PlayerComponent/AVCastPickerBuilder'
import { PlaybackSpeedMenuComponent } from '../../component/PlayerComponent/PlaybackSpeedComponent'
import { SubtitlePanelComponent } from '../../component/PlayerComponent/SubtitlePanelComponent'
import { VideoButtonsComponent } from '../../component/PlayerComponent/VideoButtonsComponent'
import { VideoSettingComponent } from '../../component/PlayerComponent/VideoSettingComponent'
import { VideoSliderComponent } from '../../component/PlayerComponent/VideoSliderComponent'
import { VideoTopComponent } from '../../component/PlayerComponent/VideoTopComponent'
import Preferences from '../../database/Preferences'
import { salmonLogger } from 'salmonlogger'

const TAG = 'Player'

@ComponentV2
export struct Player { // 播放页
  @Provider('player') player: AVPlayerController = PlayerControllerFactory.createAVPlayerController()
  subtitleManager: SubtitleManager = new SubtitleManager(this.player)
  subtitlePreferenceRestored: boolean = false

  @Monitor('player.subtitleSelected')
  onSubtitleSelectedChange() {
    this.subtitleManager.subtitleMode = this.player.subtitleSelected
    if (!this.subtitlePreferenceRestored) {
      const nowPlaying = this.player.nowPlaying
      if (nowPlaying && SubtitleUtil.hasSubtitlePreferenceMetadata(nowPlaying)) {
        if (nowPlaying.subtitle_3d_mode !== undefined &&
          [Subtitle3DMode.DISABLED, Subtitle3DMode.SIDE_BY_SIDE, Subtitle3DMode.TOP_AND_BOTTOM]
            .includes(nowPlaying.subtitle_3d_mode)) {
          this.subtitleManager.subtitle3DMode = nowPlaying.subtitle_3d_mode as Subtitle3DMode
        }
      }
      this.subtitlePreferenceRestored = true
    }
  }
  subtitleTimestampInputDialog: CustomDialogController = new CustomDialogController({
    builder: SubtitleOffsetDialog({
      getCurrentValue: () => SubtitleUtil.offsetMillis,
      onOffsetPreview: (offset: number) => {
        this.player.refreshExternalSubtitlePreview(offset)
      },
      onCloseButton: () => {
        this.cancelSubtitleOffsetSession()
        this.subtitleTimestampInputDialog.close()
      },
      onPrevSubtitle: (currentOffset: number) => {
        return this.player.getAdjacentSubtitleOffset('prev', currentOffset)
      },
      onNextSubtitle: (currentOffset: number) => {
        return this.player.getAdjacentSubtitleOffset('next', currentOffset)
      },
      confirm: (input: number) => {
        if (Number.isNaN(input)) {
          ToolsUtil.showToast('未输入偏移')
          this.cancelSubtitleOffsetSession()
          this.subtitleTimestampInputDialog.close()
        } else if (Math.abs(input) <= 50000) {
          SubtitleUtil.offsetMillis = input
          this.player.refreshExternalSubtitlePreview(input)
          this.finishSubtitleOffsetSession()
          this.subtitleManager.savePreference()
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
  @Local lockRotation: boolean = false
  xComponentController: XComponentController = new XComponentController()
  windowClass = WindowUtil.getWindow()
  @Local sideBarStatusTmp: Visibility = Visibility.Hidden
  @Local sideBarStatus: boolean = false
  @Local currentSpeedIndex: number = 0
  @Local subtitleAreaWidth: number = 0
  @Local subtitleAreaHeight: number = 0
  personalScreenExtendDialog: CustomDialogController = new CustomDialogController({
    builder: NumberInputDialog({
      title: '自定义屏幕拓展比例',
      placeholderColor: '输入范围：50-150',
      confirm: (input: number) => {
        if (input && input <= 150 && input >= 50) {
          this.player.playAreaHeight = input / 100 * VideoInfoUtil.playAreaHeight
          this.player.playAreaWidth = input / 100 * VideoInfoUtil.playAreaWidth
          this.subtitleAreaWidth = this.player.playAreaWidth
          this.subtitleAreaHeight = this.player.playAreaHeight
        } else {
          ToolsUtil.showToast('输入错误，输入范围在50-150之间')
        }
      },
    }), cornerRadius: 20, shadow: DefaultDialogShadow
  })
  @Consumer('pathStack') pathStack: NavPathStack = new NavPathStack()
  @Local exitVideoTime: number = 0
  @Local isAdjustingSubtitleOffset: boolean = false
  private subtitleOffsetPreviewBase: number = 0
  private subtitleOffsetShouldResumePlayback: boolean = false

  async aboutToAppear(): Promise<void> {
    salmonLogger.addLog(this.pathStack?.getAllPathName()[0] ?? TAG, "开始执行aboutToAppear方法", false)
    PermissionUtil.applyContinuousTask()
    try {
      await (await this.windowClass)?.setPreferredOrientation(window.Orientation.AUTO_ROTATION_RESTRICTED)
      WindowUtil.setKeepScreenStatus(PathUtils.appContext!, true)
      this.player.repeatMode = Preferences.getRepeatModeState(PathUtils.appContext!)
      const videoSpeed = Preferences.getVideoSpeed(PathUtils.appContext!)
      this.player.speed = parseFloat(videoSpeed?.replace('x', '') || '1')
      this.player.selectedText = Preferences.getScreenExtend(PathUtils.appContext!)
      WindowUtil.setBarState(PathUtils.appContext!, false, false)
    } catch (error) {
      salmonLogger.addLog(this.pathStack?.getAllPathName()[0] ?? TAG, `播放错误 ${error}`, true)
    }
    salmonLogger.addLog(this.pathStack?.getAllPathName()[0] ?? TAG, "aboutToAppear方法执行完成", false)
  }

  async aboutToDisappear(): Promise<void> {
    salmonLogger.addLog(this.pathStack?.getAllPathName()[0] ?? TAG, "开始执行aboutToDisappear方法", false)
    VideoOperateUtil.setBrightness(-1)
    WindowUtil.recoveryBarColor()
    Preferences.saveVideoSpeed(PathUtils.appContext!,
      (VideoInfoUtil.videoSpeedListAll.includes(this.player.speed) ? this.player.speed : 1) + 'x')
    Preferences.saveRepeatModeState(PathUtils.appContext!, this.player.repeatMode)
    this.player.saveSubtitlePreferenceForCurrentVideo(this.subtitleManager.subtitleVisibility,
      this.subtitleManager.isAIAsrShown, this.subtitleManager.subtitle3DMode)
    WindowUtil.setBarState(PathUtils.appContext!, true, true)
    clearTimeout(this.exitVideoTime)
    this.player.cancelSubscribe()
    await this.player.release()
    salmonLogger.addLog(this.pathStack?.getAllPathName()[0] ?? TAG, "释放播放器资源完成", false)
    salmonLogger.addLog(this.pathStack?.getAllPathName()[0] ?? TAG, "aboutToDisappear方法执行完成", false)
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
            this.player.playChooseVideo(item, this.pathStack, this.windowClass, this.xComponentController)
            this.player.setPlayerCallback(this.pathStack, this.xComponentController, this.windowClass)
            this.closeSideBar(true)
          }
        })

        Stack() {
          XComponents({
            xComponentController: this.xComponentController,
            choosePlayer: NavigationAddress.AV_PLAYER,
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

          SubtitleDisplayBuilder({
            subtitle: this.player.subtitle,
            screenWidth: this.player.screenWidth,
            screenHeight: this.player.screenHeight,
            showControl: this.player.showControl,
            subTitleVisibility: this.isOffsetSubtitleOverlayActive() ? Visibility.None :
              this.subtitleManager.subtitleVisibility,
            subtitle3DMode: this.subtitleManager.effective3DMode,
            areaWidth: this.subtitleAreaWidth,
            areaHeight: this.subtitleAreaHeight
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
              VideoOperateUtil.lastVolume = this.player.volume
              if (VideoOperateUtil.leftSideSwipe) {
                this.player.onSwipingBrightness = true
              } else {
                this.player.onSwipingVoice = true
              }
            },
            onVerticalPanUpdate: (offsetY: number) => {
              const deltaYScale = offsetY / this.player.screenHeight * VERTICAL_PAN_SENSITIVITY
              if (VideoOperateUtil.leftSideSwipe) {
                this.player.screenBrightness = VideoOperateUtil.calNewBrightness(deltaYScale)
                VideoOperateUtil.setBrightness(this.player.screenBrightness)
              } else {
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
              VideoOperateUtil.initPinchWidth = this.player.playAreaWidth
              VideoOperateUtil.initPinchHeight = this.player.playAreaHeight
              this.player.translateX = 0
              this.player.translateY = 0
              this.player.isGesturing = true
            },
            onPinchUpdate: (fingerDistance: number) => {
              const rawScale = fingerDistance / VideoOperateUtil.initPinchDistance
              const adjustedScale = 1 + (rawScale - 1) * PINCH_SCALE_SENSITIVITY
              const clampedScale = Math.min(Math.max(adjustedScale, MIN_SCALE_FACTOR), MAX_SCALE_FACTOR)
              const scaledWidth = VideoOperateUtil.initPinchWidth * clampedScale
              const maxAllowed = VideoInfoUtil.playAreaWidth * MAX_WIDTH_MULTIPLIER
              const minAllowed = VideoInfoUtil.playAreaWidth * MIN_WIDTH_MULTIPLIER
              if (scaledWidth > maxAllowed || scaledWidth < minAllowed) {
                return
              }
              this.player.playAreaWidth = scaledWidth
              this.player.playAreaHeight = VideoOperateUtil.initPinchHeight * clampedScale
              this.player.isZoomed = clampedScale !== 1
            },
            onPinchEnd: () => {
              this.player.isZoomed = this.player.playAreaWidth !== VideoInfoUtil.playAreaWidth
              this.player.isGesturing = false
            },
            onLongPressAction: () => {
              if (this.player.playing) {
                VideoOperateUtil.lastSpeed = this.player.speed
                this.player.updatePlaybackSpeed(Setting.longPressSpeed)
                XAnimation.runWithAnimation(() => {
                  this.player.longPress = true
                })
                this.currentSpeedIndex = VideoInfoUtil.videoSpeedListAll.indexOf(Setting.longPressSpeed)
              }
            },
            onLongPressEnd: () => {
              XAnimation.runWithAnimation(() => {
                this.player.longPress = false
              })
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
              this.player.isGesturing = true
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
            },
            onPanMoveEnd: () => {
              this.player.isGesturing = false
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
                subTitleVisibility: this.subtitleManager.subtitleVisibility,
                subtitle3DMode: this.subtitleManager.effective3DMode,
                areaWidth: this.player.playAreaWidth,
                areaHeight: this.player.playAreaHeight
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
            isAIAsrShown: this.subtitleManager.isAIAsrShown,
            showControl: this.player.showControl,
            screenHeight: this.player.screenHeight,
          })
        }.onAreaChange((_oldValue: Area, newValue: Area) => {
          this.player.screenWidth = Math.floor(new Number(newValue.width).valueOf())
          this.player.screenHeight = Math.floor(new Number(newValue.height).valueOf())
          this.player.setRotation()
          this.applyScreenExtend()
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
        salmonLogger.addLog(this.pathStack?.getAllPathName()[0] ?? TAG, e, true)
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
      salmonLogger.addLog(this.pathStack?.getAllPathName()[0] ?? TAG, "开始执行onWillDisappear生命周期", false)
      this.player.saveSubtitlePreferenceForCurrentVideo(this.subtitleManager.subtitleVisibility,
        this.subtitleManager.isAIAsrShown, this.subtitleManager.subtitle3DMode)
      VideoOperateUtil.saveLastPlayVideoIndex(this.player.videoMetaDataList, this.player.nowPlaying?.date)
      if (this.player.videoMetaDataList.length > 0 && this.player.playTime > 0) {
        VideoOperateUtil.saveVideoTime(this.player.playTime, this.player.nowPlaying!,
          PathUtils.appContext!)
        salmonLogger.addLog(this.pathStack?.getAllPathName()[0] ?? TAG, "保存视频播放时间完成", false)
      }
      PermissionUtil.applyStopContinuousTask()
      PiPWindowUtil.destroyPipController()
      WindowUtil.disableLandscapeMultiWindow(this.windowClass)
      try {
        WindowUtil.setKeepScreenStatus(PathUtils.appContext!, false)
        if (canIUse('SystemCapability.Window.SessionManager')) {
          await (await this.windowClass)?.setSpecificSystemBarEnabled('status', true)
          await (await this.windowClass)?.setSpecificSystemBarEnabled('navigationIndicator', true)
          salmonLogger.addLog(this.pathStack?.getAllPathName()[0] ?? TAG, "恢复系统栏显示完成", false)
        }
        await (await this.windowClass)?.setPreferredOrientation(window.Orientation.AUTO_ROTATION_RESTRICTED)
        await this.player?.avSession?.stopCasting()
        await VideoOperateUtil.releaseAVImageGenerator()
        await this.player.release()
      } catch (error) {
        salmonLogger.addLog(this.pathStack?.getAllPathName()[0] ?? TAG, `onWillDisappear中发生错误：${error}`, true)
      }
      salmonLogger.addLog(this.pathStack?.getAllPathName()[0] ?? TAG, "onWillDisappear生命周期执行完成", false)
    })
    .hideTitleBar(true)
    .blur(Privacy.isPrivacyBackground ? PRIVACY_BACKGROUND_BLUR_AMOUNT : NO_BLUR_AMOUNT)
  }

  exitVideo(timeOut: number) {
    salmonLogger.addLog(this.pathStack?.getAllPathName()[0] ?? TAG, "开始设置退出视频定时器", false)
    this.exitVideoTime = setTimeout(async () => {
      salmonLogger.addLog(this.pathStack?.getAllPathName()[0] ?? TAG, "退出视频定时器触发" + timeOut, false)
      ToolsUtil.showToast(timeOut > 0 ? '到设定的时间了，已自动退出' : '已退出')
      await this.player.reset()
      salmonLogger.addLog(this.pathStack?.getAllPathName()[0] ?? TAG, "重置播放器完成", false)
      this.pathStack.pop()
    }, timeOut)
    salmonLogger.addLog(this.pathStack?.getAllPathName()[0] ?? TAG, `退出视频定时器设置完成，超时时间：${timeOut}`, false)
  }

  @Builder
  VideoTop() {
    VideoTopComponent({
      isAnySubtitleActive: this.subtitleManager.isAnySubtitleActive,
      audioTrackMenuBuilder: () => {
        this.AudioTrackMenuBuilder()
      },
      subtitlePanelComponent: () => {
        this.SubtitleMenuBuilder()
      },
      chapterMenuBuilder: () => {
      },
      lockRotation: this.lockRotation,
      onExitVideoClick: () => {
        salmonLogger.addLog(this.pathStack?.getAllPathName()[0] ?? TAG, "点击退出视频按钮", false)
        this.exitVideo(0)
      },
      onLockRotationClick: async () => {
        this.lockRotation = !this.lockRotation
        salmonLogger.addLog(this.pathStack?.getAllPathName()[0] ?? TAG, `锁定旋转状态切换为：${this.lockRotation}`,
          false)
        const orientation = this.lockRotation ?
          (this.player.screenWidth > this.player.screenHeight ? window.Orientation.AUTO_ROTATION_LANDSCAPE_RESTRICTED
            : window.Orientation.AUTO_ROTATION_PORTRAIT_RESTRICTED)
          : window.Orientation.AUTO_ROTATION_RESTRICTED
        try {
          XAnimation.runWithAnimation(async () => {
            await (await this.windowClass)?.setPreferredOrientation(orientation)
            salmonLogger.addLog(this.pathStack?.getAllPathName()[0] ?? TAG, "窗口方向设置成功", false)
          })
        } catch (error) {
          salmonLogger.addLog(this.pathStack?.getAllPathName()[0] ?? TAG,
            `屏幕旋转异常: ${error.code}:${error.message}`, true)
        }
        const toastMessage = this.lockRotation
          ? ToolsUtil.getStringResource($r('app.string.open_rotation_lock').id)
          : ToolsUtil.getStringResource($r('app.string.close_rotation_lock').id)
        ToolsUtil.showToast(toastMessage)
      },
      onSpecificVideoProportions: (playAreaSize: number[]) => {
        this.player.playAreaWidth = playAreaSize[0]
        this.player.playAreaHeight = playAreaSize[1]
        this.subtitleAreaWidth = playAreaSize[0]
        this.subtitleAreaHeight = playAreaSize[1]
        this.player.isZoomed = false
        this.player.translateX = 0
        this.player.translateY = 0
      },
      onOriginalRatio: () => {
        this.player.playAreaHeight = VideoInfoUtil.playAreaHeight
        this.player.playAreaWidth = VideoInfoUtil.playAreaWidth
        this.subtitleAreaWidth = VideoInfoUtil.playAreaWidth
        this.subtitleAreaHeight = VideoInfoUtil.playAreaHeight
        this.player.isZoomed = false
        this.player.translateX = 0
        this.player.translateY = 0
      },
      onStretchedToFullScreen: () => {
        this.player.playAreaHeight = this.player.screenHeight
        this.player.playAreaWidth = this.player.screenWidth
        this.subtitleAreaWidth = this.player.screenWidth
        this.subtitleAreaHeight = this.player.screenHeight
        this.player.isZoomed = false
        this.player.translateX = 0
        this.player.translateY = 0
      },
      onFullScreenByWidth: () => {
        this.player.playAreaWidth = this.player.screenWidth
        this.player.playAreaHeight =
          (VideoInfoUtil.playAreaHeight / VideoInfoUtil.playAreaWidth) * this.player.screenWidth
        this.subtitleAreaWidth = this.player.playAreaWidth
        this.subtitleAreaHeight = this.player.playAreaHeight
        this.player.isZoomed = false
        this.player.translateX = 0
        this.player.translateY = 0
      },
      onFullScreenByHeight: () => {
        this.player.playAreaHeight = this.player.screenHeight
        this.player.playAreaWidth =
          (VideoInfoUtil.playAreaWidth / VideoInfoUtil.playAreaHeight) * this.player.screenHeight
        this.subtitleAreaWidth = this.player.playAreaWidth
        this.subtitleAreaHeight = this.player.playAreaHeight
        this.player.isZoomed = false
        this.player.translateX = 0
        this.player.translateY = 0
      },
      onUniformScale: (scale: number) => {
        this.player.playAreaHeight = scale * VideoInfoUtil.playAreaHeight
        this.player.playAreaWidth = scale * VideoInfoUtil.playAreaWidth
        this.subtitleAreaWidth = this.player.playAreaWidth
        this.subtitleAreaHeight = this.player.playAreaHeight
        this.player.isZoomed = false
        this.player.translateX = 0
        this.player.translateY = 0
      },
      onSelectedTextChange: (text: string) => {
        this.player.selectedText = text
        Preferences.saveScreenExtend(PathUtils.appContext!, text)
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
      onPlayNextVideoClick: async () => {
        await this.player.playNextVideoProcess(this.pathStack, this.windowClass, this.xComponentController)
        this.player.setPlayerCallback(this.pathStack, this.xComponentController, this.windowClass)
        salmonLogger.addLog(this.pathStack?.getAllPathName()[0] ?? TAG, "播放下一个视频请求已发送", false)
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
        VideoOperateUtil.saveAudioTrackPreference(this.player?.nowPlaying, index, this.player?.audioTrack.length ?? 0)
      }
    })
  }

  @Builder
  VideoSettingBuilder() {
    VideoSettingComponent({
      exitVideoTime: this.exitVideoTime,
      forward_80_s: (time: number) => {
        salmonLogger.addLog(this.pathStack?.getAllPathName()[0] ?? TAG, `执行快进80秒操作，目标时间：${time}`, false)
        this.player.seekTime(time)
      },
      closeAfter15min: (time: number) => {
        salmonLogger.addLog(this.pathStack?.getAllPathName()[0] ?? TAG, "设置15分钟后关闭播放器", false)
        this.exitVideo(time)
      },
      closeAfter30min: (time: number) => {
        salmonLogger.addLog(this.pathStack?.getAllPathName()[0] ?? TAG, "设置30分钟后关闭播放器", false)
        this.exitVideo(time)
      },
      closeAfter60min: (time: number) => {
        salmonLogger.addLog(this.pathStack?.getAllPathName()[0] ?? TAG, "设置60分钟后关闭播放器", false)
        this.exitVideo(time)
      },
      toggleListenVideo: () => {
        salmonLogger.addLog(this.pathStack?.getAllPathName()[0] ?? TAG, "切换只听视频模式", false)
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
      subtitleManager: this.subtitleManager,
      onSubtitleOffsetTime: () => {
        this.subtitleManager.switchToExternal()
        this.subtitleOffsetShouldResumePlayback = this.player.playing
        if (this.subtitleOffsetShouldResumePlayback) {
          this.player.pause()
        }
        this.subtitleOffsetPreviewBase = SubtitleUtil.offsetMillis
        this.isAdjustingSubtitleOffset = true
        this.player.refreshExternalSubtitlePreview(this.subtitleOffsetPreviewBase)
        this.subtitleTimestampInputDialog.open()
      },
    })
  }

  @Builder
  AVCastPickerBuilderBridge() {
    AVCastPickerBuilder()
  }

  private applyScreenExtend() {
    const text = this.player.selectedText
    if (!text || text === '原始比例') {
      this.subtitleAreaWidth = this.player.playAreaWidth
      this.subtitleAreaHeight = this.player.playAreaHeight
      return
    }
    if (VideoInfoUtil.ASPECT_RATIO_MAP.has(text)) {
      const playAreaSize = VideoOperateUtil.setVideoAspectRatio(
        VideoInfoUtil.ASPECT_RATIO_MAP.get(text)!,
        VideoInfoUtil.playAreaWidth, VideoInfoUtil.playAreaHeight)
      this.player.playAreaWidth = playAreaSize[0]
      this.player.playAreaHeight = playAreaSize[1]
    } else if (text === '拉伸全屏') {
      this.player.playAreaWidth = this.player.screenWidth
      this.player.playAreaHeight = this.player.screenHeight
    } else if (text === '按宽度全屏') {
      this.player.playAreaWidth = this.player.screenWidth
      this.player.playAreaHeight =
        (VideoInfoUtil.playAreaHeight / VideoInfoUtil.playAreaWidth) * this.player.screenWidth
    } else if (text === '按高度全屏') {
      this.player.playAreaHeight = this.player.screenHeight
      this.player.playAreaWidth =
        (VideoInfoUtil.playAreaWidth / VideoInfoUtil.playAreaHeight) * this.player.screenHeight
    } else {
      const scale = SCALE_FACTORS.get(text)
      if (scale) {
        this.player.playAreaWidth = scale * VideoInfoUtil.playAreaWidth
        this.player.playAreaHeight = scale * VideoInfoUtil.playAreaHeight
      }
    }
    this.subtitleAreaWidth = this.player.playAreaWidth
    this.subtitleAreaHeight = this.player.playAreaHeight
  }

  private isOffsetSubtitleOverlayActive(): boolean {
    return this.isAdjustingSubtitleOffset && this.subtitleManager.subtitleMode === SubtitleMode.EXTERNAL_SUBTITLE
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
    this.player.refreshExternalSubtitlePreview(this.subtitleOffsetPreviewBase)
    this.finishSubtitleOffsetSession()
  }
}
