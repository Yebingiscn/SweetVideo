import SelectFileUtil from '../../utils/SelectFileUtil'
import VideoInfoUtil from '../../utils/VideoInfoUtil'

class FastForwardInfo {
  speed: number = 1
  location: number = 0
}

@Builder
export function FastForwardPanelBuilder(fastForwardInfo: FastForwardInfo) {
  Stack({ alignContent: Alignment.BottomEnd }) {
    Column() {
      Text(VideoInfoUtil.optimizedFormat(fastForwardInfo.speed) + ' ⏩')
        .fontColor($r('app.color.main_color')).fontSize(15)
        .fontWeight(FontWeight.Bold)
      Row() {
        if (SelectFileUtil.getPrevAndNextItem(VideoInfoUtil.optimizedFormat(fastForwardInfo.speed),
          VideoInfoUtil.getVideoSpeedTextList())[0] !== '') {
          Text(`← ${SelectFileUtil.getPrevAndNextItem(VideoInfoUtil.optimizedFormat(fastForwardInfo.speed),
            VideoInfoUtil.getVideoSpeedTextList())[0]}`)
            .fontColor($r('sys.color.white')).margin({ right: 10 }).fontSize(10)
        }
        if (SelectFileUtil.getPrevAndNextItem(VideoInfoUtil.optimizedFormat(fastForwardInfo.speed),
          VideoInfoUtil.getVideoSpeedTextList())[1] !== '') {
          Text(`${SelectFileUtil.getPrevAndNextItem(VideoInfoUtil.optimizedFormat(fastForwardInfo.speed),
            VideoInfoUtil.getVideoSpeedTextList())[1]} →`)
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
    y: (fastForwardInfo.location === -160 || fastForwardInfo.location === -80) ?
      fastForwardInfo.location :
      (fastForwardInfo.location !== VideoInfoUtil.playAreaHeight && VideoInfoUtil.playAreaHeight !== 0 ?
        0 - VideoInfoUtil.playAreaHeight / 2 + 20 :
        0 - fastForwardInfo.location / 2 + 20)
  })
  .borderRadius(16) // 胶囊形状背景
  .backgroundColor('#30000000') // 半透明黑色背景
  .backdropBlur(100) // 背景模糊效果
  .animation({ duration: 300, curve: Curve.Smooth })
}