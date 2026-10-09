import { displaySync } from '@kit.ArkGraphics2D'
import { LengthMetricsUnit } from '@kit.ArkUI'
import { systemDateTime } from '@kit.BasicServicesKit'
import { DanmakuClock, DanmakuScheduler, DanmakuSprite, DanmakuTextCache, DanmakuTextMetrics } from '../../utils/DanmakuCore'
import { DanmakuSession } from '../../utils/DanmakuSession'
import { DanmakuGL } from '../../utils/DanmakuGL'
import { salmonLogger } from 'salmonlogger'
import ToolsUtil from '../../utils/ToolsUtil'

/** Shared timeline with a dedicated transparent GL surface. */
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
  @Local renderFailed: boolean = false
  private gl: DanmakuGL = new DanmakuGL()
  private surface: XComponentController = new XComponentController()
  private measureContext: OffscreenCanvasRenderingContext2D =
    new OffscreenCanvasRenderingContext2D(1, 1, new RenderingContextSettings(true), LengthMetricsUnit.PX)
  private viewWidth: number = 0
  private viewHeight: number = 0
  private startupTimer: number = -1
  private preparationTimer: number = -1
  private mounted: boolean = false
  private wasSeeking: boolean = false
  private sync: displaySync.DisplaySync | undefined = undefined
  private clock: DanmakuClock = new DanmakuClock()
  private scheduler: DanmakuScheduler = new DanmakuScheduler()
  private measurements: DanmakuTextCache = new DanmakuTextCache()
  private measure: (text: string, font: number) => DanmakuTextMetrics =
    (text: string, font: number): DanmakuTextMetrics => this.measureText(text, font)
  private cachedMeasure: (text: string, font: number) => DanmakuTextMetrics | undefined =
    (text: string, font: number): DanmakuTextMetrics | undefined => this.measurements.get(`${font}:${text}`)
  private preparationNow: () => number = (): number => this.now()
  private preparationTime: number = 0
  private preparationFont: number = 0
  private preparationOffset: number = 0
  private ready: boolean = false
  private started: boolean = false

  aboutToAppear(): void {
    this.mounted = true
    this.scheduler.load(this.session.items)
    this.clock.sample(this.playbackTime, this.now(), true)
    this.sync = displaySync.create()
    this.sync.setExpectedFrameRateRange({ min: 30, max: 60, expected: 60 })
    this.sync.on('frame', (info: displaySync.IntervalInfo): void => {
      const now = this.now()
      const target = info.targetTimestamp / 1000000
      // Use the presentation cadence, rather than JS callback arrival jitter.
      this.draw(Number.isFinite(target) && target >= now && target - now <= 100 ? target : now)
    })
  }

  aboutToDisappear(): void {
    this.mounted = false
    this.releaseGL()
    this.ready = false
    this.sync?.stop()
    this.sync?.off('frame')
    this.sync = undefined
    this.started = false
    this.measurements.clear()
  }

  @Monitor('mediaKey')
  mediaChanged(): void {
    this.scheduler.reset()
    this.gl.cancelPreparation()
    this.clock.sample(this.playbackTime, this.now(), true)
    this.refresh()
  }

  @Monitor('session.items')
  sourceChanged(): void {
    this.scheduler.load(this.session.items)
    this.measurements.clear()
    if (!this.renderFailed && this.ready) {
      try {
        this.gl.clear()
      } catch (_) {
        this.failGL('清理文字纹理失败')
      }
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

  build() {
    Stack() {
      if (!this.renderFailed) {
        XComponent({ type: XComponentType.SURFACE, controller: this.surface })
          .width('100%')
          .height('100%')
          .backgroundColor(Color.Transparent)
          .hitTestBehavior(HitTestMode.None)
          .onLoad(() => {
            this.openGL()
          })
          .onDestroy(() => {
            this.ready = false
            this.sync?.stop()
            this.started = false
            this.releaseGL()
          })
      }
    }
    .width('100%')
    .height('100%')
    .clip(true)
    .hitTestBehavior(HitTestMode.None)
    .onSizeChange((_old: SizeOptions, size: SizeOptions) => {
      const width = Math.round(Number(size.width))
      const height = Math.round(Number(size.height))
      if (width === this.viewWidth && height === this.viewHeight) {
        return
      }
      this.viewWidth = width
      this.viewHeight = height
      this.scheduler.reset()
      this.gl.cancelPreparation()
      this.draw()
    })
  }

  private now(): number {
    return systemDateTime.getUptime(systemDateTime.TimeType.STARTUP)
  }

  private refresh(): void {
    const seekChanged = this.seeking !== this.wasSeeking
    if (seekChanged) {
      this.wasSeeking = this.seeking
      this.scheduler.reset()
      this.gl.cancelPreparation()
    }
    const running = this.visible && this.session.enabled && this.session.items.length > 0 &&
      this.playing && !this.buffering && !this.seeking
    this.clock.setState(running, this.speed, this.now())
    // Re-anchor on lifecycle/state changes, not the seek preview position.
    this.clock.sample(this.playbackTime, this.now(), seekChanged)
    if (this.ready && running && !this.started) {
      this.sync?.start()
      this.started = true
    } else if (!running && this.started) {
      this.sync?.stop()
      this.started = false
    }
    this.draw()
  }

  private draw(stamp: number = this.now()): void {
    if (!this.ready) {
      return
    }
    const width = Math.round(this.viewWidth)
    const height = Math.round(this.viewHeight)
    if (width <= 0 || height <= 0) {
      return
    }
    if (!this.visible || !this.session.enabled || this.seeking || this.session.items.length === 0) {
      this.drawGL([], width, height)
      return
    }
    if (this.preparationFont !== this.session.fontSize || this.preparationOffset !== this.session.offsetMs) {
      this.preparationFont = this.session.fontSize
      this.preparationOffset = this.session.offsetMs
      this.scheduler.reset()
      this.gl.cancelPreparation()
    }
    this.preparationTime = this.clock.at(stamp) - this.session.offsetMs
    const sprites = this.scheduler.frame(this.preparationTime,
      width, height, this.session.fontSize, this.session.area, this.cachedMeasure)
    this.drawGL(sprites, width, height)
  }

  private measureText(text: string, font: number): DanmakuTextMetrics {
    const key = `${font}:${text}`
    const cached = this.measurements.get(key)
    if (cached) { return cached }
    this.measureContext.font = `${font}px sans-serif`
    this.measureContext.textBaseline = 'alphabetic'
    const bounds = this.measureContext.measureText(text)
    const hasBounds = Number.isFinite(bounds.actualBoundingBoxAscent) &&
      Number.isFinite(bounds.actualBoundingBoxDescent) &&
      bounds.actualBoundingBoxAscent + bounds.actualBoundingBoxDescent > 0
    const measured: DanmakuTextMetrics = {
      width: bounds.width,
      ascent: hasBounds ? Math.max(0, bounds.actualBoundingBoxAscent) : font,
      descent: hasBounds ? Math.max(0, bounds.actualBoundingBoxDescent) : font * 0.3
    }
    this.measurements.set(key, measured)
    return measured
  }

  private drawGL(sprites: DanmakuSprite[], width: number, height: number): void {
    try {
      if (!this.gl.draw(sprites, width, height, this.session.opacity, this.preparationTime)) {
        this.failGL(`提交弹幕帧失败，状态：${this.gl.status()}`)
      } else {
        this.schedulePreparation()
      }
    } catch (_) {
      this.failGL('绘制弹幕失败')
    }
  }

  private preparationAhead(): number {
    return this.started ? Math.max(0, Math.min(2000, this.speed * 500)) : 0
  }

  private schedulePreparation(): void {
    if (this.preparationTimer >= 0 || !this.mounted || !this.ready || !this.visible ||
      !this.session.enabled || this.seeking ||
      (!this.gl.hasPendingTextures() &&
        !this.scheduler.hasPendingPreparation(this.preparationTime, this.preparationAhead()))) {
      return
    }
    this.preparationTimer = setTimeout(() => {
      this.preparationTimer = -1
      if (!this.mounted || !this.ready || !this.visible || !this.session.enabled || this.seeking) { return }
      try {
        const measured = this.scheduler.prepare(this.preparationTime, this.session.fontSize,
          this.preparationAhead(), this.measure, this.preparationNow)
        this.gl.prefetch(this.scheduler.upcoming())
        const prepared = this.gl.prepare()
        // During playback the next VSync presents it. Paused seeks drain a finite preparation queue.
        if (!this.started) {
          if (measured || prepared) {
            this.draw()
            this.schedulePreparation()
          }
        }
      } catch (_) {
        this.failGL('准备弹幕文字纹理失败')
      }
    }, this.started ? 0 : 16)
  }

  private releaseGL(): void {
    if (this.preparationTimer >= 0) {
      clearTimeout(this.preparationTimer)
      this.preparationTimer = -1
    }
    if (this.startupTimer >= 0) {
      clearTimeout(this.startupTimer)
      this.startupTimer = -1
    }
    try {
      this.gl.close()
    } catch (_) {
      salmonLogger.addLog('Danmaku', '释放弹幕渲染器失败', true)
    }
  }

  private failGL(reason: string): void {
    if (this.renderFailed || !this.mounted) {
      return
    }
    this.renderFailed = true
    this.ready = false
    this.sync?.stop()
    this.started = false
    this.releaseGL()
    salmonLogger.addLog('Danmaku', `弹幕渲染已停止：${reason}`, true)
    ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.danmaku_render_failed').id))
  }

  private openGL(): void {
    if (!this.mounted || this.renderFailed) {
      return
    }
    try {
      const surfaceId = this.surface.getXComponentSurfaceId()
      const onStatus = (status: number): void => {
        if (!this.mounted || this.renderFailed) {
          return
        }
        try {
          if (status < 0) {
            this.failGL('弹幕渲染器异常')
          } else if (status === 1 && !this.ready) {
            this.ready = true
            clearTimeout(this.startupTimer)
            this.startupTimer = -1
            this.refresh()
          }
        } catch (_) {
          this.failGL('处理弹幕状态失败')
        }
      }
      if (!surfaceId || !this.gl.open(surfaceId, this.getUIContext().vp2px(1), onStatus)) {
        this.failGL('创建弹幕渲染器失败')
        return
      }
      // One watchdog for a stuck initialization; readiness/failure comes from native events.
      this.startupTimer = setTimeout(() => {
        this.startupTimer = -1
        if (this.mounted && !this.renderFailed && !this.ready) { this.failGL('弹幕渲染器初始化超时') }
      }, 3000)
    } catch (_) {
      this.failGL('初始化弹幕渲染器异常')
    }
  }
}
