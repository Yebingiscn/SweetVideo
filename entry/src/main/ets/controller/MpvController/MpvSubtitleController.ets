import { SubtitleControllerInterface } from '../PlayerControllerFactory'
import { fileIo } from '@kit.CoreFileKit'
import { salmonLogger } from 'salmonlogger'
import {
  getSubtitleTracks as mpvGetSubtitleTracks,
  getCurrentSubtitleTrack as mpvGetCurrentSubtitleTrack,
  getCurrentSecondarySubtitleTrack as mpvGetCurrentSecondarySubtitleTrack,
  getSubtitleTexts as mpvGetSubtitleTexts,
  loadExternalSubtitle as mpvLoadExternalSubtitle,
  selectSubtitle as mpvSelectSubtitle,
  selectSecondarySubtitle as mpvSelectSecondarySubtitle,
  setSubtitleDelay as mpvSetSubtitleDelay,
  setSubtitleStyle as mpvSetSubtitleStyle,
  setSubtitleRenderVisibility as mpvSetSubtitleRenderVisibility
} from 'libmpvnative.so'
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import { Subtitle3DMode, SubtitleMode } from '../../common/enum/SubtitleMode'
import { SweetRepeatMode } from '../../common/enum/SweetRepeatMode'
import { MpvSubtitleTrack, MpvSubtitleTexts } from './MpvTypes'
import { NetworkPlayback } from '../../utils/NetworkPlayback'
import { PathUtils } from '../../utils/PathUtils'
import { Setting } from '../../utils/ObservedUtil'
import ToolsUtil from '../../utils/ToolsUtil'
import SelectFileUtil from '../../utils/SelectFileUtil'
import SubtitleUtil from '../../utils/SubtitleUtil'
import SubtitleStyleUtil from '../../utils/SubtitleStyleUtil'
import SubtitleLanguageUtil from '../../utils/SubtitleLanguageUtil'
import AVSessionUtil from '../../utils/AVSessionUtil'

const TAG = 'MpvController'

// 响应式字段仍属于主控制器；此模块只管理字幕轨道、样式与原生渲染。
export interface MpvSubtitleState {
  nowPlaying: VideoMetadata | undefined
  subtitleTrack: MpvSubtitleTrack[]
  subtitleTrackSelected: number
  secondarySubtitleTrackSelected: number
  subtitleSelected: SubtitleMode
  subtitle: string
  subtitlePosition: number
  subtitleSize: number
  playAreaHeight: number
  playing: boolean
  playTime: number
  repeatMode: SweetRepeatMode
  speed: number
  refreshExternalSubtitlePreview(offset: number): void
}

export class MpvSubtitleController implements SubtitleControllerInterface {
  private externalSubtitleTrackSelected: number = -1
  private externalSubtitleCodec: string = ''
  private lastSubtitle: string = ''
  private mpvSubtitle3DMode: Subtitle3DMode = Subtitle3DMode.DISABLED

  private state: MpvSubtitleState
  private getHandle: () => number | null
  private getGeneration: () => number
  private isMediaLoaded: () => boolean

  constructor(state: MpvSubtitleState, getHandle: () => number | null,
    getGeneration: () => number, isMediaLoaded: () => boolean) {
    this.state = state
    this.getHandle = getHandle
    this.getGeneration = getGeneration
    this.isMediaLoaded = isMediaLoaded
  }

  is3DActive(): boolean {
    return this.mpvSubtitle3DMode !== Subtitle3DMode.DISABLED
  }

  reset(): void {
    this.mpvSubtitle3DMode = Subtitle3DMode.DISABLED
    this.state.subtitle = ''
    this.lastSubtitle = ''
  }

  async getSubtitleTrackList(): Promise<void> {
    const allSubtitleTracks = mpvGetSubtitleTracks(this.getHandle()) as MpvSubtitleTrack[]
    const externalTracks = allSubtitleTracks.filter((track: MpvSubtitleTrack) => track.external)
    if (externalTracks.length > 0) {
      const selectedExternalTrack = externalTracks.find((track: MpvSubtitleTrack) =>
      track.id === this.externalSubtitleTrackSelected) ?? externalTracks[externalTracks.length - 1]
      this.externalSubtitleTrackSelected = selectedExternalTrack.id
      this.externalSubtitleCodec = selectedExternalTrack.codec ?? ''
    } else {
      this.externalSubtitleTrackSelected = -1
      this.externalSubtitleCodec = ''
    }
    this.state.subtitleTrack = allSubtitleTracks.filter((track: MpvSubtitleTrack) => !track.external)
    if (this.state.subtitleTrack.length === 0) {
      this.state.subtitleTrackSelected = -1
      this.state.secondarySubtitleTrackSelected = -1
      return
    }

    const previousTrackId = this.state.subtitleTrackSelected
    const currentTrackId = mpvGetCurrentSubtitleTrack(this.getHandle())
    const hasCurrentTrack = this.state.subtitleTrack.some((track) => track.id === currentTrackId)
    const hasPreviousTrack = this.state.subtitleTrack.some((track) => track.id === previousTrackId)
    const preferredTrackId = SubtitleLanguageUtil.selectPreferredTrack(
      this.state.subtitleTrack, Setting.subtitlePreferredLanguage)?.id ?? this.state.subtitleTrack[0].id
    const hasSavedPreference = this.state.nowPlaying ? SubtitleUtil.hasSubtitlePreferenceMetadata(this.state.nowPlaying) : false
    this.state.subtitleTrackSelected = hasSavedPreference && hasCurrentTrack ? currentTrackId :
      (hasSavedPreference && hasPreviousTrack ? previousTrackId : preferredTrackId)
    const currentSecondaryTrackId = mpvGetCurrentSecondarySubtitleTrack(this.getHandle())
    const hasCurrentSecondaryTrack = this.state.subtitleTrack.some((track) =>
    track.id === currentSecondaryTrackId && track.id !== this.state.subtitleTrackSelected)
    this.state.secondarySubtitleTrackSelected = hasCurrentSecondaryTrack ? currentSecondaryTrackId : -1
    if (currentSecondaryTrackId >= 0 && !hasCurrentSecondaryTrack) {
      mpvSelectSecondarySubtitle(this.getHandle(), -1)
    }
  }

  selectSubtitleTrack(trackId: number): void {
    if (trackId >= 0 && trackId === this.state.secondarySubtitleTrackSelected) {
      this.selectSecondarySubtitleTrack(-1)
    }
    this.state.subtitleTrackSelected = trackId
    mpvSelectSubtitle(this.getHandle(), trackId)
    this.applySubtitleStyle()
    this.updateMpvSubtitlePresentation()
    AVSessionUtil.updatePlaybackSessionState(this.state.playing, this.state.playTime, this.state.repeatMode, this.state.speed)
  }

  selectExternalSubtitleTrack(): void {
    this.selectSecondarySubtitleTrack(-1)
    mpvSelectSubtitle(this.getHandle(), this.externalSubtitleTrackSelected)
    this.applySubtitleStyle()
    this.updateMpvSubtitlePresentation()
    AVSessionUtil.updatePlaybackSessionState(this.state.playing, this.state.playTime, this.state.repeatMode, this.state.speed)
  }

  selectSecondarySubtitleTrack(trackId: number): void {
    if (trackId >= 0 && trackId === this.state.subtitleTrackSelected) {
      return
    }
    this.state.secondarySubtitleTrackSelected = trackId
    mpvSelectSecondarySubtitle(this.getHandle(), trackId)
    this.applySubtitleStyle()
    this.updateMpvSubtitlePresentation()
    AVSessionUtil.updatePlaybackSessionState(this.state.playing, this.state.playTime, this.state.repeatMode, this.state.speed)
  }

  async setExternalSubtitle(nowPlaying: VideoMetadata): Promise<void> {
    const generation = this.getGeneration()
    try { await NetworkPlayback.cacheSubtitle(nowPlaying) } catch (_error) {
      ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.shared_subtitle_read_failed').id))
    }
    if (this.state.nowPlaying?.uri !== nowPlaying.uri || generation !== this.getGeneration()) return
    SubtitleUtil.offsetMillis = nowPlaying.subtitle_offset_millis ?? 0
    const existingExternalTracks = (mpvGetSubtitleTracks(this.getHandle()) as MpvSubtitleTrack[])
      .filter((track: MpvSubtitleTrack) => track.external)
    let externalSubtitleLoaded = existingExternalTracks.length > 0
    const existingExternalTrack = existingExternalTracks[existingExternalTracks.length - 1]
    this.externalSubtitleTrackSelected = existingExternalTrack?.id ?? -1
    this.externalSubtitleCodec = existingExternalTrack?.codec ?? ''
    this.state.subtitle = ''
    this.lastSubtitle = ''
    const subtitleExists = await SubtitleUtil.isSubtitleExist(PathUtils.subtitlePath!, nowPlaying.date!)
    if (generation !== this.getGeneration() || !this.isMediaLoaded()) {
      return
    }
    if (subtitleExists) {
      try {
        const existingExternalTrackIds = (mpvGetSubtitleTracks(this.getHandle()) as MpvSubtitleTrack[])
          .filter((track: MpvSubtitleTrack) => track.external)
          .map((track: MpvSubtitleTrack) => track.id)
        let subtitle = fileIo.openSync(PathUtils.subtitlePath! + nowPlaying.date, fileIo.OpenMode.READ_ONLY)
        externalSubtitleLoaded = mpvLoadExternalSubtitle(this.getHandle(), {
          path: subtitle.path,
          lang: 'unknown',
          select: false
        })
        try {
          fileIo.closeSync(subtitle)
        } catch (_e) {
        }
        if (externalSubtitleLoaded) {
          const updatedTracks = mpvGetSubtitleTracks(this.getHandle()) as MpvSubtitleTrack[]
          const addedTrack = updatedTracks.filter((track: MpvSubtitleTrack) => track.external &&
            !existingExternalTrackIds.includes(track.id)).pop()
          if (addedTrack) {
            this.externalSubtitleTrackSelected = addedTrack.id
            this.externalSubtitleCodec = addedTrack.codec ?? ''
          }
          await this.getSubtitleTrackList()
        }
      } catch (error) {
        salmonLogger.addLog(TAG, `[Subtitle] External subtitle load failed: ${error}`, true)
      }
    }
    salmonLogger.addLog(TAG,
      `[Subtitle] exists=${subtitleExists}, loaded=${externalSubtitleLoaded}, track=${this.externalSubtitleTrackSelected}`,
      subtitleExists && !externalSubtitleLoaded)

    const hasPreference = SubtitleUtil.hasSubtitlePreferenceMetadata(nowPlaying)
    if (hasPreference) {
      const preferredMode = nowPlaying.subtitle_mode as SubtitleMode | undefined
      if (preferredMode === SubtitleMode.EXTERNAL_SUBTITLE && !externalSubtitleLoaded) {
        this.state.subtitleSelected = SubtitleMode.NONE
        this.resetSubtitlePreference(nowPlaying)
        SubtitleUtil.offsetMillis = 0

      } else if (preferredMode !== undefined && preferredMode >= SubtitleMode.NONE) {
        if (preferredMode === SubtitleMode.INNER_SUBTITLE && this.state.subtitleTrack.length === 0) {
          this.state.subtitleSelected = SubtitleMode.NONE
        } else {
          if (preferredMode === SubtitleMode.INNER_SUBTITLE && nowPlaying.subtitle_track_id !== undefined &&
            this.state.subtitleTrack.some((track: MpvSubtitleTrack) => track.id === nowPlaying.subtitle_track_id)) {
            this.state.subtitleTrackSelected = nowPlaying.subtitle_track_id
            if (mpvGetCurrentSubtitleTrack(this.getHandle()) !== nowPlaying.subtitle_track_id) {
              mpvSelectSubtitle(this.getHandle(), nowPlaying.subtitle_track_id)
            }
          }
          if (nowPlaying.subtitle_offset_millis !== undefined) {
            SubtitleUtil.offsetMillis = nowPlaying.subtitle_offset_millis
          }
          this.state.subtitleSelected = preferredMode
        }
      } else {
        this.state.subtitleSelected = SubtitleMode.NONE
      }
    } else {
      if (externalSubtitleLoaded && this.externalSubtitleTrackSelected >= 0) {
        this.state.subtitleSelected = SubtitleMode.EXTERNAL_SUBTITLE
      } else if (this.state.subtitleTrackSelected >= 0) {
        this.state.subtitleSelected = SubtitleMode.INNER_SUBTITLE
      } else {
        this.state.subtitleSelected = SubtitleMode.NONE
      }
    }
    if (this.state.subtitleSelected === SubtitleMode.EXTERNAL_SUBTITLE) {
      this.selectExternalSubtitleTrack()
    } else if (this.state.subtitleSelected === SubtitleMode.INNER_SUBTITLE && this.state.subtitleTrackSelected >= 0) {
      this.selectSubtitleTrack(this.state.subtitleTrackSelected)
    } else {
      mpvSelectSubtitle(this.getHandle(), -1)
      this.selectSecondarySubtitleTrack(-1)
    }
    this.setSubtitleOffset(SubtitleUtil.offsetMillis)
    this.applySubtitleStyle()
    const saved3DMode = nowPlaying.subtitle_3d_mode
    this.setSubtitle3DMode(saved3DMode !== undefined &&
      [Subtitle3DMode.DISABLED, Subtitle3DMode.SIDE_BY_SIDE, Subtitle3DMode.TOP_AND_BOTTOM].includes(saved3DMode) ?
      saved3DMode as Subtitle3DMode : Subtitle3DMode.DISABLED)
    salmonLogger.addLog(TAG, `[Subtitle] mode=${this.state.subtitleSelected}, externalTrack=${this.externalSubtitleTrackSelected}`)
  }

  setSubtitleOffset(offsetMillis: number): void {
    const clampedOffset = Math.max(-50000, Math.min(50000, Math.round(offsetMillis)))
    if (this.getHandle()) {
      mpvSetSubtitleDelay(this.getHandle(), clampedOffset)
    }
    this.state.refreshExternalSubtitlePreview(clampedOffset)
  }

  setSubtitle3DMode(mode: Subtitle3DMode): void {
    const canUseMpv3D = mode !== Subtitle3DMode.DISABLED &&
      this.state.subtitleSelected === SubtitleMode.INNER_SUBTITLE && this.supportsSubtitle3D()
    this.mpvSubtitle3DMode = canUseMpv3D ? mode : Subtitle3DMode.DISABLED
    this.updateMpvSubtitlePresentation()
  }

  supportsSubtitle3D(): boolean {
    if (this.state.subtitleSelected === SubtitleMode.EXTERNAL_SUBTITLE) {
      return true
    }
    const primaryTrack = this.state.subtitleTrack.find((track: MpvSubtitleTrack) =>
    track.id === this.state.subtitleTrackSelected)
    if (!primaryTrack || this.isBitmapSubtitleTrack(primaryTrack)) {
      return false
    }
    if (this.state.secondarySubtitleTrackSelected >= 0) {
      const secondaryTrack = this.state.subtitleTrack.find((track: MpvSubtitleTrack) =>
      track.id === this.state.secondarySubtitleTrackSelected)
      return secondaryTrack !== undefined && !this.isBitmapSubtitleTrack(secondaryTrack)
    }
    return true
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

  applySubtitleStyle(): void {
    if (!this.getHandle()) {
      return
    }
    mpvSetSubtitleStyle(this.getHandle(),
      SubtitleStyleUtil.getMpvStyle(this.state.subtitlePosition, this.state.subtitleSize, this.state.playAreaHeight,
        this.shouldPreserveCurrentAssStyle(), this.shouldPreserveSecondaryAssStyle()))
  }

  private updateMpvSubtitlePresentation(): void {
    if (!this.getHandle()) {
      return
    }
    const useArkUi3D = this.mpvSubtitle3DMode !== Subtitle3DMode.DISABLED &&
      this.state.subtitleSelected === SubtitleMode.INNER_SUBTITLE && this.supportsSubtitle3D()
    if (useArkUi3D) {
      mpvSetSubtitleRenderVisibility(this.getHandle(), false, false)
      this.refreshMpv3DSubtitleText()
      return
    }

    if (this.mpvSubtitle3DMode !== Subtitle3DMode.DISABLED && !this.supportsSubtitle3D()) {
      this.mpvSubtitle3DMode = Subtitle3DMode.DISABLED
    }
    const showMpvSubtitle = (this.state.subtitleSelected === SubtitleMode.INNER_SUBTITLE &&
      this.state.subtitleTrackSelected >= 0) || (this.state.subtitleSelected === SubtitleMode.EXTERNAL_SUBTITLE &&
      this.externalSubtitleTrackSelected >= 0)
    mpvSetSubtitleRenderVisibility(this.getHandle(), showMpvSubtitle,
      showMpvSubtitle && this.state.secondarySubtitleTrackSelected >= 0)
    if (this.state.subtitleSelected === SubtitleMode.INNER_SUBTITLE ||
      this.state.subtitleSelected === SubtitleMode.EXTERNAL_SUBTITLE) {
      this.state.subtitle = ''
      this.lastSubtitle = ''
    }
  }

  private shouldPreserveCurrentAssStyle(): boolean {
    if (this.state.subtitleSelected === SubtitleMode.EXTERNAL_SUBTITLE) {
      return this.isAssCodec(this.externalSubtitleCodec) ||
        this.isAssCodec(this.state.nowPlaying?.external_subtitle_format ?? '')
    }
    if (this.state.subtitleSelected !== SubtitleMode.INNER_SUBTITLE) {
      return false
    }
    const selectedTrack = this.state.subtitleTrack.find((track: MpvSubtitleTrack) =>
    track.id === this.state.subtitleTrackSelected)
    return this.isAssCodec(selectedTrack?.codec ?? '')
  }

  private isAssCodec(codec: string): boolean {
    const normalizedCodec = codec.trim().toLowerCase().replace('.', '')
    return normalizedCodec === 'ass' || normalizedCodec === 'ssa'
  }

  private shouldPreserveSecondaryAssStyle(): boolean {
    if (this.state.subtitleSelected !== SubtitleMode.INNER_SUBTITLE ||
      this.state.secondarySubtitleTrackSelected < 0) {
      return false
    }
    const selectedTrack = this.state.subtitleTrack.find((track: MpvSubtitleTrack) =>
    track.id === this.state.secondarySubtitleTrackSelected)
    return this.isAssCodec(selectedTrack?.codec ?? '')
  }

  refreshMpv3DSubtitleText(): void {
    if (!this.getHandle() || this.mpvSubtitle3DMode === Subtitle3DMode.DISABLED) {
      return
    }
    const texts = mpvGetSubtitleTexts(this.getHandle()) as MpvSubtitleTexts
    const lines: string[] = []
    const secondaryText = texts.secondary?.trim() ?? ''
    const primaryText = texts.primary?.trim() ?? ''
    if (secondaryText.length > 0) {
      lines.push(secondaryText)
    }
    if (primaryText.length > 0) {
      lines.push(primaryText)
    }
    const subtitleText = lines.join('\n')
    if (subtitleText !== this.lastSubtitle) {
      this.lastSubtitle = subtitleText
      this.state.subtitle = subtitleText
    }
  }

  private isBitmapSubtitleTrack(track: MpvSubtitleTrack): boolean {
    const codec = (track.codec ?? '').toLowerCase()
    return codec.includes('pgs') || codec.includes('dvd_subtitle') ||
      codec.includes('dvb_subtitle') || codec.includes('xsub')
  }
}
