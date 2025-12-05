import TimeUtil from '../../utils/TimeUtil'
import VideoOperateUtil from '../../utils/VideoOperateUtil'

class SwipingPlayTimeValue {
  isSliderPlayTimeChange: boolean = false
  playTime: number = 0
  totalTime: number = 0
}

@Builder
export function SwipingPlayTimePanelBuilder(swipingPlayTimeValue: SwipingPlayTimeValue) {
  Stack() { // 滑动控制栏
    Text(getFormattedTimeText(swipingPlayTimeValue))
      .fontColor($r('sys.color.white'))
      .fontSize(25)
      .fontWeight(FontWeight.Bold)
  }
  .padding({
    left: 25,
    right: 25,
    top: 10,
    bottom: 10
  })
  .borderRadius(1000)
  .backgroundColor('#30000000')
  .backdropBlur(100)
  .animation({ duration: 300, curve: Curve.Smooth })
}

export function getFormattedTimeText(swipingPlayTimeValue: SwipingPlayTimeValue): string {
  const currentTime = TimeUtil.convertMSToHHMMSS(swipingPlayTimeValue.playTime);
  const totalTime = TimeUtil.convertMSToHHMMSS(swipingPlayTimeValue.totalTime);
  if (swipingPlayTimeValue.isSliderPlayTimeChange) {
    return `${currentTime}/${totalTime}`;
  } else {
    const timeDiff = Math.floor((swipingPlayTimeValue.playTime - VideoOperateUtil.lastPlayTime) / 1000);
    const sign = timeDiff > 0 ? '+' : '';
    return `${sign}${timeDiff}s : ${currentTime}/${totalTime}`;
  }
}