import { curves } from '@kit.ArkUI';
import { SideBarController } from './SideBar';

@Component
export struct MaskComponent {
  sideBarController: SideBarController = new SideBarController()

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
        this.sideBarController.closeSideBar(true);
      })
  }
}