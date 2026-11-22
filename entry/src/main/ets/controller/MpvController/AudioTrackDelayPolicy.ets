import type { AudioTrackDelay, VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import type { MpvAudioTrack } from './MpvTypes'

export const MAX_AUDIO_TRACK_DELAY_MS: number = 5000

export function validAudioTrackDelay(value: number): boolean {
  return Number.isInteger(value) && Math.abs(value) <= MAX_AUDIO_TRACK_DELAY_MS
}

export function audioTrackDelayKey(media: VideoMetadata, track: MpvAudioTrack): string {
  // Keep disc titles distinct. Prefer the demuxed stream index over mpv's
  // session-local track id; also check the track metadata before reusing a value.
  const stream = track.ffIndex !== undefined && track.ffIndex >= 0 ? `ff:${track.ffIndex}` : `mpv:${track.id}`
  return JSON.stringify([media.bluray_title_id ?? -1, stream, track.lang, track.title, track.codec ?? '',
    track.channels ?? 0])
}

export function getInternalTrackDelay(media: VideoMetadata, track: MpvAudioTrack): number {
  const key = audioTrackDelayKey(media, track)
  const value = media.audio_track_delays?.find((entry: AudioTrackDelay) => entry.key === key)?.offsetMs ?? 0
  return validAudioTrackDelay(value) ? value : 0
}

export function updateAudioTrackDelays(delays: AudioTrackDelay[] | undefined, update: AudioTrackDelay):
AudioTrackDelay[] | undefined {
  const remaining = delays?.filter((entry: AudioTrackDelay) => entry.key !== update.key) ?? []
  if (update.offsetMs !== 0) {
    remaining.push(update)
  }
  return remaining.length > 0 ? remaining : undefined
}
