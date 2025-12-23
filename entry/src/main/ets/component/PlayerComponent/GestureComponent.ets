import VideoOperateUtil from '../../utils/VideoOperateUtil';

@Component
export struct GestureComponent {
  @Link showControl: boolean
  @Link isLock: boolean
  onDoubleClickAction = (_tapX: number) => {
  };
  onSingleClickAction = () => {
  }
  onVerticalPanStart = (_tapX: number) => {
  }
  onVerticalPanUpdate = (_offsetY: number) => {
  }
  onVerticalPanEnd = () => {
  }
  onHorizonPanStart = () => {
  }
  onHorizonPanUpdate = (_offsetY: number) => {
  }
  onHorizonPanEnd = () => {
  }
  onPinchStart = (_fingerDistance: number) => {
  }
  onPinchUpdate = (_fingerDistance: number) => {
  }
  onLongPressAction = () => {
  }
  onLongPressEnd = () => {
  }
  onLongPressPanStart = (_tapX: number) => {
  }
  onLongPressPanUpdate = (_tapX: number) => {
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
                const tapX = event.fingerList[0]?.localX
                if (!VideoOperateUtil.checkLocalX(tapX)) {
                  return
                }
                this.onDoubleClickAction(tapX)
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
                const tapX = event.fingerList[0]?.localX
                if (!VideoOperateUtil.checkLocalX(tapX)) {
                  return
                }
                this.onVerticalPanStart(tapX)
              })
              .onActionUpdate((event: GestureEvent) => {
                if (this.isLock) {
                  return
                }
                if (event.fingerList?.length !== 1) {
                  return
                }
                this.onVerticalPanUpdate(event?.offsetY)
              })
              .onActionEnd(() => {
                if (this.isLock) {
                  return
                }
                this.onVerticalPanEnd()
              }),
            PanGesture({ fingers: 1, direction: PanDirection.Horizontal })// 水平滑动事件滑动调整进度
              .onActionStart((_event: GestureEvent) => { // 长按且滑动屏幕
                if (this.isLock) {
                  return
                }
                this.onHorizonPanStart()
              })
              .onActionUpdate((event: GestureEvent) => {
                if (this.isLock) {
                  return
                }
                if (!VideoOperateUtil.checkLocalX(event?.fingerList?.[0]?.localX)) {
                  return
                }
                this.onHorizonPanUpdate(event?.offsetX)
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
                const finger1 = event.fingerList[0]
                const finger2 = event.fingerList[1]
                const fingerDistance = VideoOperateUtil.calcFingerDistance(finger1, finger2)
                if (fingerDistance < 0) {
                  return
                }
                this.onPinchStart(fingerDistance)
              })
              .onActionUpdate((event: GestureEvent) => {
                if (this.isLock) {
                  return
                }
                const finger1 = event.fingerList[0]
                const finger2 = event.fingerList[1]
                if (!finger1 || !finger2) { // 双指检测失败直接返回
                  return;
                }
                const fingerDistance = VideoOperateUtil.calcFingerDistance(finger1, finger2)
                if (fingerDistance < 0) {
                  return
                }
                this.onPinchUpdate(fingerDistance)
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
                const tapX = event.fingerList[0]?.localX
                if (!VideoOperateUtil.checkLocalX(tapX)) {
                  return
                }
                this.onLongPressPanStart(tapX)
              })
              .onActionUpdate((event: GestureEvent) => {
                if (this.isLock) {
                  return
                }
                const tapX = event.fingerList[0]?.localX
                if (!VideoOperateUtil.checkLocalX(tapX)) {
                  return
                }
                this.onLongPressPanUpdate(tapX)
              })
          )))
  }
}