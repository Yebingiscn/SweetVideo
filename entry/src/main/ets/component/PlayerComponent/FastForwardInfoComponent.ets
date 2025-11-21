import VideoInfoUtil from '../../utils/VideoInfoUtil'

@Component
export struct FastForwardInfoComponent {
  @Link speed: number
  @State location: number = 0
  private list: string[] = VideoInfoUtil.getVideoSpeedTextList()

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column() {
        Text(VideoInfoUtil.optimizedFormat(this.speed) + ' ⏩')
          .fontColor($r('app.color.main_color')).fontSize(15)
          .fontWeight(FontWeight.Bold)
        Row() {
          if (this.getLastAndNextItem(VideoInfoUtil.optimizedFormat(this.speed))[0] !== '') {
            Text(`← ${this.getLastAndNextItem(VideoInfoUtil.optimizedFormat(this.speed))[0]}`)
              .fontColor($r('sys.color.white')).margin({ right: 10 }).fontSize(10)
          }
          if (this.getLastAndNextItem(VideoInfoUtil.optimizedFormat(this.speed))[1] !== '') {
            Text(`${this.getLastAndNextItem(VideoInfoUtil.optimizedFormat(this.speed))[1]} →`)
              .fontColor($r('sys.color.white')).fontSize(10)
          }
        }.justifyContent(FlexAlign.SpaceBetween).margin({ top: 5 })
      }
    }
    .padding({
      left: 10,
      right: 10,
      top: 10,
      bottom: 10
    })
    .offset({
      x: 0,
      y: (this.location === -160 || this.location === -80) ?
        this.location :
        (this.location !== VideoInfoUtil.play_area_height && VideoInfoUtil.play_area_height !== 0 ?
          0 - VideoInfoUtil.play_area_height / 2 + 20 :
          0 - this.location / 2 + 20)
    })
    .borderRadius(1000) // 胶囊形状背景
    .backgroundColor('#30000000') // 半透明黑色背景
    .backdropBlur(100) // 背景模糊效果
    .animation({ duration: 300, curve: Curve.Smooth })
  }

  getLastAndNextItem(targetItem: string) {
    const listIndex = this.list.findIndex(i => i === targetItem)
    if (listIndex === -1) {
      return ['', ''] // 如果没找到，返回空字符串
    }
    // 如果是第一个元素（最小倍速），不显示左箭头
    const prevItem = listIndex === 0 ? '' : this.list[listIndex - 1]
    // 如果是最后一个元素（最大倍速），不显示右箭头
    const nextItem = listIndex === this.list.length - 1 ? '' : this.list[listIndex + 1]
    return [prevItem, nextItem]
  }
}