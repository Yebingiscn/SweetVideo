import { media } from '@kit.MediaKit';
import AVPlayerUtil from '../utils/AVPlayerUtil';
import { fileIo as fs } from '@kit.CoreFileKit';
import PermissionUtil from '../utils/PermissionUtil';
import { window } from '@kit.ArkUI';
import { avSession as avSessionManager } from '@kit.AVSessionKit';
import AVSessionUtil from '../utils/AVSessionUtil';
import ToolsUtil from '../utils/ToolsUtil';
import VideoInfoUtil from '../utils/VideoInfoUtil';
import { audio } from '@kit.AudioKit';
import { settings } from '@kit.BasicServicesKit';
import SelectFileUtil from '../utils/SelectFileUtil';
import VideoOperateUtil from '../utils/VideoOperateUtil';
import RecentPlayUtil from '../utils/RecentPlayUtil';
import { IjkMediaPlayer } from '@ohos/ijkplayer';
import { PlayerParams } from '../common/PlayerParams';
import { VideoMetadataFromPlayer } from '../interfaces/VideoMetadataFromPlayerInterface';
import { VideoMetadata } from '../interfaces/VideoMetadataInterface';
import { AudioTrack } from '../interfaces/AudioTrackInterface';
import Preferences from '../database/Preferences';
import PrivacySpaceUtil from '../utils/PrivacySpaceUtil';
import SubtitleUtil from '../utils/SubtitleUtil';
import { PathUtils } from '../utils/PathUtils';
import { PlayerSideBarComponent } from '../component/PlayerComponent/PlayerSideBarComponent';
import { AVCastPickerBuilder } from '../component/PlayerComponent/AVCastPickerBuilder';
import { AudioTrackComponent } from '../component/PlayerComponent/AudioTrackComponent';
import { PlaybackSpeedMenuComponent } from '../component/PlayerComponent/PlaybackSpeedComponent';
import { BrightnessSwipingComponent } from '../component/PlayerComponent/BrightnessSwipingComponent';
import { VolumeSwipingComponent } from '../component/PlayerComponent/VolumeSwipingComponent';
import { FastForwardInfoComponent } from '../component/PlayerComponent/FastForwardInfoComponent';
import { StatusBarComponent } from '../component/PlayerComponent/StatusBarComponent';
import { SubtitleComponent } from '../component/PlayerComponent/SubtitleComponent';
import { LockVideoBarComponent } from '../component/PlayerComponent/LockVideoBarComponent';
import { SwipingPlayTimeDisplay } from '../component/PlayerComponent/SwipingPlayTimeDisplay';
import { VideoSliderComponent } from '../component/PlayerComponent/VideoSliderComponent';
import { GestureComponent } from '../component/PlayerComponent/GestureComponent';
import { VideoTopComponent } from '../component/PlayerComponent/VideoTopComponent';
import { VideoButtonsComponent } from '../component/PlayerComponent/VideoButtonsComponent';
import { VideoSettingComponent } from '../component/PlayerComponent/VideoSettingComponent';
import { VideoStartTimeMode } from '../common/enum/VideoStartTimeMode';

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
  @State long_press: boolean = false
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
  @State screenBrightness: number = 0
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
  @State angle: number = 0
  @State volumeActually: number = 0
  @StorageLink('allowBackgroundPlay') allowBackgroundPlay: boolean = true
  @StorageLink('fastForwardSeconds') fastForwardSeconds: string = '15'
  @StorageLink('allowPlayBackExist') allowPlayBackExist: boolean = false
  @StorageLink('allowDoubleFastForward') allowDoubleFastForward: boolean = true
  @StorageLink('skipIntroTime') skipIntroTime: string = '0'
  @StorageProp('topSafeHeight') topSafeHeight: number = 0;
  @StorageLink('smartRotation') smartRotation: boolean = true
  @Consume('pathStack') pathStack: NavPathStack
  private mIjkMediaPlayer: IjkMediaPlayer | null = null;
  private autoHideTimeout: boolean = false
  private audioVolumeManager: audio.AudioVolumeManager | null = null

  async setSessionListener() {
    this.avSession?.on('play', () => {
      if (this.mIjkMediaPlayer) {
        this.mIjkMediaPlayer?.start()
      }
      this.avPlayer?.play()
    });
    this.avSession?.on('pause', () => {
      this.avPlayer?.pause()
    });
    this.avSession?.on('seek', (position: number) => {
      this.seekTime(position)
    })
    this.avSession?.on('fastForward', () => {
      this.seekTime(this.play_time + 15000)
    })
    this.avSession?.on('rewind', () => {
      this.seekTime(this.play_time - 15000)
    })
    this.avSession?.on('playNext', () => {
      this.playNextVideo()
    })
    this.avSession?.on('outputDeviceChange', () => {
      this.avPlayer?.pause()
    })
  }

  async initVolumeAndBrightness() {
    let groupId: number = audio.DEFAULT_VOLUME_GROUP_ID;
    let audioManager = audio.getAudioManager();
    this.audioVolumeManager = audioManager.getVolumeManager();
    let volume_list = await VideoOperateUtil.getVolume(this.audioVolumeManager, groupId)
    this.volume = volume_list.get('volume')!
    this.volumeActually = this.volume
    this.audioVolumeManager.on('volumeChange', (volumeEvent: audio.VolumeEvent) => {
      this.volumeActually = volumeEvent.volume
      //  ToolsUtil.startVibration()
    });
    if (canIUse('SystemCapability.Applications.Settings.Core')) {
      settings.getValue(PathUtils.appContext!, settings.display.SCREEN_BRIGHTNESS_STATUS,
        settings.domainName.DEVICE_SHARED)
        .then((value) => {
          this.screenBrightness = Number(value) / 255;
        })
    }
  }

  updatePlaybackSpeed(speed: number): void {
    if (!VideoInfoUtil.video_speed_list.includes(speed)) {
      speed = 1;
    }
    this.avPlayer?.setSpeed(VideoInfoUtil.getVideoSpeed(speed));
    if (this.mIjkMediaPlayer) {
      this.mIjkMediaPlayer?.setSpeed(String(speed));
    }
  }

  async setScreen() {
    if (canIUse('SystemCapability.Window.SessionManager')) {
      await (await this.windowClass).setSpecificSystemBarEnabled('status', this.showControl, true)
      await (await this.windowClass).setSpecificSystemBarEnabled('navigationIndicator', this.showControl, true)
    }
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
    this.avPlayer?.off('subtitleUpdate');
    this.avPlayer?.off('timeUpdate')
    this.avPlayer?.off('seekDone')
    this.avPlayer?.off('speedDone')
    this.avPlayer?.off('audioOutputDeviceChangeWithInfo')
    this.avPlayer?.off('subtitleUpdate')
    this.avPlayer?.off('stateChange')
    this.audioVolumeManager?.off('volumeChange');
    this.audioVolumeManager = null
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
      // 保存播放数据，防止杀掉应用或者闪退丢失数据
      AppStorage.setOrCreate('nowPlayingData', [this.play_time, this.now_playing!, this.video_meta_data])
      if (this.showControl) {
        this.clock_time = ToolsUtil.getTime()
        if (!this.autoHideTimeout) {
          this.autoHideTimeout = true
          setTimeout(() => {
            this.lockVisibility = false;
            this.showControl = false
            this.autoHideTimeout = false
          }, 6000)
        }
      }
      if (this.now_playing?.end_time && duration >= this.now_playing?.end_time && !this.circle_play) {
        this.playNextVideo()
      }
      if (!this.onSwiping) {
        this.play_time = duration;
        if (this.mIjkMediaPlayer && Date.now() - VideoOperateUtil.lastSyncTime < VideoOperateUtil.syncCoolDown) {
          return;
        }
        const audioPosition = Number(this.mIjkMediaPlayer?.getCurrentPosition());
        const drift = duration - audioPosition; // 记录最近5次差异
        VideoOperateUtil.driftHistory.push(drift);
        if (VideoOperateUtil.driftHistory.length > 5) {
          VideoOperateUtil.driftHistory.shift();
        } // 动态阈值计算
        const buffer = this.mIjkMediaPlayer?.getAudioCachedBytes()!;
        const dynamicThreshold = Math.min(1000, 300 + buffer * 0.5); // 趋势分析（最近3次差异是否持续扩大）
        const isGrowing = VideoOperateUtil.driftHistory.slice(-3).every((v, i, arr) =>
        i === 0 || Math.abs(v) > Math.abs(arr[i-1])); // 触发条件：差异超过阈值或存在持续扩大趋势
        if (Math.abs(drift) > dynamicThreshold || (isGrowing && Math.abs(drift) > 300)) {
          this.handleIntelligentSync(duration, audioPosition);
          VideoOperateUtil.lastSyncTime = Date.now(); // 自适应调整冷却时间
          VideoOperateUtil.syncCoolDown = Math.max(500, 1000 - buffer * 2);
        }
      }
    });

    this.avPlayer?.on('seekDone', (percent) => {
      this.play_time = percent
      VideoOperateUtil.updateSession(this.playing, this.play_time)
    })

    this.avPlayer?.on('speedDone', (enumValue) => {
      this.speed = VideoInfoUtil.getVideoSpeed(enumValue) // 这里返回的是倍速的枚举值，需要转换为实际倍速
    })

    this.avPlayer?.on('audioOutputDeviceChangeWithInfo', (data: audio.AudioStreamDeviceChangeInfo) => {
      if (data.changeReason === audio.AudioStreamDeviceChangeReason.REASON_OLD_DEVICE_UNAVAILABLE) {
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
            let playStrategy: media.PlaybackStrategy = { showFirstFrameOnPrepare: true } // 设置播放配置
            this.avPlayer.setPlaybackStrategy(playStrategy);
            this.avPlayer.prepare();
          }
          break;
        case 'prepared':
          await this.getAudioTrack()
          this.videoStartPlayTime(VideoOperateUtil.getVideoStartPlayTimeMode(this.now_playing!, this.skipIntroTime))
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
            if (this.mIjkMediaPlayer) {
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
          this.playing = true
          if (!this.avSession && this.allowBackgroundPlay) {
            this.avSession = await AVSessionUtil.getAVSession()
            await this.setSessionListener()
            AVSessionUtil.setSessionInfo(this.now_playing!)
            VideoOperateUtil.updateSession(this.playing, this.play_time)
          }
          VideoOperateUtil.updateSession(this.playing, this.play_time)
          break
        case 'paused':
          if (this.mIjkMediaPlayer) {
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
          VideoOperateUtil.playErrorExecute(this.pathStack, this.video_meta_data, this.now_playing?.date!)
          this.avPlayer?.release()
          break;
      }
    })
  }

  async ijkPlayerStop() {
    if (this.mIjkMediaPlayer) {
      this.mIjkMediaPlayer?.pause(); // 先暂停再停止
      this.mIjkMediaPlayer?.reset();
      this.mIjkMediaPlayer?.stop()
      this.mIjkMediaPlayer?.release()
      this.mIjkMediaPlayer = null
    }
  }

  async setExternalSubtitle(now_playing: VideoMetadataFromPlayer) {
    if (await SubtitleUtil.isSubtitleExist(PathUtils.subtitlePath!, now_playing.date!)) {
      let file1 = fs.openSync(PathUtils.subtitlePath! + now_playing.date, fs.OpenMode.READ_ONLY)
      const size = fs.statSync(PathUtils.subtitlePath! + now_playing.date);
      this.avPlayer?.addSubtitleFromFd(file1.fd, 0, size.size);
    }
  }

  videoStartPlayTime(seekMode: number) {
    switch (seekMode) {
      case VideoStartTimeMode.SEEK_TO_LAST_PLAY_TIME:
        this.seekTime(this.now_playing?.last_play || 0)
        break
      case VideoStartTimeMode.SEEK_TO_START_TIME:
        this.seekTime(this.now_playing?.start_time || 0)
        break
      case VideoStartTimeMode.SEEK_TO_INTRO_TIME:
        this.seekTime(this.play_time + Number(this.skipIntroTime) * 1000)
        break
      default:
        return
    }
  }

  seekTime(seekTime: number) {
    this.avPlayer?.seek(seekTime, media.SeekMode.SEEK_CLOSEST)
    if (this.mIjkMediaPlayer) {
      this.mIjkMediaPlayer?.seekTo(String(seekTime))
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
      if (this.smartRotation && this.play_area_width > this.play_area_height &&
        this.screen_height > this.screen_width) {
        const proportion =
          Math.max(this.screen_width, this.screen_height) / Math.min(this.screen_width, this.screen_height)
        const orientation = proportion > (16 / 10)
          ? window.Orientation.AUTO_ROTATION_LANDSCAPE
          : window.Orientation.AUTO_ROTATION_RESTRICTED;
        (await this.windowClass).setPreferredOrientation(orientation)
      }
    }
  }

  async playChooseVideo(item: VideoMetadata) {
    if (!PrivacySpaceUtil.getPrivacyMode()) {
      RecentPlayUtil.addPlayback(PathUtils.appContext!, item)
    }
    await this.avPlayer?.reset()
    await this.ijkPlayerStop()
    this.now_playing = item as VideoMetadataFromPlayer
    this.getData()
    this.avSession = await AVSessionUtil.getAVSession()
    await this.setSessionListener()
    AVSessionUtil.setSessionInfo(this.now_playing!)
    VideoOperateUtil.updateSession(this.playing, this.play_time)
  }

  playNextVideo() {
    if (this.video_meta_data.length > 0 && this.play_time > 0) {
      this.ijkPlayerStop()
      VideoOperateUtil.saveVideoTime(this.play_time, this.now_playing!, this.video_meta_data,
        PathUtils.appContext!)
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
    if (VideoOperateUtil.aspectRatioMap.has(text)) {
      const ratio = VideoOperateUtil.aspectRatioMap.get(text)!;
      const play_area_size = VideoOperateUtil.setVideoAspectRatio(
        ratio,
        VideoInfoUtil.play_area_width,
        VideoInfoUtil.play_area_height
      );
      this.play_area_width = play_area_size[0];
      this.play_area_height = play_area_size[1];
      return;
    }
    switch (text) {
      case VideoInfoUtil.screen_extend_map[0]:
        this.play_area_height = VideoInfoUtil.play_area_height;
        this.play_area_width = VideoInfoUtil.play_area_width;
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

  backForward() {
    this.seekTime(this.play_time - Number(this.fastForwardSeconds) * 1000)
  }

  fastForward() {
    this.seekTime(this.play_time + Number(this.fastForwardSeconds) * 1000)
  }

  togglePlayback() {
    this.playing ? this.avPlayer?.pause() : this.avPlayer?.play()
  }

  build() {
    NavDestination() {
      SideBarContainer(SideBarContainerType.Overlay) {
        PlayerSideBarComponent({
          sideBarStatusTmp: this.sideBarStatusTmp,
          video_meta_data: this.video_meta_data,
          now_playing: this.now_playing,
          sideBarStatus: this.sideBarStatus,
          onItemClick: (item: VideoMetadata) => {
            this.playChooseVideo(item) // pass
            this.closeSideBar(true) // pass
          }
        })

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
          .animation({ duration: this.playing ? 300 : 0, curve: Curve.Ease })
          .rotate({ y: 2, angle: this.angle, perspective: 200 })

          if ((this.showControl && !this.isLock)) {
            Stack() {
              Flex({
                justifyContent: FlexAlign.SpaceBetween,
                alignItems: ItemAlign.Center,
                direction: FlexDirection.Column
              }) { //顶栏
                Flex({ justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Center }) {
                  Column() {
                    StatusBarComponent({
                      screenHeight: this.screen_height,
                      screenWidth: this.screen_width,
                      clockTime: this.clock_time
                    })
                    this.VideoTop()
                  }.width('100%')
                }
                .height(this.screen_height > this.screen_width ? 100 : 75)
                .backgroundColor('#36ffffff')
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
                .backgroundColor($r('sys.color.mask_fourth'))
                .height(this.screen_height > this.screen_width ? 180 : 110)
                .width('100%')
              }.height('100%').width('100%')
            }
            .animation({ duration: 300, curve: Curve.Smooth })
          }

          SubtitleComponent({
            subTitle: this.sub_title,
            screenWidth: this.screen_width,
            screenHeight: this.screen_height,
            showControl: this.showControl,
            subTitleVisibility: this.sub_title_visibility,
            playAreaWidth: this.play_area_width,
          })

          if (this.long_press) {
            FastForwardInfoComponent({
              speed: this.speed,
              location: 0 - VideoInfoUtil.play_area_height / 2 + 20
            })
          }

          if (this.onSwiping) {
            SwipingPlayTimeDisplay({
              isSliderPlayTimeChange: this.isSliderPlayTimeChange,
              playTime: this.play_time,
              totalTime: this.now_playing?.time,
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

          if (this.lockVisibility) {
            LockVideoBarComponent({
              isLock: this.isLock,
              screenHeight: this.screen_height,
              screenWidth: this.screen_width
            })
          }

          GestureComponent({
            showControl: this.showControl,
            onDoubleClickAction: (event: GestureEvent) => {
              if (this.isLock) {
                return;
              } // 设备锁定时直接返回
              if (!this.allowDoubleFastForward) { // 非双击快进模式时执行暂停
                this.togglePlayback()
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
              this.togglePlayback()
            },
            onSingleClickAction: () => {
              if (this.sideBarStatus) {
                this.closeSideBar(true);
              } else {
                this.lockVisibility = !this.lockVisibility;
                this.showControl = !this.showControl;
              }
            },
            onVerticalPanStart: (event: GestureEvent) => {
              if (!this.isLock) {
                const firstTouch = event.fingerList[0];
                this.isLeftSideSwipe = firstTouch.localX < this.screen_width / 2;
                VideoOperateUtil.screenBrightnessTmp = this.screenBrightness
                this.volume = this.volumeActually
                VideoOperateUtil.lastVolume = this.volume; // 记录起始音量
                VideoOperateUtil.lastVolumeTime = Date.now(); // 记录起始时间
                VideoOperateUtil.lastOffSetY = 0
              }
            },
            onVerticalPanUpdate: (event: GestureEvent) => {
              if (!this.isLock && event.fingerList.length === 1) {
                if (this.isLeftSideSwipe) {
                  this.onSwipingBrightness = true
                  const deltaYScale = event.offsetY / this.screen_height * 2.5
                  this.screenBrightness = VideoOperateUtil.calNewBrightness(deltaYScale)
                  VideoOperateUtil.setBrightness(this.screenBrightness);
                } else {
                  this.onSwipingVoice = true
                  let deltaY = event.offsetY - VideoOperateUtil.lastOffSetY
                  const deltaYScale = deltaY / this.screen_height * 150
                  this.volume = VideoOperateUtil.calNewVolume(deltaYScale)
                  VideoOperateUtil.lastVolumeTime = VideoOperateUtil.volumeGestureActiveTime;
                  VideoOperateUtil.lastVolume = this.volume
                  VideoOperateUtil.lastOffSetY = event.offsetY
                }
              }
            },
            onVerticalPanEnd: () => {
              this.onSwiping = false;
              this.onSwipingVoice = false;
              this.onSwipingBrightness = false;
            },
            onHorizonPanStart: (event: GestureEvent) => {
              if (!this.isLock) {
                const firstTouch = event.fingerList[0];
                this.swipe_start_x = firstTouch.localX;
                this.last_play_time = this.play_time;
                this.onSwiping = true
              }
            },
            onHorizonPanUpdate: (event: GestureEvent) => {
              if (this.isLock) {
                return
              }
              if (event?.fingerList?.[0]?.localX !== undefined &&
                typeof event.fingerList[0].localX === 'number') {
                const currentX = event.fingerList[0].localX;
                const deltaX = currentX - this.swipe_start_x;
                this.play_time = Math.max(0,
                  Math.min(this.last_play_time + (deltaX * VideoOperateUtil.timePerPixel), this.now_playing?.time!));
              }
            },
            onHorizonPanEnd: () => {
              this.seekTime(this.play_time)
              this.onSwiping = false;
            },
            onPinchStart: (event: GestureEvent) => {
              const finger1 = event.fingerList[0];
              const finger2 = event.fingerList[1];
              VideoOperateUtil.initPinchDistance = VideoOperateUtil.calcFingerDistance(finger1, finger2);
            },
            onPinchUpdate: (event: GestureEvent) => {
              if (this.isLock) {
                return;
              }
              const finger1 = event.fingerList[0];
              const finger2 = event.fingerList[1];
              if (!finger1 || !finger2) { // 双指检测失败直接返回
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
            },
            onLongPressAction: () => {
              if (!this.isLock) {
                this.long_press = true
                this.last_speed = this.speed
                this.updatePlaybackSpeed(3);
                this.currentSpeedIndex = VideoInfoUtil.video_speed_list.indexOf(3);
              }
            },
            onLongPressEnd: () => {
              this.long_press = false
              this.updatePlaybackSpeed(this.last_speed);
            },
            onLongPressPanStart: (event: GestureEvent) => {
              if (!this.isLock) {
                this.longPressStartX = event.fingerList[0].localX;
              }
            },
            onLongPressPanUpdate: (event: GestureEvent) => {
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
                const direction = Math.sign(deltaX);
                const newIndex = this.currentSpeedIndex + direction; // 计算新速度索引并限制在有效范围内
                const clampedIndex = Math.max(0, Math.min(newIndex, VideoInfoUtil.video_speed_list.length - 1));
                if (clampedIndex === this.currentSpeedIndex) { // 索引变化时才更新播放速度
                  return;
                }
                this.currentSpeedIndex = clampedIndex;
                this.updatePlaybackSpeed(VideoInfoUtil.video_speed_list[this.currentSpeedIndex]);
                this.longPressStartX = event.fingerList[0].localX; // 重置起始点实现分档切换效果
              }
            }
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
      .showSideBar(this.sideBarStatus)
      .sideBarPosition(SideBarPosition.End)
      .divider({ strokeWidth: 0 })
    }.onReady(() => {
      const playerParams: PlayerParams = this.pathStack.getParamByName('Player')[0] as PlayerParams
      try {
        this.now_playing = playerParams.metadata as VideoMetadataFromPlayer
        this.video_meta_data = playerParams.metadata_list as VideoMetadata[]
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
        this.avPlayer?.release()
        return false
      }
    })
    .onWillDisappear(async () => {
      if (this.video_meta_data.length > 0 && this.play_time > 0) {
        VideoOperateUtil.saveVideoTime(this.play_time, this.now_playing!, this.video_meta_data,
          PathUtils.appContext!)
      }
      if (this.allowBackgroundPlay) { //若发生错误跳转FFMpeg播放器，确保提前关闭申请防止两个播放器重复申请导致失败
        AVSessionUtil.destroySession()
        PermissionUtil.stopContinuousTask()
      }
      await this.ijkPlayerStop()
      await (await this.windowClass).setWindowKeepScreenOn(false)
      if (canIUse('SystemCapability.Window.SessionManager')) {
        await (await this.windowClass).setSpecificSystemBarEnabled('status', true)
        await (await this.windowClass).setSpecificSystemBarEnabled('navigationIndicator', true)
      }
      await (await this.windowClass).setPreferredOrientation(window.Orientation.AUTO_ROTATION_RESTRICTED);
      await this.avSession?.stopCasting();
    })
    .hideTitleBar(true)
  }

  @Builder
  VideoTop() {
    VideoTopComponent({
      videoTitle: this.now_playing?.title,
      subTitleVisibility: this.sub_title_visibility,
      screenExtendSelectedText: this.select_text,
      screenWidth: this.screen_width,
      screenHeight: this.screen_height,
      audioTrackMenuBuilder: this.getAudioMenuBuilder,
      lockRotation: this.lock_rotation,
      onExitVideoClick: () => {
        this.avPlayer?.reset()
        this.pathStack.pop()
      },
      onScreenExtendOptionSelected: (text: string) => {
        this.screenExtend(text!)
      },
      onLockRotationClick: async () => {
        this.lock_rotation = !this.lock_rotation
        const orientation = this.lock_rotation ?
          (this.screen_width > this.screen_height ? window.Orientation.AUTO_ROTATION_LANDSCAPE_RESTRICTED
            : window.Orientation.AUTO_ROTATION_PORTRAIT_RESTRICTED)
          : window.Orientation.AUTO_ROTATION_RESTRICTED
        await (await this.windowClass).setPreferredOrientation(orientation)
        const toastMessage = this.lock_rotation
          ? PathUtils.appContext!.resourceManager.getStringSync($r('app.string.open_rotation_lock'))
          : PathUtils.appContext!.resourceManager.getStringSync($r('app.string.close_rotation_lock'))
        ToolsUtil.showToast(toastMessage);
      }
    })
  }

  @Builder
  VideoSlider() {
    VideoSliderComponent({
      playTime: this.play_time,
      totalTime: this.now_playing?.time,
      screenWidth: this.screen_width,
      screenHeight: this.screen_height,
      onSliderChange: (value: number) => {
        this.onSwiping = true
        this.isSliderPlayTimeChange = true
        this.play_time = value
      },
      onSliderTouch: (event: TouchEvent) => {
        if (event.type == TouchType.Up) {
          this.seekTime(this.play_time)
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
      screenArco: this.screen_arco,
      playing: this.playing,
      speed: this.speed,
      circlePlay: this.circle_play,
      aVCastPickerBuilderBridge: this.AVCastPickerBuilderBridge,
      videoSettingBuilder: this.getVideoSettingBuilder,
      playbackSpeedMenu: this.getPlaybackSpeedMenuBuilder,
      onScreenRotationOrFullScreenClick: async () => {
        await VideoOperateUtil.fullScreenOperate()
        const orientation = this.screen_height > this.screen_width
          ? window.Orientation.AUTO_ROTATION_LANDSCAPE
          : window.Orientation.AUTO_ROTATION_PORTRAIT; // 这里是横竖屏切换顺应用户操作就好
        (await this.windowClass).setPreferredOrientation(orientation)
      },
      onTogglePlaybackClick: () => {
        this.togglePlayback()
      },
      onPlayNextVideoClick: () => {
        this.playNextVideo()
      },
      onSideBarStatusClick: () => {
        this.sideBarStatus ? this.closeSideBar(true) : this.openSideBar()
      }
    })
  }

  @Builder
  AudioTrackMenuBuilder() {
    AudioTrackComponent({
      audioTrack: this.audio_track,
      audioTrackSelected: this.audio_track_select,
      onSelect: (index: number) => {
        this.AudioTrackMenuBuilderState = false;
        this.avPlayer?.selectTrack(this.audio_track[index]?.index);
        this.audio_track_select = index;
      }
    })
  }

  @Builder
  VideoSettingBuilder() {
    VideoSettingComponent({
      playTime: this.play_time,
      circlePlay: this.circle_play,
      nowPlaying: this.now_playing,
      videoMetaData: this.video_meta_data,
      onMirrorClick: () => {
        this.angle === 0 ? this.angle = 180 : this.angle = 0
      }
    })
  }

  @Builder
  PlaybackSpeedMenuBuilder() {
    PlaybackSpeedMenuComponent({
      speed: this.speed,
      onSpeedChange: (speed: number) => {
        this.updatePlaybackSpeed(speed)
      }
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
}