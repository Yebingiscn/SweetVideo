import { SpeedListDataSource } from '../../utils/DataUtil'
import VideoInfoUtil from '../../utils/VideoInfoUtil'

@Component
export struct FastForwardInfoComponent {
  @Link speed: number
  @Prop location: number
  @State speedListDataSource: SpeedListDataSource = new SpeedListDataSource([])

  aboutToAppear(): void {
    this.speedListDataSource = new SpeedListDataSource(VideoInfoUtil.getVideoSpeedTextList())
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Row() {
        LazyForEach(this.speedListDataSource, (item: string, index) => {
          Text(`${item}${item === VideoInfoUtil.optimizedFormat(this.speed) ? ' ⏩' : ''}`)
            .fontColor(item === VideoInfoUtil.optimizedFormat(this.speed) ? $r('app.color.main_color') :
              $r('sys.color.white'))
            .fontSize(15)
            .opacity(item === VideoInfoUtil.optimizedFormat(this.speed) ? 1 : 0.6)// 当前速度不透明，其他半透明
            .fontWeight(item === VideoInfoUtil.optimizedFormat(this.speed) ? FontWeight.Bold : FontWeight.Normal)
            .margin({ right: index < VideoInfoUtil.getVideoSpeedTextList().length - 1 ? 10 : 0 }) // 项间距
        },
          (item: string) => item.toString() // 唯一键生成
        )
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
}