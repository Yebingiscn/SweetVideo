import { PlayerControllerFactory, PlayerControllerInterface } from '../../controller/PlayerControllerFactory'

import { MediaSmartGestureModifier } from '../../utils/MediaSmartGestureUtil'
import { Setting } from '../../utils/ObservedUtil'


@ComponentV2
export struct GestureComponent {
  @Consumer('player') player: PlayerControllerInterface =
    PlayerControllerFactory.createAVPlayerController() as PlayerControllerInterface
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
  @Event onLongPressPanStart: (_tapX: number) => void = () => {
  }
  @Event onLongPressPanUpdate: (_tapX: number) => void = () => {
  }
  @Event onLongPressVerticalPanUpdate: (_offsetY: number) => void = () => {
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

  private activePointerCount: number = 0
  private verticalPanCancelled: boolean = false
  private horizonPanCancelled: boolean = false

  build() {
    Column()
      .id('video_player_smart_gesture_surface')
      .attributeModifier(new MediaSmartGestureModifier(Setting.smartGestureEnabled && !this.player.isLock))
      .width('100%')
      .height(this.player.showControl ? '50%' : '80%')//触控区域
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Cancel) {
          this.activePointerCount = 0
          return
        }
        this.activePointerCount = event.touches.length
      })
      .onGestureJudgeBegin((gestureInfo: GestureInfo, event: BaseGestureEvent) => {
        // 已有多指按下时，拒绝单指Pan参与识别，避免双指操作被抢先识别为单指手势
        if (gestureInfo.type === GestureControl.GestureType.PAN_GESTURE &&
          event.fingerList.length > 1 &&
          gestureInfo.tag?.startsWith('pan_single')) {
          return GestureJudgeResult.REJECT
        }
        return GestureJudgeResult.CONTINUE
      })
      .gesture(
        GestureGroup(GestureMode.Exclusive, // 将触摸事件跟滑动、长按分成两个手势组解绑互斥,触摸事件手势组为互斥事件
          GestureGroup(GestureMode.Exclusive, //双击事件组和单击事件组互斥独立
            TapGesture({ count: 2 })// 双击事件
              .allowedTypes([SourceTool.Unknown, SourceTool.Finger, SourceTool.MOUSE, SourceTool.TOUCHPAD,
                SourceTool.JOYSTICK])
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
              .allowedTypes([SourceTool.Unknown, SourceTool.Finger, SourceTool.MOUSE, SourceTool.TOUCHPAD,
                SourceTool.JOYSTICK])
              .onAction(() => { //单击屏幕
                this.onSingleClickAction()
              }),
            PanGesture({ fingers: 1, direction: PanDirection.Vertical })// 垂直滑动
              .tag('pan_single_vertical')
              .allowedTypes([SourceTool.Unknown, SourceTool.Finger, SourceTool.TOUCHPAD,
                SourceTool.JOYSTICK])
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
                  this.onVerticalPanCancel()
                  return
                }
                if (event.fingerList?.length !== 1) {
                  return
                }
                this.onVerticalPanUpdate(event?.offsetY)
              })
              .onActionEnd(() => {
                if (this.player.isLock) {
                  return
                }
                if (this.verticalPanCancelled) {
                  this.verticalPanCancelled = false
                  return
                }
                this.onVerticalPanEnd()
              }),
            PanGesture({ fingers: 1, direction: PanDirection.Horizontal })// 水平滑动事件滑动调整进度
              .tag('pan_single_horizontal')
              .allowedTypes([SourceTool.Unknown, SourceTool.Finger, SourceTool.MOUSE, SourceTool.TOUCHPAD,
                SourceTool.JOYSTICK])
              .onActionStart((_event: GestureEvent) => { // 长按且滑动屏幕
                if (this.player.isLock) {
                  return
                }
                this.horizonPanCancelled = false
                this.onHorizonPanStart()
              })
              .onActionUpdate((event: GestureEvent) => {
                if (this.player.isLock) {
                  return
                }
                if (this.horizonPanCancelled) {
                  return
                }
                if (this.activePointerCount > 1) { // 第二指落下，取消进度调整并回滚
                  this.horizonPanCancelled = true
                  this.onHorizonPanCancel()
                  return
                }
                if (typeof event?.fingerList?.[0]?.localX !== 'number') {
                  return
                }
                this.onHorizonPanUpdate(event?.offsetX)
              })
              .onActionEnd(() => {
                if (this.player.isLock) {
                  return
                }
                if (this.horizonPanCancelled) {
                  this.horizonPanCancelled = false
                  return
                }
                this.onHorizonPanEnd()
              }),
            PinchGesture({ fingers: 2, distance: 2 })//手势缩放
              .allowedTypes([SourceTool.Unknown, SourceTool.Finger, SourceTool.MOUSE, SourceTool.TOUCHPAD,
                SourceTool.JOYSTICK])
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
              .allowedTypes([SourceTool.Unknown, SourceTool.Finger, SourceTool.MOUSE, SourceTool.TOUCHPAD,
                SourceTool.JOYSTICK])
              .onAction(() => { //长按
                if (this.player.isLock) {
                  return
                }
                this.onLongPressAction()
              })
              .onActionEnd(() => {
                if (this.player.isLock) {
                  return
                }
                this.onLongPressEnd()
              })
              .onActionCancel(() => {
                // Parallel Pan/Pinch recognition can cancel LongPress without
                // delivering onActionEnd. Restore temporary speed immediately.
                this.onLongPressEnd()
              }),
            PanGesture({
              fingers: 1,
              direction: PanDirection.Horizontal,
            })//水平滑动事件 长按加速滑动调整倍速
              .tag('pan_single_longpress_h')
              .allowedTypes([SourceTool.Unknown, SourceTool.Finger, SourceTool.MOUSE, SourceTool.TOUCHPAD,
                SourceTool.JOYSTICK])
              .onActionStart((event: GestureEvent) => { // 长按且滑动屏幕
                if (this.player.isLock) {
                  return
                }
                const tapX = event.fingerList[0]?.localX
                if (typeof tapX !== 'number') {
                  return
                }
                this.onLongPressPanStart(tapX)
              })
              .onActionUpdate((event: GestureEvent) => {
                if (this.player.isLock) {
                  return
                }
                const tapX = event.fingerList[0]?.localX
                if (typeof tapX !== 'number') {
                  return
                }
                this.onLongPressPanUpdate(tapX)
              }),
            PanGesture({
              fingers: 1,
              direction: PanDirection.Vertical,
            })//长按状态下垂直滑动 锁定倍速
              .tag('pan_single_longpress_v')
              .allowedTypes([SourceTool.Unknown, SourceTool.Finger, SourceTool.TOUCHPAD,
                SourceTool.JOYSTICK])
              .onActionUpdate((event: GestureEvent) => {
                if (this.player.isLock) {
                  return
                }
                this.onLongPressVerticalPanUpdate(event?.offsetY)
              })
           )))
      // 双指拖拽移动画面(仅在放大后生效)：脱离GestureGroup仲裁，避免被先识别的单指手势阻塞
      .parallelGesture(
        PanGesture({ fingers: 2, direction: PanDirection.All })
          .tag('pan_double_move')
          .allowedTypes([SourceTool.Unknown, SourceTool.Finger, SourceTool.MOUSE, SourceTool.TOUCHPAD,
            SourceTool.JOYSTICK])
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
        if (this.player.isLock) {
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
}
