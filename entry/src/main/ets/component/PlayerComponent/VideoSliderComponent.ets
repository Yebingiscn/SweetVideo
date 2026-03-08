import TimeUtil from '../../utils/TimeUtil'

@Component
export struct VideoSliderComponent {
  @Prop playTime: number
  @Prop totalTime: number
  @Prop screenWidth: number
  @Prop screenHeight: number
  @Prop playSpeed: number
  onSliderChange = (_value: number) => {
  }
  onSliderTouch = (_event: TouchEvent) => {
  }

  build() {
    Column() {
      Row() {
        Text(TimeUtil.getPlayTime(this.playTime, this.totalTime) + '/' +
        TimeUtil.convertMSToHHMMSS(this.totalTime || 0))
          .fontWeight(FontWeight.Medium)
          .fontSize(16)
          .fontColor($r('sys.color.white'))
          .textAlign(TextAlign.Start)
          .opacity(0.8)

        Text(TimeUtil.getRemainTime(this.playTime, this.totalTime, this.playSpeed))
          .fontWeight(FontWeight.Medium)
          .fontSize(16)
          .fontColor($r('sys.color.white'))
          .textAlign(TextAlign.End)
          .opacity(0.8)
      }.width('100%').height('auto')
      .justifyContent(FlexAlign.SpaceBetween)

      Slider({
        value: this.playTime,
        min: 0,
        max: this.totalTime,
        style: SliderStyle.NONE
      })
        .trackThickness(12)
        .selectedBorderRadius(16)
        .onChange((value) => {
          this.onSliderChange(value)
        })
        .onTouch((event) => {
          this.onSliderTouch(event)
        })
        .animation({ duration: 100, curve: Curve.Smooth })
        .selectedColor('#e0e0e0')
        .height('auto')
        .width('100%')
        .opacity(0.8)
    }.height('auto').width('90%')
  }
}