import { Subtitle3DMode } from '../../common/enum/SubtitleMode'
import { Setting } from '../../utils/ObservedUtil'
import SubtitleStyleUtil from '../../utils/SubtitleStyleUtil'

class SubtitleDisplayValue {
  subtitle: string = ''
  screenWidth: number = 0
  screenHeight: number = 0
  showControl: boolean = false
  subTitleVisibility: Visibility = Visibility.None
  subtitle3DMode: Subtitle3DMode = Subtitle3DMode.DISABLED
  subtitlePosition: number = 95
  subtitleSize: number = 22
  areaWidth: number = 0
  areaHeight: number = 0
  angle: number = 0
  scaleFactor: number = 1
  translateX: number = 0
  translateY: number = 0
  animDuration: number = 300
}

@Builder
export function SubtitleDisplayBuilder(subtitleDisplayValue: SubtitleDisplayValue) {
  Column() {
    Blank()
    if (subtitleDisplayValue.subtitle3DMode === Subtitle3DMode.DISABLED) {
      Text(subtitleDisplayValue.subtitle)
        .subtitleTextExtend(subtitleDisplayValue.subtitleSize)
        .margin({ bottom: SubtitleStyleUtil.getSubtitleBottomMargin(subtitleDisplayValue.areaHeight,
          subtitleDisplayValue.subtitlePosition) })
    } else if (subtitleDisplayValue.subtitle3DMode === Subtitle3DMode.SIDE_BY_SIDE) {
      Row() {
        Text(subtitleDisplayValue.subtitle)
          .subtitleTextExtend(subtitleDisplayValue.subtitleSize)
          .scale({
            x: 0.5
          })
        Text(subtitleDisplayValue.subtitle)
          .subtitleTextExtend(subtitleDisplayValue.subtitleSize)
          .scale({
            x: 0.5
          })
      }
      .justifyContent(FlexAlign.SpaceAround)
      .width("100%")
      .margin({ bottom: SubtitleStyleUtil.getSubtitleBottomMargin(subtitleDisplayValue.areaHeight,
        subtitleDisplayValue.subtitlePosition) })
    } else if (subtitleDisplayValue.subtitle3DMode === Subtitle3DMode.TOP_AND_BOTTOM) {
      Column() {
        Text(subtitleDisplayValue.subtitle)
          .subtitleTextExtend(subtitleDisplayValue.subtitleSize)
          .scale({
            y: 0.5
          })
        Blank()
        Text(subtitleDisplayValue.subtitle)
          .subtitleTextExtend(subtitleDisplayValue.subtitleSize)
          .scale({
            y: 0.5
          })
      }
      .justifyContent(FlexAlign.SpaceBetween)
      .width("100%")
      .height("100%")
    }
  }
  .visibility(subtitleDisplayValue.subTitleVisibility)
  .width(subtitleDisplayValue.areaWidth)
  .height(subtitleDisplayValue.areaHeight)
  .justifyContent(FlexAlign.End)
  .hitTestBehavior(HitTestMode.Transparent)
  .rotate({ y: 2, angle: subtitleDisplayValue.angle, perspective: 200 })
  .scale({ x: subtitleDisplayValue.scaleFactor, y: subtitleDisplayValue.scaleFactor })
  .translate({ x: subtitleDisplayValue.translateX, y: subtitleDisplayValue.translateY })
  .animation({ duration: subtitleDisplayValue.animDuration, curve: Curve.Ease })
}

@Extend(Text)
function subtitleTextExtend(subtitleSize: number) {
  .fontColor(Setting.subtitleColor)
  .fontSize(subtitleSize)
  .textAlign(TextAlign.Center)
  .fontWeight(Setting.subtitleBold ? FontWeight.Bold : FontWeight.Normal)
  .fontStyle(Setting.subtitleItalic ? FontStyle.Italic : FontStyle.Normal)
  .textShadow(getSubtitleShadow())

  .backgroundColor(SubtitleStyleUtil.getAppBackgroundColor())
  .borderRadius(4)
  .padding({ left: 8, right: 8, top: 2, bottom: 2 })
  .opacity(0.95)
}

function getSubtitleShadow(): ShadowOptions[] {
  const shadows: ShadowOptions[] = []
  if (Setting.subtitleBorderSize > 0) {
    shadows.push({
      color: Setting.subtitleBorderColor,
      type: ShadowType.BLUR,
      radius: Setting.subtitleBorderSize
    })
  }
  if (Setting.subtitleShadowEnabled && Setting.subtitleShadowSize > 0) {
    shadows.push({
      color: Setting.subtitleShadowColor,
      type: ShadowType.BLUR,
      radius: Setting.subtitleShadowSize,
      offsetX: 2,
      offsetY: 2
    })
  }
  return shadows
}
