import { curves } from '@kit.ArkUI';

@Component
export struct MaskComponent {
  onClose: () => void = () => {
  }

  build() {
    Column()
      .height('100%')
      .width('100%')
      .backgroundBlurStyle(BlurStyle.BACKGROUND_THIN)
      .transition(TransitionEffect.OPACITY.animation({
        curve: curves.springMotion(0, 1)
      }))
      .zIndex(1)
      .onClick(() => {
        this.onClose(); // 调用父组件关闭逻辑
      })
  }
}