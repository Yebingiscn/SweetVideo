import { Subtitle3DMode, SubtitleMode } from '../common/enum/SubtitleMode'
import { PlayerControllerInterface } from '../controller/PlayerControllerFactory'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'

@ObservedV2
export class SubtitleManager {
  @Trace subtitleMode: SubtitleMode = SubtitleMode.NONE
  @Trace subtitle3DMode: Subtitle3DMode = Subtitle3DMode.DISABLED
  private player: PlayerControllerInterface | undefined
  private isMpv: boolean = false

  constructor(player?: PlayerControllerInterface) {
    if (player) {
      this.player = player
      this.isMpv = player.isMpvPlayer()
      this.subtitleMode = player.subtitleSelected
    }
  }

  get subtitleVisibility(): Visibility {
    if (this.subtitleMode === SubtitleMode.NONE || this.subtitleMode === SubtitleMode.AI_SUBTITLE) {
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
    this.savePreference()
  }

  switchToInner(): void {
    this.setMode(SubtitleMode.INNER_SUBTITLE)
    this.savePreference()
  }

  switchToExternal(): void {
    this.setMode(SubtitleMode.EXTERNAL_SUBTITLE)
    this.player?.refreshExternalSubtitleByPlaybackTime(false, this.subtitleVisibility)
    this.savePreference()
  }

  switchToAI(): void {
    this.setMode(SubtitleMode.AI_SUBTITLE)
    this.savePreference()
  }

  set3DMode(mode: Subtitle3DMode): void {
    this.subtitle3DMode = mode !== Subtitle3DMode.DISABLED && this.isMpv &&
      this.subtitleMode === SubtitleMode.INNER_SUBTITLE && !this.player?.supportsSubtitle3D() ?
      Subtitle3DMode.DISABLED : mode
    this.player?.setSubtitle3DMode(this.subtitle3DMode)
    this.savePreference()
  }

  savePreference(): void {
    this.player?.saveSubtitlePreferenceForCurrentVideo(
      this.subtitleVisibility,
      this.isAIAsrShown,
      this.subtitle3DMode
    )
  }

  applyFromMetadata(
    nowPlaying: VideoMetadata,
    hasExternalSubtitle: boolean,
    hasInnerSubtitle: boolean
  ): void {
    const subtitleMode = nowPlaying.subtitle_mode
    const subtitleVisible = nowPlaying.subtitle_visible
    const aiAsrShown = nowPlaying.subtitle_ai_asr_shown
    const subtitle3DMode = nowPlaying.subtitle_3d_mode
    const subtitleTrackId = nowPlaying.subtitle_track_id

    if (aiAsrShown === true) {
      this.subtitleMode = SubtitleMode.AI_SUBTITLE
    } else if (subtitleVisible === false && subtitleMode === undefined) {
      this.subtitleMode = SubtitleMode.NONE
    } else if (subtitleMode !== undefined && subtitleMode >= SubtitleMode.NONE) {
      this.subtitleMode = subtitleMode as SubtitleMode
    } else {
      this.subtitleMode = SubtitleMode.NONE
    }

    if (this.subtitleMode === SubtitleMode.EXTERNAL_SUBTITLE && !hasExternalSubtitle) {
      this.subtitleMode = SubtitleMode.NONE
      this.resetSubtitleMetadata(nowPlaying)
    } else if (this.subtitleMode === SubtitleMode.INNER_SUBTITLE && !hasInnerSubtitle) {
      this.subtitleMode = SubtitleMode.NONE
    }

    this.player!.subtitleSelected = this.subtitleMode

    if (subtitle3DMode !== undefined &&
      [Subtitle3DMode.DISABLED, Subtitle3DMode.SIDE_BY_SIDE, Subtitle3DMode.TOP_AND_BOTTOM].includes(subtitle3DMode)) {
      this.subtitle3DMode = subtitle3DMode as Subtitle3DMode
    } else {
      this.subtitle3DMode = Subtitle3DMode.DISABLED
    }

    if (subtitleTrackId !== undefined && subtitleTrackId >= 0) {
      this.player!.subtitleTrackSelected = subtitleTrackId
    }

    if (this.isMpv && this.subtitleMode === SubtitleMode.INNER_SUBTITLE &&
      this.subtitle3DMode !== Subtitle3DMode.DISABLED && !this.player!.supportsSubtitle3D()) {
      this.subtitle3DMode = Subtitle3DMode.DISABLED
    }

    this.syncMpvSubtitleVisibility()
  }

  syncFromPlayer(): void {
    if (this.player) {
      this.subtitleMode = this.player.subtitleSelected
    }
  }

  syncMpvSubtitleVisibility(): void {
    if (!this.isMpv || !this.player) {
      return
    }
    if (this.subtitleMode === SubtitleMode.INNER_SUBTITLE) {
      if (this.player.subtitleTrackSelected >= 0) {
        this.player.selectSubtitleTrack(this.player.subtitleTrackSelected)
      }
    } else {
      this.player.selectSubtitleTrack(-1)
      this.player.selectSecondarySubtitleTrack(-1)
    }
    this.player.setSubtitle3DMode(this.subtitle3DMode)
  }

  private resetSubtitleMetadata(nowPlaying: VideoMetadata): void {
    nowPlaying.subtitle_mode = SubtitleMode.NONE
    nowPlaying.subtitle_visible = false
    nowPlaying.subtitle_ai_asr_shown = false
    nowPlaying.subtitle_3d_mode = Subtitle3DMode.DISABLED
    nowPlaying.subtitle_offset_millis = 0
    nowPlaying.subtitle_track_id = -1
  }

  private setMode(mode: SubtitleMode): void {
    this.subtitleMode = mode
    this.player!.subtitleSelected = mode
    this.syncMpvSubtitleVisibility()
  }
}
