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

export class DanmakuParser {
  // Deliberately supports ordinary Bilibili XML only, never DTD or executable modes.
  static async parse(source: string, cancelled: () => boolean = (): boolean => false): Promise<DanmakuParseResult> {
    if (source.length > DANMAKU_MAX_BYTES || /<!DOCTYPE|<!ENTITY/i.test(source)) {
      throw new Error('文件过大或包含不支持的 XML 声明')
    }
    const xml = source.replace(/^\uFEFF/, '').replace(/<\?xml[^?]*\?>/i, '')
      .replace(/<!--[\s\S]*?-->/g, '').trim()
    if (!/^<i(?:\s[^>]*)?>[\s\S]*<\/i>\s*$/.test(xml)) {
      throw new Error('请选择 B 站格式的 XML 弹幕文件')
    }
    const result: DanmakuParseResult = { items: [], skipped: 0 }
    const pattern = /<d\b([^>]*)>([\s\S]*?)<\/d\s*>/g
    let match: RegExpExecArray | null = pattern.exec(xml)
    let count = 0
    while (match !== null) {
      if (cancelled()) {
        throw new Error('已取消导入')
      }
      count++
      if (count > MAX_ITEMS) {
        throw new Error('弹幕过多，最多支持 50000 条')
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
        result.items.push({ time: time, mode: mode <= 3 ? 1 : mode,
          size: Math.max(12, Math.min(40, size)), color: '#' + color.toString(16).padStart(6, '0'), text: text })
      } else {
        result.skipped++
      }
      if (count % 500 === 0) {
        await new Promise<void>((resolve: () => void): void => { setTimeout(resolve, 0) })
      }
      match = pattern.exec(xml)
    }
    if (result.items.length === 0) {
      throw new Error('文件中没有可显示的普通文本弹幕')
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
        (entity: string, code: string): string => {
          switch (code) {
            case 'amp': return '&'
            case 'lt': return '<'
            case 'gt': return '>'
            case 'quot': return '"'
            case 'apos': return "'"
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

  sample(position: number, stamp: number): void {
    this.position = Math.max(0, position)
    this.stamp = stamp
  }

  setState(running: boolean, rate: number, stamp: number): void {
    this.position = this.at(stamp)
    this.stamp = stamp
    this.running = running
    this.rate = Number.isFinite(rate) && rate > 0 ? rate : 1
  }

  at(stamp: number): number {
    // Bound extrapolation: an unreported stall must not run the entire timeline ahead.
    return this.position + (this.running ? Math.min(500, Math.max(0, stamp - this.stamp)) * this.rate : 0)
  }
}

export interface DanmakuSprite {
  item: DanmakuItem
  width: number
  font: number
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

  frame(time: number, width: number, height: number, font: number, area: number,
    measure: (text: string, size: number) => number): DanmakuSprite[] {
    if (width <= 0 || height <= 0) {
      return []
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
    const line = Math.ceil(font * 40 / 25) + 8
    const lanes = Math.min(16, Math.max(0, Math.floor((height * area - 16) / line)))
    let processed = 0
    while (this.cursor < this.items.length && this.items[this.cursor].time <= time) {
      const item = this.items[this.cursor++]
      this.active = this.active.filter((sprite: DanmakuSprite): boolean => sprite.end > item.time)
      if (++processed > 2000) {
        this.cursor = this.lowerBound(time + 0.001)
        break
      }
      const size = item.size * font / 25
      const textWidth = measure(item.text, size)
      const duration = item.mode === 1 ? SCROLL_DURATION : FIXED_DURATION
      if (lanes === 0 || this.active.length >= 120 || (item.mode !== 1 && textWidth > width - 16)) {
        continue
      }
      for (let row = 0; row < lanes; row++) {
        const lane = item.mode === 4 ? lanes - row - 1 : row
        if (!this.available(lane, item, textWidth)) {
          continue
        }
        this.active.push({ item: item, width: textWidth, font: size, lane: lane,
          x: 0, y: 8 + lane * line, end: item.time + duration })
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

  private available(lane: number, item: DanmakuItem, textWidth: number): boolean {
    for (const previous of this.active) {
      if (previous.lane !== lane) {
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
