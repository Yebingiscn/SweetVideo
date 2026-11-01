import { image } from '@kit.ImageKit'
import { captureSurfaceFrame, SurfaceCaptureFrame } from 'libmpvnative.so'
import { salmonLogger } from 'salmonlogger'
import ImageStorage from './ImageStorage'

export interface SurfaceScreenshotRequest {
  surfaceId: string
  width: number
  height: number
  hdrType: number
  requestId: number
  isCurrent: () => boolean
  isFrameCurrent: () => boolean
}

const TAG = 'SurfaceScreenshot'
const CAPTURE_BUDGET_MS = 100
const MAX_RETAINED_BYTES = 64 * 1024 * 1024

// Own only an independent, click-time copy. A queued save must not retain a
// decoder buffer, capture a later frame, or keep the native worker alive.
export class SurfaceScreenshotCandidate {
  private request: SurfaceScreenshotRequest
  private owned: image.PixelMap | undefined = undefined
  private ready: Promise<image.PixelMap | undefined>
  private finishReady: (value: image.PixelMap | undefined) => void = () => {}
  private disposal: Promise<void> | undefined = undefined
  private timer: number = -1
  private expired: boolean = false
  private disposed: boolean = false
  private claimed: boolean = false
  private nativeFinished: boolean = false
  private reservationReleased: boolean = false
  private releaseReservation: () => void

  constructor(request: SurfaceScreenshotRequest, releaseReservation: () => void) {
    this.request = request
    this.releaseReservation = releaseReservation
    this.ready = new Promise((resolve) => { this.finishReady = resolve })
    this.timer = setTimeout(() => {
      this.expired = true
      this.finishReady(undefined)
      this.log('fallback', 'deadline')
    }, CAPTURE_BUDGET_MS)
    void this.capture()
  }

  async take(): Promise<image.PixelMap | undefined> {
    const result = await this.ready
    if (this.claimed) return undefined
    if (this.disposed || !this.current(false)) {
      await this.dispose()
      return undefined
    }
    if (!result || this.owned !== result) return undefined
    this.claimed = true
    this.owned = undefined
    return result
  }

  dispose(): Promise<void> {
    if (this.disposal) return this.disposal
    this.disposed = true
    this.clearTimer()
    this.finishReady(undefined)
    const owned = this.owned
    this.owned = undefined
    this.disposal = this.release(owned).then(() => {
      if (this.nativeFinished) this.freeReservation()
    })
    return this.disposal
  }

  isStale(): boolean {
    return !this.claimed && !this.current(false)
  }

  private async capture(): Promise<void> {
    const startedAt = Date.now()
    let rejected: image.PixelMap | undefined = undefined
    let accepted = false
    try {
      if (!this.current(true)) return
      const captureTask: Promise<SurfaceCaptureFrame> = captureSurfaceFrame(this.request.surfaceId, this.request.width,
        this.request.height, this.request.hdrType !== 0, this.request.requestId)
      const frame = await captureTask
      rejected = frame.pixelMap
      if (!frame.success || !rejected) {
        this.log('fallback', 'native_unavailable', frame.errorCode)
        return
      }
      if (this.disposed || this.expired || !this.current(true) ||
        Date.now() - startedAt > CAPTURE_BUDGET_MS ||
        !Number.isFinite(frame.elapsedMs) || !Number.isFinite(frame.queueMs) ||
        frame.elapsedMs < 0 || frame.queueMs < 0 ||
        frame.elapsedMs + frame.queueMs > CAPTURE_BUDGET_MS) {
        this.log('fallback', 'stale_or_late')
        return
      }
      const info = rejected.getImageInfoSync()
      const hdr = this.request.hdrType !== 0
      const format = info.pixelFormat
      const validFormat = hdr ? format === image.PixelMapFormat.RGBA_1010102 ||
        format === image.PixelMapFormat.YCBCR_P010 || format === image.PixelMapFormat.YCRCB_P010 :
        format === image.PixelMapFormat.RGBA_8888 || format === image.PixelMapFormat.BGRA_8888 ||
          format === image.PixelMapFormat.RGB_888
      if (info.size.width !== this.request.width || info.size.height !== this.request.height ||
        info.isHdr !== hdr || !validFormat) {
        this.log('fallback', 'image_mismatch')
        return
      }
      this.owned = rejected
      rejected = undefined
      accepted = true
      this.finishReady(this.owned)
      this.log('ready', 'validated')
    } catch (_) {
      this.log('fallback', 'capture_failed')
    } finally {
      this.clearTimer()
      await this.release(rejected)
      this.nativeFinished = true
      if (!accepted) {
        this.finishReady(undefined)
        this.freeReservation()
      } else if (this.disposed) {
        const disposal: Promise<void> = this.disposal ?? Promise.resolve()
        await disposal
        this.freeReservation()
      }
    }
  }

  private current(checkFrame: boolean): boolean {
    try {
      return this.request.isCurrent() && (!checkFrame || this.request.isFrameCurrent())
    } catch (_) {
      return false
    }
  }

  private clearTimer(): void {
    if (this.timer < 0) return
    clearTimeout(this.timer)
    this.timer = -1
  }

  private freeReservation(): void {
    if (this.reservationReleased) return
    this.reservationReleased = true
    this.releaseReservation()
  }

  private async release(pixelMap: image.PixelMap | undefined): Promise<void> {
    try {
      await ImageStorage.releaseImageSafely(pixelMap, 'Surface截图像素图')
    } catch (_) {
      this.log('cleanup', 'release_failed')
    }
  }

  private log(event: string, reason: string, code: number = 0): void {
    salmonLogger.addLog(TAG, `[Screenshot#${this.request.requestId}] surface=${event}, reason=${reason}, ` +
      `code=${Number.isFinite(code) ? code : 0}`, false)
  }
}

export class SurfaceScreenshotCapture {
  private static candidates: Map<number, SurfaceScreenshotCandidate> = new Map()
  private static retainedBytes: number = 0

  static prepare(request: SurfaceScreenshotRequest): SurfaceScreenshotCandidate | undefined {
    SurfaceScreenshotCapture.discardStale()
    const bytes = request.width * request.height * 4
    if (!/^[0-9]{1,32}$/.test(request.surfaceId) ||
      !Number.isInteger(request.width) || !Number.isInteger(request.height) ||
      request.width <= 0 || request.height <= 0 || request.width > 8192 || request.height > 8192 ||
      !Number.isInteger(request.hdrType) || request.hdrType < 0 || request.hdrType > 3 ||
      !Number.isSafeInteger(request.requestId) || request.requestId <= 0 ||
      SurfaceScreenshotCapture.candidates.has(request.requestId) || SurfaceScreenshotCapture.candidates.size >= 2 ||
      SurfaceScreenshotCapture.retainedBytes + bytes > MAX_RETAINED_BYTES) return undefined
    SurfaceScreenshotCapture.retainedBytes += bytes
    const candidate = new SurfaceScreenshotCandidate(request, () => {
      SurfaceScreenshotCapture.retainedBytes -= bytes
      SurfaceScreenshotCapture.candidates.delete(request.requestId)
    })
    SurfaceScreenshotCapture.candidates.set(request.requestId, candidate)
    return candidate
  }

  static discardStale(): void {
    SurfaceScreenshotCapture.candidates.forEach((candidate: SurfaceScreenshotCandidate) => {
      if (candidate.isStale()) void candidate.dispose()
    })
  }
}
