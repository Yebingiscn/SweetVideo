@Component
export struct StatusBarComponent {
  @Prop screenWidth: number
  @Prop screenHeight: number
  @Prop clockTime: string

  build() {
    if (this.screenWidth > this.screenHeight) {
      Row() {
        Text(this.clockTime)
          .fontWeight(FontWeight.Medium)
          .fontSize(16)
          .fontColor($r('sys.color.white'))
          .textAlign(TextAlign.Center)
          .align(Alignment.Center)
      }.width('100%')
      .height(15) //临时解决PC MODE下遮挡的问题
      .justifyContent(FlexAlign.Center)
    }
  }
}