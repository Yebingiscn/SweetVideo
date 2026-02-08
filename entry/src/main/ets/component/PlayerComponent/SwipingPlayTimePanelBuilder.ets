import { ImageFancyModifier } from '../../common/AttributeModifierConfig'
import NavigationAddress from '../../common/NavigationCommon'
import { Setting } from '../../utils/ObservedUtil'
import TimeUtil from '../../utils/TimeUtil'
import VideoOperateUtil from '../../utils/VideoOperateUtil'

class SwipingPlayTimeValue {
  isSliderPlayTimeChange: boolean = false
  playTime: number = 0
  totalTime: number = 0
  pixelMap: PixelMap | null = null
  player: string = ''
}

@Builder
export function SwipingPlayTimePanelBuilder(swipingPlayTimeValue: SwipingPlayTimeValue) {
  if (swipingPlayTimeValue) {
    Column() { // 滑动控制栏
      Text(getFormattedTimeText(swipingPlayTimeValue))
        .fontColor($r('sys.color.white'))
        .fontSize(25)
        .fontWeight(FontWeight.Bold)
      if (Setting.showFrameImgStatus && swipingPlayTimeValue.player === NavigationAddress.AV_PLAYER) {
        // 添加 pixelMap 检查
        if (swipingPlayTimeValue.pixelMap) {
          Image(swipingPlayTimeValue.pixelMap)
            .attributeModifier(new ImageFancyModifier(16, 100, 100))
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
    .animation({ duration: 300, curve: Curve.Smooth })
  }
}

export function getFormattedTimeText(swipingPlayTimeValue: SwipingPlayTimeValue): string {
  // 添加参数检查
  if (!swipingPlayTimeValue) {
    return "00:00/00:00"
  }

  // 使用默认值防止 NaN
  const playTime = swipingPlayTimeValue.playTime || 0
  const totalTime = swipingPlayTimeValue.totalTime || 0

  const currentTime = TimeUtil.convertMSToHHMMSS(playTime)
  const totalTimeStr = TimeUtil.convertMSToHHMMSS(totalTime)

  if (swipingPlayTimeValue.isSliderPlayTimeChange) {
    return `${currentTime}/${totalTimeStr}`
  } else {
    // 安全访问 VideoOperateUtil.lastPlayTime
    const lastPlayTime = typeof VideoOperateUtil.lastPlayTime === 'number'
      ? VideoOperateUtil.lastPlayTime
      : 0
    const timeDiff = Math.floor((playTime - lastPlayTime) / 1000)
    const sign = timeDiff > 0 ? '+' : ''
    return `${sign}${timeDiff}s : ${currentTime}/${totalTimeStr}`
  }
}