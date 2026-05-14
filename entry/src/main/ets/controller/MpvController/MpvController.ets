import { PlayerControllerInterface } from '../PlayerControllerFactory';
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface';
import { Subtitle3DMode, SubtitleMode } from '../../common/enum/SubtitleMode';
import { MpvAudioTrack, MpvDecodingMethod, MpvSubtitleTrack } from './MpvTypes';
import { avSession, avSession as avSessionManager } from '@kit.AVSessionKit';
import { audio } from '@kit.AudioKit';
import { WindowUtil } from '../../utils/WindowUtil';
import { SweetRepeatMode } from '../../common/enum/SweetRepeatMode';
import { BaseListener } from '../../utils/BaseEventUtil';
import { salmonLogger } from 'salmonlogger';
import {
  create as mpvCreate,
  destroy as mpvDestroy,
  getAudioTracks as mpvGetAudioTracks,
  getCurrentSubtitleTrack as mpvGetCurrentSubtitleTrack,
  getDuration as mpvGetDuration,
  getSubtitleTracks as mpvGetSubtitleTracks,
  getVideoHeight as mpvGetVideoHeight,
  getVideoWidth as mpvGetVideoWidth,
  loadVideo as mpvLoadVideo,
  pause as mpvPause,
  play as mpvPlay,
  registerPlaybackCompleteCallback as mpvRegisterPlaybackCompleteCallback,
  registerSurfaceModeErrorCallback as mpvRegisterSurfaceModeErrorCallback,
  registerTimeUpdateCallback as mpvRegisterTimeUpdateCallback,
  registerVideoSizeChangedCallback as mpvRegisterVideoSizeChangedCallback,
  reset as mpvReset,
  seek as mpvSeek,
  selectAudio as mpvSelectAudio,
  selectSubtitle as mpvSelectSubtitle,
  setBlurayDevice as mpvSetBlurayDevice,
  setDecodeType as mpvSetDecodeType,
  setHwdecMode as mpvSetHwdecMode,
  setKeepAspect as mpvSetKeepAspect,
  setLoudnessGain as mpvSetLoudnessGain,
  setOsdSurface as mpvSetOsdSurface,
  setSpeed as mpvSetSpeed,
  unregisterPlaybackCompleteCallback as mpvUnregisterPlaybackCompleteCallback,
  unregisterSurfaceModeErrorCallback as mpvUnregisterSurfaceModeErrorCallback,
  unregisterTimeUpdateCallback as mpvUnregisterTimeUpdateCallback,
  unregisterVideoSizeChangedCallback as mpvUnregisterVideoSizeChangedCallback,
} from 'libmpvnative.so';
import {
  AUTO_HIDE_SHOW_CONTROL_TIME,
  LEFT_ZONE_DIVISION,
  RIGHT_ZONE_DIVISION,
  SCREEN_DIVISIONS
} from '../../common/Constants';
import { VideoStartTimeMode } from '../../common/enum/VideoStartTimeMode';
import Preferences from '../../database/Preferences';
import AVSessionUtil from '../../utils/AVSessionUtil';
import IsoFileUtil from '../../utils/IsoFileUtil';
import { Setting } from '../../utils/ObservedUtil';
import { PathUtils } from '../../utils/PathUtils';
import PermissionUtil from '../../utils/PermissionUtil';
import PiPWindowUtil from '../../utils/PiPWindowUtil';
import PrivacySpaceUtil from '../../utils/PrivacySpaceUtil';
import RecentPlayUtil from '../../utils/RecentPlayUtil';
import SelectFileUtil from '../../utils/SelectFileUtil';
import SubtitleUtil from '../../utils/SubtitleUtil';
import ToolsUtil from '../../utils/ToolsUtil';
import VideoInfoUtil from '../../utils/VideoInfoUtil';
import VideoOperateUtil from '../../utils/VideoOperateUtil';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { window } from '@kit.ArkUI';

const TAG = 'MpvController'

@ObservedV2
export class MpvController implements PlayerControllerInterface {
  windowClass = WindowUtil.getWindow()
  @Trace mpvHandle: number | null = null
  surfaceId: string | null = null
  osdSurfaceId: string | null = null
  @Trace playTime: number = 0
  @Trace playing: boolean = false
  @Trace nowPlaying: VideoMetadata | undefined = undefined
  @Trace videoMetaDataList: VideoMetadata[] = []
  @Trace speed: number = 1.0
  @Trace volume: number = 0
  @Trace volumeActually: number = 0
  @Trace audioTrack: MpvAudioTrack[] = []
  @Trace subtitleTrack: MpvSubtitleTrack[] = []
  @Trace subtitleTrackSelected: number = -1
  @Trace screenBrightness: number = 0
  @Trace onSwipingVoice: boolean = false
  @Trace subtitleSelected: SubtitleMode = SubtitleMode.INNER_SUBTITLE
  @Trace screenWidth: number = 0
  @Trace screenHeight: number = 0
  @Trace playAreaHeight: number = 0
  @Trace playAreaWidth: number = 0
  @Trace angle: number = 0
  @Trace repeatMode: SweetRepeatMode = SweetRepeatMode.LIST
  @Trace selectedText: string | undefined = '原始比例'
  @Trace onSwiping: boolean = false
  @Trace onSwipingBrightness: boolean = false
  @Trace isSliderPlayTimeChange: boolean = false
  @Trace audioTrackSelected: number = 0
  @Trace volumeLoudnessGain: number = 0
  @Trace lockVisibility: boolean = false
  @Trace longPress: boolean = false
  @Trace isLock: boolean = false
  @Trace abCircleStatus: boolean = false
  @Trace osdVisibility: boolean = false
  @Trace isZoomed: boolean = false
  @Trace translateX: number = 0
  @Trace translateY: number = 0
  @Trace subtitle: string = ''
  @Trace showControl: boolean = false
  avSession: avSessionManager.AVSession | undefined = undefined
  audioVolumeManager: audio.AudioVolumeManager | null = null
  private userListener: BaseListener<number> | null = null
  private playbackCallbackRegistered: boolean = false
  private timeUpdateCallbackRegistered: boolean = false
  private videoSizeCallbackRegistered: boolean = false
  private surfaceModeErrorCallbackRegistered: boolean = false
  private isSwitchingToBufferMode: boolean = false // 防止重复切换
  private isSwitchingToSoftwareMode: boolean = false // 防止重复切换到软解

  async playChooseVideo(item: VideoMetadata, pathStack: NavPathStack) {
    this.osdVisibility = false
    ToolsUtil.addLogger("开始播放选择的视频", false)
    VideoOperateUtil.saveVideoTime(this.playTime, this.nowPlaying!, this.videoMetaDataList, PathUtils.appContext!)
    if (!PrivacySpaceUtil.getPrivacyMode()) {
      RecentPlayUtil.addPlayback(PathUtils.appContext!, item)
      ToolsUtil.addLogger("添加到最近播放记录完成", false)
    }
    this.reset()
    this.nowPlaying = item as VideoMetadata
    ToolsUtil.addLogger("设置当前播放视频完成", false)

    // 更新播放列表数据，确保使用最新的数据
    if (!PrivacySpaceUtil.getPrivacyMode()) {
      const folders = Preferences.getFileFolder(PathUtils.appContext!)
      const currentFolder = folders.find(f =>
      f.video_list.some(v => v.date === item.date)
      )
      if (currentFolder) {
        this.videoMetaDataList = currentFolder.video_list
        ToolsUtil.addLogger("更新播放列表数据完成", false)
      }
    }

    await PermissionUtil.activatePermission(item.uri)
    this.init(item.uri, pathStack)
    ToolsUtil.addLogger("获取播放数据完成", false)
    this.initAVSession()
    ToolsUtil.addLogger("播放选择视频流程完成", false)
  }

  async playNextVideoProcess(pathStack: NavPathStack) {
    ToolsUtil.addLogger("开始播放下一个视频流程", false, pathStack)
    const nextItem = this.playNextVideo(this.repeatMode)
    ToolsUtil.addLogger("获取下一个视频项完成", false, pathStack)
    if (nextItem) {
      ToolsUtil.addLogger("存在下一个视频，开始播放", false, pathStack)
      await this.playChooseVideo(nextItem, pathStack)
    } else {
      ToolsUtil.addLogger("无下一个视频，播放结束", false, pathStack)
      ToolsUtil.showToast('播放完毕，已自动退出')
      pathStack.pop()
    }
    ToolsUtil.addLogger("播放下一个视频前置流程完成", false, pathStack)
  }

  playNextVideo(repeatMode: SweetRepeatMode): VideoMetadata | undefined {
    if (this.videoMetaDataList.length === 0) {
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

  create(): void {
    if (this.mpvHandle) {
      salmonLogger.addLog(TAG, '[MpvPlayer] MPV already created, skipping', true)
      return
    }
    try {
      // 在创建 MPV 实例之前先设置解码模式
      // 因为 mpvCreate() 会立即调用 ConfigureMPV()，此时需要正确的模式值
      let decodeType = Setting.mpvDecodingMethod
      // 通过简单视频名检测是否为杜比P5
      if (this.nowPlaying?.title.includes('DV') && !this.nowPlaying?.title.includes('HDR')) {
        decodeType = MpvDecodingMethod.HARDWARE_BUFFER
      }
      switch (decodeType) {
        case MpvDecodingMethod.HARDWARE_SURFACE:
          mpvSetDecodeType(0)
          mpvSetHwdecMode(1)
          break
        case MpvDecodingMethod.SOFTWARE:
          mpvSetDecodeType(1)
          break
        case MpvDecodingMethod.HARDWARE_BUFFER:
          mpvSetDecodeType(0)
          mpvSetHwdecMode(0)
          break
        default:
          mpvSetDecodeType(1)
      }
      // 现在创建 MPV 实例，此时全局配置已正确设置
      this.mpvHandle = mpvCreate()
      if (!this.mpvHandle) {
        salmonLogger.addLog(TAG, '[MpvPlayer] Failed to create mpv instance - handle is null/undefined', true)
      } else {
        salmonLogger.addLog(TAG, '[MpvPlayer] MPV instance created:' + this.mpvHandle, false)
      }
    } catch {
      salmonLogger.addLog(TAG, '[MpvPlayer] Exception during create', true)
      ToolsUtil.showToast("MPV 创建失败")
    }
  }

  init(url?: string, pathStack?: NavPathStack): void {
    // 处理ISO文件
    let playUrl = url!;
    if (IsoFileUtil.isIsoFile(url!)) {
      salmonLogger.addLog(TAG, '检测到ISO文件，使用bd://协议播放', false);

      // ISO文件：保留完整的file:// URI格式
      // bluray-device 需要完整的URI，而不是纯路径
      const isoPath = url!; // 保留原始URI，包含file://前缀

      // 设置bluray-device选项
      mpvSetBlurayDevice(this.mpvHandle, isoPath);

      // 使用bd://longest协议播放最长的标题
      playUrl = 'bd://longest';
    } else {
      // 非ISO文件，需要转换file:// URI为本地路径
      playUrl = new fileUri.FileUri(url!).path;
    }

    // 传递起始位置给 native（参考 mpv-android）
    mpvLoadVideo(this.mpvHandle, playUrl)

    // 注册播放完成回调（只注册一次）
    this.registerPlaybackCompleteListener(pathStack!)
    this.setPlayerCallback(pathStack!)
    this.getData()

    // OSD 显示逻辑：
    // 1. 首次播放：延迟显示 OSD，等待视频尺寸变化事件触发 syncOsdSurfaceSize()
    // 2. 切换视频：OSD 保持可见，视频尺寸变化事件会自动同步 OSD 尺寸
    // 3. 不再依赖固定的 1200ms 延迟，而是通过事件驱动

    // 智能旋转和外部字幕可以延迟执行，不影响播放
    setTimeout(async () => {
      if (Setting.smartRotation &&
        (this.playAreaWidth > this.playAreaHeight || this.nowPlaying!.size[0] > this.nowPlaying!.size[1]) &&
        this.screenHeight > this.screenWidth) {
        ToolsUtil.addLogger("智能旋转条件满足，开始设置方向", false)
        const proportion =
          Math.max(this.screenWidth, this.screenHeight) / Math.min(this.screenWidth, this.screenHeight)
        const orientation = proportion > (16 / 10) ? window.Orientation.AUTO_ROTATION_LANDSCAPE
          : window.Orientation.AUTO_ROTATION_RESTRICTED;
        (await this.windowClass)?.setPreferredOrientation(orientation)?.catch(() => {
          ToolsUtil.addLogger("设置窗口方向失败", true)
        })
        ToolsUtil.addLogger("设置窗口方向完成", false)
      }
      if (this.speed !== 1) {
        this.updatePlaybackSpeed(this.speed)
      }
      // 获取信息需要有延迟，否则无法获取
      this.getAudioTrackList()
      this.getSubtitleTrackList()
      this.videoStartPlayTime(VideoOperateUtil.getVideoStartPlayTimeMode(this.nowPlaying!))
      this.nowPlaying!.time = this.getDuration()
      this.setRotation()
      this.onSwiping = false
      this.isSliderPlayTimeChange = false
      // 首次播放时显示 OSD（切换视频时 OSD 保持可见）
      if (Setting.mpvDecodingMethod === MpvDecodingMethod.HARDWARE_SURFACE && !this.osdVisibility) {
        this.osdVisibility = true
      }
      await this.setExternalSubtitle(this.nowPlaying!)
    }, 1200)
  }

  setOsdSurface(surfaceId: string, playAreaWidth: number, playAreaHeight: number): void {
    // 使用实际的播放区域尺寸，而不是设备屏幕尺寸
    // 这样 OSD Surface 尺寸会与 XComponent 的实际布局尺寸一致
    mpvSetOsdSurface(surfaceId, playAreaWidth, playAreaHeight)
  }

  // 同步 OSD Surface 尺寸到视频原生分辨率
  // 解决字幕模糊问题：使用视频原生分辨率而非显示区域尺寸
  syncOsdSurfaceSize(): void {
    if (!this.osdSurfaceId) {
      return
    }
    // 使用视频原生分辨率，而不是 playAreaWidth/Height（显示区域尺寸）
    const videoWidth = this.getPlayAreaWidth()
    const videoHeight = this.getPlayAreaHeight()

    if (videoWidth > 0 && videoHeight > 0) {
      this.setOsdSurface(this.osdSurfaceId, videoWidth, videoHeight)
    }
  }

  setPlayerCallback(pathStack: NavPathStack) {
    this.userListener = new BaseListener<number>()
    this.userListener.on('timeUpdate', (duration: number) => {
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
      // 片尾跳过逻辑保留
      const endTime = this.nowPlaying?.end_time
      if (endTime != null && duration >= endTime && endTime > 0 && this.repeatMode !== SweetRepeatMode.SINGLE) {
        ToolsUtil.addLogger(`检测到视频片尾，准备播放下一个视频，满足条件为: endTime: ${endTime}, repeatMode: ${this.repeatMode}, duration: ${duration}`,
          false)
        this.playNextVideoProcess(pathStack)
        this.userListener?.clear()
        this.userListener = null
        this.setPlayerCallback(pathStack)
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
  }

  getData() {
    this.playing = true
    // 注册播放时间更新回调（事件驱动，替代轮询）
    this.registerTimeUpdateCallback()
    // 注册视频尺寸变化回调
    this.registerVideoSizeChangedCallback()
    // 注册Surface模式错误回调
    this.registerSurfaceModeErrorCallback()
  }

  backForward(): void {
    if (!this.mpvHandle) {
      return
    }
    mpvSeek(this.mpvHandle, (this.playTime - Number(Setting.fastForwardSeconds) * 1000) / 1000, true)
  }

  fastForward(): void {
    if (!this.mpvHandle) {
      return
    }
    mpvSeek(this.mpvHandle, (this.playTime + Number(Setting.fastForwardSeconds) * 1000) / 1000, true)
  }

  prepare(): void {
    this.create()
  }

  play(): void {
    if (!this.mpvHandle) {
      return
    }
    this.playing = true
    mpvPlay(this.mpvHandle)
    AVSessionUtil.updatePlaybackSessionState(this.playing, this.playTime, this.repeatMode)
  }

  pause(): void {
    if (!this.mpvHandle) {
      return
    }
    this.playing = false
    mpvPause(this.mpvHandle)
    AVSessionUtil.updatePlaybackSessionState(this.playing, this.playTime, this.repeatMode)
  }

  reset(): void {
    mpvReset(this.mpvHandle)
    this.getData()
  }

  release(): void {
    if (!this.mpvHandle) {
      return
    }
    // 注销播放完成回调
    mpvUnregisterPlaybackCompleteCallback()
    this.playbackCallbackRegistered = false
    // 注销播放时间更新回调
    mpvUnregisterTimeUpdateCallback()
    this.timeUpdateCallbackRegistered = false
    // 注销视频尺寸变化回调
    mpvUnregisterVideoSizeChangedCallback()
    this.videoSizeCallbackRegistered = false
    // 注销Surface模式错误回调
    mpvUnregisterSurfaceModeErrorCallback()
    this.surfaceModeErrorCallbackRegistered = false
    mpvDestroy(this.mpvHandle)
    this.mpvHandle = null
    this.userListener?.off('timeUpdate')
  }

  seekTime(seekTime: number): void {
    if (!this.mpvHandle) {
      return
    }
    mpvSeek(this.mpvHandle, seekTime / 1000, true)
  }

  getPlayAreaWidth(): number {
    return mpvGetVideoWidth(this.mpvHandle)
  }

  getPlayAreaHeight(): number {
    return mpvGetVideoHeight(this.mpvHandle)
  }

  togglePlayback(): void {
    this.playing ? this.pause() : this.play()
  }

  updatePlaybackSpeed(speed: number) {
    mpvSetSpeed(this.mpvHandle, speed)
    this.speed = speed
  }

  getDuration(): number {
    const totalTime = mpvGetDuration(this.mpvHandle) as number
    if (totalTime === 0) {
      return this.nowPlaying!.time
    }
    if (this.nowPlaying?.time === 0 || this.nowPlaying?.time !== totalTime) {
      this.nowPlaying!.time = totalTime
      VideoOperateUtil.saveVideoTotalTime(PathUtils.appContext!, this.nowPlaying!)
    }
    return totalTime
  }

  videoStartPlayTime(seekMode: number): void {
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

  getAudioTrackList() {
    const tracks = mpvGetAudioTracks(this.mpvHandle) as MpvAudioTrack[]
    if (!tracks || tracks.length === 0) {
      setTimeout(() => {
        const retryTracks = mpvGetAudioTracks(this.mpvHandle) as MpvAudioTrack[]
        if (retryTracks && retryTracks.length > 0) {
          this.audioTrack = retryTracks
          ToolsUtil.addLogger(`重试获取音轨成功，共 ${retryTracks.length} 条音轨`, false)
        } else {
          this.audioTrack = retryTracks || []
          ToolsUtil.addLogger("重试获取音轨仍然失败，可能文件没有音轨", false)
        }
      }, 1000)
    } else {
      this.audioTrack = tracks
      ToolsUtil.addLogger(`获取音轨成功，共 ${tracks.length} 条音轨`, false)
    }
  }

  selectAudioTrack(trackId: number): void {
    mpvSelectAudio(this.mpvHandle, trackId)
  }

  setLoudnessGain(loudnessGain: number) {
    this.volumeLoudnessGain = loudnessGain
    if (this.mpvHandle) {
      mpvSetLoudnessGain(this.mpvHandle, loudnessGain)
    }
  }

  getSubtitleTrackList() {
    this.subtitleTrack = mpvGetSubtitleTracks(this.mpvHandle) as MpvSubtitleTrack[]
    if (this.subtitleTrack.length === 0) {
      this.subtitleTrackSelected = -1
      return
    }

    const currentTrackId = mpvGetCurrentSubtitleTrack(this.mpvHandle)
    const hasCurrentTrack = this.subtitleTrack.some((track) => track.id === currentTrackId)
    this.subtitleTrackSelected = hasCurrentTrack ? currentTrackId : this.subtitleTrack[0].id
  }

  selectSubtitleTrack(trackId: number): void {
    this.subtitleTrackSelected = trackId
    mpvSelectSubtitle(this.mpvHandle, trackId)
  }

  setRotation() {
    // 这里需要有个默认值，否则会视频宽高为0，导致视频无法播放
    let VideoWidth = this.getPlayAreaWidth() === 0 ? 1999 : this.getPlayAreaWidth()
    let VideoHeight = this.getPlayAreaHeight() === 0 ? 1999 : this.getPlayAreaHeight()
    const aspectRatioNow = VideoWidth / VideoHeight
    const screenAspectRatio = this.screenWidth / this.screenHeight
    if (aspectRatioNow > screenAspectRatio) {
      this.playAreaWidth = this.screenWidth
      this.playAreaHeight = this.playAreaWidth * (VideoHeight / VideoWidth)
    } else {
      this.playAreaHeight = this.screenHeight
      this.playAreaWidth = this.playAreaHeight * (VideoWidth / VideoHeight)
    }
    if (this.windowClass) {
      this.playAreaWidth > this.playAreaHeight ? WindowUtil.enableLandscapeMultiWindow(this.windowClass) :
        WindowUtil.disableLandscapeMultiWindow(this.windowClass)
      VideoInfoUtil.saveOriginalVideoWidthAndHeight(this.playAreaWidth, this.playAreaHeight)
    }
    if (this.nowPlaying?.size[0] === 0 && VideoWidth !== 0 && VideoHeight !== 1999) {
      this.nowPlaying!.size[0] = VideoWidth
      this.nowPlaying!.size[1] = VideoHeight
      VideoOperateUtil.saveVideoWeightAndHeight(PathUtils.appContext!, this.nowPlaying)
    }
    if (Setting.mpvDecodingMethod === MpvDecodingMethod.HARDWARE_SURFACE) {
      this.syncOsdSurfaceSize() // 不加这里就会变得很模糊？？？
    }
    PiPWindowUtil.updateContentSize()
  }

  setKeepAspectStatus(keepAspect: boolean) {
    mpvSetKeepAspect(this.mpvHandle, keepAspect)
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

  async initAVSession() {
    if (Setting.allowBackgroundPlay) {
      this.avSession = await AVSessionUtil.getAVSession()
      this.setSessionListener()
      await AVSessionUtil.setSessionInfo(this.nowPlaying!)
      AVSessionUtil.updatePlaybackSessionState(this.playing, this.playTime, this.repeatMode)
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
      salmonLogger.addLog(TAG, 'volumeChange error', true)
    }
    this.screenBrightness = await VideoOperateUtil.getScreenBrightness()
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

  async setExternalSubtitle(nowPlaying: VideoMetadata) {
    if (await SubtitleUtil.isSubtitleExist(PathUtils.subtitlePath!, nowPlaying.date!)) {
      try {
        let subtitle = fileIo.openSync(PathUtils.subtitlePath! + nowPlaying.date, fileIo.OpenMode.READ_ONLY)
        const success = await SubtitleUtil.parseSubtitleProcess(subtitle.path, nowPlaying.external_subtitle_format)
        if (success) {
          this.subtitleSelected = SubtitleMode.EXTERNAL_SUBTITLE
          this.subtitle = SubtitleUtil.getSubtitlesAtTime(this.playTime)
        } else {
          this.subtitleSelected = SubtitleMode.INNER_SUBTITLE
        }
      } catch (error) {
        this.subtitleSelected = SubtitleMode.INNER_SUBTITLE
      }
    } else {
      this.subtitleSelected = SubtitleMode.INNER_SUBTITLE
    }
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
    const targetOffset = SubtitleUtil.getAdjacentSubtitleOffset(this.playTime, currentOffset, direction)
    if (targetOffset === undefined) {
      ToolsUtil.showToast(direction === 'prev' ? '没有上一条字幕' : '没有下一条字幕')
      return undefined
    }
    if (Math.abs(targetOffset) > 50000) {
      ToolsUtil.showToast('目标字幕超出偏移范围：-50000 到 50000')
      return undefined
    }
    return Math.round(targetOffset)
  }

  hasInnerSubtitleTrack(): boolean {
    return this.subtitleTrack.length > 0
  }

  hasExternalSubtitle(): boolean {
    return (this.nowPlaying?.external_subtitle_format?.length ?? 0) > 0
  }

  saveSubtitlePreferenceForCurrentVideo(
    subtitleVisibility: Visibility,
    isAIAsrShown: boolean,
    subtitle3DMode: Subtitle3DMode
  ): void {
    const nowPlaying = this.nowPlaying
    const appContext = PathUtils.appContext
    if (!nowPlaying || !appContext) {
      return
    }

    const subtitleMode = SubtitleUtil.normalizeSubtitleMode(this.subtitleSelected)
    const subtitleVisible = subtitleVisibility === Visibility.Visible
    const subtitleAIAsrShown = isAIAsrShown
    const subtitle3DModeValue = SubtitleUtil.normalizeSubtitle3DMode(subtitle3DMode)
    const subtitleOffsetMillis = Math.max(-50000, Math.min(50000, Math.round(SubtitleUtil.offsetMillis)))
    const subtitleTrackId = this.subtitleTrackSelected
    const hasPreferenceChanged =
      nowPlaying.subtitle_mode !== subtitleMode ||
        nowPlaying.subtitle_visible !== subtitleVisible ||
        nowPlaying.subtitle_ai_asr_shown !== subtitleAIAsrShown ||
        nowPlaying.subtitle_3d_mode !== subtitle3DModeValue ||
        nowPlaying.subtitle_offset_millis !== subtitleOffsetMillis ||
        nowPlaying.subtitle_track_id !== subtitleTrackId

    if (!hasPreferenceChanged) {
      return
    }

    nowPlaying.subtitle_mode = subtitleMode
    nowPlaying.subtitle_visible = subtitleVisible
    nowPlaying.subtitle_ai_asr_shown = subtitleAIAsrShown
    nowPlaying.subtitle_3d_mode = subtitle3DModeValue
    nowPlaying.subtitle_offset_millis = subtitleOffsetMillis
    nowPlaying.subtitle_track_id = subtitleTrackId

    SelectFileUtil.saveData(appContext, nowPlaying, {
      subtitleMode,
      subtitleVisible,
      subtitleAIAsrShown,
      subtitle3DMode: subtitle3DModeValue,
      subtitleOffsetMillis,
      subtitleTrackId
    })
  }

  private registerTimeUpdateCallback() {
    if (this.timeUpdateCallbackRegistered) {
      return
    }
    try {
      mpvRegisterTimeUpdateCallback((timeMs: number) => {
        this.playTime = timeMs
        this.userListener?.emit('timeUpdate', this.playTime)
      })
      this.timeUpdateCallbackRegistered = true
    } catch (error) {
      salmonLogger.addLog(TAG, 'Failed to register time update callback', error)
    }
  }

  // 注册视频尺寸变化回调
  private registerVideoSizeChangedCallback() {
    if (this.videoSizeCallbackRegistered) {
      return
    }
    try {
      mpvRegisterVideoSizeChangedCallback(() => {
        salmonLogger.addLog(TAG, '[MpvController] Video size changed, syncing OSD surface size')
        // 当视频尺寸变化时，同步 OSD Surface 尺寸
        if (Setting.mpvDecodingMethod === MpvDecodingMethod.HARDWARE_SURFACE) {
          this.syncOsdSurfaceSize()
        }
      })
      this.videoSizeCallbackRegistered = true
    } catch (error) {
      salmonLogger.addLog(TAG, 'Failed to register video size changed callback', error)
    }
  }

  // 注册播放完成监听器
  private registerPlaybackCompleteListener(pathStack: NavPathStack) {
    // 避免重复注册回调
    if (this.playbackCallbackRegistered) {
      ToolsUtil.addLogger("播放完成监听器已注册，跳过重复注册", false)
      return
    }

    try {
      mpvRegisterPlaybackCompleteCallback(() => {
        ToolsUtil.addLogger("收到播放完成事件，准备播放下一个视频", false)
        this.playNextVideoProcess(pathStack)
      })
      this.playbackCallbackRegistered = true
      ToolsUtil.addLogger("播放完成监听器注册成功", false)
    } catch (error) {
      ToolsUtil.addLogger("播放完成监听器注册失败: " + JSON.stringify(error), true)
    }
  }

  // 注册Surface模式错误回调
  private registerSurfaceModeErrorCallback() {
    if (this.surfaceModeErrorCallbackRegistered) {
      return
    }
    try {
      mpvRegisterSurfaceModeErrorCallback((errorMessage: string) => {
        salmonLogger.addLog(TAG, '[MpvController] Surface mode error detected: ' + errorMessage, true)
        // 自动切换到Buffer模式
        this.switchToBufferMode(errorMessage)
      })
      this.surfaceModeErrorCallbackRegistered = true
    } catch (error) {
      salmonLogger.addLog(TAG, 'Failed to register surface mode error callback', error)
    }
  }

  // 统一的模式切换方法
  private switchDecodingMode(
    targetMode: 'buffer_hw' | 'buffer_sw',
    errorMessage: string,
    currentTime?: number,
    wasPlaying?: boolean,
    currentVideo?: VideoMetadata
  ) {
    // 防止重复切换
    if (this.isSwitchingToBufferMode || this.isSwitchingToSoftwareMode) {
      salmonLogger.addLog(TAG, '[MpvController] Already switching mode, skipping')
      return
    }

    // 设置切换标志
    if (targetMode === 'buffer_hw') {
      this.isSwitchingToBufferMode = true
    } else {
      this.isSwitchingToSoftwareMode = true
    }

    const modeName = targetMode === 'buffer_hw' ? 'Buffer硬件解码' : '软件解码'
    salmonLogger.addLog(TAG, `[MpvController] Switching to ${modeName} mode due to error: ${errorMessage}`, true)
    ToolsUtil.showToast(`正在切换到${modeName}模式...`)

    // 保存当前播放状态（如果未提供）
    const savedTime = currentTime || this.nowPlaying?.last_play || 0
    const savedPlaying = wasPlaying ?? this.playing
    const savedVideo = currentVideo ?? this.nowPlaying

    // 销毁当前MPV实例
    this.cleanupMpvInstance()

    // 设置解码模式
    if (targetMode === 'buffer_hw') {
      mpvSetDecodeType(0) // DECODE_TYPE_HW
      mpvSetHwdecMode(0) // HWDEC_MODE_BUFFER
    } else {
      mpvSetDecodeType(1) // DECODE_TYPE_SW
      mpvSetHwdecMode(0) // HWDEC_MODE_BUFFER
    }

    // 创建新的MPV实例
    this.mpvHandle = mpvCreate()
    if (!this.mpvHandle) {
      salmonLogger.addLog(TAG, `[MpvController] Failed to create MPV instance in ${modeName} mode`, true)

      // 如果是Buffer硬件解码失败，尝试切换到软件解码
      if (targetMode === 'buffer_hw') {
        this.isSwitchingToBufferMode = false
        this.switchDecodingMode('buffer_sw', 'Buffer硬件解码创建失败', savedTime, savedPlaying, savedVideo)
      } else {
        ToolsUtil.showToast('切换模式失败，请尝试其他视频')
        this.isSwitchingToSoftwareMode = false
      }
      return
    }

    // 重新加载视频
    if (savedVideo) {
      // 处理ISO文件
      let reloadUrl = savedVideo.uri;
      if (IsoFileUtil.isIsoFile(savedVideo.uri)) {
        // ISO文件：保留完整的file:// URI格式
        const isoPath = savedVideo.uri; // 保留原始URI，包含file://前缀
        mpvSetBlurayDevice(this.mpvHandle, isoPath);
        reloadUrl = 'bd://longest';
      } else {
        reloadUrl = new fileUri.FileUri(savedVideo.uri).path;
      }
      mpvLoadVideo(this.mpvHandle, reloadUrl)
      this.getData()

      // 延迟检查播放状态并恢复
      setTimeout(() => {
        this.verifyAndResumePlayback(targetMode, savedTime, savedPlaying, savedVideo, modeName)
      }, 500)
    } else {
      this.resetSwitchingFlags()
    }
  }

  // 清理MPV实例
  private cleanupMpvInstance() {
    if (this.mpvHandle) {
      try {
        mpvUnregisterPlaybackCompleteCallback()
        mpvUnregisterTimeUpdateCallback()
        mpvUnregisterVideoSizeChangedCallback()
        mpvUnregisterSurfaceModeErrorCallback()
        mpvDestroy(this.mpvHandle)
      } catch (error) {
        salmonLogger.addLog(TAG, '[MpvController] Error during cleanup: ' + JSON.stringify(error), true)
      }
      this.mpvHandle = null
    }

    // 重置回调注册标志
    this.osdVisibility = false
    this.playbackCallbackRegistered = false
    this.timeUpdateCallbackRegistered = false
    this.videoSizeCallbackRegistered = false
    this.surfaceModeErrorCallbackRegistered = false
  }

  // 验证播放状态并恢复播放
  private verifyAndResumePlayback(
    targetMode: 'buffer_hw' | 'buffer_sw',
    savedTime: number,
    savedPlaying: boolean,
    savedVideo: VideoMetadata | undefined,
    modeName: string
  ) {
    const videoWidth = this.getPlayAreaWidth()
    const videoHeight = this.getPlayAreaHeight()

    if (videoWidth === 0 || videoHeight === 0) {
      // 播放失败
      salmonLogger.addLog(TAG, `[MpvController] ${modeName} mode failed to play video`, true)

      // 如果是Buffer硬件解码失败，尝试切换到软件解码
      if (targetMode === 'buffer_hw') {
        this.resetSwitchingFlags()
        this.switchDecodingMode('buffer_sw', 'Buffer硬件解码播放失败', savedTime, savedPlaying, savedVideo)
      } else {
        ToolsUtil.showToast('播放失败，请尝试其他视频')
        this.resetSwitchingFlags()
      }
      return
    }
    if (savedTime > 0) {
      setTimeout(() => {
        this.seekTime(savedTime)
      }, 1500)
    }
    if (savedPlaying) {
      this.play()
    }

    this.resetSwitchingFlags()
    ToolsUtil.showToast(`已成功切换到${modeName}模式`)
    salmonLogger.addLog(TAG, `[MpvController] Successfully switched to ${modeName} mode`)
  }

  // 重置切换标志
  private resetSwitchingFlags() {
    this.isSwitchingToBufferMode = false
    this.isSwitchingToSoftwareMode = false
  }

  // 从Surface模式切换到Buffer模式（兼容旧接口）
  private switchToBufferMode(errorMessage: string) {
    // 检查当前是否为Surface模式
    if (Setting.mpvDecodingMethod !== MpvDecodingMethod.HARDWARE_SURFACE) {
      salmonLogger.addLog(TAG, '[MpvController] Not in surface mode, skipping switch')
      return
    }

    this.switchDecodingMode('buffer_hw', errorMessage, this.playTime)
  }
}
