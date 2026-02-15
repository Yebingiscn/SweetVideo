import { media } from '@kit.MediaKit'
import PermissionUtil from '../../utils/PermissionUtil'
import { window } from '@kit.ArkUI'
import AVSessionUtil from '../../utils/AVSessionUtil'
import ToolsUtil from '../../utils/ToolsUtil'
import VideoInfoUtil from '../../utils/VideoInfoUtil'
import { audio } from '@kit.AudioKit'
import VideoOperateUtil from '../../utils/VideoOperateUtil'
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import Preferences from '../../database/Preferences'
import { PathUtils } from '../../utils/PathUtils'
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
import { RepeatMode } from '../../common/enum/RepeatMode'
import NavigationAddress, { PlayerParams } from '../../common/NavigationCommon'
import { WindowUtil } from '../../utils/WindowUtil'
import { KeyCode } from '@kit.InputKit'
import { XAnimation } from '../../utils/AnimationUtil'
import { AIAsr } from '../../component/PlayerComponent/AIAsrComponent'
import SubtitleUtil from '../../utils/SubtitleUtil'
import { Subtitle3DMode, SubtitleMode } from '../../common/enum/SubtitleMode'
import { AVPlayerController } from '../../controller/AVPlayerController'
import { BrightnessSwipingBuilder } from '../../component/PlayerComponent/BrightnessSwipingBuilder'
import { FastForwardPanelBuilder } from '../../component/PlayerComponent/FastForwardPanelBuilder'
import { VolumeSwipingPanelBuilder } from '../../component/PlayerComponent/VolumeSwipingPanelBuilder'
import { SwipingPlayTimePanelBuilder } from '../../component/PlayerComponent/SwipingPlayTimePanelBuilder'
import { SubtitlePanelComponent } from '../../component/PlayerComponent/SubtitlePanelComponent'
import { Privacy, Setting } from '../../utils/ObservedUtil'
import { PlayerControllerFactory } from '../../controller/PlayerControllerFactory'
import { MpvController } from '../../controller/MpvController/MpvController'
import { XComponents } from '../../component/PlayerComponent/XComponents'
import { VideoLayoutComponent } from '../../component/PlayerComponent/VideoLayoutComponent'
import {
  AUTO_HIDE_SHOW_CONTROL_TIME,
  DEFAULT_ANGLE,
  LEFT_ZONE_DIVISION,
  MAX_SCALE_FACTOR,
  MAX_WIDTH_MULTIPLIER,
  MIN_SCALE_FACTOR,
  MIN_WIDTH_MULTIPLIER,
  MIRRORED_ANGLE,
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
export struct Player { // 播放页
  @Provide('player') player: AVPlayerController = PlayerControllerFactory.createAVPlayerController()
  @Provide('MpvPlayer') mpv: MpvController = PlayerControllerFactory.createMpvController()
  @State longPress: boolean = false
  @State @Watch('setScreen') showControl: boolean = false
  @State lockRotation: boolean = false
  xComponentController: XComponentController = new XComponentController()
  windowClass = WindowUtil.getWindow()
  @State onSwiping: boolean = false
  @State onSwipingBrightness: boolean = false
  @State audioTrackSelect: number = 0
  @State sideBarStatusTmp: Visibility = Visibility.Hidden
  @State sideBarStatus: boolean = false
  @State isLock: boolean = false
  @State lockVisibility: boolean = false
  @State isAIAsrShown: boolean = false
  @State isSliderPlayTimeChange: boolean = false
  @State currentSpeedIndex: number = 0
  @State subtitleVisibility: Visibility = Visibility.Visible
  @State subtitle3DMode: Subtitle3DMode = Subtitle3DMode.DISABLED
  @Consume('pathStack') pathStack: NavPathStack
  @State exitVideoTime: number = 0
  @State abCircleStatus: boolean = false

  async aboutToAppear(): Promise<void> {
    ToolsUtil.addLogger("开始执行aboutToAppear方法", false, this.pathStack)
    PermissionUtil.applyContinuousTask()
    this.setScreen()
    try {
      await (await this.windowClass)?.setPreferredOrientation(window.Orientation.AUTO_ROTATION_RESTRICTED)
      WindowUtil.setKeepScreenStatus(PathUtils.appContext!, true)
      this.player.repeatMode = Preferences.getRepeatModeState(PathUtils.appContext!)
      const videoSpeed = Preferences.getVideoSpeed(PathUtils.appContext!)
      this.player.speed = parseFloat(videoSpeed?.replace('x', '') || '1')
      ToolsUtil.addLogger("设置播放器速度完成", false, this.pathStack)
    } catch (error) {
      ToolsUtil.addLogger(`播放错误 ${error}`, true, this.pathStack)
    }
    ToolsUtil.addLogger("aboutToAppear方法执行完成", false, this.pathStack)
  }

  async aboutToDisappear(): Promise<void> {
    ToolsUtil.addLogger("开始执行aboutToDisappear方法", false, this.pathStack)
    VideoOperateUtil.setBrightness(-1)
    Preferences.saveVideoSpeed(PathUtils.appContext!,
      (VideoInfoUtil.getVideoSpeedList(NavigationAddress.AV_PLAYER).includes(this.player.speed) ? this.player.speed :
        1) + 'x')
    Preferences.saveRepeatModeState(PathUtils.appContext!, this.player.repeatMode)
    WindowUtil.setBarState(PathUtils.appContext!, true, true)
    clearTimeout(this.exitVideoTime)
    this.player.cancelSubscribe()
    AppStorage.delete('nowPlayingData')
    try {
      this.player.audioVolumeManager?.off('volumeChange')
      ToolsUtil.addLogger("取消音量变化监听完成", false, this.pathStack)
    } catch (error) {
      ToolsUtil.addLogger(`音量监听取消错误 ${error}`, true, this.pathStack)
    }
    this.player.audioVolumeManager = null
    this.player.release()
    ToolsUtil.addLogger("释放播放器资源完成", false, this.pathStack)
    VideoOperateUtil.avImageGenerator?.release()?.catch(() => {
    })
    ToolsUtil.addLogger("aboutToDisappear方法执行完成", false, this.pathStack)
  }

  setAVPlayerCallback() {
    this.player.avPlayer?.on('timeUpdate', (duration) => {
      if (!this.onSwiping) {
        this.player.playTime = duration
      }
      AppStorage.setOrCreate('nowPlayingData',
        [this.player.playTime, this.player.nowPlaying!, this.player.videoMetaDataList])
      if (this.showControl) {
        if (!VideoOperateUtil.autoHideTimeout) {
          VideoOperateUtil.autoHideTimeout = true
          setTimeout(() => {
            this.lockVisibility = false
            this.showControl = false
            VideoOperateUtil.autoHideTimeout = false
          }, AUTO_HIDE_SHOW_CONTROL_TIME)
        }
      }
      const endTime = this.player.nowPlaying?.end_time
      if (endTime != null && duration >= endTime && endTime > 0 && this.player.repeatMode !== RepeatMode.SINGLE) {
        ToolsUtil.addLogger(`检测到视频片尾，准备播放下一个视频，满足条件为: endTime: ${endTime}, repeatMode: ${this.player.repeatMode}, duration: ${duration}`,
          false, this.pathStack)
        this.player.playNextVideoProcess(this.pathStack, this.windowClass)
        this.setAVPlayerCallback()
        ToolsUtil.showToast('已智能跳过片尾')
      }
      if (this.player.subtitleSelected === SubtitleMode.EXTERNAL_SUBTITLE) {
        this.player.subtitle = SubtitleUtil.getSubtitlesAtTime(duration)
      }
      if (this.abCircleStatus && this.player.playing) {
        if (this.player.nowPlaying?.pointA !== undefined && this.player.nowPlaying?.pointB !== undefined) {
          const pointA = this.player.nowPlaying.pointA
          const pointB = this.player.nowPlaying.pointB
          const playTime = this.player.playTime
          if (playTime < pointA || playTime > pointB) {
            this.player.seekTime(pointA)
          }
        }
      }
    })

    this.player.avPlayer?.on('seekDone', (percent) => {
      ToolsUtil.addLogger("播放器跳转完成", false, this.pathStack)
      this.player.playTime = percent
      AVSessionUtil.updatePlaybackSessionState(this.player.playing, this.player.playTime, this.player.repeatMode)
      if (!this.player.playing) {
        this.player.startImageAnalyzer(this.xComponentController)
      }
    })

    this.player.avPlayer?.on('speedDone', (systemEnum: media.PlaybackSpeed) => {
      const actualSpeed = VideoInfoUtil.mapFromSystemSpeed(systemEnum)
      this.player.speed = actualSpeed
    })

    this.player.avPlayer?.on('audioOutputDeviceChangeWithInfo', (data: audio.AudioStreamDeviceChangeInfo) => {
      if (data.changeReason === audio.AudioStreamDeviceChangeReason.REASON_OLD_DEVICE_UNAVAILABLE) {
        this.player.pause()
      }
    })

    this.player.avPlayer?.on('stateChange', async (state) => {
      ToolsUtil.addLogger(`播放器状态变更: ${state}`, false, this.pathStack)
      switch (state) {
        case 'initialized':
          ToolsUtil.addLogger("进入initialized状态", false, this.pathStack)
          if (this.player.avPlayer) {
            this.player.avPlayer.surfaceId = this.player.surfaceID
            this.player.avPlayer.setPlaybackStrategy({
              showFirstFrameOnPrepare: true
            })?.catch(() => {
              ToolsUtil.addLogger("设置播放策略失败", true, this.pathStack)
            })
            await this.player.setExternalSubtitle(this.player.nowPlaying!)
            this.player.prepare()
          }
          break
        case 'prepared':
          ToolsUtil.addLogger("进入prepared状态", false, this.pathStack)
          this.player.videoStartPlayTime(VideoOperateUtil.getVideoStartPlayTimeMode(this.player.nowPlaying!))
          ToolsUtil.addLogger("设置视频开始播放时间完成", false, this.pathStack)
          this.player.play()
          ToolsUtil.addLogger("开始播放视频", false, this.pathStack)
          await this.player.getAudioTrackList()
          ToolsUtil.addLogger("获取音频轨道完成", false, this.pathStack)
          await this.player.initVolumeAndBrightness()
          this.player.updatePlaybackSpeed(this.player.speed)
          ToolsUtil.addLogger("更新播放速度完成", false, this.pathStack)
          this.showControl = false
          this.lockVisibility = false
          this.isSliderPlayTimeChange = false
          this.onSwiping = false
          ToolsUtil.addLogger("界面控制状态重置完成", false, this.pathStack)
          break
        case 'completed':
          ToolsUtil.addLogger("进入completed状态", false, this.pathStack)
          VideoOperateUtil.saveVideoTime(this.player.playTime, this.player.nowPlaying!, this.player.videoMetaDataList,
            PathUtils.appContext!)
          ToolsUtil.addLogger("保存视频播放时间完成", false, this.pathStack)
          const targetItem = this.player.videoMetaDataList.find(i => i.date == this.player.nowPlaying?.date)
          if (targetItem) {
            targetItem!.last_play = this.player.playTime
            ToolsUtil.addLogger("更新当前视频最后播放时间完成", false, this.pathStack)
          }
          if (this.player.repeatMode === RepeatMode.SINGLE) {
            ToolsUtil.addLogger("单曲循环模式，重新开始播放", false, this.pathStack)
            this.player.play()
            this.player.avPlayer?.seek(0, media.SeekMode.SEEK_CLOSEST)
          } else {
            ToolsUtil.addLogger("播放下一视频", false, this.pathStack)
            this.player.playNextVideoProcess(this.pathStack, this.windowClass)
            this.setAVPlayerCallback()
          }
          break
        case 'playing':
          ToolsUtil.addLogger("进入playing状态", false, this.pathStack)
          this.player.playing = true
          this.player.initAVSession()
          ToolsUtil.addLogger("初始化AVSession完成", false, this.pathStack)
          AVSessionUtil.updatePlaybackSessionState(this.player.playing, this.player.playTime, this.player.repeatMode)
          ToolsUtil.addLogger("更新播放会话状态完成", false, this.pathStack)
          this.xComponentController.stopImageAnalyzer()
          ToolsUtil.addLogger("停止图像分析器完成", false, this.pathStack)
          break
        case 'paused':
          ToolsUtil.addLogger("进入paused状态", false, this.pathStack)
          this.player.playing = false
          AVSessionUtil.updatePlaybackSessionState(this.player.playing, this.player.playTime, this.player.repeatMode)
          ToolsUtil.addLogger("更新播放会话状态为暂停完成", false, this.pathStack)
          setTimeout(() => {
            this.player.startImageAnalyzer(this.xComponentController)
          }, 100)
          break
        case 'released':
          ToolsUtil.addLogger("进入released状态", false, this.pathStack)
          this.player.playing = false
          AVSessionUtil.updatePlaybackSessionState(this.player.playing, this.player.playTime, this.player.repeatMode)
          ToolsUtil.addLogger("更新播放会话状态为释放完成", false, this.pathStack)
          break
        case 'idle':
          ToolsUtil.addLogger("进入idle状态", false, this.pathStack)
          this.player.release()
          ToolsUtil.addLogger("释放播放器资源完成", false, this.pathStack)
          break
        case 'error':
          ToolsUtil.addLogger("进入error状态", false, this.pathStack)
          VideoOperateUtil.playErrorExecute(this.pathStack, this.player.videoMetaDataList,
            this.player.nowPlaying?.date!,
            NavigationAddress.MPV_PLAYER)
          ToolsUtil.addLogger("执行播放错误处理完成", false, this.pathStack)
          this.player.release()
          ToolsUtil.addLogger("释放播放器资源完成", false, this.pathStack)
          break
      }
    })
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

  build() {
    NavDestination() {
      SideBarContainer(SideBarContainerType.Overlay) {
        PlayerSideBarComponent({
          sideBarStatusTmp: this.sideBarStatusTmp,
          videoMetadata: this.player.videoMetaDataList,
          nowPlaying: this.player.nowPlaying,
          sideBarStatus: this.sideBarStatus,
          onItemClick: (item: VideoMetadata) => {
            this.player.playChooseVideo(item, this.pathStack, this.windowClass)
            this.setAVPlayerCallback()
            this.closeSideBar(true)
          }
        })

        Stack() {
          XComponents({
            xComponentController: this.xComponentController,
            playAreaWidth: this.player.playAreaWidth,
            playAreaHeight: this.player.playAreaHeight,
            playTime: this.player.playTime,
            subtitle: this.player.subtitle,
            screenHeight: this.player.screenHeight,
            screenWidth: this.player.screenWidth,
            choosePlayer: NavigationAddress.AV_PLAYER,
            angle: this.player.angle,
            showControl: this.showControl,
            subtitleVisibility: this.subtitleVisibility,
            subtitle3DMode: this.subtitle3DMode,
            onXComponentLoad: async () => {
              this.player.surfaceID = this.xComponentController.getXComponentSurfaceId()
              await this.player.getData(this.pathStack, this.windowClass)
              this.setAVPlayerCallback()
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

          if (this.showControl && !this.isLock) {
            VideoLayoutComponent({
              screenHeight: this.player.screenHeight,
              screenWidth: this.player.screenWidth,
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
              speed: this.player.speed,
              location: this.player.playAreaHeight,
            })
          }
          if (this.onSwiping) {
            SwipingPlayTimePanelBuilder({
              isSliderPlayTimeChange: this.isSliderPlayTimeChange,
              playTime: this.player.playTime,
              totalTime: this.player.nowPlaying!.time,
              pixelMap: this.player.pixelMap,
              player: NavigationAddress.AV_PLAYER
            })
          }

          VolumeSwipingPanelBuilder({
            videoVolume: this.player.volume,
            videoVolumeShow: this.player.volumeActually,
            onSwipingVoice: this.player.onSwipingVoice
          })

          if (this.onSwipingBrightness) {
            BrightnessSwipingBuilder({ screenBrightness: this.player.screenBrightness })
          }
          if (this.lockVisibility) {
            LockVideoBarComponent({
              isLock: this.isLock,
              screenHeight: this.player.screenHeight,
              screenWidth: this.player.screenWidth,
              showControl: this.showControl,
            })
          }
          GestureComponent({
            showControl: this.showControl,
            isLock: this.isLock,
            onDoubleClickAction: (tapX: number) => {
              if (!Setting.allowDoubleFastForward) { // 非双击快进模式时执行暂停
                this.player.togglePlayback()
                return
              }
              const zoneWidth = this.player.screenWidth / SCREEN_DIVISIONS
              if (tapX < zoneWidth * LEFT_ZONE_DIVISION) {
                this.player.backForward()
                return
              }
              if (tapX > zoneWidth * RIGHT_ZONE_DIVISION) {
                this.player.fastForward()
                return
              }
              this.player.togglePlayback()
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
              VideoOperateUtil.leftSideSwipe = tapX < this.player.screenWidth / SCREEN_HALF_DIVIDER
              VideoOperateUtil.screenBrightnessTmp = this.player.screenBrightness
              this.player.volume = this.player.volumeActually
              VideoOperateUtil.lastVolume = this.player.volume // 记录起始音量
            },
            onVerticalPanUpdate: (offsetY: number) => {
              const deltaYScale = offsetY / this.player.screenHeight * VERTICAL_PAN_SENSITIVITY
              if (VideoOperateUtil.leftSideSwipe) {
                this.onSwipingBrightness = true
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
              this.onSwiping = false
              this.player.onSwipingVoice = false
              this.onSwipingBrightness = false
            },
            onHorizonPanStart: () => {
              VideoOperateUtil.lastPlayTime = this.player.playTime
              this.onSwiping = true
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
              this.onSwiping = false
            },
            onPinchStart: (fingerDistance: number) => {
              VideoOperateUtil.initPinchDistance = fingerDistance
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
              XAnimation.runWithAnimation(() => {
                this.player.playAreaWidth = this.player.playAreaWidth
                this.player.playAreaHeight = this.player.playAreaHeight
              })
            },
            onLongPressAction: () => {
              if (this.player.playing) {
                this.longPress = true
                VideoOperateUtil.lastSpeed = this.player.speed
                this.player.updatePlaybackSpeed(Setting.longPressSpeed)
                this.currentSpeedIndex =
                  VideoInfoUtil.getVideoSpeedList(NavigationAddress.AV_PLAYER).indexOf(Setting.longPressSpeed)
              }
            },
            onLongPressEnd: () => {
              this.longPress = false
              this.player.updatePlaybackSpeed(VideoOperateUtil.lastSpeed)
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
                this.player.updatePlaybackSpeed(VideoInfoUtil.getVideoSpeedList(NavigationAddress.AV_PLAYER)[this.currentSpeedIndex])
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
              y: this.player.screenWidth > this.player.screenHeight ? this.player.screenHeight / 2 - 40 :
                this.player.screenHeight / 2 - 100
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
    .onHidden(() => {
      this.player.isListenVideo = true
      this.player.setListenVideoStatus()
    })
    .onShown(() => {
      this.player.isListenVideo = false
      this.player.setListenVideoStatus()
    })
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
      if (this.showControl && !Setting.allowPlayBackExist) {
        this.showControl = false
        this.lockVisibility = false
        return true
      } else {
        this.player.release()
        ToolsUtil.addLogger("播放器资源已释放", false, this.pathStack)
        VideoOperateUtil.saveLastPlayVideoIndex(this.player.videoMetaDataList, this.player.nowPlaying?.date)
        ToolsUtil.addLogger("更新最后播放视频索引完成", false, this.pathStack)
        return false
      }
    })
    .onWillDisappear(async () => {
      ToolsUtil.addLogger("开始执行onWillDisappear生命周期", false, this.pathStack)
      if (this.player.videoMetaDataList.length > 0 && this.player.playTime > 0) {
        VideoOperateUtil.saveVideoTime(this.player.playTime, this.player.nowPlaying!, this.player.videoMetaDataList,
          PathUtils.appContext!)
        ToolsUtil.addLogger("保存视频播放时间完成", false, this.pathStack)
      }
      PermissionUtil.applyStopContinuousTask()
      try {
        WindowUtil.setKeepScreenStatus(PathUtils.appContext!, false)
        if (canIUse('SystemCapability.Window.SessionManager')) {
          await (await this.windowClass)?.setSpecificSystemBarEnabled('status', true)
          await (await this.windowClass)?.setSpecificSystemBarEnabled('navigationIndicator', true)
          ToolsUtil.addLogger("恢复系统栏显示完成", false, this.pathStack)
        }
        await (await this.windowClass)?.setPreferredOrientation(window.Orientation.AUTO_ROTATION_RESTRICTED)
        await this.player.avSession?.stopCasting()
        await VideoOperateUtil.releaseAVImageGenerator()
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
      VideoOperateUtil.saveLastPlayVideoIndex(this.player.videoMetaDataList, this.player.nowPlaying?.date)
      ToolsUtil.addLogger("更新最后播放视频索引完成", false, this.pathStack)
      this.pathStack.pop()
    }, timeOut)
    ToolsUtil.addLogger(`退出视频定时器设置完成，超时时间：${timeOut}`, false, this.pathStack)
  }

  @Builder
  VideoTop() {
    VideoTopComponent({
      videoTitle: this.player.nowPlaying?.title,
      subTitleVisibility: this.subtitleVisibility,
      subtitleSelected: this.player.subtitleSelected,
      isAIAsrShown: this.isAIAsrShown,
      screenExtendSelectedText: this.player.selectedText,
      screenWidth: this.player.screenWidth,
      screenHeight: this.player.screenHeight,
      audioTrackMenuBuilder: () => {
        this.AudioTrackMenuBuilder()
      },
      subtitlePanelComponent: () => {
        this.SubtitleMenuBuilder()
      },
      lockRotation: this.lockRotation,
      playAreaHeight: this.player.playAreaHeight,
      playAreaWidth: this.player.playAreaWidth,
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
      },
      onOriginalRatio: () => {
        this.player.playAreaHeight = VideoInfoUtil.playAreaHeight
        this.player.playAreaWidth = VideoInfoUtil.playAreaWidth
      },
      onStretchedToFullScreen: () => {
        this.player.playAreaHeight = this.player.screenHeight
        this.player.playAreaWidth = this.player.screenWidth
      },
      onFullScreenByWidth: () => {
        this.player.playAreaWidth = this.player.screenWidth
        this.player.playAreaHeight =
          (VideoInfoUtil.playAreaHeight / VideoInfoUtil.playAreaWidth) * this.player.screenWidth
      },
      onFullScreenByHeight: () => {
        this.player.playAreaHeight = this.player.screenHeight
        this.player.playAreaWidth =
          (VideoInfoUtil.playAreaWidth / VideoInfoUtil.playAreaHeight) * this.player.screenHeight
      },
      onUniformScale: (scale: number) => {
        this.player.playAreaHeight = scale * VideoInfoUtil.playAreaHeight
        this.player.playAreaWidth = scale * VideoInfoUtil.playAreaWidth
      },
      onSelectedTextChange: (text: string) => {
        this.player.selectedText = text
      },
    })
  }

  @Builder
  VideoSlider() {
    VideoSliderComponent({
      playTime: this.player.playTime,
      totalTime: this.player.nowPlaying?.time,
      screenWidth: this.player.screenWidth,
      screenHeight: this.player.screenHeight,
      playSpeed: this.player.speed,
      onSliderChange: (value: number) => {
        this.onSwiping = true
        this.isSliderPlayTimeChange = true
        this.player.playTime = value
      },
      onSliderTouch: (event: TouchEvent) => {
        if (event.type == TouchType.Up) {
          this.player.seekTime(this.player.playTime)
          this.isSliderPlayTimeChange = false
          this.onSwiping = false
        }
      }
    })
  }

  @Builder
  VideoButtons() {
    VideoButtonsComponent({
      screenHeight: this.player.screenHeight,
      screenWidth: this.player.screenWidth,
      playing: this.player.playing,
      speed: this.player.speed,
      AVCastPickerBuilderBridge: this.AVCastPickerBuilderBridge,
      videoSettingBuilder: () => {
        this.VideoSettingBuilder()
      },
      playbackSpeedMenu: () => {
        this.PlaybackSpeedMenuBuilder()
      },
      repeatMode: this.player.repeatMode,
      sideBarStatusTmp: this.sideBarStatusTmp,
      sideBarStatus: this.sideBarStatus,
      onScreenRotationOrFullScreenClick: async () => {
        VideoOperateUtil.fullScreenOrRotateScreen(this.player.screenWidth, this.player.screenHeight, this.windowClass)
      },
      onTogglePlaybackClick: () => {
        this.player.togglePlayback()
        ToolsUtil.addLogger("播放/暂停切换完成", false, this.pathStack)
      },
      onPlayNextVideoClick: () => {
        this.player.playNextVideoProcess(this.pathStack, this.windowClass)
        this.setAVPlayerCallback()
        ToolsUtil.addLogger("播放下一个视频请求已发送", false, this.pathStack)
      },
      onSideBaClose: () => {
        this.closeSideBar(true)
      },
      onChangeRepeatMode: (repeatMode: RepeatMode) => {
        this.player.repeatMode = repeatMode
      }
    })
  }

  @Builder
  AudioTrackMenuBuilder() {
    AudioTrackComponent({
      audioTrack: this.player.audioTrack,
      audioTrackSelected: this.audioTrackSelect,
      onSelect: (index: number) => {
        ToolsUtil.addLogger(`选择音频轨道，索引：${index}`, false, this.pathStack)
        this.player?.selectAudioTrack(this.player?.audioTrack[index]?.index)
        this.audioTrackSelect = index
      }
    })
  }

  @Builder
  VideoSettingBuilder() {
    VideoSettingComponent({
      playTime: this.player.playTime,
      nowPlaying: this.player.nowPlaying,
      videoMetaData: this.player.videoMetaDataList,
      exitVideoTime: this.exitVideoTime,
      abCircleStatus: this.abCircleStatus,
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
        this.player.repeatMode = RepeatMode.ONCE
      },
    })
  }

  @Builder
  PlaybackSpeedMenuBuilder() {
    PlaybackSpeedMenuComponent({
      speed: this.player.speed,
      player: NavigationAddress.AV_PLAYER,
      onSpeedChange: (speed: number) => {
        this.player.updatePlaybackSpeed(speed)
      }
    })
  }

  @Builder
  SubtitleMenuBuilder() {
    SubtitlePanelComponent({
      subTitleVisibility: this.subtitleVisibility,
      isAIAsrShown: this.isAIAsrShown,
      subtitle3DMode: this.subtitle3DMode,
      subtitleSelected: this.player.subtitleSelected,
      innerSubtitleData: [],
      mpv: this.mpv
    })
  }

  @Builder
  AVCastPickerBuilderBridge() { // 桥接AVCastPickerBuilder避免crash
    AVCastPickerBuilder()
  }
}