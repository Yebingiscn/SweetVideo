import { media } from '@kit.MediaKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import PermissionUtil from '../../utils/PermissionUtil';
import { window } from '@kit.ArkUI';
import AVSessionUtil from '../../utils/AVSessionUtil';
import ToolsUtil from '../../utils/ToolsUtil';
import VideoInfoUtil from '../../utils/VideoInfoUtil';
import { audio } from '@kit.AudioKit';
import VideoOperateUtil from '../../utils/VideoOperateUtil';
import RecentPlayUtil from '../../utils/RecentPlayUtil';
import { VideoMetadataFromPlayer } from '../../interfaces/VideoMetadataFromPlayerInterface';
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface';
import Preferences from '../../database/Preferences';
import PrivacySpaceUtil from '../../utils/PrivacySpaceUtil';
import { PathUtils } from '../../utils/PathUtils';
import { PlayerSideBarComponent } from '../../component/PlayerComponent/PlayerSideBarComponent';
import { AVCastPickerBuilder } from '../../component/PlayerComponent/AVCastPickerBuilder';
import { AudioTrackComponent } from '../../component/PlayerComponent/AudioTrackComponent';
import { PlaybackSpeedMenuComponent } from '../../component/PlayerComponent/PlaybackSpeedComponent';
import { LockVideoBarComponent } from '../../component/PlayerComponent/LockVideoBarComponent';
import { VideoSliderComponent } from '../../component/PlayerComponent/VideoSliderComponent';
import { GestureComponent } from '../../component/PlayerComponent/GestureComponent';
import { VideoTopComponent } from '../../component/PlayerComponent/VideoTopComponent';
import { VideoButtonsComponent } from '../../component/PlayerComponent/VideoButtonsComponent';
import { VideoSettingComponent } from '../../component/PlayerComponent/VideoSettingComponent';
import { RepeatMode } from '../../common/enum/RepeatMode';
import NavigationAddress, { PlayerParams } from '../../common/NavigationCommon';
import { WindowUtil } from '../../utils/WindowUtil';
import { KeyCode } from '@kit.InputKit';
import { XAnimation } from '../../utils/AnimationUtil';
import { AIAsr } from '../../component/PlayerComponent/AIAsrComponent';
import SubtitleUtil from '../../utils/SubtitleUtil';
import { SubtitleMode } from '../../common/enum/SubtitleMode';
import { AVPlayerUtil } from '../../utils/AVPlayerUtil';
import DataSyncUtil from '../../utils/DataSyncUtil';
import { AVPlayerController } from '../../controller/AVPlayerController';
import { BrightnessSwipingBuilder } from '../../component/PlayerComponent/BrightnessSwipingBuilder';
import { FastForwardPanelBuilder } from '../../component/PlayerComponent/FastForwardPanelBuilder';
import { VolumeSwipingPanelBuilder } from '../../component/PlayerComponent/VolumeSwipingPanelBuilder';
import { SwipingPlayTimePanelBuilder } from '../../component/PlayerComponent/SwipingPlayTimePanelBuilder';
import { SubtitleDisplayBuilder } from '../../component/PlayerComponent/SubtitleDisplayBuilder';
import { salmonLogger } from 'salmonlogger';
import { SubtitlePanelComponent } from '../../component/PlayerComponent/SubtitlePanelComponent';
import { Privacy, SafeHeight } from '../../utils/ObservedUtil';

@Component
export struct Player { // 播放页
  @Provide('player') player: AVPlayerController = new AVPlayerController()
  @State longPress: boolean = false
  @State @Watch('setScreen') showControl: boolean = false
  @State lockRotation: boolean = false
  xComponentController: XComponentController = new XComponentController()
  windowClass = WindowUtil.getWindow()
  @State screen_width: number = 0
  @State screen_height: number = 0
  @State play_area_height: number = 0
  @State play_area_width: number = 0
  @State onSwiping: boolean = false
  @State onSwipingBrightness: boolean = false
  @State select_text: string | undefined = '原始比例'
  @State audio_track_select: number = 0
  @State sideBarStatusTmp: Visibility = Visibility.Hidden
  @State sideBarStatus: boolean = false
  @State isLock: boolean = false
  @State lockVisibility: boolean = false
  @State isAIAsrShown: boolean = false
  @State isSliderPlayTimeChange: boolean = false
  @State currentSpeedIndex: number = 0
  @State angle: number = 0
  @State repeatMode: RepeatMode = RepeatMode.LIST // 传子不能用@Trace
  @StorageLink('allowBackgroundPlay') allowBackgroundPlay: boolean = true
  @StorageLink('allowPlayBackExist') allowPlayBackExist: boolean = false
  @StorageLink('allowDoubleFastForward') allowDoubleFastForward: boolean = true
  @StorageLink('skipIntroTime') skipIntroTime: string = '0'
  @StorageLink('smartRotation') smartRotation: boolean = true
  @StorageLink('longPressSpeed') longPressSpeed: number = 3
  @Consume('pathStack') pathStack: NavPathStack
  @State exitVideoTime: number = 0
  private autoHideTimeout: boolean = false
  private isListenVideo: boolean = false

  async aboutToAppear(): Promise<void> {
    PermissionUtil.applyContinuousTask(this.allowBackgroundPlay)
    this.setScreen()
    try {
      await (await this.windowClass)?.setPreferredOrientation(window.Orientation.AUTO_ROTATION_RESTRICTED);
      WindowUtil.setKeepScreenStatus(PathUtils.appContext!, true)
      this.repeatMode = Preferences.getRepeatModeState(PathUtils.appContext!)
      const video_speed = Preferences.getVideoSpeed(PathUtils.appContext!)
      this.player.speed = parseFloat(video_speed?.replace('x', '') || '1')
    } catch (error) {
      ToolsUtil.addLogger(`play error ${error}`, true, this.pathStack)
    }
  }

  async aboutToDisappear(): Promise<void> {
    VideoOperateUtil.setBrightness(-1)
    Preferences.saveVideoSpeed(PathUtils.appContext!,
      (VideoInfoUtil.getVideoSpeedList(NavigationAddress.AV_PLAYER).includes(this.player.speed) ? this.player.speed :
        1) + 'x')
    Preferences.saveRepeatModeState(PathUtils.appContext!, this.repeatMode)
    WindowUtil.setBarState(PathUtils.appContext!, true, true)
    clearTimeout(this.exitVideoTime)
    this.player.cancelSubscribe()
    AppStorage.delete('nowPlayingData') //清除已保存的播放进度
    try {
      this.player.audioVolumeManager?.off('volumeChange');
    } catch (error) {
      ToolsUtil.addLogger(`volume off error ${error}`, true, this.pathStack)
    }
    this.player.audioVolumeManager = null
    this.player.releaseAVPlayer()
  }

  async setRotation() {
    if (!this.player.nowPlaying) {
      return
    }
    const nowWidth = this.player.nowPlaying.size[0]
    const nowHeight = this.player.nowPlaying.size[1]
    const aspectRatioNow = nowWidth / nowHeight;
    const screenAspectRatio = this.screen_width / this.screen_height
    if (aspectRatioNow > screenAspectRatio) {
      this.play_area_width = this.screen_width
      this.play_area_height = this.play_area_width * (nowHeight / nowWidth)
    } else {
      this.play_area_height = this.screen_height
      this.play_area_width = this.play_area_height * (nowWidth / nowHeight)
    }
    if (this.select_text !== '原始比例') {
      this.select_text = '原始比例'
    }
    VideoInfoUtil.saveOriginalVideoWidthAndHeight(this.play_area_width, this.play_area_height)
  }

  async setAVPlayerCallback() {
    this.player.avPlayer?.on('timeUpdate', async (duration) => {
      AppStorage.setOrCreate('nowPlayingData',
        [this.player.playTime, this.player.nowPlaying!, this.player.video_meta_data])
      if (this.showControl) {
        if (!this.autoHideTimeout) {
          this.autoHideTimeout = true
          setTimeout(() => {
            this.lockVisibility = false;
            this.showControl = false
            this.autoHideTimeout = false
          }, 8000)
        }
      }
      if (this.player.nowPlaying?.end_time && duration >= this.player.nowPlaying?.end_time &&
        this.repeatMode !== RepeatMode.SINGLE) {
        this.playNextVideoProcess()
        ToolsUtil.showToast('已智能跳过片尾')
      }
      if (!this.onSwiping) {
        this.player.calPlayerSync(duration)
      }
      if (this.player.subtitleSelected === SubtitleMode.EXTERNAL_SUBTITLE) {
        this.player.subtitle = SubtitleUtil.getSubtitlesAtTime(duration)
      }
    });

    this.player.avPlayer?.on('seekDone', (percent) => {
      this.player.playTime = percent
      AVSessionUtil.updatePlaybackSessionState(this.player.playing, this.player.playTime)
      if (!this.player.playing) {
        this.startImageAnalyzer()
      }
    })

    this.player.avPlayer?.on('speedDone', (systemEnum: media.PlaybackSpeed) => {
      const actualSpeed = VideoInfoUtil.mapFromSystemSpeed(systemEnum)
      this.player.speed = actualSpeed
    });

    this.player.avPlayer?.on('audioOutputDeviceChangeWithInfo', (data: audio.AudioStreamDeviceChangeInfo) => {
      if (data.changeReason === audio.AudioStreamDeviceChangeReason.REASON_OLD_DEVICE_UNAVAILABLE) {
        this.player.pauseAVPlayer()
      }
    });

    this.player.avPlayer?.on('stateChange', async (state) => {
      switch (state) {
        case 'initialized':
          if (this.player.avPlayer) {
            this.player.avPlayer.surfaceId = this.player.surfaceID
            this.player.avPlayer.setPlaybackStrategy({
              showFirstFrameOnPrepare: true
            })?.catch(() => {
              console.error('player error')
            });
            await this.player.setExternalSubtitle(this.player.nowPlaying!)
            this.player.prepareAVPlayer()
          }
          break;
        case 'prepared':
          this.player.videoStartPlayTime(VideoOperateUtil.getVideoStartPlayTimeMode(this.player.nowPlaying!,
            this.skipIntroTime))
          this.player.playAVPlayer()
          await this.player.getAudioTrack()
          await this.player.initVolumeAndBrightness()
          this.player.updatePlaybackSpeed(this.player.speed)
          this.showControl = false
          this.lockVisibility = false
          this.isSliderPlayTimeChange = false
          this.onSwiping = false
          break;
        case 'completed':
          VideoOperateUtil.saveVideoTime(this.player.playTime, this.player.nowPlaying!, this.player.video_meta_data,
            PathUtils.appContext!)
          const targetItem = this.player.video_meta_data.find(i => i.date == this.player.nowPlaying?.date)
          if (targetItem) {
            targetItem!.last_play = this.player.playTime
          }
          if (this.repeatMode === RepeatMode.SINGLE) {
            if (this.player.mIjkMediaPlayer) {
              this.player.mIjkMediaPlayer?.seekTo('0')
              this.player.mIjkMediaPlayer?.start()
            }
            this.player.playAVPlayer()
            this.player.avPlayer?.seek(0, media.SeekMode.SEEK_CLOSEST)
          } else {
            this.playNextVideoProcess()
          }
          break;
        case 'playing':
          this.player.playing = true
          if (this.player.mIjkMediaPlayer) {
            this.player.mIjkMediaPlayer?.start()
          }
          this.player.initAVSession()
          AVSessionUtil.updatePlaybackSessionState(this.player.playing, this.player.playTime)
          this.xComponentController.stopImageAnalyzer()
          break
        case 'paused':
          if (this.player.mIjkMediaPlayer) {
            this.player.mIjkMediaPlayer?.pause()
          }
          this.player.playing = false
          AVSessionUtil.updatePlaybackSessionState(this.player.playing, this.player.playTime)
          setTimeout(() => {
            this.startImageAnalyzer()
          }, 100)
          break
        case 'released':
          await this.player.ijkPlayerStop()
          this.player.playing = false
          AVSessionUtil.updatePlaybackSessionState(this.player.playing, this.player.playTime)
          break
        case 'idle':
          await this.player.ijkPlayerStop()
          this.player.releaseAVPlayer()
          break;
        case 'error':
          await this.player.ijkPlayerStop()
          VideoOperateUtil.playErrorExecute(this.pathStack, this.player.video_meta_data, this.player.nowPlaying?.date!,
            NavigationAddress.FFMPEG_PLAYER)
          this.player.releaseAVPlayer()
          break;
      }
    })
  }

  playNextVideoProcess() {
    const nextItem = this.player.playNextVideo(this.repeatMode)
    if (nextItem) {
      this.playChooseVideo(nextItem)
    } else {
      ToolsUtil.showToast('播放完毕，已自动退出')
      this.pathStack.pop()
    }
  }

  async getData() {
    try {
      this.player.avPlayer = await AVPlayerUtil.getAVPlayer()
      if (this.player.avPlayer) {
        this.setAVPlayerCallback()
        try {
          await PermissionUtil.activatePermission(this.player.nowPlaying?.uri)
          this.player.avPlayer.fdSrc = fs.openSync(this.player.nowPlaying?.uri)
        } catch (error) {
          ToolsUtil.showToast('视频打开失败，可能已失效：' + error)
          this.pathStack.pop()
        }
        this.setRotation()
        if (this.windowClass) {
          this.play_area_width > this.play_area_height ? WindowUtil.enableLandscapeMultiWindow(this.windowClass) :
            WindowUtil.disableLandscapeMultiWindow(this.windowClass)
        }
        if (this.smartRotation && this.play_area_width > this.play_area_height &&
          this.screen_height > this.screen_width) {
          const proportion =
            Math.max(this.screen_width, this.screen_height) / Math.min(this.screen_width, this.screen_height)
          const orientation = proportion > (16 / 10) ? window.Orientation.AUTO_ROTATION_LANDSCAPE
            : window.Orientation.AUTO_ROTATION_RESTRICTED;
          (await this.windowClass)?.setPreferredOrientation(orientation)?.catch(() => {
            console.error('player error')
          })
        }
      }
    } catch (error) {
      const errorText = '视频加载失败。原因是：' + error
      ToolsUtil.showToast(errorText)
      ToolsUtil.addLogger(errorText, true, this.pathStack)
      this.pathStack.pop()
    }
  }

  startImageAnalyzer() {
    this.xComponentController.startImageAnalyzer(VideoOperateUtil.config)?.catch((error: BusinessError) => {
      ToolsUtil.addLogger(`startImageAnalyzer error ${error}`, true, this.pathStack)
    })
  }

  async playChooseVideo(item: VideoMetadata) {
    VideoOperateUtil.saveVideoTime(this.player.playTime, this.player.nowPlaying!, this.player.video_meta_data,
      PathUtils.appContext!)
    if (!PrivacySpaceUtil.getPrivacyMode()) {
      RecentPlayUtil.addPlayback(PathUtils.appContext!, item)
    }
    this.player.avPlayer?.off('subtitleUpdate')
    this.player.resetAVPlayer()
    await this.player.ijkPlayerStop()
    this.player.nowPlaying = item as VideoMetadataFromPlayer
    this.getData()
    this.player.initAVSession()
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
          video_meta_data: this.player.video_meta_data,
          now_playing: this.player.nowPlaying,
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
              screenWidth: this.screen_width,
              screenHeight: this.screen_height,
              showControl: this.showControl,
              subTitleVisibility: this.player.subtitleVisibility,
              playAreaWidth: this.play_area_width,
            })
          }
          .onKeyEvent((event?: KeyEvent) => {
            if (!event || event.type !== KeyType.Down) {
              return;
            }
            if (event.keyCode === KeyCode.KEYCODE_SPACE) {
              this.player.togglePlayback()
            }
            if (event.keyCode === KeyCode.KEYCODE_ESCAPE) {
              this.exitVideo(0)
            }
            if (event.keyCode === KeyCode.KEYCODE_DPAD_RIGHT) {
              this.player.fastForward();
            }
            if (event.keyCode === KeyCode.KEYCODE_DPAD_LEFT) {
              this.player.backForward();
            }
          })
          .width(this.play_area_width)
          .height(this.play_area_height)
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
                  left: (this.screen_height > this.screen_width ? 20 : 35),
                  right: 20,
                  top: (this.showControl ? SafeHeight.topSafeHeight : 0),
                  bottom: 0
                })

                Stack() { //底栏
                  if (this.screen_height / this.screen_width > 1.4) {
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
                .height(this.screen_height > this.screen_width ? 180 : 110)
                .width('100%')
              }.height('100%').width('100%')
            }
          }

          if (this.longPress) {
            FastForwardPanelBuilder({ speed: this.player.speed, location: this.play_area_height })
          }
          if (this.onSwiping) {
            SwipingPlayTimePanelBuilder({
              isSliderPlayTimeChange: this.isSliderPlayTimeChange,
              playTime: this.player.playTime,
              totalTime: this.player.nowPlaying!.time
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
              screenHeight: this.screen_height,
              screenWidth: this.screen_width,
              showControl: this.showControl,
            })
          }
          GestureComponent({
            showControl: this.showControl,
            onDoubleClickAction: (event: GestureEvent) => {
              if (this.isLock) {
                return
              } // 设备锁定时直接返回
              if (!this.allowDoubleFastForward) { // 非双击快进模式时执行暂停
                this.player.togglePlayback()
                return
              }
              const tapX = event.fingerList[0]?.localX
              if (!VideoOperateUtil.checkLocalX(tapX)) {
                return
              }
              const zoneWidth = this.screen_width / 5 // 屏幕五分之一宽度
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
            onVerticalPanStart: (event: GestureEvent) => {
              if (!this.isLock) {
                const tapX = event.fingerList[0]?.localX
                if (!VideoOperateUtil.checkLocalX(tapX)) {
                  return
                }
                VideoOperateUtil.leftSideSwipe = tapX < this.screen_width / 2
                VideoOperateUtil.screenBrightnessTmp = this.player.screenBrightness
                this.player.volume = this.player.volumeActually
                VideoOperateUtil.lastVolume = this.player.volume // 记录起始音量
              }
            },
            onVerticalPanUpdate: (event: GestureEvent) => {
              if (!this.isLock && event.fingerList?.length === 1) {
                const deltaYScale = event?.offsetY / this.screen_height * 2.5
                if (VideoOperateUtil.leftSideSwipe) {
                  this.onSwipingBrightness = true
                  this.player.screenBrightness = VideoOperateUtil.calNewBrightness(deltaYScale)
                  VideoOperateUtil.setBrightness(this.player.screenBrightness);
                } else {
                  this.player.onSwipingVoice = true
                  const newVolume = VideoOperateUtil.lastVolume - deltaYScale * 20
                  this.player.volume =
                    Math.min(Math.max(newVolume, VideoOperateUtil.min_volume), VideoOperateUtil.max_volume);
                }
              }
            },
            onVerticalPanEnd: () => {
              this.onSwiping = false
              this.player.onSwipingVoice = false
              this.onSwipingBrightness = false
            },
            onHorizonPanStart: (_event: GestureEvent) => {
              if (!this.isLock) {
                VideoOperateUtil.lastPlayTime = this.player.playTime;
                this.onSwiping = true
              }
            },
            onHorizonPanUpdate: (event: GestureEvent) => {
              if (this.isLock) {
                return;
              }
              if (!VideoOperateUtil.checkLocalX(event?.fingerList?.[0]?.localX)) {
                return
              }
              const timePerPixel = VideoOperateUtil.getTimePixel(this.screen_width, this.player.nowPlaying?.time!)
              this.player.playTime = Math.max(0,
                Math.min(VideoOperateUtil.lastPlayTime + (event.offsetX * timePerPixel),
                  this.player.nowPlaying?.time!))
            },
            onHorizonPanEnd: () => {
              this.player.seekTime(this.player.playTime);
              this.onSwiping = false;
            },
            onPinchStart: (event: GestureEvent) => {
              const finger1 = event.fingerList[0]
              const finger2 = event.fingerList[1]
              const fingerDistance = VideoOperateUtil.calcFingerDistance(finger1, finger2)
              if (fingerDistance >= 0) {
                VideoOperateUtil.initPinchDistance = fingerDistance
              } else {
                return
              }
            },
            onPinchUpdate: (event: GestureEvent) => {
              if (this.isLock) {
                return;
              }
              const finger1 = event.fingerList[0]
              const finger2 = event.fingerList[1]
              if (!finger1 || !finger2) { // 双指检测失败直接返回
                return;
              }
              const fingerDistance = VideoOperateUtil.calcFingerDistance(finger1, finger2)
              if (fingerDistance >= 0) {
                const rawScale = fingerDistance / VideoOperateUtil.initPinchDistance;
                const adjustedScale = 1 + (rawScale - 1) * 0.007 // 计算调整后的缩放比例
                const clampedScale = Math.min(Math.max(adjustedScale, 0.5), 2.0)
                const scaledWidth = this.play_area_width * clampedScale; // 计算缩放后的播放区域宽度
                const maxAllowed = VideoInfoUtil.play_area_width * 3.0
                const minAllowed = VideoInfoUtil.play_area_width * 0.5
                if (scaledWidth > maxAllowed || scaledWidth < minAllowed) { // 检查缩放是否超出允许范围
                  return;
                }
                this.play_area_width = scaledWidth
                this.play_area_height = this.play_area_height * clampedScale;
                XAnimation.runWithAnimation(() => {
                  this.play_area_width = this.play_area_width
                  this.play_area_height = this.play_area_height
                })
              }
            },
            onLongPressAction: () => {
              if (this.isLock) {
                return
              }
              if (this.player.playing) {
                this.longPress = true
                VideoOperateUtil.lastSpeed = this.player.speed
                this.player.updatePlaybackSpeed(this.longPressSpeed)
                this.currentSpeedIndex =
                  VideoInfoUtil.getVideoSpeedList(NavigationAddress.AV_PLAYER).indexOf(this.longPressSpeed)
              }
            },
            onLongPressEnd: () => {
              this.longPress = false
              this.player.updatePlaybackSpeed(VideoOperateUtil.lastSpeed);
            },
            onLongPressPanStart: (event: GestureEvent) => {
              if (this.isLock) {
                return
              }
              const tapX = event.fingerList[0]?.localX
              if (!VideoOperateUtil.checkLocalX(tapX)) {
                return
              }
              VideoOperateUtil.longPressStartX = tapX
            },
            onLongPressPanUpdate: (event: GestureEvent) => {
              if (!this.isLock && this.longPress) { // 长按状态下的滑动处理
                const tapX = event.fingerList[0]?.localX
                if (!VideoOperateUtil.checkLocalX(tapX)) {
                  return
                }
                const deltaX = tapX - VideoOperateUtil.longPressStartX;
                const SWIPE_THRESHOLD = 15
                if (Math.abs(deltaX) <= SWIPE_THRESHOLD) { // 未达到滑动阈值则直接返回
                  return;
                }
                const direction = Math.sign(deltaX)
                const newIndex = this.currentSpeedIndex + direction; // 计算新速度索引并限制在有效范围内
                const clampedIndex = Math.max(0,
                  Math.min(newIndex, VideoInfoUtil.getVideoSpeedList(NavigationAddress.AV_PLAYER).length - 1))
                if (clampedIndex === this.currentSpeedIndex) { // 索引变化时才更新播放速度
                  return;
                }
                this.currentSpeedIndex = clampedIndex
                this.player.updatePlaybackSpeed(VideoInfoUtil.getVideoSpeedList(NavigationAddress.AV_PLAYER)[this.currentSpeedIndex])
                VideoOperateUtil.longPressStartX = event.fingerList[0]?.localX; // 重置起始点实现分档切换效果
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
              y: this.screen_width > this.screen_height ? this.screen_height / 2 - 40 : this.screen_height / 2 - 100
            })
        }.onAreaChange(async (_oldValue: Area, newValue: Area) => {
          this.screen_width = Math.floor(new Number(newValue.width).valueOf())
          this.screen_height = Math.floor(new Number(newValue.height).valueOf())
          this.setRotation()
        }).backgroundColor($r('sys.color.black'))
      }
      .showControlButton(false)
      .onChange((value: boolean) => {
        this.sideBarStatus = value;
      })
      .sideBarWidth(300)
      .showSideBar(this.sideBarStatus)
      .sideBarPosition(SideBarPosition.End)
      .divider({ strokeWidth: 0 })
    }
    .onReady(() => {
      const playerParams: PlayerParams = this.pathStack.getParamByName(NavigationAddress.AV_PLAYER)[0] as PlayerParams
      try {
        this.player.nowPlaying = playerParams.metadata as VideoMetadataFromPlayer
        this.player.video_meta_data = playerParams.metadata_list as VideoMetadata[]
      } catch (e) {
        console.error(e)
      }
    })
    .onBackPressed(() => {
      if (this.sideBarStatus) {
        this.closeSideBar(true)
        return true
      }
      if (this.showControl && !this.allowPlayBackExist) {
        this.showControl = false
        this.lockVisibility = false
        return true
      } else {
        this.player.releaseAVPlayer()
        DataSyncUtil.lastPlayVideoIndex =
          this.player.video_meta_data.findIndex(i => i.date === this.player.nowPlaying?.date)
        return false
      }
    })
    .onWillDisappear(async () => {
      if (this.player.video_meta_data.length > 0 && this.player.playTime > 0) {
        VideoOperateUtil.saveVideoTime(this.player.playTime, this.player.nowPlaying!, this.player.video_meta_data,
          PathUtils.appContext!)
      }
      PermissionUtil.applyStopContinuousTask(this.allowBackgroundPlay)
      await this.player.ijkPlayerStop()
      try {
        WindowUtil.setKeepScreenStatus(PathUtils.appContext!, false)
        if (canIUse('SystemCapability.Window.SessionManager')) {
          await (await this.windowClass)?.setSpecificSystemBarEnabled('status', true)
          await (await this.windowClass)?.setSpecificSystemBarEnabled('navigationIndicator', true)
        }
        await (await this.windowClass)?.setPreferredOrientation(window.Orientation.AUTO_ROTATION_RESTRICTED);
        await this.player.avSession?.stopCasting();
      } catch (error) {
        console.error('player error：' + error)
      }
    })
    .hideTitleBar(true)
    .blur(Privacy.isPrivacyBackground ? 1000 : 0)
  }

  exitVideo(timeOut: number) {
    this.exitVideoTime = setTimeout(() => {
      ToolsUtil.showToast('播放完毕，已自动退出')
      this.player.resetAVPlayer()
      DataSyncUtil.lastPlayVideoIndex =
        this.player.video_meta_data.findIndex(i => i.date === this.player.nowPlaying?.date)
      this.pathStack.pop()
    }, timeOut)
  }

  @Builder
  VideoTop() {
    VideoTopComponent({
      videoTitle: this.player.nowPlaying?.title,
      subTitleVisibility: this.player.subtitleVisibility,
      subtitleSelected: this.player.subtitleSelected,
      isAIAsrShown: this.isAIAsrShown,
      screenExtendSelectedText: this.select_text,
      screenWidth: this.screen_width,
      screenHeight: this.screen_height,
      audioTrackMenuBuilder: this.getAudioMenuBuilder,
      subtitlePanelComponent: this.getSubtitleMenuBuilder,
      lockRotation: this.lockRotation,
      playAreaHeight: this.play_area_height,
      playAreaWidth: this.play_area_width,
      onExitVideoClick: () => {
        this.exitVideo(0)
      },
      onLockRotationClick: async () => {
        this.lockRotation = !this.lockRotation
        const orientation = this.lockRotation ?
          (this.screen_width > this.screen_height ? window.Orientation.AUTO_ROTATION_LANDSCAPE_RESTRICTED
            : window.Orientation.AUTO_ROTATION_PORTRAIT_RESTRICTED)
          : window.Orientation.AUTO_ROTATION_RESTRICTED
        try {
          XAnimation.runWithAnimation(async () => {
            await (await this.windowClass)?.setPreferredOrientation(orientation)
          })
        } catch (error) {
          salmonLogger.addLog(this.pathStack.getAllPathName()[0],
            '屏幕旋转异常: ' + error.code + ':' + error.message, true)
        }
        const toastMessage = this.lockRotation
          ? ToolsUtil.getStringResource($r('app.string.open_rotation_lock').id)
          : ToolsUtil.getStringResource($r('app.string.close_rotation_lock').id)
        ToolsUtil.showToast(toastMessage)
      }
    })
  }

  @Builder
  VideoSlider() {
    VideoSliderComponent({
      playTime: this.player.playTime,
      totalTime: this.player.nowPlaying?.time,
      screenWidth: this.screen_width,
      screenHeight: this.screen_height,
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
  AVCastPickerBuilderBridge() { // 桥接AVCastPickerBuilder避免crash
    AVCastPickerBuilder()
  }

  @Builder
  VideoButtons() {
    VideoButtonsComponent({
      screenHeight: this.screen_height,
      screenWidth: this.screen_width,
      playing: this.player.playing,
      speed: this.player.speed,
      AVCastPickerBuilderBridge: this.AVCastPickerBuilderBridge,
      videoSettingBuilder: this.getVideoSettingBuilder,
      playbackSpeedMenu: this.getPlaybackSpeedMenuBuilder,
      repeatMode: this.repeatMode,
      sideBarStatusTmp: this.sideBarStatusTmp,
      sideBarStatus: this.sideBarStatus,
      onScreenRotationOrFullScreenClick: async () => {
        const orientation = await WindowUtil.fullScreenOperate(this.screen_height, this.screen_width, this.windowClass)
        if (orientation) {
          XAnimation.runWithAnimation(async () => {
            (await this.windowClass)?.setPreferredOrientation(orientation)?.catch(() => {
              console.error('setPreferredOrientation error')
            })
          })
        }
      },
      onTogglePlaybackClick: () => {
        this.player.togglePlayback()
      },
      onPlayNextVideoClick: () => {
        this.playNextVideoProcess()
      },
      onSideBaClose: () => {
        this.closeSideBar(true)
      }
    })
  }

  @Builder
  AudioTrackMenuBuilder() {
    AudioTrackComponent({
      audioTrack: this.player.audio_track,
      audioTrackSelected: this.audio_track_select,
      onSelect: (index: number) => {
        this.player.avPlayer?.selectTrack(this.player.audio_track[index]?.index)?.catch(() => {
          console.error('select track error')
        });
        this.audio_track_select = index;
      }
    })
  }

  @Builder
  VideoSettingBuilder() {
    VideoSettingComponent({
      playTime: this.player.playTime,
      nowPlaying: this.player.nowPlaying,
      videoMetaData: this.player.video_meta_data,
      angle: this.angle,
      repeatMode: this.repeatMode,
      exitVideoTime: this.exitVideoTime,
      forward_80_s: (time: number) => {
        this.player.seekTime(time)
      },
      onActiveEnhanceAudio: () => {
        this.player.activeEnhanceAudio()
        ToolsUtil.showToast('增强型解码启用成功')
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
        this.isListenVideo = !this.isListenVideo
        this.player.avPlayer?.setMediaMuted(media.MediaType.MEDIA_TYPE_VID, this.isListenVideo);
      }
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
      subTitleVisibility: this.player.subtitleVisibility,
      isAIAsrShown: this.isAIAsrShown,
      subtitleSelected: this.player.subtitleSelected
    })
  }

  private getPlaybackSpeedMenuBuilder: () => void = () => {
    this.PlaybackSpeedMenuBuilder()
  }
  private getAudioMenuBuilder: () => void = () => {
    this.AudioTrackMenuBuilder()
  }
  private getVideoSettingBuilder: () => void = () => {
    this.VideoSettingBuilder()
  }
  private getSubtitleMenuBuilder: () => void = () => {
    this.SubtitleMenuBuilder()
  }
}