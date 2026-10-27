import { systemDateTime } from '@kit.BasicServicesKit'

const AB_SEEK_TIMEOUT_MS: number = 5000
const AB_SEEK_COOLDOWN_MS: number = 250
const AB_SEEK_TOLERANCE_MS: number = 250

/** 只管理区间和跳转决策；执行 seek、引擎命令和持久化由播放会话负责。 */
@ObservedV2
export class AbLoopController {
  @Trace mediaKey: string = ''
  @Trace pointA: number = 0
  @Trace pointB: number = 0
  @Trace durationMs: number = 0
  @Trace enabled: boolean = false
  @Trace nativeLoopActive: boolean = false

  private clock: () => number
  private pendingSeek: boolean = false
  private pendingSinceMs: number = 0
  private lastSeekAtMs: number = Number.NEGATIVE_INFINITY

  get isSeekPending(): boolean {
    return this.pendingSeek
  }

  constructor(clock: () => number = () => systemDateTime.getUptime(systemDateTime.TimeType.STARTUP, false)) {
    this.clock = clock
  }

  bindMedia(key: string, pointA: number, pointB: number, durationMs: number): void {
    const changedMedia = key !== this.mediaKey
    const nextA = Number.isFinite(pointA) && pointA >= 0 ? pointA : 0
    const nextB = Number.isFinite(pointB) && pointB >= 0 ? pointB : 0
    const changedRange = nextA !== this.pointA || nextB !== this.pointB
    this.mediaKey = key
    this.pointA = nextA
    this.pointB = nextB
    this.durationMs = Number.isFinite(durationMs) && durationMs > 0 ? durationMs : 0
    if (changedMedia) {
      this.disable()
      this.lastSeekAtMs = Number.NEGATIVE_INFINITY
    } else if (changedRange) {
      this.rangeChanged()
    }
    if (!this.validRange()) {
      this.disable()
    }
  }

  validRange(): boolean {
    return this.mediaKey.length > 0 && Number.isFinite(this.durationMs) && this.durationMs > 0 &&
      Number.isFinite(this.pointA) && Number.isFinite(this.pointB) &&
      this.pointA >= 0 && this.pointA < this.pointB && this.pointB <= this.durationMs
  }

  /** 单独编辑点位允许暂时不完整的区间，但不允许无效区间继续循环。 */
  setA(pointA: number): boolean {
    if (!this.validPoint(pointA)) { return false }
    if (pointA !== this.pointA) {
      this.pointA = pointA
      this.rangeChanged()
    }
    return true
  }

  setB(pointB: number): boolean {
    if (!this.validPoint(pointB)) { return false }
    if (pointB !== this.pointB) {
      this.pointB = pointB
      this.rangeChanged()
    }
    return true
  }

  setRange(pointA: number, pointB: number): boolean {
    if (pointA === 0 && pointB === 0) {
      this.clear()
      return true
    }
    if (!this.validPoint(pointA) || !this.validPoint(pointB) || pointA >= pointB) { return false }
    if (pointA !== this.pointA || pointB !== this.pointB) {
      this.pointA = pointA
      this.pointB = pointB
      this.rangeChanged()
    }
    return true
  }

  enable(currentPositionMs: number): boolean {
    if (!this.validRange() || !Number.isFinite(currentPositionMs) || currentPositionMs < 0) {
      this.disable()
      return false
    }
    this.enabled = true
    return true
  }

  disable(): void {
    this.enabled = false
    this.nativeLoopActive = false
    this.clearPendingSeek()
  }

  clear(): void {
    this.disable()
    this.pointA = 0
    this.pointB = 0
  }

  setNativeLoopActive(active: boolean): void {
    this.nativeLoopActive = active && this.enabled && this.validRange()
    if (this.nativeLoopActive) {
      this.clearPendingSeek()
    }
  }

  /** 用于宿主主动定位 A；与 onPosition 返回的跳转共用同一把防重入锁。 */
  markSeekPending(): void {
    if (!this.enabled || !this.validRange()) { return }
    this.pendingSeek = true
    this.pendingSinceMs = this.clock()
    this.lastSeekAtMs = this.pendingSinceMs
  }

  onPosition(positionMs: number, isPlaying: boolean, isUserSeeking: boolean): number | undefined {
    if (!this.enabled || !this.validRange() || !Number.isFinite(positionMs) || isUserSeeking) {
      return undefined
    }
    if (this.pendingSeek) {
      if (this.isNearA(positionMs) || (positionMs >= this.pointA && positionMs < this.pointB)) {
        // 高倍速时首个 timeUpdate 可能已经离开 A，但回到区间内仍能确认跳转已完成。
        this.clearPendingSeek()
      } else if (this.clock() - this.pendingSinceMs >= AB_SEEK_TIMEOUT_MS) {
        // seek 未到达 A 时停止，不依靠无限重试争抢引擎。
        this.disable()
      }
      return undefined
    }
    if (!isPlaying || this.nativeLoopActive || positionMs < this.pointB) {
      return undefined
    }
    return this.requestSeek()
  }

  seekDone(positionMs?: number): void {
    // 某些引擎先发 seekDone，再更新时间。旧的 B 位置不能提前释放防重入锁。
    if (positionMs !== undefined && Number.isFinite(positionMs) &&
      positionMs >= this.pointA && positionMs < this.pointB) {
      this.clearPendingSeek()
    }
  }

  onUserSeekCommitted(positionMs: number): void {
    this.clearPendingSeek()
    if (!Number.isFinite(positionMs) || positionMs < this.pointA || positionMs >= this.pointB) {
      this.disable()
    }
  }

  onUserSeekStarted(): void {
    this.clearPendingSeek()
  }

  onCompleted(): number | undefined {
    if (!this.enabled || !this.validRange()) { return undefined }
    if (this.pendingSeek) {
      if (this.clock() - this.pendingSinceMs >= AB_SEEK_TIMEOUT_MS) {
        this.disable()
      }
      return undefined
    }
    // B 位于文件末尾时，完成事件也必须先于播放列表切换处理。
    return this.requestSeek()
  }

  private requestSeek(): number | undefined {
    if (this.clock() - this.lastSeekAtMs < AB_SEEK_COOLDOWN_MS) { return undefined }
    this.markSeekPending()
    return this.pointA
  }

  private isNearA(positionMs: number): boolean {
    const tolerance = Math.min(AB_SEEK_TOLERANCE_MS, (this.pointB - this.pointA) / 4)
    return positionMs < this.pointB && Math.abs(positionMs - this.pointA) <= tolerance
  }

  private validPoint(pointMs: number): boolean {
    return this.mediaKey.length > 0 && Number.isFinite(pointMs) && pointMs >= 0 &&
      Number.isFinite(this.durationMs) && this.durationMs > 0 && pointMs <= this.durationMs
  }

  private rangeChanged(): void {
    this.nativeLoopActive = false
    this.clearPendingSeek()
    if (!this.validRange()) {
      this.enabled = false
    }
  }

  private clearPendingSeek(): void {
    this.pendingSeek = false
    this.pendingSinceMs = 0
  }
}
