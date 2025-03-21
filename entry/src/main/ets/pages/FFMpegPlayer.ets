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
import { PlayStatus } from '../common/PlayStatus'
import DataSyncUtil from '../utils/DataSyncUtil'
import TimeUtil from '../utils/TimeUtil'
import ToolsUtil from '../utils/ToolsUtil'
import { router, window } from '@kit.ArkUI'
import { audio } from '@kit.AudioKit'
import PermissionUtil from '../utils/PermissionUtil'
import { common } from '@kit.AbilityKit'
import AVSessionUtil, { avSessionState } from '../utils/AVSessionUtil'
import { avSession as avSessionManager } from '@kit.AVSessionKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import VideoOperateUtil from '../utils/VideoOperateUtil'
import VideoInfoUtil, { VideoMetadataFromPlayer } from '../utils/VideoInfoUtil'
import PreferencesUtil from '../utils/PreferencesUtil'

const context = getContext() as common.UIAbilityContext;

@Entry
@Component
struct EnhancePlayer {
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
  @State playSpeed: string = '1f';
  now_playing: VideoMetadataFromPlayer | undefined = undefined
  @State oldSeconds: number = 0;
  @State video_url: string = ''
  @State total_time: number = 0
  windowClass = window.getLastWindow(context)
  xComponentController: XComponentController = new XComponentController()
  @State @Watch('setScreen') ShowControl: boolean = false
  @StorageLink('allowBackgroundPlay') allowBackgroundPlay: boolean = true
  @StorageLink('allowPlayBackExist') allowPlayBackExist: boolean = false
  @State onSwiping: boolean = false
  @State long_press: boolean = false
  @State last_speed: string = '1f'
  @State swipe_start_x: number = 0
  @State isHorizontalSwiping: boolean = false
  @StorageLink('fastForwardSeconds') fastForwardSeconds: string = '15'
  private CONTROL_PlayStatus = PlayStatus.INIT;
  private mIjkMediaPlayer = IjkMediaPlayer.getInstance();

  build() {
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
            Text(TimeUtil.convertMsToMMSS(this.play_time) + '/' + TimeUtil.convertMsToMMSS(this.total_time))
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
            Row() {
              SymbolGlyph($r('sys.symbol.chevron_left'))// 返回图标
                .fontSize(40)
                .fontColor(['#f0f0f0'])
                .onClick(() => {
                  router.back()
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
          }.width('100%')
          .backgroundColor('#61000000')
          .padding({
            left: (this.screen_height > this.screen_width ? 5 : 5),
            right: 20,
            top: (this.screen_height > this.screen_width ? DataSyncUtil.getActuallyTopSafeHeight() : 5),
            bottom: 10
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
          .height(this.screen_height > this.screen_width ? '20%' : '25%')
          .width('100%')
          .padding(1)
        }.height('100%').width('100%')
      }
      .visibility(this.ShowControl ? Visibility.Visible : Visibility.Hidden)
      .animation({ duration: 300, curve: Curve.Smooth })

      if (this.long_press) {
        Stack({ alignContent: Alignment.BottomEnd }) { //快进提示
          Text('3.0x ⏩').fontColor($r('sys.color.white')).fontSize(15).fontWeight(FontWeight.Bold)
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
        .gesture(GestureGroup(GestureMode.Exclusive,
          TapGesture({ count: 2 })
            .onAction((event: GestureEvent) => {
              const tapX = event.fingerList[0].localX;
              const adjustWidth = this.screen_width / 5; // 计算五分之一宽度
              if (tapX < adjustWidth) { // 左侧1/5区域
                this.seekTo(String(this.play_time - Number(this.fastForwardSeconds) * 1000));
              } else if (tapX > adjustWidth * 4) { // 右侧1/5区域
                this.seekTo(String(this.play_time + Number(this.fastForwardSeconds) * 1000));
              } else { // 中间3/5区域
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
              this.mIjkMediaPlayer?.setSpeed('3f')
            })
            .onActionEnd(() => {
              this.long_press = false
              this.mIjkMediaPlayer?.setSpeed(this.last_speed);
            }),
          PanGesture().onActionStart((event: GestureEvent) => {
            const firstTouch = event.fingerList[0];
            this.swipe_start_x = firstTouch.localX;
            this.last_play_time = this.play_time;
          })
            .onActionUpdate((event: GestureEvent) => {
              if (event.fingerList.length === 1) {
                const currentX = event.fingerList[0].localX;
                const deltaX = currentX - this.swipe_start_x;
                if (Math.abs(deltaX) > 10) {
                  this.isHorizontalSwiping = true;
                  this.onSwiping = true
                }
                if (this.isHorizontalSwiping) {
                  const timePerPixel = 150; // 灵敏度控制
                  this.play_time = this.last_play_time + (deltaX * timePerPixel);
                }
              }
            })
            .onActionEnd(() => {
              if (this.isHorizontalSwiping) {
                this.seekTo(String(this.play_time));
              }
              this.isHorizontalSwiping = false; // 重置所有滑动状态
              this.onSwiping = false;
            })
        ))
    }
    .onAreaChange(async (_oldValue: Area, newValue: Area) => {
      this.screen_width = Math.floor(new Number(newValue.width).valueOf())
      this.screen_height = Math.floor(new Number(newValue.height).valueOf())
      this.getVideoSize()
    })
    .backgroundColor($r('sys.color.black'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
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
          this.onSwiping = true
          this.play_time = value
          this.mDestroyPage = false;
        })
        .onTouch((event) => {
          if (event.type == TouchType.Up) {
            let seekValue = this.play_time
            this.seekTo(seekValue + "");
            this.setProgress()
            this.onSwiping = false
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
          if (this.screen_height > this.screen_width) {
            (await (this.windowClass)).setPreferredOrientation(window.Orientation.AUTO_ROTATION_LANDSCAPE_RESTRICTED)
          } else {
            (await (this.windowClass)).setPreferredOrientation(window.Orientation.AUTO_ROTATION_PORTRAIT_RESTRICTED)
          }
        })
      }.span({ xs: 2, sm: 2, md: 2 })
    }.width('95%')
  }

  onBackPress(): boolean | void {
    if (this.ShowControl && !this.allowPlayBackExist) {
      this.ShowControl = false
      return true
    }
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
    let record = router.getParams() as Record<string, string>
    if (record) {
      this.now_playing = JSON.parse(record['metadata'])
    }
    this.allowBackgroundPlay =
      await PreferencesUtil.getPreferencesValue("sweet_video", "allowBackgroundPlay", true) as boolean
    if (this.allowBackgroundPlay) {
      PermissionUtil.startContinuousTask()
    }
    let groupId: number = audio.DEFAULT_VOLUME_GROUP_ID;
    let audioManager = audio.getAudioManager();
    let audioVolumeManger: audio.AudioVolumeManager = audioManager.getVolumeManager();
    this.setScreen()
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
  }

  async aboutToDisappear() {
    //    LogUtils.getInstance().LOGI("aboutToDisappear");
    this.mDestroyPage = true;
    this.mIjkMediaPlayer.setScreenOnWhilePlaying(false);
    if (this.CONTROL_PlayStatus != PlayStatus.INIT) {
      this.stop();
    }
    this.mIjkMediaPlayer.off('audioInterrupt');
    AVSessionUtil.destroySession()
    PermissionUtil.stopContinuousTask()
    await (await this.windowClass).setWindowKeepScreenOn(false)
    await (await this.windowClass).setSpecificSystemBarEnabled('status', true)
    await (await this.windowClass).setSpecificSystemBarEnabled('navigationIndicator', true)
    await (await this.windowClass).setPreferredOrientation(window.Orientation.AUTO_ROTATION_RESTRICTED);
  }

  updateSession() {
    let data: avSessionState = {
      playing: this.playing,
      duration: this.play_time
    }
    AVSessionUtil.updateSession(JSON.stringify(data))
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
      this.seekTo(seekValue + "");
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
    }
    if (this.CONTROL_PlayStatus == PlayStatus.PAUSE) {
      this.mIjkMediaPlayer.start();
      this.setProgress()
    }
    if (!this.avSession && this.allowBackgroundPlay) {
      this.avSession = await AVSessionUtil.getAVSession()
      await this.setSessionListener()
      AVSessionUtil.setSessionInfo(JSON.stringify(this.now_playing))
      this.updateSession()
    }
    this.updateSession()
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
    // 204800 943718400
    this.mIjkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "overlay-format", "SDL_FCC_RV32")
    //停止预读的最小帧数
    this.mIjkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "min-frames", "120");
    //启动预加载
    this.mIjkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "start-on-prepared", "1");
    // 设置缓冲，这是播放器的缓冲区
    this.mIjkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "videotoolbox", "1"); // 用硬件解码

    this.mIjkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "packet-buffering", "5");
    //跳帧处理,放CPU处理较慢时，进行跳帧处理，保证播放流程，画面和声音同步
    this.mIjkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "framedrop", "5");
    this.mIjkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "mediacodec-all-videos", "1");
    this.mIjkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "mediacodec-hevc", "1");
    this.mIjkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "mediacodec-sync", "1");
    this.mIjkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "mediacodec-auto-rotate", "1");
    this.mIjkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "mediacodec-handle-resolution-change", "1");
    this.mIjkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "skip_loop_filter", "48");
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
    this.updateSession()
  }

  private stop() {
    this.updateSession()
    this.CONTROL_PlayStatus = PlayStatus.INIT;
    this.mIjkMediaPlayer.stop();
    this.mIjkMediaPlayer.release();
    this.stopProgressTask();
  }

  private seekTo(value: string) {
    this.mIjkMediaPlayer.seekTo(value);
  }

  private getVideoSize() {
    let VideoWidth = this.mIjkMediaPlayer.getVideoWidth();
    //  LogUtils.getInstance().LOGI("getVideoWidth---" + VideoWidth);
    let VideoHeight = this.mIjkMediaPlayer.getVideoHeight();
    //  LogUtils.getInstance().LOGI("getVideoHeight---" + VideoHeight);
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