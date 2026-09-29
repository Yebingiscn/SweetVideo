import { displaySync } from '@kit.ArkGraphics2D'
import { LengthMetricsUnit } from '@kit.ArkUI'
import { systemDateTime } from '@kit.BasicServicesKit'
import { DanmakuClock, DanmakuScheduler, DanmakuSprite } from '../../utils/DanmakuCore'
import { DanmakuSession } from '../../utils/DanmakuSession'
import { DanmakuGL } from '../../utils/DanmakuGL'
import { salmonLogger } from 'salmonlogger'

/** Shared timeline with a dedicated transparent GL surface and a Canvas fallback. */
@ComponentV2
export struct DanmakuOverlay {
  @Param session: DanmakuSession = new DanmakuSession()
  @Param mediaKey: string = ''
  @Param playbackTime: number = 0
  @Param playing: boolean = false
  @Param buffering: boolean = false
  @Param seeking: boolean = false
  @Param speed: number = 1
  @Param visible: boolean = true
  @Local useGL: boolean = true
  private gl: DanmakuGL = new DanmakuGL()
  private surface: XComponentController = new XComponentController()
  private measureContext: OffscreenCanvasRenderingContext2D =
    new OffscreenCanvasRenderingContext2D(1, 1, new RenderingContextSettings(true), LengthMetricsUnit.PX)
  private viewWidth: number = 0
  private viewHeight: number = 0
  private healthTimer: number = -1
  private mounted: boolean = false
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true))
  private sync: displaySync.DisplaySync | undefined = undefined
  private clock: DanmakuClock = new DanmakuClock()
  private scheduler: DanmakuScheduler = new DanmakuScheduler()
  private widths: Map<string, number> = new Map()
  private ready: boolean = false
  private started: boolean = false

  aboutToAppear(): void {
    this.mounted = true
    this.scheduler.load(this.session.items)
    this.clock.sample(this.playbackTime, this.now())
    this.sync = displaySync.create()
    this.sync.setExpectedFrameRateRange({ min: 30, max: 60, expected: 60 })
    this.sync.on('frame', (): void => { this.draw() })
  }

  aboutToDisappear(): void {
    this.mounted = false
    this.releaseGL()
    this.ready = false
    this.sync?.stop()
    this.sync?.off('frame')
    this.sync = undefined
    this.started = false
    this.widths.clear()
  }

  @Monitor('mediaKey')
  mediaChanged(): void {
    this.scheduler.reset()
    this.clock.sample(this.playbackTime, this.now())
    this.refresh()
  }

  @Monitor('session.items')
  sourceChanged(): void {
    this.scheduler.load(this.session.items)
    this.widths.clear()
    if (this.useGL && this.ready) {
      try { this.gl.clear() } catch (_) { this.fallback() }
    }
    this.refresh()
  }

  @Monitor('playbackTime')
  positionChanged(): void {
    this.clock.sample(this.playbackTime, this.now())
    if (!this.started) {
      this.draw()
    }
  }

  @Monitor('playing', 'buffering', 'seeking', 'speed', 'visible', 'session.enabled',
    'session.fontSize', 'session.opacity', 'session.area', 'session.offsetMs')
  stateChanged(): void {
    this.refresh()
  }

  private now(): number {
    return systemDateTime.getUptime(systemDateTime.TimeType.STARTUP)
  }

  private refresh(): void {
    const running = this.visible && this.session.enabled && this.session.items.length > 0 &&
      this.playing && !this.buffering && !this.seeking
    this.clock.setState(running, this.speed, this.now())
    // Re-anchor on lifecycle/state changes, not the seek preview position.
    this.clock.sample(this.playbackTime, this.now())
    if (this.ready && running && !this.started) {
      this.sync?.start()
      this.started = true
    } else if (!running && this.started) {
      this.sync?.stop()
      this.started = false
    }
    this.draw()
  }

  private draw(): void {
    if (!this.ready) {
      return
    }
    const width = this.useGL ? this.viewWidth : this.context.width
    const height = this.useGL ? this.viewHeight : this.context.height
    if (width <= 0 || height <= 0) {
      return
    }
    if (!this.useGL) {
      this.context.clearRect(0, 0, width, height)
    }
    if (!this.visible || !this.session.enabled || this.seeking || this.session.items.length === 0) {
      if (this.useGL) {
        this.drawGL([], width, height)
      }
      return
    }
    const sprites = this.scheduler.frame(this.clock.at(this.now()) - this.session.offsetMs,
      width, height, this.session.fontSize, this.session.area,
      (text: string, font: number): number => {
        const key = `${font}:${text}`
        const cached = this.widths.get(key)
        if (cached !== undefined) {
          return cached
        }
        this.measureContext.font = `${font}px sans-serif`
        const measured = this.measureContext.measureText(text).width
        if (this.widths.size >= 4096) {
          this.widths.clear()
        }
        this.widths.set(key, measured)
        return measured
      })
    if (this.useGL) {
      this.drawGL(sprites, width, height)
      return
    }
    this.context.globalAlpha = this.session.opacity
    this.context.textBaseline = 'top'
    this.context.lineWidth = 2
    this.context.strokeStyle = '#000000'
    sprites.forEach((sprite: DanmakuSprite): void => {
      this.context.font = `${sprite.font}px sans-serif`
      this.context.fillStyle = sprite.item.color
      this.context.strokeText(sprite.item.text, sprite.x, sprite.y)
      this.context.fillText(sprite.item.text, sprite.x, sprite.y)
    })
  }

  private drawGL(sprites: DanmakuSprite[], width: number, height: number): void {
    try {
      if (!this.gl.draw(sprites, width, height, this.session.opacity)) {
        this.fallback()
      }
    } catch (_) {
      this.fallback()
    }
  }

  private releaseGL(): void {
    if (this.healthTimer >= 0) {
      clearInterval(this.healthTimer)
      this.healthTimer = -1
    }
    this.gl.close()
  }

  private fallback(): void {
    if (!this.useGL || !this.mounted) {
      return
    }
    salmonLogger.addLog('Danmaku', 'OpenGL 弹幕不可用，回退 Canvas', true)
    this.ready = false
    this.sync?.stop()
    this.started = false
    this.releaseGL()
    this.useGL = false
  }

  private openGL(): void {
    if (!this.mounted || !this.useGL) {
      return
    }
    try {
      const surfaceId = this.surface.getXComponentSurfaceId()
      if (!surfaceId || !this.gl.open(surfaceId, this.getUIContext().vp2px(1))) {
        this.fallback()
        return
      }
      const start = this.now()
      this.healthTimer = setInterval(() => {
        if (!this.mounted || !this.useGL) {
          return
        }
        const status = this.gl.status()
        if (status < 0 || (status === 0 && this.now() - start > 3000)) {
          this.fallback()
        }
      }, 250)
      this.ready = true
      this.refresh()
    } catch (_) {
      this.fallback()
    }
  }

  build() {
    Stack() {
      if (this.useGL) {
        XComponent({ type: XComponentType.TEXTURE, controller: this.surface })
          .width('100%')
          .height('100%')
          .backgroundColor(Color.Transparent)
          .hitTestBehavior(HitTestMode.None)
          .onLoad(() => { this.openGL() })
          .onDestroy(() => {
            if (this.useGL) {
              this.ready = false
              this.sync?.stop()
              this.started = false
              this.releaseGL()
            }
          })
      } else {
        Canvas(this.context)
          .width('100%')
          .height('100%')
          .onReady(() => {
            this.ready = true
            this.refresh()
          })
      }
    }
      .width('100%')
      .height('100%')
      .clip(true)
      .hitTestBehavior(HitTestMode.None)
      .onSizeChange((_old: SizeOptions, size: SizeOptions) => {
        this.viewWidth = Number(size.width)
        this.viewHeight = Number(size.height)
        this.scheduler.reset()
        this.draw()
      })
  }
}
