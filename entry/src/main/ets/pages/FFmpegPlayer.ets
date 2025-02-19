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
import { VideoMetadataFromPlayer } from '../utils/VideoInfoUtil'

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
  @State playing: boolean = false
  @State mContext: object | undefined = undefined;
  private CONTROL_PlayStatus = PlayStatus.INIT;
  @State updateProgressTimer: number = 0;
  @State mDestroyPage: boolean = false;
  private mIjkMediaPlayer = IjkMediaPlayer.getInstance();
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
                }).padding({ right: 10 })
              Text(String(this.now_playing?.title).slice(0, this.now_playing?.title.lastIndexOf('.')))
                .fontSize(20)
                .fontWeight(FontWeight.Medium)
                .width('100%')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.MARQUEE })
                .fontColor($r('sys.color.white'))
            }
          }.width('100%')
          .padding({
            left: (this.screen_height > this.screen_width ? 5 : 5),
            right: 20,
            top: (this.screen_height > this.screen_width ? DataSyncUtil.getActuallyTopSafeHeight() : 5),
            bottom: 10
          }).backgroundColor('#61000000')

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
          .height(this.screen_height > this.screen_width ? '20%' : '25%')
          .width('100%')
          .padding(1)
          .margin({bottom: this.screen_height > this.screen_width ? 0 : DataSyncUtil.bottomSafeHeight})
          .backgroundColor('#61000000')
        }.height('100%').width('100%')
      }
      .visibility(this.ShowControl ? Visibility.Visible : Visibility.Hidden)
      .animation({ duration: 300, curve: Curve.Smooth })

      Column()
        .width('100%')
        .height('50%')//触控区域
        .gesture(GestureGroup(GestureMode.Exclusive,
          TapGesture({ count: 2 })
            .onAction(() => {
              if (!this.playing) {
                this.pause()
                this.playing = !this.playing
              } else {
                this.startPlayOrResumePlay();
                this.playing = !this.playing
              }
            }),
          TapGesture({ count: 1 })
            .onAction(() => {
              this.ShowControl = !this.ShowControl
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
      Text(TimeUtil.convertMsToMMSS(Math.min(Math.max(this.play_time, 0), (this.total_time || 0))) + '/' +
      TimeUtil.convertMsToMMSS(this.total_time || 0))
        .fontWeight(FontWeight.Medium)
        .fontSize(16)
        .fontColor($r('sys.color.white'))
      Slider({
        value: this.play_time,
        min: 0,
        max: this.total_time,
        style: SliderStyle.InSet
      })
        .onChange((value: number) => {
          this.play_time = value
          this.mDestroyPage = false;
          let seekValue = value
          this.seekTo(seekValue + "");
          this.setProgress()
        })
        .width(this.screen_width > this.screen_height ? '72%' : '50%')
        .animation({ duration: 100, curve: Curve.Smooth })
        .selectedColor('#e0e0e0')
      Text(TimeUtil.convertMsToMMSS(Math.min(Math.max((this.total_time || 0) - this.play_time, 0),
        (this.total_time || 0))))
        .fontWeight(FontWeight.Medium).fontSize(15)
        .fontColor($r('sys.color.white'))
    }
  }

  @Builder
  VideoButtons() {
    Row() {
      Row() {
        Row() {
          Button({ type: ButtonType.Circle, stateEffect: true }) { // 播放按钮
            SymbolGlyph(this.playing ? $r('sys.symbol.play_fill') : $r('sys.symbol.pause_fill'))
              .fontSize(30)
              .fontColor(['#f0f0f0'])
              .symbolEffect(new ReplaceSymbolEffect(EffectScope.WHOLE), Number(this.playing))
          }
          .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
          .height(50)
          .width(50)
          .backgroundColor('#50000000')
          .onClick(() => {
            ToolsUtil.startVibration()
            if (!this.playing) {
              this.pause()
              this.playing = !this.playing
            } else {
              this.startPlayOrResumePlay();
              this.playing = !this.playing
            }
          })
        }.width('30%')

        Row() {
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
        }.width('55%')
      }.width('40%')
    }.width('95%')
  }

  private initDelayPlay(context: object) {
    this.mContext = context;
    let that = this;
    setTimeout(() => {
      that.startPlayOrResumePlay();
      that.playing = false;
    }, 300)
  }

  private async startPlayOrResumePlay() {
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
    if (!this.avSession) {
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

  async setScreen() {
    await (await this.windowClass).setSpecificSystemBarEnabled('status', this.ShowControl)
    await (await this.windowClass).setSpecificSystemBarEnabled('navigationIndicator', this.ShowControl)
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
    LogUtils.getInstance()
      .LOGI("setProgress position:" + position + ",duration:" + duration + ",progressValue:" + pos);
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
    this.mIjkMediaPlayer.setVolume((this.volume / 15).toString(), (this.volume / 15).toString());
    //设置视频源
    this.mIjkMediaPlayer.setDataSource(this.video_url);
    //使用精确寻帧 例如，拖动播放后，会寻找最近的关键帧进行播放，很有可能关键帧的位置不是拖动后的位置，而是较前的位置.可以设置这个参数来解决问题
    this.mIjkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "enable-accurate-seek", "1");
    //预读数据的缓冲区大小
    this.mIjkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "max-buffer-size", "102400");
    // 204800 943718400
    this.mIjkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "overlay-format", "SDL_FCC_RV32")
    //停止预读的最小帧数
    this.mIjkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "min-frames", "120");
    //启动预加载
    this.mIjkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "start-on-prepared", "1");
    // 设置缓冲，这是播放器的缓冲区
    this.mIjkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "packet-buffering", "1");
    //跳帧处理,放CPU处理较慢时，进行跳帧处理，保证播放流程，画面和声音同步
    this.mIjkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "framedrop", "5");
    this.mIjkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "mediacodec-all-videos", "1");
    this.mIjkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "mediacodec-hevc", "1");
    this.mIjkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "mediacodec-sync", "1");
    this.mIjkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "mediacodec-auto-rotate", "1");
    this.mIjkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "mediacodec-handle-resolution-change", "1");
    this.mIjkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "skip_loop_filter", "48L");
    this.mIjkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_FORMAT, "analyzeduration", "100");
    this.mIjkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_FORMAT, "analyzemaxduration", '100L');
    this.mIjkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_FORMAT, "lush_packets", '1L');
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
        LogUtils.getInstance().LOGI("OnBufferingUpdateListener-->go:" + percent);
        let MediaInfo = this.mIjkMediaPlayer.getMediaInfo()
        LogUtils.getInstance().LOGI('getMediaInfo---' + MediaInfo);
        let VideoWidth = this.mIjkMediaPlayer.getVideoWidth()
        LogUtils.getInstance().LOGI('getVideoWidth---' + VideoWidth);
        let VideoHeight = this.mIjkMediaPlayer.getVideoHeight()
        LogUtils.getInstance().LOGI('getVideoHeight---' + VideoHeight);
        let VideoSarNum = this.mIjkMediaPlayer.getVideoSarNum()
        LogUtils.getInstance().LOGI('getVideoSarNum---' + VideoSarNum);
        let VideoSarDen = this.mIjkMediaPlayer.getVideoSarDen()
        LogUtils.getInstance().LOGI('getVideoSarDen---' + VideoSarDen);
        let AudioSessionId = this.mIjkMediaPlayer.getAudioSessionId()
        LogUtils.getInstance().LOGI('getAudioSessionId---' + AudioSessionId);
        let Looping = this.mIjkMediaPlayer.isLooping()
        LogUtils.getInstance().LOGI('isLooping---' + Looping);
      }
    }
    this.mIjkMediaPlayer.setOnBufferingUpdateListener(mOnBufferingUpdateListener);

    let mOnSeekCompleteListener: OnSeekCompleteListener = {
      onSeekComplete: () => {
        LogUtils.getInstance().LOGI("OnSeekCompleteListener-->go");
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
        LogUtils.getInstance().LOGI("OnErrorListener-->go:" + what + "===" + extra)
      }
    }

    this.mIjkMediaPlayer.setOnErrorListener(mOnErrorListener);
    this.mIjkMediaPlayer.setMessageListener();
    this.mIjkMediaPlayer.prepareAsync();
    this.mIjkMediaPlayer.start();
  }

  private pause() {
    if (this.mIjkMediaPlayer.isPlaying()) {
      this.mIjkMediaPlayer.pause();
      this.setProgress();
      this.mDestroyPage = true;
      this.CONTROL_PlayStatus = PlayStatus.PAUSE;
      this.updateSession()
    }
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

  onPageShow() {
    if (this.mContext && !this.playing) {
      this.startPlayOrResumePlay();
    }
  }

  async aboutToAppear() {
    LogUtils.getInstance().LOGI("aboutToAppear");
    let record = router.getParams() as Record<string, string>
    if (record) {
      this.now_playing = JSON.parse(record['metadata'])
    }
    PermissionUtil.startContinuousTask()
    let groupId: number = audio.DEFAULT_VOLUME_GROUP_ID;
    let audioManager = audio.getAudioManager();
    let audioVolumeManger: audio.AudioVolumeManager = audioManager.getVolumeManager();
    this.setScreen()
    let volumeList = await VideoOperateUtil.getVolume(audioVolumeManger, groupId)
    this.volume = volumeList.get('volume')!
    await (await this.windowClass).setPreferredOrientation(window.Orientation.AUTO_ROTATION_RESTRICTED);
    await (await this.windowClass).setWindowKeepScreenOn(true)
    let event: Callback<InterruptEvent> = (event) => {
      LogUtils.getInstance().LOGI(`event: ${JSON.stringify(event)}`);
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
      LogUtils.getInstance().LOGI(`deviceChange event: ${JSON.stringify(event)}`);
    if (event.reason === DeviceChangeReason.REASON_OLD_DEVICE_UNAVAILABLE) { // 音频设备断开连接
        this.pause();
      }
    }
    this.mIjkMediaPlayer.on('deviceChange', deviceChangeEvent);
  }

  async aboutToDisappear() {
    LogUtils.getInstance().LOGI("aboutToDisappear");
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
      this.playing = !this.playing
    });
    this.avSession?.on('pause', () => {
      this.pause()
      this.playing = !this.playing
    });
    this.avSession?.on('seek', (position: number) => {
      this.mDestroyPage = false;
      LogUtils.getInstance().LOGI("slider-->seekValue start:" + position);
      let seekValue = position;
      this.seekTo(seekValue + "");
      this.setProgress()
      LogUtils.getInstance().LOGI("slider-->seekValue end:" + seekValue);
    })
  }

  private getVideoSize() {
    let VideoWidth = this.mIjkMediaPlayer.getVideoWidth();
    LogUtils.getInstance().LOGI("getVideoWidth---" + VideoWidth);
    let VideoHeight = this.mIjkMediaPlayer.getVideoHeight();
    LogUtils.getInstance().LOGI("getVideoHeight---" + VideoHeight);
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