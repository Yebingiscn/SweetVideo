import { Subtitle3DMode } from '../../common/enum/SubtitleMode'
import { Setting } from '../../utils/ObservedUtil'

class SubtitleDisplayValue {
  subtitle: string = ''
  screenWidth: number = 0
  screenHeight: number = 0
  showControl: boolean = false
  subTitleVisibility: Visibility = Visibility.None
  subtitle3DMode: Subtitle3DMode = Subtitle3DMode.DISABLED
  playAreaWidth: number = 0
  playAreaHeight: number = 0
}

@Builder
export function SubtitleDisplayBuilder(subtitleDisplayValue: SubtitleDisplayValue) {
  Stack({ alignContent: Alignment.BottomEnd }) { //字幕
    if (subtitleDisplayValue.subtitle3DMode === Subtitle3DMode.DISABLED) {
      Text(subtitleDisplayValue.subtitle)
        .subtitleTextExtend()
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
    } else if (subtitleDisplayValue.subtitle3DMode === Subtitle3DMode.TOP_AND_BOTTOM) {
      Column({ space: subtitleDisplayValue.playAreaHeight / 2}) {
        Text(subtitleDisplayValue.subtitle)
          .subtitleTextExtend()
          .scale({
            y: 0.5
          })
        Text(subtitleDisplayValue.subtitle)
          .subtitleTextExtend()
          .scale({
            y: 0.5
          })
      }
      .justifyContent(FlexAlign.Start)
      .width("100%")
    }
  }
  .visibility(subtitleDisplayValue.subTitleVisibility)
  .align(Alignment.Center)
  .width(subtitleDisplayValue.playAreaWidth)
  .offset(subtitleDisplayValue.subtitle3DMode === Subtitle3DMode.TOP_AND_BOTTOM ?
    { x: 0, y: subtitleDisplayValue.playAreaHeight / 4 - 40 } :
    { x: 0, y: subtitleDisplayValue.playAreaHeight / 2 - 40 }
  )
  .animation({ duration: 300, curve: Curve.Smooth })
}

@Extend(Text)
function subtitleTextExtend() {
  .fontColor('#F0F0F0')
  .fontSize(Setting.subtitleSize)
  .fontWeight(FontWeight.Medium)
  .textAlign(TextAlign.Center)
  .fontWeight(FontWeight.Normal) // 常规字重更清晰
  .textShadow({ color: Color.Black, type: ShadowType.BLUR, radius: 6 })
  .opacity(0.95) // 轻微透明度
}
