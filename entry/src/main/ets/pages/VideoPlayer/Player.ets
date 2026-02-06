import { media } from '@kit.MediaKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import PermissionUtil from '../../utils/PermissionUtil'
import { window } from '@kit.ArkUI'
import AVSessionUtil from '../../utils/AVSessionUtil'
import ToolsUtil from '../../utils/ToolsUtil'
import VideoInfoUtil from '../../utils/VideoInfoUtil'
import { audio } from '@kit.AudioKit'
import VideoOperateUtil from '../../utils/VideoOperateUtil'
import RecentPlayUtil from '../../utils/RecentPlayUtil'
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import Preferences from '../../database/Preferences'
import PrivacySpaceUtil from '../../utils/PrivacySpaceUtil'
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
import { AVPlayerUtil } from '../../utils/AVPlayerUtil'
import { AVPlayerController } from '../../controller/AVPlayerController'
import { BrightnessSwipingBuilder } from '../../component/PlayerComponent/BrightnessSwipingBuilder'
import { FastForwardPanelBuilder } from '../../component/PlayerComponent/FastForwardPanelBuilder'
import { VolumeSwipingPanelBuilder } from '../../component/PlayerComponent/VolumeSwipingPanelBuilder'
import { SwipingPlayTimePanelBuilder } from '../../component/PlayerComponent/SwipingPlayTimePanelBuilder'
import { SubtitleDisplayBuilder } from '../../component/PlayerComponent/SubtitleDisplayBuilder'
import { SubtitlePanelComponent } from '../../component/PlayerComponent/SubtitlePanelComponent'
import { Privacy, SafeHeight, Setting } from '../../utils/ObservedUtil'
import { avSession } from '@kit.AVSessionKit'
import { PlayerControllerFactory } from '../../controller/PlayerControllerFactory'

@Component
export struct Player { // 播放页
  @Provide('player') player: AVPlayerController = PlayerControllerFactory.createAVPlayerController()
  @State longPress: boolean = false
  @State @Watch('setScreen') showControl: boolean = false
  @State lockRotation: boolean = false
  xComponentController: XComponentController = new XComponentController()
  windowClass = WindowUtil.getWindow()
  @State screenWidth: number = 0
  @State screenHeight: number = 0
  @State playAreaHeight: number = 0
  @State playAreaWidth: number = 0
  @State onSwiping: boolean = false
  @State onSwipingBrightness: boolean = false
  @State selectedText: string | undefined = '原始比例'
  @State audioTrackSelect: number = 0
  @State sideBarStatusTmp: Visibility = Visibility.Hidden
  @State sideBarStatus: boolean = false
  @State isLock: boolean = false
  @State lockVisibility: boolean = false
  @State isAIAsrShown: boolean = false
  @State isSliderPlayTimeChange: boolean = false
  @State currentSpeedIndex: number = 0
  @State angle: number = 0
  @State subtitleVisibility: Visibility = Visibility.Visible
  @State subtitle3DMode: Subtitle3DMode = Subtitle3DMode.DISABLED
  @State repeatMode: RepeatMode = RepeatMode.LIST
  @Consume('pathStack') pathStack: NavPathStack
  @State pixelMap: PixelMap | null = null
  @State exitVideoTime: number = 0
  @State abCircleStatus: boolean = false
  private autoHideTimeout: boolean = false

  async aboutToAppear(): Promise<void> {
    ToolsUtil.addLogger("开始执行aboutToAppear方法", false, this.pathStack)
    PermissionUtil.applyContinuousTask()
    ToolsUtil.addLogger("应用连续任务完成", false, this.pathStack)
    this.setScreen()
    try {
      await (await this.windowClass)?.setPreferredOrientation(window.Orientation.AUTO_ROTATION_RESTRICTED)
      WindowUtil.setKeepScreenStatus(PathUtils.appContext!, true)
      this.repeatMode = Preferences.getRepeatModeState(PathUtils.appContext!)
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
    Preferences.saveRepeatModeState(PathUtils.appContext!, this.repeatMode)
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

  async setRotation() {
    ToolsUtil.addLogger("开始执行setRotation方法", false, this.pathStack)
    if (!this.player.nowPlaying) {
      return
    }
    ToolsUtil.addLogger("开始计算播放区域尺寸", false, this.pathStack)
    const nowWidth = this.player.nowPlaying.size[0]
    const nowHeight = this.player.nowPlaying.size[1]
    const aspectRatioNow = nowWidth / nowHeight
    const screenAspectRatio = this.screenWidth / this.screenHeight
    if (aspectRatioNow > screenAspectRatio) {
      this.playAreaWidth = this.screenWidth
      this.playAreaHeight = this.playAreaWidth * (nowHeight / nowWidth)
    } else {
      this.playAreaHeight = this.screenHeight
      this.playAreaWidth = this.playAreaHeight * (nowWidth / nowHeight)
    }
    if (this.selectedText !== '原始比例') {
      this.selectedText = '原始比例'
    }
    VideoInfoUtil.saveOriginalVideoWidthAndHeight(this.playAreaWidth, this.playAreaHeight)
    ToolsUtil.addLogger("setRotation方法执行完成", false, this.pathStack)
  }

  async setAVPlayerCallback() {
    this.player.avPlayer?.on('timeUpdate', async (duration) => {
      if (!this.onSwiping) {
        this.player.playTime = duration
      }
      AppStorage.setOrCreate('nowPlayingData',
        [this.player.playTime, this.player.nowPlaying!, this.player.videoMetaDataList])
      if (this.showControl) {
        if (!this.autoHideTimeout) {
          this.autoHideTimeout = true
          setTimeout(() => {
            ToolsUtil.addLogger("自动隐藏控制界面", false, this.pathStack)
            this.lockVisibility = false
            this.showControl = false
            this.autoHideTimeout = false
          }, 12000)
        }
      }
      const endTime = this.player.nowPlaying?.end_time
      if (endTime != null && duration >= endTime && endTime > 0 && this.repeatMode !== RepeatMode.SINGLE) {
        ToolsUtil.addLogger(`检测到视频片尾，准备播放下一个视频，满足条件为: endTime: ${endTime}, repeatMode: ${this.repeatMode}, duration: ${duration}`,
          false, this.pathStack)
        this.playNextVideoProcess()
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
      AVSessionUtil.updatePlaybackSessionState(this.player.playing, this.player.playTime, this.repeatMode)
      ToolsUtil.addLogger("更新播放会话状态完成", false, this.pathStack)
      if (!this.player.playing) {
        ToolsUtil.addLogger("播放暂停状态，启动图像分析器", false, this.pathStack)
        this.startImageAnalyzer()
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
          if (this.repeatMode === RepeatMode.SINGLE) {
            ToolsUtil.addLogger("单曲循环模式，重新开始播放", false, this.pathStack)
            this.player.play()
            this.player.avPlayer?.seek(0, media.SeekMode.SEEK_CLOSEST)
          } else {
            ToolsUtil.addLogger("播放下一视频", false, this.pathStack)
            this.playNextVideoProcess()
          }
          break
        case 'playing':
          ToolsUtil.addLogger("进入playing状态", false, this.pathStack)
          this.player.playing = true
          this.initAVSession()
          ToolsUtil.addLogger("初始化AVSession完成", false, this.pathStack)
          AVSessionUtil.updatePlaybackSessionState(this.player.playing, this.player.playTime, this.repeatMode)
          ToolsUtil.addLogger("更新播放会话状态完成", false, this.pathStack)
          this.xComponentController.stopImageAnalyzer()
          ToolsUtil.addLogger("停止图像分析器完成", false, this.pathStack)
          break
        case 'paused':
          ToolsUtil.addLogger("进入paused状态", false, this.pathStack)
          this.player.playing = false
          AVSessionUtil.updatePlaybackSessionState(this.player.playing, this.player.playTime, this.repeatMode)
          ToolsUtil.addLogger("更新播放会话状态为暂停完成", false, this.pathStack)
          setTimeout(() => {
            ToolsUtil.addLogger("启动图像分析器", false, this.pathStack)
            this.startImageAnalyzer()
          }, 100)
          break
        case 'released':
          ToolsUtil.addLogger("进入released状态", false, this.pathStack)
          this.player.playing = false
          AVSessionUtil.updatePlaybackSessionState(this.player.playing, this.player.playTime, this.repeatMode)
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

  playNextVideoProcess() {
    ToolsUtil.addLogger("开始播放下一个视频流程", false, this.pathStack)
    const nextItem = this.player.playNextVideo(this.repeatMode)
    ToolsUtil.addLogger("获取下一个视频项完成", false, this.pathStack)
    if (nextItem) {
      ToolsUtil.addLogger("存在下一个视频，开始播放", false, this.pathStack)
      this.playChooseVideo(nextItem)
    } else {
      ToolsUtil.addLogger("无下一个视频，播放结束", false, this.pathStack)
      ToolsUtil.showToast('播放完毕，已自动退出')
      this.pathStack.pop()
    }
    ToolsUtil.addLogger("播放下一个视频前置流程完成", false, this.pathStack)
  }

  async getData() {
    ToolsUtil.addLogger("开始获取播放数据", false, this.pathStack)
    try {
      this.player.avPlayer = await AVPlayerUtil.getAVPlayer()
      ToolsUtil.addLogger("获取AVPlayer实例完成", false, this.pathStack)
      if (this.player.avPlayer) {
        this.setAVPlayerCallback()
        ToolsUtil.addLogger("设置AVPlayer回调完成", false, this.pathStack)
        try {
          await PermissionUtil.activatePermission(this.player.nowPlaying?.uri)
          ToolsUtil.addLogger("激活文件权限完成", false, this.pathStack)
          this.player.avPlayer.fdSrc = fs.openSync(this.player.nowPlaying?.uri)
          ToolsUtil.addLogger("设置播放器文件源完成", false, this.pathStack)
        } catch (error) {
          ToolsUtil.addLogger("打开视频文件失败：" + error, true, this.pathStack)
          ToolsUtil.showToast('视频打开失败，可能已失效：' + error)
          this.pathStack.pop()
        }
        await VideoOperateUtil.getFrameTimePreprocess(this.player.nowPlaying!.uri)
        this.setRotation()
        ToolsUtil.addLogger("计算播放区域尺寸完成", false, this.pathStack)
        if (this.windowClass) {
          this.playAreaWidth > this.playAreaHeight ? WindowUtil.enableLandscapeMultiWindow(this.windowClass) :
            WindowUtil.disableLandscapeMultiWindow(this.windowClass)
          ToolsUtil.addLogger("设置窗口多窗口模式完成", false, this.pathStack)
        }
        if (Setting.smartRotation && this.playAreaWidth > this.playAreaHeight &&
          this.screenHeight > this.screenWidth) {
          ToolsUtil.addLogger("智能旋转条件满足，开始设置方向", false, this.pathStack)
          const proportion =
            Math.max(this.screenWidth, this.screenHeight) / Math.min(this.screenWidth, this.screenHeight)
          const orientation = proportion > (16 / 10) ? window.Orientation.AUTO_ROTATION_LANDSCAPE
            : window.Orientation.AUTO_ROTATION_RESTRICTED;
          (await this.windowClass)?.setPreferredOrientation(orientation)?.catch(() => {
            ToolsUtil.addLogger("设置窗口方向失败", true, this.pathStack)
          })
          ToolsUtil.addLogger("设置窗口方向完成", false, this.pathStack)
        }
      }
    } catch (error) {
      const errorText = '视频加载失败。原因是：' + error
      ToolsUtil.showToast(errorText)
      ToolsUtil.addLogger(errorText, true, this.pathStack)
      this.pathStack.pop()
    }
    ToolsUtil.addLogger("获取播放数据完成", false, this.pathStack)
  }

  startImageAnalyzer() {
    ToolsUtil.addLogger("开始启动图像分析器", false, this.pathStack)
    this.xComponentController.startImageAnalyzer(VideoOperateUtil.config)?.catch(() => {
      ToolsUtil.addLogger(`启动图像分析器错误`, true, this.pathStack)
    })
    ToolsUtil.addLogger("启动图像分析器请求已发送", false, this.pathStack)
  }

  async playChooseVideo(item: VideoMetadata) {
    ToolsUtil.addLogger("开始播放选择的视频", false, this.pathStack)
    VideoOperateUtil.saveVideoTime(this.player.playTime, this.player.nowPlaying!, this.player.videoMetaDataList,
      PathUtils.appContext!)
    if (!PrivacySpaceUtil.getPrivacyMode()) {
      RecentPlayUtil.addPlayback(PathUtils.appContext!, item)
      ToolsUtil.addLogger("添加到最近播放记录完成", false, this.pathStack)
    }
    this.player.avPlayer?.off('subtitleUpdate')
    this.player.reset()
    ToolsUtil.addLogger("重置播放器完成", false, this.pathStack)
    ToolsUtil.addLogger("停止ijk播放器完成", false, this.pathStack)
    this.player.nowPlaying = item as VideoMetadata
    ToolsUtil.addLogger("设置当前播放视频完成", false, this.pathStack)
    this.getData()
    ToolsUtil.addLogger("获取播放数据完成", false, this.pathStack)
    this.initAVSession()
    ToolsUtil.addLogger("初始化AV会话完成", false, this.pathStack)
    ToolsUtil.addLogger("播放选择视频流程完成", false, this.pathStack)
  }

  async setSessionListener() {
    try {
      this.player.avSession?.on('play', () => {
        this.player.play()
      })
      this.player.avSession?.on('pause', () => {
        this.player.pause()
      })
      this.player.avSession?.on('seek', (position: number) => {
        this.player.seekTime(position)
      })
      this.player.avSession?.on('fastForward', () => {
        this.player.fastForward()
      })
      this.player.avSession?.on('rewind', () => {
        this.player.backForward()
      })
      this.player.avSession?.on('playNext', () => {
        this.playNextVideoProcess()
      })
      this.player.avSession?.on('outputDeviceChange', () => {
        this.player.pause()
      })
      this.player.avSession?.on('setLoopMode', (mode: avSession.LoopMode) => {
        this.repeatMode = AVSessionUtil.getRepeatModeFromAvSession(mode)
        this.repeatMode = VideoOperateUtil.getRepeatMode(this.repeatMode)
        AVSessionUtil.updatePlaybackSessionState(this.player.playing, this.player.playTime, this.repeatMode)
      })
    } catch (error) {
      ToolsUtil.addLogger('set avSession state error', true, this.pathStack)
    }
  }

  async initAVSession() {
    if (Setting.allowBackgroundPlay) {
      this.player.avSession = await AVSessionUtil.getAVSession()
      await this.setSessionListener()
      AVSessionUtil.setSessionInfo(this.player.nowPlaying!)
      AVSessionUtil.updatePlaybackSessionState(this.player.playing, this.player.playTime, this.repeatMode)
    }
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
            this.playChooseVideo(item)
            this.closeSideBar(true)
          }
        })

        Stack() {
          Stack() { //播放器
            XComponent({
              type: XComponentType.SURFACE,
              controller: this.xComponentController,
              imageAIOptions: VideoOperateUtil.options
            })
              .onLoad(() => {
                this.player.surfaceID = this.xComponentController.getXComponentSurfaceId()
                this.getData()
              })
              .focusable(true)
              .defaultFocus(true)
              .enableAnalyzer(true)
            SubtitleDisplayBuilder({
              subtitle: this.player.subtitle,
              screenWidth: this.screenWidth,
              screenHeight: this.screenHeight,
              showControl: this.showControl,
              subTitleVisibility: this.subtitleVisibility,
              subtitle3DMode: this.subtitle3DMode,
              playAreaWidth: this.playAreaWidth,
              playAreaHeight: this.playAreaHeight
            })
          }
          .onKeyEvent((event?: KeyEvent) => {
            if (!event || event.type !== KeyType.Down) {
              return
            }
            if (event.keyCode === KeyCode.KEYCODE_SPACE) {
              this.player.togglePlayback()
            }
            if (event.keyCode === KeyCode.KEYCODE_ESCAPE) {
              VideoOperateUtil.fullScreenOrRotateScreen(this.screenWidth, this.screenHeight, this.windowClass)
            }
            if (event.keyCode === KeyCode.KEYCODE_DPAD_RIGHT) {
              this.player.fastForward()
            }
            if (event.keyCode === KeyCode.KEYCODE_DPAD_LEFT) {
              this.player.backForward()
            }
            if (event.keyCode === KeyCode.KEYCODE_DPAD_UP || event.keyCode === KeyCode.KEYCODE_DPAD_DOWN) {
              this.player.volume = this.player.volumeActually
              const newVolume = VideoOperateUtil.changeVolume(this.player.volume,
                event.keyCode === KeyCode.KEYCODE_DPAD_UP ? 0.5 : -0.5)
              this.player.volume = newVolume
              this.player.volumeActually = newVolume
              VideoOperateUtil.lastVolume = newVolume
            }
          })
          .width(this.playAreaWidth)
          .height(this.playAreaHeight)
          .animation({ duration: this.player.playing ? 300 : 0, curve: Curve.Ease })
          .rotate({ y: 2, angle: this.angle, perspective: 200 })

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
                .transition(XAnimation.getAnimation('up', 0, false))
                .height(90)
                .backgroundColor('#36ffffff')
                .width('100%')
                .padding({
                  left: (this.screenHeight > this.screenWidth ? 20 : 35),
                  right: 20,
                  top: (this.showControl ? SafeHeight.topSafeHeight : 0),
                  bottom: 0
                })

                Stack() { //底栏
                  if (this.screenHeight / this.screenWidth > 1.4) {
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
                }.transition(XAnimation.getAnimation('bottom', 0, false))
                .backgroundColor($r('sys.color.mask_fourth'))
                .height(this.screenHeight > this.screenWidth ? 180 : 110)
                .width('100%')
              }.height('100%').width('100%')
            }
          }

          if (this.longPress) {
            FastForwardPanelBuilder({
              speed: this.player.speed,
              location: this.playAreaHeight,
            })
          }
          if (this.onSwiping) {
            SwipingPlayTimePanelBuilder({
              isSliderPlayTimeChange: this.isSliderPlayTimeChange,
              playTime: this.player.playTime,
              totalTime: this.player.nowPlaying!.time,
              pixelMap: this.pixelMap,
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
                this.player.togglePlayback()
                return
              }
              const zoneWidth = this.screenWidth / 5 // 屏幕五分之一宽度
              if (tapX < zoneWidth) { // 左侧1/5区域：回退
                this.player.backForward()
                return
              }
              if (tapX > zoneWidth * 4) { // 右侧1/5区域：快进
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
              VideoOperateUtil.leftSideSwipe = tapX < this.screenWidth / 2
              VideoOperateUtil.screenBrightnessTmp = this.player.screenBrightness
              this.player.volume = this.player.volumeActually
              VideoOperateUtil.lastVolume = this.player.volume // 记录起始音量
            },
            onVerticalPanUpdate: (offsetY: number) => {
              const deltaYScale = offsetY / this.screenHeight * 2.5
              if (VideoOperateUtil.leftSideSwipe) {
                this.onSwipingBrightness = true
                this.player.screenBrightness = VideoOperateUtil.calNewBrightness(deltaYScale)
                VideoOperateUtil.setBrightness(this.player.screenBrightness)
              } else {
                this.player.onSwipingVoice = true
                const newVolume = VideoOperateUtil.lastVolume - deltaYScale * 20
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
              this.pixelMap = null
              this.getFrameByTime(this.player.playTime, true)
            },
            onHorizonPanUpdate: (offsetX: number) => {
              const timePerPixel = VideoOperateUtil.getTimePixel(this.screenWidth, this.player.nowPlaying?.time!)
              this.player.playTime = Math.max(0,
                Math.min(VideoOperateUtil.lastPlayTime + (offsetX * timePerPixel), this.player.nowPlaying?.time!))
              this.getFrameByTime(this.player.playTime, false)
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
              y: this.screenWidth > this.screenHeight ? this.screenHeight / 2 - 40 : this.screenHeight / 2 - 100
            })
        }.onAreaChange(async (_oldValue: Area, newValue: Area) => {
          this.screenWidth = Math.floor(new Number(newValue.width).valueOf())
          this.screenHeight = Math.floor(new Number(newValue.height).valueOf())
          this.setRotation()
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
    .blur(Privacy.isPrivacyBackground ? 1000 : 0)
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

  async getFrameByTime(time: number, isFirstFrame: boolean) {
    if (Setting.showFrameImgStatus) {
      const isUpdating = !VideoOperateUtil.updatePix
      const shouldSkip = isUpdating && !isFirstFrame
      if (shouldSkip) {
        return // 非第一帧且正在更新时跳过，避免堆积
      }
      VideoOperateUtil.updatePix = false // 加锁
      try {
        const img = await VideoOperateUtil.fetchFrameByTime(time)
        if (img) {
          this.pixelMap = img
        }
      } catch (error) {
        ToolsUtil.addLogger('获取视频帧失败:' + error, true, this.pathStack)
        this.pixelMap = null
      } finally {
        VideoOperateUtil.updatePix = true // 确保解锁
      }
    }
  }

  @Builder
  VideoTop() {
    VideoTopComponent({
      videoTitle: this.player.nowPlaying?.title,
      subTitleVisibility: this.subtitleVisibility,
      subtitleSelected: this.player.subtitleSelected,
      isAIAsrShown: this.isAIAsrShown,
      screenExtendSelectedText: this.selectedText,
      screenWidth: this.screenWidth,
      screenHeight: this.screenHeight,
      audioTrackMenuBuilder: () => {
        this.AudioTrackMenuBuilderBridge()
      },
      subtitlePanelComponent: () => {
        this.SubtitleMenuBuilderBridge()
      },
      lockRotation: this.lockRotation,
      playAreaHeight: this.playAreaHeight,
      playAreaWidth: this.playAreaWidth,
      onExitVideoClick: () => {
        ToolsUtil.addLogger("点击退出视频按钮", false, this.pathStack)
        this.exitVideo(0)
      },
      onLockRotationClick: async () => {
        this.lockRotation = !this.lockRotation
        ToolsUtil.addLogger(`锁定旋转状态切换为：${this.lockRotation}`, false, this.pathStack)
        const orientation = this.lockRotation ?
          (this.screenWidth > this.screenHeight ? window.Orientation.AUTO_ROTATION_LANDSCAPE_RESTRICTED
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
        ToolsUtil.addLogger(`显示旋转锁定提示：${toastMessage}`, false, this.pathStack)
      }
    })
  }

  @Builder
  VideoSlider() {
    VideoSliderComponent({
      playTime: this.player.playTime,
      totalTime: this.player.nowPlaying?.time,
      screenWidth: this.screenWidth,
      screenHeight: this.screenHeight,
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
      screenHeight: this.screenHeight,
      screenWidth: this.screenWidth,
      playing: this.player.playing,
      speed: this.player.speed,
      AVCastPickerBuilderBridge: this.AVCastPickerBuilderBridge,
      videoSettingBuilder: () => {
        this.VideoSettingBuilderBridge()
      },
      playbackSpeedMenu: () => {
        this.PlaybackSpeedMenuBuilderBridge()
      },
      repeatMode: this.repeatMode,
      sideBarStatusTmp: this.sideBarStatusTmp,
      sideBarStatus: this.sideBarStatus,
      onScreenRotationOrFullScreenClick: async () => {
        VideoOperateUtil.fullScreenOrRotateScreen(this.screenWidth, this.screenHeight, this.windowClass)
      },
      onTogglePlaybackClick: () => {
        this.player.togglePlayback()
        ToolsUtil.addLogger("播放/暂停切换完成", false, this.pathStack)
      },
      onPlayNextVideoClick: () => {
        this.playNextVideoProcess()
        ToolsUtil.addLogger("播放下一个视频请求已发送", false, this.pathStack)
      },
      onSideBaClose: () => {
        this.closeSideBar(true)
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
      angle: this.angle,
      repeatMode: this.repeatMode,
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
      innerSubtitleData: []
    })
  }

  @Builder
  SubtitleMenuBuilderBridge() {
    this.SubtitleMenuBuilder()
  }

  @Builder
  PlaybackSpeedMenuBuilderBridge() {
    this.PlaybackSpeedMenuBuilder()
  }

  @Builder
  AudioTrackMenuBuilderBridge() {
    this.AudioTrackMenuBuilder()
  }

  @Builder
  VideoSettingBuilderBridge() {
    this.VideoSettingBuilder()
  }

  @Builder
  AVCastPickerBuilderBridge() { // 桥接AVCastPickerBuilder避免crash
    AVCastPickerBuilder()
  }
}