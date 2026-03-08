import { XAnimation } from '../../utils/AnimationUtil'
import { SafeHeight } from '../../utils/ObservedUtil'

@Component
export struct VideoLayoutComponent {
  @Prop screenHeight: number
  @Prop screenWidth: number
  @Link showControl: boolean
  @BuilderParam VideoTop: () => void
  @BuilderParam VideoButtons: () => void
  @BuilderParam VideoSlider: () => void

  build() {
    Stack() {
      Flex({
        justifyContent: FlexAlign.SpaceBetween,
        alignItems: ItemAlign.Center,
        direction: FlexDirection.Column
      }) { //顶栏
        Flex({ justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Center }) {
          this.VideoTop()
        }
        .transition(XAnimation.getAnimation('up', 0, false))
        .height(90)
        .linearGradient({
          angle: 0,
          colors: [[Color.Transparent, 0], ['#90000000', 0.75]]
        })
        .width('100%')
        .padding({
          left: (this.screenHeight > this.screenWidth ? 20 : 35),
          right: 20,
          top: SafeHeight.topSafeHeight,
          bottom: 0
        })

        Stack() { //底栏
          if (this.screenHeight / this.screenWidth > 1.4) {
            Column({ space: 15 }) {
              this.VideoButtons()
              this.VideoSlider()
            }
          } else {
            Row({ space: 15 }) {
              Column() {
                this.VideoSlider()
                this.VideoButtons()
              }
            }
          }
        }
        .transition(XAnimation.getAnimation('bottom', 0, false))
        .linearGradient({
          angle: 180,
          colors: [[Color.Transparent, 0], ['#90000000', 0.75]]
        })
        .height(this.screenHeight > this.screenWidth ? 180 : 'auto')
        .width('100%')
        .padding({ bottom: SafeHeight.bottomSafeHeight })
      }.height('100%').width('100%')
    }
  }
}