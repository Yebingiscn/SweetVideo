class SubtitleDisplayValue {
  subtitle: string = ''
  screenWidth: number = 0
  screenHeight: number = 0
  showControl: boolean = false
  subTitleVisibility: Visibility = Visibility.None
  playAreaWidth: number = 0
}

@Builder
export function SubtitleDisplayBuilder(subtitleDisplayValue: SubtitleDisplayValue) {
  Stack({ alignContent: Alignment.BottomEnd }) { //字幕
    Text(subtitleDisplayValue.subtitle)
      .fontColor('#F0F0F0')
      .fontSize(AppStorage.get('subtitleSize') as string)
      .fontWeight(FontWeight.Medium)
      .textAlign(TextAlign.Center)
      .fontWeight(FontWeight.Normal)// 常规字重更清晰
      .textShadow({ color: Color.Black, type: ShadowType.BLUR, radius: 6 })
      .opacity(0.95) // 轻微透明度
  }
  .visibility(subtitleDisplayValue.subTitleVisibility)
  .align(Alignment.Center)
  .width(subtitleDisplayValue.playAreaWidth)
  .offset({ x: 0, y: subtitleDisplayValue.screenHeight / 2 - 40 })
  .animation({ duration: 300, curve: Curve.Smooth })
}