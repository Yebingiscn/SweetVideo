@Component
export struct SubtitleDisplayComponent {
  @Prop subtitle: string
  @StorageLink('subtitleSize') subtitleSize: string = '22'
  @Link screenWidth: number
  @Link screenHeight: number
  @Link showControl: boolean
  @Prop subTitleVisibility: Visibility
  @Link playAreaWidth: number

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) { //字幕
      Text(this.subtitle)
        .fontColor('#F0F0F0')
        .fontSize(this.subtitleSize)
        .fontWeight(FontWeight.Medium)
        .textAlign(TextAlign.Center)
        .fontWeight(FontWeight.Normal)// 常规字重更清晰
        .textShadow({ color: Color.Black, type: ShadowType.BLUR, radius: 6 })
        .opacity(0.95) // 轻微透明度
    }
    .visibility(this.subTitleVisibility)
    .align(Alignment.Center)
    .width(this.playAreaWidth)
    .offset({ x: 0, y: this.screenHeight / 2 - 40 })
    .animation({ duration: 300, curve: Curve.Smooth })
  }
}