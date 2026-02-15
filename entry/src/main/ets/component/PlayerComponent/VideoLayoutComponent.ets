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
        .backgroundColor('#36ffffff')
        .width('100%')
        .padding({
          left: (this.screenHeight > this.screenWidth ? 20 : 35),
          right: 20,
          top: (this.showControl ? SafeHeight.topSafeHeight : 0),
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
        }.transition(XAnimation.getAnimation('bottom', 0, false))
        .backgroundColor($r('sys.color.mask_fourth'))
        .height(this.screenHeight > this.screenWidth ? 180 : 110)
        .width('100%')
      }.height('100%').width('100%')
    }
  }
}