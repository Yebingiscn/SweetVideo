import { media } from '@kit.MediaKit';
import AVPlayerUtil from '../utils/AVPlayerUtil';
import { fileUri, fileIo as fs } from '@kit.CoreFileKit';
import PermissionUtil from '../utils/PermissionUtil';
import { window } from '@kit.ArkUI';
import { AVCastPicker, avSession as avSessionManager } from '@kit.AVSessionKit';
import AVSessionUtil from '../utils/AVSessionUtil';
import ToolsUtil from '../utils/ToolsUtil';
import VideoInfoUtil from '../utils/VideoInfoUtil';
import TimeUtil from '../utils/TimeUtil';
import { audio, AVVolumePanel } from '@kit.AudioKit';
import { settings } from '@kit.BasicServicesKit';
import SelectFileUtil from '../utils/SelectFileUtil';
import { VideoDataSource } from '../utils/DataUtil';
import VideoOperateUtil from '../utils/VideoOperateUtil';
import RecentPlayUtil from '../utils/RecentPlayUtil';
import { IjkMediaPlayer } from '@ohos/ijkplayer';
import { PlayerParams } from '../common/PlayerParams';
import { VideoMetadataFromPlayer } from '../interfaces/VideoMetadataFromPlayerInterface';
import { VideoMetadata } from '../interfaces/VideoMetadataInterface';
import { FileFolder } from '../interfaces/FileFolderInterface';
import { AudioTrack } from '../interfaces/AudioTrackInterface';
import Preferences from '../database/Preferences';
import PrivacySpaceUtil from '../utils/PrivacySpaceUtil';
import {
  ButtonFancyModifier,
  ImageFancyModifier,
  SelectItemFancyModifier,
  SelectItemTextFancyModifier,
  SymbolGlyphFancyModifier
} from '../utils/AttributeModifierUtil';
import { KeyCode } from '@kit.InputKit';
import SubtitleUtil from '../utils/SubtitleUtil';
import { PathUtils } from '../utils/PathUtils';
import { AVCastPickerBuilder } from '../component/AVCastPickerBuilder';

@Component
export struct Player { // 播放页
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
  @State long_press: boolean = false
  @State played: boolean = false
  @State @Watch('setScreen') showControl: boolean = false
  @State lock_rotation: boolean = false
  xComponentController: XComponentController = new XComponentController()
  windowClass = window.getLastWindow(PathUtils.appContext!)
  @State screen_width: number = 0
  @State screen_height: number = 0
  @State play_area_height: number = 0
  @State play_area_width: number = 0
  @State screen_arco: number = 0
  @State onSwiping: boolean = false
  @State onSwipingVoice: boolean = false
  @State onSwipingBrightness: boolean = false
  @State isLeftSideSwipe: boolean = false
  @State isRightSideSwipe: boolean = false
  @State volume: number = 0
  @State volumeTmp: number = 0
  @State screenBrightness: number = 0
  @State screenBrightnessTmp: number = 0
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
  @State isSliderPlayTimeChange: boolean = false
  @State longPressStartX: number = 0
  @State currentSpeedIndex: number = 0
  @State clock_time: string = ''
  @State videoDataSource: IDataSource = new VideoDataSource([])
  @StorageLink('allowBackgroundPlay') allowBackgroundPlay: boolean = true
  @StorageLink('fastForwardSeconds') fastForwardSeconds: string = '15'
  @StorageLink('subtitleSize') subtitleSize: string = '22'
  @StorageLink('allowPlayBackExist') allowPlayBackExist: boolean = false
  @StorageLink('allowDoubleFastForward') allowDoubleFastForward: boolean = true
  @StorageLink('skipIntroTime') skipIntroTime: string = '0'
  @StorageProp('topSafeHeight') topSafeHeight: number = 0;
  @Consume('pathStack') pathStack: NavPathStack
  private file_folder: FileFolder = {
    name: '',
    date: '',
    video_list: []
  }
  private listScroller: Scroller = new Scroller();
  private mIjkMediaPlayer: IjkMediaPlayer | null = null;

  async setSessionListener() {
    this.avSession?.on('play', () => {
      if (VideoOperateUtil.mIjkMediaPlayerActive) {
        this.mIjkMediaPlayer?.start()
      }
      this.avPlayer?.play()
    });
    this.avSession?.on('pause', () => {
      if (VideoOperateUtil.mIjkMediaPlayerActive && this.mIjkMediaPlayer?.isPlaying()) {
        this.mIjkMediaPlayer?.pause()
      }
      this.avPlayer?.pause()
    });
    this.avSession?.on('seek', (position: number) => {
      this.avPlayer?.seek(position, media.SeekMode.SEEK_CLOSEST)
    })
    this.avSession?.on('fastForward', () => {
      this.avPlayer?.seek(this.play_time + 15000, media.SeekMode.SEEK_CLOSEST)
    })
    this.avSession?.on('rewind', () => {
      this.avPlayer?.seek(this.play_time - 15000, media.SeekMode.SEEK_CLOSEST)
    })
  }

  async initVolumeAndBrightness() {
    let groupId: number = audio.DEFAULT_VOLUME_GROUP_ID;
    let audioManager = audio.getAudioManager();
    let audioVolumeManger: audio.AudioVolumeManager = audioManager.getVolumeManager();
    let volume_list = await VideoOperateUtil.getVolume(audioVolumeManger, groupId)
    this.volume = volume_list.get('volume')!
    settings.getValue(PathUtils.appContext!, settings.display.SCREEN_BRIGHTNESS_STATUS,
      settings.domainName.DEVICE_SHARED)
      .then((value) => {
        this.screenBrightness = Number(value) / 255;
      })
  }

  async setScreen() {
    await (await this.windowClass).setSpecificSystemBarEnabled('status', this.showControl, true)
    await (await this.windowClass).setSpecificSystemBarEnabled('navigationIndicator', this.showControl, true)
  }

  async aboutToAppear(): Promise<void> {
    if (this.allowBackgroundPlay) {
      PermissionUtil.startContinuousTask()
    }
    this.clock_time = ToolsUtil.getTime()
    this.setScreen()
    await (await this.windowClass).setPreferredOrientation(window.Orientation.AUTO_ROTATION_RESTRICTED);
    await (await this.windowClass).setWindowKeepScreenOn(true)
    this.circle_play = Preferences.getCirclePlayState(PathUtils.appContext!)
    const video_speed = Preferences.getVideoSpeed(PathUtils.appContext!)
    this.speed = parseFloat(video_speed?.replace('x', '') || '1')
  }

  async aboutToDisappear(): Promise<void> {
    VideoOperateUtil.setBrightness(-1)
    Preferences.saveVideoSpeed(PathUtils.appContext!,
      (VideoInfoUtil.video_speed_list.includes(this.speed) ? this.speed : 1) + 'x')
    Preferences.saveCirclePlayState(PathUtils.appContext!, this.circle_play)
  }

  async setRotation() {
    this.screen_arco = this.screen_height / this.screen_width
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
    VideoInfoUtil.saveVideoWidthAndHeight(this.play_area_width, this.play_area_height)
  }

  async getAudioTrack() {
    this.audio_track = await VideoOperateUtil.getAudioTracks(this.avPlayer!)
    if (VideoOperateUtil.audioTrackErrorExecute(this.audio_track)) {
      this.avPlayer!.selectTrack(this.audio_track[0].index);
    } else {
      this.mIjkMediaPlayer = IjkMediaPlayer.getInstance();
      VideoOperateUtil.mIjkMediaPlayerActive = true
      const video_url = fs.openSync(this.now_playing?.uri).path
      this.mIjkMediaPlayer.reset();
      this.mIjkMediaPlayer.setAudioId(this.surfaceID)
      this.mIjkMediaPlayer.native_setup();
      this.mIjkMediaPlayer.setDebug(false);
      this.mIjkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "max-buffer-size", '15728600');
      this.mIjkMediaPlayer.setVolume('1.0', '1.0');
      this.mIjkMediaPlayer.setDataSource(video_url)
      this.mIjkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "start-on-prepared", "1");
      this.mIjkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "enable-accurate-seek", "1");
      this.mIjkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "packet-buffering", "1");
      this.mIjkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "max-fps", "0"); // 禁用FPS限制
      this.mIjkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_FORMAT, "disable_video", "1"); // 跳过视频流
      this.mIjkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_CODEC, "skip-video", "1");
      this.mIjkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "audio-resampler", "soxr");
      this.mIjkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "avsync", '100');
      this.mIjkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "mediacodec-all-videos", "1");
      this.mIjkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "mediacodec-hevc", "0");
      this.mIjkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "enable-buffer-age", "0");
      this.mIjkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "buffer-pool-size", "32");
      this.mIjkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "sync-av-start", "1");
      this.mIjkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "infbuf", "0");
      this.mIjkMediaPlayer.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "soundtouch", "1");
      this.mIjkMediaPlayer.setSpeed('1f');
      this.mIjkMediaPlayer.setLoopCount(false);
      this.mIjkMediaPlayer.setMessageListener();
      this.mIjkMediaPlayer.prepareAsync();
      this.mIjkMediaPlayer.start()
    }
  }

  async setAVPlayerCallback() {
    this.avPlayer?.on('timeUpdate', async (duration) => {
      this.clock_time = ToolsUtil.getTime()
      const isDestroy = AppStorage.get('destroy_signal') as boolean // 监听播放器是否将被杀掉，杀掉的话就保存记录
      if (isDestroy) {
        await VideoOperateUtil.saveVideoTime(this.play_time, this.now_playing!, this.video_meta_data,
          PathUtils.appContext!,
          this.file_folder)
      }
      if (!this.onSwiping) {
        this.play_time = duration;
        if (VideoOperateUtil.mIjkMediaPlayerActive) {
          const currentTime = Date.now(); // 冷却时间检查
          if (currentTime - VideoOperateUtil.lastSyncTime < VideoOperateUtil.syncCoolDown) {
            return;
          }
          const audioPosition = Number(this.mIjkMediaPlayer?.getCurrentPosition());
          const drift = duration - audioPosition; // 记录最近5次差异
          VideoOperateUtil.driftHistory.push(drift);
          if (VideoOperateUtil.driftHistory.length > 5) {
            VideoOperateUtil.driftHistory.shift();
          } // 动态阈值计算
          const buffer = this.mIjkMediaPlayer?.getAsyncStatisticBufCapacity()!;
          const dynamicThreshold = Math.min(1000, 300 + buffer * 0.5); // 趋势分析（最近3次差异是否持续扩大）
          const isGrowing = VideoOperateUtil.driftHistory.slice(-3).every((v, i, arr) =>
          i === 0 || Math.abs(v) > Math.abs(arr[i-1])
          ); // 触发条件：差异超过阈值或存在持续扩大趋势
          if (Math.abs(drift) > dynamicThreshold || (isGrowing && Math.abs(drift) > 300)) {
            this.handleIntelligentSync(duration, audioPosition);
            VideoOperateUtil.lastSyncTime = currentTime; // 自适应调整冷却时间
            VideoOperateUtil.syncCoolDown = Math.max(500, 1000 - buffer * 2);
          }
        }
      }
    });

    this.avPlayer?.on('seekDone', (percent) => {
      this.play_time = percent
      VideoOperateUtil.updateSession(this.playing, this.play_time)
    })

    this.avPlayer?.on('speedDone', (speed) => {
      this.speed = VideoInfoUtil.getVideoSpeed(parseFloat(speed.toFixed(2)))
    })

    this.avPlayer?.on('audioOutputDeviceChangeWithInfo', (data: audio.AudioStreamDeviceChangeInfo) => {
      if (data.changeReason === audio.AudioStreamDeviceChangeReason.REASON_OLD_DEVICE_UNAVAILABLE) {
        if (VideoOperateUtil.mIjkMediaPlayerActive) {
          this.mIjkMediaPlayer?.pause()
        }
        this.avPlayer?.pause()
      }
    });

    this.avPlayer?.on('subtitleUpdate', async (info: media.SubtitleInfo) => {
      if (VideoOperateUtil.clearSubtitleTimer !== null) {
        clearTimeout(VideoOperateUtil.clearSubtitleTimer);
        VideoOperateUtil.clearSubtitleTimer = null;
      }
      if (info) {
        const text = info.text ?? '';
        const duration = info.duration ?? 0;
        this.sub_title = text;
        if (duration > 0) {
          VideoOperateUtil.clearSubtitleTimer = setTimeout(() => {
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
            let playStrategy: media.PlaybackStrategy =
              { showFirstFrameOnPrepare: true, preferredAudioLanguage: 'chi', preferredSubtitleLanguage: 'chi' }
            this.avPlayer.setPlaybackStrategy(playStrategy);
            this.avPlayer.prepare();
          }
          break;
        case 'prepared':
          await this.getAudioTrack()
          if (this.now_playing?.last_play !== 0 && this.now_playing?.last_play! < this.now_playing?.time! * 0.9) {
            this.avPlayer?.seek(this.now_playing?.last_play, media.SeekMode.SEEK_CLOSEST)
            if (VideoOperateUtil.mIjkMediaPlayerActive) {
              this.mIjkMediaPlayer?.seekTo(String(this.now_playing?.last_play))
            }
          } else if (this.skipIntroTime !== '0' && Number(this.skipIntroTime) * 1000 < this.now_playing?.time! &&
            !VideoInfoUtil.support_audio_format.includes(this.now_playing?.title.split('.')[this.now_playing?.title.split('.')
              .length-1].toLowerCase()!)
          ) {
            this.avPlayer?.seek(this.play_time + Number(this.skipIntroTime) * 1000, media.SeekMode.SEEK_CLOSEST)
            if (VideoOperateUtil.mIjkMediaPlayerActive) {
              this.mIjkMediaPlayer?.seekTo(String(this.play_time + Number(this.skipIntroTime) * 1000))
            }
          }
          this.avPlayer?.play();
          await this.initVolumeAndBrightness()
          this.updatePlaybackSpeed(this.speed)
          this.showControl = false
          this.lockVisibility = false
          this.isSliderPlayTimeChange = false
          this.onSwiping = false
          break;
        case 'completed':
          if (this.circle_play) {
            if (VideoOperateUtil.mIjkMediaPlayerActive) {
              this.mIjkMediaPlayer?.seekTo('0')
              this.mIjkMediaPlayer?.start()
            }
            this.avPlayer?.play()
            this.avPlayer?.seek(0, media.SeekMode.SEEK_CLOSEST)
          } else {
            this.playNextVideo()
          }
          break;
        case 'playing':
          this.played = true
          this.playing = true
          if (!this.avSession && this.allowBackgroundPlay) {
            this.avSession = await AVSessionUtil.getAVSession()
            await this.setSessionListener()
            AVSessionUtil.setSessionInfo(JSON.stringify(this.now_playing))
            VideoOperateUtil.updateSession(this.playing, this.play_time)
          }
          VideoOperateUtil.updateSession(this.playing, this.play_time)
          break
        case 'paused':
          if (VideoOperateUtil.mIjkMediaPlayerActive) {
            this.mIjkMediaPlayer?.pause()
          }
          this.playing = false
          VideoOperateUtil.updateSession(this.playing, this.play_time)
          break
        case 'released':
          await this.ijkPlayerStop()
          this.playing = false
          VideoOperateUtil.updateSession(this.playing, this.play_time)
          break
        case 'idle':
          await this.ijkPlayerStop()
          this.avPlayer?.release()
          break;
        case 'error':
          await this.ijkPlayerStop()
          VideoOperateUtil.playErrorExecute(this.pathStack, this.video_meta_data, this.now_playing?.date!,
            this.file_folder)
          this.avPlayer?.release()
          break;
      }
    })
  }

  async ijkPlayerStop() {
    if (VideoOperateUtil.mIjkMediaPlayerActive) {
      this.mIjkMediaPlayer?.pause(); // 先暂停再停止
      this.mIjkMediaPlayer?.reset();
      this.mIjkMediaPlayer?.stop()
      this.mIjkMediaPlayer?.release()
      this.mIjkMediaPlayer = null
      VideoOperateUtil.mIjkMediaPlayerActive = false
    }
  }

  async setExternalSubtitle(now_playing: VideoMetadataFromPlayer) {
    if (await SubtitleUtil.isSubtitleExist(PathUtils.subtitlePath!, now_playing.date!)) {
      let file1 = fs.openSync(PathUtils.subtitlePath! + now_playing.date, fs.OpenMode.READ_ONLY)
      const size = fs.statSync(PathUtils.subtitlePath! + now_playing.date);
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

  async playChooseVideo(item: VideoMetadata) {
    if (!PrivacySpaceUtil.getPrivacyMode()) {
      RecentPlayUtil.addPlayback(PathUtils.appContext!, item)
    }
    await this.avPlayer?.reset()
    if (VideoOperateUtil.mIjkMediaPlayerActive) {
      await this.ijkPlayerStop()
    }
    this.now_playing = JSON.parse(JSON.stringify(item)) as VideoMetadataFromPlayer
    this.getData()
    this.avSession = await AVSessionUtil.getAVSession()
    await this.setSessionListener()
    AVSessionUtil.setSessionInfo(JSON.stringify(this.now_playing))
    VideoOperateUtil.updateSession(this.playing, this.play_time)
  }

  async playNextVideo() {
    this.ijkPlayerStop()
    if (this.video_meta_data.length > 0 && this.play_time > 0) {
      await VideoOperateUtil.saveVideoTime(this.play_time, this.now_playing!, this.video_meta_data,
        PathUtils.appContext!,
        this.file_folder)
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

  screenExtend(text: string) {
    switch (text) {
      case VideoInfoUtil.screen_extend_map[0]:
        this.play_area_height = VideoInfoUtil.play_area_height
        this.play_area_width = VideoInfoUtil.play_area_width
        break;
      case VideoInfoUtil.screen_extend_map[1]:
        this.play_area_height = this.screen_height;
        this.play_area_width = this.screen_width;
        break;
      default:
        const scale = text ? VideoInfoUtil.scale_factors.get(text) : undefined;
        if (scale) {
          this.play_area_height = scale * VideoInfoUtil.play_area_height;
          this.play_area_width = scale * VideoInfoUtil.play_area_width;
        }
        break;
    }
  }

  doublePause() {
    this.togglePlayback()
  }

  backForward() {
    this.avPlayer?.seek(this.play_time - Number(this.fastForwardSeconds) * 1000,
      media.SeekMode.SEEK_CLOSEST);
    if (VideoOperateUtil.mIjkMediaPlayerActive) {
      this.mIjkMediaPlayer?.seekTo(String(this.play_time -
        Number(this.fastForwardSeconds) * 1000))
    }
  }

  fastForward() {
    this.avPlayer?.seek(this.play_time + Number(this.fastForwardSeconds) * 1000,
      media.SeekMode.SEEK_CLOSEST);
    if (VideoOperateUtil.mIjkMediaPlayerActive) {
      this.mIjkMediaPlayer?.seekTo(String(this.play_time + Number(this.fastForwardSeconds) * 1000))
    }
  }

  togglePlayback() {
    this.playing ? this.avPlayer?.pause() : this.avPlayer?.play()
    if (VideoOperateUtil.mIjkMediaPlayerActive) {
      this.playing ? this.mIjkMediaPlayer?.pause() : this.mIjkMediaPlayer?.start()
    }
  }

  build() {
    NavDestination() {
      SideBarContainer(SideBarContainerType.Overlay) {
        List({ scroller: this.listScroller, space: 10 }) {
          LazyForEach(this.videoDataSource, (item: VideoMetadata) => {
            ListItem() {
              if (VideoInfoUtil.videoWidthAndHeightFormat(String(SelectFileUtil.getItem(this.video_meta_data,
                item?.date)?.size)) !== '0 x 0') {
                Column() {
                  Row() {
                    Image(fileUri.getUriFromPath(PathUtils.coverPath + item.date))
                      .attributeModifier(new ImageFancyModifier(10, 60, 90))
                      .margin({ left: 5 })
                    Text((String(SelectFileUtil.getItem(this.video_meta_data, item?.date)?.title)).slice(0,
                      String(SelectFileUtil.getItem(this.video_meta_data, item?.date)?.title).lastIndexOf('.')))
                      .fontSize(15)
                      .fontColor(this.now_playing?.date ===
                        SelectFileUtil.getItem(this.video_meta_data, item?.date)?.date
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
                  .width('100%')
                  .height(100)
                  .clickEffect({ level: ClickEffectLevel.HEAVY, scale: 0.9 })
                }
              }
            }
          }, (item: VideoMetadata) => item.date)
        }
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true }) // 滚动边缘效果
        .chainAnimation(true)
        .scrollBar(BarState.Off)
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
        .height('100%')
        .backgroundColor($r('app.color.start_window_background'))
        .padding({ top: 50, left: 20, right: 20 })
        .transition(TransitionEffect.translate({ x: 200 }).animation({ duration: 500, curve: Curve.Friction }))
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

          if ((this.showControl && !this.isLock)) {
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
                        Text(this.clock_time)
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
                }
                .height(this.screen_height > this.screen_width ? 85 : 75)
                .backgroundColor('#61000000')
                .width('100%')
                .padding({
                  left: (this.screen_height > this.screen_width ? 20 : 35),
                  right: 20,
                  top: (this.screen_height > this.screen_width ? this.topSafeHeight : 0),
                  bottom: 0
                })

                Stack() { //底栏
                  if (this.screen_arco > 1.4) {
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
              Text(VideoInfoUtil.optimizedFormat(this.speed) + ' ⏩')
                .fontColor($r('sys.color.white'))
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
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
            Stack() { // 滑动控制栏
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
                  volumeParameter: {
                    position: {
                      x: 10000,
                      y: 20000
                    }
                  }
                }).visibility(Visibility.None)
                SymbolGlyph($r('sys.symbol.speaker_wave_1'))
                  .attributeModifier(new SymbolGlyphFancyModifier(23, '', ''))
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
                  .attributeModifier(new SymbolGlyphFancyModifier(23, '', ''))
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
                  .selectedColor('#e0e0e0')
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
            Button({ type: ButtonType.Circle, stateEffect: true }) { //锁定播放栏
              SymbolGlyph(this.isLock ? $r('sys.symbol.lock_fill') : $r('sys.symbol.lock_open_fill'))
                .fontWeight(FontWeight.Bold)
                .attributeModifier(new SymbolGlyphFancyModifier(23, '', ''))
                .fontColor(['#f0f0f0'])
            }
            .zIndex(100)
            .attributeModifier(new ButtonFancyModifier(40, 40))
            .backgroundColor('#50000000')
            .aspectRatio(1)
            .onClick(() => {
              this.isLock = !this.isLock
            })
            .position({ bottom: this.screen_height / 2, left: this.screen_height > this.screen_width ? 30 : 50 })
          }

          Column()
            .width('100%')
            .height(this.showControl ? '50%' : '80%')//触控区域
            .gesture(
              GestureGroup(GestureMode.Exclusive, // 将触摸事件跟滑动、长按分成两个手势组解绑互斥,触摸事件手势组为互斥事件
                GestureGroup(GestureMode.Exclusive, //双击事件组和单击事件组互斥独立
                  TapGesture({ count: 2 })// 双击事件
                    .onAction((event: GestureEvent) => {
                      if (this.isLock) {
                        return;
                      } // 设备锁定时直接返回
                      if (!this.allowDoubleFastForward) { // 非双击快进模式时执行暂停
                        this.doublePause();
                        return;
                      }
                      const tapX = event.fingerList[0].localX;
                      const zoneWidth = this.screen_width / 5; // 屏幕五分之一宽度
                      if (tapX < zoneWidth) { // 左侧1/5区域：回退
                        this.backForward();
                        return;
                      }
                      if (tapX > zoneWidth * 4) { // 右侧1/5区域：快进
                        this.fastForward();
                        return;
                      }
                      this.doublePause(); // 中间3/5区域：暂停
                    }),
                  TapGesture({ count: 1 })// 单击事件
                    .onAction(() => { //单击屏幕
                      if (this.sideBarStatus) {
                        this.closeSideBar(true);
                      } else {
                        this.lockVisibility = !this.lockVisibility;
                        this.showControl = !this.showControl;
                      }
                    }),
                  PanGesture({ fingers: 1, direction: PanDirection.Vertical })// 垂直滑动
                    .onActionStart((event: GestureEvent) => { // 滑动屏幕
                      if (!this.isLock) {
                        const firstTouch = event.fingerList[0];
                        this.swipe_start_x = firstTouch.localX;
                        this.swipe_start_y = firstTouch.localY;
                        this.isLeftSideSwipe = firstTouch.localX < this.screen_width / 2;
                        this.screenBrightnessTmp = this.screenBrightness
                        this.volumeTmp = this.volume
                      }
                    })
                    .onActionUpdate((event: GestureEvent) => {
                      if (!this.isLock && event.fingerList.length === 1) {
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
                      }
                    })
                    .onActionEnd(() => {
                      this.onSwiping = false;
                      this.onSwipingVoice = false;
                      this.onSwipingBrightness = false;
                    }),
                  PanGesture({ fingers: 1, direction: PanDirection.Horizontal })// 水平滑动事件滑动调整进度
                    .onActionStart((event: GestureEvent) => { // 长按且滑动屏幕
                      if (!this.isLock) {
                        const firstTouch = event.fingerList[0];
                        this.swipe_start_x = firstTouch.localX;
                        this.last_play_time = this.play_time;
                        this.onSwiping = true
                      }
                    })
                    .onActionUpdate((event: GestureEvent) => {
                      if (this.isLock) {
                        return
                      }
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
                      this.avPlayer?.seek(this.play_time, media.SeekMode.SEEK_CLOSEST);
                      if (VideoOperateUtil.mIjkMediaPlayerActive) {
                        this.mIjkMediaPlayer?.seekTo(String(this.play_time))
                      }
                      this.onSwiping = false;
                    }),
                  PinchGesture({ fingers: 2, distance: 2 })//手势缩放
                    .onActionStart((event: GestureEvent) => {
                      const finger1 = event.fingerList[0];
                      const finger2 = event.fingerList[1];
                      VideoOperateUtil.initPinchDistance = VideoOperateUtil.calcFingerDistance(finger1, finger2);
                    })
                    .onActionUpdate((event: GestureEvent) => {
                      if (this.isLock) {
                        return;
                      }
                      const finger1 = event.fingerList[0];
                      const finger2 = event.fingerList[1];
                      // 双指检测失败直接返回
                      if (!finger1 || !finger2) {
                        return;
                      }
                      const currentDistance = VideoOperateUtil.calcFingerDistance(finger1, finger2);
                      const rawScale = currentDistance / VideoOperateUtil.initPinchDistance;
                      const adjustedScale = 1 + (rawScale - 1) * 0.007; // 计算调整后的缩放比例
                      const clampedScale = Math.min(Math.max(adjustedScale, 0.5), 2.0);
                      const scaledWidth = this.play_area_width * clampedScale; // 计算缩放后的播放区域宽度
                      const maxAllowed = VideoInfoUtil.play_area_width * 3.0;
                      const minAllowed = VideoInfoUtil.play_area_width * 0.5;
                      if (scaledWidth > maxAllowed || scaledWidth < minAllowed) { // 检查缩放是否超出允许范围
                        return;
                      }
                      this.play_area_width = scaledWidth; // 更新播放区域尺寸
                      this.play_area_height = this.play_area_height * clampedScale;
                      animateTo({ duration: 100 }, () => {
                        this.play_area_width = this.play_area_width;
                        this.play_area_height = this.play_area_height;
                      });
                    })
                ),
                GestureGroup(GestureMode.Parallel, // 不用互斥事件，会导致左右滑动调节倍速的功能失效
                  LongPressGesture()// 长按手势
                    .onAction(() => { //长按
                      if (!this.isLock) {
                        this.long_press = true
                        this.last_speed = this.speed
                        this.updatePlaybackSpeed(3);
                        this.currentSpeedIndex = VideoInfoUtil.video_speed_list.indexOf(3);
                      }
                    })
                    .onActionEnd(() => {
                      this.long_press = false
                      this.updatePlaybackSpeed(this.last_speed);
                    }),
                  PanGesture({
                    fingers: 1,
                    direction: PanDirection.Horizontal,
                  })//水平滑动事件 长按加速滑动调整倍速
                    .onActionStart((event: GestureEvent) => { // 长按且滑动屏幕
                      if (!this.isLock) {
                        this.longPressStartX = event.fingerList[0].localX;
                      }
                    })
                    .onActionUpdate((event: GestureEvent) => {
                      if (!this.isLock && this.long_press) { // 长按状态下的滑动处理
                        const deltaX = event.fingerList[0].localX - this.longPressStartX;
                        const SWIPE_THRESHOLD = 30;
                        if (Math.abs(deltaX) <= SWIPE_THRESHOLD) { // 未达到滑动阈值则直接返回
                          return;
                        }
                        if (typeof this.currentSpeedIndex === 'undefined') { // 确保currentSpeedIndex已初始化
                          const defaultSpeedIdx = VideoInfoUtil.video_speed_list.indexOf(this.speed);
                          this.currentSpeedIndex = defaultSpeedIdx === -1 ? 0 : defaultSpeedIdx;
                        }
                        const direction = deltaX > 0 ? 1 : -1; // 确定滑动方向（正值为右滑，负值为左滑）
                        const newIndex = this.currentSpeedIndex + direction; // 计算新速度索引并限制在有效范围内
                        const clampedIndex = Math.max(0, Math.min(newIndex, VideoInfoUtil.video_speed_list.length - 1));
                        if (clampedIndex === this.currentSpeedIndex) { // 索引变化时才更新播放速度
                          return;
                        }
                        this.currentSpeedIndex = clampedIndex;
                        this.updatePlaybackSpeed(VideoInfoUtil.video_speed_list[this.currentSpeedIndex]);
                        this.longPressStartX = event.fingerList[0].localX; // 重置起始点实现分档切换效果
                      }
                    })
                )))
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
      .showSideBar(this.sideBarStatus)
      .sideBarPosition(SideBarPosition.End)
      .divider({ strokeWidth: 0 })
    }.onReady(() => {
      const playerParams: PlayerParams = this.pathStack.getParamByName('Player')[0] as PlayerParams
      try {
        this.now_playing = playerParams.metadata as VideoMetadataFromPlayer
        this.video_meta_data = playerParams.metadata_list as VideoMetadata[]
        this.videoDataSource = new VideoDataSource(this.video_meta_data);
        this.file_folder = playerParams.file_folder as FileFolder
      } catch (e) {
        console.error(e)
      }
    })
    .onBackPressed(() => {
      if (this.showControl && !this.allowPlayBackExist) {
        this.showControl = false
        this.lockVisibility = false
        return true
      } else {
        this.avPlayer?.release()
        return false
      }
    })
    .onWillDisappear(async () => {
      await (await this.windowClass).setWindowKeepScreenOn(false)
      await (await this.windowClass).setSpecificSystemBarEnabled('status', true)
      await (await this.windowClass).setSpecificSystemBarEnabled('navigationIndicator', true)
      await (await this.windowClass).setPreferredOrientation(window.Orientation.AUTO_ROTATION_RESTRICTED);
      this.avPlayer?.off('subtitleUpdate');
      if (this.video_meta_data.length > 0 && this.play_time > 0) {
        await VideoOperateUtil.saveVideoTime(this.play_time, this.now_playing!, this.video_meta_data,
          PathUtils.appContext!,
          this.file_folder)
      }
      if (this.allowBackgroundPlay) { //若发生错误跳转FFMpeg播放器，确保提前关闭申请防止两个播放器重复申请导致失败
        AVSessionUtil.destroySession()
        PermissionUtil.stopContinuousTask()
      }
      await this.avSession?.stopCasting();
    })
    .hideTitleBar(true)
  }

  @Builder
  VideoTop() {
    Row({ space: 8 }) {
      SymbolGlyph($r('sys.symbol.chevron_left'))
        .attributeModifier(new SymbolGlyphFancyModifier(40, '', ''))
        .fontColor(['#f0f0f0'])
        .onClick(() => {
          this.avPlayer?.reset()
          this.pathStack.pop()
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
        Row({ space: 12 }) {
          SymbolGlyph(this.sub_title_visibility === Visibility.Visible ?
          $r('sys.symbol.textformat_size_square_fill') : $r('sys.symbol.textformat_size_square'))
            .attributeModifier(new SymbolGlyphFancyModifier(30, '', ''))
            .fontColor(['#f0f0f0'])
            .onClick(() => {
              this.sub_title_visibility === Visibility.Visible ? this.sub_title_visibility = Visibility.None :
                this.sub_title_visibility = Visibility.Visible
            })
          if (this.screen_width > this.screen_height) {
            SymbolGlyph($r('sys.symbol.opticaldisc'))
              .attributeModifier(new SymbolGlyphFancyModifier(30, '', ''))
              .fontColor(['#f0f0f0'])
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
              .onSelect(async (_index: number, text?: string | undefined) => {
                this.select_text = text
                this.screenExtend(text!)
              })
              .menuBackgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THIN)
          }
        }.alignItems(VerticalAlign.Center)
      }.height('100%').layoutWeight(1)

      Button({ type: ButtonType.Circle, stateEffect: true }) { // 旋转锁定
        SymbolGlyph(this.lock_rotation ? $r('sys.symbol.lock_fill') : $r('sys.symbol.rotate_left'))
          .attributeModifier(new SymbolGlyphFancyModifier(23, '', ''))
          .fontColor(['#f0f0f0'])
          .symbolEffect(new ReplaceSymbolEffect(EffectScope.WHOLE), Number(this.lock_rotation))
      }
      .attributeModifier(new ButtonFancyModifier(35, 40))
      .backgroundColor('#50000000')
      .onClick(async () => {
        this.lock_rotation = !this.lock_rotation
        const windowInstance = await this.windowClass
        const orientation = this.lock_rotation ?
          (this.screen_width > this.screen_height ? window.Orientation.AUTO_ROTATION_LANDSCAPE_RESTRICTED
            : window.Orientation.AUTO_ROTATION_PORTRAIT_RESTRICTED)
          : window.Orientation.AUTO_ROTATION_RESTRICTED
        await windowInstance.setPreferredOrientation(orientation)
        const toastMessage = this.lock_rotation
          ? PathUtils.appContext!.resourceManager.getStringSync($r('app.string.open_rotation_lock'))
          : PathUtils.appContext!.resourceManager.getStringSync($r('app.string.close_rotation_lock'))
        ToolsUtil.showToast(toastMessage);
      })
    }
    .padding({ left: 8, right: 8 })
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .focusable(true)
    .onKeyEvent((event: KeyEvent) => {
      if (event.keyCode === KeyCode.KEYCODE_ESCAPE &&
        event.type === KeyType.Down) {
        this.avPlayer?.reset();
        this.pathStack.pop();
      }
    })
  }

  @Builder
  VideoSlider() {
    Row({ space: 10 }) {
      Row() { // 播放时间进度
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
            if (VideoOperateUtil.mIjkMediaPlayerActive) {
              this.mIjkMediaPlayer?.seekTo(String(this.play_time))
            }
            this.isSliderPlayTimeChange = false
            this.onSwiping = false
          }
        })
        .layoutWeight(1)
        .animation({ duration: 100, curve: Curve.Smooth })
        .selectedColor('#e0e0e0')
      if (this.screen_width > this.screen_height) {
        Row() { //剩余时间
          Text(TimeUtil.convertMsToMMSS(Math.min(Math.max((this.now_playing?.time || 0) - this.play_time, 0),
            (this.now_playing?.time || 0))))
            .fontWeight(FontWeight.Medium)
            .fontSize(15)
            .fontColor($r('sys.color.white'))
            .textAlign(TextAlign.End)
        }.backgroundColor('#50000000').padding(5).borderRadius(10).margin({ right: 5 })
      }
    }
  }

  @Builder
  AVCastPickerBuilderBridge() { // 桥接AVCastPickerBuilder避免crash
    AVCastPickerBuilder()
  }

  @Builder
  VideoButtons() {
    GridRow({ columns: this.screen_arco > 1.4 ? 8 : 16, gutter: 5 }) {
      GridCol() {
        Button({ type: ButtonType.Circle, stateEffect: true }) { // 播放按钮
          SymbolGlyph(this.playing ? $r('sys.symbol.pause_fill') : $r('sys.symbol.play_fill'))
            .attributeModifier(new SymbolGlyphFancyModifier(23, '', ''))
            .fontColor(['#f0f0f0'])
            .symbolEffect(new ReplaceSymbolEffect(EffectScope.WHOLE), Number(this.playing))
        }
        .attributeModifier(new ButtonFancyModifier(40, 40))
        .backgroundColor('#50000000')
        .onClick(() => {
          ToolsUtil.startVibration()
          this.togglePlayback()
        })
        .onKeyEvent((event: KeyEvent) => {
          if ((event.keyCode === KeyCode.KEYCODE_SPACE && event.type === KeyType.Down)) {
            this.togglePlayback()
          }
        })
        .defaultFocus(true) // 自动获取键盘焦点
      }.span({ xs: 2, sm: 2, md: 2 })

      GridCol() {
        Button({ type: ButtonType.Circle, stateEffect: true }) { // 下一首按钮
          SymbolGlyph($r('sys.symbol.forward_end_fill'))
            .attributeModifier(new SymbolGlyphFancyModifier(23, '', ''))
            .fontColor(['#f0f0f0'])
        }
        .attributeModifier(new ButtonFancyModifier(40, 40))
        .backgroundColor('#50000000')
        .onClick(() => {
          this.playNextVideo()
        })
      }.span({ xs: 2, sm: 2, md: 2 })

      GridCol() {
        Button({ type: ButtonType.Circle, stateEffect: true }) { // 循环按钮
          SymbolGlyph(this.circle_play ? $r('sys.symbol.repeat') : $r('sys.symbol.order_play'))
            .attributeModifier(new SymbolGlyphFancyModifier(23, '', ''))
            .fontColor(['#f0f0f0'])
        }
        .attributeModifier(new ButtonFancyModifier(40, 40))
        .backgroundColor('#50000000')
        .onClick(() => {
          this.circle_play = !this.circle_play
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

      GridCol() {
        Button({ type: ButtonType.Circle, stateEffect: true }) { // 音量
          SymbolGlyph($r('sys.symbol.speaker_wave_1'))
            .attributeModifier(new SymbolGlyphFancyModifier(23, '', ''))
            .fontColor(['#f0f0f0'])
        }
        .attributeModifier(new ButtonFancyModifier(40, 40))
        .backgroundColor('#50000000')
        .bindMenu(this.VolumeBuilder())
      }.span({ xs: 2, sm: 2, md: 2 })

      GridCol() {
        Button({ type: ButtonType.Circle, stateEffect: true }) { //选集
          SymbolGlyph($r('sys.symbol.music_note_list'))
            .attributeModifier(new SymbolGlyphFancyModifier(23, '', ''))
            .fontColor(['#f0f0f0'])
        }
        .attributeModifier(new ButtonFancyModifier(40, 40))
        .backgroundColor('#50000000')
        .onClick(() => {
          this.sideBarStatus ? this.closeSideBar(true) : this.openSideBar()
        })
      }.span({ xs: 2, sm: 2, md: 2 })

      GridCol() {
        Button({ type: ButtonType.Circle, stateEffect: true }) { // 倍速调整按钮
          Text(`${this.speed}x`)
            .fontSize(18)
            .fontColor($r('sys.color.white'))
            .minFontSize(8)
            .maxFontSize(18)
            .maxLines(1)
            .padding(5)
        }
        .attributeModifier(new ButtonFancyModifier(40, 40))
        .backgroundColor('#50000000')
        .bindMenu(this.PlaybackSpeedMenu, {
          backgroundColor: Color.Transparent,
          backgroundBlurStyle: BlurStyle.COMPONENT_ULTRA_THIN,
        })
      }.span({ xs: 2, sm: 2, md: 2 })

      GridCol() {
        Button({ type: ButtonType.Circle, stateEffect: true }) { // 全屏按钮
          SymbolGlyph($r('sys.symbol.screen_rotation'))
            .attributeModifier(new SymbolGlyphFancyModifier(23, '', ''))
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
    }.width('95%')
  }

  @Builder
  AudioTrackMenuBuilder() {
    Flex({ direction: FlexDirection.Column, justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center }) {
      ForEach(this.audio_track, (item: AudioTrack, index: number) => {
        Row() { // 音轨
          Text(`${item.index} : ${item.name}(${VideoOperateUtil.getLanguageName(item.language)})`)
            .fontSize(18)
            .height(40)
            .flexGrow(1)
            .flexShrink(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .fontColor(this.audio_track_select === index ? $r('app.color.main_color') : $r('app.color.text_color'))
            .margin({ left: 5 })
          if (item.mime.split('/')[1] === 'av3a') {
            Image($r('app.media.audio_vivid_icon'))
              .attributeModifier(new ImageFancyModifier(10, 85, 30))
              .width(95)
          }
        }
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
        .width('100%')
        .onClick(() => {
          this.AudioTrackMenuBuilderState = false;
          this.avPlayer!.selectTrack(item.index);
          this.audio_track_select = index;
        })
      })
    }.width(235).onAppear(() => {
      VideoOperateUtil.audioTrackErrorExecute(this.audio_track)
    })
  }

  @Builder
  VolumeBuilder() {
    Flex({ direction: FlexDirection.Column, justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center }) {
      Row() {
        AVVolumePanel({
          volumeLevel: this.volume,
          volumeParameter: {
            position: {
              x: 10000,
              y: 20000
            }
          }
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
              .attributeModifier(new SymbolGlyphFancyModifier(23, '', ''))
              .fontColor(['#f0f0f0'])
          }
          .attributeModifier(new ButtonFancyModifier(80, 40))
          .backgroundColor('#50000000')
          .backdropBlur(150)
          .onClick(() => {
            VideoOperateUtil.setBrightness(-1)
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

  @Builder
  PlaybackSpeedMenu() {
    Flex({ direction: FlexDirection.Column, justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center }) {
      ForEach(VideoInfoUtil.video_speed_list, (speed: number) => {
        Column() {
          Row() {
            Text(`${speed}x`)
              .attributeModifier(new SelectItemTextFancyModifier(this.speed == speed))
          }
          .width('100%')
          .height(40)
          .justifyContent(FlexAlign.Start)
          .align(Alignment.Center)
          .onClick(() => {
            this.updatePlaybackSpeed(speed)
          })
        }
        .attributeModifier(new SelectItemFancyModifier(this.speed == speed))
      })
    }
    .width(100)
  }

  private async handleIntelligentSync(videoPos: number, audioPos: number) {
    const drift = videoPos - audioPos;
    try { // 分级处理策略
      if (Math.abs(drift) > 1000) { // 严重不同步：完全重置
        await this.fullResetSync(videoPos);
      } else if (Math.abs(drift) > 700) { // 中度不同步：双重seek
        await this.doubleSeekSync(videoPos);
      } else { // 轻度不同步：加速追赶
        await this.speedAdjustSync(drift);
      }
    } catch (error) {
      console.error('同步失败:', error);
    }
  }

  private async fullResetSync(position: number) { // 严重不同步处理
    this.avPlayer?.pause();
    this.mIjkMediaPlayer?.pause();
    this.mIjkMediaPlayer?.seekTo(String(position))
    await new Promise<void>(resolve => setTimeout(resolve, 50));
    this.avPlayer?.play();
    this.mIjkMediaPlayer?.start();
  }

  private async doubleSeekSync(position: number) { // 中度不同步处理
    const prePos = Math.max(0, position - 500);
    this.mIjkMediaPlayer?.seekTo(String(prePos));
    await new Promise<void>(resolve => setTimeout(resolve, 30));
    this.mIjkMediaPlayer?.seekTo(String(position));
  }

  private async speedAdjustSync(drift: number) { // 轻度不同步处理
    const speed = Math.min(1.1, Math.max(0.9, 1 + drift / 2000));
    this.mIjkMediaPlayer?.setSpeed(speed.toFixed(1.5)); // 30秒后恢复或差异小于310ms时恢复
    const restore = () => {
      if (Math.abs(this.play_time - Number(this.mIjkMediaPlayer?.getCurrentPosition())) < 310) {
        this.mIjkMediaPlayer?.setSpeed(String(this.speed));
      } else {
        setTimeout(restore, 1000);
      }
    };
    setTimeout(restore, 30000);
  }

  private updatePlaybackSpeed(speed: number): void {
    if (!VideoInfoUtil.video_speed_list.includes(speed)) {
      speed = 1;
    }
    this.avPlayer?.setSpeed(VideoInfoUtil.getVideoSpeed(speed));
    if (VideoOperateUtil.mIjkMediaPlayerActive) {
      this.mIjkMediaPlayer?.setSpeed(String(speed));
    }
  }
}