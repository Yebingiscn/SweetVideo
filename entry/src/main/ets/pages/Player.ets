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
import SelectFileUtil from '../utils/SelectFileUtil';
import { VideoDataSource } from '../utils/DataUtil';
import VideoOperateUtil from '../utils/VideoOperateUtil';

@Extend(Button)
function buttonFancy(width: number | string, height: number | string) {
  .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
  .height(width)
  .width(height)
  .backgroundColor('#50000000')
}

const context = getContext() as common.UIAbilityContext;
const sandbox_path = getContext().filesDir + '/'
const sandbox_subtitle = getContext().filesDir + '/subtitle/'

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
  @State screenBrightness: number = 0
  @State screenBrightnessAtFirst: number = 0
  @State windowClassTmp: window.Window | undefined = undefined;
  @State video_meta_data: VideoMetadata[] = []
  @State select_text: string | undefined = '原始比例'
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
  @State isSliderPlayTimeChange: boolean = false
  @State videoDataSource: IDataSource = new VideoDataSource([])
  @StorageLink('allowBackgroundPlay') allowBackgroundPlay: boolean = true
  @StorageLink('fastForwardSeconds') fastForwardSeconds: string = '15'
  @StorageLink('subtitleSize') subtitleSize: string = '22'
  @StorageLink('allowPlayBackExist') allowPlayBackExist: boolean = false
  private clearSubtitleTimer: number | null = null;
  private listScroller: Scroller = new Scroller();
  private initPinchDistance: number = 0;

  onBackPress(): boolean | void {
    if (this.showControl && !this.allowPlayBackExist) {
      this.showControl = false
      this.lockVisibility = false
      return true
    } else {
      this.avPlayer?.release()
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
      try {
        this.now_playing = JSON.parse(record['metadata']) as VideoMetadataFromPlayer
        this.video_meta_data = JSON.parse(record['metadata_list']) as VideoMetadata[];
      } catch (e) {
        console.error(e)
      }
    }
    this.seek_time = this.now_playing?.last_play
    this.videoDataSource = new VideoDataSource(this.video_meta_data);
    if (this.allowBackgroundPlay) {
      PermissionUtil.startContinuousTask()
    }
    this.setScreen()
    await (await this.windowClass).setPreferredOrientation(window.Orientation.AUTO_ROTATION_RESTRICTED);
    await (await this.windowClass).setWindowKeepScreenOn(true)
    let groupId: number = audio.DEFAULT_VOLUME_GROUP_ID;
    let audioManager = audio.getAudioManager();
    let audioVolumeManger: audio.AudioVolumeManager = audioManager.getVolumeManager();
    let volume_list = await VideoOperateUtil.getVolume(audioVolumeManger, groupId)
    this.volume = volume_list.get('volume')!
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
    if (this.allowBackgroundPlay) {
      AVSessionUtil.destroySession()
      PermissionUtil.stopContinuousTask()
    }
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
    VideoInfoUtil.play_area_width = this.play_area_width
    VideoInfoUtil.play_area_height = this.play_area_height
  }

  async getAudioTrack() {
    this.audio_track = await VideoInfoUtil.getAudioTracks(this.avPlayer!)
    if (VideoOperateUtil.audioTrackErrorExecute(this.audio_track)) {
      this.avPlayer!.selectTrack(this.audio_track[0].index);
    }
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
          this.avPlayer?.setSpeed(VideoInfoUtil.getVideoSpeed(this.speed))
          this.showControl = false
          this.lockVisibility = false
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
          if (!this.avSession && this.allowBackgroundPlay) {
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
          this.avPlayer?.release()
          break;
        case 'error':
          VideoOperateUtil.playErrorExecute(this.video_meta_data, this.now_playing?.date!)
          this.avPlayer?.release()
          break;
      }
    })
  }

  async setExternalSubtitle(now_playing: VideoMetadataFromPlayer) {
    if (await SelectFileUtil.isSubtitleExist(sandbox_subtitle, now_playing.date!)) {
      let file1 = fs.openSync(sandbox_subtitle + now_playing.date, fs.OpenMode.READ_ONLY)
      const size = fs.statSync(sandbox_subtitle + now_playing.date);
      this.avPlayer?.addSubtitleFromFd(file1.fd, 0, size.size);
    }
  }

  async getData() {
    this.avPlayer = await AVPlayerUtil.getAVPlayer()
    if (this.avPlayer) {
      this.setAVPlayerCallback()
      await PermissionUtil.activatePermission(this.now_playing?.uri || '')
      this.avPlayer.fdSrc = fs.openSync(this.now_playing?.uri);
      await this.setExternalSubtitle(this.now_playing!)
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
    this.now_playing = JSON.parse(JSON.stringify(item)) as VideoMetadataFromPlayer
    this.getData()
    this.avSession = await AVSessionUtil.getAVSession()
    await this.setSessionListener()
    AVSessionUtil.setSessionInfo(JSON.stringify(this.now_playing))
    this.updateSession()
  }

  playNextVideo() {
    if (this.video_meta_data.length > 0) {
      let item = SelectFileUtil.getItem(this.video_meta_data, this.now_playing?.date || '') as VideoMetadata
      let next_item = SelectFileUtil.getNextItem(this.video_meta_data, item.date)
      this.playChooseVideo(next_item!)
    }
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

  calcFingerDistance(f1: FingerInfo, f2: FingerInfo): number {
    const dx = f2.localX - f1.localX;
    const dy = f2.localY - f1.localY;
    return Math.sqrt(dx * dx + dy * dy);
  }

  build() {
    SideBarContainer(SideBarContainerType.Overlay) {
      List({ scroller: this.listScroller, space: 10 }) {
        LazyForEach(this.videoDataSource, (item: VideoMetadata) => {
          ListItem() {
            if (VideoInfoUtil.videoWidthAndHeightFormat(String(SelectFileUtil.getItem(this.video_meta_data,
              item?.date)?.size)) !== '0 x 0') {
              Column() {
                Row() {
                  Image(fileUri.getUriFromPath(sandbox_path + item.date))
                    .width(60)
                    .height(90)
                    .alt($r('app.media.sweet_video_src'))
                    .backgroundImageSize(ImageSize.Cover)
                    .borderRadius(5)
                    .margin({ left: 5 })
                    .autoResize(true)
                    .interpolation(ImageInterpolation.Low)
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
                .height(120)
                .borderRadius(10)
                .clickEffect({ level: ClickEffectLevel.HEAVY, scale: 0.9 })
              }
            }
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
      .transition(TransitionEffect.translate({ x: 200 }).animation({ duration: 500 }))
      .borderRadius(20)

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
              .backgroundColor('#61000000')
              .width('100%')
              .padding({
                left: (this.screen_height > this.screen_width ? 20 : 35),
                right: 20,
                top: (this.screen_height > this.screen_width ? DataSyncUtil.getActuallyTopSafeHeight() : 5),
                bottom: 5
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
              .height(this.screen_height > this.screen_width ? '20%' : '30%')
              .width('100%')
              .padding(1)
            }.height('100%').width('100%')
          }
          .animation({ duration: 300, curve: Curve.Smooth })
        }

        Stack({ alignContent: Alignment.BottomEnd }) { //字幕
          Text(this.sub_title)
            .fontColor('#F0F0F0')
            .fontSize(this.subtitleSize)
            .fontWeight(FontWeight.Medium)
            .textAlign(TextAlign.Center)
            .fontWeight(FontWeight.Normal)// 常规字重更清晰
            .opacity(0.95)// 轻微透明度
            .offset({
              x: 0,
              y: this.screen_width > this.screen_height && this.showControl ? -120 : 0
            })
        }
        .visibility(this.sub_title_visibility)
        .align(Alignment.Center)
        .width(this.play_area_width)
        .offset({ x: 0, y: VideoInfoUtil.play_area_height / 2 - 40 })
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
          .offset({ x: 0, y: 0 - VideoInfoUtil.play_area_height / 2 + 20 })
          .borderRadius(1000)
          .backgroundColor('#30000000')
          .backdropBlur(100)
          .animation({ duration: 300, curve: Curve.Smooth })
        }

        if (this.onSwiping) {
          Stack() {
            Text(this.isSliderPlayTimeChange ?
              TimeUtil.convertMsToMMSS(this.play_time) + '/' + TimeUtil.convertMsToMMSS(this.now_playing?.time) :
              (this.play_time - this.last_play_time > 0 ? '+' : '') +
              Math.floor((this.play_time - this.last_play_time) / 1000) + 's : ' +
              TimeUtil.convertMsToMMSS(this.play_time) + '/' + TimeUtil.convertMsToMMSS(this.now_playing?.time))
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

        if (this.lockVisibility) {
          Button({ type: ButtonType.Circle, stateEffect: true }) {
            SymbolGlyph(this.isLock ? $r('sys.symbol.lock_fill') : $r('sys.symbol.lock_open_fill'))
              .fontWeight(FontWeight.Bold)
              .fontSize(30)
              .fontColor(['#f0f0f0'])
          }
          .zIndex(100)
          .buttonFancy(40, 40)
          .aspectRatio(1)
          .onClick(() => {
            this.isLock = !this.isLock
          })
          .position({ bottom: this.screen_height / 2, left: this.screen_height > this.screen_width ? 30 : 50 })
        }

        Column()
          .width('100%')
          .height(this.showControl ? '50%' : '80%')//触控区域
          .gesture(GestureGroup(GestureMode.Exclusive,
            TapGesture({ count: 2 })
              .onAction((event: GestureEvent) => {
                if (!this.isLock) {
                  const tapX = event.fingerList[0].localX;
                  const quarterWidth = this.screen_width / 4; // 计算四分之一宽度
                  if (tapX < quarterWidth) { // 左侧1/4区域
                    this.avPlayer?.seek(this.play_time - Number(this.fastForwardSeconds) * 1000,
                      media.SeekMode.SEEK_CLOSEST);
                  } else if (tapX > quarterWidth * 3) { // 右侧1/4区域
                    this.avPlayer?.seek(this.play_time + Number(this.fastForwardSeconds) * 1000,
                      media.SeekMode.SEEK_CLOSEST);
                  } else { // 中间1/2区域
                    this.playing ? this.avPlayer?.pause() : this.avPlayer?.play();
                  }
                }
              }),
            PanGesture()
              .onActionStart((event: GestureEvent) => {
                if (!this.isLock) {
                  const firstTouch = event.fingerList[0];
                  this.swipe_start_x = firstTouch.localX;
                  this.swipe_start_y = firstTouch.localY;
                  this.last_play_time = this.play_time;
                  this.isLeftSideSwipe = firstTouch.localX < this.screen_width / 2;
                }
              })
              .onActionUpdate((event: GestureEvent) => {
                if (!this.isLock && event.fingerList.length === 1) {
                  const currentX = event.fingerList[0].localX;
                  const currentY = event.fingerList[0].localY;
                  // 方向判断阈值
                  const deltaX = currentX - this.swipe_start_x;
                  const deltaY = currentY - this.swipe_start_y;
                  // 初始化滑动方向
                  if (Math.abs(deltaY) > 10 && Math.abs(deltaX) < 10) {
                    this.isVerticalSwiping = true;
                  } else if (Math.abs(deltaX) > 10 && Math.abs(deltaY) < 10) {
                    this.isHorizontalSwiping = true;
                    this.onSwiping = true
                  }
                  // 垂直滑动处理
                  if (this.isVerticalSwiping) {
                    const volumeStep = 0.0001; // 每像素音量变化量
                    const brightnessStep = 0.00001; // 每像素亮度变化量
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
                  // 水平滑动处理
                  if (this.isHorizontalSwiping) {
                    const timePerPixel = 150; // 灵敏度控制
                    this.play_time = this.last_play_time + (deltaX * timePerPixel);
                  }
                }
              })
              .onActionEnd(() => {
                if (this.isHorizontalSwiping) {
                  this.avPlayer?.seek(this.play_time, media.SeekMode.SEEK_CLOSEST);
                }
                this.isHorizontalSwiping = false; // 重置所有滑动状态
                this.isVerticalSwiping = false;
                this.onSwiping = false;
                this.onSwipingVoice = false;
                this.onSwipingBrightness = false;
              }),
            TapGesture({ count: 1 })
              .onAction(() => {
                if (this.sideBarStatus) {
                  this.closeSideBar(true);
                } else {
                  this.lockVisibility = !this.lockVisibility;
                  this.showControl = !this.showControl;
                }
              }),
            LongPressGesture()
              .onAction(() => {
                if (!this.isLock) {
                  this.long_press = true
                  this.last_speed = this.speed
                  this.avPlayer?.setSpeed(VideoInfoUtil.getVideoSpeed(3))
                }
              })
              .onActionEnd(() => {
                this.long_press = false
                this.avPlayer?.setSpeed(VideoInfoUtil.getVideoSpeed(this.last_speed));
              }),
            PinchGesture({ fingers: 2, distance: 2 })
              .onActionStart((event: GestureEvent) => {
                const finger1 = event.fingerList[0];
                const finger2 = event.fingerList[1];
                this.initPinchDistance = this.calcFingerDistance(finger1, finger2);
              })
              .onActionUpdate((event: GestureEvent) => {
                if (!this.isLock) {
                  const finger1 = event.fingerList[0];
                  const finger2 = event.fingerList[1];
                  const currentDistance = this.calcFingerDistance(finger1, finger2);
                  const rawScale = currentDistance / this.initPinchDistance;
                  const adjustedScale = 1 + (rawScale - 1) * 0.005;
                  const clampedScale = Math.min(Math.max(adjustedScale, 0.5), 2.0);
                  this.play_area_width = Math.max(this.play_area_width * clampedScale, 0.5);
                  this.play_area_height = Math.max(this.play_area_height * clampedScale, 0.5);
                  animateTo({ duration: 100 }, () => {
                    this.play_area_width = this.play_area_width;
                    this.play_area_height = this.play_area_height;
                  });
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
    .showSideBar(this.sideBarStatus)
    .sideBarPosition(SideBarPosition.End)
    .divider({ strokeWidth: 0 })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  @Builder
  VideoTop() {
    Row({ space: 8 }) {
      SymbolGlyph($r('sys.symbol.chevron_left'))
        .fontSize(40)
        .fontColor(['#f0f0f0'])
        .onClick(() => {
          this.avPlayer?.reset()
          router.back()
        })
        .padding({ right: 5 })
      Row() {
        Text(String(this.now_playing?.title).slice(0, this.now_playing?.title.lastIndexOf('.')))
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.MARQUEE })
          .fontColor($r('sys.color.white'))
          .layoutWeight(1) // 关键布局属性
        Row({ space: 8 }) {
          Text(this.sub_title_visibility === Visibility.Visible ? '字幕开' : '字幕关')
            .fontSize(18)
            .fontColor(this.sub_title_visibility === Visibility.Visible ? $r('app.color.main_color') :
            $r('sys.color.white'))
            .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
            .onClick(() => {
              this.sub_title_visibility === Visibility.Visible ? this.sub_title_visibility = Visibility.None :
                this.sub_title_visibility = Visibility.Visible
            })
          if (this.screen_width > this.screen_height) {
            Text('选择音轨')
              .fontSize(18)
              .fontColor($r('sys.color.white'))
              .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
              .bindMenu(this.AudioTrackMenuBuilder)
          }
          if (this.screen_width > this.screen_height) {
            Select([//屏幕扩展
              { value: '原始比例' },
              { value: '填满屏幕' },
              { value: '等比放大 110%' },
              { value: '等比放大 120%' },
              { value: '等比放大 130%' },
              { value: '等比放大 140%' }])
              .font({ size: 18, weight: FontWeight.Medium })
              .value(this.select_text)
              .selected(VideoInfoUtil.screen_extend_map.indexOf(this.select_text!))
              .fontColor($r('sys.color.white'))
              .onSelect((_index: number, text?: string | undefined) => {
                this.select_text = text
                switch (text) {
                  case '填满屏幕':
                    this.play_area_height = this.screen_height;
                    this.play_area_width = this.screen_width;
                    break;
                  case '原始比例':
                    this.play_area_height = VideoInfoUtil.play_area_height
                    this.play_area_width = VideoInfoUtil.play_area_width
                    break;
                  default:
                    const scale = text ? VideoInfoUtil.scale_factors.get(text) : undefined;
                    if (scale) {
                      this.play_area_height = scale * VideoInfoUtil.play_area_height;
                      this.play_area_width = scale * VideoInfoUtil.play_area_width;
                    }
                    break;
                }
              })
              .backgroundColor('#00000000')
              .menuBackgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THIN)
          }
        }.alignItems(VerticalAlign.Center)
      }.height(this.screen_height > this.screen_width ? '5%' : '20%').layoutWeight(1)

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
    }.padding({ left: 8, right: 8 })
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  VideoSlider() {
    Row({ space: 10 }) {
      Row() {
        Text(TimeUtil.convertMsToMMSS(Math.min(Math.max(this.play_time, 0), (this.now_playing?.time || 0))) + '/' +
        TimeUtil.convertMsToMMSS(this.now_playing?.time || 0))
          .fontWeight(FontWeight.Medium)
          .fontSize(16)
          .fontColor($r('sys.color.white'))
          .textAlign(TextAlign.Start)
      }.backgroundColor('#50000000').padding(5).borderRadius(10).margin({ left: 5 })

      Slider({
        value: this.play_time,
        min: 0,
        max: this.now_playing?.time,
        style: SliderStyle.InSet
      })
        .onChange((value) => {
          this.onSwiping = true
          this.isSliderPlayTimeChange = true
          this.play_time = value
        })
        .onTouch((event) => {
          if (event.type == TouchType.Up) {
            this.avPlayer?.seek(this.play_time, media.SeekMode.SEEK_CLOSEST)
            this.isSliderPlayTimeChange = false
            this.onSwiping = false
          }
        })
        .layoutWeight(1)
        .animation({ duration: 100, curve: Curve.Smooth })
        .selectedColor('#e0e0e0')
      Row() {
        Text(TimeUtil.convertMsToMMSS(Math.min(Math.max((this.now_playing?.time || 0) - this.play_time, 0),
          (this.now_playing?.time || 0))))
          .fontWeight(FontWeight.Medium)
          .fontSize(15)
          .fontColor($r('sys.color.white'))
          .textAlign(TextAlign.End)
          .visibility(this.screen_width > this.screen_height ? Visibility.Visible : Visibility.None)
      }.backgroundColor('#50000000').padding(5).borderRadius(10).margin({ right: 5 })
    }
  }

  @Builder
  VideoButtons() {
    GridRow({ columns: this.screen_height > this.screen_width ? 8 : 16, gutter: 5 }) {
      GridCol() {
        Button({ type: ButtonType.Circle, stateEffect: true }) { // 播放按钮
          SymbolGlyph(this.playing ? $r('sys.symbol.pause_fill') : $r('sys.symbol.play_fill'))
            .fontSize(30)
            .fontColor(['#f0f0f0'])
            .symbolEffect(new ReplaceSymbolEffect(EffectScope.WHOLE), Number(this.playing))
        }
        .buttonFancy(this.screen_height > this.screen_width ? 40 : 50,
          this.screen_height > this.screen_width ? 40 : 50)
        .onClick(() => {
          ToolsUtil.startVibration()
          this.playing ? this.avPlayer?.pause() : this.avPlayer?.play()
        })
      }.span({ xs: 2, sm: 2, md: 2 })

      GridCol() {
        Button({ type: ButtonType.Circle, stateEffect: true }) { // 下一首按钮
          SymbolGlyph($r('sys.symbol.forward_end_fill'))
            .fontSize(23)
            .fontColor(['#f0f0f0'])
        }
        .buttonFancy(40, 40)
        .onClick(() => {
          this.playNextVideo()
        })
      }.span({ xs: 2, sm: 2, md: 2 })

      GridCol() {
        Button({ type: ButtonType.Circle, stateEffect: true }) { // 循环按钮
          SymbolGlyph(this.circle_play ? $r('sys.symbol.repeat') : $r('sys.symbol.order_play'))
            .fontSize(23)
            .fontColor(['#f0f0f0'])
        }
        .buttonFancy(40, 40)
        .onClick(() => {
          this.circle_play = !this.circle_play
        })
      }.span({ xs: 2, sm: 2, md: 2 })

      GridCol() {
        Button({ type: ButtonType.Circle, stateEffect: true }) { // 亮度按钮
          SymbolGlyph($r('sys.symbol.sun_max'))
            .fontSize(23)
            .fontColor(['#f0f0f0'])
        }
        .buttonFancy(40, 40)
        .bindMenu(this.BrightnessBuilder())
      }.span({ xs: 2, sm: 2, md: 2 })

      GridCol() {
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.speaker_wave_1'))
            .fontSize(23)
            .fontColor(['#f0f0f0'])
        }
        .buttonFancy(40, 40)
        .bindMenu(this.VolumeBuilder())
      }.span({ xs: 2, sm: 2, md: 2 })

      GridCol() {
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          Text('选集')
            .fontSize(15)
            .fontColor($r('sys.color.white'))
        }
        .buttonFancy(40, 40)
        .onClick(() => {
          this.sideBarStatus ? this.closeSideBar(true) : this.openSideBar()
        })
      }.span({ xs: 2, sm: 2, md: 2 })

      GridCol() {
        Select([//倍速
          { value: '0.25x' },
          { value: '0.5x' },
          { value: '0.75x' },
          { value: '1x' },
          { value: '1.25x' },
          { value: '1.5x' },
          { value: '1.75x' },
          { value: '2x' },
          { value: '3x' }])
          .font({ size: this.screen_height > this.screen_width ? 13 : 15, weight: FontWeight.Medium })
          .fontColor($r('sys.color.white'))
          .selected(VideoInfoUtil.speed_index_map.indexOf(this.speed))
          .value(VideoInfoUtil.optimizedFormat(this.speed))
          .onSelect((_index: number, text?: string | undefined) => {
            this.avPlayer?.setSpeed(VideoInfoUtil.getVideoSpeed(parseFloat(text?.replace('x', '') || '1')))
          })
          .backgroundColor('#00000000')
          .menuBackgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THIN)
      }.span({ xs: 2, sm: 2, md: 2 })


      GridCol() {
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
      }.span({ xs: 2, sm: 2, md: 2 })
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
          min: VideoOperateUtil.min_volume,
          max: VideoOperateUtil.max_volume,
          step: 0.1,
          style: SliderStyle.NONE,
          direction: Axis.Vertical,
          reverse: true
        })
          .width(40)
          .height(160)
          .selectedColor('#e0e0e0')
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
            .selectedColor('#e0e0e0')
            .trackColor(Color.Black)
            .trackThickness(40)
            .onChange((value) => {
              this.screenBrightness = value
              VideoOperateUtil.setBrightness(value)
            })
        }
      }.width(40)
    }
  }
}