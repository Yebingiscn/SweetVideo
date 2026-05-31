import { curves } from '@kit.ArkUI'
import { SideBarController } from './SideBar'
import { Setting } from '../../utils/ObservedUtil'

class SideBarValue {
  sideBarController: SideBarController | undefined = undefined
}

@Builder
export function MaskComponent(sideBarValue: SideBarValue) {
  Column()
    .height('100%')
    .width('100%')
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