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
import TimeUtil from '../utils/TimeUtil'
import ToolsUtil from '../utils/ToolsUtil'
import { window } from '@kit.ArkUI'
import { audio, AVVolumePanel } from '@kit.AudioKit'
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
import { FileFolder } from '../interfaces/FileFolderInterface'
import VideoInfoUtil from '../utils/VideoInfoUtil'
import { KeyCode } from '@kit.InputKit'
import { PathUtils } from '../utils/PathUtils'
import { AVCastPickerBuilder } from '../component/AVCastPickerBuilder'
import { ButtonFancyModifier } from '../utils/AttributeModifierUtil'

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
  @State screenBrightnessTmp: number = 0
  @State volumeTmp: number = 0
  @State isLock: boolean = false
  @State isSliderPlayTimeChange: boolean = false
  windowClass = window.getLastWindow(PathUtils.appContext!)
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
  @StorageLink('skipIntroTime') skipIntroTime: string = '0'
  @Consume('pathStack') pathStack: NavPathStack
  @StorageProp('topSafeHeight') topSafeHeight: number = 0;
  private initPinchDistance: number = 0;
  private CONTROL_PlayStatus = PlayStatus.INIT;
  private mIjkMediaPlayer: IjkMediaPlayer | null = null;
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
              .backgroundColor('#61000000')
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
              .backgroundColor('#61000000')
              .height(this.screen_height > this.screen_width ? 180 : 110)
              .width('100%')
              .padding(1)
            }.height('100%').width('100%')
          }.visibility(this.ShowControl ? Visibility.Visible : Visibility.Hidden)
          .animation({ duration: 300, curve: Curve.Smooth })
        }

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
            Text(this.play_speed + 'x ⏩').fontColor($r('sys.color.white')).fontSize(15).fontWeight(FontWeight.Bold)
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
          .height(this.ShowControl ? '50%' : '80%')//触控区域
          .gesture(
            GestureGroup(GestureMode.Exclusive, // 将触摸事件跟滑动、长按分成两个手势组解绑互斥
              GestureGroup(GestureMode.Exclusive,
                TapGesture({ count: 2 })// 触摸事件手势组为互斥事件
                  .onAction((event: GestureEvent) => {
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
                  }),
                TapGesture({ count: 1 })// 单击事件
                  .onAction(() => {
                    this.ShowControl = !this.ShowControl
                  }),
                PanGesture({ fingers: 1, direction: PanDirection.Vertical })//垂直滑动
                  .onActionStart((event: GestureEvent) => {
                    const firstTouch = event.fingerList[0];
                    this.last_play_time = this.play_time;
                    this.swipe_start_y = firstTouch.localY;
                    this.isLeftSideSwipe = firstTouch.localX < this.screen_width / 2;
                    this.screenBrightnessTmp = this.screenBrightness
                    this.volumeTmp = this.volume
                  })
                  .onActionUpdate((event: GestureEvent) => {
                    if (this.isLock) {
                      return
                    }
                    const currentY = event.fingerList[0].localY; // 拖动后当前的位置
                    const deltaY = currentY - this.swipe_start_y; // 拖动后的垂直距离
                    const deltaYScale = deltaY / this.screen_height * 2.5 // 滑动像素占屏幕高度比例
                    if (this.isLeftSideSwipe) {
                      this.onSwipingBrightness = true
                      const newBrightness = this.screenBrightnessTmp - deltaYScale
                      this.screenBrightness = Math.min(Math.max(newBrightness, 0), 1)
                      VideoOperateUtil.setBrightness(this.screenBrightness);
                    } else {
                      this.onSwipingVoice = true
                      const newVolume = (this.volumeTmp - deltaYScale * 20);
                      this.volume =
                        Math.min(Math.max(newVolume, VideoOperateUtil.min_volume), VideoOperateUtil.max_volume);
                    }
                  })
                  .onActionEnd(() => {
                    this.onSwiping = false;
                    this.onSwipingVoice = false;
                    this.onSwipingBrightness = false;
                  }),
                PanGesture({ fingers: 1, direction: PanDirection.Horizontal })//水平滑动
                  .onActionStart((event: GestureEvent) => {
                    if (this.isLock) {
                      return
                    }
                    const firstTouch = event.fingerList[0];
                    this.swipe_start_x = firstTouch.localX;
                    this.swipe_start_y = firstTouch.localY;
                    this.last_play_time = this.play_time;
                    this.onSwiping = true
                  })
                  .onActionUpdate((event: GestureEvent) => {
                    if (event?.fingerList?.[0]?.localX !== undefined &&
                      typeof event.fingerList[0].localX === 'number') {
                      const currentX = event.fingerList[0].localX;
                      const deltaX = currentX - this.swipe_start_x;
                      this.play_time = Math.max(0,
                        Math.min(this.last_play_time + (deltaX * VideoOperateUtil.timePerPixel),
                          this.now_playing?.time));
                    }
                  })
                  .onActionEnd(() => {
                    this.mIjkMediaPlayer?.seekTo(String(this.play_time));
                    this.onSwiping = false;
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
              ),
              GestureGroup(GestureMode.Parallel, //长按事件
                LongPressGesture()
                  .onAction(() => {
                    this.long_press = true
                    this.last_speed = this.play_speed
                    this.play_speed = '3'
                    this.mIjkMediaPlayer?.setSpeed(this.play_speed)
                    this.currentSpeedIndex = VideoInfoUtil.video_speed_list.indexOf(3);
                  })
                  .onActionEnd(() => {
                    this.long_press = false
                    this.play_speed = this.last_speed
                    this.mIjkMediaPlayer?.setSpeed(this.last_speed);
                  }),
                PanGesture({ fingers: 1, direction: PanDirection.Horizontal })
                  .onActionStart((event: GestureEvent) => {
                    this.longPressStartX = event.fingerList[0].localX;
                  })
                  .onActionUpdate((event: GestureEvent) => {
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
                  })
              )))
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
      await (await this.windowClass).setWindowKeepScreenOn(false)
      await (await this.windowClass).setSpecificSystemBarEnabled('status', true)
      await (await this.windowClass).setSpecificSystemBarEnabled('navigationIndicator', true)
      await (await this.windowClass).setPreferredOrientation(window.Orientation.AUTO_ROTATION_RESTRICTED);
      if (this.now_playing?.time === 0) {
        this.now_playing.time = this.total_time; // 若系统无法识别视频时长，则由 FFMpeg API 提供以保存记忆时间
      }
      if (this.video_meta_data.length > 0 && this.play_time > 0) {
        await VideoOperateUtil.saveVideoTime(this.play_time, this.now_playing!, this.video_meta_data,
          PathUtils.appContext!,
          this.file_folder)
      }
      this.mDestroyPage = true;
      this.mIjkMediaPlayer?.setScreenOnWhilePlaying(false);
      if (this.CONTROL_PlayStatus != PlayStatus.INIT) {
        this.stop();
      }
      this.mIjkMediaPlayer?.off('audioInterrupt');
      if (this.allowBackgroundPlay) {
        AVSessionUtil.destroySession()
        PermissionUtil.stopContinuousTask()
      }
    }).hideTitleBar(true)
  }

  @Builder
  VideoTop() {
    Row() {
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
            this.mIjkMediaPlayer?.seekTo(seekValue + "");
            this.setProgress()
            this.onSwiping = false
            this.isSliderPlayTimeChange = false
          }
        })
        .layoutWeight(1)
        .animation({ duration: 100, curve: Curve.Smooth })
        .selectedColor('#e0e0e0')
      if (this.screen_width > this.screen_height) {
        Row() {
          Text(TimeUtil.convertMsToMMSS(Math.min(Math.max((this.total_time || 0) - this.play_time, 0),
            (this.total_time || 0))))
            .fontWeight(FontWeight.Medium).fontSize(15)
            .fontColor($r('sys.color.white'))
        }.backgroundColor('#50000000').padding(5).borderRadius(10).margin({ right: 5 })
      }
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
          this.screen_height > this.screen_width ?
          (await (this.windowClass)).setPreferredOrientation(window.Orientation.AUTO_ROTATION_LANDSCAPE)
            : (await (this.windowClass)).setPreferredOrientation(window.Orientation.AUTO_ROTATION_PORTRAIT)
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
    await (await this.windowClass).setSpecificSystemBarEnabled('status', this.ShowControl)
    await (await this.windowClass).setSpecificSystemBarEnabled('navigationIndicator', this.ShowControl)
  }

  onPageShow() {
    if (this.mContext && !this.playing) {
      this.startPlayOrResumePlay();
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
    let audioVolumeManger: audio.AudioVolumeManager = audioManager.getVolumeManager();
    let volumeList = await VideoOperateUtil.getVolume(audioVolumeManger, groupId)
    this.volume = volumeList.get('volume')!
    await (await this.windowClass).setPreferredOrientation(window.Orientation.AUTO_ROTATION_RESTRICTED);
    await (await this.windowClass).setWindowKeepScreenOn(true)
    let event: Callback<InterruptEvent> = (event) => {
      //  LogUtils.getInstance().LOGI(`event: ${JSON.stringify(event)}`);
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
      //  LogUtils.getInstance().LOGI(`deviceChange event: ${JSON.stringify(event)}`);
      if (event.reason === DeviceChangeReason.REASON_OLD_DEVICE_UNAVAILABLE) { // 音频设备断开连接
        this.pause();
      }
    }
    this.mIjkMediaPlayer?.on('deviceChange', deviceChangeEvent);
    settings.getValue(PathUtils.appContext!, settings.display.SCREEN_BRIGHTNESS_STATUS,
      settings.domainName.DEVICE_SHARED)
      .then((value) => {
        this.screenBrightness = Number(value) / 255;
      })
  }

  async aboutToDisappear() {
    //    LogUtils.getInstance().LOGI("aboutToDisappear");
    this.mIjkMediaPlayer = null
    VideoOperateUtil.setBrightness(-1)
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
      this.mIjkMediaPlayer?.seekTo(seekValue + "");
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
        if (this.now_playing?.last_play! < this.total_time * 0.9 && this.now_playing?.last_play != 0) {
          this.mIjkMediaPlayer?.seekTo(this.now_playing?.last_play! + '')
        } else if (this.skipIntroTime !== '0' && Number(this.skipIntroTime) * 1000 < this.now_playing?.time! &&
          !VideoInfoUtil.support_audio_format.includes(this.now_playing?.title.split('.')[this.now_playing?.title.split('.')
            .length-1].toLowerCase()!)) {
          this.mIjkMediaPlayer?.seekTo(this.play_time + Number(this.skipIntroTime) * 1000 + '')
        }
      }, 600)
    }
    if (this.CONTROL_PlayStatus == PlayStatus.PAUSE) {
      this.mIjkMediaPlayer?.start();
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
        // LogUtils.getInstance().LOGI("OnBufferingUpdateListener-->go:" + percent);
        // let MediaInfo = this.mIjkMediaPlayer?.getMediaInfo()
        // LogUtils.getInstance().LOGI('getMediaInfo---' + MediaInfo);
        // let VideoWidth = this.mIjkMediaPlayer?.getVideoWidth()
        // LogUtils.getInstance().LOGI('getVideoWidth---' + VideoWidth);
        // let VideoHeight = this.mIjkMediaPlayer?.getVideoHeight()
        // LogUtils.getInstance().LOGI('getVideoHeight---' + VideoHeight);
        // let VideoSarNum = this.mIjkMediaPlayer?.getVideoSarNum()
        // LogUtils.getInstance().LOGI('getVideoSarNum---' + VideoSarNum);
        // let VideoSarDen = this.mIjkMediaPlayer?.getVideoSarDen()
        // LogUtils.getInstance().LOGI('getVideoSarDen---' + VideoSarDen);
        // let AudioSessionId = this.mIjkMediaPlayer?.getAudioSessionId()
        // LogUtils.getInstance().LOGI('getAudioSessionId---' + AudioSessionId);
        // let Looping = this.mIjkMediaPlayer?.isLooping()
        // LogUtils.getInstance().LOGI('isLooping---' + Looping);
      }
    }
    this.mIjkMediaPlayer?.setOnBufferingUpdateListener(mOnBufferingUpdateListener);
    let mOnSeekCompleteListener: OnSeekCompleteListener = {
      onSeekComplete: () => {
        //  LogUtils.getInstance().LOGI("OnSeekCompleteListener-->go");
        that.startPlayOrResumePlay();
      }
    }
    this.mIjkMediaPlayer?.setOnSeekCompleteListener(mOnSeekCompleteListener);

    let mOnInfoListener: OnInfoListener = {
      onInfo: (what: number, extra: number) => {
        LogUtils.getInstance().LOGI("OnInfoListener-->go:" + what + "===" + extra);
      }
    }
    this.mIjkMediaPlayer?.setOnInfoListener(mOnInfoListener);

    let mOnErrorListener: OnErrorListener = {
      onError: (what: number, extra: number) => {
        this.stopProgressTask();
        //  LogUtils.getInstance().LOGI("OnErrorListener-->go:" + what + "===" + extra)
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
    //  LogUtils.getInstance().LOGI("getVideoWidth---" + VideoWidth);
    let VideoHeight = this.mIjkMediaPlayer?.getVideoHeight()!;
    //  LogUtils.getInstance().LOGI("getVideoHeight---" + VideoHeight);
    if (this.now_playing?.size[0] === 0 && VideoWidth !== 0) {
      this.now_playing.size[0] = VideoWidth
      this.now_playing.size[1] = VideoHeight
      VideoOperateUtil.saveVideoWeightAndHeight(this.now_playing, this.video_meta_data, PathUtils.appContext!,
        this.file_folder)
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