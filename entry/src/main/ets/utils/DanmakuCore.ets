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

export interface DanmakuTextMetrics {
  width: number
  ascent: number
  descent: number
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
    this.correction = smooth ? error : 0
    // Limit clock correction to 20% of playback speed, so movement never reverses.
    this.correctionDuration = Math.max(250, Math.abs(this.correction) / (this.rate * 0.2))
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
    // Bound extrapolation: an unreported stall must not run the entire timeline ahead.
    const elapsed = Math.min(500, Math.max(0, stamp - this.stamp))
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

  load(items: DanmakuItem[]): void {
    this.items = items
    this.reset()
  }

  reset(): void {
    this.active = []
    this.lastTime = -1
    this.cursor = 0
  }

  frame(time: number, width: number, height: number, font: number, area: number,
    measure: (text: string, size: number) => DanmakuTextMetrics): DanmakuSprite[] {
    if (width <= 0 || height <= 0) {
      return []
    }
    // Small engine timestamp jitter must not reconstruct lanes; explicit seeks call reset().
    if (time < this.lastTime && this.lastTime - time <= 250) {
      time = this.lastTime
    }
    const changed = width !== this.width || height !== this.height || font !== this.font || area !== this.area
    if (changed || this.lastTime < 0 || time < this.lastTime || time - this.lastTime > 1000) {
      this.active = []
      // Reconstruct a bounded window after seek; discard excess density, never queue a burst.
      this.cursor = Math.max(this.lowerBound(time - SCROLL_DURATION), this.lowerBound(time + 0.001) - 2000)
    }
    this.width = width
    this.height = height
    this.font = font
    this.area = area
    const regionHeight = height * Math.max(0, Math.min(1, area))
    let processed = 0
    while (this.cursor < this.items.length && this.items[this.cursor].time <= time) {
      const item = this.items[this.cursor++]
      this.active = this.active.filter((sprite: DanmakuSprite): boolean => sprite.end > item.time)
      if (++processed > 2000) {
        this.cursor = this.lowerBound(time + 0.001)
        break
      }
      const size = item.size * font / 10
      const metrics = measure(item.text, size)
      const textWidth = metrics.width
      // Tight glyph bounds plus outline padding; transparent raster space is not a lane.
      const textHeight = Math.ceil(metrics.ascent + metrics.descent) + 6
      const gap = Math.max(2, Math.round(8 - Math.max(0, size - 22) * 6 / 26))
      const line = textHeight + gap
      const lanes = Math.min(16, Math.max(0, Math.floor((regionHeight - 16 + gap) / line)))
      const duration = item.mode === 1 ? SCROLL_DURATION : FIXED_DURATION
      if (lanes === 0 || this.active.length >= 120 || (item.mode !== 1 && textWidth > width - 16)) {
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
        this.active.push({
          item: item,
          width: textWidth,
          font: size,
          ascent: metrics.ascent,
          height: textHeight,
          lane: lane,
          x: 0,
          y: y,
          end: item.time + duration
        })
        break
      }
    }
    this.active = this.active.filter((sprite: DanmakuSprite): boolean => sprite.end > time)
    this.active.forEach((sprite: DanmakuSprite): void => {
      sprite.x = sprite.item.mode === 1 ? width - (width + sprite.width) *
        (time - sprite.item.time) / SCROLL_DURATION : (width - sprite.width) / 2
    })
    this.lastTime = time
    return this.active
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
    for (const previous of this.active) {
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
    return true
  }
}
