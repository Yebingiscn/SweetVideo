import { danmakuCacheLimit, danmakuCreate, danmakuDestroy, danmakuFrame, danmakuStatus, danmakuTexture } from 'libmpvnative.so'
import { DANMAKU_MAX_ACTIVE, DanmakuSprite } from './DanmakuCore'
import { LengthMetricsUnit } from '@kit.ArkUI'
import ToolsUtil from './ToolsUtil.ets'

interface TextTexture {
  id: number
  width: number
  height: number
  bytes: number
  used: number
}

/** Rasterize a text only on cache miss; animation submits positions instead of drawing text again. */
export class DanmakuGL {
  private handle: number = 0
  private generation: number = 0
  private nextId: number = 0
  private textures: Map<string, TextTexture> = new Map()
  private bytes: number = 0
  private scale: number = 1
  private readonly padding: number = 3
  private readonly maxTextureBytes: number = 4 * 1024 * 1024
  private readonly cacheBytes: number = danmakuCacheLimit
  private positions: Float32Array = new Float32Array(DANMAKU_MAX_ACTIVE * 5)
  private positionViews: Map<number, Float32Array> = new Map()
  private keep: Set<string> = new Set()
  private nextKeep: Set<string> = new Set()
  private budgetBlocked: Set<string> = new Set()
  private spriteKeys: WeakMap<DanmakuSprite, string> = new WeakMap()
  private pendingSprites: DanmakuSprite[] = []
  private pendingKeys: Set<string> = new Set()
  private rejected: Set<string> = new Set()
  private generatedTextures: number = 0
  private emptyPixels: ArrayBuffer = new ArrayBuffer(0)
  private upcomingSprites: DanmakuSprite[] = []
  private upcomingKeys: Set<string> = new Set()
  private cacheTick: number = 0
  private uploadsPending: boolean = false
  private emptyPresented: boolean = false
  private lastWidth: number = 0
  private lastHeight: number = 0

  open(surfaceId: string, scale: number, onStatus: (status: number) => void): boolean {
    this.close()
    // Rasterize at the actual density; a fixed cap stretches glyphs on denser displays.
    this.scale = Number.isFinite(scale) && scale > 0 ? scale : 1
    const generation = this.generation
    this.handle = danmakuCreate(surfaceId, (status: number): void => {
      if (this.handle > 0 && generation === this.generation) { onStatus(status) }
    })
    return this.handle > 0
  }

  status(): number {
    return this.handle > 0 ? danmakuStatus(this.handle) : -1
  }

  close(): void {
    this.generation++
    const handle = this.handle
    this.handle = 0
    this.textures.clear()
    this.rejected.clear()
    this.keep.clear()
    this.nextKeep.clear()
    this.budgetBlocked.clear()
    this.cancelPreparation()
    this.spriteKeys = new WeakMap()
    this.bytes = 0
    this.nextId = 0
    this.cacheTick = 0
    this.uploadsPending = false
    this.emptyPresented = false
    if (handle > 0) {
      danmakuDestroy(handle)
    }
  }

  clear(): void {
    for (const texture of this.textures.values()) {
      if (!danmakuTexture(this.handle, texture.id, 0, 0, this.emptyPixels)) {
        throw new Error(ToolsUtil.getStringResource($r('app.string.danmaku_texture_release_failed').id))
      }
      this.uploadsPending = true
    }
    this.textures.clear()
    this.rejected.clear()
    this.cancelPreparation()
    this.keep.clear()
    this.nextKeep.clear()
    this.budgetBlocked.clear()
    this.emptyPresented = false
    this.bytes = 0
  }

  private key(sprite: DanmakuSprite): string {
    let key = this.spriteKeys.get(sprite)
    if (key === undefined) {
      key = `${sprite.font}:${sprite.item.color}:${sprite.item.text}`
      this.spriteKeys.set(sprite, key)
    }
    return key
  }

  hasPendingTextures(): boolean {
    return this.pendingSprites.length > 0 || this.upcomingSprites.length > 0
  }

  cancelPreparation(): void {
    this.pendingSprites.length = 0
    this.pendingKeys.clear()
    this.upcomingSprites.length = 0
    this.upcomingKeys.clear()
  }

  prefetch(sprites: DanmakuSprite[]): void {
    for (const sprite of sprites) {
      const key = this.key(sprite)
      if (this.upcomingSprites.length >= 64) { break }
      if (!this.textures.has(key) && !this.rejected.has(key) && !this.upcomingKeys.has(key)) {
        this.upcomingKeys.add(key)
        this.upcomingSprites.push(sprite)
      }
    }
  }

  /** One raster/upload per task, outside the animation frame callback. */
  prepare(): boolean {
    this.generatedTextures = 0
    while (this.hasPendingTextures()) {
      const sprite = this.pendingSprites.length > 0 ? this.pendingSprites.shift()! : this.upcomingSprites.shift()!
      this.upcomingKeys.delete(this.key(sprite))
      if (this.texture(sprite)) { return true }
      // Invalid/cache-blocked entries do not prevent a smaller comment being prepared.
      if (this.generatedTextures > 0) { break }
    }
    // A failed raster may already have evicted textures. Flush those releases even while paused.
    return this.uploadsPending
  }

  private reject(key: string): void {
    if (this.rejected.size >= 256) {
      for (const oldest of this.rejected) {
        this.rejected.delete(oldest)
        break
      }
    }
    this.rejected.add(key)
  }

  private texture(sprite: DanmakuSprite): TextTexture | undefined {
    const key = this.key(sprite)
    const cached = this.textures.get(key)
    if (cached) {
      cached.used = this.cacheTick
      return cached
    }
    if (this.rejected.has(key) || this.budgetBlocked.has(key)) { return undefined }
    const width = Math.ceil((sprite.width + 2 * this.padding) * this.scale)
    const height = Math.ceil(sprite.height * this.scale)
    const bytes = width * height * 4
    // Bound individual raster work. A malformed/oversized comment cannot stop the renderer.
    if (!Number.isFinite(bytes) || width <= 0 || height <= 0 || width > 2048 || height > 512 ||
      bytes > this.maxTextureBytes || this.nextId >= 16000000) {
      this.reject(key)
      return undefined
    }
    while (this.bytes + bytes > this.cacheBytes || this.textures.size >= 256) {
      let oldest: TextTexture | undefined = undefined
      let oldestKey: string = ''
      for (const entry of this.textures.entries()) {
        if (!this.keep.has(entry[0]) && (!oldest || entry[1].used < oldest.used)) {
          oldest = entry[1]
          oldestKey = entry[0]
        }
      }
      if (!oldest) {
        this.budgetBlocked.add(key)
        return undefined
      }
      if (!danmakuTexture(this.handle, oldest.id, 0, 0, this.emptyPixels)) {
        throw new Error(ToolsUtil.getStringResource($r('app.string.danmaku_texture_release_failed').id))
      }
      this.uploadsPending = true
      this.bytes -= oldest.bytes
      this.textures.delete(oldestKey)
    }
    if (this.bytes + bytes > this.cacheBytes || this.textures.size >= 256) {
      return undefined
    }
    this.generatedTextures++
    let pixels: ArrayBuffer
    try {
      const canvas = new OffscreenCanvasRenderingContext2D(width, height,
        new RenderingContextSettings(true), LengthMetricsUnit.PX)
      canvas.font = `${sprite.font * this.scale}px sans-serif`
      canvas.textBaseline = 'alphabetic'
      canvas.lineWidth = 2 * this.scale
      canvas.strokeStyle = '#000000'
      canvas.fillStyle = sprite.item.color
      const padding = this.padding * this.scale
      const baseline = padding + sprite.ascent * this.scale
      canvas.strokeText(sprite.item.text, padding, baseline)
      canvas.fillText(sprite.item.text, padding, baseline)
      pixels = canvas.getImageData(0, 0, width, height).data.buffer as ArrayBuffer
    } catch (_) {
      this.reject(key)
      return undefined
    }
    const id = ++this.nextId
    if (!danmakuTexture(this.handle, id, width, height, pixels)) {
      if (this.status() < 0) {
        throw new Error(ToolsUtil.getStringResource($r('app.string.danmaku_texture_upload_failed').id))
      }
      // Upload pressure is transient. Retry on a later playback frame, without spinning while paused.
      return undefined
    }
    const texture: TextTexture = {
      id: id, width: width / this.scale, height: height / this.scale, bytes: bytes, used: this.cacheTick
    }
    this.textures.set(key, texture)
    this.bytes += bytes
    this.uploadsPending = true
    return texture
  }

  draw(sprites: DanmakuSprite[], width: number, height: number, opacity: number, time: number = 0): boolean {
    this.cacheTick++
    let upcoming = 0
    this.upcomingKeys.clear()
    for (const sprite of this.upcomingSprites) {
      const key = this.key(sprite)
      if (sprite.item.time > time && !this.textures.has(key) && !this.rejected.has(key)) {
        this.upcomingSprites[upcoming++] = sprite
        this.upcomingKeys.add(key)
      }
    }
    this.upcomingSprites.length = upcoming
    this.nextKeep.clear()
    this.pendingSprites.length = 0
    this.pendingKeys.clear()
    const limit = Math.min(sprites.length, DANMAKU_MAX_ACTIVE)
    let keepChanged = false
    for (let i = 0; i < limit; i++) {
      const key = this.key(sprites[i])
      this.nextKeep.add(key)
      if (!this.keep.has(key)) { keepChanged = true }
    }
    if (keepChanged || this.nextKeep.size !== this.keep.size) { this.budgetBlocked.clear() }
    const previousKeep = this.keep
    this.keep = this.nextKeep
    this.nextKeep = previousKeep
    let count = 0
    for (let i = 0; i < limit; i++) {
      const sprite = sprites[i]
      const key = this.key(sprite)
      const texture = this.textures.get(key)
      if (!texture) {
        if (!this.rejected.has(key) && !this.pendingKeys.has(key)) {
          this.pendingKeys.add(key)
          this.pendingSprites.push(sprite)
        }
        continue
      }
      texture.used = this.cacheTick
      this.positions[count * 5] = texture.id
      this.positions[count * 5 + 1] = sprite.x - this.padding
      this.positions[count * 5 + 2] = sprite.y - this.padding
      this.positions[count * 5 + 3] = texture.width
      this.positions[count * 5 + 4] = texture.height
      count++
    }
    if (count === 0 && this.emptyPresented && width === this.lastWidth && height === this.lastHeight &&
      !this.uploadsPending) { return true }
    let positions = this.positionViews.get(count)
    if (!positions) {
      positions = this.positions.subarray(0, count * 5)
      this.positionViews.set(count, positions)
    }
    // Native Submit copies this view synchronously; reusing it cannot mutate an in-flight frame.
    const submitted = danmakuFrame(this.handle, positions, width, height, opacity)
    if (submitted) {
      this.emptyPresented = count === 0
      this.lastWidth = width
      this.lastHeight = height
      this.uploadsPending = false
    }
    return submitted
  }
}
