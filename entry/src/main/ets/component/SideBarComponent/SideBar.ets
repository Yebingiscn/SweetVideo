import { ImageFancyModifier } from '../../common/AttributeModifierConfig';
import TimeUtil from '../../utils/TimeUtil';
import ToolsUtil from '../../utils/ToolsUtil';


export class AppInfoBuilderParams {
  topSafeHeight: number = 0;
}

@Builder
export function AppInfoBuilder(params: AppInfoBuilderParams) {
  Stack() {
    Image($r("app.media.Background"))
      .attributeModifier(new ImageFancyModifier(16, '100%', 120))
      .zIndex(1)
    Row() {
      Image($r("app.media.Foreground"))
        .width(50)
        .height(50)
        .interpolation(ImageInterpolation.Medium)// 用于重采样后的抗锯齿
        .draggable(false)// 禁止长按手势拖动
        .autoResize(true) // 重采样，可减少内存占用
      Text(TimeUtil.getTextByTime())
        .fontSize(20)
        .fontColor('#ffff')
        .margin({ left: 5, right: 12 })
        .textOverflow({ overflow: TextOverflow.MARQUEE })
    }.width('100%')
    .justifyContent(FlexAlign.Center)
    .zIndex(2)
  }.margin({ top: params.topSafeHeight }).clickEffect({ level: ClickEffectLevel.HEAVY, scale: 0.9 }).onClick(() => {
    ToolsUtil.startVibration()
    ToolsUtil.showToast('不管多么难熬，人生都要眉开眼笑 ( •̀ ω •́ )✧')
  })
}

@Observed
export class SideBarController {
  mode: SideBarContainerType = SideBarContainerType.Embed
  visibility: Visibility = Visibility.Hidden
  overlay: boolean = false
  isShow: boolean = false

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