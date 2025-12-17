@Component
export struct GestureComponent {
  @Link showControl: boolean
  @Link isLock: boolean
  onDoubleClickAction = (_event: GestureEvent) => {
  };
  onSingleClickAction = () => {
  }
  onVerticalPanStart = (_event: GestureEvent) => {
  }
  onVerticalPanUpdate = (_event: GestureEvent) => {
  }
  onVerticalPanEnd = () => {
  }
  onHorizonPanStart = (_event: GestureEvent) => {
  }
  onHorizonPanUpdate = (_event: GestureEvent) => {
  }
  onHorizonPanEnd = () => {
  }
  onPinchStart = (_event: GestureEvent) => {
  }
  onPinchUpdate = (_event: GestureEvent) => {
  }
  onLongPressAction = () => {
  }
  onLongPressEnd = () => {
  }
  onLongPressPanStart = (_event: GestureEvent) => {
  }
  onLongPressPanUpdate = (_event: GestureEvent) => {
  }

  build() {
    Column()
      .width('100%')
      .height(this.showControl ? '50%' : '80%')//触控区域
      .gesture(
        GestureGroup(GestureMode.Exclusive, // 将触摸事件跟滑动、长按分成两个手势组解绑互斥,触摸事件手势组为互斥事件
          GestureGroup(GestureMode.Exclusive, //双击事件组和单击事件组互斥独立
            TapGesture({ count: 2 })// 双击事件
              .onAction((event: GestureEvent) => {
                if (this.isLock) {
                  return
                }
                this.onDoubleClickAction(event)
              }),
            TapGesture({ count: 1 })// 单击事件
              .onAction(() => { //单击屏幕
                this.onSingleClickAction()
              }),
            PanGesture({ fingers: 1, direction: PanDirection.Vertical })// 垂直滑动
              .allowedTypes([SourceTool.Unknown, SourceTool.Finger, SourceTool.MOUSE, SourceTool.TOUCHPAD,
                SourceTool.JOYSTICK])
              .onActionStart((event: GestureEvent) => { // 滑动屏幕
                if (this.isLock) {
                  return
                }
                this.onVerticalPanStart(event)
              })
              .onActionUpdate((event: GestureEvent) => {
                if (this.isLock) {
                  return
                }
                this.onVerticalPanUpdate(event)
              })
              .onActionEnd(() => {
                if (this.isLock) {
                  return
                }
                this.onVerticalPanEnd()
              }),
            PanGesture({ fingers: 1, direction: PanDirection.Horizontal })// 水平滑动事件滑动调整进度
              .onActionStart((event: GestureEvent) => { // 长按且滑动屏幕
                if (this.isLock) {
                  return
                }
                this.onHorizonPanStart(event)
              })
              .onActionUpdate((event: GestureEvent) => {
                if (this.isLock) {
                  return
                }
                this.onHorizonPanUpdate(event)
              })
              .onActionEnd(() => {
                if (this.isLock) {
                  return
                }
                this.onHorizonPanEnd()
              }),
            PinchGesture({ fingers: 2, distance: 2 })//手势缩放
              .onActionStart((event: GestureEvent) => {
                if (this.isLock) {
                  return
                }
                this.onPinchStart(event)
              })
              .onActionUpdate((event: GestureEvent) => {
                if (this.isLock) {
                  return
                }
                this.onPinchUpdate(event)
              })
          ),
          GestureGroup(GestureMode.Parallel, // 不用互斥事件，会导致左右滑动调节倍速的功能失效
            LongPressGesture()// 长按手势
              .onAction(() => { //长按
                if (this.isLock) {
                  return
                }
                this.onLongPressAction()
              })
              .onActionEnd(() => {
                if (this.isLock) {
                  return
                }
                this.onLongPressEnd()
              }),
            PanGesture({
              fingers: 1,
              direction: PanDirection.Horizontal,
            })//水平滑动事件 长按加速滑动调整倍速
              .onActionStart((event: GestureEvent) => { // 长按且滑动屏幕
                if (this.isLock) {
                  return
                }
                this.onLongPressPanStart(event)
              })
              .onActionUpdate((event: GestureEvent) => {
                if (this.isLock) {
                  return
                }
                this.onLongPressPanUpdate(event)
              })
          )))
  }
}