import VideoInfoUtil from '../../utils/VideoInfoUtil'

@Component
export struct FastForwardInfoComponent {
  @Link speed: number
  @Prop location: number
  private list: string[] = VideoInfoUtil.getVideoSpeedTextList()

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column() {
        Text(VideoInfoUtil.optimizedFormat(this.speed) + ' ⏩')
          .fontColor($r('app.color.main_color')).fontSize(15)
          .fontWeight(FontWeight.Bold)
        Row() {
          Text(`← ${this.getLastAndNextItem(VideoInfoUtil.optimizedFormat(this.speed))[0]}`)
            .fontColor($r('sys.color.white')).margin({ right: 10 }).fontSize(10)
          Text(`${this.getLastAndNextItem(VideoInfoUtil.optimizedFormat(this.speed))[1]} →`)
            .fontColor($r('sys.color.white')).fontSize(10)
        }.justifyContent(FlexAlign.SpaceBetween).margin({ top: 5 })
      }
    }
    .padding({
      left: 10,
      right: 10,
      top: 10,
      bottom: 10
    })
    .offset({ x: 0, y: this.location })
    .borderRadius(1000) // 胶囊形状背景
    .backgroundColor('#30000000') // 半透明黑色背景
    .backdropBlur(100) // 背景模糊效果
    .animation({ duration: 300, curve: Curve.Smooth })
  }

  getLastAndNextItem(targetItem: string) {
    const listIndex = this.list.findIndex(i => i === targetItem)
    const prevIndex = (listIndex - 1 + this.list.length) % this.list.length
    const nextIndex = (listIndex + 1) % this.list.length
    return [this.list[prevIndex], this.list[nextIndex]]
  }
}