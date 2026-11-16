import ToolsUtil from '../utils/ToolsUtil'
import VideoInfoUtil from '../utils/VideoInfoUtil'
import { XAnimation } from '../utils/AnimationUtil'
import { Setting } from '../utils/ObservedUtil'
import { SWIPE_THRESHOLD } from '../common/Constants'

export interface LongPressSpeedHost {
  readonly playing: boolean
  longPress: boolean
  speedLocked: boolean
  speed: number
  getRequestedPlaybackSpeed?(): number
  updatePlaybackSpeed(speed: number): void
  restoreSpeedAfterLongPress(speed: number): void
}

// 普通播放与短视频共用倍速会话，业务层仅适配实际的播放速度。
export class LongPressSpeedController {
  private currentSpeedIndex: number = 0
  private longPressSpeedSession: number = 0
  private activeLongPressSpeedSession: number = 0
  private longPressBaseSpeed: number = 1
  private longPressPreviousSpeed: number = 1
  private longPressPreviousLock: boolean = false
  private longPressStartX: number = 0
  private longPressStartY: number = 0
  private host: LongPressSpeedHost

  constructor(host: LongPressSpeedHost) {
    this.host = host
  }

  reset(): void {
    this.unlock()
    this.activeLongPressSpeedSession = 0
    this.longPressStartX = 0
    this.longPressStartY = 0
    this.host.longPress = false
  }

  begin(): void {
    if (!this.host.playing || this.activeLongPressSpeedSession !== 0) {
      return
    }
    this.activeLongPressSpeedSession = ++this.longPressSpeedSession
    this.longPressPreviousSpeed = this.requestedSpeed()
    this.longPressPreviousLock = this.host.speedLocked
    if (!this.host.speedLocked) {
      this.longPressBaseSpeed = this.longPressPreviousSpeed
      this.host.updatePlaybackSpeed(Setting.longPressSpeed)
    }
    this.longPressStartX = 0
    this.longPressStartY = 0
    XAnimation.runWithAnimation(() => {
      this.host.longPress = true
    })
    ToolsUtil.startVibration()
    this.currentSpeedIndex = this.speedIndex(this.requestedSpeed())
  }

  end(): void {
    if (this.activeLongPressSpeedSession === 0) {
      return
    }
    this.activeLongPressSpeedSession = 0
    XAnimation.runWithAnimation(() => {
      this.host.longPress = false
    })
    if (!this.host.speedLocked) {
      this.host.restoreSpeedAfterLongPress(this.longPressBaseSpeed)
    }
  }

  cancel(): void {
    if (this.activeLongPressSpeedSession === 0) return
    this.activeLongPressSpeedSession = 0
    this.host.speedLocked = this.longPressPreviousLock
    XAnimation.runWithAnimation(() => {
      this.host.longPress = false
    })
    this.host.restoreSpeedAfterLongPress(this.longPressPreviousLock ?
      this.longPressPreviousSpeed : this.longPressBaseSpeed)
  }

  unlock(): void {
    if (this.activeLongPressSpeedSession === 0 && !this.host.speedLocked) return
    this.activeLongPressSpeedSession = 0
    this.host.speedLocked = false
    XAnimation.runWithAnimation(() => {
      this.host.longPress = false
    })
    this.host.restoreSpeedAfterLongPress(this.longPressBaseSpeed)
  }

  panStart(offsetX: number, offsetY: number): void {
    if (this.activeLongPressSpeedSession === 0) return
    this.longPressStartX = 0
    this.longPressStartY = 0
    this.panUpdate(offsetX, offsetY)
  }

  panUpdate(offsetX: number, offsetY: number): void {
    if (this.activeLongPressSpeedSession === 0 || !this.host.longPress ||
      !Number.isFinite(offsetX) || !Number.isFinite(offsetY)) return
    const deltaX = offsetX - this.longPressStartX
    const deltaY = offsetY - this.longPressStartY
    if (Math.abs(deltaY) > SWIPE_THRESHOLD && Math.abs(deltaY) >= Math.abs(deltaX)) {
      // 每次动作都更新双轴基准，反向下滑从锁定位置计算，而非最初触点。
      this.longPressStartX = offsetX
      this.longPressStartY = offsetY
      if (deltaY > 0) {
        this.unlock()
        ToolsUtil.startVibration()
      } else if (!this.host.speedLocked) {
        this.host.speedLocked = true
        ToolsUtil.startVibration()
      }
      return
    }
    if (Math.abs(deltaX) <= SWIPE_THRESHOLD) return
    const wasLocked = this.host.speedLocked
    // 达到最高/最低档位也能解除锁定，松手后仍恢复锁定前的常规速度。
    this.host.speedLocked = false
    this.longPressStartX = offsetX
    this.longPressStartY = offsetY
    const newIndex = Math.max(0, Math.min(this.currentSpeedIndex + Math.sign(deltaX),
      VideoInfoUtil.videoSpeedListAll.length - 1))
    const speedChanged = newIndex !== this.currentSpeedIndex
    if (speedChanged) {
      this.currentSpeedIndex = newIndex
      this.host.updatePlaybackSpeed(VideoInfoUtil.videoSpeedListAll[this.currentSpeedIndex])
    }
    if (wasLocked || speedChanged) ToolsUtil.startVibration()
  }

  private requestedSpeed(): number {
    const speed = this.host.getRequestedPlaybackSpeed?.() ?? this.host.speed
    return Number.isFinite(speed) && speed > 0 ? speed : 1
  }

  private speedIndex(speed: number): number {
    const speeds = VideoInfoUtil.videoSpeedListAll
    let index = 0
    for (let i = 1; i < speeds.length; i++) {
      if (Math.abs(speeds[i] - speed) < Math.abs(speeds[index] - speed)) index = i
    }
    return index
  }

}
