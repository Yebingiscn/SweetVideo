import { PlayerControllerFactory, PlayerControllerInterface } from '../../controller/PlayerControllerFactory'
import { XAnimation } from '../../utils/AnimationUtil'
import { SafeHeight } from '../../utils/ObservedUtil'
import { HiCar } from '../../utils/HiCarUtil'
import HiCarLayout from '../../utils/HiCarLayout'

@ComponentV2
export struct VideoLayoutComponent {
  @Consumer('player') player: PlayerControllerInterface =
    PlayerControllerFactory.createAVPlayerController() as PlayerControllerInterface
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
      .height(HiCar.enabled ? 64 : (this.isPortrait() ? 90 : 80))
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
    .padding(HiCar.enabled ? {
      left: HiCar.leftInset, right: HiCar.rightInset, top: HiCar.topInset, bottom: HiCar.bottomInset
    } : 0)
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
    .alignItems(HiCar.enabled ? HorizontalAlign.Start : HorizontalAlign.Center)
  }

  @Builder
  buildBottomBar() {
    Column() {
      Column({ space: HiCar.enabled ? 4 : (this.isLongScreen() ? 15 : 0) }) {
        if (!HiCar.enabled && this.isLongScreen()) {
          this.VideoButtons()
          this.VideoSlider()
        } else {
          this.VideoSlider()
          this.VideoButtons()
        }
      }
      .width(HiCar.enabled ? HiCarLayout.controlWidth(this.player.screenWidth - HiCar.leftInset - HiCar.rightInset) : '100%')
      .alignItems(HiCar.enabled ? HorizontalAlign.Start : HorizontalAlign.Center)
    }
    .width('100%')
    .alignItems(HiCar.enabled ? HorizontalAlign.Start : HorizontalAlign.Center)
    .height(HiCar.enabled ? 'auto' : (this.isPortrait() ? 180 : 'auto'))
    .linearGradient(this.getBottomGradient())
    .padding(HiCar.enabled ? { left: 8, bottom: 4 } :
      { bottom: SafeHeight.bottomSafeHeight == 0 ? 20 : SafeHeight.bottomSafeHeight })
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
      left: HiCar.enabled ? 8 : (this.isPortrait() ? 20 : 35),
      right: HiCar.enabled ? 8 : 20,
      top: HiCar.enabled ? 0 : SafeHeight.topSafeHeight,
    }
  }
}
