import VideoInfoUtil from '../../utils/VideoInfoUtil'

@Component
export struct SubtitleComponent {
  @Prop subTitle: string
  @StorageLink('subtitleSize') subtitleSize: string = '22'
  @Prop screenWidth: number
  @Prop screenHeight: number
  @Prop showControl: boolean
  @Prop subTitleVisibility: Visibility
  @Prop playAreaWidth: number

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) { //字幕
      Text(this.subTitle)
        .fontColor('#F0F0F0')
        .fontSize(this.subtitleSize)
        .fontWeight(FontWeight.Medium)
        .textAlign(TextAlign.Center)
        .fontWeight(FontWeight.Normal)// 常规字重更清晰
        .opacity(0.95)// 轻微透明度
        .offset({
          x: 0,
          y: this.screenWidth > this.screenHeight && this.showControl ? -120 : 0
        })
    }
    .visibility(this.subTitleVisibility)
    .align(Alignment.Center)
    .width(this.playAreaWidth)
    .offset({ x: 0, y: VideoInfoUtil.play_area_height / 2 - 40 })
    .animation({ duration: 300, curve: Curve.Smooth })
  }
}