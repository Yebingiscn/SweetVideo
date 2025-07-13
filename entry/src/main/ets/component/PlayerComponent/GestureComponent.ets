@Component
export struct GestureComponent {
  @Prop showControl: boolean
  onDoubleClickAction = (event: GestureEvent) => {
    console.log('onDoubleClickAction active: ' + event)
  };
  onSingleClickAction = () => {
    console.log('onSingleClickAction active')
  }
  onVerticalPanStart = (event: GestureEvent) => {
    console.log('onVerticalPanStart active: ' + event)
  }
  onVerticalPanUpdate = (event: GestureEvent) => {
    console.log('onVerticalPanUpdate active: ' + event)
  }
  onVerticalPanEnd = () => {
    console.log('onVerticalPanEnd active')
  }
  onHorizonPanStart = (event: GestureEvent) => {
    console.log('onHorizonPanStart active: ' + event)
  }
  onHorizonPanUpdate = (event: GestureEvent) => {
    console.log('onHorizonPanUpdate active: ' + event)
  }
  onHorizonPanEnd = () => {
    console.log('onHorizonPanEnd active')
  }
  onPinchStart = (event: GestureEvent) => {
    console.log('onPinchStart active: ' + event)
  }
  onPinchUpdate = (event: GestureEvent) => {
    console.log('onPinchUpdate active: ' + event)
  }
  onLongPressAction = () => {
    console.log('onLongPressAction active')
  }
  onLongPressEnd = () => {
    console.log('onLongPressEnd active')
  }
  onLongPressPanStart = (event: GestureEvent) => {
    console.log('onLongPressPanStart active: ' + event)
  }
  onLongPressPanUpdate = (event: GestureEvent) => {
    console.log('onLongPressPanUpdate active: ' + event)
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
                this.onDoubleClickAction(event)
              }),
            TapGesture({ count: 1 })// 单击事件
              .onAction(() => { //单击屏幕
                this.onSingleClickAction()
              }),
            PanGesture({ fingers: 1, direction: PanDirection.Vertical })// 垂直滑动
              .onActionStart((event: GestureEvent) => { // 滑动屏幕
                this.onVerticalPanStart(event)
              })
              .onActionUpdate((event: GestureEvent) => {
                this.onVerticalPanUpdate(event)
              })
              .onActionEnd(() => {
                this.onVerticalPanEnd()
              }),
            PanGesture({ fingers: 1, direction: PanDirection.Horizontal })// 水平滑动事件滑动调整进度
              .onActionStart((event: GestureEvent) => { // 长按且滑动屏幕
                this.onHorizonPanStart(event)
              })
              .onActionUpdate((event: GestureEvent) => {
                this.onHorizonPanUpdate(event)
              })
              .onActionEnd(() => {
                this.onHorizonPanEnd()
              }),
            PinchGesture({ fingers: 2, distance: 2 })//手势缩放
              .onActionStart((event: GestureEvent) => {
                this.onPinchStart(event)
              })
              .onActionUpdate((event: GestureEvent) => {
                this.onPinchUpdate(event)
              })
          ),
          GestureGroup(GestureMode.Parallel, // 不用互斥事件，会导致左右滑动调节倍速的功能失效
            LongPressGesture()// 长按手势
              .onAction(() => { //长按
                this.onLongPressAction()
              })
              .onActionEnd(() => {
                this.onLongPressEnd()
              }),
            PanGesture({
              fingers: 1,
              direction: PanDirection.Horizontal,
            })//水平滑动事件 长按加速滑动调整倍速
              .onActionStart((event: GestureEvent) => { // 长按且滑动屏幕
                this.onLongPressPanStart(event)
              })
              .onActionUpdate((event: GestureEvent) => {
                this.onLongPressPanUpdate(event)
              })
          )))
  }
}