import VideoInfoUtil from '../../utils/VideoInfoUtil'
import { SpeedNeighborInterface } from '../../interfaces/SpeedNeighborInterface'
import { LightMaterialModifier, SymbolGlyphFancyModifier } from '../../common/AttributeModifierConfig'

class FastForwardInfo {
  speed: number = 1
  location: number = 0
  speedLocked: boolean = false
}

// 获取相邻倍速信息
function getNeighborSpeeds(currentSpeed: number): SpeedNeighborInterface {
  const speeds = VideoInfoUtil.videoSpeedListAll
  const currentIndex = speeds.findIndex((s: number) => Math.abs(s - currentSpeed) < 0.01)
  return {
    prev: currentIndex > 0 ? speeds[currentIndex - 1] : null,
    current: currentSpeed,
    next: currentIndex >= 0 && currentIndex < speeds.length - 1 ? speeds[currentIndex + 1] : null
  }
}

@Builder
export function FastForwardPanelBuilder(fastForwardInfo: FastForwardInfo) {
  Column() {
    FastForwardSpeedRow(fastForwardInfo)
  }
  .padding({
    left: 6,
    right: 6,
    top: 6,
    bottom: 6
  })
  .borderRadius(16)
  .attributeModifier(new LightMaterialModifier())
  .offset({
    x: 0,
    y: -fastForwardInfo.location / 2.5
  })
  .zIndex(101)
  .hitTestBehavior(HitTestMode.None)
  .animation({ duration: 300, curve: Curve.Friction })
}

@Builder
function FastForwardSpeedRow(fastForwardInfo: FastForwardInfo) {
  Row({ space: 4 }) {
    // 左侧：上一个倍速（最小倍速时隐藏）
    if (fastForwardInfo.speed > VideoInfoUtil.videoSpeedListAll[0]) {
      Text(`${VideoInfoUtil.optimizedFormat(getNeighborSpeeds(fastForwardInfo.speed).prev!).replace('x', '')}x`)
        .fontColor('#60FFFFFF')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .textAlign(TextAlign.Center)
        .width(40)
        .height(36)
    } else {
      // 占位保持布局稳定
      Text('')
        .width(40)
        .height(36)
    }

    // 中间：当前倍速（带边框高亮）
    Row({ space: 2 }) {
      Text(`${VideoInfoUtil.optimizedFormat(fastForwardInfo.speed).replace('x', '')}`)
        .fontColor($r('app.color.main_color'))
        .fontSize(20)
        .fontWeight(FontWeight.Bold)

      Text('x')
        .fontColor($r('app.color.main_color'))
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .margin({ bottom: 4 })

      if (fastForwardInfo.speedLocked) {
        SymbolGlyph($r('sys.symbol.lock_fill'))
          .attributeModifier(new SymbolGlyphFancyModifier(12, '', ''))
          .fontColor([$r('app.color.main_color')])
          .margin({ left: 2, bottom: 4 })
      }
    }
    .alignItems(VerticalAlign.Bottom)
    .padding({
      left: 4,
      right: 4,
      top: 4,
      bottom: 4
    })
    .height(36)
    .borderWidth(1.5)
    .borderColor($r('app.color.main_color'))
    .borderRadius(6)
    .backgroundColor('#20FFFFFF')

    // 右侧：下一个倍速（最大倍速时隐藏）
    if (fastForwardInfo.speed < VideoInfoUtil.videoSpeedListAll[VideoInfoUtil.videoSpeedListAll.length - 1]) {
      Text(`${VideoInfoUtil.optimizedFormat(getNeighborSpeeds(fastForwardInfo.speed).next!).replace('x', '')}x`)
        .fontColor('#60FFFFFF')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .textAlign(TextAlign.Center)
        .width(40)
        .height(36)
    } else {
      Text('')
        .width(40)
        .height(36)
    }
  }
  .alignItems(VerticalAlign.Center)
}
