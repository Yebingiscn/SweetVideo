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
import NavigationAddress, { PlayerEngine, PlayerParams } from '../../common/NavigationCommon'
import { WindowUtil } from '../../utils/WindowUtil'
import { KeyCode } from '@kit.InputKit'
import { XAnimation } from '../../utils/AnimationUtil'
import { Subtitle3DMode } from '../../common/enum/SubtitleMode'
import { SubtitleManager } from '../../utils/SubtitleManager'
import { BrightnessSwipingBuilder } from '../../component/PlayerComponent/BrightnessSwipingBuilder'
import { FastForwardPanelBuilder } from '../../component/PlayerComponent/FastForwardPanelBuilder'
import { VolumeSwipingPanelBuilder } from '../../component/PlayerComponent/VolumeSwipingPanelBuilder'
import { SwipingPlayTimePanelBuilder } from '../../component/PlayerComponent/SwipingPlayTimePanelBuilder'
import { SubtitleDisplayBuilder } from '../../component/PlayerComponent/SubtitleDisplayBuilder'
import { Privacy, Setting } from '../../utils/ObservedUtil'
import { PlayerControllerFactory, PlayerControllerInterface } from '../../controller/PlayerControllerFactory'
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
import PrivacySpaceUtil from '../../utils/PrivacySpaceUtil'

const TAG = 'VideoPlayer'

type PlayerType = PlayerControllerInterface

@ComponentV2
export struct VideoPlayer {
  @Local playerType: string = PlayerEngine.AV_PLAYER
  @Provider('player') player: PlayerType = PlayerControllerFactory.createAVPlayerController() as PlayerType
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

        } else {
          ToolsUtil.showToast('输入错误，输入范围在50-150之间')
        }
      },
    }), cornerRadius: 20, shadow: DefaultDialogShadow
  })
  subtitleManager: SubtitleManager = new SubtitleManager(this.player)
  subtitleTimestampInputDialog: CustomDialogController = new CustomDialogController({
    builder: SubtitleOffsetDialog({
      getCurrentValue: (): number => SubtitleUtil.offsetMillis,
      onOffsetPreview: (offset: number): void => {
        this.player.refreshExternalSubtitlePreview(offset)
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
      confirm: (input: number): void => {
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
    cancel: (): void => {
      this.cancelSubtitleOffsetSession()
    }
  })
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
  private subtitleOffsetPreviewBase: number = 0
  private subtitleOffsetShouldResumePlayback: boolean = false

  async aboutToAppear(): Promise<void> {
    salmonLogger.addLog(this.pathStack?.getAllPathName()[0] ?? TAG, "开始执行aboutToAppear方法", false)
    this.player.prepareIfNeeded()
    PermissionUtil.applyContinuousTask()
    try {
      await (await this.getWindowClass())?.setPreferredOrientation(window.Orientation.AUTO_ROTATION_RESTRICTED)
      WindowUtil.setKeepScreenStatus(PathUtils.appContext!, true)
      this.player.repeatMode = Preferences.getRepeatModeState(PathUtils.appContext!)
      const videoSpeed = Preferences.getVideoSpeed(PathUtils.appContext!)
      this.player.speed = parseFloat(videoSpeed?.replace('x', '') || '1')
      this.player.selectedText = Preferences.getScreenExtend(PathUtils.appContext!)

      WindowUtil.setBarState(PathUtils.appContext!, false, false)
      if (Setting.defaultBrightness > 0) {
        VideoOperateUtil.setBrightness(Setting.defaultBrightness / 100)
      }

    } catch (error) {
      salmonLogger.addLog(this.pathStack?.getAllPathName()[0] ?? TAG, `播放错误 ${error}`, true)
    }
    this.player.onPlayerReady()
    salmonLogger.addLog(this.pathStack?.getAllPathName()[0] ?? TAG, "aboutToAppear方法执行完成", false)
  }

  async aboutToDisappear(): Promise<void> {
    salmonLogger.addLog(this.pathStack?.getAllPathName()[0] ?? TAG, "开始执行aboutToDisappear方法", false)
    VideoOperateUtil.setBrightness(-1)
    WindowUtil.recoveryBarColor()
    this.player.savePlayerSpeed(PathUtils.appContext!)
    Preferences.saveRepeatModeState(PathUtils.appContext!, this.player.repeatMode)
    this.player.onDisappearSaveSubtitlePreference(this.subtitleManager.subtitleVisibility,
      this.subtitleManager.isAIAsrShown, this.subtitleManager.subtitle3DMode)
    this.player.onDisappearCleanup()
    clearTimeout(this.exitVideoTime)
    await this.player.onDisappearRelease()
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
          onItemClick: async (item: VideoMetadata) => {
            this.player.playChooseVideo(item, this.pathStack, this.windowClass, this.xComponentController)
            this.player.setPlayerCallback(this.pathStack, this.xComponentController, this.windowClass)
            this.closeSideBar(true)
          }
        })

        Stack() {
          XComponents({
            xComponentController: this.xComponentController,
            xComponentId: this.player.getXComponentId(),
            libraryName: this.player.getLibraryName(),
            choosePlayer: this.player.isMpvPlayer() ? PlayerEngine.MPV_PLAYER : PlayerEngine.AV_PLAYER,
            barState: this.player.showControl,
            osdXController: this.player.isMpvPlayer() ? this.osdXController : undefined,
            osdVisibility: this.player.getOsdVisibility(),
            onXComponentLoad: async () => {
              await this.player.onSurfaceLoad(this.xComponentController, this.pathStack, this.windowClass)
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
            onOsdSurfaceLoad: (surfaceId: string) => {
              this.player.onOsdSurfaceLoad(surfaceId)
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
                ToolsUtil.startVibration()
                this.currentSpeedIndex = VideoInfoUtil.videoSpeedListAll.indexOf(Setting.longPressSpeed)
              }
            },
            onLongPressEnd: () => {
              XAnimation.runWithAnimation(() => {
                this.player.longPress = false
              })
              this.player.restoreSpeedAfterLongPress(VideoOperateUtil.lastSpeed)
            },
            onLongPressPanStart: (tapX: number) => {
              VideoOperateUtil.longPressStartX = tapX
              ToolsUtil.startVibration()
            },
            onLongPressPanUpdate: (tapX: number) => {
              if (this.player.longPress) {
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
                VideoOperateUtil.longPressStartX = tapX
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
            areaWidth: this.player.playAreaWidth,
            areaHeight: this.player.playAreaHeight,
            angle: this.player.angle,
            translateX: this.player.translateX,
            translateY: this.player.translateY,
            animDuration: this.player.playTime > 300 ? 300 : 0
          })

          AISubtitleComponent({
            isAIAsrShown: this.subtitleManager.isAIAsrShown,
            showControl: this.player.showControl,
            screenHeight: this.player.screenHeight,
          })
        }.onAreaChange(async (_oldValue: Area, newValue: Area) => {
          this.player.screenWidth = Math.floor(new Number(newValue.width).valueOf())
          this.player.screenHeight = Math.floor(new Number(newValue.height).valueOf())
          this.player.setRotation()

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
        if (this.playerType === PlayerEngine.MPV_PLAYER) {
          this.player = PlayerControllerFactory.createMpvController() as PlayerType
        } else {
          this.player = PlayerControllerFactory.createAVPlayerController() as PlayerType
        }

        this.subtitleManager = new SubtitleManager(this.player)
        const metadata = playerParams.metadata as VideoMetadata
        if (metadata && !PrivacySpaceUtil.getPrivacyMode()) {
          const findResult = Preferences.findVideoByDate(PathUtils.appContext!, metadata.date)
          this.player.nowPlaying = findResult[0] ?? metadata
        } else {
          this.player.nowPlaying = metadata
        }
        if (playerParams.metadata_list) {
          this.player.videoMetaDataList = playerParams.metadata_list as VideoMetadata[]
        } else if (playerParams!.folder_date) {
          const folders = Preferences.getFileFolder(PathUtils.appContext!)
          const folder = folders.find(f => f.date === playerParams!.folder_date)
          if (folder) {
            this.player.videoMetaDataList = folder.video_list
          }
        }
        this.player.skipHistory = playerParams.skipHistory
        this.restoreSubtitlePreference()
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
      WindowUtil.setKeepScreenStatus(PathUtils.appContext!, true)
    })
    .onWillDisappear(async () => {
      salmonLogger.addLog(this.pathStack?.getAllPathName()[0] ?? TAG, "开始执行onWillDisappear生命周期", false)
      this.player.saveSubtitlePreferenceForCurrentVideo(this.subtitleManager.subtitleVisibility,
        this.subtitleManager.isAIAsrShown, this.subtitleManager.subtitle3DMode)
      VideoOperateUtil.saveLastPlayVideoIndex(this.player.videoMetaDataList, this.player.nowPlaying?.date)
      if (this.player.videoMetaDataList.length > 0 && this.player.playTime > 0 && !this.player.skipHistory) {
        const nowPlaying = this.player.nowPlaying!
        const totalTime = nowPlaying.time ?? 0
        const lastPlay = nowPlaying.last_play ?? 0
        const isAlreadyWatched = totalTime > 0 && lastPlay >= totalTime * 0.95
        const isCurrentEarlier = this.player.playTime < lastPlay
        if (isAlreadyWatched && isCurrentEarlier) {
          salmonLogger.addLog(this.pathStack?.getAllPathName()[0] ?? TAG,
            `跳过保存: 视频已标记为已观看(last_play=${lastPlay}), 当前playTime=${this.player.playTime}更小`, false)
        } else {
          VideoOperateUtil.saveVideoTime(this.player.playTime, nowPlaying,
            PathUtils.appContext!)
          salmonLogger.addLog(this.pathStack?.getAllPathName()[0] ?? TAG, "保存视频播放时间完成", false)
        }
      }
      PermissionUtil.applyStopContinuousTask()
      PiPWindowUtil.destroyPipController()
      WindowUtil.disableLandscapeMultiWindow(this.getWindowClass())
      try {
        WindowUtil.setKeepScreenStatus(PathUtils.appContext!, false)
        await this.player.restoreSystemBars(this.windowClass)
        this.player.onWillDisappearCleanup()
        await (await this.getWindowClass())?.setPreferredOrientation(window.Orientation.AUTO_ROTATION_RESTRICTED)
        await this.player.avSession?.stopCasting()
        await this.player.onWillDisappearRelease(this.windowClass)
      } catch (error) {
        salmonLogger.addLog(this.pathStack?.getAllPathName()[0] ?? TAG, `onWillDisappear中发生错误：${error}`, true)
      }
      salmonLogger.addLog(this.pathStack?.getAllPathName()[0] ?? TAG, "onWillDisappear生命周期执行完成", false)
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
            await (await this.getWindowClass())?.setPreferredOrientation(orientation)
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
        this.player.isZoomed = false
        this.player.translateX = 0
        this.player.translateY = 0
      },
      onOriginalRatio: () => {
        this.player.resetAspectRatio()
        this.player.playAreaHeight = VideoInfoUtil.playAreaHeight
        this.player.playAreaWidth = VideoInfoUtil.playAreaWidth
        this.player.isZoomed = false
        this.player.translateX = 0
        this.player.translateY = 0
      },
      onStretchedToFullScreen: () => {
        this.player.stretchToFullScreen()
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
        VideoOperateUtil.fullScreenOrRotateScreen(this.player.screenWidth, this.player.screenHeight,
          this.getWindowClass())
      },
      onTogglePlaybackClick: () => {
        this.player.togglePlayback()
      },
      onPlayNextVideoClick: async () => {
        this.player.playNextVideoProcess(this.pathStack, this.windowClass, this.xComponentController)
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
        salmonLogger.addLog(this.pathStack?.getAllPathName()[0] ?? TAG, `执行快进80秒操作，目标时间：${time}`, false)
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
    salmonLogger.addLog(this.pathStack?.getAllPathName()[0] ?? TAG, "开始设置退出视频定时器", false)
    this.exitVideoTime = setTimeout(async () => {
      salmonLogger.addLog(this.pathStack?.getAllPathName()[0] ?? TAG, "退出视频定时器触发" + timeOut, false)
      await this.player.exitPlayback(timeOut)
      this.pathStack.pop()
    }, timeOut)
    salmonLogger.addLog(this.pathStack?.getAllPathName()[0] ?? TAG, `退出视频定时器设置完成，超时时间：${timeOut}`, false)
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
