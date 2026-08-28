import PermissionUtil from '../../utils/PermissionUtil'
import { window } from '@kit.ArkUI'
import { KeyCode, pointer } from '@kit.InputKit'
import ToolsUtil from '../../utils/ToolsUtil'
import VideoInfoUtil from '../../utils/VideoInfoUtil'
import VideoOperateUtil from '../../utils/VideoOperateUtil'
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import { PathUtils } from '../../utils/PathUtils'
import { PlayerSideBarComponent } from '../../component/PlayerComponent/PlayerSideBarComponent'
import { LockVideoBarComponent } from '../../component/PlayerComponent/LockVideoBarComponent'
import { GestureComponent } from '../../component/PlayerComponent/GestureComponent'
import NavigationAddress, { PlayerEngine, PlayerParams } from '../../common/NavigationCommon'
import { WindowUtil } from '../../utils/WindowUtil'
import { XAnimation } from '../../utils/AnimationUtil'
import { Subtitle3DMode } from '../../common/enum/SubtitleMode'
import { SubtitleManager } from '../../utils/SubtitleManager'
import { FastForwardPanelBuilder } from '../../component/PlayerComponent/FastForwardPanelBuilder'
import { SwipingPanelBuilder } from '../../component/PlayerComponent/SwipingPanelBuilder'
import { SwipingPlayTimePanelBuilder } from '../../component/PlayerComponent/SwipingPlayTimePanelBuilder'
import { SubtitleDisplayBuilder } from '../../component/PlayerComponent/SubtitleDisplayBuilder'
import { Pc, Privacy, Setting } from '../../utils/ObservedUtil'
import { AVPlayerController } from '../../controller/AVPlayerController/AVPlayerController'
import { PlayerControllerFactory, PlayerControllerInterface } from '../../controller/PlayerControllerFactory'
import { PlaybackSessionController } from '../../controller/PlaybackSessionController'
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
  SCROLL_BRIGHTNESS_SENSITIVITY,
  SCROLL_VOLUME_SENSITIVITY,
  SWIPE_THRESHOLD,
  VERTICAL_PAN_SENSITIVITY,
  VOLUME_PAN_MULTIPLIER,
  VOLUME_STEP
} from '../../common/Constants'
import PiPWindowUtil from '../../utils/PiPWindowUtil'
import { DefaultDialogShadow } from '../../common/AttributeModifierConfig'
import { NumberInputDialog } from '../../component/Dialog/NumberInputDialog'
import { SubtitleOffsetDialog } from '../../component/Dialog/SubtitleOffsetDialog'
import SubtitleUtil from '../../utils/SubtitleUtil'
import { SweetRepeatMode } from '../../common/enum/SweetRepeatMode'
import { AudioTrackComponent } from '../../component/PlayerComponent/AudioTrackComponent'
import { AVCastPickerBuilder } from '../../component/PlayerComponent/AVCastPickerBuilder'
import { ChapterListComponent } from '../../component/PlayerComponent/ChapterListComponent'
import { PlaybackSpeedMenuComponent } from '../../component/PlayerComponent/PlaybackSpeedComponent'
import { SubtitlePanelComponent } from '../../component/PlayerComponent/SubtitlePanelComponent'
import { VideoButtonsComponent } from '../../component/PlayerComponent/VideoButtonsComponent'
import { VideoSettingComponent } from '../../component/PlayerComponent/VideoSettingComponent'
import { VideoSliderComponent } from '../../component/PlayerComponent/VideoSliderComponent'
import { VideoTopComponent } from '../../component/PlayerComponent/VideoTopComponent'
import Preferences from '../../database/Preferences'
import { salmonLogger } from 'salmonlogger'
import { AISubtitleComponent } from '../../component/PlayerComponent/AIAsrComponent'
import AVSessionUtil from '../../utils/AVSessionUtil'

const TAG = 'VideoPlayer'

type PlayerType = PlayerControllerInterface

@ComponentV2
export struct VideoPlayer {
  @Local playerType: string = PlayerEngine.AV_PLAYER
  @Local autoListenVideoEnabled: boolean = false
  @Provider('player') player: PlayerType = PlayerControllerFactory.createAVPlayerController() as PlayerType
  subtitleManager: SubtitleManager = new SubtitleManager(this.player)
  personalScreenExtendDialog: CustomDialogController = new CustomDialogController({
    builder: NumberInputDialog({
      title: '自定义屏幕拓展比例',
      placeholderColor: '输入范围：50-150',
      confirm: (input: number): void => {
        if (input && input <= 150 && input >= 50) {
          this.player.selectedText = `自定义比例:${input}`
          Preferences.saveScreenExtend(PathUtils.appContext!, this.player.selectedText)
          this.player.playAreaHeight = input / 100 * VideoInfoUtil.playAreaHeight
          this.player.playAreaWidth = input / 100 * VideoInfoUtil.playAreaWidth
          this.player.scaleFactor = 1

        } else {
          ToolsUtil.showToast('输入错误，输入范围在50-150之间')
        }
      },
    }), cornerRadius: 20, shadow: DefaultDialogShadow
  })
  @Local isPlayerConfigured: boolean = false
  @Local subtitlePreferenceRestored: boolean = false
  @Local lockRotation: boolean = false
  xComponentController: XComponentController = new XComponentController()
  osdXController: XComponentController = new XComponentController()
  windowClass: Promise<window.Window | undefined> = WindowUtil.getWindow()
  @Local sideBarStatusTmp: Visibility = Visibility.Hidden
  @Local sideBarStatus: boolean = false
  @Local currentSpeedIndex: number = 0
  @Consumer('pathStack') pathStack: NavPathStack = new NavPathStack()
  @Local exitVideoTime: number = 0
  @Local isAdjustingSubtitleOffset: boolean = false
  private containerWidth: number = 0
  private containerHeight: number = 0
  private longPressSpeedSession: number = 0
  private activeLongPressSpeedSession: number = 0
  private longPressBaseSpeed: number = 1
  private playbackSession: PlaybackSessionController = new PlaybackSessionController()
  private engineSwitchTask: Promise<void> | undefined = undefined
  private playerDisposeTask: Promise<void> | undefined = undefined
  private isPlaybackSessionDisposed: boolean = false
  private isPageDisappearing: boolean = false
  private subtitleOffsetPreviewBase: number = 0
  private subtitleOffsetShouldResumePlayback: boolean = false
  private isAdjustingMpvSubtitleOffset: boolean = false
  subtitleTimestampInputDialog: CustomDialogController = new CustomDialogController({
    builder: SubtitleOffsetDialog({
      getCurrentValue: (): number => SubtitleUtil.offsetMillis,
      onOffsetPreview: (offset: number): void => {
        this.player.setSubtitleOffset(offset)
      },
      onCloseButton: (): void => {
        this.cancelSubtitleOffsetSession()
        this.subtitleTimestampInputDialog.close()
      },
      onPrevSubtitle: (currentOffset: number): number | undefined => {
        return this.player.getAdjacentSubtitleOffset('prev', currentOffset)
      },
      onNextSubtitle: (currentOffset: number): number | undefined => {
        return this.player.getAdjacentSubtitleOffset('next', currentOffset)
      },
      showSubtitleNavigation: (): boolean => !this.isAdjustingMpvSubtitleOffset,
      confirm: (input: number): void => {
        if (Number.isNaN(input)) {
          ToolsUtil.showToast('未输入偏移')
          this.cancelSubtitleOffsetSession()
          this.subtitleTimestampInputDialog.close()
        } else if (Math.abs(input) <= 50000) {
          SubtitleUtil.offsetMillis = input
          this.player.setSubtitleOffset(input)
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
    cancel: (): void => {
      this.cancelSubtitleOffsetSession()
    }
  })
  private scrollAxisTimeout: number = 0
  private orientationRequestVersion: number = 0

  @Monitor('player.showControl')
  onShowControlMonitor() {
    if (!Pc.pcMode) {
      return
    }
    if (canIUse("SystemCapability.MultimodalInput.Input.Pointer")) {
      pointer.setPointerVisible(this.player.showControl).catch(() => {
        salmonLogger.addLog(TAG, `setPointerVisible failed`, true)
      })
    }
  }

  aboutToAppear(): void {
    this.isPageDisappearing = false
    const requestVersion = ++this.orientationRequestVersion
    salmonLogger.addLog(TAG, "开始执行aboutToAppear方法", false)
    PermissionUtil.applyContinuousTask()
    this.getWindowClass()?.then(w => {
      if (!this.isPageDisappearing && requestVersion === this.orientationRequestVersion) {
        w?.setPreferredOrientation(window.Orientation.AUTO_ROTATION_RESTRICTED)?.catch(() => {
        })
      }
    })
    WindowUtil.setKeepScreenStatus(PathUtils.appContext!, true)
    WindowUtil.setBarState(PathUtils.appContext!, false, false)
    if (Setting.defaultBrightness > 0) {
      VideoOperateUtil.setBrightness(Setting.defaultBrightness / 100)
    }
    salmonLogger.addLog(TAG, "aboutToAppear方法执行完成", false)
  }

  async aboutToDisappear(): Promise<void> {
    this.isPageDisappearing = true
    this.orientationRequestVersion++
    this.player.onWillDisappearCleanup()
    VideoOperateUtil.cancelControlAutoHide()
    this.restoreAutomaticOrientation()
    salmonLogger.addLog(TAG, "开始执行aboutToDisappear方法", false)
    VideoOperateUtil.setBrightness(-1)
    WindowUtil.recoveryBarColor()
    if (Pc.pcMode) {
      if (canIUse("SystemCapability.MultimodalInput.Input.Pointer")) {
        pointer.setPointerVisible(true).catch(() => {
          salmonLogger.addLog(TAG, `restore pointer visible failed`, true)
        })
      }
    }
    this.player.savePlayerSpeed(PathUtils.appContext!)
    Preferences.saveRepeatModeState(PathUtils.appContext!, this.player.repeatMode)
    this.player.onDisappearSaveSubtitlePreference(this.subtitleManager.subtitleVisibility,
      this.subtitleManager.isAIAsrShown, this.subtitleManager.subtitle3DMode)
    this.player.onDisappearCleanup()
    clearTimeout(this.exitVideoTime)
    clearTimeout(this.scrollAxisTimeout)
    await this.disposePlaybackSession()
    salmonLogger.addLog(TAG, "释放播放器资源完成", false)
    salmonLogger.addLog(TAG, "aboutToDisappear方法执行完成", false)
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
          onItemClick: async (item: VideoMetadata) => {
            await this.player.playChooseVideo(item, this.pathStack, this.windowClass, this.xComponentController)
            this.player.setPlayerCallback(this.pathStack, this.xComponentController, this.windowClass)
            this.closeSideBar(true)
          }
        })

        Stack() {
          if (this.isPlayerConfigured) {
            XComponents({
              xComponentController: this.xComponentController,
              xComponentId: this.player.getXComponentId(),
              libraryName: this.player.getLibraryName(),
              choosePlayer: this.player.isMpvPlayer() ? PlayerEngine.MPV_PLAYER : PlayerEngine.AV_PLAYER,
              barState: this.player.showControl,
              osdXController: this.player.isMpvPlayer() ? this.osdXController : undefined,
              osdVisibility: this.player.getOsdVisibility(),
              onXComponentLoad: async (surfaceController: XComponentController | undefined,
                surfaceEngine: string) => {
                if (this.isPageDisappearing) {
                  return
                }
                const surfacePlayer = this.player
                const currentEngine =
                  surfacePlayer.isMpvPlayer() ? PlayerEngine.MPV_PLAYER : PlayerEngine.AV_PLAYER
                if (!surfaceController || currentEngine !== surfaceEngine) {
                  return
                }
                if (this.isPageDisappearing) {
                  return
                }
                await surfacePlayer.onSurfaceLoad(surfaceController, this.pathStack, this.windowClass)
              },
              onKeyCodeSpace: () => {
                this.player.togglePlayback()
              },
              onKeyCodeEscape: () => {
                VideoOperateUtil.fullScreenOrRotateScreen(this.player.screenWidth, this.player.screenHeight,
                  this.getWindowClass())
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
              onOsdSurfaceLoad: (surfaceId: string, surfaceWidth: number, surfaceHeight: number) => {
                this.player.onOsdSurfaceLoad(surfaceId, surfaceWidth, surfaceHeight)
              },
              onOsdSurfaceDestroy: (surfaceId: string) => {
                this.player.onOsdSurfaceDestroy(surfaceId)
              },
            })
          }

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
              speedLocked: this.player.speedLocked,
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

          SwipingPanelBuilder({
            videoVolume: this.player.volume,
            videoVolumeShow: this.player.volumeActually,
            onSwipingVoice: this.player.onSwipingVoice,
            onSwipingBrightness: this.player.onSwipingBrightness,
            screenBrightness: this.player.screenBrightness,
            playAreaHeight: VideoInfoUtil.playAreaHeight
          })
          if (this.player.lockVisibility) {
            LockVideoBarComponent({
              onLockClick: () => {
                this.player.isLock = !this.player.isLock
                this.player.showControl = true
              },
              lockRotation: this.lockRotation,
              onLockRotationClick: async () => {
                this.lockRotation = !this.lockRotation
                salmonLogger.addLog(TAG, `锁定旋转状态切换为：${this.lockRotation}`,
                  false)
                const orientation = this.lockRotation ?
                  (this.player.screenWidth > this.player.screenHeight ?
                    window.Orientation.AUTO_ROTATION_LANDSCAPE_RESTRICTED
                    : window.Orientation.AUTO_ROTATION_PORTRAIT_RESTRICTED)
                  : window.Orientation.AUTO_ROTATION_RESTRICTED
                try {
                  XAnimation.runWithAnimation(async () => {
                    await (await this.getWindowClass())?.setPreferredOrientation(orientation)
                    salmonLogger.addLog(TAG, "窗口方向设置成功", false)
                  })
                } catch (error) {
                  salmonLogger.addLog(TAG,
                    `屏幕旋转异常: ${error.code}:${error.message}`, true)
                }
                const toastMessage = this.lockRotation
                  ? ToolsUtil.getStringResource($r('app.string.open_rotation_lock').id)
                  : ToolsUtil.getStringResource($r('app.string.close_rotation_lock').id)
                ToolsUtil.showToast(toastMessage)
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
                XAnimation.runWithAnimation(() => {
                  this.player.lockVisibility = !this.player.lockVisibility
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
              VideoOperateUtil.initScaleFactor = this.player.scaleFactor
              this.player.translateX = 0
              this.player.translateY = 0
              this.player.isGesturing = true
            },
            onPinchUpdate: (fingerDistance: number) => {
              const rawScale = fingerDistance / VideoOperateUtil.initPinchDistance
              const adjustedScale = 1 + (rawScale - 1) * PINCH_SCALE_SENSITIVITY
              const newScaleFactor = VideoOperateUtil.initScaleFactor * adjustedScale
              const clampedScaleFactor = Math.min(Math.max(newScaleFactor, MIN_SCALE_FACTOR), MAX_SCALE_FACTOR)
              const effectiveWidth = VideoInfoUtil.playAreaWidth * clampedScaleFactor
              const maxAllowed = VideoInfoUtil.playAreaWidth * MAX_WIDTH_MULTIPLIER
              const minAllowed = VideoInfoUtil.playAreaWidth * MIN_WIDTH_MULTIPLIER
              if (effectiveWidth > maxAllowed || effectiveWidth < minAllowed) {
                return
              }
              this.player.scaleFactor = clampedScaleFactor
              this.player.isZoomed = clampedScaleFactor !== 1
            },
            onPinchEnd: () => {
              this.player.isZoomed = this.player.scaleFactor !== 1
              this.player.isGesturing = false
            },
            onLongPressAction: () => {
              if (!this.player.playing || this.activeLongPressSpeedSession !== 0) {
                return
              }
              this.activeLongPressSpeedSession = ++this.longPressSpeedSession
              this.longPressBaseSpeed = this.player.speed
              this.player.speedLocked = false
              this.player.updatePlaybackSpeed(Setting.longPressSpeed)
              XAnimation.runWithAnimation(() => {
                this.player.longPress = true
              })
              ToolsUtil.startVibration()
              this.currentSpeedIndex = VideoInfoUtil.videoSpeedListAll.indexOf(Setting.longPressSpeed)
            },
            onLongPressEnd: () => {
              if (this.activeLongPressSpeedSession === 0) {
                return
              }
              this.activeLongPressSpeedSession = 0
              XAnimation.runWithAnimation(() => {
                this.player.longPress = false
              })
              if (!this.player.speedLocked) {
                // Restore the media clock before running any UI animation.
                // Late callbacks from the parallel Pan recognizers are ignored
                // because the active session was invalidated above.
                this.player.restoreSpeedAfterLongPress(this.longPressBaseSpeed)
              }
              this.player.speedLocked = false
            },
            onLongPressPanStart: (tapX: number) => {
              VideoOperateUtil.longPressStartX = tapX
              ToolsUtil.startVibration()
            },
            onLongPressPanUpdate: (tapX: number) => {
              if (this.activeLongPressSpeedSession !== 0 && this.player.longPress) {
                const deltaX = tapX - VideoOperateUtil.longPressStartX
                if (Math.abs(deltaX) <= SWIPE_THRESHOLD) {
                  return
                }
                const direction = Math.sign(deltaX)
                const newIndex = this.currentSpeedIndex + direction
                const clampedIndex = Math.max(0, Math.min(newIndex, VideoInfoUtil.videoSpeedListAll.length - 1))
                if (clampedIndex === this.currentSpeedIndex) {
                  return
                }
                this.currentSpeedIndex = clampedIndex
                this.player.updatePlaybackSpeed(VideoInfoUtil.videoSpeedListAll[this.currentSpeedIndex])
                this.player.speedLocked = false
                VideoOperateUtil.longPressStartX = tapX
                ToolsUtil.startVibration()
              }
            },
            onLongPressVerticalPanUpdate: (offsetY: number) => {
              if (this.activeLongPressSpeedSession !== 0 && this.player.longPress &&
                !this.player.speedLocked && offsetY < -SWIPE_THRESHOLD) {
                this.player.speedLocked = true
                ToolsUtil.startVibration()
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
            },
            onScrollAxisBegin: (isLeftSide: boolean) => {
              clearTimeout(this.scrollAxisTimeout)
              if (isLeftSide) {
                this.player.onSwipingVoice = false
                VideoOperateUtil.screenBrightnessTmp = this.player.screenBrightness
                this.player.onSwipingBrightness = true
              } else {
                this.player.onSwipingBrightness = false
                this.player.volume = this.player.volumeActually
                VideoOperateUtil.lastVolume = this.player.volume
                this.player.onSwipingVoice = true
              }
            },
            onScrollAxisUpdate: (axisValue: number, isLeftSide: boolean) => {
              const delta = -axisValue
              if (isLeftSide) {
                const brightnessStep = delta * SCROLL_BRIGHTNESS_SENSITIVITY
                const newBrightness = this.player.screenBrightness + brightnessStep
                this.player.screenBrightness = Math.min(Math.max(newBrightness, 0), 1)
                VideoOperateUtil.setBrightness(this.player.screenBrightness)
              } else {
                const volumeStep = delta * SCROLL_VOLUME_SENSITIVITY
                const newVolume = this.player.volume + volumeStep
                this.player.volume =
                  Math.min(Math.max(newVolume, VideoOperateUtil.minVolume), VideoOperateUtil.maxVolume)
                this.player.volumeActually = this.player.volume
                VideoOperateUtil.lastVolume = this.player.volume
              }
            },
            onScrollAxisEnd: () => {
              this.scrollAxisTimeout = setTimeout(() => {
                this.player.onSwipingVoice = false
                this.player.onSwipingBrightness = false
              }, 1500)
            }
          })
            .hitTestBehavior(HitTestMode.Transparent)

          SubtitleDisplayBuilder({
            subtitle: this.player.subtitle,
            screenWidth: this.player.screenWidth,
            screenHeight: this.player.screenHeight,
            showControl: this.player.showControl,
            subTitleVisibility: this.subtitleManager.subtitleVisibility,
            subtitle3DMode: this.subtitleManager.effective3DMode,
            subtitlePosition: this.player.subtitlePosition,
            subtitleSize: this.player.subtitleSize,
            areaWidth: this.player.playAreaWidth,
            areaHeight: this.player.playAreaHeight,
            angle: this.player.angle,
            scaleFactor: this.player.scaleFactor,
            translateX: this.player.translateX,
            translateY: this.player.translateY,
            animDuration: this.player.playTime > 300 ? 300 : 0
          })

          AISubtitleComponent({
            isAIAsrShown: this.subtitleManager.isAIAsrShown,
            showControl: this.player.showControl,
            screenHeight: this.player.screenHeight,
          })
        }
        .onAreaChange(async (_oldValue: Area, newValue: Area) => {
          this.containerWidth = Math.floor(new Number(newValue.width).valueOf())
          this.containerHeight = Math.floor(new Number(newValue.height).valueOf())
          this.player.screenWidth = this.containerWidth
          this.player.screenHeight = this.containerHeight
          this.player.setRotation()
        })
        .height('100%')
        .width('100%')
        .backgroundColor($r('sys.color.black'))
        .onMouse((event: MouseEvent) => {
          if (!Pc.pcMode || event.action !== MouseAction.Move) {
            return
          }
          if (!this.player.showControl) {
            this.player.showControl = true
          }
          VideoOperateUtil.scheduleControlAutoHide(() => {
            this.player.lockVisibility = false
            this.player.showControl = false
          })
        })
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
      if (this.isPageDisappearing) {
        return
      }
      this.isPlaybackSessionDisposed = false
      this.isPlayerConfigured = false
      let playerParams: PlayerParams | undefined
      const videoPlayerParams: PlayerParams[] =
        this.pathStack.getParamByName(NavigationAddress.VIDEO_PLAYER) as PlayerParams[]
      if (videoPlayerParams.length > 0) {
        playerParams = videoPlayerParams[0]
      }
      if (!playerParams) {
        return
      }
      try {
        this.playerType = playerParams.playerType ?? PlayerEngine.AV_PLAYER
        this.player = PlayerControllerFactory.createController(this.playerType) as PlayerType

        this.bindEngineSwitchHandler(this.player)
        this.subtitleManager = new SubtitleManager(this.player)
        const metadata = playerParams.metadata as VideoMetadata
        this.player.nowPlaying = metadata
        if (playerParams.metadata_list) {
          this.player.videoMetaDataList = playerParams.metadata_list as VideoMetadata[]
        } else if (playerParams!.folder_date) {
          setTimeout(() => {
            const folders = Preferences.getFileFolder(PathUtils.appContext!)
            const folder = folders.find(f => f.date === playerParams!.folder_date)
            if (folder) {
              this.player.videoMetaDataList = folder.video_list
            }
          }, 0)
        }
        this.player.skipHistory = playerParams.skipHistory
        this.player.repeatMode = Preferences.getRepeatModeState(PathUtils.appContext!)
        const videoSpeed = Preferences.getVideoSpeed(PathUtils.appContext!)
        this.player.speed = parseFloat(videoSpeed?.replace('x', '') || '1')
        this.player.selectedText = Preferences.getScreenExtend(PathUtils.appContext!)
        this.restoreSubtitlePreference()
        if (this.isPageDisappearing) {
          this.player.onWillDisappearCleanup()
          return
        }
        this.player.onPlayerReady()
        this.isPlayerConfigured = true
      } catch (e) {
        salmonLogger.addLog(TAG, e, true)
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
      this.player.onSwiping = false
      this.player.isSliderPlayTimeChange = false
      this.player.onSwipingVoice = false
      this.player.onSwipingBrightness = false
      if (PiPWindowUtil.pipOpenState) {
        PiPWindowUtil.stopPip()
      }
      WindowUtil.setKeepScreenStatus(PathUtils.appContext!, true)
      if (this.autoListenVideoEnabled) {
        if (this.player instanceof AVPlayerController && this.player.isListenVideo) {
          this.player.isListenVideo = false
          this.player.setListenVideoStatus()
        }
        this.autoListenVideoEnabled = false
      }
      if (Setting.autoResumeOnReturn && !this.player.playing) {
        this.player.play()
      }
    })
    .onHidden(() => {
      salmonLogger.addLog(TAG, "开始执行onHidden生命周期", false)
      this.player.onSwiping = false
      this.player.isSliderPlayTimeChange = false
      this.player.onSwipingVoice = false
      this.player.onSwipingBrightness = false
      VideoOperateUtil.saveVideoPlayTimeIfNeed(this.player.playTime, this.player.nowPlaying,
        this.player.skipHistory, PathUtils.appContext!)
      if (this.player instanceof AVPlayerController && !PiPWindowUtil.pipOpenState &&
        !Setting.autoActivePip && !this.player.isListenVideo) {
        this.player.isListenVideo = true
        this.player.setListenVideoStatus()
        this.autoListenVideoEnabled = true
      }
    })
    .onWillDisappear(async () => {
      this.isPageDisappearing = true
      this.orientationRequestVersion++
      this.player.onWillDisappearCleanup()
      const orientationRestore = this.restoreAutomaticOrientation()
      salmonLogger.addLog(TAG, "开始执行onWillDisappear生命周期", false)
      try {
        this.player.saveSubtitlePreferenceForCurrentVideo(this.subtitleManager.subtitleVisibility,
          this.subtitleManager.isAIAsrShown, this.subtitleManager.subtitle3DMode)
        VideoOperateUtil.saveLastPlayVideoIndex(this.player.videoMetaDataList, this.player.nowPlaying?.date)
        VideoOperateUtil.saveVideoPlayTimeIfNeed(this.player.playTime, this.player.nowPlaying,
          this.player.skipHistory, PathUtils.appContext!)
        // stopCasting 必须发生在 applyStopContinuousTask 销毁 AVSession 之前。
        await AVSessionUtil.stopCastingIfActive()
        PermissionUtil.applyStopContinuousTask()
        await PiPWindowUtil.destroyPipController()
        WindowUtil.disableLandscapeMultiWindow(this.getWindowClass())
        WindowUtil.setKeepScreenStatus(PathUtils.appContext!, false)
        await this.player.restoreSystemBars(this.windowClass)
        await orientationRestore
      } catch (error) {
        salmonLogger.addLog(TAG, `onWillDisappear中发生错误：${error}`, true)
      } finally {
        await this.disposePlaybackSession()
      }
      salmonLogger.addLog(TAG, "onWillDisappear生命周期执行完成", false)
    })
    .hideTitleBar(true)

    .blur(Privacy.isPrivacyBackground ? PRIVACY_BACKGROUND_BLUR_AMOUNT : NO_BLUR_AMOUNT)
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
      chapterMenuBuilder: this.player.hasChapterSupport() ? () => {
        this.ChapterMenuBuilder()
      } : () => {
      },
      onExitVideoClick: () => {
        salmonLogger.addLog(TAG, "点击退出视频按钮", false)
        this.exitVideo(0)
      },
      onCaptureScreen: () => {
        if (this.player.surfaceId) {
          VideoOperateUtil.saveCaptureScreenToAlbum(this.player.surfaceId)
        }
      },
      onSpecificVideoProportions: (playAreaSize: number[]) => {
        this.player.playAreaWidth = playAreaSize[0]
        this.player.playAreaHeight = playAreaSize[1]
        this.player.isZoomed = false
        this.player.scaleFactor = 1
        this.player.translateX = 0
        this.player.translateY = 0
      },
      onOriginalRatio: () => {
        this.player.resetAspectRatio()
        this.player.playAreaHeight = VideoInfoUtil.playAreaHeight
        this.player.playAreaWidth = VideoInfoUtil.playAreaWidth
        this.player.isZoomed = false
        this.player.scaleFactor = 1
        this.player.translateX = 0
        this.player.translateY = 0
      },
      onStretchedToFullScreen: () => {
        this.player.stretchToFullScreen()
        this.player.playAreaHeight = this.player.screenHeight
        this.player.playAreaWidth = this.player.screenWidth
        this.player.isZoomed = false
        this.player.scaleFactor = 1
        this.player.translateX = 0
        this.player.translateY = 0
      },
      onFullScreenByWidth: () => {
        this.player.playAreaWidth = this.player.screenWidth
        this.player.playAreaHeight =
          (VideoInfoUtil.playAreaHeight / VideoInfoUtil.playAreaWidth) * this.player.screenWidth
        this.player.isZoomed = false
        this.player.scaleFactor = 1
        this.player.translateX = 0
        this.player.translateY = 0
      },
      onFullScreenByHeight: () => {
        this.player.playAreaHeight = this.player.screenHeight
        this.player.playAreaWidth =
          (VideoInfoUtil.playAreaWidth / VideoInfoUtil.playAreaHeight) * this.player.screenHeight
        this.player.isZoomed = false
        this.player.scaleFactor = 1
        this.player.translateX = 0
        this.player.translateY = 0
      },
      onUniformScale: (scale: number) => {
        this.player.playAreaHeight = scale * VideoInfoUtil.playAreaHeight
        this.player.playAreaWidth = scale * VideoInfoUtil.playAreaWidth
        this.player.isZoomed = false
        this.player.scaleFactor = 1
        this.player.translateX = 0
        this.player.translateY = 0
      },
      onSelectedTextChange: (text: string) => {
        this.player.selectedText = text
        Preferences.saveScreenExtend(PathUtils.appContext!, text)
      },
      pipStateChange: async () => {
        await PiPWindowUtil.startPip()
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
        this.player.isSliderPlayTimeChange = true
        this.player.playTime = value
        this.player.getFrameByTime(value, false)
      },
      onSliderTouch: (event: TouchEvent) => {
        if (event.type == TouchType.Down) {
          this.player.onSwiping = true
          this.player.getFrameByTime(this.player.playTime, true)
        }
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
        VideoOperateUtil.fullScreenOrRotateScreen(this.player.screenWidth, this.player.screenHeight,
          this.getWindowClass())
      },
      onTogglePlaybackClick: () => {
        this.player.togglePlayback()
      },
      onPlayPreviousVideoClick: async () => {
        const previousRepeatMode =
          this.player.repeatMode === SweetRepeatMode.SINGLE ? SweetRepeatMode.LIST : this.player.repeatMode
        const previousItem = this.player.playAdjacentVideo(previousRepeatMode, 'previous')
        if (!previousItem) {
          ToolsUtil.showToast('没有上一首')
          return
        }
        await this.player.playChooseVideo(previousItem, this.pathStack, this.windowClass, this.xComponentController)
        this.player.setPlayerCallback(this.pathStack, this.xComponentController, this.windowClass)
        salmonLogger.addLog(TAG, '播放上一首视频请求已发送', false)
      },
      onPlayNextVideoClick: async () => {
        const nextRepeatMode =
          this.player.repeatMode === SweetRepeatMode.SINGLE ? SweetRepeatMode.LIST : this.player.repeatMode
        this.player.playNextVideoProcess(this.pathStack, this.windowClass, this.xComponentController, nextRepeatMode)
          .catch((error: Error) => {
            salmonLogger.addLog(TAG, `play next video failed: ${error.message}`, true)
          })
        this.player.setPlayerCallback(this.pathStack, this.xComponentController, this.windowClass)
        salmonLogger.addLog(TAG, "播放下一个视频请求已发送", false)
      },
      onSideBaClose: () => {
        this.closeSideBar(true)
      }
    })
  }

  @Builder
  AudioTrackMenuBuilder() {
    AudioTrackComponent({
      onSelect: (index: number) => {
        this.player.selectAudioTrackByIndex(index)
        this.player.audioTrackSelected = index
        VideoOperateUtil.saveAudioTrackPreference(this.player.nowPlaying, index, this.player.getAudioTrackCount())
      }
    })
  }

  @Builder
  ChapterMenuBuilder() {
    ChapterListComponent({
      onSelect: (index: number) => {
        this.player.seekToChapter(index)
      }
    })
  }

  @Builder
  VideoSettingBuilder() {
    VideoSettingComponent({
      exitVideoTime: this.exitVideoTime,
      forward_80_s: (time: number) => {
        salmonLogger.addLog(TAG, `执行快进80秒操作，目标时间：${time}`, false)
        this.player.seekTime(time)
      },
      closeAfter15min: (time: number) => {
        this.exitVideo(time)
      },
      closeAfter30min: (time: number) => {
        this.exitVideo(time)
      },
      closeAfter60min: (time: number) => {
        this.exitVideo(time)
      },
      toggleListenVideo: () => {
        this.player.toggleListenVideo()
      },
      captureScreen: () => {
        if (this.player.surfaceId) {
          VideoOperateUtil.saveCaptureScreenToAlbum(this.player.surfaceId)
        }
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
      onSwitchPlayerEngine: (targetEngine: string) => {
        this.switchPlayerEngine(targetEngine, 'manual switch').catch(() => {
        })
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
      onSubtitleOffsetTime: (useMpvSubtitle: boolean) => {
        if (useMpvSubtitle) {
          this.subtitleManager.switchToInner()
        } else {
          this.subtitleManager.switchToExternal()
        }
        this.isAdjustingMpvSubtitleOffset = useMpvSubtitle
        this.subtitleOffsetShouldResumePlayback = this.player.playing
        if (this.subtitleOffsetShouldResumePlayback) {
          this.player.pause()
        }
        this.subtitleOffsetPreviewBase = SubtitleUtil.offsetMillis
        this.isAdjustingSubtitleOffset = true
        this.player.setSubtitleOffset(this.subtitleOffsetPreviewBase)
        this.subtitleTimestampInputDialog.open()
      },
      onSwitchPlayerEngine: (targetEngine: string) => {
        this.switchPlayerEngine(targetEngine, 'subtitle compatibility').catch(() => {
        })
      },
    })
  }

  @Builder
  AVCastPickerBuilderBridge() {
    AVCastPickerBuilder()
  }

  private async restoreAutomaticOrientation(): Promise<void> {
    try {
      await (await this.getWindowClass())?.setPreferredOrientation(window.Orientation.AUTO_ROTATION_RESTRICTED)
    } catch (error) {
      salmonLogger.addLog(TAG, `恢复自动旋转失败：${error}`, true)
    }
  }

  private bindEngineSwitchHandler(player: PlayerControllerInterface): void {
    player.setEngineSwitchHandler(async (targetEngine: string, reason: string,
      resumePlayback?: boolean): Promise<void> => {
      if (this.player !== player || this.isPageDisappearing) {
        return
      }
      await this.switchPlayerEngine(targetEngine, reason, resumePlayback)
    })
  }

  private async disposePlaybackSession(): Promise<void> {
    if (this.isPlaybackSessionDisposed) {
      return
    }
    if (this.playerDisposeTask) {
      await this.playerDisposeTask
      return
    }
    const task = this.performPlaybackSessionDispose()
    this.playerDisposeTask = task
    try {
      await task
      this.isPlaybackSessionDisposed = true
    } finally {
      if (this.playerDisposeTask === task) {
        this.playerDisposeTask = undefined
      }
    }
  }

  private async performPlaybackSessionDispose(): Promise<void> {
    if (this.engineSwitchTask) {
      try {
        await this.engineSwitchTask
      } catch (_error) {
      }
    }
    this.player.setEngineSwitchHandler(undefined)
    await this.player.dispose()
  }

  private async switchPlayerEngine(targetEngine: string, reason: string,
    resumePlayback?: boolean): Promise<void> {
    const currentEngine = this.player.isMpvPlayer() ? PlayerEngine.MPV_PLAYER : PlayerEngine.AV_PLAYER
    if (currentEngine === targetEngine || this.isPageDisappearing) {
      return
    }
    if (this.engineSwitchTask) {
      await this.engineSwitchTask
      return
    }
    const task = this.performEngineSwitch(targetEngine, reason, resumePlayback)
    this.engineSwitchTask = task
    try {
      await task
    } finally {
      if (this.engineSwitchTask === task) {
        this.engineSwitchTask = undefined
      }
    }
  }

  private async performEngineSwitch(targetEngine: string, reason: string,
    resumePlayback?: boolean): Promise<void> {
    const oldPlayer = this.player
    const subtitleMode = this.subtitleManager.subtitleMode
    const subtitle3DMode = this.subtitleManager.subtitle3DMode
    oldPlayer.saveSubtitlePreferenceForCurrentVideo(this.subtitleManager.subtitleVisibility,
      this.subtitleManager.isAIAsrShown, subtitle3DMode)
    try {
      await PiPWindowUtil.destroyPipController()
      await VideoOperateUtil.releaseFrameExtractor()
      const nextPlayer = await this.playbackSession.switchEngine(oldPlayer, targetEngine, resumePlayback)
      if (this.isPageDisappearing || this.player !== oldPlayer) {
        await nextPlayer.release()
        return
      }

      this.xComponentController = new XComponentController()
      this.osdXController = new XComponentController()
      this.playerType = targetEngine
      this.player = nextPlayer
      this.bindEngineSwitchHandler(nextPlayer)

      const nextSubtitleManager = new SubtitleManager(nextPlayer)
      nextSubtitleManager.subtitleMode = subtitleMode
      nextSubtitleManager.subtitle3DMode = subtitle3DMode
      nextPlayer.subtitleSelected = subtitleMode
      this.subtitleManager = nextSubtitleManager
      this.subtitlePreferenceRestored = true
      nextPlayer.onPlayerReady()
      if (this.containerWidth > 0 && this.containerHeight > 0) {
        nextPlayer.screenWidth = this.containerWidth
        nextPlayer.screenHeight = this.containerHeight
        nextPlayer.setRotation()
      }
      salmonLogger.addLog(TAG,
        `原地切换播放引擎完成: ${oldPlayer.isMpvPlayer() ? PlayerEngine.MPV_PLAYER : PlayerEngine.AV_PLAYER}` +
          ` -> ${targetEngine}, reason=${reason}`,
        false)
    } catch (error) {
      salmonLogger.addLog(TAG, `切换播放引擎失败: ${error}`, true)
      ToolsUtil.showToast('切换播放引擎失败')
      throw new Error(`切换播放引擎失败: ${error}`)
    }
  }

  private restoreSubtitlePreference() {
    if (this.subtitlePreferenceRestored) {
      return
    }
    const nowPlaying: VideoMetadata | undefined = this.player.nowPlaying
    if (nowPlaying && SubtitleUtil.hasSubtitlePreferenceMetadata(nowPlaying)) {
      if (nowPlaying.subtitle_3d_mode !== undefined &&
        [Subtitle3DMode.DISABLED, Subtitle3DMode.SIDE_BY_SIDE, Subtitle3DMode.TOP_AND_BOTTOM]
          .includes(nowPlaying.subtitle_3d_mode)) {
        this.subtitleManager.subtitle3DMode = nowPlaying.subtitle_3d_mode as Subtitle3DMode
      }
    }
    this.subtitlePreferenceRestored = true
    this.subtitleManager.syncMpvSubtitleVisibility()
  }

  private getWindowClass(): Promise<window.Window | undefined> {
    return this.player.getWindowClass() ?? this.windowClass
  }

  private exitVideo(timeOut: number) {
    salmonLogger.addLog(TAG, "开始设置退出视频定时器", false)
    this.exitVideoTime = setTimeout(async () => {
      salmonLogger.addLog(TAG, "退出视频定时器触发" + timeOut, false)
      await this.player.exitPlayback(timeOut)
      this.pathStack.pop()
    }, timeOut)
    salmonLogger.addLog(TAG, `退出视频定时器设置完成，超时时间：${timeOut}`, false)
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
    this.isAdjustingMpvSubtitleOffset = false
    this.resumePlaybackAfterSubtitleOffsetIfNeeded()
  }

  private cancelSubtitleOffsetSession(): void {
    if (!this.isAdjustingSubtitleOffset) {
      return
    }
    this.player.setSubtitleOffset(this.subtitleOffsetPreviewBase)
    this.finishSubtitleOffsetSession()
  }
}
