import { curves } from '@kit.ArkUI';
import { SideBarController } from './SideBar';

@Builder
export function MaskComponent(sideBarController: SideBarController) {
  Column()
    .height('100%')
    .width('100%')
    .backgroundBlurStyle(BlurStyle.BACKGROUND_THIN)
    .transition(TransitionEffect.OPACITY.animation({
      curve: curves.springMotion(0, 1)
    }))
    .scale({
      x: sideBarController.sideBarStatus === true ? 1.05 : 1,
      y: sideBarController.sideBarStatus ? 1.05 : 1
    })
    .zIndex(1)
    .onClick(() => {
      sideBarController.closeSideBar(true);
    })
}