import { curves } from '@kit.ArkUI'
import { SideBarController } from './SideBar'
import { Setting } from '../../utils/ObservedUtil'

class SideBarValue {
  sideBarController: SideBarController | undefined = undefined
}

@Builder
export function MaskComponent(sideBarValue: SideBarValue) {
  Column()
  // 遮罩需要大于屏幕宽高，否则会在边缘露出小鸡脚
    .height('200%')
    .width('200%')
    .backdropBlur(Setting.backgroundDropBlur > 0 ? Setting.backgroundDropBlur : 20)
    .transition(TransitionEffect.OPACITY.animation({
      curve: curves.springMotion(0, 1)
    }))
    .scale({
      x: sideBarValue.sideBarController?.isShow === true ? 1.05 : 1,
      y: sideBarValue.sideBarController?.isShow ? 1.05 : 1
    })
    .zIndex(1)
    .onClick(() => {
      sideBarValue.sideBarController?.close(true)
    })
}