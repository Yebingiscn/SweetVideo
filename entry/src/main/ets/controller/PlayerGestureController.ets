import { framePreviewSession } from '../utils/FFmpegThumbnailUtil'
import ToolsUtil from '../utils/ToolsUtil'
import VideoInfoUtil from '../utils/VideoInfoUtil'
import VideoOperateUtil from '../utils/VideoOperateUtil'
import { PathUtils } from '../utils/PathUtils'
import { XAnimation } from '../utils/AnimationUtil'
import { Setting } from '../utils/ObservedUtil'
import { PlayerControllerInterface } from '../controller/PlayerControllerFactory'
import {
  MAX_SCALE_FACTOR,
  MAX_WIDTH_MULTIPLIER,
  MIN_SCALE_FACTOR,
  MIN_WIDTH_MULTIPLIER,
  PINCH_SCALE_SENSITIVITY,
  SCREEN_HALF_DIVIDER,
  SCROLL_BRIGHTNESS_SENSITIVITY,
  SCROLL_VOLUME_SENSITIVITY,
  SWIPE_THRESHOLD,
  TWO_FINGER_PAN_BASE_VP,
  TWO_FINGER_ZOOM_BASE_VP,
  VERTICAL_PAN_SENSITIVITY,
  VOLUME_PAN_MULTIPLIER
} from '../common/Constants'
import { TwoFingerMode } from '../common/enum/TwoFingerMode'

@ObservedV2
export class PlayerGestureController {
  @Trace seekStartTime: number = 0
  private currentSpeedIndex: number = 0
  private scrollAxisTimeout: number = 0
  private longPressSpeedSession: number = 0
  private activeLongPressSpeedSession: number = 0
  private longPressBaseSpeed: number = 1
  private twoFingerMode: TwoFingerMode = TwoFingerMode.NONE
  private twoFingerDistStart: number = 0
  private twoFingerMidStartX: number = 0
  private twoFingerMidStartY: number = 0

  private initPinchDistance: number = 0
  private initScaleFactor: number = 1
  private screenBrightnessTmp: number = 0
  private lastVolume: number = 0
  private longPressStartX: number = 0
  private panStartX: number = 0
  private panStartY: number = 0
  private leftSideSwipe: boolean = true

  private player: PlayerControllerInterface

  constructor(player: PlayerControllerInterface) {
    this.player = player
  }

  reset(): void {
    this.onLongPressEnd()
    clearTimeout(this.scrollAxisTimeout)
    this.scrollAxisTimeout = 0
    this.activeLongPressSpeedSession = 0
    this.twoFingerMode = TwoFingerMode.NONE
    this.player.volumeGestureActive = false
    this.player.onSwiping = false
    this.player.onSwipingVoice = false
    this.player.onSwipingBrightness = false
    this.player.isGesturing = false
    this.player.longPress = false
    this.player.speedLocked = false
  }

  onVerticalPanStart(tapX: number): void {
    clearTimeout(this.scrollAxisTimeout)
    this.leftSideSwipe = tapX < this.player.screenWidth / SCREEN_HALF_DIVIDER
    this.player.volumeGestureActive = !this.leftSideSwipe
    this.screenBrightnessTmp = this.player.screenBrightness
    this.player.volume = this.player.volumeActually
    this.lastVolume = this.player.volume
    if (this.leftSideSwipe) {
      this.player.onSwipingBrightness = true
    } else {
      this.player.onSwipingVoice = true
    }
  }

  onVerticalPanUpdate(offsetY: number): void {
    const deltaYScale = offsetY / this.player.screenHeight * VERTICAL_PAN_SENSITIVITY
    if (this.leftSideSwipe) {
      this.player.screenBrightness = Math.min(Math.max(this.screenBrightnessTmp - deltaYScale, 0), 1)
      VideoOperateUtil.setBrightness(this.player.screenBrightness)
    } else {
      const newVolume = this.lastVolume - deltaYScale * VOLUME_PAN_MULTIPLIER
      this.player.volume =
        Math.min(Math.max(newVolume, VideoOperateUtil.minVolume), VideoOperateUtil.maxVolume)
    }
  }

  onVerticalPanEnd(): void {
    this.player.volumeGestureActive = false
    this.player.onSwiping = false
    this.player.onSwipingVoice = false
    this.player.onSwipingBrightness = false
  }

  onVerticalPanCancel(): void {
    this.player.volumeGestureActive = false
    if (this.leftSideSwipe) {
      this.player.screenBrightness = this.screenBrightnessTmp
      VideoOperateUtil.setBrightness(this.player.screenBrightness)
    } else {
      this.player.volume = this.lastVolume
    }
    this.player.onSwiping = false
    this.player.onSwipingVoice = false
    this.player.onSwipingBrightness = false
  }

  onHorizonPanStart(): void {
    this.seekStartTime = this.player.playTime
    this.player.onSwiping = true
    framePreviewSession.requestFrame(this.player, this.player.playTime, true)
  }

  onHorizonPanUpdate(offsetX: number): void {
    const timePerPixel = VideoOperateUtil.getTimePixel(this.player.screenWidth, this.player.nowPlaying?.time!)
    this.player.playTime = Math.max(0,
      Math.min(this.seekStartTime + (offsetX * timePerPixel), this.player.nowPlaying?.time!))
    framePreviewSession.requestFrame(this.player, this.player.playTime, false)
  }

  onHorizonPanEnd(): void {
    this.player.seekTime(this.player.playTime)
    this.player.onSwiping = false
  }

  onHorizonPanCancel(): void {
    this.player.playTime = this.seekStartTime
    this.player.seekTime(this.player.playTime)
    this.player.onSwiping = false
  }

  onPinchStart(event: GestureEvent): void {
    if (this.player.isLock) {
      return
    }
    const finger1 = event.fingerList[0]
    const finger2 = event.fingerList[1]
    const fingerDistance = this.calcFingerDistance(finger1, finger2)
    if (fingerDistance < 0) {
      return
    }
    this.initPinchDistance = fingerDistance
    this.initScaleFactor = this.player.scaleFactor
    this.player.isGesturing = true

    this.twoFingerDistStart = fingerDistance
    this.twoFingerMidStartX = ((finger1?.localX ?? 0) + (finger2?.localX ?? 0)) / 2
    this.twoFingerMidStartY = ((finger1?.localY ?? 0) + (finger2?.localY ?? 0)) / 2
  }

  onPinchUpdate(event: GestureEvent): void {
    if (this.player.isLock) {
      return
    }
    const finger1 = event.fingerList[0]
    const finger2 = event.fingerList[1]
    if (!finger1 || !finger2) { // 双指检测失败直接返回
      return
    }
    const fingerDistance = this.calcFingerDistance(finger1, finger2)
    if (fingerDistance < 0) {
      return
    }
    // 双指会话主导仲裁：平移已锁定时忽略缩放，避免拖动画面被误回正
    if (this.twoFingerMode === TwoFingerMode.PAN) {
      return
    }
    if (this.twoFingerMode !== TwoFingerMode.PINCH) {
      const midX = (finger1.localX + finger2.localX) / 2
      const midY = (finger1.localY + finger2.localY) / 2
      const distDelta = Number.isNaN(this.twoFingerDistStart)
        ? 0 : Math.abs(fingerDistance - this.twoFingerDistStart)
      const midDelta = Math.hypot(midX - this.twoFingerMidStartX, midY - this.twoFingerMidStartY)
      if (!(distDelta > TWO_FINGER_ZOOM_BASE_VP && distDelta > midDelta)) {
        return
      }
      this.twoFingerMode = TwoFingerMode.PINCH
      // 缩放主导确立，重置中点滚动基准，此后平移跟随双指中点（放大到某个点）
      this.twoFingerMidStartX = midX
      this.twoFingerMidStartY = midY
    }

    const rawScale = fingerDistance / this.initPinchDistance
    const adjustedScale = 1 + (rawScale - 1) * PINCH_SCALE_SENSITIVITY
    const newScaleFactor = this.initScaleFactor * adjustedScale
    const clampedScaleFactor = Math.min(Math.max(newScaleFactor, MIN_SCALE_FACTOR), MAX_SCALE_FACTOR)
    const effectiveWidth = VideoInfoUtil.playAreaWidth * clampedScaleFactor
    const maxAllowed = VideoInfoUtil.playAreaWidth * MAX_WIDTH_MULTIPLIER
    const minAllowed = VideoInfoUtil.playAreaWidth * MIN_WIDTH_MULTIPLIER
    if (effectiveWidth > maxAllowed || effectiveWidth < minAllowed) {
      return
    }
    this.player.scaleFactor = clampedScaleFactor
    this.player.isZoomed = clampedScaleFactor !== 1
  }

  onPinchEnd(): void {
    this.player.isZoomed = this.player.scaleFactor !== 1
    this.player.isGesturing = false
    this.twoFingerMode = TwoFingerMode.NONE
  }

  onLongPressAction(): void {
    if (!this.player.playing || this.activeLongPressSpeedSession !== 0) {
      return
    }
    this.activeLongPressSpeedSession = ++this.longPressSpeedSession
    this.longPressBaseSpeed = this.player.speed
    this.player.speedLocked = false
    this.player.updatePlaybackSpeed(Setting.longPressSpeed)
    XAnimation.runWithAnimation(() => {
      this.player.longPress = true
    })
    ToolsUtil.startVibration()
    this.currentSpeedIndex = VideoInfoUtil.videoSpeedListAll.indexOf(Setting.longPressSpeed)
  }

  onLongPressEnd(): void {
    if (this.activeLongPressSpeedSession === 0) {
      return
    }
    this.activeLongPressSpeedSession = 0
    XAnimation.runWithAnimation(() => {
      this.player.longPress = false
    })
    if (!this.player.speedLocked) {
      this.player.restoreSpeedAfterLongPress(this.longPressBaseSpeed)
    } else {
      this.player.savePlayerSpeed(PathUtils.appContext!)
    }
    this.player.speedLocked = false
  }

  onLongPressPanStart(tapX: number): void {
    this.longPressStartX = tapX
    ToolsUtil.startVibration()
  }

  onLongPressPanUpdate(tapX: number): void {
    if (this.activeLongPressSpeedSession !== 0 && this.player.longPress) {
      const deltaX = tapX - this.longPressStartX
      if (Math.abs(deltaX) <= SWIPE_THRESHOLD) {
        return
      }
      const direction = Math.sign(deltaX)
      const newIndex = this.currentSpeedIndex + direction
      const clampedIndex = Math.max(0, Math.min(newIndex, VideoInfoUtil.videoSpeedListAll.length - 1))
      if (clampedIndex === this.currentSpeedIndex) {
        return
      }
      this.currentSpeedIndex = clampedIndex
      this.player.updatePlaybackSpeed(VideoInfoUtil.videoSpeedListAll[this.currentSpeedIndex])
      this.player.speedLocked = false
      this.longPressStartX = tapX
      ToolsUtil.startVibration()
    }
  }

  onLongPressVerticalPanUpdate(offsetY: number): void {
    if (this.activeLongPressSpeedSession !== 0 && this.player.longPress &&
      !this.player.speedLocked && offsetY < -SWIPE_THRESHOLD) {
      this.player.speedLocked = true
      ToolsUtil.startVibration()
    }
  }

  onPanMoveStart(event: GestureEvent): void {
    const finger1 = event.fingerList[0]
    const finger2 = event.fingerList[1]
    this.panStartX = finger1?.localX || 0
    this.panStartY = finger1?.localY || 0
    this.player.isGesturing = true
    const dist = this.calcFingerDistance(finger1, finger2)
    this.twoFingerDistStart = dist < 0 ? NaN : dist
    this.twoFingerMidStartX = ((finger1?.localX ?? 0) + (finger2?.localX ?? 0)) / 2
    this.twoFingerMidStartY = ((finger1?.localY ?? 0) + (finger2?.localY ?? 0)) / 2
  }

  onPanMoveUpdate(event: GestureEvent): void {
    const finger1 = event.fingerList[0]
    const finger2 = event.fingerList[1]
    const currentX = finger1?.localX || 0
    const currentY = finger1?.localY || 0
    // 缩放主导期间平移跟随双指中点：纯捏合中点不动不漂移，边捏边移可放大到指定点
    if (this.twoFingerMode === TwoFingerMode.PINCH) {
      if (!finger1 || !finger2) {
        return
      }
      const midX = (finger1.localX + finger2.localX) / 2
      const midY = (finger1.localY + finger2.localY) / 2
      this.player.translateX += midX - this.twoFingerMidStartX
      this.player.translateY += midY - this.twoFingerMidStartY
      this.twoFingerMidStartX = midX
      this.twoFingerMidStartY = midY
      return
    }
    if (this.twoFingerMode !== TwoFingerMode.PAN) {
      const midX = ((finger1?.localX ?? 0) + (finger2?.localX ?? 0)) / 2
      const midY = ((finger1?.localY ?? 0) + (finger2?.localY ?? 0)) / 2
      const dist = this.calcFingerDistance(finger1, finger2)
      const distDelta =
        (dist < 0 || Number.isNaN(this.twoFingerDistStart)) ? 0 : Math.abs(dist - this.twoFingerDistStart)
      const midDelta = Math.hypot(midX - this.twoFingerMidStartX, midY - this.twoFingerMidStartY)
      if (!(midDelta > TWO_FINGER_PAN_BASE_VP && midDelta > distDelta)) {
        return
      }
      this.twoFingerMode = TwoFingerMode.PAN
    }
    const deltaX = currentX - this.panStartX
    const deltaY = currentY - this.panStartY
    this.player.translateX += deltaX
    this.player.translateY += deltaY
    this.panStartX = currentX
    this.panStartY = currentY
  }

  onPanMoveEnd(): void {
    this.player.isGesturing = false
    this.twoFingerMode = TwoFingerMode.NONE
  }

  onScrollAxisBegin(isLeftSide: boolean): void {
    clearTimeout(this.scrollAxisTimeout)
    this.player.volumeGestureActive = !isLeftSide
    if (isLeftSide) {
      this.player.onSwipingVoice = false
      this.screenBrightnessTmp = this.player.screenBrightness
      this.player.onSwipingBrightness = true
    } else {
      this.player.onSwipingBrightness = false
      this.player.volume = this.player.volumeActually
      this.lastVolume = this.player.volume
      this.player.onSwipingVoice = true
    }
    this.scheduleScrollPanelHide()
  }

  onScrollAxisUpdate(axisValue: number, isLeftSide: boolean): void {
    const delta = -axisValue
    if (isLeftSide) {
      const brightnessStep = delta * SCROLL_BRIGHTNESS_SENSITIVITY
      const newBrightness = this.player.screenBrightness + brightnessStep
      this.player.screenBrightness = Math.min(Math.max(newBrightness, 0), 1)
      VideoOperateUtil.setBrightness(this.player.screenBrightness)
    } else {
      const volumeStep = delta * SCROLL_VOLUME_SENSITIVITY
      const newVolume = this.player.volume + volumeStep
      this.player.volume =
        Math.min(Math.max(newVolume, VideoOperateUtil.minVolume), VideoOperateUtil.maxVolume)
      this.player.volumeActually = this.player.volume
      this.lastVolume = this.player.volume
    }
    // 每次滚动都刷新兜底，避免设备没有发送 END 时面板残留。
    this.scheduleScrollPanelHide()
  }

  onScrollAxisEnd(): void {
    this.scheduleScrollPanelHide()
  }
  private scheduleScrollPanelHide(): void {
    clearTimeout(this.scrollAxisTimeout)
    const player = this.player
    this.scrollAxisTimeout = setTimeout(() => {
      this.scrollAxisTimeout = 0
      player.volumeGestureActive = false
      player.onSwipingVoice = false
      player.onSwipingBrightness = false
    }, 1500)
  }

  // 计算手指移动距离
  private calcFingerDistance(f1: FingerInfo, f2: FingerInfo): number {
    // 检查坐标是否存在
    if (
      typeof f1?.localX != 'number' ||
      typeof f1?.localY != 'number' ||
      typeof f2?.localX != 'number' ||
      typeof f2?.localY != 'number'
    ) {
      return -1
    }
    const dx = f2.localX - f1.localX
    const dy = f2.localY - f1.localY
    return Math.sqrt(dx * dx + dy * dy)
  }
}
