import type { MpvChapter } from '../../controller/MpvController/MpvTypes'

export interface PlaybackProgressMarker {
  key: string
  timeMs: number
  label: string
  color?: ResourceColor
  kind?: 'chapter'
}

export interface PlaybackRangeMarker {
  key: string
  timeMs: number
  label: string
  color: ResourceColor
  ratio: number
  kind?: 'chapter'
}

export interface PlaybackRangeMarkerLabel {
  key: string
  label: string
  color: ResourceColor
  ratio: number
  compact?: boolean
}

// InSet reserves 6vp at each end, then half the track thickness before the
// minimum/maximum thumb centre. Keep these equal to the Slider's explicit size.
export const PLAYBACK_SLIDER_TRACK_THICKNESS: number = 20
export const PLAYBACK_SLIDER_BLOCK_SIZE: number = 12
export const PLAYBACK_SLIDER_TRACK_INSET: number = 6 + PLAYBACK_SLIDER_TRACK_THICKNESS / 2
const LABEL_WIDTH_RATIO: number = 0.25
const AB_LABEL_WIDTH: number = 16
const MAX_RANGE_MARKERS: number = 4
// Dense chapter lists share sub-pixel ticks instead of creating unbounded UI nodes.
const CHAPTER_TRACK_BUCKETS: number = 256

/** Reuse the controller's chapter list (seconds); the shared slider uses milliseconds. */
export function playbackChapterMarkers(chapters: MpvChapter[]): PlaybackProgressMarker[] {
  return chapters.filter((chapter: MpvChapter): boolean =>
    Number.isFinite(chapter.time) && chapter.time >= 0 && Number.isFinite(chapter.time * 1000))
    .map((chapter: MpvChapter): PlaybackProgressMarker => ({
      key: `chapter:${chapter.time * 1000}`,
      timeMs: chapter.time * 1000,
      label: chapter.title || '',
      color: '#D9E7F1',
      kind: 'chapter'
    }))
}

/** Unknown duration and invalid/out-of-media points must not fabricate marks. */
export function playbackRangeMarkers(markers: PlaybackProgressMarker[] | undefined,
  durationMs: number): PlaybackRangeMarker[] {
  if (!markers || !Number.isFinite(durationMs) || durationMs <= 0) { return [] }
  const result: PlaybackRangeMarker[] = []
  const keys: Set<string> = new Set()
  const chapterBuckets: Set<number> = new Set()
  let rangeCount: number = 0
  for (const marker of markers) {
    if (!marker.key || (!marker.label && marker.kind !== 'chapter') || keys.has(marker.key) || !Number.isFinite(marker.timeMs) ||
      marker.timeMs < 0 || marker.timeMs > durationMs) { continue }
    const ratio = clampRatio(marker.timeMs / durationMs)
    if (marker.kind === 'chapter') {
      const bucket = Math.round(ratio * CHAPTER_TRACK_BUCKETS)
      if (chapterBuckets.has(bucket)) { continue }
      chapterBuckets.add(bucket)
    } else {
      if (rangeCount >= MAX_RANGE_MARKERS) { continue }
      rangeCount++
    }
    keys.add(marker.key)
    result.push({
      key: marker.key,
      timeMs: marker.timeMs,
      label: marker.label,
      color: marker.color ?? defaultMarkerColor(marker.key, result.length),
      ratio: ratio,
      kind: marker.kind
    })
  }
  return result.sort((left: PlaybackRangeMarker, right: PlaybackRangeMarker): number => left.ratio - right.ratio)
}

/** Long captions merge and stay in bounds. A standalone A/B caption is narrow
 * enough to stay centred on its tick, including at either end of the track. */
export function playbackRangeMarkerLabels(markers: PlaybackRangeMarker[]): PlaybackRangeMarkerLabel[] {
  const result: PlaybackRangeMarkerLabel[] = []
  const groups: PlaybackRangeMarker[][] = []
  for (const marker of markers) {
    // Chapter titles remain in the chapter menu; only policy points need captions.
    if (marker.kind === 'chapter') { continue }
    const group = groups[groups.length - 1]
    const previous = result[result.length - 1]
    const ratio = labelRatio(marker.ratio)
    if (group && previous && ratio - previous.ratio < LABEL_WIDTH_RATIO) {
      group.push(marker)
      previous.key = group.map((item: PlaybackRangeMarker): string => item.key).join('|')
      previous.label = group.map((item: PlaybackRangeMarker): string => item.label).join(' · ')
      const mean = group.reduce((sum: number, item: PlaybackRangeMarker): number => sum + item.ratio, 0) /
        group.length
      previous.ratio = labelRatio(mean)
    } else {
      groups.push([marker])
      result.push({ key: marker.key, label: marker.label, color: marker.color, ratio: ratio })
    }
  }
  for (let index = 0; index < groups.length; index++) {
    const group = groups[index]
    const key = group[0].key.toLowerCase()
    if (group.length === 1 && (key === 'a' || key === 'b' || key === 'ab-a' || key === 'ab-b')) {
      result[index].ratio = group[0].ratio
      result[index].compact = true
    }
  }
  return result
}

/** Position is relative to the overlay's inset content area. Unlike size APIs,
 * ArkUI position does not retain calc expressions, so use a plain percentage. */
export function playbackRangeMarkerPosition(ratio: number): string {
  return `${clampRatio(ratio) * 100}%`
}

export function playbackRangeMarkerLabelWidth(label?: PlaybackRangeMarkerLabel): number | string {
  return label?.compact ? AB_LABEL_WIDTH : `${LABEL_WIDTH_RATIO * 100}%`
}

function labelRatio(ratio: number): number {
  return Math.min(1 - LABEL_WIDTH_RATIO / 2, Math.max(LABEL_WIDTH_RATIO / 2, clampRatio(ratio)))
}

function clampRatio(ratio: number): number {
  return Number.isFinite(ratio) ? Math.min(1, Math.max(0, ratio)) : 0
}

function defaultMarkerColor(key: string, index: number): ResourceColor {
  const normalized = key.toLowerCase()
  if (normalized === 'a') { return '#67E8F9' }
  if (normalized === 'b') { return '#F9A8D4' }
  if (normalized === 'intro' || normalized === 'op') { return '#FCD34D' }
  if (normalized === 'outro' || normalized === 'ed') { return '#C4B5FD' }
  const colors: ResourceColor[] = ['#67E8F9', '#F9A8D4', '#FCD34D', '#C4B5FD']
  return colors[index % colors.length]
}
