import {
  DeviceChangeReason,
  IjkMediaPlayer,
  InterruptEvent,
  InterruptHintType,
  LogUtils,
  OnBufferingUpdateListener,
  OnCompletionListener,
  OnErrorListener,
  OnInfoListener,
  OnPreparedListener,
  OnSeekCompleteListener,
  OnTimedTextListener,
  OnVideoSizeChangedListener
} from '@ohos/ijkplayer'
import DataSyncUtil from '../utils/DataSyncUtil'
import TimeUtil from '../utils/TimeUtil'
import ToolsUtil from '../utils/ToolsUtil'
import { window } from '@kit.ArkUI'
import { audio, AVVolumePanel } from '@kit.AudioKit'
import PermissionUtil from '../utils/PermissionUtil'
import { common } from '@kit.AbilityKit'
import AVSessionUtil from '../utils/AVSessionUtil'
import { avSession as avSessionManager } from '@kit.AVSessionKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import VideoOperateUtil from '../utils/VideoOperateUtil'
import PreferencesUtil from '../utils/PreferencesUtil'
import { settings } from '@kit.BasicServicesKit'
import { PlayerParams } from '../common/PlayerParams'
import { VideoMetadataFromPlayer } from '../interfaces/VideoMetadataFromPlayerInterface'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import { PlayStatus } from '../common/enum/PlayStatus'
import { FileFolder } from '../interfaces/FileFolderInterface'
import VideoInfoUtil from '../utils/VideoInfoUtil'


@Builder
export function FFMpegPlayerBuilder() {
  FFMpegPlayer()
}

const context = getContext() as common.UIAbilityContext;

@Entry
@Component
struct FFMpegPlayer { // FFMpeg播放器页
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
  @State playSpeed: string = '1';
  now_playing: VideoMetadataFromPlayer | undefined = undefined
  @State oldSeconds: number = 0;
  @State video_url: string = ''
  @State total_time: number = 0
  @State currentSpeedIndex: number = 0
  @State longPressStartX: number = 0
  @State isLeftSideSwipe: boolean = false
  @State isRightSideSwipe: boolean = false
  @State isVerticalSwiping: boolean = false
  @State screenBrightnessAtFirst: number = 0
  @State swipe_start_y: number = 0
  @State SwipeMovingY: number = 0
  @State onSwipingVoice: boolean = false
  @State onSwipingBrightness: boolean = false
  @State screenBrightness: number = 0
  @State isSliderPlayTimeChange: boolean = false
  windowClass = window.getLastWindow(context)
  xComponentController: XComponentController = new XComponentController()
  @State @Watch('setScreen') ShowControl: boolean = false
  @StorageLink('allowBackgroundPlay') allowBackgroundPlay: boolean = true
  @StorageLink('allowPlayBackExist') allowPlayBackExist: boolean = false
  @State onSwiping: boolean = false
  @State long_press: boolean = false
  @State last_speed: string = '1'
  @State swipe_start_x: number = 0
  @State isHorizontalSwiping: boolean = false
  @State video_meta_data: VideoMetadata[] = []
  @StorageLink('fastForwardSeconds') fastForwardSeconds: string = '15'
  @StorageLink('allowDoubleFastForward') allowDoubleFastForward: boolean = true
  pathStack: NavPathStack = new NavPathStack()
  private initPinchDistance: number = 0;
  private CONTROL_PlayStatus = PlayStatus.INIT;
  private mIjkMediaPlayer = IjkMediaPlayer.getInstance();
  private file_folder: FileFolder = {
    name: '',
    date: '',
    video_list: []
  }

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

          if (this.onSwiping) {
            Stack() {
              Text(this.isSliderPlayTimeChange ?
                TimeUtil.convertMsToMMSS(this.play_time) + '/' + TimeUtil.convertMsToMMSS(this.total_time) :
                (this.play_time - this.last_play_time > 0 ? '+' : '') +
                Math.floor((this.play_time - this.last_play_time) / 1000) + 's : ' +
                TimeUtil.convertMsToMMSS(this.play_time) + '/' + TimeUtil.convertMsToMMSS(this.total_time))
                .fontColor($r('sys.color.white'))
                .fontSize(25)
                .fontWeight(FontWeight.Bold)
            }
            .padding({
              left: 25,
              right: 25,
              top: 10,
              bottom: 10
            })
            .borderRadius(1000)
            .backgroundColor('#30000000')
            .backdropBlur(100)
            .animation({ duration: 300, curve: Curve.Smooth })
          }
        }

        Stack() {
          Flex({
            justifyContent: FlexAlign.SpaceBetween,
            alignItems: ItemAlign.Center,
            direction: FlexDirection.Column
          }) { //顶栏
            Flex({ justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Center }) {
              Column() {
                if (this.screen_width > this.screen_height) {
                  Row() {
                    Text(ToolsUtil.getTime())
                      .fontWeight(FontWeight.Medium)
                      .fontSize(16)
                      .fontColor($r('sys.color.white'))
                      .textAlign(TextAlign.Center)
                      .align(Alignment.Center)
                  }
                  .width('100%')
                  .height(5)
                  .justifyContent(FlexAlign.Center)
                }
                this.VideoTop()
              }.width('100%')
            }.height(85)
            .width('100%')
            .backgroundColor('#61000000')
            .padding({
              left: (this.screen_height > this.screen_width ? 5 : 5),
              right: 20,
              top: (this.screen_height > this.screen_width ? DataSyncUtil.getActuallyTopSafeHeight() : 0),
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
            .backgroundColor('#61000000')
            .height(this.screen_height > this.screen_width ? 180 : 110)
            .width('100%')
            .padding(1)
          }.height('100%').width('100%')
        }
        .visibility(this.ShowControl ? Visibility.Visible : Visibility.Hidden)
        .animation({ duration: 300, curve: Curve.Smooth })

        if (this.onSwipingVoice) {
          Stack() { //音量提示
            Column() {
              AVVolumePanel({
                volumeLevel: this.volume,
                volumeParameter: {
                  position: {
                    x: 10000,
                    y: 20000
                  }
                }
              }).visibility(Visibility.None)
              SymbolGlyph($r('sys.symbol.speaker_wave_1'))
                .fontSize(23)
                .fontColor(['#f0f0f0'])
              Slider({
                value: this.volume,
                min: VideoOperateUtil.min_volume,
                max: VideoOperateUtil.max_volume,
                step: 0.1,
                style: SliderStyle.NONE,
                direction: Axis.Horizontal,
                reverse: false
              })
                .width(60)
                .height(30)
                .selectedColor('#e0e0e0')
                .trackColor(Color.Black)
                .trackThickness(40)
                .onChange((value) => {
                  this.volume = value
                })
            }
          }
          .padding({
            left: 25,
            right: 25,
            top: 10,
            bottom: 10
          })
          .borderRadius(1000)
          .backgroundColor('#30000000')
          .backdropBlur(100)
          .animation({ duration: 300, curve: Curve.Smooth })
        }

        if (this.onSwipingBrightness) {
          Stack() { //亮度提示
            Column() {
              SymbolGlyph($r('sys.symbol.sun_max'))
                .fontSize(23)
                .fontColor(['#f0f0f0'])
              Slider({
                value: this.screenBrightness,
                min: 0,
                max: 1,
                step: 0.1,
                style: SliderStyle.NONE,
                direction: Axis.Horizontal,
                reverse: false
              })
                .width(60)
                .height(30)
                .selectedColor($r('app.color.main_color'))
                .trackColor(Color.Black)
                .trackThickness(40)
            }
          }
          .padding({
            left: 25,
            right: 25,
            top: 10,
            bottom: 10
          })
          .borderRadius(1000)
          .backgroundColor('#30000000')
          .backdropBlur(100)
          .animation({ duration: 300, curve: Curve.Smooth })
        }

        if (this.long_press) {
          Stack({ alignContent: Alignment.BottomEnd }) { //快进提示
            Text(this.playSpeed + 'x ⏩').fontColor($r('sys.color.white')).fontSize(15).fontWeight(FontWeight.Bold)
          }
          .padding({
            left: 25,
            right: 25,
            top: 10,
            bottom: 10
          })
          .offset({ x: 0, y: 0 - this.play_area_height / 2 + 20 })
          .borderRadius(1000)
          .backgroundColor('#30000000')
          .backdropBlur(100)
          .animation({ duration: 300, curve: Curve.Smooth })
        }
        Column()
          .width('100%')
          .height('50%')//触控区域
          .gesture(GestureGroup(GestureMode.Parallel,
            TapGesture({ count: 2 })
              .onAction((event: GestureEvent) => {
                if (this.allowDoubleFastForward) {
                  const tapX = event.fingerList[0].localX;
                  const adjustWidth = this.screen_width / 5; // 计算五分之一宽度
                  if (tapX < adjustWidth) { // 左侧1/5区域
                    this.mIjkMediaPlayer.seekTo(String(this.play_time - Number(this.fastForwardSeconds) * 1000));
                  } else if (tapX > adjustWidth * 4) { // 右侧1/5区域
                    this.mIjkMediaPlayer.seekTo(String(this.play_time + Number(this.fastForwardSeconds) * 1000));
                  } else { // 中间3/5区域
                    this.playing ? this.pause() : this.startPlayOrResumePlay()
                  }
                } else {
                  this.playing ? this.pause() : this.startPlayOrResumePlay()
                }
              }),
            TapGesture({ count: 1 })
              .onAction(() => {
                this.ShowControl = !this.ShowControl
              }),
            LongPressGesture()
              .onAction(() => {
                this.long_press = true
                this.last_speed = this.playSpeed
                this.playSpeed = '3'
                this.mIjkMediaPlayer?.setSpeed(this.playSpeed)
                this.currentSpeedIndex = VideoInfoUtil.speed_index_map.indexOf(3);
              })
              .onActionEnd(() => {
                this.long_press = false
                this.playSpeed = this.last_speed
                this.mIjkMediaPlayer?.setSpeed(this.last_speed);
              }),
            PanGesture().onActionStart((event: GestureEvent) => {
              if (this.long_press) { // 初始化长按滑动参数
                this.longPressStartX = event.fingerList[0].localX;
              } else {
                const firstTouch = event.fingerList[0];
                this.swipe_start_x = firstTouch.localX;
                this.last_play_time = this.play_time;
                this.swipe_start_y = firstTouch.localY;
                this.isLeftSideSwipe = firstTouch.localX < this.screen_width / 2;
              }
            })
              .onActionUpdate((event: GestureEvent) => {
                if (this.long_press) { // 长按状态下的滑动处理
                  const deltaX = event.fingerList[0].localX - this.longPressStartX;
                  const SWIPE_THRESHOLD = 30;
                  if (Math.abs(deltaX) > SWIPE_THRESHOLD) {
                    const direction = deltaX > 0 ? 1 : -1;
                    const arrayLength = VideoInfoUtil.speed_index_map.length;
                    this.currentSpeedIndex = (this.currentSpeedIndex + direction + arrayLength) % arrayLength;
                    this.playSpeed = VideoInfoUtil.speed_index_map[this.currentSpeedIndex].toString()
                    this.mIjkMediaPlayer?.setSpeed(this.playSpeed);
                    this.longPressStartX = event.fingerList[0].localX; // 重置起始点（实现分档切换效果）
                  }
                  return
                }
                if (event.fingerList.length === 1) {
                  const currentX = event.fingerList[0].localX;
                  const currentY = event.fingerList[0].localY; // 方向判断阈值
                  const deltaX = currentX - this.swipe_start_x;
                  const deltaY = currentY - this.swipe_start_y; // 初始化滑动方向
                  if (Math.abs(deltaX) > Math.abs(deltaY)) { // 水平为主
                    if (Math.abs(deltaX) > 10 && !this.isVerticalSwiping) {
                      this.onSwiping = true
                      this.isHorizontalSwiping = true;
                      this.isVerticalSwiping = false; // 明确清除对立状态
                    }
                  } else { // 垂直为主
                    if (Math.abs(deltaY) > 10 && !this.isHorizontalSwiping) {
                      this.isVerticalSwiping = true;
                      this.isHorizontalSwiping = false; // 明确清除对立状态
                    }
                  }
                  if (this.isVerticalSwiping) {
                    const volumeStep = 0.0006; // 每像素音量变化量
                    const brightnessStep = 0.00003; // 每像素亮度变化量
                    if (this.isLeftSideSwipe) {
                      this.onSwipingBrightness = true
                      const newBrightness = this.screenBrightness - (deltaY * brightnessStep);
                      this.screenBrightness = Math.min(Math.max(newBrightness, 0), 1)
                      VideoOperateUtil.setBrightness(this.screenBrightness);
                    } else {
                      this.onSwipingVoice = true
                      const newVolume = this.volume - (deltaY * volumeStep);
                      this.volume =
                        Math.min(Math.max(newVolume, VideoOperateUtil.min_volume), VideoOperateUtil.max_volume);
                    }
                  }
                  if (this.isHorizontalSwiping) {
                    const timePerPixel = 150; // 灵敏度控制
                    this.play_time =
                      Math.max(0, Math.min(this.last_play_time + (deltaX * timePerPixel), this.total_time));
                  }
                }
              })
              .onActionEnd(() => {
                if (this.isHorizontalSwiping) {
                  this.mIjkMediaPlayer.seekTo(String(this.play_time));
                }
                this.isHorizontalSwiping = false; // 重置所有滑动状态
                this.isVerticalSwiping = false;
                this.onSwiping = false;
                this.onSwipingVoice = false;
                this.onSwipingBrightness = false;
              }),
            PinchGesture({ fingers: 2, distance: 2 })//手势缩放
              .onActionStart((event: GestureEvent) => {
                const finger1 = event.fingerList[0];
                const finger2 = event.fingerList[1];
                this.initPinchDistance = VideoOperateUtil.calcFingerDistance(finger1, finger2);
              })
              .onActionUpdate((event: GestureEvent) => {
                const finger1 = event.fingerList[0];
                const finger2 = event.fingerList[1];
                const currentDistance = VideoOperateUtil.calcFingerDistance(finger1, finger2);
                const rawScale = currentDistance / this.initPinchDistance;
                const adjustedScale = 1 + (rawScale - 1) * 0.007;
                const clampedScale = Math.min(Math.max(adjustedScale, 0.5), 2.0);
                this.play_area_width = Math.max(this.play_area_width * clampedScale, 0.5);
                this.play_area_height = Math.max(this.play_area_height * clampedScale, 0.5);
                animateTo({ duration: 100 }, () => {
                  this.play_area_width = this.play_area_width;
                  this.play_area_height = this.play_area_height;
                });
              })
          ))
      }
      .onAreaChange(async (_oldValue: Area, newValue: Area) => {
        this.screen_width = Math.floor(new Number(newValue.width).valueOf())
        this.screen_height = Math.floor(new Number(newValue.height).valueOf())
        this.getVideoSize()
      })
      .backgroundColor($r('sys.color.black'))
    }.onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
      const playerParams: PlayerParams = this.pathStack.getParamByName('FFMpegPlayer')[0] as PlayerParams
      try {
        this.now_playing = playerParams.metadata as VideoMetadataFromPlayer
        this.video_meta_data = playerParams.metadata_list as VideoMetadata[];
        this.file_folder = playerParams.file_folder as FileFolder
      } catch (e) {
        console.error(e)
      }
    }).onBackPressed(() => {
      if (this.ShowControl && !this.allowPlayBackExist) {
        this.ShowControl = false
        return true
      } else {
        return false
      }
    }).onWillDisappear(async () => {
      if (this.video_meta_data.length > 0) {
        await VideoOperateUtil.saveVideoTime(this.play_time, this.now_playing!, this.video_meta_data, context,
          this.file_folder)
      }
      this.mDestroyPage = true;
      this.mIjkMediaPlayer.setScreenOnWhilePlaying(false);
      if (this.CONTROL_PlayStatus != PlayStatus.INIT) {
        this.stop();
      }
      this.mIjkMediaPlayer.off('audioInterrupt');
    }).hideTitleBar(true)
  }

  @Builder
  VideoTop() {
    Row() {
      SymbolGlyph($r('sys.symbol.chevron_left'))// 返回图标
        .fontSize(40)
        .fontColor(['#f0f0f0'])
        .onClick(() => {
          this.pathStack.clear()
        })
        .padding({ right: 10 })
        .margin({ left: 15 })
      Text(String(this.now_playing?.title).slice(0, this.now_playing?.title.lastIndexOf('.')))
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .width('100%')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.MARQUEE })
        .fontColor($r('sys.color.white'))
    }
  }

  @Builder
  VideoSlider() {
    Row({ space: 10 }) {
      Row() {
        Text(TimeUtil.convertMsToMMSS(Math.min(Math.max(this.play_time, 0), (this.total_time || 0))) + '/' +
        TimeUtil.convertMsToMMSS(this.total_time || 0))
          .fontWeight(FontWeight.Medium)
          .fontSize(16)
          .fontColor($r('sys.color.white'))
          .textAlign(TextAlign.Start)
      }.backgroundColor('#50000000').padding(5).borderRadius(10).margin({ left: 5 })

      Slider({
        value: this.play_time,
        min: 0,
        max: this.total_time,
        style: SliderStyle.InSet
      })
        .onChange((value: number) => {
          this.isSliderPlayTimeChange = true
          this.onSwiping = true
          this.play_time = value
          this.mDestroyPage = false;
        })
        .onTouch((event) => {
          if (event.type == TouchType.Up) {
            let seekValue = this.play_time
            this.mIjkMediaPlayer.seekTo(seekValue + "");
            this.setProgress()
            this.onSwiping = false
            this.isSliderPlayTimeChange = false
          }
        })
        .layoutWeight(1)
        .animation({ duration: 100, curve: Curve.Smooth })
        .selectedColor('#e0e0e0')
      Row() {
        Text(TimeUtil.convertMsToMMSS(Math.min(Math.max((this.total_time || 0) - this.play_time, 0),
          (this.total_time || 0))))
          .fontWeight(FontWeight.Medium).fontSize(15)
          .fontColor($r('sys.color.white'))
      }.backgroundColor('#50000000').padding(5).borderRadius(10).margin({ right: 5 })
    }
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
        .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
        .height(40)
        .width(40)
        .backgroundColor('#50000000')
        .onClick(() => {
          ToolsUtil.startVibration()
          this.playing ? this.pause() : this.startPlayOrResumePlay()
        })
      }.span({ xs: 2, sm: 2, md: 2 })

      GridCol() {
        Button({ type: ButtonType.Circle, stateEffect: true }) { // 全屏按钮
          SymbolGlyph($r('sys.symbol.screen_rotation'))
            .fontSize(23)
            .fontColor(['#f0f0f0'])
        }
        .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
        .height(40)
        .width(40)
        .backgroundColor('#50000000')
        .onClick(async () => {
          this.screen_height > this.screen_width ?
          (await (this.windowClass)).setPreferredOrientation(window.Orientation.AUTO_ROTATION_LANDSCAPE)
            : (await (this.windowClass)).setPreferredOrientation(window.Orientation.AUTO_ROTATION_PORTRAIT)
        })
      }.span({ xs: 2, sm: 2, md: 2 })
    }.width('95%')
  }

  async setScreen() {
    await (await this.windowClass).setSpecificSystemBarEnabled('status', this.ShowControl)
    await (await this.windowClass).setSpecificSystemBarEnabled('navigationIndicator', this.ShowControl)
  }

  onPageShow() {
    if (this.mContext && !this.playing) {
      this.startPlayOrResumePlay();
    }
  }

  async aboutToAppear() {
    //  LogUtils.getInstance().LOGI("aboutToAppear");
    this.allowBackgroundPlay =
      await PreferencesUtil.getPreferencesValue(context, "sweet_video", "allowBackgroundPlay", true) as boolean
    if (this.allowBackgroundPlay) {
      PermissionUtil.startContinuousTask()
    }
    let groupId: number = audio.DEFAULT_VOLUME_GROUP_ID;
    let audioManager = audio.getAudioManager();
    let audioVolumeManger: audio.AudioVolumeManager = audioManager.getVolumeManager();
    this.setScreen()
    let volumeList = await VideoOperateUtil.getVolume(audioVolumeManger, groupId)
    this.volume = volumeList.get('volume')!
    await (await this.windowClass).setPreferredOrientation(window.Orientation.FOLLOW_DESKTOP);
    await (await this.windowClass).setWindowKeepScreenOn(true)
    let event: Callback<InterruptEvent> = (event) => {
      //  LogUtils.getInstance().LOGI(`event: ${JSON.stringify(event)}`);
      if (event.hintType === InterruptHintType.INTERRUPT_HINT_PAUSE) {
        this.pause();
      } else if (event.hintType === InterruptHintType.INTERRUPT_HINT_RESUME) {
        this.startPlayOrResumePlay();
      } else if (event.hintType === InterruptHintType.INTERRUPT_HINT_STOP) {
        this.stop();
      }
    }
    this.mIjkMediaPlayer.on('audioInterrupt', event);
    let deviceChangeEvent: Callback<InterruptEvent> = (event) => {
      //  LogUtils.getInstance().LOGI(`deviceChange event: ${JSON.stringify(event)}`);
      if (event.reason === DeviceChangeReason.REASON_OLD_DEVICE_UNAVAILABLE) { // 音频设备断开连接
        this.pause();
      }
    }
    this.mIjkMediaPlayer.on('deviceChange', deviceChangeEvent);
    settings.getValue(context, settings.display.SCREEN_BRIGHTNESS_STATUS, settings.domainName.DEVICE_SHARED)
      .then((value) => {
        this.screenBrightness = Number(value) / 255;
        this.screenBrightnessAtFirst = this.screenBrightness
      })
  }

  async aboutToDisappear() {
    //    LogUtils.getInstance().LOGI("aboutToDisappear");
    if (this.screenBrightness != this.screenBrightnessAtFirst) {
      VideoOperateUtil.setBrightness(this.screenBrightnessAtFirst)
    }
    AVSessionUtil.destroySession()
    PermissionUtil.stopContinuousTask()
    await (await this.windowClass).setWindowKeepScreenOn(false)
    await (await this.windowClass).setSpecificSystemBarEnabled('status', true)
    await (await this.windowClass).setSpecificSystemBarEnabled('navigationIndicator', true)
    await (await this.windowClass).setPreferredOrientation(window.Orientation.FOLLOW_DESKTOP);
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
      //  LogUtils.getInstance().LOGI("slider-->seekValue start:" + position);
      let seekValue = position;
      this.mIjkMediaPlayer.seekTo(seekValue + "");
      this.setProgress()
      // LogUtils.getInstance().LOGI("slider-->seekValue end:" + seekValue);
    })
  }

  private initDelayPlay(context: object) {
    this.mContext = context;
    let that = this;
    setTimeout(() => {
      that.startPlayOrResumePlay();
    }, 150)
  }

  private async startPlayOrResumePlay() {
    this.playing = true
    this.mDestroyPage = false;
    if (this.CONTROL_PlayStatus == PlayStatus.INIT) {
      this.stopProgressTask();
      this.startProgressTask();
      this.play();
      setTimeout(() => {
        if (this.now_playing?.last_play! < this.total_time * 0.9 && this.now_playing?.last_play != 0) {
          this.mIjkMediaPlayer.seekTo(this.now_playing?.last_play.toString()!)
        }
      }, 500)
    }
    if (this.CONTROL_PlayStatus == PlayStatus.PAUSE) {
      this.mIjkMediaPlayer.start();
      this.setProgress()
    }
    if (!this.avSession && this.allowBackgroundPlay) {
      this.avSession = await AVSessionUtil.getAVSession()
      await this.setSessionListener()
      AVSessionUtil.setSessionInfo(JSON.stringify(this.now_playing))
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
    let position = this.mIjkMediaPlayer.getCurrentPosition();
    let duration = this.mIjkMediaPlayer.getDuration();
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
    // LogUtils.getInstance()
    //   .LOGI("setProgress position:" + position + ",duration:" + duration + ",progressValue:" + pos);
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
      this.mIjkMediaPlayer.setContext(this.mContext, 'xcomponentId');
    }
    if (this.CONTROL_PlayStatus == PlayStatus.INIT) {
      this.mIjkMediaPlayer.reset();
    }
    this.CONTROL_PlayStatus = PlayStatus.PLAY;
    //设置debug模式
    this.mIjkMediaPlayer.setDebug(false);
    //初始化配置
    this.mIjkMediaPlayer.native_setup();
    // 初始化配置后需要重新设置音频流音量，否则音量为默认值1.0
    this.mIjkMediaPlayer.setVolume('1.0', '1.0');
    //设置视频源
    this.mIjkMediaPlayer.setDataSource(this.video_url);
    //使用精确寻帧 例如，拖动播放后，会寻找最近的关键帧进行播放，很有可能关键帧的位置不是拖动后的位置，而是较前的位置.可以设置这个参数来解决问题
    this.mIjkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "enable-accurate-seek", "1");
    //预读数据的缓冲区大小
    const buffer_area =
      VideoInfoUtil.support_audio_format.includes(this.now_playing?.title.split('.').pop()!.toLowerCase()!)
        ? '524288' : '943718400'
    this.mIjkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "max-buffer-size", buffer_area);
    this.mIjkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "min-frames", "120");
    this.mIjkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "start-on-prepared", "1");
    this.mIjkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "videotoolbox", "1"); // 用硬件解码
    this.mIjkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "packet-buffering", "1");
    this.mIjkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "framedrop", "5");
    this.mIjkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "mediacodec-all-videos", "1");
    this.mIjkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "mediacodec-hevc", "0");
    this.mIjkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "mediacodec-sync", "1");
    this.mIjkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "mediacodec-auto-rotate", "1");
    this.mIjkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "mediacodec-handle-resolution-change", "1");
    this.mIjkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "skip_loop_filter", "48L");
    this.mIjkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_FORMAT, "analyzeduration", "100");
    this.mIjkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_FORMAT, "analyzemaxduration", '100L');
    this.mIjkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_FORMAT, "lush_packets", '1L');
    this.mIjkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "subtitle", '1');
    // 屏幕常亮
    this.mIjkMediaPlayer.setScreenOnWhilePlaying(true);
    // 变速播放
    this.mIjkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "soundtouch", "1");
    this.mIjkMediaPlayer.setSpeed(this.playSpeed);
    let Speed = this.mIjkMediaPlayer.getSpeed()
    //是否开启循环播放
    this.mIjkMediaPlayer.setLoopCount(true);
    let mOnVideoSizeChangedListener: OnVideoSizeChangedListener = {
      onVideoSizeChanged: (width: number, height: number, sar_num: number, sar_den: number) => {
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
    this.mIjkMediaPlayer.setOnVideoSizeChangedListener(mOnVideoSizeChangedListener);
    let mOnPreparedListener: OnPreparedListener = {
      onPrepared: () => {
      }
    }
    this.mIjkMediaPlayer.setOnPreparedListener(mOnPreparedListener);

    let mOnTimedTextListener: OnTimedTextListener = {
      onTimedText: () => {
      }
    }
    this.mIjkMediaPlayer.setOnTimedTextListener(mOnTimedTextListener)
    // 播完之后
    let mOnCompletionListener: OnCompletionListener = {
      onCompletion: () => {
        that.showRePlay();
        that.play_time = this.mIjkMediaPlayer.getDuration()
        that.slideEnable = false;
        that.stop();
      }
    }
    this.mIjkMediaPlayer.setOnCompletionListener(mOnCompletionListener);
    let mOnBufferingUpdateListener: OnBufferingUpdateListener = {
      onBufferingUpdate: (percent: number) => {
        // LogUtils.getInstance().LOGI("OnBufferingUpdateListener-->go:" + percent);
        // let MediaInfo = this.mIjkMediaPlayer.getMediaInfo()
        // LogUtils.getInstance().LOGI('getMediaInfo---' + MediaInfo);
        // let VideoWidth = this.mIjkMediaPlayer.getVideoWidth()
        // LogUtils.getInstance().LOGI('getVideoWidth---' + VideoWidth);
        // let VideoHeight = this.mIjkMediaPlayer.getVideoHeight()
        // LogUtils.getInstance().LOGI('getVideoHeight---' + VideoHeight);
        // let VideoSarNum = this.mIjkMediaPlayer.getVideoSarNum()
        // LogUtils.getInstance().LOGI('getVideoSarNum---' + VideoSarNum);
        // let VideoSarDen = this.mIjkMediaPlayer.getVideoSarDen()
        // LogUtils.getInstance().LOGI('getVideoSarDen---' + VideoSarDen);
        // let AudioSessionId = this.mIjkMediaPlayer.getAudioSessionId()
        // LogUtils.getInstance().LOGI('getAudioSessionId---' + AudioSessionId);
        // let Looping = this.mIjkMediaPlayer.isLooping()
        // LogUtils.getInstance().LOGI('isLooping---' + Looping);
      }
    }
    this.mIjkMediaPlayer.setOnBufferingUpdateListener(mOnBufferingUpdateListener);
    let mOnSeekCompleteListener: OnSeekCompleteListener = {
      onSeekComplete: () => {
        //  LogUtils.getInstance().LOGI("OnSeekCompleteListener-->go");
        that.startPlayOrResumePlay();
      }
    }
    this.mIjkMediaPlayer.setOnSeekCompleteListener(mOnSeekCompleteListener);

    let mOnInfoListener: OnInfoListener = {
      onInfo: (what: number, extra: number) => {
        LogUtils.getInstance().LOGI("OnInfoListener-->go:" + what + "===" + extra);
      }
    }
    this.mIjkMediaPlayer.setOnInfoListener(mOnInfoListener);

    let mOnErrorListener: OnErrorListener = {
      onError: (what: number, extra: number) => {
        this.stopProgressTask();
        //  LogUtils.getInstance().LOGI("OnErrorListener-->go:" + what + "===" + extra)
      }
    }

    this.mIjkMediaPlayer.setOnErrorListener(mOnErrorListener);
    this.mIjkMediaPlayer.setMessageListener();
    this.mIjkMediaPlayer.prepareAsync();
    this.mIjkMediaPlayer.start();
  }

  private pause() {
    this.playing = false
    this.mIjkMediaPlayer.pause();
    this.setProgress();
    this.mDestroyPage = true;
    this.CONTROL_PlayStatus = PlayStatus.PAUSE;
    VideoOperateUtil.updateSession(this.playing, this.play_time)
  }

  private stop() {
    VideoOperateUtil.updateSession(this.playing, this.play_time)
    this.CONTROL_PlayStatus = PlayStatus.INIT;
    this.mIjkMediaPlayer.stop();
    this.mIjkMediaPlayer.release();
    this.stopProgressTask();
  }

  private getVideoSize() {
    let VideoWidth = this.mIjkMediaPlayer.getVideoWidth();
    //  LogUtils.getInstance().LOGI("getVideoWidth---" + VideoWidth);
    let VideoHeight = this.mIjkMediaPlayer.getVideoHeight();
    //  LogUtils.getInstance().LOGI("getVideoHeight---" + VideoHeight);
    if (this.now_playing?.size[0] === 0 && VideoWidth !== 0) {
      this.now_playing.size[0] = VideoWidth
      this.now_playing.size[1] = VideoHeight
      VideoOperateUtil.saveVideoWeightAndHeight(this.now_playing, this.video_meta_data, context, this.file_folder)
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