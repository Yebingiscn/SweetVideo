import { media } from '@kit.MediaKit'
import { avSession, avSession as avSessionManager } from '@kit.AVSessionKit'
import { AudioTrack, SubtitleTrack } from '../../interfaces/AudioTrackInterface'
import ToolsUtil from '../../utils/ToolsUtil'
import { audio } from '@kit.AudioKit'
import { Subtitle3DMode, SubtitleMode } from '../../common/enum/SubtitleMode'
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import { SweetRepeatMode } from '../../common/enum/SweetRepeatMode'
import { PlayerControllerInterface, PlayerEngineSwitchHandler } from '../PlayerControllerFactory'
import { MpvChapter } from '../MpvController/MpvTypes'
import { salmonLogger } from 'salmonlogger'
import { window } from '@kit.ArkUI'

import { PlayerState } from './AVPlayerState'
import {
  AUTO_HIDE_SHOW_CONTROL_TIME,
  IMAGE_ANALYZER_CONFIG,
  LEFT_ZONE_DIVISION,
  RIGHT_ZONE_DIVISION,
  SCREEN_DIVISIONS
} from '../../common/Constants'
import { VideoStartTimeMode } from '../../common/enum/VideoStartTimeMode'
import { PlayerEngine } from '../../common/NavigationCommon'
import Preferences from '../../database/Preferences'
import AVSessionUtil from '../../utils/AVSessionUtil'
import { ThrottleUtil } from '../../utils/DebounceUtil'
import { Setting } from '../../utils/ObservedUtil'
import { PathUtils } from '../../utils/PathUtils'
import PermissionUtil from '../../utils/PermissionUtil'
import PiPWindowUtil from '../../utils/PiPWindowUtil'
import PrivacySpaceUtil from '../../utils/PrivacySpaceUtil'
import SelectFileUtil from '../../utils/SelectFileUtil'
import SubtitleUtil from '../../utils/SubtitleUtil'
import VideoInfoUtil from '../../utils/VideoInfoUtil'
import VideoOperateUtil from '../../utils/VideoOperateUtil'
import { WindowUtil } from '../../utils/WindowUtil'
import { fileIo } from '@kit.CoreFileKit'
import { AVPlayerEngineAdapter } from '../engine/AVPlayerEngineAdapter'

const TAG = 'AVPlayerController'

@ObservedV2
export class AVPlayerController implements PlayerControllerInterface {
  avSession: avSessionManager.AVSession | undefined = undefined
  surfaceID: string = ''
  @Trace nowPlaying: VideoMetadata | undefined = undefined
  initialPlayTime: number | undefined = undefined
  initialPlaying: boolean | undefined = undefined
  @Trace playing: boolean = false
  @Trace networkPlaybackActive: boolean = false
  @Trace networkSpeedText: string = '0 KB/s'
  @Trace networkBufferPercent: number = 0
  @Trace networkCacheDuration: number = 0
  @Trace networkBuffering: boolean = false
  @Trace speed: number = 1.0
  @Trace playTime: number = 0
  @Trace audioTrack: AudioTrack[] = []
  @Trace subtitleTrack: SubtitleTrack[] = []
  @Trace subtitleTrackSelected: number = -1
  @Trace secondarySubtitleTrackSelected: number = -1
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
  @Trace subtitlePosition: number = Setting.subtitlePosition
  @Trace subtitleSize: number = Number(Setting.subtitleSize)
  @Trace audioChannelMode: number = 0
  @Trace superResolutionState: boolean = false
  @Trace audioTrackSelected: number = 0
  @Trace lockVisibility: boolean = false
  @Trace longPress: boolean = false
  @Trace speedLocked: boolean = false
  @Trace isLock: boolean = false
  @Trace abCircleStatus: boolean = false
  @Trace chapterList: MpvChapter[] = []
  @Trace isZoomed: boolean = false
  @Trace isGesturing: boolean = false
  @Trace scaleFactor: number = 1
  @Trace translateX: number = 0
  @Trace translateY: number = 0
  @Trace showControl: boolean = false
  skipHistory: boolean = false
  private engineAdapter: AVPlayerEngineAdapter = new AVPlayerEngineAdapter()
  private isSkippingEnding: boolean = false
  private lastSubtitle: string = ''
  private lastAppStorageUpdateTime: number = 0
  private playerState: PlayerState = PlayerState.IDLE
  private stateChangeResolvers: Map<string, ((value: void) => void)> = new Map()
  private callbackPlayer: media.AVPlayer | undefined = undefined
  private videoSwitchVersion: number = 0
  private isSwitchingVideo: boolean = false
  private playbackDetailsInitialized: boolean = false
  // 视频帧预览节流控制
  private lastFrameFetchTime: number = 0
  private readonly FRAME_FETCH_INTERVAL: number = 200 // 200ms 获取一次预览帧
  private lastFrameFetchPlayTime: number = -1 // 上次获取帧的播放时间，避免同时间重复获取导致闪烁
  private pendingFrameTime: number = -1 // 待处理的最新帧请求时间
  private frameFetchTimer: number = 0
  private stateChangeRejectors: Map<string, ((reason: Error) => void)> = new Map()
  private engineSwitchHandler: PlayerEngineSwitchHandler | undefined = undefined

  get surfaceId(): string | null {
    return this.surfaceID
  }

  set surfaceId(value: string | null) {
    if (value !== null) {
      this.surfaceID = value
    }
  }

  private get avPlayer(): media.AVPlayer | undefined {
    return this.engineAdapter.player
  }

  async create(): Promise<void> {
    try {
      await this.engineAdapter.create()
    } catch (error) {
      ToolsUtil.showToast('播放异常')
      salmonLogger.addLog('avplayer', `create avplayer error: ${error}`, true)
    }
  }

  async getFrameByTime(time: number, isFirstFrame: boolean) {
    if (!Setting.showFrameImgStatus) {
      return
    }
    this.pendingFrameTime = time
    if (isFirstFrame) {
      if (this.frameFetchTimer) {
        clearTimeout(this.frameFetchTimer)
        this.frameFetchTimer = 0
      }
      await this.fetchPendingFrame()
      return
    }
    this.schedulePendingFrameFetch()
  }

  private schedulePendingFrameFetch(): void {
    if (this.pendingFrameTime < 0 || !VideoOperateUtil.updatePix || this.frameFetchTimer) {
      return
    }
    const remaining = this.FRAME_FETCH_INTERVAL - (Date.now() - this.lastFrameFetchTime)
    if (remaining <= 0) {
      this.fetchPendingFrame()
      return
    }
    this.frameFetchTimer = setTimeout(() => {
      this.frameFetchTimer = 0
      this.fetchPendingFrame()
    }, remaining)
  }

  private async fetchPendingFrame(): Promise<void> {
    if (this.pendingFrameTime < 0 || !VideoOperateUtil.updatePix) {
      return
    }
    const time = this.pendingFrameTime
    this.pendingFrameTime = -1
    if (Math.floor(time) === Math.floor(this.lastFrameFetchPlayTime)) {
      this.schedulePendingFrameFetch()
      return
    }
    this.lastFrameFetchTime = Date.now()
    this.lastFrameFetchPlayTime = time
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
      this.schedulePendingFrameFetch()
    }
  }

  async initVolumeAndBrightness() {
    let audioManager = audio.getAudioManager()
    this.audioVolumeManager = audioManager.getVolumeManager()
    let volumeList = VideoOperateUtil.getVolume()
    if (this.volume === 0) {
      this.volume = volumeList.get('volume')!
      this.volumeActually = this.volume
    }
    try {
      this.audioVolumeManager.off('streamVolumeChange')
    } catch (_error) {
    }
    let swipingVoiceTimer: number | null = null
    let changeVolumeByVolumeButton: boolean = false
    try {
      this.audioVolumeManager.on('streamVolumeChange', audio.StreamUsage.STREAM_USAGE_MOVIE,
        (streamVolumeEvent: audio.StreamVolumeEvent) => {
          clearTimeout(swipingVoiceTimer)
          if (!this.onSwipingVoice) {
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
    if (this.screenBrightness === 0) {
      this.screenBrightness = await VideoOperateUtil.getScreenBrightness()
    }
  }

  registerSubtitleListener() {
    this.avPlayer?.on('subtitleUpdate', async (info: media.SubtitleInfo) => {
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

  setExternalSubtitle(nowPlaying: VideoMetadata) {
    SubtitleUtil.offsetMillis = nowPlaying.subtitle_offset_millis ?? 0
    SubtitleUtil.isSubtitleExist(PathUtils.subtitlePath!, nowPlaying.date!).then(exists => {
      if (!exists) {
        this.applySubtitlePreference(nowPlaying, false)
        return
      }
      try {
        let subtitle = fileIo.openSync(PathUtils.subtitlePath! + nowPlaying.date, fileIo.OpenMode.READ_ONLY)
        SubtitleUtil.parseSubtitleProcess(subtitle.path, nowPlaying.external_subtitle_format).then(success => {
          try {
            fileIo.closeSync(subtitle)
          } catch (_e) {
          }
          if (success) {
            this.subtitle = SubtitleUtil.getSubtitlesAtTime(this.playTime)
            this.applySubtitlePreference(nowPlaying, true)
          } else {
            this.applySubtitlePreference(nowPlaying, false)
          }
        }).catch(() => {
          try {
            fileIo.closeSync(subtitle)
          } catch (_e) {
          }
          this.applySubtitlePreference(nowPlaying, false)
        })
      } catch (_error) {
        this.applySubtitlePreference(nowPlaying, false)
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
      case VideoStartTimeMode.SEEK_TO_BEGINNING:
        this.seekTime(0)
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

  selectAudioTrackByIndex(index: number): void {
    if (index >= 0 && index < this.audioTrack.length) {
      this.selectAudioTrack(this.audioTrack[index].index)
    }
  }

  getAudioTrackCount(): number {
    return this.audioTrack.length
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

  async release(): Promise<void> {
    this.videoSwitchVersion++
    this.isSwitchingVideo = false
    const player = this.avPlayer
    if (!player) {
      await this.engineAdapter.release()
      return
    }
    this.transitionTo(PlayerState.RELEASING)
    AppStorage.delete('nowPlayingData')
    await this.engineAdapter.release(() => {
      this.clearAudioVolumeSubscription()
      this.clearPlayerSubscriptions(player)
    })
    this.transitionTo(PlayerState.IDLE)
  }

  async reset(): Promise<void> {
    if (!this.isSwitchingVideo) {
      this.transitionTo(PlayerState.IDLE)
    }
    await this.engineAdapter.reset()
  }

  prepare() {
    this.avPlayer?.prepare()?.catch(() => {
      salmonLogger.addLog(TAG, 'prepare error', true)
    })
  }

  pause() {
    PiPWindowUtil.disableAutoStart()
    this.avPlayer?.pause()?.catch(() => {
      salmonLogger.addLog(TAG, `pause error`, true)
    })
  }

  play() {
    PiPWindowUtil.enableAutoStart()
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
    this.release().catch(() => {
      salmonLogger.addLog(TAG, 'cancelSubscribe error', true)
    })
  }

  playAdjacentVideo(repeatMode: SweetRepeatMode,
    direction: 'previous' | 'next'): VideoMetadata | undefined {
    return VideoOperateUtil.computeAdjacentVideo(this.videoMetaDataList, this.nowPlaying, repeatMode, direction)
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
    AVSessionUtil.applyAudioConcurrencyMode()
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
    xComponentController?: XComponentController, overrideRepeatMode?: SweetRepeatMode) {
    salmonLogger.addLog(TAG, "开始播放下一个视频前置流程", false)
    const effectiveRepeatMode = overrideRepeatMode ?? this.repeatMode
    const nextItem = this.playAdjacentVideo(effectiveRepeatMode, 'next')
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
    const switchVersion = ++this.videoSwitchVersion
    this.isSwitchingVideo = true
    try {
      if (!this.skipHistory) {
        VideoOperateUtil.saveVideoTime(this.playTime, this.nowPlaying!, PathUtils.appContext!)
      }

      this.pixelMap = null
      const player = this.avPlayer
      if (player) {
        await this.engineAdapter.waitForReset(player)
      }
      if (this.engineAdapter.isReleasing() || (player && !this.engineAdapter.isCurrent(player))) {
        salmonLogger.addLog(TAG, "播放器正在释放，取消切换视频", true)
        return
      }
      player?.off('subtitleUpdate')

      this.transitionTo(PlayerState.LOADING)
      await this.reset()
      if (!this.isVideoSwitchActive(switchVersion) || (player && !this.engineAdapter.isCurrent(player))) {
        salmonLogger.addLog(TAG, "播放器生命周期已变化，取消加载新视频", true)
        return
      }
      if (!this.avPlayer) {
        salmonLogger.addLog(TAG, "reset后avPlayer为空，重新创建播放器", true)
        await this.init()
        if (xComponentController) {
          this.setPlayerCallback(pathStack, xComponentController, windowClass)
        }
      }
      const loadingPlayer = this.avPlayer
      if (!loadingPlayer || !this.isVideoSwitchActive(switchVersion, loadingPlayer)) {
        salmonLogger.addLog(TAG, "播放器已失效，取消加载新视频", false)
        return
      }
      if (!PrivacySpaceUtil.getPrivacyMode()) {
        const findResult = Preferences.findVideoByDate(PathUtils.appContext!, item.date)
        const latestItem = findResult[0]
        const videoList = findResult[1]
        if (latestItem && videoList.length > 0) {
          this.videoMetaDataList = videoList
          this.nowPlaying = latestItem
        } else {
          this.nowPlaying = item as VideoMetadata
        }
        salmonLogger.addLog(TAG, "更新播放列表数据完成", false)
      } else {
        this.nowPlaying = item as VideoMetadata
      }
      salmonLogger.addLog(TAG, "设置当前播放视频完成", false)

      const loaded = await this.loadAndPrepare(pathStack!, windowClass!, loadingPlayer, switchVersion)
      if (!loaded) {
        salmonLogger.addLog(TAG, "视频切换已取消，跳过后续初始化", false)
        return
      }
      salmonLogger.addLog(TAG, "获取播放数据完成", false)
      await this.initAVSession()
      salmonLogger.addLog(TAG, "播放选择视频流程完成", false)
    } catch (e) {
      if (switchVersion !== this.videoSwitchVersion) {
        salmonLogger.addLog(TAG, "播放器生命周期已变化，忽略已取消切换的异常: " + e, false)
        return
      }
      salmonLogger.addLog(TAG, "播放选择视频失败: " + e, true)
      this.transitionTo(PlayerState.ERROR)
    } finally {
      if (switchVersion === this.videoSwitchVersion) {
        this.isSwitchingVideo = false
        this.isSkippingEnding = false
      }
    }
  }

  async getData(pathStack?: NavPathStack, windowClass?: Promise<window.Window | undefined>) {
    salmonLogger.addLog(TAG, "开始获取播放数据", false)
    this.transitionTo(PlayerState.PREPARING)
    try {
      if (this.avPlayer) {
        try {
          await PermissionUtil.activatePermission(this.nowPlaying?.uri)
          if (ToolsUtil.isNetworkUrl(this.nowPlaying?.uri)) {
            this.avPlayer.url = this.nowPlaying?.uri
          } else {
            this.avPlayer.fdSrc = fileIo.openSync(this.nowPlaying?.uri)
          }
        } catch (error) {
          salmonLogger.addLog(TAG, "打开视频文件失败：" + error, true)
          ToolsUtil.showToast('视频打开失败，可能已失效：' + error)
          pathStack && pathStack.pop()
          return
        }
        if (!ToolsUtil.isNetworkUrl(this.nowPlaying?.uri)) {
          VideoOperateUtil.getFrameTimePreprocess(this.nowPlaying!.uri)?.catch(() => {
          })
        }
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
    this.applyScreenExtend()
    salmonLogger.addLog(TAG, "setRotation方法执行完成", false)
  }

  async init() {
    await this.create()
  }

  setLoudnessGain(loudnessGain: number) {
    this.volumeLoudnessGain = loudnessGain
    this.avPlayer?.setLoudnessGain(loudnessGain)?.catch(() => {
      salmonLogger.addLog(TAG, "设置响度失败", true)
    })
  }

  selectExternalSubtitleTrack(): void {
    // AVPlayer external subtitles continue to be rendered by ArkUI.
  }

  selectSecondarySubtitleTrack(_trackId: number): void {
    this.secondarySubtitleTrackSelected = -1
  }

  setSubtitlePosition(position: number): void {
    this.subtitlePosition = Math.max(5, Math.min(95, Math.round(position)))
  }

  setSubtitleSize(size: number): void {
    this.subtitleSize = Math.max(14, Math.min(48, Math.round(size)))
  }

  setAudioChannelMode(_mode: number): void {
  }

  async setAVPlayerProperties() {
    this.avPlayer!.surfaceId = this.surfaceID
    this.avPlayer!.audioInterruptMode = AVSessionUtil.getInterruptMode()
    this.avPlayer?.setPlaybackStrategy({
      preferredBufferDurationForPlaying: 20,
      showFirstFrameOnPrepare: true,
      // enableSuperResolution: true,
      preferredHdr: true
    })?.catch(() => {
      salmonLogger.addLog(TAG, "设置播放策略失败", true)
    })
    // if (Setting.superResolutionState) {
    //   this.setSuperResolutionState(true)
    // }
    this.registerSubtitleListener()
    this.setExternalSubtitle(this.nowPlaying!)
    this.registerAudioInterruptListener()
  }

  registerAudioInterruptListener() {
    this.avPlayer?.on('audioInterrupt', async (interruptEvent: audio.InterruptEvent) => {
      if (interruptEvent.forceType === audio.InterruptForceType.INTERRUPT_FORCE) {
        switch (interruptEvent.hintType) {
          case audio.InterruptHint.INTERRUPT_HINT_PAUSE:
            this.pause()
            break
          case audio.InterruptHint.INTERRUPT_HINT_STOP:
            this.pause()
            break
          case audio.InterruptHint.INTERRUPT_HINT_DUCK:
            salmonLogger.addLog(TAG, 'Audio interrupted: ducked', false)
            break
          case audio.InterruptHint.INTERRUPT_HINT_UNDUCK:
            salmonLogger.addLog(TAG, 'Audio interrupted: unducked', false)
            break
          default:
            break
        }
      } else if (interruptEvent.forceType === audio.InterruptForceType.INTERRUPT_SHARE) {
        switch (interruptEvent.hintType) {
          case audio.InterruptHint.INTERRUPT_HINT_RESUME:
            this.play()
            break
          default:
            break
        }
      }
    })
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
    const player = this.avPlayer
    if (!player) {
      return
    }
    if (this.callbackPlayer === player) {
      return
    }
    this.callbackPlayer = player
    player.on('timeUpdate', async (duration) => {
      if (!this.onSwiping) {
        ThrottleUtil.throttle('playTime', () => {
          this.playTime = duration
        }, 100)
      }
      const now = Date.now()
      if (now - this.lastAppStorageUpdateTime >= 200) {
        this.lastAppStorageUpdateTime = now
        AppStorage.setOrCreate('nowPlayingData',
          [this.playTime, this.nowPlaying!, this.skipHistory])
      }
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
      const totalTime = this.nowPlaying?.time ?? 0
      const startTime = this.nowPlaying?.start_time
      const endTime = this.nowPlaying?.end_time
      const skipIntroMs = Number(Setting.skipIntroTime) * 1000
      const skipOutroSeconds = Number(Setting.skipOutroTime)
      const skipOutroMs = skipOutroSeconds * 1000
      // 单视频片尾跳过：片尾<=总时长 且 片尾>片头（片头+片尾<=总时长）
      if (endTime != null && endTime > 0 && (totalTime <= 0 || endTime <= totalTime)
        && (startTime == null || startTime <= 0 || endTime > startTime)
        && duration >= endTime && this.repeatMode !== SweetRepeatMode.SINGLE
        && !this.isSkippingEnding) {
        this.isSkippingEnding = true
        salmonLogger.addLog(pathStack?.getAllPathName()[0] ?? TAG,
          `检测到视频片尾，准备播放下一个视频，满足条件为: endTime: ${endTime}, repeatMode: ${this.repeatMode}, duration: ${duration}`,
          false)
        await this.playNextVideoProcess(pathStack, windowClass, xComponentController)
        this.setPlayerCallback(pathStack, xComponentController, windowClass)
        ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.skipped_video_ending').id))
      }
      // 全局片尾跳过：片尾<=总时长 且 片头+片尾<=总时长
      if (skipOutroSeconds > 0 && (endTime == null || endTime === 0)) {
        if (totalTime > 0 && skipOutroMs <= totalTime && skipIntroMs + skipOutroMs <= totalTime
          && duration >= totalTime - skipOutroMs && this.repeatMode !== SweetRepeatMode.SINGLE
          && !this.isSkippingEnding) {
          this.isSkippingEnding = true
          salmonLogger.addLog(pathStack?.getAllPathName()[0] ?? TAG,
            `检测到视频片尾（全局），准备播放下一个视频，满足条件为: skipOutroTime: ${skipOutroSeconds}s, totalTime: ${totalTime}, duration: ${duration}`,
            false)
          await this.playNextVideoProcess(pathStack, windowClass, xComponentController)
          this.setPlayerCallback(pathStack, xComponentController, windowClass)
          ToolsUtil.showToast('已跳过片尾')
        }
      }
      if (this.subtitleSelected === SubtitleMode.EXTERNAL_SUBTITLE) {
        const newSubtitle = SubtitleUtil.getSubtitlesAtTime(duration)
        if (newSubtitle !== this.lastSubtitle) {
          this.lastSubtitle = newSubtitle
          this.subtitle = newSubtitle
        }
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

    player.on('seekDone', (percent) => {
      salmonLogger.addLog(pathStack?.getAllPathName()[0] ?? TAG, "播放器跳转完成", false)
      this.playTime = percent
      AVSessionUtil.updatePlaybackSessionState(this.playing, this.playTime, this.repeatMode)
      if (!this.playing) {
        this.startImageAnalyzer(xComponentController!)
      }
    })

    player.on('playbackRateDone', (rate: number) => {
      this.speed = rate
    })

    player.on('audioOutputDeviceChangeWithInfo', (data: audio.AudioStreamDeviceChangeInfo) => {
      if (data.changeReason === audio.AudioStreamDeviceChangeReason.REASON_OLD_DEVICE_UNAVAILABLE) {
        this.pause()
      }
    })

    player.on('stateChange', async (state) => {
      salmonLogger.addLog(pathStack?.getAllPathName()[0] ?? TAG,
        `AVPlayer原生状态变更: ${state}, 应用状态: ${PlayerState[this.playerState]}`, false)
      if (!this.engineAdapter.isCurrent(player)) {
        salmonLogger.addLog(TAG, `忽略已失效播放器的状态回调: ${state}`, false)
        return
      }
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
          this.playbackDetailsInitialized = false
          if (this.initialPlayTime !== undefined) {
            const resumeTime = this.initialPlayTime
            this.initialPlayTime = undefined
            this.seekTime(resumeTime)
            salmonLogger.addLog(TAG, `切换引擎后恢复播放进度: ${resumeTime}`, false)
          } else {
            const seekMode = VideoOperateUtil.getVideoStartPlayTimeMode(this.nowPlaying!)
            salmonLogger.addLog(pathStack?.getAllPathName()[0] ?? TAG,
              `恢复播放进度: last_play=${this.nowPlaying?.last_play}, time=${this.nowPlaying?.time}, start_time=${this.nowPlaying?.start_time}, seekMode=${seekMode}`,
              false)
            this.videoStartPlayTime(seekMode)
          }
          this.play()
          salmonLogger.addLog(pathStack?.getAllPathName()[0] ?? TAG, "开始播放视频", false)
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
          this.playTime = this.nowPlaying?.time || this.playTime
          if (!this.skipHistory) {
            const completedPlayTime = this.nowPlaying!.time || this.playTime
            salmonLogger.addLog(pathStack?.getAllPathName()[0] ?? TAG,
              `播放完成，保存进度: playTime=${this.playTime}, totalTime=${this.nowPlaying!.time}, savedTime=${completedPlayTime}`,
              false)
            VideoOperateUtil.saveVideoTime(completedPlayTime, this.nowPlaying!,
              PathUtils.appContext!)
          }
          salmonLogger.addLog(pathStack?.getAllPathName()[0] ?? TAG, "保存视频播放时间完成", false)
          if (this.repeatMode === SweetRepeatMode.SINGLE) {
            salmonLogger.addLog(pathStack?.getAllPathName()[0] ?? TAG, "单曲循环模式，重新开始播放", false)
            this.play()
            this.seekTime(0)
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
          const shouldPauseAfterSwitch = this.initialPlaying === false
          this.initialPlaying = undefined
          await this.initAVSession()
          salmonLogger.addLog(pathStack?.getAllPathName()[0] ?? TAG, "初始化AVSession完成", false)
          this.initializePlaybackDetails(player, pathStack)
          AVSessionUtil.updatePlaybackSessionState(this.playing, this.playTime, this.repeatMode)
          salmonLogger.addLog(pathStack?.getAllPathName()[0] ?? TAG, "更新播放会话状态完成", false)
          xComponentController!.stopImageAnalyzer()
          salmonLogger.addLog(pathStack?.getAllPathName()[0] ?? TAG, "停止图像分析器完成", false)
          if (shouldPauseAfterSwitch) {
            this.pause()
          }
          break
        case 'paused':
          if (this.isSwitchingVideo) {
            salmonLogger.addLog(TAG, '切换视频期间忽略 reset 产生的 paused 回调', false)
            break
          }
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
          if (this.isSwitchingVideo || this.isInState(PlayerState.LOADING) || this.isInState(PlayerState.IDLE)
            || this.isInState(PlayerState.PREPARING)) {
            salmonLogger.addLog(pathStack?.getAllPathName()[0] ?? TAG, "正在加载、空闲或准备中，跳过idle状态释放", false)
          } else {
            await this.release()
            salmonLogger.addLog(pathStack?.getAllPathName()[0] ?? TAG, "释放播放器资源完成", false)
          }
          break
        case 'error':
          salmonLogger.addLog(pathStack?.getAllPathName()[0] ?? TAG, "进入error状态", false)
          this.transitionTo(PlayerState.ERROR)
          try {
            await VideoOperateUtil.releaseAVImageGenerator()
            await this.requestEngineSwitch(PlayerEngine.MPV_PLAYER, 'AVPlayer state error', true)
            salmonLogger.addLog(pathStack?.getAllPathName()[0] ?? TAG, "执行播放错误处理完成", false)
          } catch (error) {
            salmonLogger.addLog(TAG, `AVPlayer error fallback failed: ${error}`, true)
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

  setSubtitleOffset(offsetMillis: number): void {
    this.refreshExternalSubtitlePreview(offsetMillis)
  }

  setSubtitle3DMode(_mode: Subtitle3DMode): void {
  }

  supportsSubtitle3D(): boolean {
    return true
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

  isMpvPlayer(): boolean {
    return false
  }

  getWindowClass(): Promise<window.Window | undefined> | undefined {
    return undefined
  }

  prepareIfNeeded(): void {
  }

  onPlayerReady(): void {
    this.initVolumeAndBrightness().catch((err: Error) => {
      salmonLogger.addLog(TAG, 'initVolumeAndBrightness failed: ' + err, true)
    })
  }

  savePlayerSpeed(context: Context): void {
    Preferences.saveVideoSpeed(context,
      (VideoInfoUtil.videoSpeedListAll.includes(this.speed) ? this.speed : 1) + 'x')
  }

  onDisappearSaveSubtitlePreference(subtitleVisibility: Visibility, isAIAsrShown: boolean,
    subtitle3DMode: Subtitle3DMode): void {
    this.saveSubtitlePreferenceForCurrentVideo(subtitleVisibility, isAIAsrShown, subtitle3DMode)
  }

  onDisappearCleanup(): void {
  }

  async dispose(): Promise<void> {
    AppStorage.delete('nowPlayingData')
    await VideoOperateUtil.releaseAVImageGenerator()
    await this.release()
  }

  async onDisappearRelease(): Promise<void> {
    await this.dispose()
  }

  async onSurfaceLoad(xComponentController: XComponentController, pathStack: NavPathStack,
    windowClass?: Promise<window.Window | undefined>): Promise<void> {
    this.surfaceId = xComponentController.getXComponentSurfaceId()
    const permissionPromise = PermissionUtil.activatePermission(this.nowPlaying?.uri)
    await this.init()
    this.setPlayerCallback(pathStack, xComponentController, windowClass)
    try {
      await permissionPromise
      if (this.avPlayer) {
        if (ToolsUtil.isNetworkUrl(this.nowPlaying?.uri)) {
          this.avPlayer.url = this.nowPlaying?.uri
        } else {
          this.avPlayer.fdSrc = fileIo.openSync(this.nowPlaying?.uri)
        }
      }
    } catch (error) {
      salmonLogger.addLog(TAG, "打开视频文件失败：" + error, true)
      ToolsUtil.showToast('视频打开失败，可能已失效：' + error)
      pathStack.pop()
      return
    }
    if (!ToolsUtil.isNetworkUrl(this.nowPlaying?.uri)) {
      VideoOperateUtil.getFrameTimePreprocess(this.nowPlaying!.uri)?.catch(() => {
      })
    }
    this.setRotation()
    if (windowClass) {
      this.playAreaWidth > this.playAreaHeight ?
        WindowUtil.enableLandscapeMultiWindow(windowClass) :
        WindowUtil.disableLandscapeMultiWindow(windowClass)
    }
    if (Setting.smartRotation && this.playAreaWidth > this.playAreaHeight &&
      this.screenHeight > this.screenWidth) {
      windowClass?.then(w => {
        const proportion =
          Math.max(this.screenWidth, this.screenHeight) /
            Math.min(this.screenWidth, this.screenHeight)
        const orientation = proportion > (16 / 10) ? window.Orientation.AUTO_ROTATION_LANDSCAPE
          : window.Orientation.AUTO_ROTATION_RESTRICTED
        w?.setPreferredOrientation(orientation)?.catch(() => {
          salmonLogger.addLog(TAG, "设置窗口方向失败", true)
        })
      })
    }
    await PiPWindowUtil.createPipController(xComponentController, this)

    this.transitionTo(PlayerState.PREPARING)
    try {
      await this.waitForState(PlayerState.PLAYING, 10000)
    } catch (e) {
      salmonLogger.addLog(TAG, "onSurfaceLoad等待PLAYING状态超时，降级到MPV: " + e, true)
      try {
        await VideoOperateUtil.releaseAVImageGenerator()
        await this.requestEngineSwitch(PlayerEngine.MPV_PLAYER, 'AVPlayer start timeout', true)
      } catch (error) {
        salmonLogger.addLog(TAG, `AVPlayer timeout fallback failed: ${error}`, true)
      }
    }
  }

  onOsdSurfaceLoad(_surfaceId: string, _surfaceWidth: number, _surfaceHeight: number): void {
  }

  restoreSpeedAfterLongPress(lastSpeed: number): void {
    this.updatePlaybackSpeed(lastSpeed)
  }

  async restoreSystemBars(windowClass?: Promise<window.Window | undefined>): Promise<void> {
    if (canIUse('SystemCapability.Window.SessionManager')) {
      (await windowClass)?.setSpecificSystemBarEnabled('status', true).catch(() => {
        salmonLogger.addLog(TAG, "设置状态栏失败", true)
      })
      ;
      (await windowClass)?.setSpecificSystemBarEnabled('navigationIndicator', true).catch(() => {
        salmonLogger.addLog(TAG, "设置导航指示器失败", true)
      })
    }
  }

  onWillDisappearCleanup(): void {
  }

  async onWillDisappearRelease(_windowClass?: Promise<window.Window | undefined>): Promise<void> {
    await this.dispose()
  }

  hasChapterSupport(): boolean {
    return false
  }

  seekToChapter(_chapterIndex: number): void {
  }

  resetAspectRatio(): void {
  }

  stretchToFullScreen(): void {
  }

  async exitPlayback(timeout: number): Promise<void> {
    ToolsUtil.showToast(timeout > 0 ? '到设定的时间了，已自动退出' : '已退出')
    await this.reset()
  }

  toggleListenVideo(): void {
    this.isListenVideo = !this.isListenVideo
    this.isListenVideo ? ToolsUtil.showToast('只听视频模式已开启') :
      ToolsUtil.showToast('只听视频模式已关闭')
    this.setListenVideoStatus()
  }

  getXComponentId(): string | undefined {
    return undefined
  }

  getLibraryName(): string | undefined {
    return undefined
  }

  getOsdVisibility(): boolean {
    return false
  }

  setEngineSwitchHandler(handler: PlayerEngineSwitchHandler | undefined): void {
    this.engineSwitchHandler = handler
  }

  async requestEngineSwitch(targetEngine: string, reason: string, resumePlayback?: boolean): Promise<void> {
    if (!this.engineSwitchHandler) {
      salmonLogger.addLog(TAG, `Ignore engine switch without handler: ${reason}`, true)
      return
    }
    await this.engineSwitchHandler(targetEngine, reason, resumePlayback)
  }

  private clearAudioVolumeSubscription(): void {
    try {
      this.audioVolumeManager?.off('streamVolumeChange')
      this.audioVolumeManager = null
      salmonLogger.addLog(TAG, "取消音量监听完成", false)
    } catch (error) {
      salmonLogger.addLog(TAG, `取消音量监听错误 ${error}`, true)
    }
  }

  private clearPlayerSubscription(action: () => void, eventName: string): void {
    try {
      action()
    } catch (error) {
      salmonLogger.addLog(TAG, `取消${eventName}监听错误 ${error}`, true)
    }
  }

  private clearPlayerSubscriptions(player: media.AVPlayer): void {
    // 先移除状态回调，避免 reset/release 的状态通知再次进入销毁流程。
    this.clearPlayerSubscription(() => player.off('stateChange'), 'stateChange')
    this.clearPlayerSubscription(() => player.off('timeUpdate'), 'timeUpdate')
    this.clearPlayerSubscription(() => player.off('seekDone'), 'seekDone')
    this.clearPlayerSubscription(() => player.off('playbackRateDone'), 'playbackRateDone')
    this.clearPlayerSubscription(() => player.off('audioOutputDeviceChangeWithInfo'),
      'audioOutputDeviceChangeWithInfo')
    this.clearPlayerSubscription(() => player.off('audioInterrupt'), 'audioInterrupt')
    this.clearPlayerSubscription(() => player.off('superResolutionChanged'), 'superResolutionChanged')
    // subtitleUpdate 会进入系统的 SetSubtitleCbDfxStatus，必须在 reset 开始前调用。
    this.clearPlayerSubscription(() => player.off('subtitleUpdate'), 'subtitleUpdate')
    if (this.callbackPlayer === player) {
      this.callbackPlayer = undefined
    }
    salmonLogger.addLog(TAG, "取消播放器监听完成", false)
  }

  private initializePlaybackDetails(player: media.AVPlayer, pathStack: NavPathStack): void {
    if (this.playbackDetailsInitialized) {
      return
    }
    this.playbackDetailsInitialized = true
    Promise.all([
      this.getAudioTrackList(),
      this.getSubtitleTrackList(),
      this.initVolumeAndBrightness()
    ]).then(() => {
      if (!this.engineAdapter.isCurrent(player)) {
        return
      }
      this.restoreInnerSubtitlePreference(this.nowPlaying!)
      salmonLogger.addLog(pathStack?.getAllPathName()[0] ?? TAG, "获取音频和字幕轨道完成", false)
    }).catch((error: Error) => {
      if (this.engineAdapter.isCurrent(player)) {
        this.playbackDetailsInitialized = false
        salmonLogger.addLog(TAG, `初始化音频和字幕轨道失败: ${error.message}`, true)
      }
    })
  }

  private applySubtitlePreference(nowPlaying: VideoMetadata, externalSubtitleLoaded: boolean) {
    const hasPreference = SubtitleUtil.hasSubtitlePreferenceMetadata(nowPlaying)
    if (hasPreference) {
      const preferredMode = nowPlaying.subtitle_mode as SubtitleMode | undefined
      if (preferredMode === SubtitleMode.EXTERNAL_SUBTITLE && !externalSubtitleLoaded) {
        this.subtitleSelected = SubtitleMode.NONE
        this.resetSubtitlePreference(nowPlaying)
        SubtitleUtil.offsetMillis = 0
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
  }

  private applyScreenExtend() {
    const size = VideoOperateUtil.calcScreenExtendSize(this.selectedText, this.screenWidth, this.screenHeight)
    if (size) {
      this.playAreaWidth = size[0]
      this.playAreaHeight = size[1]
    }
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
      this.stateChangeRejectors.delete(key)
    }
    if (newState === PlayerState.ERROR) {
      this.stateChangeResolvers.forEach((_, k) => {
        const rejector = this.stateChangeRejectors.get(k)
        if (rejector) {
          rejector(new Error(`播放器进入错误状态，等待${k}被取消`))
        }
      })
      this.stateChangeResolvers.clear()
      this.stateChangeRejectors.clear()
    }
  }

  private waitForState(targetState: PlayerState, timeoutMs: number = 10000): Promise<void> {
    if (this.playerState === targetState) {
      return Promise.resolve()
    }
    return new Promise<void>((resolve, reject) => {
      const key = PlayerState[targetState]
      this.stateChangeResolvers.set(key, resolve)
      this.stateChangeRejectors.set(key, reject)
      setTimeout(() => {
        if (this.stateChangeResolvers.has(key)) {
          this.stateChangeResolvers.delete(key)
          this.stateChangeRejectors.delete(key)
          reject(new Error(`等待状态${key}超时`))
        }
      }, timeoutMs)
    })
  }

  private isInState(state: PlayerState): boolean {
    return this.playerState === state
  }

  private async loadAndPrepare(pathStack: NavPathStack, windowClass: Promise<window.Window | undefined> | undefined,
    player: media.AVPlayer, switchVersion: number): Promise<boolean> {
    if (!this.isVideoSwitchActive(switchVersion, player)) {
      return false
    }
    try {
      await PermissionUtil.activatePermission(this.nowPlaying?.uri)
      if (!this.isVideoSwitchActive(switchVersion, player)) {
        return false
      }
      if (ToolsUtil.isNetworkUrl(this.nowPlaying?.uri)) {
        player.url = this.nowPlaying?.uri
      } else {
        player.fdSrc = fileIo.openSync(this.nowPlaying?.uri)
      }
    } catch (error) {
      if (!this.isVideoSwitchActive(switchVersion, player)) {
        salmonLogger.addLog(TAG, "播放器生命周期已变化，取消设置视频源", false)
        return false
      }
      salmonLogger.addLog(TAG, "打开视频文件失败：" + error, true)
      ToolsUtil.showToast('视频打开失败，可能已失效：' + error)
      pathStack.pop()
      throw new Error('打开视频文件失败：' + error)
    }
    if (!ToolsUtil.isNetworkUrl(this.nowPlaying?.uri)) {
      VideoOperateUtil.getFrameTimePreprocess(this.nowPlaying!.uri)?.catch(() => {
      })
    }
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
    await this.waitForState(PlayerState.PLAYING, 10000)
    return this.isVideoSwitchActive(switchVersion, player)
  }

  private isVideoSwitchActive(switchVersion: number, player?: media.AVPlayer): boolean {
    return this.isSwitchingVideo && switchVersion === this.videoSwitchVersion &&
      !this.engineAdapter.isReleasing() && (!player || this.engineAdapter.isCurrent(player))
  }
}
