import VideoInfoUtil from '../../utils/VideoInfoUtil'

@Component
export struct FastForwardInfoComponent {
  @Prop speed: number
  @Prop location: number

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) { //快进提示
      Text(VideoInfoUtil.optimizedFormat(this.speed) + ' ⏩')
        .fontColor($r('sys.color.white'))
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
    }
    .padding({
      left: 25,
      right: 25,
      top: 10,
      bottom: 10
    })
    .offset({ x: 0, y: this.location })
    .borderRadius(1000)
    .backgroundColor('#30000000')
    .backdropBlur(100)
    .animation({ duration: 300, curve: Curve.Smooth })
  }
}