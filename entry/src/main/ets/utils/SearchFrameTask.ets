import { FrameCallback } from '@kit.ArkUI'

// Run after a rendered frame. A queued task from onFrame also guarantees progress
// when onIdle is continually deferred because the renderer has no idle budget.
export class SearchFrameTask extends FrameCallback {
  private action: (() => void) | undefined
  private queued: boolean = false
  private timer: number | undefined = undefined

  constructor(action: () => void) {
    super()
    this.action = action
  }

  onFrame(_frameTimeInNano: number): void {
    if (!this.action || this.queued) {
      return
    }
    this.queued = true
    this.timer = setTimeout(() => {
      this.timer = undefined
      this.run()
    }, 0)
  }

  onIdle(_timeLeftInNano: number): void {
    this.run()
  }

  cancel(): void {
    if (this.timer !== undefined) {
      clearTimeout(this.timer)
    }
    this.timer = undefined
    this.action = undefined
  }

  private run(): void {
    const action = this.action
    this.cancel()
    action?.()
  }
}
