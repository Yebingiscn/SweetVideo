import { media } from '@kit.MediaKit'
import { avSession as avSessionManager } from '@kit.AVSessionKit'
import VideoOperateUtil from '../utils/VideoOperateUtil'
import { fileIo as fs } from '@kit.CoreFileKit'
import NavigationAddress from '../common/NavigationCommon'
import VideoInfoUtil from '../utils/VideoInfoUtil'
import { AudioTrack } from '../interfaces/AudioTrackInterface'
import { VideoStartTimeMode } from '../common/enum/VideoStartTimeMode'
import ToolsUtil from '../utils/ToolsUtil'
import { audio } from '@kit.AudioKit'
import { SubtitleMode } from '../common/enum/SubtitleMode'
import { PathUtils } from '../utils/PathUtils'
import SubtitleUtil from '../utils/SubtitleUtil'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import SelectFileUtil from '../utils/SelectFileUtil'
import { RepeatMode } from '../common/enum/RepeatMode'
import { Setting } from '../utils/ObservedUtil'
import { PlayerControllerInterface } from './PlayerControllerFactory'
import { IMAGE_ANALYZER_CONFIG } from '../common/Constants'
import { salmonLogger } from 'salmonlogger'

@Observed
export class AVPlayerController implements PlayerControllerInterface {
  @Track avPlayer: media.AVPlayer | undefined = undefined
  avSession: avSessionManager.AVSession | undefined = undefined
  surfaceID: string = ''
  @Track nowPlaying: VideoMetadata | undefined = undefined
  @Track playing: boolean = false
  @Track speed: number = 1.0
  @Track playTime: number = 0
  @Track audioTrack: AudioTrack[] = []
  @Track volume: number = 0
  @Track volumeActually: number = 0
  @Track screenBrightness: number = 0
  @Track onSwipingVoice: boolean = false
  @Track subtitleSelected: SubtitleMode = SubtitleMode.INNER_SUBTITLE
  @Track subtitle: string = ''
  @Track videoMetaDataList: VideoMetadata[] = []
  audioVolumeManager: audio.AudioVolumeManager | null = null
  @Track isListenVideo: boolean = false
  @Track screenWidth: number = 0
  @Track screenHeight: number = 0
  @Track playAreaHeight: number = 0
  @Track playAreaWidth: number = 0
  @Track pixelMap: PixelMap | null = null

  async getAVPlayer() {
    try {
      if (!this.avPlayer) {
        this.avPlayer = await media.createAVPlayer()
      }
    } catch (error) {
      ToolsUtil.showToast('播放异常')
      salmonLogger.addLog('avplayer',
        'create avplayer error: ' + error.code + ':' + error.message, true)
    }
    return this.avPlayer
  }

  async getFrameByTime(time: number, isFirstFrame: boolean) {
    if (Setting.showFrameImgStatus) {
      const isUpdating = !VideoOperateUtil.updatePix
      const shouldSkip = isUpdating && !isFirstFrame
      if (shouldSkip) {
        return // 非第一帧且正在更新时跳过，避免堆积
      }
      VideoOperateUtil.updatePix = false // 加锁
      try {
        const img = await VideoOperateUtil.fetchFrameByTime(time)
        if (img) {
          this.pixelMap = img
        }
      } catch (error) {
        ToolsUtil.addLogger('获取视频帧失败:' + error, true)
        this.pixelMap = null
      } finally {
        VideoOperateUtil.updatePix = true // 确保解锁
      }
    }
  }

  async initVolumeAndBrightness() {
    let groupId: number = audio.DEFAULT_VOLUME_GROUP_ID
    let audioManager = audio.getAudioManager()
    this.audioVolumeManager = audioManager.getVolumeManager()
    let volumeList = await VideoOperateUtil.getVolume(this.audioVolumeManager, groupId)
    this.volume = volumeList.get('volume')!
    this.volumeActually = this.volume
    let swipingVoiceTimer: number | null = null
    let changeVolumeByVolumeButton: boolean = false
    try {
      this.audioVolumeManager.on('volumeChange', (volumeEvent: audio.VolumeEvent) => {
        clearTimeout(swipingVoiceTimer)
        if (!this.onSwipingVoice) { // 这里复用手势音量调节提示
          this.onSwipingVoice = !this.onSwipingVoice
          changeVolumeByVolumeButton = true
        }
        this.volumeActually = volumeEvent.volume
        ToolsUtil.startVibration()
        swipingVoiceTimer = setTimeout(() => {
          if (changeVolumeByVolumeButton) {
            this.onSwipingVoice = !this.onSwipingVoice
            changeVolumeByVolumeButton = false
          }
        }, 800)
      })
    } catch (error) {
      console.error('volumeChange error:' + error)
    }
    this.screenBrightness = await VideoOperateUtil.getScreenBrightness()
  }


  async setExternalSubtitle(now_playing: VideoMetadata) {
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
        clearTimeout(VideoOperateUtil.clearSubtitleTimer)
        VideoOperateUtil.clearSubtitleTimer = null
      }
      if (this.subtitleSelected === SubtitleMode.INNER_SUBTITLE) {
        if (info) {
          const text = info.text ?? ''
          const duration = info.duration ?? 0
          this.subtitle = text
          if (duration > 0) {
            VideoOperateUtil.clearSubtitleTimer = setTimeout(() => {
              this.subtitle = ''
            }, duration) as number
          }
        } else {
          this.subtitle = ''
        }
      }
    })
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

  updatePlaybackSpeed(speed: number): void {
    if (!VideoInfoUtil.getVideoSpeedList(NavigationAddress.AV_PLAYER).includes(speed)) {
      speed = 1.0
    }
    const systemSpeed = VideoInfoUtil.mapToSystemSpeed(speed)
    this.avPlayer?.setSpeed(systemSpeed)
  }

  async getAudioTrackList() {
    this.audioTrack = await VideoOperateUtil.getAudioTracks(this.avPlayer!)
    this.selectAudioTrack(this.audioTrack[0].index)
  }

  selectAudioTrack(index: number) {
    this.avPlayer?.selectTrack(index)?.catch(() => {
      ToolsUtil.addLogger('selectTrack error', true)
    })
  }

  release() {
    this.avPlayer?.release()?.catch(() => {
      ToolsUtil.addLogger('release error', true)
    })
    this.avPlayer = undefined
  }

  reset() {
    this.avPlayer?.reset()?.catch(() => {
      ToolsUtil.addLogger('reset error', true)
    })
  }

  prepare() {
    this.avPlayer?.prepare()?.catch(() => {
      ToolsUtil.addLogger('prepare error', true)
    })
  }

  pause() {
    this.avPlayer?.pause()?.catch(() => {
      ToolsUtil.addLogger(`pause error`, true)
    })
  }

  play() {
    this.avPlayer?.play()?.catch(() => {
      ToolsUtil.addLogger(`play error`, true)
    })
  }

  setListenVideoStatus() {
    this.avPlayer?.setMediaMuted(media.MediaType.MEDIA_TYPE_VID, this.isListenVideo)?.catch(() => {
      ToolsUtil.addLogger('设置视频静音失败', true)
    })
    ToolsUtil.addLogger(`视频静音状态设置为：${this.isListenVideo}`, false)
  }

  cancelSubscribe() {
    this.avPlayer?.off('subtitleUpdate')
    this.avPlayer?.off('timeUpdate')
    this.avPlayer?.off('seekDone')
    this.avPlayer?.off('speedDone')
    this.avPlayer?.off('audioOutputDeviceChangeWithInfo')
    this.avPlayer?.off('subtitleUpdate')
    this.avPlayer?.off('stateChange')
  }

  playNextVideo(repeatMode: RepeatMode): VideoMetadata | undefined {
    if (this.videoMetaDataList.length === 0 || this.playTime <= 0) {
      return undefined
    }
    let item = SelectFileUtil.getItem(this.videoMetaDataList, this.nowPlaying?.date || '') as VideoMetadata
    if (!item) {
      item = this.videoMetaDataList[0]
    }
    switch (repeatMode) {
      case RepeatMode.RANDOM:
        const availableVideos = this.videoMetaDataList.filter(v => v.date !== item.date)
        return availableVideos.length > 0
          ? availableVideos[Math.floor(Math.random() * availableVideos.length)]
          : item
      case RepeatMode.ONCE:
        return undefined
      case RepeatMode.SEQUENCE:
        if (SelectFileUtil.isLastItem(this.videoMetaDataList, item.date)) {
          return undefined
        }
        return SelectFileUtil.getNextItem(this.videoMetaDataList, item.date)
      case RepeatMode.SINGLE:
        return this.videoMetaDataList.find(v => v.date === this.nowPlaying?.date)!
      case RepeatMode.LIST:
        return SelectFileUtil.getNextItem(this.videoMetaDataList, item.date)
      default:
        return undefined
    }
  }

  togglePlayback() {
    this.playing ? this.pause() : this.play()
  }

  backForward() {
    this.seekTime(this.playTime - Number(Setting.fastForwardSeconds) * 1000)
  }

  fastForward() {
    this.seekTime(this.playTime + Number(Setting.fastForwardSeconds) * 1000)
  }

  seekTime(seekTime: number) {
    this.avPlayer?.seek(seekTime, media.SeekMode.SEEK_CLOSEST)
  }

  startImageAnalyzer(xComponentController: XComponentController) {
    ToolsUtil.addLogger("开始启动图像分析器", false)
    xComponentController.startImageAnalyzer(IMAGE_ANALYZER_CONFIG)?.catch(() => {
      ToolsUtil.addLogger(`启动图像分析器错误`, true)
    })
  }
}