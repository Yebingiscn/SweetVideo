import type { DanmakuItem } from './DanmakuCore'

const HEATMAP_BUCKETS: number = 120
const PATH_WIDTH: number = 1000
const PATH_HEIGHT: number = 100

/** A bounded density timeline in media time; independent of playback ticks. */
export class DanmakuHeatmap {
  static build(items: DanmakuItem[], durationMs: number, offsetMs: number = 0): number[] {
    if (items.length === 0 || !Number.isFinite(durationMs) || durationMs <= 0 || !Number.isFinite(offsetMs)) {
      return []
    }
    const counts: number[] = new Array<number>(HEATMAP_BUCKETS).fill(0)
    let peak: number = 0
    for (const item of items) {
      if (!Number.isFinite(item.time) || item.time < 0) {
        continue
      }
      // The overlay samples mediaTime - offsetMs, so positive offsets delay a comment.
      const mediaTime = item.time + offsetMs
      if (!Number.isFinite(mediaTime) || mediaTime < 0 || mediaTime > durationMs) {
        continue
      }
      const index = Math.min(HEATMAP_BUCKETS - 1, Math.floor(mediaTime / durationMs * HEATMAP_BUCKETS))
      counts[index]++
      peak = Math.max(peak, counts[index])
    }
    if (peak === 0) {
      return []
    }
    return counts.map((count: number): number => count / peak)
  }

  /** Closed area in the requested coordinate space; Path.commands uses physical pixels. */
  static path(values: number[], width: number = PATH_WIDTH, height: number = PATH_HEIGHT): string {
    if (values.length === 0 || !Number.isFinite(width) || width <= 0 || !Number.isFinite(height) || height <= 0) {
      return ''
    }
    // Keep the command count bounded even if a caller supplies an oversized series.
    const count = Math.min(HEATMAP_BUCKETS, values.length)
    const points: number[] = new Array<number>(count).fill(0)
    let peak: number = 0
    for (let index = 0; index < values.length; index++) {
      const value = Number.isFinite(values[index]) ? Math.max(0, Math.min(1, values[index])) : 0
      const bucket = Math.min(count - 1, Math.floor(index / values.length * count))
      points[bucket] = Math.max(points[bucket], value)
      peak = Math.max(peak, value)
    }
    if (peak === 0) {
      return ''
    }
    let commands = `M0 ${height} L0 ${DanmakuHeatmap.height(points[0], height)}`
    for (let index = 0; index < count; index++) {
      const x = ((index + 0.5) / count * width).toFixed(2)
      commands += ` L${x} ${DanmakuHeatmap.height(points[index], height)}`
    }
    return commands + ` L${width} ${DanmakuHeatmap.height(points[count - 1], height)} L${width} ${height} Z`
  }

  private static height(value: number, height: number): string {
    return (height * (1 - value)).toFixed(2)
  }
}
