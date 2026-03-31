import { PlayerControllerInterface } from '../PlayerControllerFactory';
import {
  create as mpvCreate,
  destroy as mpvDestroy,
  getAudioTracks as mpvGetAudioTracks,
  getCurrentPosition as mpvGetCurrentPosition,
  getDuration as mpvGetDuration,
  getSubtitleTracks as mpvGetSubtitleTracks,
  getVideoHeight as mpvGetVideoHeight,
  getVideoWidth as mpvGetVideoWidth,
  loadVideo as mpvLoadVideo,
  pause as mpvPause,
  play as mpvPlay,
  reset as mpvReset,
  seek as mpvSeek,
  selectAudio as mpvSelectAudio,
  selectSubtitle as mpvSelectSubtitle,
  setDecodeType as mpvSetDecodeType,
  setKeepAspect as mpvSetKeepAspect,
  setSpeed as mpvSetSpeed,
  setHwdecMode as mpvSetHwdecMode,
} from 'libmpvnative.so';
import { Setting } from '../../utils/ObservedUtil';
import { VideoStartTimeMode } from '../../common/enum/VideoStartTimeMode';
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface';
import { SubtitleMode } from '../../common/enum/SubtitleMode';
import { PathUtils } from '../../utils/PathUtils';
import VideoOperateUtil from '../../utils/VideoOperateUtil';
import { MpvAudioTrack, MpvDecodingMethod, MpvSubtitleTrack } from './MpvTypes';
import { avSession, avSession as avSessionManager } from '@kit.AVSessionKit';
import { audio } from '@kit.AudioKit';
import { WindowUtil } from '../../utils/WindowUtil';
import { window } from '@kit.ArkUI';
import VideoInfoUtil from '../../utils/VideoInfoUtil';
import ToolsUtil from '../../utils/ToolsUtil';
import { RepeatMode } from '../../common/enum/RepeatMode';
import AVSessionUtil from '../../utils/AVSessionUtil';
import { LEFT_ZONE_DIVISION, RIGHT_ZONE_DIVISION, SCREEN_DIVISIONS } from '../../common/Constants';
import { fileIo as fs, fileUri } from '@kit.CoreFileKit';
import { salmonLogger } from 'salmonlogger';
import PrivacySpaceUtil from '../../utils/PrivacySpaceUtil';
import RecentPlayUtil from '../../utils/RecentPlayUtil';
import SelectFileUtil from '../../utils/SelectFileUtil';
import SubtitleUtil from '../../utils/SubtitleUtil';

const TAG = 'MpvController'

@Observed
export class MpvController implements PlayerControllerInterface {
  windowClass = WindowUtil.getWindow()
  @Track mpvHandle: number | null = null
  surfaceId: string | null = null
  @Track playTime: number = 0
  @Track playing: boolean = false
  @Track nowPlaying: VideoMetadata | undefined = undefined
  @Track videoMetaDataList: VideoMetadata[] = []
  @Track speed: number = 1.0
  @Track volume: number = 0
  @Track volumeActually: number = 0
  @Track audioTrack: MpvAudioTrack[] = []
  @Track subtitleTrack: MpvSubtitleTrack[] = []
  @Track screenBrightness: number = 0
  @Track onSwipingVoice: boolean = false
  @Track subtitleSelected: SubtitleMode = SubtitleMode.INNER_SUBTITLE
  @Track screenWidth: number = 0
  @Track screenHeight: number = 0
  @Track playAreaHeight: number = 0
  @Track playAreaWidth: number = 0
  @Track angle: number = 0
  @Track repeatMode: RepeatMode = RepeatMode.LIST
  @Track selectedText: string | undefined = '原始比例'
  @Track onSwiping: boolean = false
  @Track onSwipingBrightness: boolean = false
  @Track isSliderPlayTimeChange: boolean = false
  @Track audioTrackSelected: number = 0
  @Track pipOpenState: boolean = false
  @Track lockVisibility: boolean = false
  @Track longPress: boolean = false
  @Track isLock: boolean = false
  @Track abCircleStatus: boolean = false
  avSession: avSessionManager.AVSession | undefined = undefined
  audioVolumeManager: audio.AudioVolumeManager | null = null
  private playTimeUpdateTag: number | null = null

  async playChooseVideo(item: VideoMetadata) {
    ToolsUtil.addLogger("开始播放选择的视频", false)
    VideoOperateUtil.saveVideoTime(this.playTime, this.nowPlaying!, this.videoMetaDataList, PathUtils.appContext!)
    if (!PrivacySpaceUtil.getPrivacyMode()) {
      RecentPlayUtil.addPlayback(PathUtils.appContext!, item)
      ToolsUtil.addLogger("添加到最近播放记录完成", false)
    }
    this.reset()
    this.onSwiping = false
    this.isSliderPlayTimeChange = false
    this.nowPlaying = item as VideoMetadata
    ToolsUtil.addLogger("设置当前播放视频完成", false)
    this.init(item.uri)
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
      this.playChooseVideo(nextItem)
    } else {
      ToolsUtil.addLogger("无下一个视频，播放结束", false, pathStack)
      ToolsUtil.showToast('播放完毕，已自动退出')
      pathStack.pop()
    }
    ToolsUtil.addLogger("播放下一个视频前置流程完成", false, pathStack)
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

  create(): void {
    if (this.mpvHandle) {
      console.error('[MpvPlayer] MPV already created, skipping')
      return
    }
    try {
      this.mpvHandle = mpvCreate()
      if (!this.mpvHandle) {
        console.error('[MpvPlayer] Failed to create mpv instance - handle is null/undefined')
      } else {
        console.error('[MpvPlayer] MPV instance created:', this.mpvHandle)
        switch (Setting.mpvDecodingMethod) {
          case MpvDecodingMethod.HARDWARE_BUFFER:
            mpvSetDecodeType(0)
            mpvSetHwdecMode(0)
            break
          case MpvDecodingMethod.SOFTWARE:
            mpvSetDecodeType(1)
            break
          case MpvDecodingMethod.HARDWARE_SURFACE:
            mpvSetDecodeType(0)
            mpvSetHwdecMode(1)
            break
          default:
            mpvSetDecodeType(1)
        }
      }
    } catch {
      console.error('[MpvPlayer] Exception during create')
      ToolsUtil.showToast("MPV 创建失败")
    }
  }

  init(url?: string, startPosition?: number): void {
    // 传递起始位置给 native（参考 mpv-android）
    if (startPosition !== undefined && startPosition > 0) {
      mpvLoadVideo(this.mpvHandle, url, startPosition)
    } else {
      mpvLoadVideo(this.mpvHandle, new fileUri.FileUri(url!).path)
    }
    this.getData()
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
      // 获取信息需要有延迟，否则为空
      this.getAudioTrackList()
      this.getSubtitleTrackList()
      this.videoStartPlayTime(VideoOperateUtil.getVideoStartPlayTimeMode(this.nowPlaying!))
      this.nowPlaying!.time = this.getDuration()
      this.setRotation()
      await this.setExternalSubtitle(this.nowPlaying!)
    }, 500) // 减少延迟到 300ms
  }

  getData() {
    // 立即设置播放状态和启动定时器
    this.playing = true
    // 立即启动定时器，不延迟
    this.playTimeUpdateTag = setInterval(() => {
      this.playTime = mpvGetCurrentPosition(this.mpvHandle)
    }, 1000);
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
  }

  pause(): void {
    if (!this.mpvHandle) {
      return
    }
    this.playing = false
    mpvPause(this.mpvHandle)
  }

  reset(): void {
    clearInterval(this.playTimeUpdateTag)
    mpvReset(this.mpvHandle)
    this.getData()
  }

  release(): void {
    if (!this.mpvHandle) {
      return
    }
    mpvDestroy(this.mpvHandle)
    clearInterval(this.playTimeUpdateTag)
    this.mpvHandle = null
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
    this.audioTrack = mpvGetAudioTracks(this.mpvHandle) as MpvAudioTrack[];
  }

  selectAudioTrack(trackId: number): void {
    mpvSelectAudio(this.mpvHandle, trackId)
  }

  getSubtitleTrackList() {
    this.subtitleTrack = mpvGetSubtitleTracks(this.mpvHandle) as MpvSubtitleTrack[]
  }

  selectSubtitleTrack(trackId: number): void {
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

  async setExternalSubtitle(now_playing: VideoMetadata) {
    if (await SubtitleUtil.isSubtitleExist(PathUtils.subtitlePath!, now_playing.date!)) {
      try {
        let subtitle = fs.openSync(PathUtils.subtitlePath! + now_playing.date, fs.OpenMode.READ_ONLY)
        await SubtitleUtil.parseSubtitleProcess(subtitle.path, now_playing.external_subtitle_format) ?
          this.subtitleSelected = SubtitleMode.EXTERNAL_SUBTITLE : this.subtitleSelected = SubtitleMode.INNER_SUBTITLE
      } catch (error) {
        this.subtitleSelected = SubtitleMode.INNER_SUBTITLE
      }
    } else {
      this.subtitleSelected = SubtitleMode.INNER_SUBTITLE
    }
  }
}