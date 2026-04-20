import { AVPlayerController } from '../../controller/AVPlayerController'
import { MpvController } from '../../controller/MpvController/MpvController'
import { XAnimation } from '../../utils/AnimationUtil'
import { SafeHeight } from '../../utils/ObservedUtil'

@Component
export struct VideoLayoutComponent {
  @Consume('player') player: AVPlayerController | MpvController
  @BuilderParam VideoTop: () => void
  @BuilderParam VideoButtons: () => void
  @BuilderParam VideoSlider: () => void

  build() {
    Column() {
      // 顶栏
      Row() {
        this.VideoTop()
      }
      .width('100%')
      .height(this.isPortrait() ? 90 : 80)
      .linearGradient(this.getTopGradient())
      .padding(this.getTopPadding())
      .transition(XAnimation.getAnimation('up', 0, false))
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Center)

      // 中间空白区域（自动填充）
      Blank()

      // 底栏
      this.buildBottomBar()
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
  }

  @Builder
  buildBottomBar() {
    Column() {
      if (this.isLongScreen()) {
        // 长屏：垂直布局
        Column({ space: 15 }) {
          this.VideoButtons()
          this.VideoSlider()
        }
      } else {
        // 普通屏幕：水平布局
        Column() {
          this.VideoSlider()
          this.VideoButtons()
        }
      }
    }
    .width('100%')
    .height(this.isPortrait() ? 180 : 'auto')
    .linearGradient(this.getBottomGradient())
    .padding({ bottom: SafeHeight.bottomSafeHeight === 0 ? 25 : SafeHeight.bottomSafeHeight })
    .transition(XAnimation.getAnimation('bottom', 0, false))
  }

  // 计算属性：是否为竖屏
  private isPortrait(): boolean {
    return this.player.screenHeight > this.player.screenWidth
  }

  // 计算属性：是否为长屏（高宽比 > 1.4）
  private isLongScreen(): boolean {
    return this.player.screenHeight / this.player.screenWidth > 1.4
  }

  // 获取顶栏渐变
  private getTopGradient(): LinearGradient {
    return {
      angle: 0,
      colors: [[Color.Transparent, 0], ['#90000000', 0.75]]
    }
  }

  // 获取底栏渐变
  private getBottomGradient(): LinearGradient {
    return {
      angle: 180,
      colors: [[Color.Transparent, 0], ['#90000000', 0.75]]
    }
  }

  // 获取顶栏 padding
  private getTopPadding(): Padding {
    return {
      left: this.isPortrait() ? 20 : 35,
      right: 20,
      top: SafeHeight.topSafeHeight,
    }
  }
}