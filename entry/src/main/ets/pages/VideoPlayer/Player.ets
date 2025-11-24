import { media } from '@kit.MediaKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import PermissionUtil from '../../utils/PermissionUtil';
import { window } from '@kit.ArkUI';
import { avSession as avSessionManager } from '@kit.AVSessionKit';
import AVSessionUtil from '../../utils/AVSessionUtil';
import ToolsUtil from '../../utils/ToolsUtil';
import VideoInfoUtil from '../../utils/VideoInfoUtil';
import { audio } from '@kit.AudioKit';
import SelectFileUtil from '../../utils/SelectFileUtil';
import VideoOperateUtil from '../../utils/VideoOperateUtil';
import RecentPlayUtil from '../../utils/RecentPlayUtil';
import { IjkMediaPlayer } from '@ohos/ijkplayer';
import { VideoMetadataFromPlayer } from '../../interfaces/VideoMetadataFromPlayerInterface';
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface';
import { AudioTrack } from '../../interfaces/AudioTrackInterface';
import Preferences from '../../database/Preferences';
import PrivacySpaceUtil from '../../utils/PrivacySpaceUtil';
import { PathUtils } from '../../utils/PathUtils';
import { PlayerSideBarComponent } from '../../component/PlayerComponent/PlayerSideBarComponent';
import { AVCastPickerBuilder } from '../../component/PlayerComponent/AVCastPickerBuilder';
import { AudioTrackComponent } from '../../component/PlayerComponent/AudioTrackComponent';
import { PlaybackSpeedMenuComponent } from '../../component/PlayerComponent/PlaybackSpeedComponent';
import { BrightnessSwipingComponent } from '../../component/PlayerComponent/BrightnessSwipingComponent';
import { VolumeSwipingComponent } from '../../component/PlayerComponent/VolumeSwipingComponent';
import { FastForwardInfoComponent } from '../../component/PlayerComponent/FastForwardInfoComponent';
import { SubtitleDisplayComponent } from '../../component/PlayerComponent/SubtitleDisplayComponent';
import { LockVideoBarComponent } from '../../component/PlayerComponent/LockVideoBarComponent';
import { SwipingPlayTimeDisplay } from '../../component/PlayerComponent/SwipingPlayTimeDisplay';
import { VideoSliderComponent } from '../../component/PlayerComponent/VideoSliderComponent';
import { GestureComponent } from '../../component/PlayerComponent/GestureComponent';
import { VideoTopComponent } from '../../component/PlayerComponent/VideoTopComponent';
import { VideoButtonsComponent } from '../../component/PlayerComponent/VideoButtonsComponent';
import { VideoSettingComponent } from '../../component/PlayerComponent/VideoSettingComponent';
import { RepeatMode } from '../../common/enum/RepeatMode';
import { VideoStartTimeMode } from '../../common/enum/VideoStartTimeMode';
import NavigationAddress, { PlayerParams } from '../../common/NavigationCommon';
import { WindowUtil } from '../../utils/WindowUtil';
import { KeyCode } from '@kit.InputKit';
import { XAnimation } from '../../utils/AnimationUtil';
import { AIAsr } from '../../component/VideoItemComponent/AIAsrComponent';
import SubtitleUtil from '../../utils/SubtitleUtil';
import { SubtitlePanelComponent } from '../../component/PlayerComponent/SubtitlePanelComponent';
import { SubtitleMode } from '../../common/enum/SubtitleMode';
import { AVPlayerUtil } from '../../utils/AVPlayerUtil';
import DataSyncUtil from '../../utils/DataSyncUtil';

@Component
export struct Player { // 播放页
  avPlayer: media.AVPlayer | undefined = undefined
  avSession: avSessionManager.AVSession | undefined = undefined;
  @State now_playing: VideoMetadataFromPlayer | undefined = undefined
  @State playing: boolean = false
  @State speed: number = 1.0
  @State playTime: number = 0
  surfaceID: string = ''
  @State longPress: boolean = false
  @State @Watch('setScreen') showControl: boolean = false
  @State lock_rotation: boolean = false
  xComponentController: XComponentController = new XComponentController()
  windowClass = WindowUtil.getWindow()
  @State screen_width: number = 0
  @State screen_height: number = 0
  @State play_area_height: number = 0
  @State play_area_width: number = 0
  @State onSwiping: boolean = false
  @State onSwipingVoice: boolean = false
  @State onSwipingBrightness: boolean = false
  @State volume: number = 0
  @State screenBrightness: number = 0
  @State video_meta_data: VideoMetadata[] = []
  @State select_text: string | undefined = '原始比例'
  @State repeatMode: RepeatMode = RepeatMode.LIST_LOOP
  @State audio_track: AudioTrack[] = []
  @State audio_track_select: number = 0
  @State sideBarStatusTmp: Visibility = Visibility.Hidden
  @State sideBarStatus: boolean = false
  @State isLock: boolean = false
  @State lockVisibility: boolean = false
  @State sub_title: string = ''
  @State sub_title_visibility: Visibility = Visibility.Visible
  @State subtitleSelected: SubtitleMode = SubtitleMode.INNER_SUBTITLE
  @State isAIAsrShown: boolean = false
  @State isSliderPlayTimeChange: boolean = false
  @State currentSpeedIndex: number = 0
  @State angle: number = 0
  @State volumeActually: number = 0
  @StorageLink('allowBackgroundPlay') allowBackgroundPlay: boolean = true
  @StorageLink('fastForwardSeconds') fastForwardSeconds: string = '15'
  @StorageLink('allowPlayBackExist') allowPlayBackExist: boolean = false
  @StorageLink('allowDoubleFastForward') allowDoubleFastForward: boolean = true
  @StorageLink('skipIntroTime') skipIntroTime: string = '0'
  @StorageProp('topSafeHeight') topSafeHeight: number = 0;
  @StorageLink('smartRotation') smartRotation: boolean = true
  @StorageLink('longPressSpeed') longPressSpeed: number = 3
  @StorageLink('isPrivacyBackground') isPrivacyBackground: boolean = false
  @Consume('pathStack') pathStack: NavPathStack
  @State exitVideoTime: number = 0
  private mIjkMediaPlayer: IjkMediaPlayer | null = null;
  private autoHideTimeout: boolean = false
  private audioVolumeManager: audio.AudioVolumeManager | null = null

  async setSessionListener() {
    try {
      this.avSession?.on('play', () => {
        if (this.mIjkMediaPlayer) {
          this.mIjkMediaPlayer?.start()
        }
        this.avPlayer?.play()?.catch(() => {
          console.error('player error')
        })
      });
      this.avSession?.on('pause', () => {
        this.avPlayer?.pause()?.catch(() => {
          console.error('player error')
        })
      });
      this.avSession?.on('seek', (position: number) => {
        this.seekTime(position)
      })
      this.avSession?.on('fastForward', () => {
        this.seekTime(this.playTime + 15000)
      })
      this.avSession?.on('rewind', () => {
        this.seekTime(this.playTime - 15000)
      })
      this.avSession?.on('playNext', () => {
        this.playNextVideo()
      })
      this.avSession?.on('outputDeviceChange', () => {
        this.avPlayer?.pause()?.catch(() => {
          console.error('player error')
        })
      })
    } catch (error) {
      console.error('set av session state error')
    }
  }

  async initVolumeAndBrightness() {
    let groupId: number = audio.DEFAULT_VOLUME_GROUP_ID;
    let audioManager = audio.getAudioManager();
    this.audioVolumeManager = audioManager.getVolumeManager();
    let volume_list = await VideoOperateUtil.getVolume(this.audioVolumeManager, groupId)
    this.volume = volume_list.get('volume')!
    this.volumeActually = this.volume
    try {
      this.audioVolumeManager.on('volumeChange', (volumeEvent: audio.VolumeEvent) => {
        let changeVolumeByVolumeButton = false
        if (!this.onSwipingVoice) { // 这里复用手势音量调节提示
          this.onSwipingVoice = !this.onSwipingVoice
          changeVolumeByVolumeButton = true
        }
        this.volumeActually = volumeEvent.volume
        ToolsUtil.startVibration()
        setTimeout(() => {
          if (changeVolumeByVolumeButton) {
            this.onSwipingVoice = !this.onSwipingVoice
          }
        }, 800)
      });
    } catch (error) {
      console.error('volumeChange error:' + error)
    }
    this.screenBrightness = await VideoOperateUtil.getScreenBrightness()
  }

  updatePlaybackSpeed(speed: number): void {
    if (!VideoInfoUtil.getVideoSpeedList(NavigationAddress.AV_PLAYER).includes(speed)) {
      speed = 1.0;
    }
    const systemSpeed = VideoInfoUtil.mapToSystemSpeed(speed);
    this.avPlayer?.setSpeed(systemSpeed);
    if (this.mIjkMediaPlayer) {
      this.mIjkMediaPlayer?.setSpeed(String(speed));
    }
  }

  async aboutToAppear(): Promise<void> {
    PermissionUtil.applyContinuousTask(this.allowBackgroundPlay)
    this.setScreen()
    try {
      await (await this.windowClass)?.setPreferredOrientation(window.Orientation.AUTO_ROTATION_RESTRICTED);
      WindowUtil.setKeepScreenStatus(PathUtils.appContext!, true)
      this.repeatMode = Preferences.getRepeatModeState(PathUtils.appContext!)
      const video_speed = Preferences.getVideoSpeed(PathUtils.appContext!)
      this.speed = parseFloat(video_speed?.replace('x', '') || '1');
    } catch (error) {
      console.error('player error' + error)
    }
  }

  async aboutToDisappear(): Promise<void> {
    VideoOperateUtil.setBrightness(-1)
    Preferences.saveVideoSpeed(PathUtils.appContext!,
      (VideoInfoUtil.getVideoSpeedList(NavigationAddress.AV_PLAYER).includes(this.speed) ? this.speed : 1) + 'x')
    Preferences.saveRepeatModeState(PathUtils.appContext!, this.repeatMode)
    WindowUtil.setBarState(PathUtils.appContext!, true, true)
    clearTimeout(this.exitVideoTime)
    this.avPlayer?.off('subtitleUpdate');
    this.avPlayer?.off('timeUpdate')
    this.avPlayer?.off('seekDone')
    this.avPlayer?.off('speedDone')
    this.avPlayer?.off('audioOutputDeviceChangeWithInfo')
    this.avPlayer?.off('subtitleUpdate')
    this.avPlayer?.off('stateChange')
    AppStorage.delete('nowPlayingData') //清除已保存的播放进度
    try {
      this.audioVolumeManager?.off('volumeChange');
    } catch (error) {
      console.error('volume off error' + error)
    }
    this.audioVolumeManager = null
    this.releaseAVPlayer()
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
    if (this.select_text !== '原始比例') {
      this.select_text = '原始比例'
    }
    VideoInfoUtil.saveOriginalVideoWidthAndHeight(this.play_area_width, this.play_area_height)
  }

  async getAudioTrack() {
    this.audio_track = await VideoOperateUtil.getAudioTracks(this.avPlayer!)
    if (VideoOperateUtil.validateAudioTracks(this.audio_track)) {
      this.avPlayer!.selectTrack(this.audio_track[0].index)?.catch(() => {
        console.error('player error')
      });
    } else {
      this.activeEnhanceAudio()
    }
  }

  activeEnhanceAudio() {
    this.mIjkMediaPlayer = IjkMediaPlayer.getInstance();
    try {
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
    } catch (error) {
      console.error('ijk error:' + error)
    }
  }

  async setAVPlayerCallback() {
    this.avPlayer?.on('timeUpdate', async (duration) => {
      AppStorage.setOrCreate('nowPlayingData', [this.playTime, this.now_playing!, this.video_meta_data])
      if (this.showControl) {
        if (!this.autoHideTimeout) {
          this.autoHideTimeout = true
          setTimeout(() => {
            this.lockVisibility = false;
            this.showControl = false
            this.autoHideTimeout = false
          }, 8000)
        }
      }
      if (this.now_playing?.end_time && duration >= this.now_playing?.end_time &&
        this.repeatMode !== RepeatMode.SINGLE_LOOP) {
        this.playNextVideo()
        ToolsUtil.showToast('已智能跳过片尾')
      }
      if (!this.onSwiping) {
        this.calPlayerSync(duration)
      }
      if (this.subtitleSelected === SubtitleMode.EXTERNAL_SUBTITLE) {
        this.sub_title = SubtitleUtil.getSubtitlesAtTime(duration)
      }
    });

    this.avPlayer?.on('seekDone', (percent) => {
      this.playTime = percent
      AVSessionUtil.updatePlaybackSessionState(this.playing, this.playTime)
    })

    this.avPlayer?.on('speedDone', (systemEnum: media.PlaybackSpeed) => {
      const actualSpeed = VideoInfoUtil.mapFromSystemSpeed(systemEnum);
      this.speed = actualSpeed;
    });

    this.avPlayer?.on('audioOutputDeviceChangeWithInfo', (data: audio.AudioStreamDeviceChangeInfo) => {
      if (data.changeReason === audio.AudioStreamDeviceChangeReason.REASON_OLD_DEVICE_UNAVAILABLE) {
        this.avPlayer?.pause()?.catch(() => {
          console.error('player error')
        })
      }
    });

    this.avPlayer?.on('stateChange', async (state) => {
      switch (state) {
        case 'initialized':
          if (this.avPlayer) {
            this.avPlayer.surfaceId = this.surfaceID
            this.avPlayer.setPlaybackStrategy({
              showFirstFrameOnPrepare: true
            })?.catch(() => {
              console.error('player error')
            });
            await this.setExternalSubtitle(this.now_playing!)
            this.avPlayer.prepare()?.catch(() => {
              console.error('player error')
            });
          }
          break;
        case 'prepared':
          this.videoStartPlayTime(VideoOperateUtil.getVideoStartPlayTimeMode(this.now_playing!, this.skipIntroTime))
          this.avPlayer?.play()?.catch(() => {
            console.error('player error')
          });
          await this.getAudioTrack()
          await this.initVolumeAndBrightness()
          this.updatePlaybackSpeed(this.speed)
          this.showControl = false
          this.lockVisibility = false
          this.isSliderPlayTimeChange = false
          this.onSwiping = false
          break;
        case 'completed':
          VideoOperateUtil.saveVideoTime(this.playTime, this.now_playing!, this.video_meta_data,
            PathUtils.appContext!)
          const targetItem = this.video_meta_data.find(i => i.date == this.now_playing?.date)
          if (targetItem) {
            targetItem!.last_play = this.playTime
          }
          if (this.repeatMode === RepeatMode.SINGLE_LOOP) {
            if (this.mIjkMediaPlayer) {
              this.mIjkMediaPlayer?.seekTo('0')
              this.mIjkMediaPlayer?.start()
            }
            this.avPlayer?.play()?.catch(() => {
              console.error('player error')
            })
            this.avPlayer?.seek(0, media.SeekMode.SEEK_CLOSEST)
          } else {
            this.playNextVideo()
          }
          break;
        case 'playing':
          this.playing = true
          if (this.mIjkMediaPlayer) {
            this.mIjkMediaPlayer?.start()
          }
          this.initAVSession()
          AVSessionUtil.updatePlaybackSessionState(this.playing, this.playTime)
          break
        case 'paused':
          if (this.mIjkMediaPlayer) {
            this.mIjkMediaPlayer?.pause()
          }
          this.playing = false
          AVSessionUtil.updatePlaybackSessionState(this.playing, this.playTime)
          break
        case 'released':
          await this.ijkPlayerStop()
          this.playing = false
          AVSessionUtil.updatePlaybackSessionState(this.playing, this.playTime)
          break
        case 'idle':
          await this.ijkPlayerStop()
          this.releaseAVPlayer()
          break;
        case 'error':
          await this.ijkPlayerStop()
          VideoOperateUtil.playErrorExecute(this.pathStack, this.video_meta_data, this.now_playing?.date!,
            NavigationAddress.FFMPEG_PLAYER)
          this.releaseAVPlayer()
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
      try {
        let file1 = fs.openSync(PathUtils.subtitlePath! + now_playing.date, fs.OpenMode.READ_ONLY)
        await SubtitleUtil.parseSubtitleProcess(file1.path, now_playing.external_subtitle_format) ?
          this.subtitleSelected = SubtitleMode.EXTERNAL_SUBTITLE : this.subtitleSelected = SubtitleMode.INNER_SUBTITLE
      } catch (error) {
        this.subtitleSelected = SubtitleMode.INNER_SUBTITLE
        console.error('subtitle error' + error)
      }
    } else {
      this.subtitleSelected = SubtitleMode.INNER_SUBTITLE
    }
    this.avPlayer?.on('subtitleUpdate', async (info: media.SubtitleInfo) => { // 需要进入prepare状态前完成注册
      if (VideoOperateUtil.clearSubtitleTimer !== null) {
        clearTimeout(VideoOperateUtil.clearSubtitleTimer);
        VideoOperateUtil.clearSubtitleTimer = null;
      }
      if (this.subtitleSelected === SubtitleMode.INNER_SUBTITLE) {
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
      }
    });
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
        this.seekTime(this.playTime + Number(this.skipIntroTime) * 1000)
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

  releaseAVPlayer() {
    this.avPlayer?.release()?.catch(() => {
      console.error('player error')
    })
  }

  async getData() {
    this.avPlayer = await AVPlayerUtil.getAVPlayer()
    if (this.avPlayer) {
      this.setAVPlayerCallback()
      await PermissionUtil.activatePermission(this.now_playing?.uri || '')
      try {
        this.avPlayer.fdSrc = fs.openSync(this.now_playing?.uri);
      } catch (error) {
        ToolsUtil.showToast('视频打开失败，可能已失效')
        DataSyncUtil.invalidVideoIndex = this.video_meta_data.findIndex(i => i.date === this.now_playing?.date)
        this.pathStack.pop()
      }
      this.setRotation()
      if (this.windowClass) {
        this.play_area_width > this.play_area_height ? WindowUtil.enableLandscapeMultiWindow(this.windowClass) :
          WindowUtil.disableLandscapeMultiWindow(this.windowClass)
      }
      if (this.smartRotation && this.play_area_width > this.play_area_height &&
        this.screen_height > this.screen_width) {
        const proportion =
          Math.max(this.screen_width, this.screen_height) / Math.min(this.screen_width, this.screen_height)
        const orientation = proportion > (16 / 10) ? window.Orientation.AUTO_ROTATION_LANDSCAPE
          : window.Orientation.AUTO_ROTATION_RESTRICTED;
        (await this.windowClass)?.setPreferredOrientation(orientation)?.catch(() => {
          console.error('player error')
        })
      }
    }
  }

  async playChooseVideo(item: VideoMetadata) {
    VideoOperateUtil.saveVideoTime(this.playTime, this.now_playing!, this.video_meta_data,
      PathUtils.appContext!)
    if (!PrivacySpaceUtil.getPrivacyMode()) {
      RecentPlayUtil.addPlayback(PathUtils.appContext!, item)
    }
    this.avPlayer?.off('subtitleUpdate');
    try {
      await this.avPlayer?.reset()
    } catch (error) {
      console.error('reset error' + error)
    }
    await this.ijkPlayerStop()
    this.now_playing = item as VideoMetadataFromPlayer
    this.getData()
    this.initAVSession()
  }

  playNextVideo() {
    if (this.video_meta_data.length === 0 || this.playTime <= 0) {
      return;
    }
    const currentDate = this.now_playing?.date || '';
    let item = SelectFileUtil.getItem(this.video_meta_data, currentDate) as VideoMetadata;
    if (!item) {
      item = this.video_meta_data[0];
    }
    let nextItem: VideoMetadata | null = null;
    try {
      if (this.repeatMode === RepeatMode.RANDOM) {
        const availableVideos = this.video_meta_data.filter(v => v.date !== item.date);
        nextItem = availableVideos.length > 0
          ? availableVideos[Math.floor(Math.random() * availableVideos.length)]
          : item
      } else if (this.repeatMode === RepeatMode.SINGLE_PLAY) {
        this.exitVideo(0);
        return
      } else {
        nextItem = SelectFileUtil.getNextItem(this.video_meta_data, item.date);
      }
      if (nextItem) {
        this.playChooseVideo(nextItem);
      }
    } catch (error) {
      console.error('Error in playNextVideo:', error);
      this.exitVideo(0);
    }
  }

  closeSideBar(isPlayAnimation: boolean) {
    this.sideBarStatusTmp = Visibility.Hidden
    isPlayAnimation ? setTimeout(() => {
      this.sideBarStatus = false
    }, 400) : this.sideBarStatus = false
  }

  backForward() {
    this.seekTime(this.playTime - Number(this.fastForwardSeconds) * 1000)
  }

  fastForward() {
    this.seekTime(this.playTime + Number(this.fastForwardSeconds) * 1000)
  }

  togglePlayback() {
    this.playing ? this.avPlayer?.pause()?.catch(() => {
      console.error('player error')
    }) : this.avPlayer?.play()?.catch(() => {
      console.error('player error')
    })
  }

  setScreen() {
    WindowUtil.setBarState(PathUtils.appContext!, this.showControl, this.showControl)
  }

  async initAVSession() {
    if (!this.avSession && this.allowBackgroundPlay) {
      this.avSession = await AVSessionUtil.getAVSession()
      await this.setSessionListener()
      AVSessionUtil.setSessionInfo(this.now_playing!)
      AVSessionUtil.updatePlaybackSessionState(this.playing, this.playTime)
    }
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
            this.playChooseVideo(item)
            this.closeSideBar(true)
          }
        })

        Stack() {
          Stack() { //播放器
            XComponent({ type: XComponentType.SURFACE, controller: this.xComponentController })
              .onLoad(() => {
                this.surfaceID = this.xComponentController.getXComponentSurfaceId()
                this.getData()
              }).focusable(true)
              .defaultFocus(true)
            SubtitleDisplayComponent({
              subTitle: this.sub_title,
              screenWidth: this.screen_width,
              screenHeight: this.screen_height,
              showControl: this.showControl,
              subTitleVisibility: this.sub_title_visibility,
              playAreaWidth: this.play_area_width,
            })
          }
          .onKeyEvent((event?: KeyEvent) => {
            if (!event || event.type !== KeyType.Down) {
              return;
            }
            if (event.keyCode === KeyCode.KEYCODE_SPACE) {
              this.togglePlayback()
            }
            if (event.keyCode === KeyCode.KEYCODE_ESCAPE) {
              this.exitVideo(0)
            }
            if (event.keyCode === KeyCode.KEYCODE_DPAD_RIGHT) {
              this.fastForward();
            }
            if (event.keyCode === KeyCode.KEYCODE_DPAD_LEFT) {
              this.backForward();
            }
          })
          .width(this.play_area_width)
          .height(this.play_area_height)
          .animation({ duration: this.playing ? 300 : 0, curve: Curve.Ease })
          .rotate({ y: 2, angle: this.angle, perspective: 200 })

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
                .transition(XAnimation.getAnimation('up', 0, false))
                .height(90)
                .backgroundColor('#36ffffff')
                .width('100%')
                .padding({
                  left: (this.screen_height > this.screen_width ? 20 : 35),
                  right: 20,
                  top: (this.screen_height > this.screen_width ? this.topSafeHeight : 0),
                  bottom: 0
                })

                Stack() { //底栏
                  if (this.screen_height / this.screen_width > 1.4) {
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
                }.transition(XAnimation.getAnimation('bottom', 0, false))
                .backgroundColor($r('sys.color.mask_fourth'))
                .height(this.screen_height > this.screen_width ? 180 : 110)
                .width('100%')
              }.height('100%').width('100%')
            }
          }

          if (this.longPress) {
            FastForwardInfoComponent({
              speed: this.speed,
              location: this.play_area_height,
            })
          }
          if (this.onSwiping) {
            SwipingPlayTimeDisplay({
              isSliderPlayTimeChange: this.isSliderPlayTimeChange,
              playTime: this.playTime,
              totalTime: this.now_playing?.time,
            })
          }

          VolumeSwipingComponent({
            videoVolume: this.volume,
            videoVolumeShow: this.volumeActually,
            onSwipingVoice: this.onSwipingVoice,
          })

          if (this.onSwipingBrightness) {
            BrightnessSwipingComponent({
              screenBrightness: this.screenBrightness,
            })
          }
          if (this.lockVisibility) {
            LockVideoBarComponent({
              isLock: this.isLock,
              screenHeight: this.screen_height,
              screenWidth: this.screen_width,
              showControl: this.showControl,
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
              const tapX = event.fingerList[0]?.localX;
              if (!VideoOperateUtil.checkLocalX(tapX)) {
                return
              }
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
                XAnimation.runWithAnimation(() => {
                  if (this.isLock) {
                    this.showControl = false
                  } else {
                    this.showControl = !this.showControl;
                  }
                })
              }
            },
            onVerticalPanStart: (event: GestureEvent) => {
              if (!this.isLock) {
                const tapX = event.fingerList[0]?.localX;
                if (!VideoOperateUtil.checkLocalX(tapX)) {
                  return
                }
                VideoOperateUtil.leftSideSwipe = tapX < this.screen_width / 2;
                VideoOperateUtil.screenBrightnessTmp = this.screenBrightness
                this.volume = this.volumeActually
                VideoOperateUtil.lastVolume = this.volume; // 记录起始音量
              }
            },
            onVerticalPanUpdate: (event: GestureEvent) => {
              if (!this.isLock && event.fingerList?.length === 1) {
                const deltaYScale = event?.offsetY / this.screen_height * 2.5
                if (VideoOperateUtil.leftSideSwipe) {
                  this.onSwipingBrightness = true
                  this.screenBrightness = VideoOperateUtil.calNewBrightness(deltaYScale)
                  VideoOperateUtil.setBrightness(this.screenBrightness);
                } else {
                  this.onSwipingVoice = true
                  const newVolume = VideoOperateUtil.lastVolume - deltaYScale * 20;
                  this.volume =
                    Math.min(Math.max(newVolume, VideoOperateUtil.min_volume), VideoOperateUtil.max_volume);
                }
              }
            },
            onVerticalPanEnd: () => {
              this.onSwiping = false;
              this.onSwipingVoice = false;
              this.onSwipingBrightness = false;
            },
            onHorizonPanStart: (_event: GestureEvent) => {
              if (!this.isLock) {
                VideoOperateUtil.lastPlayTime = this.playTime;
                this.onSwiping = true;
              }
            },
            onHorizonPanUpdate: (event: GestureEvent) => {
              if (this.isLock) {
                return;
              }
              if (!VideoOperateUtil.checkLocalX(event?.fingerList?.[0]?.localX)) {
                return
              }
              const timePerPixel = VideoOperateUtil.getTimePixel(this.screen_width, this.now_playing?.time!)
              this.playTime = Math.max(0,
                Math.min(VideoOperateUtil.lastPlayTime + (event.offsetX * timePerPixel),
                  this.now_playing?.time!));
            },
            onHorizonPanEnd: () => {
              this.seekTime(this.playTime);
              this.onSwiping = false;
            },
            onPinchStart: (event: GestureEvent) => {
              const finger1 = event.fingerList[0];
              const finger2 = event.fingerList[1];
              const fingerDistance = VideoOperateUtil.calcFingerDistance(finger1, finger2)
              if (fingerDistance >= 0) {
                VideoOperateUtil.initPinchDistance = fingerDistance
              } else {
                return
              }
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
              const fingerDistance = VideoOperateUtil.calcFingerDistance(finger1, finger2)
              if (fingerDistance >= 0) {
                const rawScale = fingerDistance / VideoOperateUtil.initPinchDistance;
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
                XAnimation.runWithAnimation(() => {
                  this.play_area_width = this.play_area_width;
                  this.play_area_height = this.play_area_height;
                })
              }
            },
            onLongPressAction: () => {
              if (!this.isLock) {
                this.longPress = true
                VideoOperateUtil.lastSpeed = this.speed
                this.updatePlaybackSpeed(this.longPressSpeed);
                this.currentSpeedIndex =
                  VideoInfoUtil.getVideoSpeedList(NavigationAddress.AV_PLAYER).indexOf(this.longPressSpeed);
              }
            },
            onLongPressEnd: () => {
              this.longPress = false
              this.updatePlaybackSpeed(VideoOperateUtil.lastSpeed);
            },
            onLongPressPanStart: (event: GestureEvent) => {
              if (this.isLock) {
                return
              }
              const tapX = event.fingerList[0]?.localX
              if (!VideoOperateUtil.checkLocalX(tapX)) {
                return
              }
              VideoOperateUtil.longPressStartX = tapX
            },
            onLongPressPanUpdate: (event: GestureEvent) => {
              if (!this.isLock && this.longPress) { // 长按状态下的滑动处理
                const tapX = event.fingerList[0]?.localX
                if (!VideoOperateUtil.checkLocalX(tapX)) {
                  return
                }
                const deltaX = tapX - VideoOperateUtil.longPressStartX;
                const SWIPE_THRESHOLD = 15;
                if (Math.abs(deltaX) <= SWIPE_THRESHOLD) { // 未达到滑动阈值则直接返回
                  return;
                }
                const direction = Math.sign(deltaX);
                const newIndex = this.currentSpeedIndex + direction; // 计算新速度索引并限制在有效范围内
                const clampedIndex = Math.max(0,
                  Math.min(newIndex, VideoInfoUtil.getVideoSpeedList(NavigationAddress.AV_PLAYER).length - 1));
                if (clampedIndex === this.currentSpeedIndex) { // 索引变化时才更新播放速度
                  return;
                }
                this.currentSpeedIndex = clampedIndex;
                this.updatePlaybackSpeed(VideoInfoUtil.getVideoSpeedList(NavigationAddress.AV_PLAYER)[this.currentSpeedIndex]);
                VideoOperateUtil.longPressStartX = event.fingerList[0]?.localX; // 重置起始点实现分档切换效果
              }
            }
          })

          AIAsr({
            isShown: this.isAIAsrShown
          })
            .visibility(this.showControl ? Visibility.None : Visibility.Visible)
            .width('80%').height(80)
            .offset({
              x: 0,
              y: this.screen_width > this.screen_height ? this.screen_height / 2 - 40 : this.screen_height / 2 - 100
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
      .sideBarWidth(300)
      .showSideBar(this.sideBarStatus)
      .sideBarPosition(SideBarPosition.End)
      .divider({ strokeWidth: 0 })
    }
    .onReady(() => {
      const playerParams: PlayerParams = this.pathStack.getParamByName(NavigationAddress.AV_PLAYER)[0] as PlayerParams
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
        this.releaseAVPlayer()
        DataSyncUtil.lastPlayVideoIndex = this.video_meta_data.findIndex(i => i.date === this.now_playing?.date)
        return false
      }
    })
    .onWillDisappear(async () => {
      if (this.video_meta_data.length > 0 && this.playTime > 0) {
        VideoOperateUtil.saveVideoTime(this.playTime, this.now_playing!, this.video_meta_data,
          PathUtils.appContext!)
      }
      PermissionUtil.applyStopContinuousTask(this.allowBackgroundPlay)
      await this.ijkPlayerStop()
      try {
        WindowUtil.setKeepScreenStatus(PathUtils.appContext!, false)
        if (canIUse('SystemCapability.Window.SessionManager')) {
          await (await this.windowClass)?.setSpecificSystemBarEnabled('status', true)
          await (await this.windowClass)?.setSpecificSystemBarEnabled('navigationIndicator', true)
        }
        await (await this.windowClass)?.setPreferredOrientation(window.Orientation.AUTO_ROTATION_RESTRICTED);
        await this.avSession?.stopCasting();
      } catch (error) {
        console.error('player error：' + error)
      }
    })
    .hideTitleBar(true)
    .blur(this.isPrivacyBackground ? 1000 : 0)
  }

  exitVideo(timeOut: number) {
    this.exitVideoTime = setTimeout(() => {
      this.avPlayer?.reset()?.catch(() => {
        console.error('player error')
      })
      DataSyncUtil.lastPlayVideoIndex = this.video_meta_data.findIndex(i => i.date === this.now_playing?.date)
      this.pathStack.pop()
    }, timeOut);
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
      subtitleMenuBuilder: this.getSubtitleMenuBuilder,
      lockRotation: this.lock_rotation,
      playAreaHeight: this.play_area_height,
      playAreaWidth: this.play_area_width,
      onExitVideoClick: () => {
        this.exitVideo(0)
      },
      onLockRotationClick: async () => {
        this.lock_rotation = !this.lock_rotation
        const orientation = this.lock_rotation ?
          (this.screen_width > this.screen_height ? window.Orientation.AUTO_ROTATION_LANDSCAPE_RESTRICTED
            : window.Orientation.AUTO_ROTATION_PORTRAIT_RESTRICTED)
          : window.Orientation.AUTO_ROTATION_RESTRICTED
        try {
          XAnimation.runWithAnimation(async () => {
            await (await this.windowClass)?.setPreferredOrientation(orientation)
          })
        } catch (error) {
          ToolsUtil.errorCatchExec('屏幕旋转异常', String(error))
        }
        const toastMessage = this.lock_rotation
          ? ToolsUtil.getStringResource($r('app.string.open_rotation_lock').id)
          : ToolsUtil.getStringResource($r('app.string.close_rotation_lock').id)
        ToolsUtil.showToast(toastMessage);
      }
    })
  }

  @Builder
  VideoSlider() {
    VideoSliderComponent({
      playTime: this.playTime,
      totalTime: this.now_playing?.time,
      screenWidth: this.screen_width,
      screenHeight: this.screen_height,
      playSpeed: this.speed,
      onSliderChange: (value: number) => {
        this.onSwiping = true
        this.isSliderPlayTimeChange = true
        this.playTime = value
      },
      onSliderTouch: (event: TouchEvent) => {
        if (event.type == TouchType.Up) {
          this.seekTime(this.playTime)
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
      screenHeight: this.screen_height,
      screenWidth: this.screen_width,
      playing: this.playing,
      speed: this.speed,
      aVCastPickerBuilderBridge: this.AVCastPickerBuilderBridge,
      videoSettingBuilder: this.getVideoSettingBuilder,
      playbackSpeedMenu: this.getPlaybackSpeedMenuBuilder,
      repeatMode: this.repeatMode,
      sideBarStatusTmp: this.sideBarStatusTmp,
      sideBarStatus: this.sideBarStatus,
      onScreenRotationOrFullScreenClick: async () => {
        const orientation = await WindowUtil.fullScreenOperate(this.screen_height, this.screen_width, this.windowClass)
        if (orientation) {
          XAnimation.runWithAnimation(async () => {
            (await this.windowClass)?.setPreferredOrientation(orientation)?.catch(() => {
              console.error('setPreferredOrientation error')
            })
          })
        }
      },
      onTogglePlaybackClick: () => {
        this.togglePlayback()
      },
      onPlayNextVideoClick: () => {
        this.playNextVideo()
      },
      onSideBaClose: () => {
        this.closeSideBar(true)
      }
    })
  }

  @Builder
  AudioTrackMenuBuilder() {
    AudioTrackComponent({
      audioTrack: this.audio_track,
      audioTrackSelected: this.audio_track_select,
      onSelect: (index: number) => {
        this.avPlayer?.selectTrack(this.audio_track[index]?.index)?.catch(() => {
          console.error('select track error')
        });
        this.audio_track_select = index;
      }
    })
  }

  @Builder
  VideoSettingBuilder() {
    VideoSettingComponent({
      playTime: this.playTime,
      nowPlaying: this.now_playing,
      videoMetaData: this.video_meta_data,
      angle: this.angle,
      repeatMode: this.repeatMode,
      exitVideoTime: this.exitVideoTime,
      forward_80_s: (time: number) => {
        this.seekTime(time)
      },
      onActiveEnhanceAudio: () => {
        this.activeEnhanceAudio()
        ToolsUtil.showToast('增强型解码启用成功')
      },
      closeAfter15min: (time: number) => {
        this.exitVideo(time)
      },
      closeAfter30min: (time: number) => {
        this.exitVideo(time)
      },
      closeAfter60min: (time: number) => {
        this.exitVideo(time)
      },
    })
  }

  @Builder
  PlaybackSpeedMenuBuilder() {
    PlaybackSpeedMenuComponent({
      speed: this.speed,
      player: NavigationAddress.AV_PLAYER,
      onSpeedChange: (speed: number) => {
        this.updatePlaybackSpeed(speed)
      }
    })
  }

  @Builder
  SubtitleMenuBuilder() {
    SubtitlePanelComponent({
      subTitleVisibility: this.sub_title_visibility,
      isAIAsrShown: this.isAIAsrShown,
      subtitleSelected: this.subtitleSelected
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
  private getSubtitleMenuBuilder: () => void = () => {
    this.SubtitleMenuBuilder()
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
    this.avPlayer?.pause()?.catch(() => {
      console.error('player error')
    });
    this.mIjkMediaPlayer?.pause();
    this.mIjkMediaPlayer?.seekTo(String(position))
    await new Promise<void>(resolve => setTimeout(resolve, 50));
    this.avPlayer?.play()?.catch(() => {
      console.error('player error')
    });
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
      if (Math.abs(this.playTime - Number(this.mIjkMediaPlayer?.getCurrentPosition())) < 310) {
        this.mIjkMediaPlayer?.setSpeed(String(this.speed));
      } else {
        setTimeout(restore, 1000);
      }
    };
    setTimeout(restore, 30000);
  }

  private calPlayerSync(duration: number) {
    this.playTime = duration;
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
}