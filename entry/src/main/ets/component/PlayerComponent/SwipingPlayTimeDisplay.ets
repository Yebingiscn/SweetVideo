import TimeUtil from '../../utils/TimeUtil'

@Component
export struct SwipingPlayTimeDisplay {
  @Link isSliderPlayTimeChange: boolean
  @Link playTime: number
  @Prop lastPlayTime: number
  @Prop totalTime: number

  build() {
    Stack() { // 滑动控制栏
      Text(this.isSliderPlayTimeChange ?
        TimeUtil.convertMSToHHMMSS(this.playTime) + '/' + TimeUtil.convertMSToHHMMSS(this.totalTime) :
        (this.playTime - this.lastPlayTime > 0 ? '+' : '') +
        Math.floor((this.playTime - this.lastPlayTime) / 1000) + 's : ' +
        TimeUtil.convertMSToHHMMSS(this.playTime) + '/' + TimeUtil.convertMSToHHMMSS(this.totalTime))
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
}