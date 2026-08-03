import {
  create as mpvCreate,
  destroy as mpvDestroy,
  loadVideo as mpvLoadVideo,
  reset as mpvReset
} from 'libmpvnative.so'
import { EngineReleaseHook, PlayerEngineAdapter } from './PlayerEngineAdapter'

export class MpvPlayerEngineAdapter implements PlayerEngineAdapter {
  private nativeHandle: number | null = null

  get handle(): number | null {
    return this.nativeHandle
  }

  isCreated(): boolean {
    return this.nativeHandle !== null
  }

  create(): number | null {
    if (!this.nativeHandle) {
      this.nativeHandle = mpvCreate()
    }
    return this.nativeHandle
  }

  reset(): void {
    if (this.nativeHandle) {
      mpvReset(this.nativeHandle)
    }
  }

  load(url: string, startPosition?: number, subtitleTrackId?: number): void {
    if (this.nativeHandle) {
      mpvLoadVideo(this.nativeHandle, url, startPosition, subtitleTrackId)
    }
  }

  destroy(beforeNativeRelease?: EngineReleaseHook): void {
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
