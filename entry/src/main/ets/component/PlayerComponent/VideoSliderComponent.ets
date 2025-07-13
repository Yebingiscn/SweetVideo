import TimeUtil from '../../utils/TimeUtil'

@Component
export struct VideoSliderComponent {
  @Prop playTime: number
  @Prop totalTime: number
  @Prop screenWidth: number
  @Prop screenHeight: number
  onSliderChange = (value: number) => {
    console.log('slider change: ' + value)
  }
  onSliderTouch = (event: TouchEvent) => {
    console.log('slider touch: ' + event.type)
  }

  build() {
    Row({ space: 10 }) {
      Row() { // 播放时间进度
        Text(TimeUtil.convertMsToMMSS(Math.min(Math.max(this.playTime, 0), (this.totalTime || 0))) + '/' +
        TimeUtil.convertMsToMMSS(this.totalTime || 0))
          .fontWeight(FontWeight.Medium)
          .fontSize(16)
          .fontColor($r('sys.color.white'))
          .textAlign(TextAlign.Start)
      }.backgroundColor('#50000000').padding(5).borderRadius(10).margin({ left: 5 })

      Slider({
        value: this.playTime,
        min: 0,
        max: this.totalTime,
        style: SliderStyle.InSet
      })
        .onChange((value) => {
          this.onSliderChange(value)
        })
        .onTouch((event) => {
          this.onSliderTouch(event)
        })
        .layoutWeight(1)
        .animation({ duration: 100, curve: Curve.Smooth })
        .selectedColor('#e0e0e0')
      if (this.screenWidth > this.screenHeight) {
        Row() { //剩余时间
          Text(TimeUtil.convertMsToMMSS(Math.min(Math.max((this.totalTime || 0) - this.playTime, 0),
            (this.totalTime || 0))))
            .fontWeight(FontWeight.Medium)
            .fontSize(15)
            .fontColor($r('sys.color.white'))
            .textAlign(TextAlign.End)
        }.backgroundColor('#50000000').padding(5).borderRadius(10).margin({ right: 5 })
      }
    }
  }
}