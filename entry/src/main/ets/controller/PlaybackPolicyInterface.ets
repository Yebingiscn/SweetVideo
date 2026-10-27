import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import { SweetRepeatMode } from '../common/enum/SweetRepeatMode'

/** 会话策略优先于引擎的片头片尾、完成历史和播放列表处理。 */
export interface PlaybackPolicyCallbacks {
  onPosition: (positionMs: number) => boolean
  onCompleted: () => boolean
  onSeek: (targetMs: number) => void
  onSeekStart: () => void
  onMediaChanged: () => void
  onSeekDone: (positionMs: number) => void
  onReady: (initialPositionMs?: number) => boolean
}
/** 最小播放能力，避免短视频为复用策略实现整个普通播放器接口。 */
export interface PlaybackPolicyHost {
  readonly nowPlaying: VideoMetadata | undefined
  readonly playbackPositionMs: number
  readonly durationMs?: number
  readonly repeatMode?: SweetRepeatMode
  finishAtEnding?: () => void
  readonly playing: boolean
  readonly onSwiping: boolean
  readonly isSliderPlayTimeChange: boolean
  readonly initialPlayTime: number | undefined
  playbackPolicy: PlaybackPolicyCallbacks | undefined
  seekTime(positionMs: number): void
  play(): void
  pause(): void
  setABLoop(pointAMs?: number, pointBMs?: number): boolean
}
