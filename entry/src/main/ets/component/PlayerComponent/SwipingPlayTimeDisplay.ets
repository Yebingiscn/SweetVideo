import TimeUtil from '../../utils/TimeUtil'
import VideoOperateUtil from '../../utils/VideoOperateUtil'

@Component
export struct SwipingPlayTimeDisplay {
  @Link isSliderPlayTimeChange: boolean
  @Prop playTime: number
  @Prop totalTime: number

  build() {
    Stack() { // 滑动控制栏
      Text(this.getFormattedTimeText())
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

  getFormattedTimeText(): string {
    const currentTime = TimeUtil.convertMSToHHMMSS(this.playTime);
    const totalTime = TimeUtil.convertMSToHHMMSS(this.totalTime);
    if (this.isSliderPlayTimeChange) {
      return `${currentTime}/${totalTime}`;
    } else {
      const timeDiff = Math.floor((this.playTime - VideoOperateUtil.lastPlayTime) / 1000);
      const sign = timeDiff > 0 ? '+' : '';
      return `${sign}${timeDiff}s : ${currentTime}/${totalTime}`;
    }
  }
}