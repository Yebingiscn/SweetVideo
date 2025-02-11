import { media } from '@kit.MediaKit';
import AVPlayerUtil from '../utils/AVPlayerUtil';
import DataSyncUtil from '../utils/DataSyncUtil';
import { fileIo as fs } from '@kit.CoreFileKit';
import PermissionUtil from '../utils/PermissionUtil';
import { common } from '@kit.AbilityKit';
import { router, window } from '@kit.ArkUI';
import { avSession as avSessionManager } from '@kit.AVSessionKit';
import AVSessionUtil from '../utils/AVSessionUtil';
import ToolsUtil from '../utils/ToolsUtil';
import { hilog } from '@kit.PerformanceAnalysisKit';
import VideoSpeedUtil from '../utils/VideoInfoUtil';
import VideoInfoUtil, { VideoMetadata } from '../utils/VideoInfoUtil';
import TimeUtil from '../utils/TimeUtil';
import { audio, AVVolumePanel } from '@kit.AudioKit';
import { settings } from '@kit.BasicServicesKit';
import VideoOperateUtil from '../utils/VideoOperateUtil';
import SelectFileUtil from '../utils/SelectFileUtil';

interface VideoMetadataPlayer {
  uri: string
  title: string
  date: string,
  size: number[]
  time: number
  last_play: number
}

interface avSessionState {
  playing: boolean
  duration: number
}

const context = getContext() as common.UIAbilityContext;

@Entry
@Component
struct Player {
  avPlayer: media.AVPlayer | undefined = undefined
  avSession: avSessionManager.AVSession | undefined = undefined;
  @State now_playing: VideoMetadataPlayer | undefined = undefined
  @State playing: boolean = false
  @State speed: number = 1.0
  @State last_speed: number = 1
  @State play_time: number = 0
  @State last_play_time: number = 0
  surfaceID: string = ''
  @State SwipeStartX: number = 0
  @State SwipeMovingX: number = 0
  @State SwipeStartY: number = 0
  @State SwipeMovingY: number = 0
  seek_time: number | undefined = undefined
  @State LongPress: boolean = false
  @State played: boolean = false
  @State @Watch('setScreen') ShowControl: boolean = false
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
  @StorageLink('sideBarWidth') sideBarWidth: number = 0
  @StorageLink('isShow') isShow: boolean = false
  @State video_meta_data: VideoMetadata[] = []
  @State select_text: string | undefined = '原始比例'
  @State select_video: Visibility = Visibility.None
  @State speed_show: number = 2
  @State circle_play: boolean = false
  @State audio_track: number[] = []
  @State AudioTrackMenuBuilderState: boolean = false
  @State audio_track_select: number = 0

  @Builder
  AudioTrackMenuBuilder() {
    Flex({ direction: FlexDirection.Column, justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center }) {
      ForEach(this.audio_track, (index: number) => {
        if (index !== 0) {
          Row() {
            Text('音轨：' + index)
              .fontSize(20)
              .width(150)
              .height(40)
              .fontColor(this.audio_track_select === index ? $r('app.color.main_color') : $r('app.color.text_color'))
          }
          .padding(10)
          .onClick(() => {
            this.AudioTrackMenuBuilderState = false
            this.avPlayer!.selectTrack(this.audio_track[this.audio_track.indexOf(index)]);
            this.audio_track_select = index
          })
          if (this.audio_track.indexOf(index) !== this.audio_track.length - 1) {
            Divider().height(2)
          }
        }
      })
    }.width(150).onAppear(() => {
      ToolsUtil.startVibration()
      this.audio_track.length <= 1 ? ToolsUtil.showToast('视频未识别到音轨') : this.AudioTrackMenuBuilderState = true
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
          .selectedColor(Color.White)
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
          .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
          .height(40)
          .width(80)
          .backgroundColor($r('app.color.start_window_background_blur'))
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
            .selectedColor(Color.White)
            .trackColor(Color.Black)
            .trackThickness(40)
            .onChange((value) => {
              VideoOperateUtil.setBrightness(value)
            })
        }
      }.width(40)
    }
  }

  onBackPress(): boolean | void {
    if (this.ShowControl) {
      this.ShowControl = false
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
      this.avPlayer?.seek(this.play_time + 15000)
    })
    this.avSession?.on('rewind', () => {
      this.avPlayer?.seek(this.play_time - 15000)
    })
  }

  async setScreen() {
    await (await this.windowClass).setSpecificSystemBarEnabled('status', this.ShowControl)
    await (await this.windowClass).setSpecificSystemBarEnabled('navigationIndicator', this.ShowControl)
  }

  async aboutToAppear(): Promise<void> {
    let record = router.getParams() as Record<string, string>
    if (record) {
      this.now_playing = JSON.parse(record['metadata'])
      this.video_meta_data = JSON.parse(record['metadata_list']) as VideoMetadata[];
    }
    this.seek_time = this.now_playing?.last_play
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
      try {
        this.speed = VideoSpeedUtil.getVideoSpeed(parseFloat(speed.toFixed(2)))
        this.speed_show = VideoSpeedUtil.getVideoSpeedShow(this.speed)
      } catch (e) {
        hilog.error(777, 'testFlag', 'speed return undefined: ' + e)
      }
    })

    this.avPlayer?.on('stateChange', async (state) => {
      switch (state) {
        case 'initialized':
          if (this.avPlayer) {
            this.avPlayer.surfaceId = this.surfaceID
            this.avPlayer.prepare();
          }
          break;
        case 'prepared':
          this.audio_track = await VideoOperateUtil.getAudioTracks(this.avPlayer!) as number[]
          this.avPlayer!.selectTrack(this.audio_track[this.audio_track.length - 1]);
          this.audio_track_select = this.audio_track[this.audio_track.length - 1]
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
    this.now_playing = JSON.parse(JSON.stringify(item)) as VideoMetadataPlayer
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

  build() {
    SideBarContainer(SideBarContainerType.Overlay) {
      List() {
        ForEach(this.video_meta_data, (item: VideoMetadata) => {
          ListItem() {
            Column() {
              Row() {
                if (VideoInfoUtil.videoWidthAndHeightFormat(String(SelectFileUtil.getItem(this.video_meta_data,
                  item?.date)?.size)) !== '0 x 0') {
                  Text((String(SelectFileUtil.getItem(this.video_meta_data, item?.date)?.title)).slice(0,
                    String(SelectFileUtil.getItem(this.video_meta_data, item?.date)?.title).lastIndexOf('.')))
                    .fontSize(20)
                    .fontColor(this.now_playing?.date === SelectFileUtil.getItem(this.video_meta_data, item?.date)?.date
                      ? $r('app.color.main_color') : $r('sys.color.white'))
                    .fontWeight(FontWeight.Medium)
                    .maxLines(4)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .textAlign(TextAlign.Center)
                    .backgroundColor('#80393737')
                    .width('100%')
                    .height('25%')
                    .borderRadius(5)
                    .clickEffect({ level: ClickEffectLevel.HEAVY, scale: 0.9 })
                    .shadow({
                      radius: 5,
                      color: '#ffffffff',
                      offsetX: 0,
                      offsetY: 0
                    })
                }
              }.onClick(async () => {
                this.playChooseVideo(item)
              })
            }
          }
        })
      }

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
                  .width(this.screen_width > this.screen_height ? '60%' : '65%')
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.MARQUEE })
                  .fontColor($r('sys.color.white'))
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
                  .visibility(this.select_video =
                    this.screen_width > this.screen_height ? Visibility.Visible : Visibility.None)

                Select([//倍速
                  { value: '0.5x' },
                  { value: '0.75x' },
                  { value: '1.0x' },
                  { value: '1.25x' },
                  { value: '1.5x' },
                  { value: '2.0x' },
                  { value: '3.0x' }])
                  .font({ size: 18, weight: FontWeight.Medium })
                  .fontColor($r('sys.color.white'))
                  .width(this.screen_height > this.screen_width ? '35%' : '18%')
                  .selected(this.speed_show)
                  .value(this.speed.toFixed(2) + 'x')
                  .onSelect((_index: number, text?: string | undefined) => {
                    this.avPlayer?.setSpeed(VideoSpeedUtil.getVideoSpeed(parseFloat(text?.replace('x', '') || '1')))
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
              .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
              .height(40)
              .width(35)
              .backgroundColor('#00000000')
              .onClick(async () => {
                this.lock_rotation = !this.lock_rotation
                if (this.lock_rotation) {
                  ToolsUtil.showToast(getContext().resourceManager.getStringSync($r('app.string.open_rotation_lock')))
                  if (this.screen_width > this.screen_height) {
                    (await this.windowClass).setPreferredOrientation(window.Orientation.AUTO_ROTATION_LANDSCAPE_RESTRICTED)
                  } else {
                    (await this.windowClass).setPreferredOrientation(window.Orientation.AUTO_ROTATION_PORTRAIT_RESTRICTED)
                  }
                } else {
                  (await this.windowClass).setPreferredOrientation(window.Orientation.AUTO_ROTATION_RESTRICTED)
                  ToolsUtil.showToast(getContext().resourceManager.getStringSync($r('app.string.close_rotation_lock')))
                }
              })
            }
            .width('100%')
            .padding({
              left: (this.screen_height > this.screen_width ? 20 : 35),
              right: 20,
              top: (this.screen_height > this.screen_width ? DataSyncUtil.topSafeHeight : 5),
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
            .backgroundColor('#61000000')
          }.height('100%').width('100%')
        }
        .visibility(this.ShowControl ? Visibility.Visible : Visibility.Hidden)
        .animation({ duration: 300, curve: Curve.Smooth })

        Stack({ alignContent: Alignment.BottomEnd }) { //快进提示
          Text('3.0x').fontColor($r('sys.color.white')).fontSize(25).fontWeight(FontWeight.Bold)
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
        .visibility(this.LongPress ? Visibility.Visible : Visibility.Hidden)
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
              .selectedColor(Color.White)
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
              .selectedColor(Color.White)
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

        Column()
          .width('100%')
          .height('50%')//触控区域
          .onTouch((event: TouchEvent) => {
            if (event.type == TouchType.Down) {
              this.last_play_time = this.play_time;
              this.SwipeStartX = Math.floor(event.touches[0].x);
              this.SwipeStartY = Math.floor(event.touches[0].y);
              if (this.SwipeStartX < this.screen_width / 2) {
                this.isLeftSideSwipe = true; // 左边竖滑
                this.isRightSideSwipe = false;
              } else {
                this.isLeftSideSwipe = false;
                this.isRightSideSwipe = true; // 右边竖滑
              }
            }
            if (event.type == TouchType.Move) {
              this.SwipeMovingX = Math.floor(event.touches[0].x);
              this.SwipeMovingY = Math.floor(event.touches[0].y);
              if (Math.abs(this.SwipeStartX - this.SwipeMovingX) > 10 &&
                Math.abs(this.SwipeStartY - this.SwipeMovingY) < 5) {
                if (this.speed > 1) {
                  return;
                }
                this.onSwiping = true;
                this.ShowControl = true;
                this.play_time = this.last_play_time + (this.SwipeMovingX - this.SwipeStartX) *
                  (Math.abs(this.SwipeStartX - this.SwipeMovingX) > 150 ?
                    40 * (Math.abs(this.SwipeStartX - this.SwipeMovingX)) / 100 : 100);
              } else if (Math.abs(this.SwipeStartY - this.SwipeMovingY) > 10 &&
                Math.abs(this.SwipeStartX - this.SwipeMovingX) < 10) { // 处理竖滑
                let offsetY = this.SwipeMovingY - this.SwipeStartY
                const step_area = this.screen_width > this.screen_height ? 10 : 50
                const step = this.screen_width > this.screen_height ? 0.01 : 0.05
                if (this.isRightSideSwipe) {
                  this.onSwipingVoice = true;
                  const delta = ToolsUtil.calculateDelta(offsetY, step_area, step, offsetY < 0 ? 1 : -1);
                  this.volume = Math.min(Math.max(this.volume + delta, 0.0), 15.0);
                } else if (this.isLeftSideSwipe) {
                  this.onSwipingBrightness = true;
                  const delta = ToolsUtil.calculateDelta(offsetY, step_area, step / 10, offsetY < 0 ? 1 : -1);
                  VideoOperateUtil.setBrightness(Math.min(Math.max(this.screenBrightness + delta, 0.0), 1.0))
                }
              }
            }
            if (event.type == TouchType.Up) {
              if (Math.abs(this.SwipeStartX - this.SwipeMovingX) > 10 &&
                Math.abs(this.SwipeStartY - this.SwipeMovingY) < 10) {
                this.avPlayer?.seek(this.play_time);
              }
              this.onSwiping = false;
              if (Math.abs(this.SwipeStartY - this.SwipeMovingY) > 10) { // 处理竖滑结束
                this.onSwipingVoice = false
                this.onSwipingBrightness = false
              }
              if (this.LongPress) {
                this.LongPress = false;
                this.avPlayer?.setSpeed(this.last_speed);
              }
            }
          })
          .gesture(LongPressGesture().onAction(() => {
            this.LongPress = true
            this.last_speed = this.speed
            this.avPlayer?.setSpeed(3)
          }))
          .gesture(GestureGroup(GestureMode.Exclusive,
            TapGesture({ count: 2 })
              .onAction(() => {
                this.playing ? this.avPlayer?.pause() : this.avPlayer?.play()
              }),
            TapGesture({ count: 1 })
              .onAction(() => {
                this.isShow ? this.isShow = false : this.ShowControl = !this.ShowControl
              })
          ))
      }.onAreaChange(async (_oldValue: Area, newValue: Area) => {
        this.screen_width = Math.floor(new Number(newValue.width).valueOf())
        this.screen_height = Math.floor(new Number(newValue.height).valueOf())
        this.setRotation()
      }).backgroundColor($r('sys.color.black'))
    }
    .showControlButton(false)
    .sideBarWidth(200)
    .minSideBarWidth(150)
    .maxSideBarWidth(200)
    .showSideBar(this.isShow)
    .divider({
      strokeWidth: '1vp',
      color: Color.Gray,
      startMargin: '4vp',
      endMargin: '4vp'
    })
    .onChange((value: boolean) => {
      value ? this.sideBarWidth = 200 : this.sideBarWidth = 0
    })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
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
        .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
        .height(50)
        .width(50)
        .backgroundColor('#50000000')
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
        .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
        .height(40)
        .width(40)
        .backgroundColor('#50000000')
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
        .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
        .height(40)
        .width(40)
        .backgroundColor('#50000000')
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
        .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
        .height(40)
        .width(40)
        .backgroundColor('#50000000')
        .onClick(() => {
          this.avPlayer?.seek(this.play_time - 15000)
        })
      }.width(this.screen_height > this.screen_width ? '13%' : '10%')

      Row() {
        Button({ type: ButtonType.Circle, stateEffect: true }) { // 快进按钮
          SymbolGlyph($r('sys.symbol.goforward_15'))
            .fontSize(23)
            .fontColor(['#f0f0f0'])
        }
        .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
        .height(40)
        .width(40)
        .backgroundColor('#50000000')
        .onClick(() => {
          this.avPlayer?.seek(this.play_time + 15000)
        })
      }.width(this.screen_height > this.screen_width ? '13%' : '10%')

      Row() {
        Button({ type: ButtonType.Circle, stateEffect: true }) { // 快进按钮
          SymbolGlyph($r('sys.symbol.goforward_30'))
            .fontSize(23)
            .fontColor(['#f0f0f0'])
        }
        .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
        .height(40)
        .width(40)
        .backgroundColor('#50000000')
        .onClick(() => {
          this.avPlayer?.seek(this.play_time + 30000)
        })
      }.width('10%').visibility(this.screen_height > this.screen_width ? Visibility.None : Visibility.Visible)


      Row() {
        Button({ type: ButtonType.Circle, stateEffect: true }) { // 亮度按钮
          SymbolGlyph($r('sys.symbol.sun_max'))
            .fontSize(23)
            .fontColor(['#f0f0f0'])
        }
        .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
        .height(40)
        .width(40)
        .backgroundColor('#50000000')
        .bindMenu(this.BrightnessBuilder())
      }.width(this.screen_height > this.screen_width ? '13%' : '10%')

      Row() {
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.speaker_wave_1'))
            .fontSize(23)
            .fontColor(['#f0f0f0'])
        }
        .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
        .height(40)
        .width(40)
        .backgroundColor('#50000000')
        .bindMenu(this.VolumeBuilder())
      }.width(this.screen_height > this.screen_width ? '13%' : '10%')

      Row() {
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          Text('选集')
            .fontSize(15)
            .fontColor($r('sys.color.white'))
        }
        .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
        .height(40)
        .width(40)
        .backgroundColor('#50000000')
        .onClick(() => {
          this.isShow = !this.isShow
        })
      }.width(this.screen_height > this.screen_width ? '13%' : '10%')

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
          this.screen_height > this.screen_width ?
          (await (this.windowClass)).setPreferredOrientation(window.Orientation.AUTO_ROTATION_LANDSCAPE)
            : (await (this.windowClass)).setPreferredOrientation(window.Orientation.AUTO_ROTATION_PORTRAIT)
        })
      }.width(this.screen_height > this.screen_width ? '13%' : '10%')
    }.width('95%')
  }
}