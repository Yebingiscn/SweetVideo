import { danmakuCreate, danmakuDestroy, danmakuFrame, danmakuStatus, danmakuTexture } from 'libmpvnative.so'
import { DanmakuSprite } from './DanmakuCore'
import { LengthMetricsUnit } from '@kit.ArkUI'

interface TextTexture {
  id: number
  width: number
  height: number
  bytes: number
}

/** Rasterize a text only on cache miss; animation submits positions instead of drawing text again. */
export class DanmakuGL {
  private handle: number = 0
  private nextId: number = 0
  private textures: Map<string, TextTexture> = new Map()
  private bytes: number = 0
  private scale: number = 1
  private readonly padding: number = 3

  open(surfaceId: string, scale: number): boolean {
    this.close()
    this.scale = Math.max(1, Math.min(3, scale))
    this.handle = danmakuCreate(surfaceId)
    return this.handle > 0
  }

  status(): number {
    return this.handle > 0 ? danmakuStatus(this.handle) : -1
  }

  close(): void {
    const handle = this.handle
    this.handle = 0
    this.textures.clear()
    this.bytes = 0
    if (handle > 0) {
      danmakuDestroy(handle)
    }
  }

  clear(): void {
    for (const texture of this.textures.values()) {
      if (!danmakuTexture(this.handle, texture.id, 0, 0, new ArrayBuffer(0))) {
        throw new Error('弹幕纹理释放失败')
      }
    }
    this.textures.clear()
    this.bytes = 0
  }

  private key(sprite: DanmakuSprite): string {
    return `${sprite.font}:${sprite.item.color}:${sprite.item.text}`
  }

  private texture(sprite: DanmakuSprite, keep: Set<string>): TextTexture {
    const key = this.key(sprite)
    const cached = this.textures.get(key)
    if (cached) {
      this.textures.delete(key)
      this.textures.set(key, cached)
      return cached
    }
    const width = Math.ceil((sprite.width + 2 * this.padding) * this.scale)
    const height = Math.ceil((sprite.font * 2 + 2 * this.padding) * this.scale)
    const bytes = width * height * 4
    if (width > 8192 || height > 2048 || bytes > 4 * 1024 * 1024 || this.nextId >= 16000000) {
      throw new Error('弹幕纹理超出限制')
    }
    for (const entry of this.textures.entries()) {
      if (this.bytes + bytes <= 24 * 1024 * 1024 && this.textures.size < 256) {
        break
      }
      if (!keep.has(entry[0])) {
        if (!danmakuTexture(this.handle, entry[1].id, 0, 0, new ArrayBuffer(0))) {
          throw new Error('弹幕纹理释放失败')
        }
        this.bytes -= entry[1].bytes
        this.textures.delete(entry[0])
      }
    }
    if (this.bytes + bytes > 24 * 1024 * 1024) {
      throw new Error('弹幕纹理缓存已满')
    }
    const canvas = new OffscreenCanvasRenderingContext2D(width, height,
      new RenderingContextSettings(true), LengthMetricsUnit.PX)
    canvas.font = `${sprite.font * this.scale}px sans-serif`
    canvas.textBaseline = 'top'
    canvas.lineWidth = 2 * this.scale
    canvas.strokeStyle = '#000000'
    canvas.fillStyle = sprite.item.color
    const padding = this.padding * this.scale
    canvas.strokeText(sprite.item.text, padding, padding)
    canvas.fillText(sprite.item.text, padding, padding)
    const data = canvas.getImageData(0, 0, width, height)
    const id = ++this.nextId
    if (!danmakuTexture(this.handle, id, width, height, data.data.buffer as ArrayBuffer)) {
      throw new Error('弹幕纹理上传失败')
    }
    const texture: TextTexture = { id: id, width: width / this.scale, height: height / this.scale, bytes: bytes }
    this.textures.set(key, texture)
    this.bytes += bytes
    return texture
  }

  draw(sprites: DanmakuSprite[], width: number, height: number, opacity: number): boolean {
    const keep = new Set<string>(sprites.map((sprite: DanmakuSprite): string => this.key(sprite)))
    const positions = new Float32Array(sprites.length * 5)
    for (let i = 0; i < sprites.length; i++) {
      const sprite = sprites[i]
      const texture = this.texture(sprite, keep)
      positions[i * 5] = texture.id
      positions[i * 5 + 1] = sprite.x - this.padding
      positions[i * 5 + 2] = sprite.y - this.padding
      positions[i * 5 + 3] = texture.width
      positions[i * 5 + 4] = texture.height
    }
    return danmakuFrame(this.handle, positions, width, height, opacity)
  }
}
