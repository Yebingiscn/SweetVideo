import { media } from '@kit.MediaKit'
import { avSession, avSession as avSessionManager } from '@kit.AVSessionKit'
import VideoOperateUtil from '../utils/VideoOperateUtil'
import { fileIo as fs } from '@kit.CoreFileKit'
import VideoInfoUtil from '../utils/VideoInfoUtil'
import { AudioTrack, SubtitleTrack } from '../interfaces/AudioTrackInterface'
import { VideoStartTimeMode } from '../common/enum/VideoStartTimeMode'
import ToolsUtil from '../utils/ToolsUtil'
import { audio } from '@kit.AudioKit'
import { SubtitleMode } from '../common/enum/SubtitleMode'
import { PathUtils } from '../utils/PathUtils'
import SubtitleUtil from '../utils/SubtitleUtil'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import SelectFileUtil from '../utils/SelectFileUtil'
import { SweetRepeatMode } from '../common/enum/SweetRepeatMode'
import { Setting } from '../utils/ObservedUtil'
import { PlayerControllerInterface } from './PlayerControllerFactory'
import {
  AUTO_HIDE_SHOW_CONTROL_TIME,
  IMAGE_ANALYZER_CONFIG,
  LEFT_ZONE_DIVISION,
  RIGHT_ZONE_DIVISION,
  SCREEN_DIVISIONS
} from '../common/Constants'
import { salmonLogger } from 'salmonlogger'
import AVSessionUtil from '../utils/AVSessionUtil'
import PrivacySpaceUtil from '../utils/PrivacySpaceUtil'
import RecentPlayUtil from '../utils/RecentPlayUtil'
import PermissionUtil from '../utils/PermissionUtil'
import { WindowUtil } from '../utils/WindowUtil'
import { window } from '@kit.ArkUI'
import NavigationAddress from '../common/NavigationCommon'

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
  @Track subtitleTrack: SubtitleTrack[] = []
  @Track subtitleTrackSelected: number = -1
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
  @Track angle: number = 0
  @Track pixelMap: PixelMap | null = null
  @Track repeatMode: SweetRepeatMode = SweetRepeatMode.LIST
  @Track selectedText: string | undefined = '原始比例'
  @Track onSwiping: boolean = false
  @Track onSwipingBrightness: boolean = false
  @Track isSliderPlayTimeChange: boolean = false
  @Track volumeLoudnessGain: number = 0
  @Track superResolutionState: boolean = false
  @Track audioTrackSelected: number = 0
  @Track lockVisibility: boolean = false
  @Track longPress: boolean = false
  @Track isLock: boolean = false
  @Track abCircleStatus: boolean = false
  @Track isZoomed: boolean = false
  @Track translateX: number = 0
  @Track translateY: number = 0
  @Track showControl: boolean = false

  async create() {
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
        const img = await VideoOperateUtil.fetchFrameByTime(time, this.nowPlaying?.size)
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
      this.audioVolumeManager.on('streamVolumeChange', audio.StreamUsage.STREAM_USAGE_MOVIE,
        (streamVolumeEvent: audio.StreamVolumeEvent) => {
          clearTimeout(swipingVoiceTimer)
          if (!this.onSwipingVoice) { // 这里复用手势音量调节提示
            this.onSwipingVoice = !this.onSwipingVoice
            changeVolumeByVolumeButton = true
          }
          this.volumeActually = streamVolumeEvent.volume
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


  async setExternalSubtitle(nowPlaying: VideoMetadata) {
    if (await SubtitleUtil.isSubtitleExist(PathUtils.subtitlePath!, nowPlaying.date!)) {
      try {
        let subtitle = fs.openSync(PathUtils.subtitlePath! + nowPlaying.date, fs.OpenMode.READ_ONLY)
        await SubtitleUtil.parseSubtitleProcess(subtitle.path, nowPlaying.external_subtitle_format) ?
          this.subtitleSelected = SubtitleMode.EXTERNAL_SUBTITLE : this.subtitleSelected = SubtitleMode.INNER_SUBTITLE
      } catch (error) {
        this.subtitleSelected = SubtitleMode.INNER_SUBTITLE
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
    if (!VideoInfoUtil.videoSpeedListAll.includes(speed)) {
      speed = 1.0
    }
    const systemSpeed = VideoInfoUtil.mapToSystemSpeed(speed)
    this.avPlayer?.setSpeed(systemSpeed)
  }

  async getAudioTrackList() {
    this.audioTrack = await VideoOperateUtil.getAudioTracks(this.avPlayer!)
    this.selectAudioTrack(this.audioTrack[0].index)
  }

  async getSubtitleTrackList() {
    this.subtitleTrack = await VideoOperateUtil.getInnerSubtitles(this.avPlayer!)
    this.subtitleTrackSelected = this.subtitleTrack.length > 0 ? this.subtitleTrack[0].id : -1
  }

  selectSubtitleTrack(index: number): void {
    this.subtitleTrackSelected = index
    this.avPlayer?.selectTrack(index)?.catch(() => {
      ToolsUtil.addLogger('selectTrack error', true)
    })
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
      ToolsUtil.addLogger('设置听视频失败', true)
    })
    ToolsUtil.addLogger(`视频听视频设置为：${this.isListenVideo}`, false)
  }

  cancelSubscribe() {
    this.avPlayer?.off('subtitleUpdate')
    this.avPlayer?.off('timeUpdate')
    this.avPlayer?.off('seekDone')
    this.avPlayer?.off('speedDone')
    this.avPlayer?.off('audioOutputDeviceChangeWithInfo')
    this.avPlayer?.off('subtitleUpdate')
    this.avPlayer?.off('stateChange')
    if (Setting.superResolutionState) {
      this.avPlayer?.off('superResolutionChanged')
    }
  }

  playNextVideo(repeatMode: SweetRepeatMode): VideoMetadata | undefined {
    if (this.videoMetaDataList.length === 0 || this.playTime <= 0) {
      return undefined
    }
    let item = SelectFileUtil.getItem(this.videoMetaDataList, this.nowPlaying?.date || '') as VideoMetadata
    if (!item) {
      item = this.videoMetaDataList[0]
    }
    switch (repeatMode) {
      case SweetRepeatMode.RANDOM:
        const availableVideos = this.videoMetaDataList.filter(v => v.date !== item.date)
        return availableVideos.length > 0
          ? availableVideos[Math.floor(Math.random() * availableVideos.length)]
          : item
      case SweetRepeatMode.ONCE:
        return undefined
      case SweetRepeatMode.SEQUENCE:
        if (SelectFileUtil.isLastItem(this.videoMetaDataList, item.date)) {
          return undefined
        }
        return SelectFileUtil.getNextItem(this.videoMetaDataList, item.date)
      case SweetRepeatMode.SINGLE:
        return this.videoMetaDataList.find(v => v.date === this.nowPlaying?.date)!
      case SweetRepeatMode.LIST:
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

  async initAVSession() {
    if (Setting.allowBackgroundPlay) {
      this.avSession = await AVSessionUtil.getAVSession()
      this.setSessionListener()
      await AVSessionUtil.setSessionInfo(this.nowPlaying!)
      AVSessionUtil.updatePlaybackSessionState(this.playing, this.playTime, this.repeatMode)
    } else {
      ToolsUtil.addLogger('未开启后台播放功能', false)
    }
  }

  setSessionListener() {
    try {
      this.avSession?.on('play', () => {
        this.play()
      })
      this.avSession?.on('pause', () => {
        this.pause()
      })
      this.avSession?.on('seek', (position: number) => {
        this.seekTime(position)
      })
      this.avSession?.on('fastForward', () => {
        this.fastForward()
      })
      this.avSession?.on('rewind', () => {
        this.backForward()
      })
      this.avSession?.on('outputDeviceChange', () => {
        this.pause()
      })
      this.avSession?.on('setLoopMode', (mode: avSession.LoopMode) => {
        this.repeatMode = AVSessionUtil.getRepeatModeFromAvSession(mode)
        this.repeatMode = VideoOperateUtil.getRepeatMode(this.repeatMode)
        AVSessionUtil.updatePlaybackSessionState(this.playing, this.playTime, this.repeatMode)
      })
    } catch (error) {
      ToolsUtil.addLogger('set avSession state error', true)
    }
  }

  async playNextVideoProcess(pathStack: NavPathStack, windowClass?: Promise<window.Window | undefined>) {
    ToolsUtil.addLogger("开始播放下一个视频流程", false, pathStack)
    const nextItem = this.playNextVideo(this.repeatMode)
    ToolsUtil.addLogger("获取下一个视频项完成", false, pathStack)
    if (nextItem) {
      ToolsUtil.addLogger("存在下一个视频，开始播放", false, pathStack)
      this.playChooseVideo(nextItem, pathStack, windowClass)
    } else {
      ToolsUtil.addLogger("无下一个视频，播放结束", false, pathStack)
      ToolsUtil.showToast('播放完毕，已自动退出')
      pathStack.pop()
    }
    ToolsUtil.addLogger("播放下一个视频前置流程完成", false, pathStack)
  }

  async playChooseVideo(item: VideoMetadata, pathStack: NavPathStack,
    windowClass?: Promise<window.Window | undefined>) {
    ToolsUtil.addLogger("开始播放选择的视频", false)
    // ORM 改造：保存播放进度和添加最近记录均已异步化，必须在切歌前 await 确保数据落库，
    // 防止用户快速切歌或应用退后台时丢失上一条播放记录。
    await VideoOperateUtil.saveVideoTime(this.playTime, this.nowPlaying!, this.videoMetaDataList, PathUtils.appContext!)
    if (!PrivacySpaceUtil.getPrivacyMode()) {
      await RecentPlayUtil.addPlayback(PathUtils.appContext!, item)
      ToolsUtil.addLogger("添加到最近播放记录完成", false)
    }
    this.avPlayer?.off('subtitleUpdate')
    this.reset()
    this.nowPlaying = item as VideoMetadata
    ToolsUtil.addLogger("设置当前播放视频完成", false)
    this.getData(pathStack!, windowClass!)
    ToolsUtil.addLogger("获取播放数据完成", false)
    await this.initAVSession()
    ToolsUtil.addLogger("播放选择视频流程完成", false)
  }

  async getData(pathStack?: NavPathStack, windowClass?: Promise<window.Window | undefined>) {
    ToolsUtil.addLogger("开始获取播放数据", false)
    try {
      if (this.avPlayer) {
        try {
          await PermissionUtil.activatePermission(this.nowPlaying?.uri)
          this.avPlayer.fdSrc = fs.openSync(this.nowPlaying?.uri)
        } catch (error) {
          ToolsUtil.addLogger("打开视频文件失败：" + error, true)
          ToolsUtil.showToast('视频打开失败，可能已失效：' + error)
          pathStack && pathStack.pop()
        }
        await VideoOperateUtil.getFrameTimePreprocess(this.nowPlaying!.uri)
        this.setRotation()
        ToolsUtil.addLogger("计算播放区域尺寸完成", false)
        if (windowClass) {
          this.playAreaWidth > this.playAreaHeight ?
            WindowUtil.enableLandscapeMultiWindow(windowClass) :
            WindowUtil.disableLandscapeMultiWindow(windowClass)
        }
        if (Setting.smartRotation && this.playAreaWidth > this.playAreaHeight &&
          this.screenHeight > this.screenWidth) {
          ToolsUtil.addLogger("智能旋转条件满足，开始设置方向", false)
          const proportion =
            Math.max(this.screenWidth, this.screenHeight) /
              Math.min(this.screenWidth, this.screenHeight)
          const orientation = proportion > (16 / 10) ? window.Orientation.AUTO_ROTATION_LANDSCAPE
            : window.Orientation.AUTO_ROTATION_RESTRICTED;
          (await windowClass)?.setPreferredOrientation(orientation)?.catch(() => {
            ToolsUtil.addLogger("设置窗口方向失败", true)
          })
          ToolsUtil.addLogger("设置窗口方向完成", false)
        }
      }
    } catch (error) {
      const errorText = '视频加载失败。原因是：' + error
      ToolsUtil.showToast(errorText)
      ToolsUtil.addLogger(errorText, true)
      pathStack && pathStack.pop()
    }
    ToolsUtil.addLogger("获取播放数据完成", false)
  }

  setRotation() {
    ToolsUtil.addLogger("开始执行setRotation方法", false)
    if (!this.nowPlaying) {
      return
    }
    ToolsUtil.addLogger("开始计算播放区域尺寸", false)
    const nowWidth = this.nowPlaying.size[0]
    const nowHeight = this.nowPlaying.size[1]
    const aspectRatioNow = nowWidth / nowHeight
    const screenAspectRatio = this.screenWidth / this.screenHeight
    if (aspectRatioNow > screenAspectRatio) {
      this.playAreaWidth = this.screenWidth
      this.playAreaHeight = this.playAreaWidth * (nowHeight / nowWidth)
    } else {
      this.playAreaHeight = this.screenHeight
      this.playAreaWidth = this.playAreaHeight * (nowWidth / nowHeight)
    }
    if (this.selectedText !== '原始比例') {
      this.selectedText = '原始比例'
    }
    VideoInfoUtil.saveOriginalVideoWidthAndHeight(this.playAreaWidth, this.playAreaHeight)
    ToolsUtil.addLogger("setRotation方法执行完成", false)
  }

  async init() {
    this.avPlayer = await this.create()
  }

  setLoudnessGain(loudnessGain: number) {
    this.volumeLoudnessGain = loudnessGain
    this.avPlayer!.setLoudnessGain(loudnessGain)?.catch(() => {
      ToolsUtil.addLogger("设置响度失败", true)
    })
  }

  async setAVPlayerProperties() {
    this.avPlayer!.surfaceId = this.surfaceID
    this.avPlayer?.setPlaybackStrategy({
      showFirstFrameOnPrepare: true,
      enableSuperResolution: true,
      preferredHdr: true
    })?.catch(() => {
      ToolsUtil.addLogger("设置播放策略失败", true)
    })
    if (Setting.superResolutionState) {
      this.setSuperResolutionState(true)
    }
    await this.setExternalSubtitle(this.nowPlaying!)
  }

  setSuperResolutionState(enable: boolean) {
    this.avPlayer?.setSuperResolution(enable)
      .then(() => {
        this.superResolutionState = enable
      })
      ?.catch(() => {
        ToolsUtil.showToast('当前视频不支持超分辨率')
        this.superResolutionState = false
        ToolsUtil.addLogger("设置超分失败", true)
      })
    this.avPlayer?.setVideoWindowSize(1920, 1080)
    ?.catch(() => {
      ToolsUtil.addLogger("设置超分至目标分辨率失败", true)
    })
    this.avPlayer?.on('superResolutionChanged', (enabled: boolean) => {
      ToolsUtil.showToast(enabled ? '视频超分辨率已开启' : '视频超分辨率已关闭')
      this.superResolutionState = enabled
    })
  }

  onScreenDoubleClick(tapX: number) {
    if (!Setting.allowDoubleFastForward) { // 非双击快进模式时执行暂停
      this.togglePlayback()
      return
    }
    const zoneWidth = this.screenWidth / SCREEN_DIVISIONS
    if (tapX < zoneWidth * LEFT_ZONE_DIVISION) {
      this.backForward()
      return
    }
    if (tapX > zoneWidth * RIGHT_ZONE_DIVISION) {
      this.fastForward()
      return
    }
    this.togglePlayback()
  }

  setPlayerCallback(pathStack: NavPathStack, xComponentController?: XComponentController,
    windowClass?: Promise<window.Window | undefined>) {
    this.avPlayer?.on('timeUpdate', async (duration) => {
      if (!this.onSwiping) {
        this.playTime = duration
      }
      AppStorage.setOrCreate('nowPlayingData',
        [this.playTime, this.nowPlaying!, this.videoMetaDataList])
      if (this.showControl) {
        if (!VideoOperateUtil.autoHideTimeout) {
          VideoOperateUtil.autoHideTimeout = true
          setTimeout(() => {
            this.lockVisibility = false
            this.showControl = false
            VideoOperateUtil.autoHideTimeout = false
          }, AUTO_HIDE_SHOW_CONTROL_TIME)
        }
      }
      const endTime = this.nowPlaying?.end_time
      if (endTime != null && duration >= endTime && endTime > 0 && this.repeatMode !== SweetRepeatMode.SINGLE) {
        ToolsUtil.addLogger(`检测到视频片尾，准备播放下一个视频，满足条件为: endTime: ${endTime}, repeatMode: ${this.repeatMode}, duration: ${duration}`,
          false, pathStack)
        this.playNextVideoProcess(pathStack, windowClass)
        this.setPlayerCallback(pathStack, xComponentController, windowClass)
        ToolsUtil.showToast('已智能跳过片尾')
      }
      if (this.subtitleSelected === SubtitleMode.EXTERNAL_SUBTITLE) {
        this.subtitle = SubtitleUtil.getSubtitlesAtTime(duration)
      }
      if (this.abCircleStatus && this.playing) {
        if (this.nowPlaying?.pointA !== undefined && this.nowPlaying?.pointB !== undefined) {
          const pointA = this.nowPlaying.pointA
          const pointB = this.nowPlaying.pointB
          const playTime = this.playTime
          if (playTime < pointA || playTime > pointB) {
            this.seekTime(pointA)
          }
        }
      }
    })

    this.avPlayer?.on('seekDone', (percent) => {
      ToolsUtil.addLogger("播放器跳转完成", false, pathStack)
      this.playTime = percent
      AVSessionUtil.updatePlaybackSessionState(this.playing, this.playTime, this.repeatMode)
      // this.refreshExternalSubtitleByPlaybackTime()
      if (!this.playing) {
        this.startImageAnalyzer(xComponentController!)
      }
    })

    this.avPlayer?.on('speedDone', (systemEnum: media.PlaybackSpeed) => {
      const actualSpeed = VideoInfoUtil.mapFromSystemSpeed(systemEnum)
      this.speed = actualSpeed
    })

    this.avPlayer?.on('audioOutputDeviceChangeWithInfo', (data: audio.AudioStreamDeviceChangeInfo) => {
      if (data.changeReason === audio.AudioStreamDeviceChangeReason.REASON_OLD_DEVICE_UNAVAILABLE) {
        this.pause()
      }
    })

    this.avPlayer?.on('stateChange', async (state) => {
      ToolsUtil.addLogger(`播放器状态变更: ${state}`, false, pathStack)
      switch (state) {
        case 'initialized':
          ToolsUtil.addLogger("进入initialized状态", false, pathStack)
          if (this.avPlayer) {
            await this.setAVPlayerProperties()
            this.prepare()
          }
          break
        case 'prepared':
          ToolsUtil.addLogger("进入prepared状态", false, pathStack)
          this.videoStartPlayTime(VideoOperateUtil.getVideoStartPlayTimeMode(this.nowPlaying!))
          ToolsUtil.addLogger("设置视频开始播放时间完成", false, pathStack)
          this.play()
          ToolsUtil.addLogger("开始播放视频", false, pathStack)
          await this.getAudioTrackList()
          await this.getSubtitleTrackList()
          //     this.applySubtitlePreferenceFromMetadata()
          ToolsUtil.addLogger("获取音频轨道完成", false, pathStack)
          await this.initVolumeAndBrightness()
          this.updatePlaybackSpeed(this.speed)
          ToolsUtil.addLogger("更新播放速度完成", false, pathStack)
          this.showControl = false
          this.lockVisibility = false
          this.isSliderPlayTimeChange = false
          this.onSwiping = false
          //  this.isAdjustingSubtitleOffset = false
          // this.refreshExternalSubtitleByPlaybackTime()
          ToolsUtil.addLogger("界面控制状态重置完成", false, pathStack)
          break
        case 'completed':
          ToolsUtil.addLogger("进入completed状态", false, pathStack)
          VideoOperateUtil.saveVideoTime(this.playTime, this.nowPlaying!, this.videoMetaDataList,
            PathUtils.appContext!)
          ToolsUtil.addLogger("保存视频播放时间完成", false, pathStack)
          const targetItem = this.videoMetaDataList.find(i => i.date == this.nowPlaying?.date)
          if (targetItem) {
            targetItem!.last_play = this.playTime
            ToolsUtil.addLogger("更新当前视频最后播放时间完成", false, pathStack)
          }
          if (this.repeatMode === SweetRepeatMode.SINGLE) {
            ToolsUtil.addLogger("单曲循环模式，重新开始播放", false, pathStack)
            this.play()
            this.avPlayer?.seek(0, media.SeekMode.SEEK_CLOSEST)
          } else {
            ToolsUtil.addLogger("播放下一视频", false, pathStack)
            this.playNextVideoProcess(pathStack, windowClass)
            this.setPlayerCallback(pathStack, xComponentController, windowClass)
          }
          break
        case 'playing':
          ToolsUtil.addLogger("进入playing状态", false, pathStack)
          this.playing = true
          this.initAVSession()
          ToolsUtil.addLogger("初始化AVSession完成", false, pathStack)
          AVSessionUtil.updatePlaybackSessionState(this.playing, this.playTime, this.repeatMode)
          ToolsUtil.addLogger("更新播放会话状态完成", false, pathStack)
          xComponentController!.stopImageAnalyzer()
          ToolsUtil.addLogger("停止图像分析器完成", false, pathStack)
          break
        case 'paused':
          ToolsUtil.addLogger("进入paused状态", false, pathStack)
          this.playing = false
          AVSessionUtil.updatePlaybackSessionState(this.playing, this.playTime, this.repeatMode)
          ToolsUtil.addLogger("更新播放会话状态为暂停完成", false, pathStack)
          setTimeout(() => {
            this.startImageAnalyzer(xComponentController!)
          }, 100)
          break
        case 'released':
          ToolsUtil.addLogger("进入released状态", false, pathStack)
          this.playing = false
          AVSessionUtil.updatePlaybackSessionState(this.playing, this.playTime, this.repeatMode)
          ToolsUtil.addLogger("更新播放会话状态为释放完成", false, pathStack)
          break
        case 'idle':
          ToolsUtil.addLogger("进入idle状态", false, pathStack)
          this.release()
          ToolsUtil.addLogger("释放播放器资源完成", false, pathStack)
          break
        case 'error':
          ToolsUtil.addLogger("进入error状态", false, pathStack)
          try {
            await (await windowClass)?.setPreferredOrientation(window.Orientation.AUTO_ROTATION_RESTRICTED)
            VideoOperateUtil.playErrorExecute(pathStack, this.videoMetaDataList,
              this.nowPlaying?.date!, NavigationAddress.MPV_PLAYER, this.playTime)
            ToolsUtil.addLogger("执行播放错误处理完成", false, pathStack)
          } catch (error) {
            pathStack.pop()
          } finally {
            this.release()
          }
          ToolsUtil.addLogger("释放播放器资源完成", false, pathStack)
          break
      }
    })
  }
}
