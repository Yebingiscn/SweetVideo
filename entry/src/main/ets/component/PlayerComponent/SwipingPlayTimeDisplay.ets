import TimeUtil from '../../utils/TimeUtil'

@Component
export struct SwipingPlayTimeDisplay {
  @Prop isSliderPlayTimeChange: boolean
  @Prop playTime: number
  @Prop lastPlayTime: number
  @Prop totalTime: number

  build() {
    Stack() { // 滑动控制栏
      Text(this.isSliderPlayTimeChange ?
        TimeUtil.convertMsToMMSS(this.playTime) + '/' + TimeUtil.convertMsToMMSS(this.totalTime) :
        (this.playTime - this.lastPlayTime > 0 ? '+' : '') +
        Math.floor((this.playTime - this.lastPlayTime) / 1000) + 's : ' +
        TimeUtil.convertMsToMMSS(this.playTime) + '/' + TimeUtil.convertMsToMMSS(this.totalTime))
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