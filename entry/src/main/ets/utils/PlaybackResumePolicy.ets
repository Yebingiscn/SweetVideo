import type { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import { VideoStartTimeMode } from '../common/enum/VideoStartTimeMode'

const MAX_VIDEO_REPLAY_TAIL_MS: number = 60000

export interface PlaybackBounds {
  startMs: number
  endMs: number
  introMs: number
  outroMs: number
}

export interface PlaybackResumePlan {
  mode: number
  positionMs: number
  replay: boolean
}

export function playbackBounds(metadata: VideoMetadata | undefined, durationMs: number,
  globalIntroMs: number, globalOutroMs: number): PlaybackBounds {
  const start = metadata?.start_time ?? 0
  const end = metadata?.end_time ?? 0
  const duration = Number.isFinite(durationMs) && durationMs > 0 ? durationMs : 0
  const startMs = Number.isFinite(start) && start > 0 ? start : 0
  const endMs = Number.isFinite(end) && end > 0 ?
    (metadata?.end_time_is_duration ? (duration > 0 ? Math.max(0, duration - end) : 0) : end) : 0
  const intro = startMs > 0 ? startMs : globalIntroMs
  const introMs = Number.isFinite(intro) && intro > 0 && intro < duration ? intro : 0
  const ending = end !== 0 ? endMs : duration - globalOutroMs
  const hasOutro = end !== 0 || (Number.isFinite(globalOutroMs) && globalOutroMs > 0)
  const outroMs = hasOutro && Number.isFinite(ending) && ending > introMs && ending < duration &&
    startMs < duration ? ending : 0
  return {
    startMs,
    endMs,
    introMs,
    outroMs
  }
}

export function resolvePlaybackResume(metadata: VideoMetadata, hasVideo: boolean, resumeHistory: boolean,
  globalIntroMs: number, globalOutroMs: number, positionOverride?: number): PlaybackResumePlan {
  const duration = Number.isFinite(metadata.time) && metadata.time > 0 ? metadata.time : 0
  const saved = positionOverride ?? metadata.last_play
  const position = Number.isFinite(saved) && saved > 0 ? saved : 0
  const bounds = playbackBounds(metadata, duration, hasVideo ? globalIntroMs : 0, hasVideo ? globalOutroMs : 0)
  const end = bounds.outroMs || duration
  const remaining = end - position
  const playableMs = end - bounds.introMs
  const nearVideoEnd = hasVideo && position > 0 && playableMs > 0 && remaining >= 0 &&
    remaining <= Math.min(playableMs * 0.05, MAX_VIDEO_REPLAY_TAIL_MS)
  // Never start in an already configured skip area, or at the exact EOF.
  const replay = nearVideoEnd || (end > 0 && position >= end)

  if (bounds.startMs > 0 && (bounds.introMs === bounds.startMs ||
    (duration === 0 && (bounds.endMs === 0 || bounds.endMs > bounds.startMs))) &&
    (replay || position < bounds.startMs || !resumeHistory)) {
    return { mode: VideoStartTimeMode.SEEK_TO_START_TIME, positionMs: bounds.startMs, replay }
  }
  if (!replay && resumeHistory && position > 0 && duration > 0 && position < duration) {
    return { mode: VideoStartTimeMode.SEEK_TO_LAST_PLAY_TIME, positionMs: position, replay: false }
  }
  if (bounds.startMs === 0 && bounds.introMs > 0) {
    return { mode: VideoStartTimeMode.SEEK_TO_INTRO_TIME, positionMs: bounds.introMs, replay }
  }
  return { mode: replay ? VideoStartTimeMode.SEEK_TO_BEGINNING : -1, positionMs: 0, replay }
}
