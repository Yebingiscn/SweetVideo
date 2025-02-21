import { media } from '@kit.MediaKit';
import AVPlayerUtil from '../utils/AVPlayerUtil';
import DataSyncUtil from '../utils/DataSyncUtil';
import { fileUri, fileIo as fs } from '@kit.CoreFileKit';
import PermissionUtil from '../utils/PermissionUtil';
import { common } from '@kit.AbilityKit';
import { router, window } from '@kit.ArkUI';
import { avSession as avSessionManager } from '@kit.AVSessionKit';
import AVSessionUtil, { avSessionState } from '../utils/AVSessionUtil';
import ToolsUtil from '../utils/ToolsUtil';
import VideoInfoUtil, { AudioTrack, VideoMetadata, VideoMetadataFromPlayer } from '../utils/VideoInfoUtil';
import TimeUtil from '../utils/TimeUtil';
import { audio, AVVolumePanel } from '@kit.AudioKit';
import { settings } from '@kit.BasicServicesKit';
import VideoOperateUtil, {
  BrightnessLandscape,
  BrightnessVertical,
  VolConfigLandscape,
  VolConfigVertical
} from '../utils/VideoOperateUtil';
import SelectFileUtil from '../utils/SelectFileUtil';
import { VideoDataSource } from '../utils/DataUtil';

@Extend(Button)
function buttonFancy(width: number | string, height: number | string) {
  .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
  .height(width)
  .width(height)
  .backgroundColor('#50000000')
}

const context = getContext() as common.UIAbilityContext;
const sandbox_path = getContext().filesDir + '/'

@Entry
@Component
struct Player {
  avPlayer: media.AVPlayer | undefined = undefined
  avSession: avSessionManager.AVSession | undefined = undefined;
  @State now_playing: VideoMetadataFromPlayer | undefined = undefined
  @State playing: boolean = false
  @State speed: number = 1.0
  @State last_speed: number = 1
  @State play_time: number = 0
  @State last_play_time: number = 0
  surfaceID: string = ''
  @State swipe_start_x: number = 0
  @State swipe_start_y: number = 0
  @State SwipeMovingY: number = 0
  seek_time: number | undefined = undefined
  @State long_press: boolean = false
  @State played: boolean = false
  @State @Watch('setScreen') showControl: boolean = false
  @State lock_rotation: boolean = false
  xComponentController: XComponentController = new XComponentController()
  windowClass = window.getLastWindow(context)
  @State screen_width: number = 0
  @State screen_height: number = 0
  @State play_area_height: number = 0
  @State play_area_width: number = 0
  @State onSwiping: boolean = false
  @State onSwipingVoice: boolean = false
  @State onSwipingBrightness: boolean = false
  @State isLeftSideSwipe: boolean = false
  @State isRightSideSwipe: boolean = false
  @State volume: number = 0
  @State max_volume: number = 0
  @State min_volume: number = 0
  @State screenBrightness: number = 0
  @State screenBrightnessAtFirst: number = 0
  @State windowClassTmp: window.Window | undefined = undefined;
  @State video_meta_data: VideoMetadata[] = []
  @State select_text: string | undefined = '原始比例'
  @State speed_show: number = 2
  @State circle_play: boolean = false
  @State audio_track: AudioTrack[] = []
  @State AudioTrackMenuBuilderState: boolean = false
  @State audio_track_select: number = 0
  @State sideBarStatusTmp: Visibility = Visibility.Hidden
  @State sideBarStatus: boolean = false
  @State isLock: boolean = false
  @State lockVisibility: boolean = false
  @State sub_title: string = ''
  @State sub_title_visibility: Visibility = Visibility.Visible
  @State isHorizontalSwiping: boolean = false
  @State isVerticalSwiping: boolean = false
  @State shouldPreventTap: boolean = false
  @State videoDataSource: IDataSource = new VideoDataSource([])
  private clearSubtitleTimer: number | null = null;
  private listScroller: Scroller = new Scroller();

  onBackPress(): boolean | void {
    if (this.showControl) {
      this.showControl = false
      this.lockVisibility = false
      return true
    } else {
      this.avPlayer?.reset()
      return false
    }
  }

  async setSessionListener() {
    this.avSession?.on('play', () => {
      this.avPlayer?.play()
    });
    this.avSession?.on('pause', () => {
      this.avPlayer?.pause()
    });
    this.avSession?.on('seek', (position: number) => {
      this.avPlayer?.seek(position)
    })
    this.avSession?.on('fastForward', () => {
      this.avPlayer?.seek(this.play_time + 15000, media.SeekMode.SEEK_CLOSEST)
    })
    this.avSession?.on('rewind', () => {
      this.avPlayer?.seek(this.play_time - 15000)
    })
  }

  async setScreen() {
    await (await this.windowClass).setSpecificSystemBarEnabled('status', this.showControl)
    await (await this.windowClass).setSpecificSystemBarEnabled('navigationIndicator', this.showControl)
  }

  async aboutToAppear(): Promise<void> {
    let record = router.getParams() as Record<string, string>
    if (record) {
      this.now_playing = JSON.parse(record['metadata'])
      this.video_meta_data = JSON.parse(record['metadata_list']) as VideoMetadata[];
    }
    this.seek_time = this.now_playing?.last_play
    this.videoDataSource = new VideoDataSource(this.video_meta_data);
    PermissionUtil.startContinuousTask()
    this.setScreen()
    this.avPlayer = await AVPlayerUtil.getAVPlayer()
    await (await this.windowClass).setPreferredOrientation(window.Orientation.AUTO_ROTATION_RESTRICTED);
    await (await this.windowClass).setWindowKeepScreenOn(true)
    let groupId: number = audio.DEFAULT_VOLUME_GROUP_ID;
    let audioManager = audio.getAudioManager();
    let audioVolumeManger: audio.AudioVolumeManager = audioManager.getVolumeManager();
    let volume_list = await VideoOperateUtil.getVolume(audioVolumeManger, groupId)
    this.volume = volume_list.get('volume')!
    this.max_volume = volume_list.get('max_volume')!
    this.min_volume = volume_list.get('min_volume')!
    settings.getValue(context, settings.display.SCREEN_BRIGHTNESS_STATUS, settings.domainName.DEVICE_SHARED)
      .then((value) => {
        this.screenBrightness = Number(value) / 255;
        this.screenBrightnessAtFirst = this.screenBrightness
      })
  }

  async aboutToDisappear(): Promise<void> {
    if (this.screenBrightness != this.screenBrightnessAtFirst) {
      VideoOperateUtil.setBrightness(this.screenBrightnessAtFirst)
    }
    AVSessionUtil.destroySession()
    PermissionUtil.stopContinuousTask()
    await (await this.windowClass).setWindowKeepScreenOn(false)
    await (await this.windowClass).setSpecificSystemBarEnabled('status', true)
    await (await this.windowClass).setSpecificSystemBarEnabled('navigationIndicator', true)
    await (await this.windowClass).setPreferredOrientation(window.Orientation.AUTO_ROTATION_RESTRICTED);
  }

  async setRotation() {
    if (!this.now_playing) {
      return
    }
    const nowWidth = this.now_playing.size[0];
    const nowHeight = this.now_playing.size[1];
    const aspectRatioNow = nowWidth / nowHeight;
    const screenAspectRatio = this.screen_width / this.screen_height;
    if (aspectRatioNow > screenAspectRatio) {
      this.play_area_width = this.screen_width;
      this.play_area_height = this.play_area_width * (nowHeight / nowWidth);
    } else {
      this.play_area_height = this.screen_height;
      this.play_area_width = this.play_area_height * (nowWidth / nowHeight);
    }
  }

  async getAudioTrack() {
    this.audio_track = await VideoInfoUtil.getAudioTracks(this.avPlayer!)
    VideoOperateUtil.audioTrackErrorExecute(this.audio_track)
    this.avPlayer!.selectTrack(this.audio_track[0].index);
  }

  async setAVPlayerCallback() {
    this.avPlayer?.on('timeUpdate', (duration) => {
      if (!this.onSwiping) {
        animateTo({ duration: 300, curve: Curve.Ease }, () => {
          this.play_time = duration
        })
      }
      DataSyncUtil.last_time = duration
    })

    this.avPlayer?.on('seekDone', (percent) => {
      this.play_time = percent
      this.updateSession()
    })

    this.avPlayer?.on('speedDone', (speed) => {
      this.speed = VideoInfoUtil.getVideoSpeed(parseFloat(speed.toFixed(2)))
      this.speed_show = VideoInfoUtil.getVideoSpeedShow(this.speed)
    })

    this.avPlayer?.on('audioOutputDeviceChangeWithInfo', (data: audio.AudioStreamDeviceChangeInfo) => {
      if (data.changeReason === audio.AudioStreamDeviceChangeReason.REASON_OLD_DEVICE_UNAVAILABLE) {
        this.avPlayer?.pause()
      }
    });

    this.avPlayer?.on('subtitleUpdate', async (info: media.SubtitleInfo) => {
      if (this.clearSubtitleTimer !== null) {
        clearTimeout(this.clearSubtitleTimer);
        this.clearSubtitleTimer = null;
      }
      if (info) {
        const text = info.text ?? '';
        const duration = info.duration ?? 0;
        this.sub_title = text;
        if (duration > 0) {
          this.clearSubtitleTimer = setTimeout(() => {
            this.sub_title = '';
          }, duration) as number;
        }
      } else {
        this.sub_title = '';
        console.info('subtitleUpdate info is null');
      }
    });

    this.avPlayer?.on('stateChange', async (state) => {
      switch (state) {
        case 'initialized':
          if (this.avPlayer) {
            this.avPlayer.surfaceId = this.surfaceID
            this.avPlayer.prepare();
          }
          break;
        case 'prepared':
          await this.getAudioTrack()
          this.avPlayer?.play();
          break;
        case 'completed':
          if (this.circle_play) {
            this.avPlayer?.play()
            this.avPlayer?.seek(0)
          } else {
            this.playNextVideo()
          }
          break;
        case 'playing':
          this.played = true
          this.playing = true
          if (this.seek_time) {
            this.avPlayer?.seek(this.seek_time)
            this.seek_time = undefined
          }
          if (!this.avSession) {
            this.avSession = await AVSessionUtil.getAVSession()
            await this.setSessionListener()
            AVSessionUtil.setSessionInfo(JSON.stringify(this.now_playing))
            this.updateSession()
          }
          this.updateSession()
          break
        case 'paused':
          this.playing = false
          this.updateSession()
          break
        case 'released':
          this.playing = false
          this.updateSession()
          break
        case 'idle':
          break;
        case 'error':
          VideoOperateUtil.playErrorExecute(this.video_meta_data, this.now_playing?.date!)
          break;
      }
    })
  }

  async getData() {
    if (this.avPlayer) {
      this.setAVPlayerCallback()
      await PermissionUtil.activatePermission(this.now_playing?.uri || '')
      this.avPlayer.fdSrc = fs.openSync(this.now_playing?.uri);
      this.setRotation()
    }
  }

  updateSession() {
    let data: avSessionState = {
      playing: this.playing,
      duration: this.play_time
    }
    AVSessionUtil.updateSession(JSON.stringify(data))
  }

  async playChooseVideo(item: VideoMetadata) {
    await this.avPlayer?.reset()
    this.avPlayer = await AVPlayerUtil.getAVPlayer()
    this.now_playing = JSON.parse(JSON.stringify(item)) as VideoMetadataFromPlayer
    this.getData()
    this.avSession = await AVSessionUtil.getAVSession()
    await this.setSessionListener()
    AVSessionUtil.setSessionInfo(JSON.stringify(this.now_playing))
    this.updateSession()
  }

  playNextVideo() {
    let item = SelectFileUtil.getItem(this.video_meta_data, this.now_playing?.date || '') as VideoMetadata
    let next_item = SelectFileUtil.getNextItem(this.video_meta_data, item.date)
    this.playChooseVideo(next_item)
  }

  closeSideBar(isPlayAnimation: boolean) {
    this.sideBarStatusTmp = Visibility.Hidden
    isPlayAnimation ? setTimeout(() => {
      this.sideBarStatus = false
    }, 400) : this.sideBarStatus = false
  }

  openSideBar() {
    this.sideBarStatusTmp = Visibility.Visible
    this.sideBarStatus = true
  }

  build() {
    SideBarContainer(SideBarContainerType.Overlay) {
      List({ scroller: this.listScroller, space: 10 }) {
        LazyForEach(this.videoDataSource, (item: VideoMetadata) => {
          ListItem() {
            Column() {
              Row() {
                Image(fileUri.getUriFromPath(sandbox_path + item.date))
                  .width(60)
                  .height(90)
                  .backgroundImageSize(ImageSize.Cover)
                  .borderRadius(5)
                  .margin({ left: 5 })
                Text((String(SelectFileUtil.getItem(this.video_meta_data, item?.date)?.title)).slice(0,
                  String(SelectFileUtil.getItem(this.video_meta_data, item?.date)?.title).lastIndexOf('.')))
                  .fontSize(15)
                  .fontColor(this.now_playing?.date === SelectFileUtil.getItem(this.video_meta_data, item?.date)?.date
                    ? $r('app.color.main_color') : $r('app.color.text_color'))
                  .fontWeight(FontWeight.Medium)
                  .maxLines(4)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('65%')
                  .margin({ left: 5 })
                  .wordBreak(WordBreak.BREAK_ALL)
              }
              .onClick(async () => {
                this.playChooseVideo(item)
              })
              .margin({ top: 10 })
              .backgroundColor($r('app.color.list_item_background'))
              .width('100%')
              .height(this.screen_height > this.screen_width ? '15%' : '30%')
              .borderRadius(10)
              .clickEffect({ level: ClickEffectLevel.HEAVY, scale: 0.9 })
            }.visibility(VideoInfoUtil.videoWidthAndHeightFormat(String(SelectFileUtil.getItem(this.video_meta_data,
              item?.date)?.size)) !== '0 x 0' ? Visibility.Visible : Visibility.None)
          }
        }, (item: VideoMetadata) => item.date)
      }
      .onAppear(() => {
        this.listScroller.scrollToIndex(this.video_meta_data.findIndex(item =>
        this.now_playing?.date === SelectFileUtil.getItem(this.video_meta_data, item?.date)?.date))!
      })
      .gesture(SwipeGesture({ direction: SwipeDirection.Horizontal }).onAction((event: GestureEvent) => {
        if (event) {
          this.closeSideBar(true)
        }
      }))
      .visibility(this.sideBarStatusTmp)
      .width('100%')
      .backgroundColor($r('app.color.start_window_background'))
      .padding({ top: 50, left: 20, right: 20 })
      .transition(TransitionEffect.translate({ x: -200 })
        .animation({ duration: 500 }))
      .borderRadius(20)
      .shadow({
        radius: 15,
        color: $r('app.color.shadow_color'),
        offsetX: 0,
        offsetY: 0
      })

      Stack() {
        Stack() {
          Stack() { //播放器
            XComponent({ type: XComponentType.SURFACE, controller: this.xComponentController })
              .onLoad(() => {
                this.surfaceID = this.xComponentController.getXComponentSurfaceId()
                this.getData()
              })
          }
          .width(this.play_area_width)
          .height(this.play_area_height)
          .animation({ duration: this.played ? 300 : 0, curve: Curve.Ease })
        }
        .height('100%')
        .width('100%')

        Stack() {
          Flex({
            justifyContent: FlexAlign.SpaceBetween,
            alignItems: ItemAlign.Center,
            direction: FlexDirection.Column
          }) { //顶栏
            Flex({ justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Center }) {
              this.VideoTop()
            }
            .width('100%')
            .padding({
              left: (this.screen_height > this.screen_width ? 20 : 35),
              right: 20,
              top: (this.screen_height > this.screen_width ? DataSyncUtil.getActuallyTopSafeHeight() : 5),
              bottom: 10
            })
            .backgroundColor('#61000000')

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
            .margin({ bottom: this.screen_height > this.screen_width ? 0 : DataSyncUtil.bottomSafeHeight })
            .backgroundColor('#61000000')
          }.height('100%').width('100%')
        }
        .visibility(this.showControl && !this.isLock ? Visibility.Visible : Visibility.Hidden)
        .animation({ duration: 300, curve: Curve.Smooth })

        Stack({ alignContent: Alignment.BottomEnd }) { //字幕
          Text(this.sub_title)
            .fontColor($r('sys.color.white'))
            .fontSize(this.screen_width > this.screen_height ? 25 : 20)
            .fontWeight(FontWeight.Medium)
            .textAlign(TextAlign.Center)
        }
        .visibility(this.sub_title_visibility)
        .align(Alignment.Center)
        .width(this.play_area_width)
        .offset({ x: 0, y: this.play_area_height / 2 - 40 })
        .animation({ duration: 300, curve: Curve.Smooth })

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
        .visibility(this.long_press ? Visibility.Visible : Visibility.Hidden)
        .animation({ duration: 300, curve: Curve.Smooth })

        Stack() { //快进提示
          Text((this.play_time - this.last_play_time > 0 ? '+' : '') +
          Math.floor((this.play_time - this.last_play_time) / 1000) + 's')
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
        .visibility(this.onSwiping ? Visibility.Visible : Visibility.Hidden)
        .animation({ duration: 300, curve: Curve.Smooth })

        Stack() { //音量提示
          Column() {
            AVVolumePanel({
              volumeLevel: this.volume,
            }).visibility(Visibility.None)
            SymbolGlyph($r('sys.symbol.speaker_wave_1'))
              .fontSize(23)
              .fontColor(['#f0f0f0'])
            Slider({
              value: this.volume,
              min: this.min_volume,
              max: this.max_volume,
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
        .visibility(this.onSwipingVoice ? Visibility.Visible : Visibility.Hidden)
        .animation({ duration: 300, curve: Curve.Smooth })

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
        .visibility(this.onSwipingBrightness ? Visibility.Visible : Visibility.Hidden)
        .animation({ duration: 300, curve: Curve.Smooth })

        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph(this.isLock ? $r('sys.symbol.lock_fill') : $r('sys.symbol.lock_open_fill'))
            .fontWeight(FontWeight.Bold)
            .fontSize(30)
            .fontColor(['#f0f0f0'])
        }
        .zIndex(100)
        .buttonFancy(40, 40)
        .aspectRatio(1)
        .visibility(this.lockVisibility ? Visibility.Visible : Visibility.Hidden)
        .onClick(() => {
          this.isLock = !this.isLock
        })
        .position({ bottom: this.screen_height / 2, left: 30 })

        Column()
          .width('100%')
          .height('50%')//触控区域
          .onTouch((event: TouchEvent) => {
            if (!this.isLock) {
              if (event.type == TouchType.Down) {
                this.last_play_time = this.play_time; // 初始化触摸数据
                this.swipe_start_x = Math.floor(event.touches[0].x);
                this.swipe_start_y = Math.floor(event.touches[0].y);
                this.isHorizontalSwiping = false;
                this.isVerticalSwiping = false;
                this.isLeftSideSwipe = this.swipe_start_x < this.screen_width / 2; // 判断触摸区域
                this.isRightSideSwipe = !this.isLeftSideSwipe;
                this.shouldPreventTap = false; // 重置点击阻止标志
              }
              if (event.type == TouchType.Move) {
                const currentX = Math.floor(event.touches[0].x);
                const currentY = Math.floor(event.touches[0].y);
                const deltaX = Math.abs(currentX - this.swipe_start_x);
                const deltaY = Math.abs(currentY - this.swipe_start_y);
                if (!this.isHorizontalSwiping && deltaY > 10 && deltaX < 30) { // 优先处理垂直滑动
                  this.isVerticalSwiping = true;
                  this.shouldPreventTap = true;
                  const offsetY = currentY - this.swipe_start_y;
                  const isLandscape = this.screen_width > this.screen_height;
                  const volConfig = isLandscape ? ({ area: 20, step: 0.005 } as VolConfigLandscape) :
                    ({ area: 30, step: 0.01 } as VolConfigVertical);
                  const brightConfig = isLandscape ? ({ area: 15, step: 0.001 } as BrightnessLandscape) :
                    ({ area: 40, step: 0.001 } as BrightnessVertical);
                  if (this.isRightSideSwipe) {
                    const delta = ToolsUtil.calculateDelta(
                      offsetY,
                      volConfig.area,
                      volConfig.step,
                      offsetY < 0 ? 1 : -1
                    );
                    this.volume = Math.min(Math.max(this.volume + delta, 0.0), 15.0);
                    this.onSwipingVoice = true;
                  } else {
                    const delta = ToolsUtil.calculateDelta(// 亮度调节（保持较大步长）
                      offsetY,
                      brightConfig.area,
                      brightConfig.step,
                      offsetY < 0 ? 1 : -1
                    );
                    VideoOperateUtil.setBrightness(
                      this.screenBrightness = Math.min(Math.max(this.screenBrightness + delta, 0.0), 1.0)
                    );
                    this.onSwipingBrightness = true;
                  }
                  return;
                }
                if (!this.isVerticalSwiping && deltaX > 10 && deltaY < 5) { // 处理水平滑动
                  if (this.speed > 1) {
                    return;
                  }
                  this.isHorizontalSwiping = true;
                  this.shouldPreventTap = true;
                  const distance = currentX - this.swipe_start_x;
                  const sensitivity = this.screen_width / 150; // 动态灵敏度
                  const baseMultiplier = deltaX > 150 ? 100 : 70; // 提升基础倍率
                  this.play_time = this.last_play_time + (distance * baseMultiplier * sensitivity);
                  this.onSwiping = true;
                }
              }
              if (event.type == TouchType.Up) { // 处理滑动结束
                if (this.isHorizontalSwiping) {
                  this.avPlayer?.seek(this.play_time, media.SeekMode.SEEK_CLOSEST);
                } else if (this.long_press) {
                  this.long_press = false;
                  this.avPlayer?.setSpeed(VideoInfoUtil.getVideoSpeed(this.last_speed));
                }
                this.isHorizontalSwiping = false; // 重置所有滑动状态
                this.isVerticalSwiping = false;
                this.onSwiping = false;
                this.onSwipingVoice = false;
                this.onSwipingBrightness = false;
                setTimeout(() => { // 延迟重置点击阻止标志
                  this.shouldPreventTap = false;
                }, 300);
              }
            }
          })
          .gesture(LongPressGesture().onAction(() => {
            if (!this.isLock && !this.shouldPreventTap) {
              this.long_press = true;
              this.last_speed = this.speed;
              this.avPlayer?.setSpeed(VideoInfoUtil.getVideoSpeed(3));
            }
          }))
          .gesture(GestureGroup(GestureMode.Exclusive,
            TapGesture({ count: 2 })
              .onAction(() => {
                if (!this.isLock && !this.shouldPreventTap) {
                  this.playing ? this.avPlayer?.pause() : this.avPlayer?.play();
                }
              }),
            TapGesture({ count: 1 })
              .onAction(() => {
                if (this.shouldPreventTap) {
                  return;
                }
                if (this.sideBarStatus) {
                  this.closeSideBar(true);
                } else {
                  this.lockVisibility = !this.lockVisibility;
                  this.showControl = !this.showControl;
                }
              })
          ))
          .gesture(LongPressGesture().onAction(() => {
            if (!this.isLock) {
              this.long_press = true
              this.last_speed = this.speed
              this.avPlayer?.setSpeed(VideoInfoUtil.getVideoSpeed(3))
            }
          }))
          .gesture(GestureGroup(GestureMode.Exclusive,
            TapGesture({ count: 2 })
              .onAction(() => {
                if (!this.isLock) {
                  this.playing ? this.avPlayer?.pause() : this.avPlayer?.play()
                }
              }),
            TapGesture({ count: 1 })
              .onAction(() => {
                if (this.sideBarStatus) {
                  this.closeSideBar(true)
                } else {
                  this.lockVisibility = !this.lockVisibility;
                  this.showControl = !this.showControl
                }
              })
          ))
      }.onAreaChange(async (_oldValue: Area, newValue: Area) => {
        this.screen_width = Math.floor(new Number(newValue.width).valueOf())
        this.screen_height = Math.floor(new Number(newValue.height).valueOf())
        this.setRotation()
      }).backgroundColor($r('sys.color.black'))
    }
    .showControlButton(false)
    .divider({ strokeWidth: 0 })
    .onChange((value: boolean) => {
      this.sideBarStatus = value;
    })
    .sideBarWidth(250)
    .showSideBar(this.sideBarStatus)
    .divider({ strokeWidth: 0 })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  @Builder
  VideoTop() {
    SymbolGlyph($r('sys.symbol.chevron_left'))
      .fontSize(40)
      .fontColor(['#f0f0f0'])
      .onClick(() => {
        this.avPlayer?.reset()
        router.back()
      })
      .padding({ right: 10 })
    Row() {
      Text(String(this.now_playing?.title).slice(0, this.now_playing?.title.lastIndexOf('.')))
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .width(this.screen_width > this.screen_height ? '50%' : '60%')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.MARQUEE })
        .fontColor($r('sys.color.white'))
      Text(this.sub_title_visibility === Visibility.Visible ? '字幕开' : '字幕关')
        .fontSize(18)
        .fontColor(this.sub_title_visibility === Visibility.Visible ? $r('app.color.main_color') :
        $r('sys.color.white'))
        .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
        .width('9%')
        .visibility(this.screen_width > this.screen_height ? Visibility.Visible : Visibility.None)
        .onClick(() => {
          this.sub_title_visibility === Visibility.Visible ? this.sub_title_visibility = Visibility.None :
            this.sub_title_visibility = Visibility.Visible
        })
      Text('选择音轨')
        .fontSize(18)
        .fontColor($r('sys.color.white'))
        .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
        .width('10%')
        .bindMenu(this.AudioTrackMenuBuilder)
        .visibility(this.screen_width > this.screen_height ? Visibility.Visible : Visibility.None)
      Select([//屏幕扩展
        { value: '原始比例' },
        { value: '填满屏幕' }])
        .font({ size: 18, weight: FontWeight.Medium })
        .value(this.select_text)
        .selected(this.select_text == '填满屏幕' ? 1 : 0)
        .fontColor($r('sys.color.white'))
        .width('18%')
        .onSelect((_index: number, text?: string | undefined) => {
          this.select_text = text
          if (text === '填满屏幕') {
            this.play_area_height = this.screen_height
            this.play_area_width = this.screen_width
          } else {
            this.setRotation()
          }
        })
        .backgroundColor('#00000000')
        .menuBackgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THIN)
        .visibility(this.screen_width > this.screen_height ? Visibility.Visible : Visibility.None)

      Select([//倍速
        { value: '0.5x' },
        { value: '0.75x' },
        { value: '1.0x' },
        { value: '1.25x' },
        { value: '1.5x' },
        { value: '1.75x' },
        { value: '2.0x' },
        { value: '3.0x' }])
        .font({ size: 18, weight: FontWeight.Medium })
        .fontColor($r('sys.color.white'))
        .width(this.screen_height > this.screen_width ? '35%' : '14%')
        .selected(this.speed_show)
        .value(this.speed.toFixed(2) + 'x')
        .onSelect((_index: number, text?: string | undefined) => {
          this.avPlayer?.setSpeed(VideoInfoUtil.getVideoSpeed(parseFloat(text?.replace('x', '') || '1')))
        })
        .backgroundColor('#00000000')
        .menuBackgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THIN)
    }.height(this.screen_height > this.screen_width ? '5%' : '20%')

    Button({ type: ButtonType.Circle, stateEffect: true }) { // 旋转锁定
      SymbolGlyph(this.lock_rotation ? $r('sys.symbol.lock_fill') : $r('sys.symbol.rotate_left'))
        .fontSize(23)
        .fontColor(['#f0f0f0'])
        .symbolEffect(new ReplaceSymbolEffect(EffectScope.WHOLE), Number(this.lock_rotation))
    }
    .buttonFancy(35, 40)
    .onClick(async () => {
      this.lock_rotation = !this.lock_rotation
      const windowInstance = await this.windowClass
      const orientation = this.lock_rotation ?
        (this.screen_width > this.screen_height ? window.Orientation.AUTO_ROTATION_LANDSCAPE_RESTRICTED
          : window.Orientation.AUTO_ROTATION_PORTRAIT_RESTRICTED)
        : window.Orientation.AUTO_ROTATION_RESTRICTED
      await windowInstance.setPreferredOrientation(orientation)
      const toastMessage = this.lock_rotation
        ? getContext().resourceManager.getStringSync($r('app.string.open_rotation_lock'))
        : getContext().resourceManager.getStringSync($r('app.string.close_rotation_lock'))
      ToolsUtil.showToast(toastMessage);
    })
  }

  @Builder
  VideoSlider() {
    Row({ space: 10 }) {
      Text(TimeUtil.convertMsToMMSS(Math.min(Math.max(this.play_time, 0), (this.now_playing?.time || 0))) + '/' +
      TimeUtil.convertMsToMMSS(this.now_playing?.time || 0))
        .fontWeight(FontWeight.Medium)
        .fontSize(16)
        .fontColor($r('sys.color.white'))
      Slider({
        value: this.play_time,
        min: 0,
        max: this.now_playing?.time,
        style: SliderStyle.InSet
      })
        .onChange((value) => {
          this.play_time = value
          this.avPlayer?.seek(value)
        })
        .width(this.screen_width > this.screen_height ? '72%' : '55%')
        .animation({ duration: 100, curve: Curve.Smooth })
        .selectedColor('#e0e0e0')
      Text(TimeUtil.convertMsToMMSS(Math.min(Math.max((this.now_playing?.time || 0) - this.play_time, 0),
        (this.now_playing?.time || 0))))
        .fontWeight(FontWeight.Medium).fontSize(15)
        .fontColor($r('sys.color.white'))
        .visibility(this.screen_width > this.screen_height ? Visibility.Visible : Visibility.None)
    }
  }

  @Builder
  VideoButtons() {
    Row() {
      Row() {
        Button({ type: ButtonType.Circle, stateEffect: true }) { // 播放按钮
          SymbolGlyph(this.playing ? $r('sys.symbol.pause_fill') : $r('sys.symbol.play_fill'))
            .fontSize(30)
            .fontColor(['#f0f0f0'])
            .symbolEffect(new ReplaceSymbolEffect(EffectScope.WHOLE), Number(this.playing))
        }
        .buttonFancy(this.screen_height > this.screen_width ? 40 : 50, this.screen_height > this.screen_width ? 40 : 50)
        .onClick(() => {
          ToolsUtil.startVibration()
          this.playing ? this.avPlayer?.pause() : this.avPlayer?.play()
        })
      }.width(this.screen_height > this.screen_width ? '13%' : '10%')

      Row() {
        Button({ type: ButtonType.Circle, stateEffect: true }) { // 下一首按钮
          SymbolGlyph($r('sys.symbol.forward_end_fill'))
            .fontSize(30)
            .fontColor(['#f0f0f0'])
        }
        .buttonFancy(40, 40)
        .onClick(() => {
          this.playNextVideo()
        })
      }.width(this.screen_height > this.screen_width ? '13%' : '10%')

      Row() {
        Button({ type: ButtonType.Circle, stateEffect: true }) { // 循环按钮
          SymbolGlyph(this.circle_play ? $r('sys.symbol.repeat') : $r('sys.symbol.order_play'))
            .fontSize(23)
            .fontColor(['#f0f0f0'])
        }
        .buttonFancy(40, 40)
        .onClick(() => {
          this.circle_play = !this.circle_play
        })
      }.width('10%').visibility(this.screen_height > this.screen_width ? Visibility.None : Visibility.Visible)


      Row() {
        Button({ type: ButtonType.Circle, stateEffect: true }) { // 后退按钮
          SymbolGlyph($r('sys.symbol.gobackward_15'))
            .fontSize(23)
            .fontColor(['#f0f0f0'])
        }
        .buttonFancy(40, 40)
        .onClick(() => {
          this.avPlayer?.seek(this.play_time - 15000)
        })
      }.width(this.screen_height > this.screen_width ? '13%' : '10%')

      Row() {
        Button({ type: ButtonType.Circle, stateEffect: true }) { // 亮度按钮
          SymbolGlyph($r('sys.symbol.sun_max'))
            .fontSize(23)
            .fontColor(['#f0f0f0'])
        }
        .buttonFancy(40, 40)
        .bindMenu(this.BrightnessBuilder())
      }.width(this.screen_height > this.screen_width ? '13%' : '10%')

      Row() {
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.speaker_wave_1'))
            .fontSize(23)
            .fontColor(['#f0f0f0'])
        }
        .buttonFancy(40, 40)
        .bindMenu(this.VolumeBuilder())
      }.width(this.screen_height > this.screen_width ? '13%' : '10%')

      Row() {
        Button({ type: ButtonType.Circle, stateEffect: true }) { // 快进按钮
          SymbolGlyph($r('sys.symbol.goforward_15'))
            .fontSize(23)
            .fontColor(['#f0f0f0'])
        }
        .buttonFancy(40, 40)
        .onClick(() => {
          this.avPlayer?.seek(this.play_time + 15000, media.SeekMode.SEEK_CLOSEST)
        })
      }.width(this.screen_height > this.screen_width ? '13%' : '10%')

      Row() {
        Button({ type: ButtonType.Circle, stateEffect: true }) { // 快进按钮
          SymbolGlyph($r('sys.symbol.goforward_30'))
            .fontSize(23)
            .fontColor(['#f0f0f0'])
        }
        .buttonFancy(40, 40)
        .onClick(() => {
          this.avPlayer?.seek(this.play_time + 30000, media.SeekMode.SEEK_CLOSEST)
        })
      }.width('10%').visibility(this.screen_height > this.screen_width ? Visibility.None : Visibility.Visible)

      Row() {
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          Text('选集')
            .fontSize(15)
            .fontColor($r('sys.color.white'))
        }
        .buttonFancy(40, 40)
        .onClick(() => {
          this.sideBarStatus ? this.closeSideBar(true) : this.openSideBar()
        })
      }.width(this.screen_height > this.screen_width ? '13%' : '10%')

      Row() {
        Button({ type: ButtonType.Circle, stateEffect: true }) { // 全屏按钮
          SymbolGlyph($r('sys.symbol.screen_rotation'))
            .fontSize(23)
            .fontColor(['#f0f0f0'])
        }
        .buttonFancy(40, 40)
        .onClick(async () => {
          this.screen_height > this.screen_width ?
          (await (this.windowClass)).setPreferredOrientation(window.Orientation.AUTO_ROTATION_LANDSCAPE)
            : (await (this.windowClass)).setPreferredOrientation(window.Orientation.AUTO_ROTATION_PORTRAIT)
        })
      }.width(this.screen_height > this.screen_width ? '13%' : '10%')
    }.width('95%')
  }

  @Builder
  AudioTrackMenuBuilder() {
    Flex({ direction: FlexDirection.Column, justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center }) {
      ForEach(this.audio_track, (item: AudioTrack, index: number) => {
        Row() {
          Text(`${item.index} : ${item.name}(${item.language})`)
            .fontSize(20)
            .width(150)
            .height(40)
            .fontColor(this.audio_track_select === index ? $r('app.color.main_color') : $r('app.color.text_color'))
        }
        .padding(10)
        .onClick(() => {
          this.AudioTrackMenuBuilderState = false;
          this.avPlayer!.selectTrack(item.index);
          this.audio_track_select = index;
        })

        if (index !== this.audio_track.length - 1) {
          Divider().height(2)
        }
      })
    }.width(150).onAppear(() => {
      VideoOperateUtil.audioTrackErrorExecute(this.audio_track)
    })
  }

  @Builder
  VolumeBuilder() {
    Flex({ direction: FlexDirection.Column, justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center }) {
      Row() {
        AVVolumePanel({
          volumeLevel: this.volume,
        })
      }.visibility(Visibility.None)

      Row() {
        Slider({
          value: this.volume,
          min: this.min_volume,
          max: this.max_volume,
          step: 0.1,
          style: SliderStyle.NONE,
          direction: Axis.Vertical,
          reverse: true
        })
          .width(40)
          .height(160)
          .selectedColor($r('app.color.main_color'))
          .trackColor(Color.Black)
          .trackThickness(40)
          .onChange((value) => {
            this.volume = value
          })
      }
    }.width(40)
  }

  @Builder
  BrightnessBuilder() {
    Flex({ direction: FlexDirection.Column, justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center }) {
      Stack() {
        Column() {
          Button({ type: ButtonType.Circle, stateEffect: true }) {
            SymbolGlyph($r('sys.symbol.undo'))
              .fontSize(20)
              .fontColor([$r('app.color.text_color')])
          }
          .buttonFancy(80, 40)
          .backdropBlur(150)
          .onClick(() => {
            VideoOperateUtil.setBrightness(this.screenBrightnessAtFirst)
          })

          Slider({
            value: this.screenBrightness,
            min: 0,
            max: 1,
            step: 0.1,
            style: SliderStyle.NONE,
            direction: Axis.Vertical,
            reverse: true
          })
            .width(40)
            .height(160)
            .selectedColor($r('app.color.main_color'))
            .trackColor(Color.Black)
            .trackThickness(40)
            .onChange((value) => {
              VideoOperateUtil.setBrightness(value)
            })
        }
      }.width(40)
    }
  }
}