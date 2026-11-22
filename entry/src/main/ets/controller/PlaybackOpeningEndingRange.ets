import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import { playbackBounds } from '../utils/PlaybackResumePolicy'

/** 同时保留单片设置与生效点位，兼容旧版“距结尾时长”数据。 */
@ObservedV2
export class PlaybackOpeningEndingRange {
  @Trace startTime: number = 0
  @Trace endTime: number = 0
  @Trace introEndMs: number = 0
  @Trace outroStartMs: number = 0

  bind(metadata: VideoMetadata | undefined, durationMs: number, globalIntroMs: number, globalOutroMs: number): void {
    const bounds = playbackBounds(metadata, durationMs, globalIntroMs, globalOutroMs)
    this.startTime = bounds.startMs
    this.endTime = bounds.endMs
    this.introEndMs = bounds.introMs
    this.outroStartMs = bounds.outroMs
  }

  static valid(start: number, end: number, duration: number, allowUnsetEnd: boolean): boolean {
    return Number.isFinite(start) && Number.isFinite(end) && Number.isFinite(duration) && duration > 0 &&
      start >= 0 && start < duration && end >= 0 && end <= duration &&
      ((allowUnsetEnd && end === 0) || end > start)
  }
}
