import type { PlaybackGestureHost } from '../../common/PlaybackGestureConfig'
import { PLAYBACK_GESTURE_INPUTS, PLAYBACK_VERTICAL_GESTURE_INPUTS } from '../../common/PlaybackGestureConfig'

import { MediaSmartGestureModifier } from '../../utils/MediaSmartGestureUtil'
import { Setting } from '../../utils/ObservedUtil'

@ComponentV2
export struct GestureComponent {
  @Require @Param player: PlaybackGestureHost
  @Param gestureEnabled: boolean = true
  @Param extendedGestures: boolean = true
  @Param touchAreaHeight: Length | undefined = undefined
  @Param smartGestureEnabled: boolean = true
  @Param gestureSurfaceId: string = 'video_player_smart_gesture_surface'
  private activePointerCount: number = 0
  private verticalPanCancelled: boolean = false
  private verticalPanActive: boolean = false
  private horizonPanCancelled: boolean = false
  private horizonPanActive: boolean = false
  private longPressGestureActive: boolean = false

  @Event onDoubleClickAction: (_tapX: number) => void = () => {
  }

  @Event onSingleClickAction: () => void = () => {
  }

  @Event onVerticalPanStart: (_tapX: number) => void = () => {
  }

  @Event onVerticalPanUpdate: (_offsetY: number) => void = () => {
  }

  @Event onVerticalPanEnd: () => void = () => {
  }

  @Event onHorizonPanStart: () => void = () => {
  }

  @Event onHorizonPanUpdate: (_offsetY: number) => void = () => {
  }

  @Event onHorizonPanEnd: () => void = () => {
  }

  @Event onPinchStart: (_event: GestureEvent) => void = () => {
  }

  @Event onPinchUpdate: (_event: GestureEvent) => void = () => {
  }

  @Event onPinchEnd: () => void = () => {
  }

  @Event onLongPressAction: () => void = () => {
  }

  @Event onLongPressEnd: () => void = () => {
  }

  @Event onLongPressCancel: () => void = () => {
  }

  @Event onLongPressPanStart: (_offsetX: number, _offsetY: number) => void = () => {
  }

  @Event onLongPressPanUpdate: (_offsetX: number, _offsetY: number) => void = () => {
  }

  @Event onPanMoveStart: (_event: GestureEvent) => void = () => {
  }

  @Event onPanMoveUpdate: (_event: GestureEvent) => void = () => {
  }

  @Event onPanMoveEnd: () => void = () => {
  }

  @Event onVerticalPanCancel: () => void = () => {
  }

  @Event onHorizonPanCancel: () => void = () => {
  }

  @Event onScrollAxisBegin: (_isLeftSide: boolean) => void = () => {
  }

  @Event onScrollAxisUpdate: (_axisValue: number, _isLeftSide: boolean) => void = () => {
  }

  @Event onScrollAxisEnd: () => void = () => {
  }

  @Monitor('gestureEnabled')
  onGestureEnabledChanged(): void {
    if (!this.gestureEnabled) {
      this.activePointerCount = 0
      this.cancelLongPressGesture()
      this.cancelHorizonPanGesture()
    }
  }

  build() {
    Column()
      .id(this.gestureSurfaceId)
      .attributeModifier(new MediaSmartGestureModifier(
        this.smartGestureEnabled && Setting.smartGestureEnabled && !this.player.isLock))
      .width('100%')
      .height(this.touchAreaHeight ?? (this.player.showControl ? '50%' : '80%'))
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Cancel) {
          this.activePointerCount = 0
          this.cancelLongPressGesture()
          this.cancelHorizonPanGesture()
          return
        }
        this.activePointerCount = event.touches.length
        if (this.activePointerCount > 1) {
          this.cancelLongPressGesture()
          this.cancelHorizonPanGesture()
        }
      })
      .onGestureJudgeBegin((gestureInfo: GestureInfo, event: BaseGestureEvent) => {
        if (!this.gestureEnabled) {
          return GestureJudgeResult.REJECT
        }
        // 短视频保留长按调速，普通垂直调节和缩放交给各自界面。
        if (!this.extendedGestures && (gestureInfo.tag === 'pan_single_vertical' ||
          gestureInfo.tag === 'pinch_zoom' || gestureInfo.tag === 'pan_double_move')) {
          return GestureJudgeResult.REJECT
        }
        // 已有多指按下时，拒绝单指Pan参与识别，避免双指操作被抢先识别为单指手势
        if (gestureInfo.type === GestureControl.GestureType.PAN_GESTURE &&
          gestureInfo.tag?.startsWith('pan_single')) {
          if (event.fingerList.length > 1) {
            return GestureJudgeResult.REJECT
          }
          const isLongPressPan = gestureInfo.tag === 'pan_single_longpress'
          // 在长按识别成功后只接收倍速拖动，普通滑动仍交给音量、亮度和进度手势。
          if (isLongPressPan !== this.player.longPress) {
            return GestureJudgeResult.REJECT
          }
        }
        return GestureJudgeResult.CONTINUE
      })
      .gesture(
        GestureGroup(GestureMode.Exclusive, // 将触摸事件跟滑动、长按分成两个手势组解绑互斥,触摸事件手势组为互斥事件
          GestureGroup(GestureMode.Exclusive, //双击事件组和单击事件组互斥独立
            TapGesture({ count: 2 })// 双击事件
              .allowedTypes(PLAYBACK_GESTURE_INPUTS)
              .onAction((event: GestureEvent) => {
                if (this.player.isLock) {
                  return
                }
                const tapX = event.fingerList[0]?.localX
                if (typeof tapX !== 'number') {
                  return
                }
                this.onDoubleClickAction(tapX)
              }),
            TapGesture({ count: 1 })// 单击事件
              .allowedTypes(PLAYBACK_GESTURE_INPUTS)
              .onAction(() => { //单击屏幕
                this.onSingleClickAction()
              }),
            PanGesture({ fingers: 1, direction: PanDirection.Vertical })// 垂直滑动
              .tag('pan_single_vertical')
              .allowedTypes(PLAYBACK_VERTICAL_GESTURE_INPUTS)
              .onActionStart((event: GestureEvent) => { // 滑动屏幕
                if (this.player.isLock) {
                  return
                }
                this.verticalPanCancelled = false
                const tapX = event.fingerList[0]?.localX
                if (typeof tapX !== 'number') {
                  return
                }
                this.onVerticalPanStart(tapX)
                this.verticalPanActive = true
              })
              .onActionUpdate((event: GestureEvent) => {
                if (this.player.isLock) {
                  return
                }
                if (this.verticalPanCancelled) {
                  return
                }
                if (this.activePointerCount > 1) { // 第二指落下，取消本次调节并回滚
                  this.verticalPanCancelled = true
                  this.verticalPanActive = false
                  this.onVerticalPanCancel()
                  return
                }
                if (event.fingerList?.length !== 1) {
                  return
                }
                this.onVerticalPanUpdate(event?.offsetY)
              })
              .onActionEnd(() => {
                if (this.verticalPanCancelled) {
                  this.verticalPanCancelled = false
                  return
                }
                if (this.verticalPanActive) {
                  this.verticalPanActive = false
                  this.onVerticalPanEnd()
                }
              })
              .onActionCancel(() => {
                if (this.verticalPanActive) {
                  this.verticalPanActive = false
                  this.onVerticalPanCancel()
                }
                this.verticalPanCancelled = false
              }),
            PanGesture({ fingers: 1, direction: PanDirection.Horizontal })// 水平滑动事件滑动调整进度
              .tag('pan_single_horizontal')
              .allowedTypes(PLAYBACK_GESTURE_INPUTS)
              .onActionStart((_event: GestureEvent) => { // 长按且滑动屏幕
                if (this.player.isLock) {
                  return
                }
                this.horizonPanCancelled = false
                this.onHorizonPanStart()
                this.horizonPanActive = true
              })
              .onActionUpdate((event: GestureEvent) => {
                if (this.player.isLock) {
                  return
                }
                if (this.horizonPanCancelled) {
                  return
                }
                if (this.activePointerCount > 1) { // 第二指落下，取消进度调整并回滚
                  this.cancelHorizonPanGesture()
                  return
                }
                if (typeof event?.fingerList?.[0]?.localX !== 'number') {
                  return
                }
                this.onHorizonPanUpdate(event?.offsetX)
              })
              .onActionEnd(() => {
                if (this.player.isLock || this.horizonPanCancelled) {
                  this.cancelHorizonPanGesture()
                  this.horizonPanCancelled = false
                  return
                }
                if (this.horizonPanActive) {
                  this.horizonPanActive = false
                  this.onHorizonPanEnd()
                }
              })
              .onActionCancel(() => {
                this.cancelHorizonPanGesture()
              }),
            PinchGesture({ fingers: 2, distance: 2 })//手势缩放
              .tag('pinch_zoom')
              .allowedTypes(PLAYBACK_GESTURE_INPUTS)
              .onActionStart((event: GestureEvent) => {
                if (this.player.isLock) {
                  return
                }
                this.onPinchStart(event)
              })
              .onActionUpdate((event: GestureEvent) => {
                if (this.player.isLock) {
                  return
                }
                this.onPinchUpdate(event)
              })
              .onActionEnd(() => {
                this.onPinchEnd()
              })
              .onActionCancel(() => {
                this.onPinchEnd()
              })
          ),
          GestureGroup(GestureMode.Parallel, // 不用互斥事件，会导致左右滑动调节倍速的功能失效
            LongPressGesture()// 长按手势
              .allowedTypes(PLAYBACK_GESTURE_INPUTS)
              .onAction((event: GestureEvent) => { //长按
                if (this.player.isLock || this.activePointerCount > 1 || event.fingerList.length > 1) {
                  return
                }
                this.onLongPressAction()
                this.longPressGestureActive = this.player.longPress
              })
              .onActionEnd(() => {
                this.endLongPressGesture()
              })
              .onActionCancel(() => {
                this.cancelLongPressGesture()
              }),
            PanGesture({
              fingers: 1,
              direction: PanDirection.All,
            })//同一次长按内支持横滑调速、上滑锁定和下滑解锁，转向无需更换识别器。
              .tag('pan_single_longpress')
              .allowedTypes(PLAYBACK_GESTURE_INPUTS)
              .onActionStart((event: GestureEvent) => { // 长按且滑动屏幕
                if (this.player.isLock || this.activePointerCount > 1 || event.fingerList.length > 1) {
                  this.cancelLongPressGesture()
                  return
                }
                if (!this.longPressGestureActive) {
                  return
                }
                this.onLongPressPanStart(event.offsetX, event.offsetY)
              })
              .onActionUpdate((event: GestureEvent) => {
                if (this.player.isLock || this.activePointerCount > 1 || event.fingerList.length > 1) {
                  this.cancelLongPressGesture()
                  return
                }
                if (!this.longPressGestureActive) {
                  return
                }
                this.onLongPressPanUpdate(event.offsetX, event.offsetY)
              })
              .onActionEnd(() => {
                this.endLongPressGesture()
              })
              .onActionCancel(() => {
                this.cancelLongPressGesture()
              })
          )))
      // 双指拖拽移动画面(仅在放大后生效)：脱离GestureGroup仲裁，避免被先识别的单指手势阻塞
      .parallelGesture(
        PanGesture({ fingers: 2, direction: PanDirection.All })
          .tag('pan_double_move')
          .allowedTypes(PLAYBACK_GESTURE_INPUTS)
          .onActionStart((event: GestureEvent) => {
            if (this.player.isLock) {
              return
            }
            if (!this.player.isZoomed) {
              return
            }
            const tapX = event.fingerList[0]?.localX
            if (typeof tapX !== 'number') {
              return
            }
            this.onPanMoveStart(event)
          })
          .onActionUpdate((event: GestureEvent) => {
            if (this.player.isLock) {
              return
            }
            if (!this.player.isZoomed) {
              return
            }
            const tapX = event.fingerList[0]?.localX
            if (typeof tapX !== 'number') {
              return
            }
            this.onPanMoveUpdate(event)
          })
          .onActionEnd(() => {
            this.onPanMoveEnd()
          })
          .onActionCancel(() => {
            this.onPanMoveEnd()
          })
      )
      .onAxisEvent((event: AxisEvent) => {
        if (!this.gestureEnabled || !this.extendedGestures || this.player.isLock) {
          return
        }
        const isLeftSide = event.x < this.player.screenWidth / 2

        if (event.action === AxisAction.BEGIN) {
          this.onScrollAxisBegin(isLeftSide)
        }
        if (event.action === AxisAction.BEGIN || event.action === AxisAction.UPDATE) {
          const axisValue = event.axisVertical
          if (axisValue !== undefined && axisValue !== 0) {
            this.onScrollAxisUpdate(axisValue, isLeftSide)
          }
        }
        if (event.action === AxisAction.END || event.action === AxisAction.CANCEL) {
          this.onScrollAxisEnd()
        }
      })
  }

  private cancelHorizonPanGesture(): void {
    if (!this.horizonPanActive) {
      return
    }
    this.horizonPanActive = false
    this.horizonPanCancelled = true
    this.onHorizonPanCancel()
  }

  private cancelLongPressGesture(): void {
    if (!this.longPressGestureActive) {
      return
    }
    this.longPressGestureActive = false
    this.onLongPressCancel()
  }

  private endLongPressGesture(): void {
    if (!this.longPressGestureActive) {
      return
    }
    if (this.player.isLock || this.activePointerCount > 1) {
      this.cancelLongPressGesture()
      return
    }
    this.longPressGestureActive = false
    this.onLongPressEnd()
  }
}
