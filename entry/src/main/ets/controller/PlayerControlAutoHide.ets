// Page-owned idle timer. Playback time updates are not user interaction.
export class PlayerControlAutoHide {
  private timer: number = -1
  private generation: number = 0
  private active: boolean = false
  private deadline: number = 0
  private held: Set<string> = new Set<string>()
  private delayMs: number
  private canHide: () => boolean
  private onHide: () => void

  constructor(delayMs: number, canHide: () => boolean, onHide: () => void) {
    this.delayMs = delayMs
    this.canHide = canHide
    this.onHide = onHide
  }

  start(): void {
    this.active = true
    this.refresh()
  }

  stop(): void {
    this.active = false
    this.cancel()
    this.held.clear()
  }

  activity(): void {
    if (!this.active) return
    this.deadline = Date.now() + this.delayMs
    if (this.timer === -1 && this.held.size === 0 && this.canHide()) this.arm(this.delayMs)
  }

  // Visibility / gesture state changed: start a full idle interval when ready.
  refresh(): void {
    this.cancel()
    this.activity()
  }

  setHeld(reason: string, held: boolean): void {
    if (!this.active) return
    if (held) {
      this.held.add(reason)
      this.cancel()
    } else {
      this.held.delete(reason)
    }
    this.activity()
  }

  private cancel(): void {
    this.generation++
    if (this.timer !== -1) clearTimeout(this.timer)
    this.timer = -1
  }

  private arm(delay: number): void {
    const generation = this.generation
    this.timer = setTimeout(() => {
      if (generation !== this.generation || !this.active) return
      this.timer = -1
      if (this.held.size > 0 || !this.canHide()) return
      const remaining = this.deadline - Date.now()
      if (remaining > 0) this.arm(remaining)
      else this.onHide()
    }, delay)
  }
}
