import { media } from '@kit.MediaKit'
import { avSession, avSession as avSessionManager } from '@kit.AVSessionKit'
import { AudioTrack, SubtitleTrack } from '../../interfaces/AudioTrackInterface'
import ToolsUtil from '../../utils/ToolsUtil'
import PiPWindowUtil from '../../utils/PiPWindowUtil'
import { audio } from '@kit.AudioKit'
import { Subtitle3DMode, SubtitleMode } from '../../common/enum/SubtitleMode'
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import { SweetRepeatMode } from '../../common/enum/SweetRepeatMode'
import { PlayerControllerInterface } from '../PlayerControllerFactory'
import { salmonLogger } from 'salmonlogger'
import { window } from '@kit.ArkUI'
import {
  AUTO_HIDE_SHOW_CONTROL_TIME,
  IMAGE_ANALYZER_CONFIG,
  LEFT_ZONE_DIVISION,
  RIGHT_ZONE_DIVISION,
  SCREEN_DIVISIONS
} from '../../common/Constants'
import { VideoStartTimeMode } from '../../common/enum/VideoStartTimeMode'
import NavigationAddress from '../../common/NavigationCommon'
import Preferences from '../../database/Preferences'
import AVSessionUtil from '../../utils/AVSessionUtil'
import { ThrottleUtil } from '../../utils/DebounceUtil'
import { Setting } from '../../utils/ObservedUtil'
import { PathUtils } from '../../utils/PathUtils'
import SelectFileUtil from '../../utils/SelectFileUtil'
import PermissionUtil from '../../utils/PermissionUtil'
import PrivacySpaceUtil from '../../utils/PrivacySpaceUtil'

import SubtitleUtil from '../../utils/SubtitleUtil'
import VideoInfoUtil from '../../utils/VideoInfoUtil'
import VideoOperateUtil from '../../utils/VideoOperateUtil'
import { WindowUtil } from '../../utils/WindowUtil'
import fileIo from '@ohos.file.fs'
import { PlayerState } from './AVPlayerState'

const TAG = 'AVPlayerController'

@ObservedV2
export class AVPlayerController implements PlayerControllerInterface {
  @Trace avPlayer: media.AVPlayer | undefined = undefined
  avSession: avSessionManager.AVSession | undefined = undefined
  surfaceID: string = ''
  @Trace nowPlaying: VideoMetadata | undefined = undefined
  @Trace playing: boolean = false
  @Trace speed: number = 1.0
  @Trace playTime: number = 0
  @Trace audioTrack: AudioTrack[] = []
  @Trace subtitleTrack: SubtitleTrack[] = []
  @Trace subtitleTrackSelected: number = -1
  @Trace volume: number = 0
  @Trace volumeActually: number = 0
  @Trace screenBrightness: number = 0
  @Trace onSwipingVoice: boolean = false
  @Trace subtitleSelected: SubtitleMode = SubtitleMode.NONE
  @Trace subtitle: string = ''
  @Trace videoMetaDataList: VideoMetadata[] = []
  audioVolumeManager: audio.AudioVolumeManager | null = null
  @Trace isListenVideo: boolean = false
  @Trace screenWidth: number = 0
  @Trace screenHeight: number = 0
  @Trace playAreaHeight: number = 0
  @Trace playAreaWidth: number = 0
  @Trace angle: number = 0
  @Trace pixelMap: PixelMap | null = null
  @Trace repeatMode: SweetRepeatMode = SweetRepeatMode.LIST
  @Trace selectedText: string | undefined = '原始比例'
  @Trace onSwiping: boolean = false
  @Trace onSwipingBrightness: boolean = false
  @Trace isSliderPlayTimeChange: boolean = false
  @Trace volumeLoudnessGain: number = 0
  @Trace superResolutionState: boolean = false
  @Trace audioTrackSelected: number = 0
  @Trace lockVisibility: boolean = false
  @Trace longPress: boolean = false
  @Trace isLock: boolean = false
  @Trace abCircleStatus: boolean = false
  @Trace isZoomed: boolean = false
  @Trace isGesturing: boolean = false
  @Trace translateX: number = 0
  @Trace translateY: number = 0
  @Trace showControl: boolean = false
  private playerState: PlayerState = PlayerState.IDLE
  private stateChangeResolvers: Map<string, ((value: void) => void)> = new Map()
  // 视频帧预览节流控制
  private lastFrameFetchTime: number = 0
  private readonly FRAME_FETCH_INTERVAL: number = 200 // 200ms 获取一次预览帧
  private lastFrameFetchPlayTime: number = -1 // 上次获取帧的播放时间，避免同时间重复获取导致闪烁
  private pendingFrameTime: number = -1 // 待处理的最新帧请求时间

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
      const now = Date.now()
      if (!isFirstFrame && now - this.lastFrameFetchTime < this.FRAME_FETCH_INTERVAL) {
        this.pendingFrameTime = time
        return
      }
      if (!isFirstFrame && Math.floor(time) === Math.floor(this.lastFrameFetchPlayTime)) {
        return
      }
      this.lastFrameFetchTime = now
      this.lastFrameFetchPlayTime = time

      if (!VideoOperateUtil.updatePix) {
        this.pendingFrameTime = time
        return
      }
      VideoOperateUtil.updatePix = false
      try {
        const img = await VideoOperateUtil.fetchFrameByTime(time, this.nowPlaying?.size)
        if (img && Math.abs(this.playTime - time) < 3000) {
          this.pixelMap = img
        }
      } catch (error) {
        salmonLogger.addLog(TAG, '获取视频帧失败:' + error, true)
      } finally {
        VideoOperateUtil.updatePix = true
        if (this.pendingFrameTime >= 0 && this.pendingFrameTime !== this.lastFrameFetchPlayTime) {
          const nextTime = this.pendingFrameTime
          this.pendingFrameTime = -1
          this.getFrameByTime(nextTime, false)
        }
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
      salmonLogger.addLog(TAG, 'volumeChange error:' + error, true)
    }
    this.screenBrightness = await VideoOperateUtil.getScreenBrightness()
  }

  async setExternalSubtitle(nowPlaying: VideoMetadata) {
    let externalSubtitleLoaded = false
    if (await SubtitleUtil.isSubtitleExist(PathUtils.subtitlePath!, nowPlaying.date!)) {
      try {
        let subtitle = fileIo.openSync(PathUtils.subtitlePath! + nowPlaying.date, fileIo.OpenMode.READ_ONLY)
        const success = await SubtitleUtil.parseSubtitleProcess(subtitle.path, nowPlaying.external_subtitle_format)
        if (success) {
          externalSubtitleLoaded = true
          this.subtitle = SubtitleUtil.getSubtitlesAtTime(this.playTime)
        }
      } catch (_error) {
      }
    }

    const hasPreference = SubtitleUtil.hasSubtitlePreferenceMetadata(nowPlaying)
    if (hasPreference) {
      const preferredMode = nowPlaying.subtitle_mode as SubtitleMode | undefined
      if (preferredMode === SubtitleMode.EXTERNAL_SUBTITLE && !externalSubtitleLoaded) {
        this.subtitleSelected = SubtitleMode.NONE
        this.resetSubtitlePreference(nowPlaying)
      } else if (preferredMode !== undefined && preferredMode >= SubtitleMode.NONE) {
        if (nowPlaying.subtitle_offset_millis !== undefined) {
          SubtitleUtil.offsetMillis = nowPlaying.subtitle_offset_millis
        }
        this.subtitleSelected = preferredMode
      } else {
        this.subtitleSelected = SubtitleMode.NONE
      }
    } else {
      this.subtitleSelected = externalSubtitleLoaded ? SubtitleMode.EXTERNAL_SUBTITLE : SubtitleMode.NONE
    }

    this.avPlayer?.on('subtitleUpdate', async (info: media.SubtitleInfo) => { // 需要进入prepare状态前完成注册
      if (VideoOperateUtil.clearSubtitleTimer !== null) {
        clearTimeout(VideoOperateUtil.clearSubtitleTimer)
        VideoOperateUtil.clearSubtitleTimer = null
      }
      if (this.subtitleSelected === SubtitleMode.INNER_SUBTITLE) {
        if (info) {
          const text = (info.text ?? '')
            .replace(/\\[Nn]/g, '\n')
            .replace(/\{[^}]*\}/g, '')
            .replace(/<[^>]*>/g, '')
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
    try {
      this.avPlayer?.setPlaybackRate(speed)
    } catch (error) {
      salmonLogger.addLog(TAG, 'updatePlaybackSpeed error:' + error, true)
      ToolsUtil.showToast('播放速度更新失败')
    }
  }

  async getAudioTrackList() {
    this.audioTrack = await VideoOperateUtil.getAudioTracks(this.avPlayer!)
    this.selectAudioTrack(this.audioTrack[0].index)
    this.restoreAudioTrackPreference()
  }

  async getSubtitleTrackList() {
    this.subtitleTrack = await VideoOperateUtil.getInnerSubtitles(this.avPlayer!)
    this.subtitleTrackSelected = this.subtitleTrack.length > 0 ? this.subtitleTrack[0].id : -1
  }

  selectSubtitleTrack(index: number): void {
    this.subtitleTrackSelected = index
    this.avPlayer?.selectTrack(index)?.catch(() => {
      salmonLogger.addLog(TAG, 'selectTrack error', true)
    })
  }

  selectAudioTrack(index: number) {
    this.avPlayer?.selectTrack(index)?.catch(() => {
      salmonLogger.addLog(TAG, 'selectTrack error', true)
    })
  }

  restoreAudioTrackPreference(): void {
    if (!this.nowPlaying || this.audioTrack.length <= 1) {
      return
    }
    const audioTrackId = this.nowPlaying.audio_track_id
    if (audioTrackId !== undefined && audioTrackId > 0 && audioTrackId < this.audioTrack.length) {
      this.selectAudioTrack(this.audioTrack[audioTrackId].index)
      this.audioTrackSelected = audioTrackId
    }
  }

  async release() {
    if (!this.avPlayer) {
      return
    }
    this.transitionTo(PlayerState.RELEASING)
    try {
      await this.avPlayer?.reset()
    } catch (e) {
      salmonLogger.addLog(TAG, 'release reset error', true)
    }
    const releasePromise = this.avPlayer?.release()?.catch(() => {
      salmonLogger.addLog(TAG, 'release error', true)
    })
    const timeoutPromise = new Promise<void>((resolve) => setTimeout(resolve, 3000))
    await Promise.race([releasePromise, timeoutPromise])
    this.avPlayer = undefined
    this.transitionTo(PlayerState.IDLE)
  }

  async reset() {
    this.transitionTo(PlayerState.IDLE)
    try {
      await this.avPlayer?.reset()
    } catch (e) {
      salmonLogger.addLog(TAG, 'reset error', true)
    }
  }

  prepare() {
    this.avPlayer?.prepare()?.catch(() => {
      salmonLogger.addLog(TAG, 'prepare error', true)
    })
  }

  pause() {
    this.avPlayer?.pause()?.catch(() => {
      salmonLogger.addLog(TAG, `pause error`, true)
    })
  }

  play() {
    this.avPlayer?.play()?.catch(() => {
      salmonLogger.addLog(TAG, `play error`, true)
    })
  }

  setListenVideoStatus() {
    this.avPlayer?.setMediaMuted(media.MediaType.MEDIA_TYPE_VID, this.isListenVideo)?.catch(() => {
      salmonLogger.addLog(TAG, '设置听视频失败', true)
      this.isListenVideo = false
    })
    salmonLogger.addLog(TAG, `视频听视频设置为：${this.isListenVideo}`, false)
  }

  cancelSubscribe() {
    this.avPlayer?.off('subtitleUpdate')
    this.avPlayer?.off('timeUpdate')
    this.avPlayer?.off('seekDone')
    this.avPlayer?.off('playbackRateDone')
    this.avPlayer?.off('audioOutputDeviceChangeWithInfo')
    this.avPlayer?.off('subtitleUpdate')
    this.avPlayer?.off('stateChange')
    if (Setting.superResolutionState) {
      this.avPlayer?.off('superResolutionChanged')
    }
    AppStorage.delete('nowPlayingData')
    try {
      this.audioVolumeManager?.off('streamVolumeChange')
      this.audioVolumeManager = null
      salmonLogger.addLog(TAG, "取消音量监听完成", false)
    } catch (error) {
      salmonLogger.addLog(TAG, `取消音量监听错误 ${error}`, true)
    }
  }

  playNextVideo(repeatMode: SweetRepeatMode): VideoMetadata | undefined {
    if (this.playTime <= 0) {
      return undefined
    }
    return VideoOperateUtil.computeNextVideo(this.videoMetaDataList, this.nowPlaying, repeatMode)
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
    salmonLogger.addLog(TAG, "开始启动图像分析器", false)
    xComponentController.startImageAnalyzer(IMAGE_ANALYZER_CONFIG)?.catch(() => {
      salmonLogger.addLog(TAG, `启动图像分析器错误`, true)
    })
  }

  async initAVSession() {
    if (Setting.allowBackgroundPlay) {
      this.avSession = await AVSessionUtil.getAVSession()
      this.setSessionListener()
      await AVSessionUtil.setSessionInfo(this.nowPlaying!)
      AVSessionUtil.updatePlaybackSessionState(this.playing, this.playTime, this.repeatMode)
    } else {
      salmonLogger.addLog(TAG, '未开启后台播放功能', false)
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
      salmonLogger.addLog(TAG, 'set avSession state error', true)
    }
  }

  async playNextVideoProcess(pathStack: NavPathStack, windowClass?: Promise<window.Window | undefined>,
    xComponentController?: XComponentController) {
    salmonLogger.addLog(TAG, "开始播放下一个视频前置流程", false)
    const nextItem = this.playNextVideo(this.repeatMode)
    salmonLogger.addLog(TAG, "获取下一个视频项", false)
    if (nextItem) {
      salmonLogger.addLog(pathStack?.getAllPathName()[0] ?? TAG, "存在下一个视频，开始播放", false)
      await this.playChooseVideo(nextItem, pathStack, windowClass, xComponentController)
    } else {
      salmonLogger.addLog(pathStack?.getAllPathName()[0] ?? TAG, "无下一个视频，播放结束", false)
      ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.play_finished_auto_exit').id))
      pathStack.pop()
    }
    salmonLogger.addLog(pathStack?.getAllPathName()[0] ?? TAG, "播放下一个视频前置流程完成", false)
  }

  async playChooseVideo(item: VideoMetadata, pathStack: NavPathStack,
    windowClass?: Promise<window.Window | undefined>, xComponentController?: XComponentController) {
    salmonLogger.addLog(TAG, "开始播放选择的视频", false)
    VideoOperateUtil.saveVideoTime(this.playTime, this.nowPlaying!, PathUtils.appContext!)

    this.avPlayer?.off('subtitleUpdate')

    this.transitionTo(PlayerState.LOADING)
    try {
      await this.reset()
      if (!this.avPlayer) {
        salmonLogger.addLog(TAG, "reset后avPlayer为空，重新创建播放器", true)
        await this.init()
        if (xComponentController) {
          this.setPlayerCallback(pathStack, xComponentController, windowClass)
        }
      }
      if (!PrivacySpaceUtil.getPrivacyMode()) {
        const folders = Preferences.getFileFolder(PathUtils.appContext!)
        const currentFolder = folders.find(f =>
        f.video_list.some(v => v.date === item.date)
        )
        if (currentFolder) {
          this.videoMetaDataList = currentFolder.video_list
          const latestItem = currentFolder.video_list.find(v => v.date === item.date)
          if (latestItem) {
            this.nowPlaying = latestItem
          } else {
            this.nowPlaying = item as VideoMetadata
          }
          salmonLogger.addLog(TAG, "更新播放列表数据完成", false)
        } else {
          this.nowPlaying = item as VideoMetadata
        }
      } else {
        this.nowPlaying = item as VideoMetadata
      }
      salmonLogger.addLog(TAG, "设置当前播放视频完成", false)

      await this.loadAndPrepare(pathStack!, windowClass!)
      salmonLogger.addLog(TAG, "获取播放数据完成", false)
      await this.initAVSession()
      salmonLogger.addLog(TAG, "播放选择视频流程完成", false)
    } catch (e) {
      salmonLogger.addLog(TAG, "播放选择视频失败: " + e, true)
      this.transitionTo(PlayerState.ERROR)
    }
  }

  async getData(pathStack?: NavPathStack, windowClass?: Promise<window.Window | undefined>) {
    salmonLogger.addLog(TAG, "开始获取播放数据", false)
    this.transitionTo(PlayerState.PREPARING)
    try {
      if (this.avPlayer) {
        try {
          await PermissionUtil.activatePermission(this.nowPlaying?.uri)
          this.avPlayer.fdSrc = fileIo.openSync(this.nowPlaying?.uri)
        } catch (error) {
          salmonLogger.addLog(TAG, "打开视频文件失败：" + error, true)
          ToolsUtil.showToast('视频打开失败，可能已失效：' + error)
          pathStack && pathStack.pop()
          return
        }
        await VideoOperateUtil.getFrameTimePreprocess(this.nowPlaying!.uri)
        this.setRotation()
        salmonLogger.addLog(TAG, "计算播放区域尺寸完成", false)
        if (windowClass) {
          this.playAreaWidth > this.playAreaHeight ?
            WindowUtil.enableLandscapeMultiWindow(windowClass) :
            WindowUtil.disableLandscapeMultiWindow(windowClass)
        }
        if (Setting.smartRotation && this.playAreaWidth > this.playAreaHeight &&
          this.screenHeight > this.screenWidth) {
          salmonLogger.addLog(TAG, "智能旋转条件满足，开始设置方向", false)
          const proportion =
            Math.max(this.screenWidth, this.screenHeight) /
              Math.min(this.screenWidth, this.screenHeight)
          const orientation = proportion > (16 / 10) ? window.Orientation.AUTO_ROTATION_LANDSCAPE
            : window.Orientation.AUTO_ROTATION_RESTRICTED;
          (await windowClass)?.setPreferredOrientation(orientation)?.catch(() => {
            salmonLogger.addLog(TAG, "设置窗口方向失败", true)
          })
          salmonLogger.addLog(TAG, "设置窗口方向完成", false)
        }
      } else {
        salmonLogger.addLog(TAG, "avPlayer为空，无法设置fdSrc", true)
      }
    } catch (error) {
      const errorText = '视频加载失败。原因是：' + error
      ToolsUtil.showToast(errorText)
      salmonLogger.addLog(TAG, errorText, true)
      pathStack && pathStack.pop()
    }
    PiPWindowUtil.updateContentSize()
    salmonLogger.addLog(TAG, "获取播放数据完成", false)
  }

  setRotation() {
    salmonLogger.addLog(TAG, "开始执行setRotation方法", false)
    if (!this.nowPlaying) {
      return
    }
    salmonLogger.addLog(TAG, "开始计算播放区域尺寸", false)
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
    VideoInfoUtil.saveOriginalVideoWidthAndHeight(this.playAreaWidth, this.playAreaHeight)
    salmonLogger.addLog(TAG, "setRotation方法执行完成", false)
  }

  async init() {
    this.avPlayer = await this.create()
  }

  setLoudnessGain(loudnessGain: number) {
    this.volumeLoudnessGain = loudnessGain
    this.avPlayer?.setLoudnessGain(loudnessGain)?.catch(() => {
      salmonLogger.addLog(TAG, "设置响度失败", true)
    })
  }

  async setAVPlayerProperties() {
    this.avPlayer!.surfaceId = this.surfaceID
    this.avPlayer?.setPlaybackStrategy({
      preferredBufferDurationForPlaying: 20,
      showFirstFrameOnPrepare: true,
      enableSuperResolution: true,
      preferredHdr: true
    })?.catch(() => {
      salmonLogger.addLog(TAG, "设置播放策略失败", true)
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
        salmonLogger.addLog(TAG, "设置超分失败", true)
      })
    this.avPlayer?.setVideoWindowSize(1920, 1080)
    ?.catch(() => {
      salmonLogger.addLog(TAG, "设置超分至目标分辨率失败", true)
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
      // 使用节流控制播放进度更新频率，降低UI重渲染开销
      if (!this.onSwiping) {
        ThrottleUtil.throttle('playTime', () => {
          this.playTime = duration
        }, 100)
      }
      AppStorage.setOrCreate('nowPlayingData',
        [this.playTime, this.nowPlaying!])
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
        salmonLogger.addLog(pathStack?.getAllPathName()[0] ?? TAG,
          `检测到视频片尾，准备播放下一个视频，满足条件为: endTime: ${endTime}, repeatMode: ${this.repeatMode}, duration: ${duration}`,
          false)
        await this.playNextVideoProcess(pathStack, windowClass, xComponentController)
        this.setPlayerCallback(pathStack, xComponentController, windowClass)
        ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.skipped_video_ending').id))
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
      salmonLogger.addLog(pathStack?.getAllPathName()[0] ?? TAG, "播放器跳转完成", false)
      this.playTime = percent
      AVSessionUtil.updatePlaybackSessionState(this.playing, this.playTime, this.repeatMode)
      // this.refreshExternalSubtitleByPlaybackTime()
      if (!this.playing) {
        this.startImageAnalyzer(xComponentController!)
      }
    })

    this.avPlayer?.on('playbackRateDone', (rate: number) => {
      this.speed = rate
    })

    this.avPlayer?.on('audioOutputDeviceChangeWithInfo', (data: audio.AudioStreamDeviceChangeInfo) => {
      if (data.changeReason === audio.AudioStreamDeviceChangeReason.REASON_OLD_DEVICE_UNAVAILABLE) {
        this.pause()
      }
    })

    this.avPlayer?.on('stateChange', async (state) => {
      salmonLogger.addLog(pathStack?.getAllPathName()[0] ?? TAG,
        `AVPlayer原生状态变更: ${state}, 应用状态: ${PlayerState[this.playerState]}`, false)
      switch (state) {
        case 'initialized':
          salmonLogger.addLog(pathStack?.getAllPathName()[0] ?? TAG, "进入initialized状态", false)
          if (this.avPlayer) {
            await this.setAVPlayerProperties()
            this.prepare()
          }
          break
        case 'prepared':
          salmonLogger.addLog(pathStack?.getAllPathName()[0] ?? TAG, "进入prepared状态", false)
          this.transitionTo(PlayerState.PREPARING)
          this.videoStartPlayTime(VideoOperateUtil.getVideoStartPlayTimeMode(this.nowPlaying!))
          salmonLogger.addLog(pathStack?.getAllPathName()[0] ?? TAG, "设置视频开始播放时间完成", false)
          this.play()
          salmonLogger.addLog(pathStack?.getAllPathName()[0] ?? TAG, "开始播放视频", false)
          await this.getAudioTrackList()
          await this.getSubtitleTrackList()
          this.restoreInnerSubtitlePreference(this.nowPlaying!)
          salmonLogger.addLog(pathStack?.getAllPathName()[0] ?? TAG, "获取音频轨道完成", false)
          await this.initVolumeAndBrightness()
          this.updatePlaybackSpeed(this.speed)
          salmonLogger.addLog(pathStack?.getAllPathName()[0] ?? TAG, "更新播放速度完成", false)
          this.showControl = false
          this.lockVisibility = false
          this.isSliderPlayTimeChange = false
          this.onSwiping = false
          salmonLogger.addLog(pathStack?.getAllPathName()[0] ?? TAG, "界面控制状态重置完成", false)
          break
        case 'completed':
          salmonLogger.addLog(pathStack?.getAllPathName()[0] ?? TAG, "进入completed状态", false)
          this.transitionTo(PlayerState.COMPLETED)
          VideoOperateUtil.saveVideoTime(this.playTime, this.nowPlaying!,
            PathUtils.appContext!)
          salmonLogger.addLog(pathStack?.getAllPathName()[0] ?? TAG, "保存视频播放时间完成", false)
          if (this.repeatMode === SweetRepeatMode.SINGLE) {
            salmonLogger.addLog(pathStack?.getAllPathName()[0] ?? TAG, "单曲循环模式，重新开始播放", false)
            this.play()
            this.avPlayer?.seek(0, media.SeekMode.SEEK_CLOSEST)
          } else {
            salmonLogger.addLog(pathStack?.getAllPathName()[0] ?? TAG, "播放下一视频", false)
            await this.playNextVideoProcess(pathStack, windowClass, xComponentController)
            this.setPlayerCallback(pathStack, xComponentController, windowClass)
          }
          break
        case 'playing':
          salmonLogger.addLog(pathStack?.getAllPathName()[0] ?? TAG, "进入playing状态", false)
          this.transitionTo(PlayerState.PLAYING)
          this.playing = true
          this.initAVSession()
          salmonLogger.addLog(pathStack?.getAllPathName()[0] ?? TAG, "初始化AVSession完成", false)
          AVSessionUtil.updatePlaybackSessionState(this.playing, this.playTime, this.repeatMode)
          salmonLogger.addLog(pathStack?.getAllPathName()[0] ?? TAG, "更新播放会话状态完成", false)
          xComponentController!.stopImageAnalyzer()
          salmonLogger.addLog(pathStack?.getAllPathName()[0] ?? TAG, "停止图像分析器完成", false)
          break
        case 'paused':
          salmonLogger.addLog(pathStack?.getAllPathName()[0] ?? TAG, "进入paused状态", false)
          this.transitionTo(PlayerState.PAUSED)
          this.playing = false
          AVSessionUtil.updatePlaybackSessionState(this.playing, this.playTime, this.repeatMode)
          salmonLogger.addLog(pathStack?.getAllPathName()[0] ?? TAG, "更新播放会话状态为暂停完成", false)
          setTimeout(() => {
            this.startImageAnalyzer(xComponentController!)
          }, 100)
          break
        case 'released':
          salmonLogger.addLog(pathStack?.getAllPathName()[0] ?? TAG, "进入released状态", false)
          this.transitionTo(PlayerState.RELEASING)
          this.playing = false
          AVSessionUtil.updatePlaybackSessionState(this.playing, this.playTime, this.repeatMode)
          salmonLogger.addLog(pathStack?.getAllPathName()[0] ?? TAG, "更新播放会话状态为释放完成", false)
          break
        case 'idle':
          salmonLogger.addLog(pathStack?.getAllPathName()[0] ?? TAG,
            `进入idle状态, 应用状态: ${PlayerState[this.playerState]}`, false)
          if (this.isInState(PlayerState.LOADING) || this.isInState(PlayerState.IDLE)) {
            salmonLogger.addLog(pathStack?.getAllPathName()[0] ?? TAG, "正在加载或空闲，跳过idle状态释放", false)
          } else {
            await this.release()
            salmonLogger.addLog(pathStack?.getAllPathName()[0] ?? TAG, "释放播放器资源完成", false)
          }
          break
        case 'error':
          salmonLogger.addLog(pathStack?.getAllPathName()[0] ?? TAG, "进入error状态", false)
          this.transitionTo(PlayerState.ERROR)
          try {
            await (await windowClass)?.setPreferredOrientation(window.Orientation.AUTO_ROTATION_RESTRICTED)
            VideoOperateUtil.playErrorExecute(pathStack, this.videoMetaDataList,
              this.nowPlaying?.date!, NavigationAddress.MPV_PLAYER, this.playTime)
            salmonLogger.addLog(pathStack?.getAllPathName()[0] ?? TAG, "执行播放错误处理完成", false)
          } catch (error) {
            pathStack.pop()
          } finally {
            await this.release()
          }
          salmonLogger.addLog(pathStack?.getAllPathName()[0] ?? TAG, "释放播放器资源完成", false)
          break
      }
    })
  }

  refreshExternalSubtitlePreview(offset: number): void {
    if (this.subtitleSelected !== SubtitleMode.EXTERNAL_SUBTITLE) {
      return
    }
    this.subtitle = SubtitleUtil.getSubtitlesAtTime(this.playTime, offset)
  }

  refreshExternalSubtitleByPlaybackTime(isAdjustingSubtitleOffset: boolean, subtitleVisibility: Visibility): void {
    if (isAdjustingSubtitleOffset) {
      return
    }
    if (this.subtitleSelected !== SubtitleMode.EXTERNAL_SUBTITLE) {
      return
    }
    if (subtitleVisibility !== Visibility.Visible) {
      return
    }
    this.subtitle = SubtitleUtil.getSubtitlesAtTime(this.playTime)
  }

  getAdjacentSubtitleOffset(direction: 'prev' | 'next', currentOffset: number): number | undefined {
    return VideoOperateUtil.getAdjacentSubtitleOffset(this.playTime, currentOffset, direction)
  }

  saveSubtitlePreferenceForCurrentVideo(
    subtitleVisibility: Visibility,
    isAIAsrShown: boolean,
    subtitle3DMode: Subtitle3DMode
  ): void {
    VideoOperateUtil.saveSubtitlePreference(
      this.nowPlaying, this.subtitleSelected, this.subtitleTrackSelected,
      subtitleVisibility, isAIAsrShown, subtitle3DMode
    )
  }

  private resetSubtitlePreference(nowPlaying: VideoMetadata): void {
    nowPlaying.subtitle_mode = SubtitleMode.NONE
    nowPlaying.subtitle_visible = false
    nowPlaying.subtitle_ai_asr_shown = false
    nowPlaying.subtitle_3d_mode = Subtitle3DMode.DISABLED
    nowPlaying.subtitle_offset_millis = 0
    nowPlaying.subtitle_track_id = -1
    SelectFileUtil.saveData(PathUtils.appContext!, nowPlaying, {
      subtitleMode: SubtitleMode.NONE,
      subtitleVisible: false,
      subtitleAIAsrShown: false,
      subtitle3DMode: Subtitle3DMode.DISABLED,
      subtitleOffsetMillis: 0,
      subtitleTrackId: -1
    })
  }

  private restoreInnerSubtitlePreference(nowPlaying: VideoMetadata): void {
    if (this.subtitleSelected !== SubtitleMode.INNER_SUBTITLE) {
      return
    }
    if (this.subtitleTrack.length === 0) {
      this.subtitleSelected = SubtitleMode.NONE
      return
    }
    if (nowPlaying.subtitle_track_id !== undefined && nowPlaying.subtitle_track_id >= 0) {
      this.subtitleTrackSelected = nowPlaying.subtitle_track_id
    }
  }

  private transitionTo(newState: PlayerState): void {
    const oldState = this.playerState
    if (oldState === newState) {
      return
    }
    salmonLogger.addLog(TAG, `播放器状态转换: ${PlayerState[oldState]} -> ${PlayerState[newState]}`, false)
    this.playerState = newState
    const key = PlayerState[newState]
    const resolver = this.stateChangeResolvers.get(key)
    if (resolver) {
      resolver()
      this.stateChangeResolvers.delete(key)
    }
  }

  private waitForState(targetState: PlayerState, timeoutMs: number = 10000): Promise<void> {
    if (this.playerState === targetState) {
      return Promise.resolve()
    }
    return new Promise<void>((resolve, reject) => {
      const key = PlayerState[targetState]
      this.stateChangeResolvers.set(key, resolve)
      setTimeout(() => {
        if (this.stateChangeResolvers.has(key)) {
          this.stateChangeResolvers.delete(key)
          reject(new Error(`等待状态${key}超时`))
        }
      }, timeoutMs)
    })
  }

  private isInState(state: PlayerState): boolean {
    return this.playerState === state
  }

  private async loadAndPrepare(pathStack: NavPathStack,
    windowClass?: Promise<window.Window | undefined>): Promise<void> {
    if (!this.avPlayer) {
      throw new Error('avPlayer为空，无法加载视频')
    }
    try {
      await PermissionUtil.activatePermission(this.nowPlaying?.uri)
      this.avPlayer.fdSrc = fileIo.openSync(this.nowPlaying?.uri)
    } catch (error) {
      salmonLogger.addLog(TAG, "打开视频文件失败：" + error, true)
      ToolsUtil.showToast('视频打开失败，可能已失效：' + error)
      pathStack.pop()
      throw new Error('打开视频文件失败：' + error)
    }
    await VideoOperateUtil.getFrameTimePreprocess(this.nowPlaying!.uri)
    this.setRotation()
    salmonLogger.addLog(TAG, "计算播放区域尺寸完成", false)
    if (windowClass) {
      this.playAreaWidth > this.playAreaHeight ?
        WindowUtil.enableLandscapeMultiWindow(windowClass) :
        WindowUtil.disableLandscapeMultiWindow(windowClass)
    }
    if (Setting.smartRotation && this.playAreaWidth > this.playAreaHeight &&
      this.screenHeight > this.screenWidth) {
      salmonLogger.addLog(TAG, "智能旋转条件满足，开始设置方向", false)
      const proportion =
        Math.max(this.screenWidth, this.screenHeight) /
          Math.min(this.screenWidth, this.screenHeight)
      const orientation = proportion > (16 / 10) ? window.Orientation.AUTO_ROTATION_LANDSCAPE
        : window.Orientation.AUTO_ROTATION_RESTRICTED;
      (await windowClass)?.setPreferredOrientation(orientation)?.catch(() => {
        salmonLogger.addLog(TAG, "设置窗口方向失败", true)
      })
      salmonLogger.addLog(TAG, "设置窗口方向完成", false)
    }
    PiPWindowUtil.updateContentSize()
    salmonLogger.addLog(TAG, "fdSrc设置完成，等待PLAYING状态", false)
    this.transitionTo(PlayerState.PREPARING)
    await this.waitForState(PlayerState.PLAYING, 15000)
  }
}
