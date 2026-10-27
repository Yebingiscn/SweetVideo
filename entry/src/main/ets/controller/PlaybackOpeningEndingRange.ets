import { VideoMetadata } from '../interfaces/VideoMetadataInterface'

/** 同时保留单片设置与生效点位，兼容旧版“距结尾时长”数据。 */
@ObservedV2
export class PlaybackOpeningEndingRange {
  @Trace startTime: number = 0
  @Trace endTime: number = 0
  @Trace introEndMs: number = 0
  @Trace outroStartMs: number = 0

  bind(metadata: VideoMetadata | undefined, durationMs: number, globalIntroMs: number, globalOutroMs: number): void {
    const start = metadata?.start_time ?? 0
    const ending = metadata?.end_time ?? 0
    this.startTime = Number.isFinite(start) && start > 0 ? start : 0
    this.endTime = Number.isFinite(ending) && ending > 0 ?
      (metadata?.end_time_is_duration ?
        (Number.isFinite(durationMs) && durationMs > 0 ? Math.max(0, durationMs - ending) : 0) : ending) : 0
    if (!Number.isFinite(durationMs) || durationMs <= 0) {
      this.introEndMs = 0
      this.outroStartMs = 0
      return
    }
    const intro = this.startTime > 0 ? this.startTime : globalIntroMs
    this.introEndMs = Number.isFinite(intro) && intro > 0 && intro < durationMs ? intro : 0
    const hasSpecificEnd = ending !== 0
    const end = hasSpecificEnd ? this.endTime : durationMs - globalOutroMs
    const hasEnding = hasSpecificEnd || (Number.isFinite(globalOutroMs) && globalOutroMs > 0)
    // 非法单片设置不落回全局；片头片尾不能覆盖整段媒体。
    this.outroStartMs = hasEnding && Number.isFinite(end) && end > this.introEndMs &&
      end < durationMs && this.startTime < durationMs ? end : 0
  }

  static valid(start: number, end: number, duration: number, allowUnsetEnd: boolean): boolean {
    return Number.isFinite(start) && Number.isFinite(end) && Number.isFinite(duration) && duration > 0 &&
      start >= 0 && start < duration && end >= 0 && end <= duration &&
      ((allowUnsetEnd && end === 0) || end > start)
  }
}
