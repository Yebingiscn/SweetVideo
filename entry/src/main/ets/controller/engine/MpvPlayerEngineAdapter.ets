import {
  create as mpvCreate,
  destroy as mpvDestroy,
  loadVideo as mpvLoadVideo,
  isCoreAlive as mpvIsCoreAlive,
  reset as mpvReset
} from 'libmpvnative.so'
import { EngineReleaseHook, PlayerEngineAdapter } from './PlayerEngineAdapter'

export class MpvPlayerEngineAdapter implements PlayerEngineAdapter {
  private nativeHandle: number | null = null
  private loadRequestId: number = 0
  private mediaLoaded: boolean = false

  get handle(): number | null {
    return this.nativeHandle
  }

  isCreated(): boolean {
    return this.nativeHandle !== null
  }

  isAlive(): boolean {
    return this.nativeHandle !== null && mpvIsCoreAlive()
  }

  invalidateLoad(): void {
    this.loadRequestId = 0
    this.mediaLoaded = false
  }

  acceptsEvent(requestId: number): boolean {
    return requestId > 0 && requestId === this.loadRequestId && this.nativeHandle !== null
  }

  markLoaded(requestId: number): void {
    if (this.acceptsEvent(requestId)) {
      this.mediaLoaded = true
    }
  }

  isMediaLoaded(): boolean {
    return this.mediaLoaded
  }

  create(): number | null {
    if (!this.nativeHandle) {
      this.nativeHandle = mpvCreate()
    }
    return this.nativeHandle
  }

  reset(): void {
    if (this.nativeHandle) {
      this.invalidateLoad()
      const newHandle = mpvReset(this.nativeHandle)
      if (typeof newHandle !== 'number' || newHandle <= 0) {
        throw new Error('MPV reset failed')
      }
      this.nativeHandle = newHandle
    }
  }

  load(url: string, startPosition?: number, subtitleTrackId?: number, userAgent?: string): void {
    this.invalidateLoad()
    if (!this.nativeHandle || !this.isAlive()) {
      throw new Error('MPV core is not alive')
    }
    const requestId = mpvLoadVideo(this.nativeHandle, url, startPosition, subtitleTrackId, userAgent)
    if (!Number.isSafeInteger(requestId) || requestId <= 0) {
      throw new Error('MPV loadfile did not return a valid request ID')
    }
    this.loadRequestId = requestId
  }

  destroy(beforeNativeRelease?: EngineReleaseHook): void {
    this.invalidateLoad()
    const handle = this.nativeHandle
    if (!handle) {
      return
    }
    this.nativeHandle = null
    try {
      beforeNativeRelease?.()
    } finally {
      mpvDestroy(handle)
    }
  }

  async release(beforeNativeRelease?: EngineReleaseHook): Promise<void> {
    this.destroy(beforeNativeRelease)
  }
}
