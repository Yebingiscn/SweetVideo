import { PlayerControllerFactory, PlayerControllerInterface } from '../../controller/PlayerControllerFactory'
import VideoOperateUtil from '../../utils/VideoOperateUtil'

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
  @Event onPinchStart: (_fingerDistance: number) => void = () => {
  }
  @Event onPinchUpdate: (_fingerDistance: number) => void = () => {
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

  build() {
    Column()
      .width('100%')
      .height(this.player.showControl ? '50%' : '80%')//触控区域
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
              .allowedTypes([SourceTool.Unknown, SourceTool.Finger, SourceTool.MOUSE, SourceTool.TOUCHPAD,
                SourceTool.JOYSTICK])
              .onActionStart((event: GestureEvent) => { // 滑动屏幕
                if (this.player.isLock) {
                  return
                }
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
                if (event.fingerList?.length !== 1) {
                  return
                }
                this.onVerticalPanUpdate(event?.offsetY)
              })
              .onActionEnd(() => {
                if (this.player.isLock) {
                  return
                }
                this.onVerticalPanEnd()
              }),
            PanGesture({ fingers: 1, direction: PanDirection.Horizontal })// 水平滑动事件滑动调整进度
              .allowedTypes([SourceTool.Unknown, SourceTool.Finger, SourceTool.MOUSE, SourceTool.TOUCHPAD,
                SourceTool.JOYSTICK])
              .onActionStart((_event: GestureEvent) => { // 长按且滑动屏幕
                if (this.player.isLock) {
                  return
                }
                this.onHorizonPanStart()
              })
              .onActionUpdate((event: GestureEvent) => {
                if (this.player.isLock) {
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
                this.onHorizonPanEnd()
              }),
            PinchGesture({ fingers: 2, distance: 2 })//手势缩放
              .allowedTypes([SourceTool.Unknown, SourceTool.Finger, SourceTool.MOUSE, SourceTool.TOUCHPAD,
                SourceTool.JOYSTICK])
              .onActionStart((event: GestureEvent) => {
                if (this.player.isLock) {
                  return
                }
                const finger1 = event.fingerList[0]
                const finger2 = event.fingerList[1]
                const fingerDistance = VideoOperateUtil.calcFingerDistance(finger1, finger2)
                if (fingerDistance < 0) {
                  return
                }
                this.onPinchStart(fingerDistance)
              })
              .onActionUpdate((event: GestureEvent) => {
                if (this.player.isLock) {
                  return
                }
                const finger1 = event.fingerList[0]
                const finger2 = event.fingerList[1]
                if (!finger1 || !finger2) { // 双指检测失败直接返回
                  return
                }
                const fingerDistance = VideoOperateUtil.calcFingerDistance(finger1, finger2)
                if (fingerDistance < 0) {
                  return
                }
                this.onPinchUpdate(fingerDistance)
              })
              .onActionEnd(() => {
                if (this.player.isLock) {
                  return
                }
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
              }),
            PanGesture({
              fingers: 1,
              direction: PanDirection.Horizontal,
            })//水平滑动事件 长按加速滑动调整倍速
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
              .allowedTypes([SourceTool.Unknown, SourceTool.Finger, SourceTool.MOUSE, SourceTool.TOUCHPAD,
                SourceTool.JOYSTICK])
              .onActionUpdate((event: GestureEvent) => {
                if (this.player.isLock) {
                  return
                }
                this.onLongPressVerticalPanUpdate(event?.offsetY)
              }),
            PanGesture({ fingers: 2, direction: PanDirection.All })// 双指拖拽移动画面(仅在放大后生效)
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
                if (this.player.isLock) {
                  return
                }
                if (!this.player.isZoomed) {
                  return
                }
                this.onPanMoveEnd()
              })
          )))
  }
}