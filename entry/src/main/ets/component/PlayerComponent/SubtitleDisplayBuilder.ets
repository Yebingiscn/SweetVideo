import { Subtitle3DMode } from '../../common/enum/SubtitleMode'
import { Setting } from '../../utils/ObservedUtil'

class SubtitleDisplayValue {
  subtitle: string = ''
  screenWidth: number = 0
  screenHeight: number = 0
  showControl: boolean = false
  subTitleVisibility: Visibility = Visibility.None
  subtitle3DMode: Subtitle3DMode = Subtitle3DMode.DISABLED
  areaWidth: number = 0
  areaHeight: number = 0
}

@Builder
export function SubtitleDisplayBuilder(subtitleDisplayValue: SubtitleDisplayValue) {
  Column() {
    Blank()
    if (subtitleDisplayValue.subtitle3DMode === Subtitle3DMode.DISABLED) {
      Text(subtitleDisplayValue.subtitle)
        .subtitleTextExtend()
        .margin({ bottom: 20 })
    } else if (subtitleDisplayValue.subtitle3DMode === Subtitle3DMode.SIDE_BY_SIDE) {
      Row() {
        Text(subtitleDisplayValue.subtitle)
          .subtitleTextExtend()
          .scale({
            x: 0.5
          })
        Text(subtitleDisplayValue.subtitle)
          .subtitleTextExtend()
          .scale({
            x: 0.5
          })
      }
      .justifyContent(FlexAlign.SpaceAround)
      .width("100%")
      .margin({ bottom: 20 })
    } else if (subtitleDisplayValue.subtitle3DMode === Subtitle3DMode.TOP_AND_BOTTOM) {
      Column() {
        Text(subtitleDisplayValue.subtitle)
          .subtitleTextExtend()
          .scale({
            y: 0.5
          })
        Blank()
        Text(subtitleDisplayValue.subtitle)
          .subtitleTextExtend()
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
  .animation({ duration: 300, curve: Curve.Smooth })
}

@Extend(Text)
function subtitleTextExtend() {
  .fontColor('#F0F0F0')
  .fontSize(Setting.subtitleSize)
  .fontWeight(FontWeight.Medium)
  .textAlign(TextAlign.Center)
  .fontWeight(FontWeight.Normal)
  .textShadow({ color: Color.Black, type: ShadowType.BLUR, radius: 6 })
  .opacity(0.95)
}
