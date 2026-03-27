import VideoInfoUtil from '../../utils/VideoInfoUtil'
import { SpeedNeighborInterface } from '../../interfaces/SpeedNeighborInterface'

class FastForwardInfo {
  speed: number = 1
  location: number = 0
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
  Row({ space: 12 }) {
    // 左侧：上一个倍速（最小倍速时隐藏）
    if (fastForwardInfo.speed > VideoInfoUtil.videoSpeedListAll[0]) {
      Text(`${getNeighborSpeeds(fastForwardInfo.speed).prev?.toFixed(2).replace(/\.?0+$/, '')}x`)
        .fontColor('#60FFFFFF')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
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
      Text(`${fastForwardInfo.speed.toFixed(2).replace(/\.?0+$/, '')}`)
        .fontColor($r('sys.color.white'))
        .fontSize(20)
        .fontWeight(FontWeight.Bold)

      Text('x')
        .fontColor($r('sys.color.white'))
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .margin({ bottom: 4 })
    }
    .alignItems(VerticalAlign.Bottom)
    .padding({
      left: 12,
      right: 12,
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
      Text(`${getNeighborSpeeds(fastForwardInfo.speed).next?.toFixed(2).replace(/\.?0+$/, '')}x`)
        .fontColor('#60FFFFFF')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .width(40)
        .height(36)
    } else {
      Text('')
        .width(40)
        .height(36)
    }
  }
  .alignItems(VerticalAlign.Center)
  .padding({
    left: 16,
    right: 16,
    top: 12,
    bottom: 12
  })
  .borderRadius(16)
  .backgroundColor('#30000000')
  .backdropBlur(100)
  .offset({
    x: 0,
    y: -fastForwardInfo.location / 2.5
  })
  .animation({ duration: 200, curve: Curve.EaseInOut })
}