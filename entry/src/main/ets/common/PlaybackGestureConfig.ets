// 两种播放界面共用输入来源，垂直调节仍由滚轮处理鼠标输入。
export const PLAYBACK_GESTURE_INPUTS: SourceTool[] = [
  SourceTool.Unknown, SourceTool.Finger, SourceTool.Pen,
  SourceTool.MOUSE, SourceTool.TOUCHPAD, SourceTool.JOYSTICK
]

export const PLAYBACK_VERTICAL_GESTURE_INPUTS: SourceTool[] = [
  SourceTool.Unknown, SourceTool.Finger, SourceTool.Pen,
  SourceTool.TOUCHPAD, SourceTool.JOYSTICK
]

export interface PlaybackGestureHost {
  readonly isLock: boolean
  readonly showControl: boolean
  readonly longPress: boolean
  readonly isZoomed: boolean
  readonly screenWidth: number
}

@ObservedV2
export class PlaybackGestureState implements PlaybackGestureHost {
  @Trace isLock: boolean = false
  @Trace showControl: boolean = false
  @Trace longPress: boolean = false
  @Trace speedLocked: boolean = false
  @Trace isZoomed: boolean = false
  @Trace screenWidth: number = 0
}
