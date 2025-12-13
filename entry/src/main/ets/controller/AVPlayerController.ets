import { media } from '@kit.MediaKit';
import { avSession as avSessionManager } from '@kit.AVSessionKit';
import { IjkMediaPlayer } from '@ohos/ijkplayer';
import VideoOperateUtil from '../utils/VideoOperateUtil';
import { fileIo as fs } from '@kit.CoreFileKit';
import { VideoMetadataFromPlayer } from '../interfaces/VideoMetadataFromPlayerInterface';
import NavigationAddress from '../common/NavigationCommon';
import VideoInfoUtil from '../utils/VideoInfoUtil';
import AVSessionUtil from '../utils/AVSessionUtil';
import { AudioTrack } from '../interfaces/AudioTrackInterface';
import { VideoStartTimeMode } from '../common/enum/VideoStartTimeMode';
import ToolsUtil from '../utils/ToolsUtil';
import { audio } from '@kit.AudioKit';
import { SubtitleMode } from '../common/enum/SubtitleMode';
import { PathUtils } from '../utils/PathUtils';
import SubtitleUtil from '../utils/SubtitleUtil';
import { AVPlayerUtil } from '../utils/AVPlayerUtil';
import { VideoMetadata } from '../interfaces/VideoMetadataInterface';
import SelectFileUtil from '../utils/SelectFileUtil';
import { RepeatMode } from '../common/enum/RepeatMode';
import { Setting } from '../utils/ObservedUtil';

@Observed
export class AVPlayerController {
  avPlayer: media.AVPlayer | undefined = undefined
  avSession: avSessionManager.AVSession | undefined = undefined
  surfaceID: string = ''
  @Track nowPlaying: VideoMetadataFromPlayer | undefined = undefined
  @Track playing: boolean = false
  @Track speed: number = 1.0
  @Track playTime: number = 0
  @Track audio_track: AudioTrack[] = []
  @Track volume: number = 0
  @Track volumeActually: number = 0
  @Track screenBrightness: number = 0
  @Track onSwipingVoice: boolean = false
  @Track subtitleSelected: SubtitleMode = SubtitleMode.INNER_SUBTITLE
  @Track subtitle: string = ''
  @Track subtitleVisibility: Visibility = Visibility.Visible
  @Track video_meta_data: VideoMetadata[] = []
  mIjkMediaPlayer: IjkMediaPlayer | null = null
  audioVolumeManager: audio.AudioVolumeManager | null = null

  async setSessionListener() {
    try {
      this.avSession?.on('play', () => {
        if (this.mIjkMediaPlayer) {
          this.mIjkMediaPlayer?.start()
        }
        this.playAVPlayer()
      });
      this.avSession?.on('pause', () => {
        this.pauseAVPlayer()
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
        // this.playNextVideo()
      })
      this.avSession?.on('outputDeviceChange', () => {
        this.pauseAVPlayer()
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


  async setExternalSubtitle(now_playing: VideoMetadataFromPlayer) {
    if (await SubtitleUtil.isSubtitleExist(PathUtils.subtitlePath!, now_playing.date!)) {
      try {
        let subtitle = fs.openSync(PathUtils.subtitlePath! + now_playing.date, fs.OpenMode.READ_ONLY)
        await SubtitleUtil.parseSubtitleProcess(subtitle.path, now_playing.external_subtitle_format) ?
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
          this.subtitle = text;
          if (duration > 0) {
            VideoOperateUtil.clearSubtitleTimer = setTimeout(() => {
              this.subtitle = '';
            }, duration) as number;
          }
        } else {
          this.subtitle = '';
        }
      }
    });
  }

  videoStartPlayTime(seekMode: number) {
    switch (seekMode) {
      case VideoStartTimeMode.SEEK_TO_LAST_PLAY_TIME:
        this.seekTime(this.nowPlaying?.last_play || 0)
        break
      case VideoStartTimeMode.SEEK_TO_START_TIME:
        this.seekTime(this.nowPlaying?.start_time || 0)
        break
      case VideoStartTimeMode.SEEK_TO_INTRO_TIME:
        this.seekTime(this.playTime + Number(Setting.skipIntroTime) * 1000)
        break
      default:
        return
    }
  }

  async initAVSession() {
    if (!this.avSession && Setting.allowBackgroundPlay) {
      this.avSession = await AVSessionUtil.getAVSession()
      await this.setSessionListener()
      AVSessionUtil.setSessionInfo(this.nowPlaying!)
      AVSessionUtil.updatePlaybackSessionState(this.playing, this.playTime)
    }
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

  releaseAVPlayer() {
    this.avPlayer?.release()?.catch(() => {
      console.error('player error')
    })
    AVPlayerUtil.avPlayer = undefined
  }

  resetAVPlayer() {
    this.avPlayer?.reset()?.catch(() => {
      console.error('player error')
    })
  }

  prepareAVPlayer() {
    this.avPlayer?.prepare()?.catch(() => {
      console.error('player error')
    });
  }

  pauseAVPlayer() {
    this.avPlayer?.pause()?.catch(() => {
      ToolsUtil.addLogger(`pause error`, true)
    })
  }

  playAVPlayer() {
    this.avPlayer?.play()?.catch(() => {
      ToolsUtil.addLogger(`play error`, true)
    })
  }

  cancelSubscribe() {
    this.avPlayer?.off('subtitleUpdate');
    this.avPlayer?.off('timeUpdate')
    this.avPlayer?.off('seekDone')
    this.avPlayer?.off('speedDone')
    this.avPlayer?.off('audioOutputDeviceChangeWithInfo')
    this.avPlayer?.off('subtitleUpdate')
    this.avPlayer?.off('stateChange')
  }

  playNextVideo(repeatMode: RepeatMode) {
    if (this.video_meta_data.length === 0 || this.playTime <= 0) {
      return
    }
    const currentDate = this.nowPlaying?.date || ''
    let item = SelectFileUtil.getItem(this.video_meta_data, currentDate) as VideoMetadata
    if (!item) {
      item = this.video_meta_data[0]
    }
    let nextItem: VideoMetadata | null = null
    try {
      if (repeatMode === RepeatMode.RANDOM) {
        const availableVideos = this.video_meta_data.filter(v => v.date !== item.date)
        nextItem = availableVideos.length > 0
          ? availableVideos[Math.floor(Math.random() * availableVideos.length)]
          : item
      } else if (repeatMode === RepeatMode.ONCE) {
        return false
      } else {
        if (repeatMode === RepeatMode.SEQUENCE) {
          if (SelectFileUtil.isLastItem(this.video_meta_data, item.date)) {
            return false
          }
        }
        nextItem = SelectFileUtil.getNextItem(this.video_meta_data, item.date)
      }
      if (nextItem) {
        return nextItem
      }
      return undefined
    } catch (error) {
      ToolsUtil.addLogger(`Error in playNextVideo: ${error}`, true, undefined, 'player')
      return undefined
    }
  }

  activeEnhanceAudio() {
    this.mIjkMediaPlayer = IjkMediaPlayer.getInstance();
    try {
      const video_url = fs.openSync(this.nowPlaying?.uri).path
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

  togglePlayback() {
    this.playing ? this.pauseAVPlayer() : this.playAVPlayer()
  }

  backForward() {
    this.seekTime(this.playTime - Number(Setting.fastForwardSeconds) * 1000)
  }

  fastForward() {
    this.seekTime(this.playTime + Number(Setting.fastForwardSeconds) * 1000)
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

  seekTime(seekTime: number) {
    this.avPlayer?.seek(seekTime, media.SeekMode.SEEK_CLOSEST)
    if (this.mIjkMediaPlayer) {
      this.mIjkMediaPlayer?.seekTo(String(seekTime))
    }
  }

  async handleIntelligentSync(videoPos: number, audioPos: number) {
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

  async fullResetSync(position: number) { // 严重不同步处理
    this.pauseAVPlayer()
    this.mIjkMediaPlayer?.pause();
    this.mIjkMediaPlayer?.seekTo(String(position))
    await new Promise<void>(resolve => setTimeout(resolve, 50));
    this.playAVPlayer()
    this.mIjkMediaPlayer?.start();
  }

  calPlayerSync(duration: number) {
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
}