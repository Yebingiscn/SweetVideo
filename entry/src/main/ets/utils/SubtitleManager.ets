import { Subtitle3DMode, SubtitleMode } from '../common/enum/SubtitleMode'
import { PlayerControllerInterface } from '../controller/PlayerControllerFactory'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import SubtitleUtil from './SubtitleUtil'
import SubtitleLanguageUtil from './SubtitleLanguageUtil'
import { Setting } from './ObservedUtil'
import { deviceInfo } from '@kit.BasicServicesKit'
import { AICaptionController } from '@kit.SpeechKit'
import { salmonLogger } from 'salmonlogger'
import ToolsUtil from './ToolsUtil'

const TAG = 'SubtitleManager'

@ObservedV2
export class SubtitleManager {
  @Trace subtitleMode: SubtitleMode = SubtitleMode.NONE
  @Trace subtitle3DMode: Subtitle3DMode = Subtitle3DMode.DISABLED
  private player: PlayerControllerInterface | undefined
  private isMpv: boolean = false
  private aiFallbackMode: SubtitleMode = SubtitleMode.NONE
  private aiFallbackTrackId: number = -1
  private aiFallbackSecondaryTrackId: number = -1
  private aiFallbackMedia: VideoMetadata | undefined = undefined
  private pendingAISelection: boolean = false

  constructor(player?: PlayerControllerInterface) {
    if (player) {
      this.player = player
      this.isMpv = player.isMpvPlayer()
      this.syncFromPlayer()
    }
  }

  get subtitleVisibility(): Visibility {
    if (this.subtitleMode === SubtitleMode.NONE || this.subtitleMode === SubtitleMode.AI_SUBTITLE) {
      return Visibility.None
    }
    if (this.isMpv && this.subtitleMode === SubtitleMode.EXTERNAL_SUBTITLE) {
      return Visibility.None
    }
    if (this.isMpv && this.subtitleMode === SubtitleMode.INNER_SUBTITLE) {
      return this.subtitle3DMode === Subtitle3DMode.DISABLED ? Visibility.None : Visibility.Visible
    }
    return Visibility.Visible
  }

  get isAIAsrShown(): boolean {
    return this.subtitleMode === SubtitleMode.AI_SUBTITLE
  }

  get isSubtitleOff(): boolean {
    return this.subtitleMode === SubtitleMode.NONE
  }

  get isAnySubtitleActive(): boolean {
    return this.subtitleMode !== SubtitleMode.NONE
  }

  get isInnerSubtitleActive(): boolean {
    return this.subtitleMode === SubtitleMode.INNER_SUBTITLE
  }

  get isExternalSubtitleActive(): boolean {
    return this.subtitleMode === SubtitleMode.EXTERNAL_SUBTITLE
  }

  get effective3DMode(): Subtitle3DMode {
    if (this.subtitleVisibility !== Visibility.Visible) {
      return Subtitle3DMode.DISABLED
    }
    return this.subtitle3DMode
  }

  switchToNone(): void {
    this.setMode(SubtitleMode.NONE)
    this.savePreference(true)
  }

  switchToInner(): void {
    this.setMode(SubtitleMode.INNER_SUBTITLE)
    this.savePreference(true)
  }

  switchToExternal(): void {
    this.setMode(SubtitleMode.EXTERNAL_SUBTITLE)
    this.player?.subtitleController.refreshExternalSubtitleByPlaybackTime(false, this.subtitleVisibility)
    this.savePreference(true)
  }

  switchToAI(): void {
    if (this.isAIAsrShown || !this.canEnableAICaption()) {
      return
    }
    this.rememberAIFallback(this.subtitleMode)
    this.setMode(SubtitleMode.AI_SUBTITLE)
    // 只有初始化成功才记住用户的 AI 选择，失败不能覆盖原字幕偏好。
    this.pendingAISelection = true
  }

  onAICaptionPrepared(): void {
    if (this.isAIAsrShown && this.pendingAISelection && this.aiFallbackMedia === this.player?.nowPlaying) {
      this.pendingAISelection = false
      this.savePreference(true)
    }
  }

  onAICaptionError(): void {
    if (!this.isAIAsrShown) {
      return
    }
    this.restoreAIFallback()
    ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.ai_subtitle_unavailable').id))
  }

  set3DMode(mode: Subtitle3DMode): void {
    this.subtitle3DMode = mode !== Subtitle3DMode.DISABLED && this.isMpv &&
      this.subtitleMode === SubtitleMode.INNER_SUBTITLE && !this.player?.subtitleController.supportsSubtitle3D() ?
      Subtitle3DMode.DISABLED : mode
    this.player?.subtitleController.setSubtitle3DMode(this.subtitle3DMode)
    this.savePreference()
  }

  savePreference(selectionChanged: boolean = false): void {
    this.player?.saveSubtitlePreferenceForCurrentVideo(
      this.subtitleVisibility,
      this.isAIAsrShown,
      this.subtitle3DMode,
      selectionChanged
    )
  }

  applyFromMetadata(
    nowPlaying: VideoMetadata,
    hasExternalSubtitle: boolean,
    hasInnerSubtitle: boolean
  ): void {
    const subtitleMode = SubtitleUtil.getSubtitleSelectionMode(nowPlaying)
    const subtitle3DMode = nowPlaying.subtitle_3d_mode
    const subtitleTrackId = nowPlaying.subtitle_track_id

    if (subtitleMode !== undefined) {
      this.subtitleMode = subtitleMode
    } else {
      this.subtitleMode = hasExternalSubtitle ? SubtitleMode.EXTERNAL_SUBTITLE :
        (hasInnerSubtitle ? SubtitleMode.INNER_SUBTITLE : SubtitleMode.NONE)
    }

    if (this.subtitleMode === SubtitleMode.EXTERNAL_SUBTITLE && !hasExternalSubtitle) {
      this.subtitleMode = SubtitleMode.NONE
    } else if (this.subtitleMode === SubtitleMode.INNER_SUBTITLE && !hasInnerSubtitle) {
      this.subtitleMode = SubtitleMode.NONE
    }

    if (this.isAIAsrShown) {
      this.rememberAIFallback(hasExternalSubtitle ? SubtitleMode.EXTERNAL_SUBTITLE :
        (hasInnerSubtitle ? SubtitleMode.INNER_SUBTITLE : SubtitleMode.NONE))
      if (!this.canEnableAICaption()) {
        this.restoreAIFallback()
      }
    }

    this.player!.subtitleSelected = this.subtitleMode

    if (subtitle3DMode !== undefined &&
      [Subtitle3DMode.DISABLED, Subtitle3DMode.SIDE_BY_SIDE, Subtitle3DMode.TOP_AND_BOTTOM].includes(subtitle3DMode)) {
      this.subtitle3DMode = subtitle3DMode as Subtitle3DMode
    } else {
      this.subtitle3DMode = Subtitle3DMode.DISABLED
    }

    if (subtitleTrackId !== undefined && subtitleTrackId >= 0 &&
      this.player!.subtitleTrack.some(track => track.id === subtitleTrackId)) {
      this.player!.subtitleTrackSelected = subtitleTrackId
    } else if (this.subtitleMode === SubtitleMode.INNER_SUBTITLE) {
      this.player!.subtitleTrackSelected = SubtitleLanguageUtil.selectPreferredTrack(
        this.player!.subtitleTrack, Setting.subtitlePreferredLanguage)?.id ?? -1
    }

    if (this.isMpv && this.subtitleMode === SubtitleMode.INNER_SUBTITLE &&
      this.subtitle3DMode !== Subtitle3DMode.DISABLED && !this.player!.subtitleController.supportsSubtitle3D()) {
      this.subtitle3DMode = Subtitle3DMode.DISABLED
    }

    this.syncMpvSubtitleVisibility()
  }

  syncFromPlayer(): void {
    if (this.player) {
      if (this.player.subtitleSelected === SubtitleMode.AI_SUBTITLE &&
        (!this.isAIAsrShown || this.aiFallbackMedia !== this.player.nowPlaying)) {
        this.rememberAIFallback(this.getDefaultSubtitleMode())
        if (!this.canEnableAICaption()) {
          this.restoreAIFallback()
          return
        }
      }
      this.subtitleMode = this.player.subtitleSelected
    }
  }

  private canEnableAICaption(): boolean {
    try {
      if (canIUse('SystemCapability.AI.AICaption')) {
        // API 23–25 没有检测接口，继续使用原流程，并由 onError 处理失败。
        if (!deviceInfo.apiAvailable('26.0.0')) {
          return true
        }
        const supported = new AICaptionController().isCapabilitySupported()
        salmonLogger.addLog(TAG, `AI字幕设备能力检测: supported=${supported}`)
        if (supported) {
          return true
        }
      }
      ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.ai_subtitle_unsupported').id))
    } catch (error) {
      salmonLogger.addLog(TAG, `AI字幕设备能力检测失败: ${error}`, true)
      ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.ai_subtitle_unavailable').id))
    }
    return false
  }

  private getDefaultSubtitleMode(): SubtitleMode {
    return (this.player?.nowPlaying?.external_subtitle_format?.length ?? 0) > 0 ? SubtitleMode.EXTERNAL_SUBTITLE :
      ((this.player?.subtitleTrack.length ?? 0) > 0 ? SubtitleMode.INNER_SUBTITLE : SubtitleMode.NONE)
  }

  private rememberAIFallback(mode: SubtitleMode): void {
    this.aiFallbackMode = mode
    this.aiFallbackTrackId = this.player?.subtitleTrackSelected ?? -1
    this.aiFallbackSecondaryTrackId = this.player?.secondarySubtitleTrackSelected ?? -1
    this.aiFallbackMedia = this.player?.nowPlaying
    this.pendingAISelection = false
  }

  private restoreAIFallback(): void {
    this.pendingAISelection = false
    let mode = this.aiFallbackMedia === this.player?.nowPlaying ? this.aiFallbackMode : this.getDefaultSubtitleMode()
    if (mode === SubtitleMode.EXTERNAL_SUBTITLE &&
      (this.player?.nowPlaying?.external_subtitle_format?.length ?? 0) === 0) {
      mode = this.getDefaultSubtitleMode()
    }
    if (mode === SubtitleMode.INNER_SUBTITLE && this.player) {
      const track = this.player.subtitleTrack.find(item =>
      this.aiFallbackMedia === this.player?.nowPlaying && item.id === this.aiFallbackTrackId) ??
        SubtitleLanguageUtil.selectPreferredTrack(this.player.subtitleTrack, Setting.subtitlePreferredLanguage)
      this.player.subtitleTrackSelected = track?.id ?? -1
      if (!track) {
        mode = SubtitleMode.NONE
      }
    }
    this.setMode(mode)
    if (mode === SubtitleMode.INNER_SUBTITLE && this.isMpv && this.player &&
      this.aiFallbackMedia === this.player.nowPlaying &&
      this.aiFallbackSecondaryTrackId !== this.player.subtitleTrackSelected &&
      this.player.subtitleTrack.some(track => track.id === this.aiFallbackSecondaryTrackId)) {
      this.player.subtitleController.selectSecondarySubtitleTrack(this.aiFallbackSecondaryTrackId)
    }
    if (mode === SubtitleMode.INNER_SUBTITLE && !this.isMpv && this.player) {
      this.player.subtitleController.selectSubtitleTrack(this.player.subtitleTrackSelected)
    } else if (mode === SubtitleMode.EXTERNAL_SUBTITLE) {
      this.player?.subtitleController.refreshExternalSubtitleByPlaybackTime(false, this.subtitleVisibility)
    }
    // 临时能力/服务故障不写回视频的字幕选择，保留原有记忆。
  }

  syncMpvSubtitleVisibility(): void {
    if (!this.isMpv || !this.player) {
      return
    }
    if (this.subtitleMode === SubtitleMode.INNER_SUBTITLE) {
      if (this.player.subtitleTrackSelected >= 0) {
        this.player.subtitleController.selectSubtitleTrack(this.player.subtitleTrackSelected)
      }
    } else if (this.subtitleMode === SubtitleMode.EXTERNAL_SUBTITLE) {
      this.player.subtitleController.selectExternalSubtitleTrack()
    } else {
      this.player.subtitleController.selectSubtitleTrack(-1)
      this.player.subtitleController.selectSecondarySubtitleTrack(-1)
    }
    this.player.subtitleController.setSubtitle3DMode(this.subtitle3DMode)
  }

  private setMode(mode: SubtitleMode): void {
    this.pendingAISelection = false
    this.subtitleMode = mode
    if (this.player) {
      this.player.subtitleSelected = mode
    }
    this.syncMpvSubtitleVisibility()
  }
}
