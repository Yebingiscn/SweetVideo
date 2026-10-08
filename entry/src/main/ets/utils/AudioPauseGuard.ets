// 只有可恢复的音频中断可以授权自动播放；新的操作会使旧恢复请求失效。
export class AudioPauseGuard {
  private revision: number = 0
  private interrupted: boolean = false
  private resuming: boolean = false

  cancel(): void {
    this.revision++
    this.interrupted = false
    this.resuming = false
  }

  interrupt(playing: boolean, resumable: boolean): void {
    const interrupted = resumable && (playing || this.interrupted)
    this.cancel()
    this.interrupted = interrupted
  }

  beginResume(): number {
    if (!this.interrupted || this.resuming) {
      return -1
    }
    this.resuming = true
    return this.revision
  }

  completeResume(token: number): boolean {
    if (token < 0 || token !== this.revision || !this.interrupted || !this.resuming) {
      return false
    }
    this.cancel()
    return true
  }

  resumeFailed(token: number): void {
    if (token === this.revision) {
      this.resuming = false
    }
  }
}
