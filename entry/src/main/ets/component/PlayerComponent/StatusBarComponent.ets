@Component
export struct StatusBarComponent {
  @Prop screenWidth: number
  @Prop screenHeight: number
  @Prop clockTime: string

  build() {
    Row() {
      Text(this.clockTime)
        .fontWeight(FontWeight.Medium)
        .fontSize(16)
        .fontColor($r('sys.color.white'))
        .textAlign(TextAlign.Center)
        .align(Alignment.Center)
    }
    .width('100%')
    .height(5)
    .justifyContent(FlexAlign.Center)
  }
}