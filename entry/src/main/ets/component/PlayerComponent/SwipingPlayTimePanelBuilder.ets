import { ImageFancyModifier } from '../../common/AttributeModifierConfig'
import { Setting } from '../../utils/ObservedUtil'
import TimeUtil from '../../utils/TimeUtil'
import VideoOperateUtil from '../../utils/VideoOperateUtil'
import { DIALOG_TITLE_FONT_SIZE } from '../../common/Constants'

class SwipingPlayTimeValue {
  isSliderPlayTimeChange: boolean = false
  playTime: number = 0
  totalTime: number = 0
  pixelMap: PixelMap | null = null
}

@Builder
export function SwipingPlayTimePanelBuilder(swipingPlayTimeValue: SwipingPlayTimeValue) {
  if (swipingPlayTimeValue) {
    Column() { // 滑动控制栏
      Text(getFormattedTimeText(swipingPlayTimeValue))
        .fontColor($r('sys.color.white'))
        .fontSize(DIALOG_TITLE_FONT_SIZE)
        .fontWeight(FontWeight.Bold)
      if (Setting?.showFrameImgStatus) {
        if (swipingPlayTimeValue?.pixelMap) {
          Image(swipingPlayTimeValue?.pixelMap)
            .attributeModifier(new ImageFancyModifier(16, 160, 90))
            .objectFit(ImageFit.Cover)
            .borderRadius(16)
            .clip(true)
        }
      }
    }
    .padding({
      left: 25,
      right: 25,
      top: 10,
      bottom: 10
    })
    .borderRadius(16)
    .backgroundColor('#30000000')
    .backdropBlur(100)
    .animation({ duration: 300, curve: Curve.Friction })
  }
}

export function getFormattedTimeText(swipingPlayTimeValue: SwipingPlayTimeValue): string {
  if (!swipingPlayTimeValue) {
    return "00:00/00:00"
  }
  const playTime = swipingPlayTimeValue?.playTime || 0
  const totalTime = swipingPlayTimeValue?.totalTime || 0
  const currentTime = TimeUtil?.convertMSToHHMMSS(playTime)
  const totalTimeStr = TimeUtil?.convertMSToHHMMSS(totalTime)
  if (swipingPlayTimeValue?.isSliderPlayTimeChange) {
    return `${currentTime}/${totalTimeStr}`
  } else {
    const lastPlayTime = typeof VideoOperateUtil?.lastPlayTime === 'number'
      ? VideoOperateUtil?.lastPlayTime
      : 0
    const timeDiff = Math.floor((playTime - lastPlayTime) / 1000)
    const sign = timeDiff > 0 ? '+' : ''
    return `${sign}${timeDiff}s : ${currentTime}/${totalTimeStr}`
  }
}