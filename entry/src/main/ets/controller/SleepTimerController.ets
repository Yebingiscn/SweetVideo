import { systemDateTime } from '@kit.BasicServicesKit'

export type SleepTimerMode = 'off' | 'countdown' | 'end-current'

export interface SleepTimerRuntime {
  now(): number
  schedule(callback: () => void, delayMs: number): number
  cancel(timerId: number): void
}

class SystemSleepTimerRuntime implements SleepTimerRuntime {
  now(): number {
    // STARTUP includes deep sleep and is unaffected by wall-clock adjustments.
    return systemDateTime.getUptime(systemDateTime.TimeType.STARTUP, false)
  }

  schedule(callback: () => void, delayMs: number): number {
    return setTimeout(callback, delayMs)
  }

  cancel(timerId: number): void {
    clearTimeout(timerId)
  }
}

const MAX_TIMEOUT_MS = 2147483647

// Owned by a playback session, not by a menu or an individual media engine.
@ObservedV2
export class SleepTimerController {
  @Trace mode: SleepTimerMode = 'off'
  @Trace remainingMs: number = 0
  onExpired: () => void = (): void => {}

  private runtime: SleepTimerRuntime
  private deadlineMs: number = 0
  private mediaKey: string = ''
  private timerId: number | undefined = undefined
  private version: number = 0
  private disposed: boolean = false

  constructor(runtime: SleepTimerRuntime = new SystemSleepTimerRuntime()) {
    this.runtime = runtime
  }

  start(durationMs: number): void {
    if (this.disposed || !Number.isFinite(durationMs) || durationMs <= 0) {
      return
    }
    const deadline = this.runtime.now() + durationMs
    if (!Number.isFinite(deadline)) { return }
    this.cancel()
    this.mode = 'countdown'
    this.deadlineMs = deadline
    this.remainingMs = durationMs
    this.scheduleDeadline()
  }

  stopAfterCurrent(mediaKey: string): void {
    if (this.disposed || mediaKey.length === 0) { return }
    this.cancel()
    this.mode = 'end-current'
    this.mediaKey = mediaKey
  }

  cancel(): void {
    this.version++
    if (this.timerId !== undefined) {
      this.runtime.cancel(this.timerId)
      this.timerId = undefined
    }
    this.mode = 'off'
    this.remainingMs = 0
    this.deadlineMs = 0
    this.mediaKey = ''
  }

  // Playback updates and foreground restoration can catch a delayed JS timeout.
  // Reading the monotonic deadline also refreshes the displayed remaining time.
  checkDeadline(): boolean {
    if (this.disposed || this.mode !== 'countdown') { return false }
    this.remainingMs = Math.max(0, this.deadlineMs - this.runtime.now())
    if (this.remainingMs > 0) { return false }
    this.expire()
    return true
  }

  consumeMediaEnd(mediaKey: string): boolean {
    if (this.disposed || this.mode !== 'end-current' || this.mediaKey !== mediaKey) {
      return false
    }
    this.expire()
    return true
  }

  onMediaChanged(mediaKey: string): void {
    if (this.disposed) { return }
    if (this.mode === 'end-current' && this.mediaKey !== mediaKey) {
      this.cancel()
    } else {
      this.checkDeadline()
    }
  }

  dispose(): void {
    if (this.disposed) { return }
    this.disposed = true
    this.cancel()
    this.onExpired = (): void => {}
  }

  private expire(): void {
    // Clear first: an end event and timeout may arrive together or re-enter.
    this.cancel()
    this.onExpired()
  }

  private scheduleDeadline(): void {
    const version = this.version
    this.timerId = this.runtime.schedule((): void => {
      if (this.disposed || version !== this.version || this.mode !== 'countdown') {
        return
      }
      this.timerId = undefined
      if (!this.checkDeadline()) {
        // Long durations are split to avoid timeout overflow. An early timer
        // wakeup is also measured against the original deadline, not restarted.
        this.scheduleDeadline()
      }
    }, Math.min(MAX_TIMEOUT_MS, Math.max(1, this.remainingMs)))
  }
}
