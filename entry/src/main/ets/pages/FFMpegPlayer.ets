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
import ToolsUtil from '../utils/ToolsUtil'
import { window } from '@kit.ArkUI'
import { audio } from '@kit.AudioKit'
import PermissionUtil from '../utils/PermissionUtil'
import AVSessionUtil from '../utils/AVSessionUtil'
import { AVCastPicker, avSession as avSessionManager } from '@kit.AVSessionKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import VideoOperateUtil from '../utils/VideoOperateUtil'
import { settings } from '@kit.BasicServicesKit'
import { PlayerParams } from '../common/PlayerParams'
import { VideoMetadataFromPlayer } from '../interfaces/VideoMetadataFromPlayerInterface'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import { PlayStatus } from '../common/enum/PlayStatus'
import VideoInfoUtil from '../utils/VideoInfoUtil'
import { KeyCode } from '@kit.InputKit'
import { PathUtils } from '../utils/PathUtils'
import { ButtonFancyModifier } from '../utils/AttributeModifierUtil'
import { AVCastPickerBuilder } from '../component/PlayerComponent/AVCastPickerBuilder'
import { VolumeSwipingComponent } from '../component/PlayerComponent/VolumeSwipingComponent'
import { BrightnessSwipingComponent } from '../component/PlayerComponent/BrightnessSwipingComponent'
import { FastForwardInfoComponent } from '../component/PlayerComponent/FastForwardInfoComponent'
import { SwipingPlayTimeDisplay } from '../component/PlayerComponent/SwipingPlayTimeDisplay'
import { VideoSliderComponent } from '../component/PlayerComponent/VideoSliderComponent'
import { GestureComponent } from '../component/PlayerComponent/GestureComponent'
import { VideoStartTimeMode } from '../common/enum/VideoStartTimeMode'

@Component
export struct FFMpegPlayer { // FFMpeg播放器页
  avSession: avSessionManager.AVSession | undefined = undefined;
  @State play_area_height: number = 1
  @State play_area_width: number = 1
  @State screen_width: number = 0
  @State screen_height: number = 0
  @State play_time: number = 0
  @State last_play_time: number = 0
  @State playing: boolean = false
  @State mContext: object | undefined = undefined;
  @State updateProgressTimer: number = 0;
  @State mDestroyPage: boolean = false;
  @State slideEnable: boolean = false;
  @State loadingVisible: Visibility = Visibility.None;
  @State replayVisible: Visibility = Visibility.None;
  @State volume: number = 1.0;
  @State play_speed: string = '1';
  now_playing: VideoMetadataFromPlayer | undefined = undefined
  @State video_url: string = ''
  @State total_time: number = 0
  @State currentSpeedIndex: number = 0
  @State longPressStartX: number = 0
  @State isLeftSideSwipe: boolean = false
  @State isRightSideSwipe: boolean = false
  @State isVerticalSwiping: boolean = false
  @State swipe_start_y: number = 0
  @State onSwipingVoice: boolean = false
  @State onSwipingBrightness: boolean = false
  @State screenBrightness: number = 0
  @State volumeTmp: number = 0
  @State isLock: boolean = false
  @State isSliderPlayTimeChange: boolean = false
  windowClass = window.getLastWindow(PathUtils.appContext!)
  xComponentController: XComponentController = new XComponentController()
  @State @Watch('setScreen') showControl: boolean = false
  @StorageLink('allowBackgroundPlay') allowBackgroundPlay: boolean = true
  @StorageLink('allowPlayBackExist') allowPlayBackExist: boolean = false
  @State onSwiping: boolean = false
  @State long_press: boolean = false
  @State last_speed: string = '1'
  @State swipe_start_x: number = 0
  @State isHorizontalSwiping: boolean = false
  @State video_meta_data: VideoMetadata[] = []
  @State volumeActually: number = 0
  @StorageLink('fastForwardSeconds') fastForwardSeconds: string = '15'
  @StorageLink('allowDoubleFastForward') allowDoubleFastForward: boolean = true
  @StorageLink('skipIntroTime') skipIntroTime: string = '0'
  @Consume('pathStack') pathStack: NavPathStack
  @StorageProp('topSafeHeight') topSafeHeight: number = 0;
  private CONTROL_PlayStatus = PlayStatus.INIT;
  private mIjkMediaPlayer: IjkMediaPlayer | null = null;
  private audioVolumeManager: audio.AudioVolumeManager | null = null

  build() {
    NavDestination() {
      Stack() {
        Stack() {
          Stack() { //播放器
            XComponent({
              type: XComponentType.SURFACE,
              controller: this.xComponentController,
              id: 'xcomponentId',
              libraryname: 'ijkplayer_napi'
            })
              .onLoad(async (event?: object) => {
                if (!!event) {
                  this.initDelayPlay(event);
                  await PermissionUtil.activatePermission(this.now_playing?.uri || '')
                  const file = fs.openSync(this.now_playing?.uri)
                  this.video_url = file.path
                }
              })
          }
          .width(this.play_area_width)
          .height(this.play_area_height)
          .animation({ duration: this.play_time > 300 ? 300 : 0, curve: Curve.Ease })

          Stack() {
            Flex({
              justifyContent: FlexAlign.SpaceBetween,
              alignItems: ItemAlign.Center,
              direction: FlexDirection.Column
            }) { //顶栏
              Flex({ justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Center }) {
                Column() {
                  this.VideoTop()
                }.width('100%')
              }.height(85)
              .width('100%')
              .backgroundColor($r('sys.color.mask_fourth'))
              .padding({
                left: (this.screen_height > this.screen_width ? 5 : 5),
                right: 20,
                top: (this.screen_height > this.screen_width ? this.topSafeHeight : 0),
                bottom: 0
              })

              Stack() { //底栏
                if (this.screen_height > this.screen_width) {
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
              .backgroundColor($r('sys.color.mask_fourth'))
              .height(this.screen_height > this.screen_width ? 180 : 110)
              .width('100%')
              .padding(1)
            }.height('100%').width('100%')
          }.visibility(this.showControl ? Visibility.Visible : Visibility.Hidden)
          .animation({ duration: 300, curve: Curve.Smooth })
        }

        if (this.onSwiping) {
          SwipingPlayTimeDisplay({
            isSliderPlayTimeChange: this.isSliderPlayTimeChange,
            playTime: this.play_time,
            totalTime: this.total_time,
            lastPlayTime: this.last_play_time
          })
        }

        if (this.onSwipingVoice) {
          VolumeSwipingComponent({
            videoVolume: this.volume,
            videoVolumeShow: this.volumeActually
          })
        }

        if (this.onSwipingBrightness) {
          BrightnessSwipingComponent({
            screenBrightness: this.screenBrightness,
          })
        }

        if (this.long_press) {
          FastForwardInfoComponent({
            speed: Number(this.play_speed),
            location: 0 - this.play_area_height / 2 + 20
          })
        }

        GestureComponent({
          showControl: this.showControl,
          onDoubleClickAction: (event: GestureEvent) => {
            if (!this.allowDoubleFastForward) { // 非快进模式直接切换播放状态
              this.togglePlayState();
              return;
            }
            const tapX = event.fingerList[0].localX;
            const zoneWidth = this.screen_width / 5; // 计算区域分割宽度
            if (tapX < zoneWidth) { // 左侧区域：回退
              this.mIjkMediaPlayer?.seekTo(String(this.play_time - Number(this.fastForwardSeconds) * 1000));
              return;
            }
            if (tapX > zoneWidth * 4) { // 右侧区域：快进
              this.mIjkMediaPlayer?.seekTo(String(this.play_time + Number(this.fastForwardSeconds) * 1000));
              return;
            }
            this.togglePlayState(); // 中间区域：播放/暂停切换
          },
          onSingleClickAction: () => {
            this.showControl = !this.showControl
          },
          onVerticalPanStart: (event: GestureEvent) => {
            if (!this.isLock) {
              const firstTouch = event.fingerList[0];
              this.swipe_start_x = firstTouch.localX;
              this.swipe_start_y = firstTouch.localY;
              this.isLeftSideSwipe = firstTouch.localX < this.screen_width / 2;
              VideoOperateUtil.screenBrightnessTmp = this.screenBrightness
              VideoOperateUtil.lastVolume = this.volume; // 记录起始音量
              VideoOperateUtil.lastVolumeTime = Date.now(); // 记录起始时间
            }
          },
          onVerticalPanUpdate: (event: GestureEvent) => {
            if (!this.isLock && event.fingerList.length === 1) {
              const currentY = event.fingerList[0].localY;
              const deltaY = currentY - this.swipe_start_y;
              const deltaYScale = deltaY / this.screen_height * 2.5;
              if (this.isLeftSideSwipe) {
                this.onSwipingBrightness = true
                this.screenBrightness = VideoOperateUtil.calNewBrightness(deltaYScale)
                VideoOperateUtil.setBrightness(this.screenBrightness);
              } else {
                this.onSwipingVoice = true
                this.volume = VideoOperateUtil.calNewVolume(deltaYScale)
                VideoOperateUtil.lastVolumeTime = VideoOperateUtil.volumeGestureActiveTime;
                VideoOperateUtil.lastVolume = this.volume
              }
            }
          },
          onVerticalPanEnd: () => {
            this.onSwiping = false;
            this.onSwipingVoice = false;
            this.onSwipingBrightness = false;
          },
          onHorizonPanStart: (event: GestureEvent) => {
            if (this.isLock) {
              return
            }
            const firstTouch = event.fingerList[0];
            this.swipe_start_x = firstTouch.localX;
            this.swipe_start_y = firstTouch.localY;
            this.last_play_time = this.play_time;
            this.onSwiping = true
          },
          onHorizonPanUpdate: (event: GestureEvent) => {
            if (event?.fingerList?.[0]?.localX !== undefined &&
              typeof event.fingerList[0].localX === 'number') {
              const currentX = event.fingerList[0].localX;
              const deltaX = currentX - this.swipe_start_x;
              this.play_time = Math.max(0,
                Math.min(this.last_play_time + (deltaX * VideoOperateUtil.timePerPixel),
                  this.now_playing?.time!));
            }
          },
          onHorizonPanEnd: () => {
            this.mIjkMediaPlayer?.seekTo(String(this.play_time));
            this.onSwiping = false;
          },
          onPinchStart: (event: GestureEvent) => {
            const finger1 = event.fingerList[0];
            const finger2 = event.fingerList[1];
            VideoOperateUtil.initPinchDistance = VideoOperateUtil.calcFingerDistance(finger1, finger2);
          },
          onPinchUpdate: (event: GestureEvent) => {
            const finger1 = event.fingerList[0];
            const finger2 = event.fingerList[1];
            const currentDistance = VideoOperateUtil.calcFingerDistance(finger1, finger2);
            const rawScale = currentDistance / VideoOperateUtil.initPinchDistance;
            const adjustedScale = 1 + (rawScale - 1) * 0.007;
            const clampedScale = Math.min(Math.max(adjustedScale, 0.5), 2.0);
            this.play_area_width = Math.max(this.play_area_width * clampedScale, 0.5);
            this.play_area_height = Math.max(this.play_area_height * clampedScale, 0.5);
            animateTo({ duration: 100 }, () => {
              this.play_area_width = this.play_area_width;
              this.play_area_height = this.play_area_height;
            });
          },
          onLongPressAction: () => {
            this.long_press = true
            this.last_speed = this.play_speed
            this.play_speed = '3'
            this.mIjkMediaPlayer?.setSpeed(this.play_speed)
            this.currentSpeedIndex = VideoInfoUtil.video_speed_list.indexOf(3);
          },
          onLongPressEnd: () => {
            this.long_press = false
            this.play_speed = this.last_speed
            this.mIjkMediaPlayer?.setSpeed(this.last_speed);
          },
          onLongPressPanStart: (event: GestureEvent) => {
            this.longPressStartX = event.fingerList[0].localX;
          },
          onLongPressPanUpdate: (event: GestureEvent) => {
            const deltaX = event.fingerList[0].localX - this.longPressStartX;
            const SWIPE_THRESHOLD = 30;
            if (Math.abs(deltaX) <= SWIPE_THRESHOLD) { // 检查是否达到滑动阈值
              return;
            }
            const direction = deltaX > 0 ? 1 : -1; // 确定滑动方向（正值为右滑，负值为左滑）
            const newIndex = this.currentSpeedIndex + direction; // 计算新的速度索引
            const clampedIndex = Math.max(0, Math.min(newIndex, VideoInfoUtil.video_speed_list.length - 1));
            if (clampedIndex === this.currentSpeedIndex) { // 如果速度没有变化则直接返回
              return;
            }
            this.currentSpeedIndex = clampedIndex
            this.play_speed = VideoInfoUtil.video_speed_list[this.currentSpeedIndex].toString()
            this.mIjkMediaPlayer?.setSpeed(this.play_speed);
            this.longPressStartX = event.fingerList[0].localX; // 重置起始点实现分档切换效果
          }
        })
      }
      .onAreaChange(async (_oldValue: Area, newValue: Area) => {
        this.screen_width = Math.floor(new Number(newValue.width).valueOf())
        this.screen_height = Math.floor(new Number(newValue.height).valueOf())
        this.getVideoSize()
      })
      .backgroundColor($r('sys.color.black'))
    }.onReady(() => {
      const playerParams: PlayerParams = this.pathStack.getParamByName('FFMpegPlayer')[0] as PlayerParams
      try {
        this.now_playing = playerParams.metadata as VideoMetadataFromPlayer
        this.video_meta_data = playerParams.metadata_list as VideoMetadata[];
      } catch (e) {
        console.error(e)
      }
    }).onBackPressed(() => {
      if (this.showControl && !this.allowPlayBackExist) {
        this.showControl = false
        return true
      } else {
        return false
      }
    }).onWillDisappear(async () => {
      if (this.video_meta_data.length > 0 && this.play_time > 0) {
        VideoOperateUtil.saveVideoTime(this.play_time, this.now_playing!, this.video_meta_data,
          PathUtils.appContext!)
      }
      await (await this.windowClass).setWindowKeepScreenOn(false)
      if (canIUse('SystemCapability.Window.SessionManager')) {
        await (await this.windowClass).setSpecificSystemBarEnabled('status', true)
        await (await this.windowClass).setSpecificSystemBarEnabled('navigationIndicator', true)
      }
      await (await this.windowClass).setPreferredOrientation(window.Orientation.AUTO_ROTATION_RESTRICTED);
      if (this.now_playing?.time === 0) {
        this.now_playing.time = this.total_time; // 若系统无法识别视频时长，则由 FFMpeg API 提供以保存记忆时间
      }
      this.mDestroyPage = true;
      this.mIjkMediaPlayer?.setScreenOnWhilePlaying(false);
      if (this.CONTROL_PlayStatus != PlayStatus.INIT) {
        this.stop();
      }
      this.mIjkMediaPlayer?.off('audioInterrupt');
      this.mIjkMediaPlayer?.off('deviceChange')
      if (this.allowBackgroundPlay) {
        AVSessionUtil.destroySession()
        PermissionUtil.stopContinuousTask()
      }
    }).hideTitleBar(true)
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
      Text(String(this.now_playing?.title).slice(0, this.now_playing?.title.lastIndexOf('.')))
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
      screenHeight: this.screen_height,
      screenWidth: this.screen_width,
      onSliderChange: (value: number) => {
        this.isSliderPlayTimeChange = true
        this.onSwiping = true
        this.play_time = value
        this.mDestroyPage = false;
      },
      onSliderTouch: (event: TouchEvent) => {
        if (event.type == TouchType.Up) {
          let seekValue = this.play_time
          this.mIjkMediaPlayer?.seekTo(seekValue + "");
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
        .defaultFocus(true)
        .onKeyEvent((event?: KeyEvent) => {
          if (event) {
            if (event.type === KeyType.Down && event.keyCode === KeyCode.KEYCODE_SPACE) { // 空格键按下触发
              this.togglePlayState()
            }
          }
        })
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
          VideoOperateUtil.fullScreenOperate()
          const orientation = this.screen_height > this.screen_width
            ? window.Orientation.AUTO_ROTATION_LANDSCAPE
            : window.Orientation.AUTO_ROTATION_PORTRAIT;
          (await this.windowClass).setPreferredOrientation(orientation)
        })
      }.span({ xs: 2, sm: 2, md: 2 })

      GridCol() { // 投播
        AVCastPicker({
          normalColor: Color.White,
          onStateChange: VideoOperateUtil.castOnStateChange,
          customPicker: () => this.AVCastPickerBuilderBridge()
        })
          .width(23)
          .height(23)
          .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
      }.span({ xs: 2, sm: 2, md: 2 })
    }.width('95%')
  }

  @Builder
  AVCastPickerBuilderBridge() { // 桥接AVCastPickerBuilder避免crash
    AVCastPickerBuilder()
  }

  async setScreen() {
    if (canIUse('SystemCapability.Window.SessionManager')) {
      await (await this.windowClass).setSpecificSystemBarEnabled('status', this.showControl, true)
      await (await this.windowClass).setSpecificSystemBarEnabled('navigationIndicator', this.showControl, true)
    }
  }

  async aboutToAppear() {
    this.mIjkMediaPlayer = IjkMediaPlayer.getInstance();
    if (this.allowBackgroundPlay) {
      PermissionUtil.startContinuousTask()
    }
    await this.setScreen()
    let groupId: number = audio.DEFAULT_VOLUME_GROUP_ID;
    let audioManager = audio.getAudioManager();
    this.audioVolumeManager = audioManager.getVolumeManager();
    let volumeList = await VideoOperateUtil.getVolume(this.audioVolumeManager, groupId)
    this.volume = volumeList.get('volume')!
    await (await this.windowClass).setPreferredOrientation(window.Orientation.AUTO_ROTATION_RESTRICTED);
    await (await this.windowClass).setWindowKeepScreenOn(true)
    let event: Callback<InterruptEvent> = (event) => {
      if (event.hintType === InterruptHintType.INTERRUPT_HINT_PAUSE) {
        this.pause();
      } else if (event.hintType === InterruptHintType.INTERRUPT_HINT_RESUME) {
        this.startPlayOrResumePlay();
      } else if (event.hintType === InterruptHintType.INTERRUPT_HINT_STOP) {
        this.pause();
      }
    }
    this.mIjkMediaPlayer?.on('audioInterrupt', event);
    let deviceChangeEvent: Callback<InterruptEvent> = (event) => {
      if (event.reason === DeviceChangeReason.REASON_OLD_DEVICE_UNAVAILABLE) { // 音频设备断开连接
        this.pause();
      }
    }
    this.mIjkMediaPlayer?.on('deviceChange', deviceChangeEvent);
    if (canIUse('SystemCapability.Applications.Settings.Core')) {
      settings.getValue(PathUtils.appContext!, settings.display.SCREEN_BRIGHTNESS_STATUS,
        settings.domainName.DEVICE_SHARED)
        .then((value) => {
          this.screenBrightness = Number(value) / 255;
        })
    }
    this.volumeActually = this.volume
    this.audioVolumeManager.on('volumeChange', (volumeEvent: audio.VolumeEvent) => {
      this.volumeActually = volumeEvent.volume
      ToolsUtil.startVibration()
    });
  }

  async aboutToDisappear() {
    this.mIjkMediaPlayer = null
    VideoOperateUtil.setBrightness(-1)
    this.audioVolumeManager?.off('volumeChange');
    this.audioVolumeManager = null
  }

  async setSessionListener() {
    this.avSession?.on('play', () => {
      this.startPlayOrResumePlay();
    });
    this.avSession?.on('pause', () => {
      this.pause()
    });
    this.avSession?.on('seek', (position: number) => {
      this.mDestroyPage = false;
      let seekValue = position;
      this.mIjkMediaPlayer?.seekTo(seekValue + "");
      this.setProgress()
    })
  }

  videoStartPlayTime(seekMode: number) {
    switch (seekMode) {
      case VideoStartTimeMode.SEEK_TO_LAST_PLAY_TIME:
        this.mIjkMediaPlayer?.seekTo(String(this.now_playing?.last_play) || '0')
        break
      case VideoStartTimeMode.SEEK_TO_START_TIME:
        this.mIjkMediaPlayer?.seekTo(String(this.now_playing?.start_time) || '0')
        break
      case VideoStartTimeMode.SEEK_TO_INTRO_TIME:
        this.mIjkMediaPlayer?.seekTo(String(this.play_time + Number(this.skipIntroTime) * 1000))
        break
      default:
        return
    }
  }

  private initDelayPlay(context: object) {
    this.mContext = context;
    let that = this;
    setTimeout(() => {
      that.startPlayOrResumePlay();
    }, 150)
  }

  private togglePlayState() {
    this.playing ? this.pause() : this.startPlayOrResumePlay();
  }

  private async startPlayOrResumePlay() {
    this.playing = true
    this.mDestroyPage = false;
    if (this.CONTROL_PlayStatus == PlayStatus.INIT) {
      this.stopProgressTask();
      this.startProgressTask();
      this.play();
      setTimeout(() => {
        this.videoStartPlayTime(VideoOperateUtil.getVideoStartPlayTimeMode(this.now_playing!, this.skipIntroTime))
      }, 600)
    }
    if (this.CONTROL_PlayStatus == PlayStatus.PAUSE) {
      this.mIjkMediaPlayer?.start();
      this.setProgress()
    }
    if (!this.avSession && this.allowBackgroundPlay) {
      this.avSession = await AVSessionUtil.getAVSession()
      await this.setSessionListener()
      AVSessionUtil.setSessionInfo(this.now_playing!)
      VideoOperateUtil.updateSession(this.playing, this.play_time)
    }
    VideoOperateUtil.updateSession(this.playing, this.play_time)
  }

  private startProgressTask() {
    let that = this;
    this.updateProgressTimer = setInterval(() => {
      if (!that.mDestroyPage) {
        that.setProgress();
      }
    }, 300);
  }

  private stopProgressTask() {
    clearInterval(this.updateProgressTimer);
  }

  private setProgress() { //设置进度条
    let position = this.mIjkMediaPlayer?.getCurrentPosition()!;
    let duration = this.mIjkMediaPlayer?.getDuration()!;
    let pos = 0;
    this.total_time = duration
    if (duration > 0) {
      this.slideEnable = true;
      let curPercent = position / duration;
      pos = curPercent * 100;
      if (pos > (this.total_time || 0)) {
        this.play_time = this.total_time || 0
      } else {
        this.play_time = pos;
      }
    }
    if (position > duration) {
      position = duration;
    }
    this.play_time = position;
  }

  private showRePlay() {
    this.loadingVisible = Visibility.None;
    this.replayVisible = Visibility.Visible;
  }

  private play() {
    let that = this;
    //设置XComponent回调的context
    if (!!this.mContext) {
      this.mIjkMediaPlayer?.setContext(this.mContext, 'xcomponentId');
    }
    if (this.CONTROL_PlayStatus == PlayStatus.INIT) {
      this.mIjkMediaPlayer?.reset();
    }
    this.CONTROL_PlayStatus = PlayStatus.PLAY;
    //设置debug模式
    this.mIjkMediaPlayer?.setDebug(false);
    //初始化配置
    this.mIjkMediaPlayer?.native_setup();
    // 初始化配置后需要重新设置音频流音量，否则音量为默认值1.0
    this.mIjkMediaPlayer?.setVolume('1.0', '1.0');
    //设置视频源
    this.mIjkMediaPlayer?.setDataSource(this.video_url);
    //使用精确寻帧 例如，拖动播放后，会寻找最近的关键帧进行播放，很有可能关键帧的位置不是拖动后的位置，而是较前的位置.可以设置这个参数来解决问题
    this.mIjkMediaPlayer?.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "enable-accurate-seek", "1");
    //预读数据的缓冲区大小
    this.mIjkMediaPlayer?.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "max-buffer-size", '943718400');
    this.mIjkMediaPlayer?.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "min-frames", "120");
    this.mIjkMediaPlayer?.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "start-on-prepared", "1");
    this.mIjkMediaPlayer?.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "videotoolbox", "1"); // 用硬件解码
    this.mIjkMediaPlayer?.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "packet-buffering", "1");
    this.mIjkMediaPlayer?.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "framedrop", "5");
    this.mIjkMediaPlayer?.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "mediacodec-all-videos", "1");
    this.mIjkMediaPlayer?.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "mediacodec-hevc", "0");
    this.mIjkMediaPlayer?.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "mediacodec-sync", "1");
    this.mIjkMediaPlayer?.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "mediacodec-auto-rotate", "1");
    this.mIjkMediaPlayer?.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "mediacodec-handle-resolution-change", "1");
    this.mIjkMediaPlayer?.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "skip_loop_filter", "48L");
    this.mIjkMediaPlayer?.setOption(IjkMediaPlayer.OPT_CATEGORY_FORMAT, "analyzeduration", "100");
    this.mIjkMediaPlayer?.setOption(IjkMediaPlayer.OPT_CATEGORY_FORMAT, "analyzemaxduration", '100L');
    this.mIjkMediaPlayer?.setOption(IjkMediaPlayer.OPT_CATEGORY_FORMAT, "lush_packets", '1L');
    // 重置错误状态
    this.mIjkMediaPlayer?.setOption(IjkMediaPlayer.OPT_CATEGORY_FORMAT, "skip_clear", "0");
    // 使用相对安全模式
    this.mIjkMediaPlayer?.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "seek-at-start", "1");
    // 屏幕常亮
    this.mIjkMediaPlayer?.setScreenOnWhilePlaying(true);
    // 变速播放
    this.mIjkMediaPlayer?.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "soundtouch", "1");
    this.mIjkMediaPlayer?.setSpeed(this.play_speed);
    //是否开启循环播放
    this.mIjkMediaPlayer?.setLoopCount(true);
    let mOnVideoSizeChangedListener: OnVideoSizeChangedListener = {
      onVideoSizeChanged: (width: number, height: number, sar_num: number, sar_den: number) => {
        console.log('video size: ' + sar_num + ':' + sar_den)
        if (height === 0) {
          return;
        }
        const aspectRatioNow = width / height;
        const screenAspectRatio = this.screen_width / this.screen_height;
        if (aspectRatioNow > screenAspectRatio) {
          this.play_area_width = this.screen_width;
          this.play_area_height = this.play_area_width * (height / width);
        } else {
          this.play_area_height = this.screen_height;
          this.play_area_width = this.play_area_height * (width / height);
        }
        that.getVideoSize();
      }
    }
    this.mIjkMediaPlayer?.setOnVideoSizeChangedListener(mOnVideoSizeChangedListener);
    let mOnPreparedListener: OnPreparedListener = {
      onPrepared: () => {
      }
    }
    this.mIjkMediaPlayer?.setOnPreparedListener(mOnPreparedListener);

    let mOnTimedTextListener: OnTimedTextListener = {
      onTimedText: () => {
      }
    }
    this.mIjkMediaPlayer?.setOnTimedTextListener(mOnTimedTextListener)
    // 播完之后
    let mOnCompletionListener: OnCompletionListener = {
      onCompletion: () => {
        that.showRePlay();
        that.play_time = this.mIjkMediaPlayer?.getDuration()!
        that.slideEnable = false;
        that.stop();
      }
    }
    this.mIjkMediaPlayer?.setOnCompletionListener(mOnCompletionListener);
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
    this.mIjkMediaPlayer?.setOnBufferingUpdateListener(mOnBufferingUpdateListener);
    let mOnSeekCompleteListener: OnSeekCompleteListener = {
      onSeekComplete: () => {
        that.startPlayOrResumePlay();
      }
    }
    this.mIjkMediaPlayer?.setOnSeekCompleteListener(mOnSeekCompleteListener);

    let mOnInfoListener: OnInfoListener = {
      onInfo: (what: number, extra: number) => {
        console.log("OnInfoListener-->go:" + what + "===" + extra)
      }
    }
    this.mIjkMediaPlayer?.setOnInfoListener(mOnInfoListener);

    let mOnErrorListener: OnErrorListener = {
      onError: (what: number, extra: number) => {
        this.stopProgressTask();
        ToolsUtil.showToast('播放出错了: ' + what + ':' + extra)
        console.log('mOnErrorListener' + what + ':' + extra)
      }
    }

    this.mIjkMediaPlayer?.setOnErrorListener(mOnErrorListener);
    this.mIjkMediaPlayer?.setMessageListener();
    this.mIjkMediaPlayer?.prepareAsync();
    this.mIjkMediaPlayer?.start();
  }

  private pause() {
    this.playing = false
    this.mIjkMediaPlayer?.pause();
    this.setProgress();
    this.mDestroyPage = true;
    this.CONTROL_PlayStatus = PlayStatus.PAUSE;
    VideoOperateUtil.updateSession(this.playing, this.play_time)
  }

  private stop() {
    VideoOperateUtil.updateSession(this.playing, this.play_time)
    this.CONTROL_PlayStatus = PlayStatus.INIT;
    this.mIjkMediaPlayer?.stop();
    this.mIjkMediaPlayer?.release();
    this.stopProgressTask();
    this.mIjkMediaPlayer = null
  }

  private getVideoSize() {
    let VideoWidth = this.mIjkMediaPlayer?.getVideoWidth()!;
    let VideoHeight = this.mIjkMediaPlayer?.getVideoHeight()!;
    if (this.now_playing?.size[0] === 0 && VideoWidth !== 0) {
      this.now_playing.size[0] = VideoWidth
      this.now_playing.size[1] = VideoHeight
      VideoOperateUtil.saveVideoWeightAndHeight(PathUtils.appContext!, this.now_playing)
    }
    const aspectRatioNow = VideoWidth / VideoHeight;
    const screenAspectRatio = this.screen_width / this.screen_height;
    if (aspectRatioNow > screenAspectRatio) {
      this.play_area_width = this.screen_width;
      this.play_area_height = this.play_area_width * (VideoHeight / VideoWidth);
    } else {
      this.play_area_height = this.screen_height;
      this.play_area_width = this.play_area_height * (VideoWidth / VideoHeight);
    }
  }
}