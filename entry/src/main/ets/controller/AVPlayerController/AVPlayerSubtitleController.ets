import { NetworkPlayback } from '../../utils/NetworkPlayback'
import { media } from '@kit.MediaKit'
import { SubtitleTrack } from '../../interfaces/AudioTrackInterface'
import ToolsUtil from '../../utils/ToolsUtil'
import { Subtitle3DMode, SubtitleMode } from '../../common/enum/SubtitleMode'
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import { PlayerControllerInterface, SubtitleControllerInterface } from '../PlayerControllerFactory'
import { salmonLogger } from 'salmonlogger'
import AVSessionUtil from '../../utils/AVSessionUtil'
import { Setting } from '../../utils/ObservedUtil'
import { PathUtils } from '../../utils/PathUtils'
import SubtitleUtil from '../../utils/SubtitleUtil'
import VideoOperateUtil from '../../utils/VideoOperateUtil'
import { fileIo } from '@kit.CoreFileKit'
import { NativeAVPlayer } from '../engine/NativeAVPlayer'
import SubtitleLanguageUtil from '../../utils/SubtitleLanguageUtil'
import MediaLibraryService from '../../utils/MediaLibraryService'

const TAG = 'AVPlayerSubtitleController'

export class AVPlayerSubtitleController implements SubtitleControllerInterface {
  private lastSubtitle: string = ''
  private externalSubtitleAvailable: boolean = false
  private clearSubtitleTimer: number | null = null

  private state: PlayerControllerInterface
  private getPlayer: () => NativeAVPlayer | undefined
  private getGeneration: () => number

  constructor(state: PlayerControllerInterface, getPlayer: () => NativeAVPlayer | undefined,
    getGeneration: () => number) {
    this.state = state
    this.getPlayer = getPlayer
    this.getGeneration = getGeneration
  }

  clear(player?: NativeAVPlayer): void {
    if (this.clearSubtitleTimer !== null) {
      clearTimeout(this.clearSubtitleTimer)
      this.clearSubtitleTimer = null
    }
    this.lastSubtitle = ''
    this.externalSubtitleAvailable = false
    player?.off('subtitleUpdate')
  }

  updatePlaybackTime(time: number): void {
    if (this.state.subtitleSelected === SubtitleMode.EXTERNAL_SUBTITLE) {
      const text = SubtitleUtil.getSubtitlesAtTime(time)
      if (text !== this.lastSubtitle) {
        this.lastSubtitle = text
        this.state.subtitle = text
      }
    }
  }

  registerSubtitleListener() {
    const player = this.getPlayer()
    const generation = this.getGeneration()
    player?.on('subtitleUpdate', async (info: media.SubtitleInfo) => {
      if (player !== this.getPlayer() || generation !== this.getGeneration()) { return }
      if (this.clearSubtitleTimer !== null) {
        clearTimeout(this.clearSubtitleTimer)
        this.clearSubtitleTimer = null
      }
      if (this.state.subtitleSelected === SubtitleMode.INNER_SUBTITLE) {
        if (info) {
          const text = (info.text ?? '')
            .replace(/\\[Nn]/g, '\n')
            .replace(/\{[^}]*\}/g, '')
            .replace(/<[^>]*>/g, '')
          const duration = info.duration ?? 0
          this.state.subtitle = text
          if (duration > 0) {
            this.clearSubtitleTimer = setTimeout(() => {
              if (player === this.getPlayer() && generation === this.getGeneration()) {
                this.state.subtitle = ''
              }
            }, duration) as number
          }
        } else {
          this.state.subtitle = ''
        }
      }
    })
  }

  async setExternalSubtitle(nowPlaying: VideoMetadata): Promise<void> {
    const version = this.getGeneration()
    try {
      await NetworkPlayback.cacheSubtitle(nowPlaying)
    } catch (_error) {
      ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.shared_subtitle_read_failed').id))
    }
    if (this.state.nowPlaying?.uri !== nowPlaying.uri || version !== this.getGeneration()) {
      return
    }
    this.externalSubtitleAvailable = false
    SubtitleUtil.offsetMillis = nowPlaying.subtitle_offset_millis ?? 0
    await SubtitleUtil.isSubtitleExist(PathUtils.subtitlePath!, nowPlaying.date!).then(async (exists): Promise<void> => {
      if (this.state.nowPlaying?.uri !== nowPlaying.uri || version !== this.getGeneration()) {
        return
      }
      if (!exists) {
        this.externalSubtitleAvailable = false
        this.applySubtitlePreference(nowPlaying, false)
        return
      }
      try {
        let subtitle = fileIo.openSync(PathUtils.subtitlePath! + nowPlaying.date, fileIo.OpenMode.READ_ONLY)
        await SubtitleUtil.parseSubtitleProcess(subtitle.path, nowPlaying.external_subtitle_format,
          (): boolean => this.state.nowPlaying?.uri !== nowPlaying.uri || version !== this.getGeneration()).then(success => {
            try {
              fileIo.closeSync(subtitle)
            } catch (_e) {
            }
            if (this.state.nowPlaying?.uri !== nowPlaying.uri || version !== this.getGeneration()) {
              return
            }
            if (success) {
              this.externalSubtitleAvailable = true
              this.state.subtitle = SubtitleUtil.getSubtitlesAtTime(this.state.playTime)
              this.applySubtitlePreference(nowPlaying, true)
            } else {
              this.externalSubtitleAvailable = false
              this.applySubtitlePreference(nowPlaying, false)
            }
          }).catch(() => {
            try {
              fileIo.closeSync(subtitle)
            } catch (_e) {
            }
            if (this.state.nowPlaying?.uri !== nowPlaying.uri || version !== this.getGeneration()) { return }
            this.externalSubtitleAvailable = false
            this.applySubtitlePreference(nowPlaying, false)
          })
      } catch (_error) {
        if (this.state.nowPlaying?.uri !== nowPlaying.uri || version !== this.getGeneration()) { return }
        this.externalSubtitleAvailable = false
        this.applySubtitlePreference(nowPlaying, false)
      }
    })
  }

  async getSubtitleTrackList() {
    const player = this.getPlayer()
    const generation = this.getGeneration()
    const tracks = await VideoOperateUtil.getInnerSubtitles(player!)
    if (player !== this.getPlayer() || generation !== this.getGeneration()) { return }
    this.state.subtitleTrack = tracks
    this.state.subtitleTrackSelected = SubtitleLanguageUtil.selectPreferredTrack(
      this.state.subtitleTrack, Setting.subtitlePreferredLanguage)?.id ?? -1
    if (this.state.nowPlaying) {
      this.applySubtitlePreference(this.state.nowPlaying, this.externalSubtitleAvailable)
    }
  }

  selectSubtitleTrack(index: number): void {
    this.state.subtitleTrackSelected = index
    this.getPlayer()?.selectTrack(index)?.catch(() => {
      salmonLogger.addLog(TAG, 'selectTrack error', true)
    })
    AVSessionUtil.updatePlaybackSessionState(this.state.playing, this.state.playTime, this.state.repeatMode, this.state.speed)
  }

  selectExternalSubtitleTrack(): void {
    // AVPlayer external subtitles continue to be rendered by ArkUI.
  }

  selectSecondarySubtitleTrack(_trackId: number): void {
    this.state.secondarySubtitleTrackSelected = -1
  }

  setSubtitleOffset(offsetMillis: number): void {
    if (this.state.subtitleSelected !== SubtitleMode.EXTERNAL_SUBTITLE) {
      return
    }
    this.state.subtitle = SubtitleUtil.getSubtitlesAtTime(this.state.playTime, offsetMillis)
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
    if (this.state.subtitleSelected !== SubtitleMode.EXTERNAL_SUBTITLE) {
      return
    }
    if (subtitleVisibility !== Visibility.Visible) {
      return
    }
    this.state.subtitle = SubtitleUtil.getSubtitlesAtTime(this.state.playTime)
  }

  private applySubtitlePreference(nowPlaying: VideoMetadata, externalSubtitleLoaded: boolean) {
    const hasPreference = SubtitleUtil.hasSubtitlePreferenceMetadata(nowPlaying)
    if (hasPreference) {
      const preferredMode = nowPlaying.subtitle_mode as SubtitleMode | undefined
      if (preferredMode === SubtitleMode.EXTERNAL_SUBTITLE && !externalSubtitleLoaded) {
        this.state.subtitleSelected = SubtitleMode.NONE
        this.resetSubtitlePreference(nowPlaying)
        SubtitleUtil.offsetMillis = 0
      } else if (preferredMode !== undefined && preferredMode >= SubtitleMode.NONE) {
        if (nowPlaying.subtitle_offset_millis !== undefined) {
          SubtitleUtil.offsetMillis = nowPlaying.subtitle_offset_millis
        }
        this.state.subtitleSelected = preferredMode
      } else {
        this.state.subtitleSelected = SubtitleMode.NONE
      }
    } else {
      if (externalSubtitleLoaded) {
        this.state.subtitleSelected = SubtitleMode.EXTERNAL_SUBTITLE
      } else if (this.state.subtitleTrackSelected >= 0) {
        this.state.subtitleSelected = SubtitleMode.INNER_SUBTITLE
        this.selectSubtitleTrack(this.state.subtitleTrackSelected)
      } else {
        this.state.subtitleSelected = SubtitleMode.NONE
      }
    }
  }

  private resetSubtitlePreference(nowPlaying: VideoMetadata): void {
    nowPlaying.subtitle_mode = SubtitleMode.NONE
    nowPlaying.subtitle_visible = false
    nowPlaying.subtitle_ai_asr_shown = false
    nowPlaying.subtitle_3d_mode = Subtitle3DMode.DISABLED
    nowPlaying.subtitle_offset_millis = 0
    nowPlaying.subtitle_track_id = -1
    MediaLibraryService.saveData(PathUtils.appContext!, nowPlaying, {
      subtitleMode: SubtitleMode.NONE,
      subtitleVisible: false,
      subtitleAIAsrShown: false,
      subtitle3DMode: Subtitle3DMode.DISABLED,
      subtitleOffsetMillis: 0,
      subtitleTrackId: -1
    })
  }

  restoreInnerSubtitlePreference(nowPlaying: VideoMetadata): void {
    if (this.state.subtitleSelected !== SubtitleMode.INNER_SUBTITLE) {
      return
    }
    if (this.state.subtitleTrack.length === 0) {
      this.state.subtitleSelected = SubtitleMode.NONE
      return
    }
    if (nowPlaying.subtitle_track_id !== undefined && nowPlaying.subtitle_track_id >= 0) {
      const savedTrackExists =
        this.state.subtitleTrack.some((track: SubtitleTrack) => track.id === nowPlaying.subtitle_track_id)
      if (savedTrackExists) {
        this.state.subtitleTrackSelected = nowPlaying.subtitle_track_id
      }
    }
    this.selectSubtitleTrack(this.state.subtitleTrackSelected)
  }
}
