import TimeUtil from '../../utils/TimeUtil'
import ToolsUtil from '../../utils/ToolsUtil'
import { SweetAgentComponent } from '../common/SweetAgentComponent]'


export class AppInfoBuilderParams {
  topSafeHeight: number = 0
}

@Builder
export function AppInfoBuilder(params: AppInfoBuilderParams) {
  Row() {
    Image($r("app.media.Foreground"))
      .width(50)
      .height(50)
      .interpolation(ImageInterpolation.Medium)// 用于重采样后的抗锯齿
      .draggable(false)// 禁止长按手势拖动
      .autoResize(true) // 重采样，可减少内存占用
    Text(TimeUtil.getTextByTime())
      .fontSize(20)
      .fontColor($r('app.color.text_color'))
      .margin({ left: 5, right: 12 })
      .textOverflow({ overflow: TextOverflow.MARQUEE })
    SweetAgentComponent()
  }
  .width('100%')
  .justifyContent(FlexAlign.Center)
  .margin({ top: params.topSafeHeight })
  .clickEffect({ level: ClickEffectLevel.HEAVY, scale: 0.9 })
  .onClick(() => {
    ToolsUtil.startVibration()
    ToolsUtil.showToast('不管多么难熬，人生都要眉开眼笑 ( •̀ ω •́ )✧')
  })
}

@ObservedV2
export class SideBarController {
  @Trace mode: SideBarContainerType = SideBarContainerType.Embed
  @Trace visibility: Visibility = Visibility.Hidden
  @Trace overlay: boolean = false
  @Trace isShow: boolean = false

  public open() {
    if (this.mode === SideBarContainerType.Overlay) {
      this.visibility = Visibility.Visible
      this.overlay = true
      this.isShow = true
    }
    if (this.visibility == Visibility.Hidden) {
      this.overlay = false
    }
  }

  public close(isPlayAnimation: boolean) {
    if (this.mode === SideBarContainerType.Overlay) {
      this.visibility = Visibility.Hidden
      isPlayAnimation ? setTimeout(() => {
        this.isShow = false
        this.overlay = false
      }, 200) : this.isShow = false
    }
    this.overlay = false
  }
}