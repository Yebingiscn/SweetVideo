import ToolsUtil from './ToolsUtil.ets'
/** Engine-independent timeline. All times are milliseconds in media time. */
export interface DanmakuItem {
  time: number
  mode: number
  size: number
  color: string
  text: string
}

export interface DanmakuParseResult {
  items: DanmakuItem[]
  skipped: number
}

export const DANMAKU_MAX_BYTES: number = 8 * 1024 * 1024

const MAX_ITEMS: number = 50000
const SCROLL_DURATION: number = 8000
const FIXED_DURATION: number = 4000
const BASE_FONT_SIZE: number = 25
const COLLISION_BAND_HEIGHT: number = 32
const PREPARE_ITEMS: number = 16
const FRAME_ITEMS: number = 128
export const DANMAKU_MAX_ACTIVE: number = 120

export interface DanmakuTextMetrics {
  width: number
  ascent: number
  descent: number
}

/** Bounded LRU: replacing one entry never invalidates all measured text. */
export class DanmakuTextCache {
  private entries: Map<string, DanmakuTextMetrics> = new Map()
  private capacity: number

  constructor(capacity: number = 4096) {
    this.capacity = Math.max(1, Math.floor(capacity))
  }

  get(key: string): DanmakuTextMetrics | undefined {
    const value = this.entries.get(key)
    if (value) {
      this.entries.delete(key)
      this.entries.set(key, value)
    }
    return value
  }

  set(key: string, value: DanmakuTextMetrics): void {
    this.entries.delete(key)
    if (this.entries.size >= this.capacity) {
      for (const oldest of this.entries.keys()) {
        this.entries.delete(oldest)
        break
      }
    }
    this.entries.set(key, value)
  }

  clear(): void {
    this.entries.clear()
  }
}

export class DanmakuParser {
  // Deliberately supports ordinary BiliBili XML only, never DTD or executable modes.
  static async parse(source: string, cancelled: () => boolean = (): boolean => false): Promise<DanmakuParseResult> {
    if (source.length > DANMAKU_MAX_BYTES || /<!DOCTYPE|<!ENTITY/i.test(source)) {
      throw new Error(ToolsUtil.getStringResource($r('app.string.danmaku_file_too_large_or_xml').id))
    }
    const xml = source.replace(/^\uFEFF/, '').replace(/<\?xml[^?]*\?>/i, '')
      .replace(/<!--[\s\S]*?-->/g, '').trim()
    if (!/^<i(?:\s[^>]*)?>[\s\S]*<\/i>\s*$/.test(xml)) {
      throw new Error(ToolsUtil.getStringResource($r('app.string.danmaku_select_bilibili_xml').id))
    }
    const result: DanmakuParseResult = { items: [], skipped: 0 }
    const pattern = /<d\b([^>]*)>([\s\S]*?)<\/d\s*>/g
    let match: RegExpExecArray | null = pattern.exec(xml)
    let count = 0
    while (match !== null) {
      if (cancelled()) {
        throw new Error(ToolsUtil.getStringResource($r('app.string.danmaku_import_cancelled').id))
      }
      count++
      if (count > MAX_ITEMS) {
        throw new Error(ToolsUtil.getStringResource($r('app.string.danmaku_too_many').id))
      }
      const attribute = /(?:^|\s)p\s*=\s*(["'])([^"']*)\1/.exec(match[1])
      const fields: string[] = attribute ? attribute[2].split(',') : []
      const time = fields.length >= 4 && fields[0].trim() !== '' ? Number(fields[0]) * 1000 : NaN
      const mode = Number(fields[1])
      const size = Number(fields[2])
      const color = Number(fields[3])
      const text = DanmakuParser.text(match[2])
      if (Number.isFinite(time) && time >= 0 && time <= 7 * 86400000 &&
        [1, 2, 3, 4, 5].includes(mode) && Number.isFinite(size) && size > 0 &&
        Number.isInteger(color) && color >= 0 && color <= 0xffffff && text.length > 0) {
        result.items.push({
          time: time,
          mode: mode <= 3 ? 1 : mode,
          size: Math.max(14, Math.min(48, size)),
          color: '#' + color.toString(16).padStart(6, '0'),
          text: text
        })
      } else {
        result.skipped++
      }
      if (count % 500 === 0) {
        await new Promise<void>((resolve: () => void): void => {
          setTimeout(resolve, 0)
        })
      }
      match = pattern.exec(xml)
    }
    if (result.items.length === 0) {
      throw new Error(ToolsUtil.getStringResource($r('app.string.danmaku_no_text_items').id))
    }
    result.items.sort((a: DanmakuItem, b: DanmakuItem): number => a.time - b.time)
    return result
  }

  private static text(value: string): string {
    let text = value.trim()
    if (text.startsWith('<![CDATA[') && text.endsWith(']]>')) {
      text = text.slice(9, -3)
    } else {
      if (text.includes('<')) {
        return ''
      }
      text = text.replace(/&(#x[0-9a-f]+|#\d+|amp|lt|gt|quot|apos);/gi,
        (_entity: string, code: string): string => {
          switch (code) {
            case 'amp':
              return '&'
            case 'lt':
              return '<'
            case 'gt':
              return '>'
            case 'quot':
              return '"'
            case 'apos':
              return "'"
          }
          const point = code.toLowerCase().startsWith('#x') ? parseInt(code.slice(2), 16) :
            parseInt(code.slice(1), 10)
          return point > 0 && point <= 0x10ffff && !(point >= 0xd800 && point <= 0xdfff) ?
            String.fromCodePoint(point) : ''
        })
    }
    return text.replace(/[\u0000-\u001f\u007f]/g, ' ').trim().slice(0, 200)
  }
}

export class DanmakuClock {
  private position: number = 0
  private stamp: number = 0
  private rate: number = 1
  private running: boolean = false
  private correction: number = 0
  private correctionDuration: number = 250
  private initialized: boolean = false

  sample(position: number, stamp: number, discontinuity: boolean = false): void {
    const target = Math.max(0, position)
    const current = this.at(stamp)
    const error = target - current
    const smooth = this.initialized && this.running && !discontinuity && Math.abs(error) <= 1000
    this.position = smooth ? current : target
    // Ignore ordinary callback jitter (about two frames). Do not modulate scrolling speed for it.
    this.correction = smooth && Math.abs(error) > 32 * this.rate ? error : 0
    // Larger drift converges gently; a seek still re-anchors immediately.
    this.correctionDuration = Math.max(250, Math.abs(this.correction) / (this.rate * 0.05))
    this.stamp = stamp
    this.initialized = true
  }

  setState(running: boolean, rate: number, stamp: number): void {
    this.position = this.at(stamp)
    this.correction = 0
    this.stamp = stamp
    this.running = running
    this.rate = Number.isFinite(rate) && rate > 0 ? rate : 1
  }

  at(stamp: number): number {
    // Playback/buffering state freezes the clock. Sparse time callbacks must not stop animation.
    const elapsed = Math.max(0, stamp - this.stamp)
    return this.position + (this.running ? elapsed * this.rate +
      this.correction * Math.min(1, elapsed / this.correctionDuration) : 0)
  }
}

export interface DanmakuSprite {
  item: DanmakuItem
  width: number
  font: number
  ascent: number
  height: number
  lane: number
  x: number
  y: number
  end: number
}

export class DanmakuScheduler {
  private items: DanmakuItem[] = []
  private active: DanmakuSprite[] = []
  private cursor: number = 0
  private lastTime: number = -1
  private width: number = 0
  private height: number = 0
  private font: number = 0
  private area: number = 0
  private nextExpiry: number = Infinity
  private collisionBands: DanmakuSprite[][] = []
  private prepareCursor: number = 0
  private invalid: Set<DanmakuItem> = new Set()
  private prefetched: DanmakuSprite[] = []

  load(items: DanmakuItem[]): void {
    this.items = items
    this.reset()
  }

  reset(): void {
    this.clearActive()
    this.lastTime = -1
    this.cursor = 0
    this.prepareCursor = 0
    this.invalid.clear()
    this.prefetched.length = 0
  }

  hasPendingPreparation(time: number, ahead: number): boolean {
    const cursor = Math.max(this.prepareCursor, this.cursor)
    return cursor < this.items.length && this.items[cursor].time <= time + ahead
  }

  /** Warm metrics in bounded tasks. Only future comments also prefetch their texture. */
  prepare(time: number, font: number, ahead: number,
    measure: (text: string, size: number) => DanmakuTextMetrics, now?: () => number): boolean {
    this.prefetched.length = 0
    this.prepareCursor = Math.max(this.prepareCursor, this.cursor)
    let processed = 0
    const start = now ? now() : 0
    while (this.prepareCursor < this.items.length && this.items[this.prepareCursor].time <= time + ahead &&
      processed < PREPARE_ITEMS && (processed === 0 || !now || now() - start < 3)) {
      const item = this.items[this.prepareCursor++]
      processed++
      if (item.time + (item.mode === 1 ? SCROLL_DURATION : FIXED_DURATION) <= time) { continue }
      const size = item.size * font / BASE_FONT_SIZE
      try {
        const metrics = measure(item.text, size)
        if (!this.validMetrics(metrics)) {
          this.invalid.add(item)
        } else if (item.time > time) {
          this.prefetched.push(this.sprite(item, size, metrics, -1, 0))
        }
      } catch (_) {
        this.invalid.add(item)
      }
    }
    return processed > 0
  }

  upcoming(): DanmakuSprite[] { return this.prefetched }

  frame(time: number, width: number, height: number, font: number, area: number,
    measure: (text: string, size: number) => DanmakuTextMetrics | undefined): DanmakuSprite[] {
    if (width <= 0 || height <= 0) {
      return []
    }
    // Small engine timestamp jitter must not reconstruct lanes; explicit seeks call reset().
    if (time < this.lastTime && this.lastTime - time <= 250) {
      time = this.lastTime
    }
    const changed = width !== this.width || height !== this.height || font !== this.font || area !== this.area
    if (changed || this.lastTime < 0 || time < this.lastTime || time - this.lastTime > 1000) {
      this.clearActive()
      // Reconstruct a bounded window after seek; discard excess density, never queue a burst.
      this.cursor = Math.max(this.lowerBound(time - SCROLL_DURATION), this.lowerBound(time + 0.001) - 2000)
      this.prepareCursor = this.cursor
      this.invalid.clear()
      this.prefetched.length = 0
    }
    this.width = width
    this.height = height
    this.font = font
    this.area = area
    const regionHeight = height * Math.max(0, Math.min(1, area))
    let processed = 0
    while (this.cursor < this.items.length && this.items[this.cursor].time <= time) {
      if (++processed > FRAME_ITEMS) { break }
      const item = this.items[this.cursor]
      const duration = item.mode === 1 ? SCROLL_DURATION : FIXED_DURATION
      if (item.time + duration <= time || this.invalid.has(item)) {
        this.invalid.delete(item)
        this.cursor++
        continue
      }
      this.pruneExpired(item.time)
      if (this.active.length >= DANMAKU_MAX_ACTIVE) {
        this.cursor++
        continue
      }
      // BiliBili's ordinary 25-size text uses the size selected in the UI.
      const size = item.size * font / BASE_FONT_SIZE
      let metrics: DanmakuTextMetrics | undefined
      try {
        metrics = measure(item.text, size)
      } catch (_) {
        this.cursor++
        continue
      }
      // A cold glyph waits for the preparation task; never measure on the render callback.
      if (!metrics) {
        this.prepareCursor = Math.min(this.prepareCursor, this.cursor)
        break
      }
      this.cursor++
      const textWidth = metrics.width
      if (!this.validMetrics(metrics)) {
        continue
      }
      // Tight glyph bounds plus outline padding; transparent raster space is not a lane.
      const textHeight = Math.ceil(metrics.ascent + metrics.descent) + 6
      const gap = Math.max(2, Math.round(8 - Math.max(0, size - 22) * 6 / 26))
      const line = textHeight + gap
      const lanes = Math.min(16, Math.max(0, Math.floor((regionHeight - 16 + gap) / line)))
      if (lanes === 0 || (item.mode !== 1 && textWidth > width - 16)) {
        continue
      }
      for (let row = 0; row < lanes; row++) {
        const lane = item.mode === 4 ? lanes - row - 1 : row
        const y = item.mode === 4 ? regionHeight - 8 - textHeight - row * line : 8 + row * line
        if (y < 8 || y + textHeight > regionHeight - 8) {
          continue
        }
        if (!this.available(y, textHeight, item, textWidth)) {
          continue
        }
        const sprite = this.sprite(item, size, metrics, lane, y)
        this.active.push(sprite)
        this.nextExpiry = Math.min(this.nextExpiry, sprite.end)
        const firstBand = Math.floor(y / COLLISION_BAND_HEIGHT)
        const lastBand = Math.floor((y + textHeight) / COLLISION_BAND_HEIGHT)
        while (this.collisionBands.length <= lastBand) { this.collisionBands.push([]) }
        for (let band = firstBand; band <= lastBand; band++) {
          this.collisionBands[band].push(sprite)
        }
        break
      }
    }
    this.pruneExpired(time)
    for (const sprite of this.active) {
      sprite.x = sprite.item.mode === 1 ? width - (width + sprite.width) *
        (time - sprite.item.time) / SCROLL_DURATION : (width - sprite.width) / 2
    }
    this.lastTime = time
    return this.active
  }

  private validMetrics(metrics: DanmakuTextMetrics): boolean {
    return Number.isFinite(metrics.width) && metrics.width > 0 && Number.isFinite(metrics.ascent) &&
      Number.isFinite(metrics.descent) && metrics.ascent >= 0 && metrics.descent >= 0
  }

  private sprite(item: DanmakuItem, font: number, metrics: DanmakuTextMetrics, lane: number,
    y: number): DanmakuSprite {
    return {
      item: item, width: metrics.width, font: font, ascent: metrics.ascent,
      height: Math.ceil(metrics.ascent + metrics.descent) + 6, lane: lane, x: 0, y: y,
      end: item.time + (item.mode === 1 ? SCROLL_DURATION : FIXED_DURATION)
    }
  }

  private clearActive(): void {
    this.active.length = 0
    this.nextExpiry = Infinity
    for (const band of this.collisionBands) { band.length = 0 }
  }

  private pruneExpired(time: number): void {
    if (time < this.nextExpiry) { return }
    let count = 0
    this.nextExpiry = Infinity
    for (const sprite of this.active) {
      if (sprite.end > time) {
        this.active[count++] = sprite
        this.nextExpiry = Math.min(this.nextExpiry, sprite.end)
      }
    }
    this.active.length = count
    for (const band of this.collisionBands) {
      let retained = 0
      for (const sprite of band) {
        if (sprite.end > time) { band[retained++] = sprite }
      }
      band.length = retained
    }
  }

  private lowerBound(time: number): number {
    let lo = 0
    let hi = this.items.length
    while (lo < hi) {
      const mid = (lo + hi) >>> 1
      if (this.items[mid].time < time) {
        lo = mid + 1
      } else {
        hi = mid
      }
    }
    return lo
  }

  private available(y: number, height: number, item: DanmakuItem, textWidth: number): boolean {
    const firstBand = Math.floor(y / COLLISION_BAND_HEIGHT)
    const lastBand = Math.min(this.collisionBands.length - 1, Math.floor((y + height) / COLLISION_BAND_HEIGHT))
    for (let band = firstBand; band <= lastBand; band++) {
      for (const previous of this.collisionBands[band]) {
        // A tall sprite can occur in several bands. Check it only in the first shared band.
        if (band !== Math.max(firstBand, Math.floor(previous.y / COLLISION_BAND_HEIGHT))) { continue }
        if (y + height <= previous.y || previous.y + previous.height <= y) {
          continue
        }
        if (item.mode !== 1 || previous.item.mode !== 1) {
          return false
        }
        const oldSpeed = (this.width + previous.width) / SCROLL_DURATION
        const newSpeed = (this.width + textWidth) / SCROLL_DURATION
        const right = this.width + previous.width - oldSpeed * (item.time - previous.item.time)
        const gap = this.width - right
        if (gap < 12 || (newSpeed > oldSpeed && gap -
          (newSpeed - oldSpeed) * (previous.end - item.time) < 12)) {
          return false
        }
      }
    }
    return true
  }
}
