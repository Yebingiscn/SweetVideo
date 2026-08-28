export interface AnimatedPlaybackTimeBuilderParams {
  playTime: number
  totalTime: number
  fontSize?: number
  fontColor?: ResourceColor
  textOpacity?: number
}

@Builder
export function AnimatedPlaybackTimeBuilder(params: AnimatedPlaybackTimeBuilderParams) {
  Row() {
    if (params.totalTime > 0) {
      if (showHours(params)) {
        Text(Math.floor(currentSeconds(params) / 3600).toString().padStart(2, '0'))
          .fontWeight(FontWeight.Medium)
          .fontSize(params.fontSize ?? 16)
          .fontColor(params.fontColor ?? Color.White)
          .opacity(params.textOpacity ?? 0.9)
          .textShadow({ color: Color.Black, type: ShadowType.BLUR, radius: 4 })
          .contentTransition({ flipDirection: FlipDirection.DOWN, enableBlur: true })
        Text(':')
          .fontWeight(FontWeight.Medium)
          .fontSize(params.fontSize ?? 16)
          .fontColor(params.fontColor ?? Color.White)
          .opacity(params.textOpacity ?? 0.9)
      }
      Text(Math.floor((currentSeconds(params) % 3600) / 60).toString().padStart(2, '0'))
        .fontWeight(FontWeight.Medium)
        .fontSize(params.fontSize ?? 16)
        .fontColor(params.fontColor ?? Color.White)
        .opacity(params.textOpacity ?? 0.9)
        .textShadow({ color: Color.Black, type: ShadowType.BLUR, radius: 4 })
        .contentTransition({ flipDirection: FlipDirection.DOWN, enableBlur: true })
      Text(':')
        .fontWeight(FontWeight.Medium)
        .fontSize(params.fontSize ?? 16)
        .fontColor(params.fontColor ?? Color.White)
        .opacity(params.textOpacity ?? 0.9)
      Text((currentSeconds(params) % 60).toString().padStart(2, '0'))
        .fontWeight(FontWeight.Medium)
        .fontSize(params.fontSize ?? 16)
        .fontColor(params.fontColor ?? Color.White)
        .opacity(params.textOpacity ?? 0.9)
        .textShadow({ color: Color.Black, type: ShadowType.BLUR, radius: 4 })
        .contentTransition({ flipDirection: FlipDirection.DOWN, enableBlur: true })
      Text(' / ')
        .fontWeight(FontWeight.Medium)
        .fontSize(params.fontSize ?? 16)
        .fontColor(params.fontColor ?? Color.White)
        .opacity(params.textOpacity ?? 0.9)
      if (showHours(params)) {
        Text(Math.floor(totalSeconds(params) / 3600).toString().padStart(2, '0'))
          .fontWeight(FontWeight.Medium)
          .fontSize(params.fontSize ?? 16)
          .fontColor(params.fontColor ?? Color.White)
          .opacity(params.textOpacity ?? 0.9)
          .textShadow({ color: Color.Black, type: ShadowType.BLUR, radius: 4 })
          .contentTransition({ flipDirection: FlipDirection.DOWN, enableBlur: true })
        Text(':')
          .fontWeight(FontWeight.Medium)
          .fontSize(params.fontSize ?? 16)
          .fontColor(params.fontColor ?? Color.White)
          .opacity(params.textOpacity ?? 0.9)
      }
      Text(Math.floor((totalSeconds(params) % 3600) / 60).toString().padStart(2, '0'))
        .fontWeight(FontWeight.Medium)
        .fontSize(params.fontSize ?? 16)
        .fontColor(params.fontColor ?? Color.White)
        .opacity(params.textOpacity ?? 0.9)
        .textShadow({ color: Color.Black, type: ShadowType.BLUR, radius: 4 })
        .contentTransition({ flipDirection: FlipDirection.DOWN, enableBlur: true })
      Text(':')
        .fontWeight(FontWeight.Medium)
        .fontSize(params.fontSize ?? 16)
        .fontColor(params.fontColor ?? Color.White)
        .opacity(params.textOpacity ?? 0.9)
      Text((totalSeconds(params) % 60).toString().padStart(2, '0'))
        .fontWeight(FontWeight.Medium)
        .fontSize(params.fontSize ?? 16)
        .fontColor(params.fontColor ?? Color.White)
        .opacity(params.textOpacity ?? 0.9)
        .textShadow({ color: Color.Black, type: ShadowType.BLUR, radius: 4 })
        .contentTransition({ flipDirection: FlipDirection.DOWN, enableBlur: true })
    } else {
      Text('--:-- / --:--')
        .fontWeight(FontWeight.Medium)
        .fontSize(params.fontSize ?? 16)
        .fontColor(params.fontColor ?? Color.White)
        .opacity(params.textOpacity ?? 0.9)
        .textShadow({ color: Color.Black, type: ShadowType.BLUR, radius: 4 })
    }
  }
}

function currentSeconds(params: AnimatedPlaybackTimeBuilderParams): number {
  return Math.floor(Math.min(Math.max(params.playTime, 0), params.totalTime) / 1000)
}

function totalSeconds(params: AnimatedPlaybackTimeBuilderParams): number {
  return Math.floor(Math.max(params.totalTime, 0) / 1000)
}

function showHours(params: AnimatedPlaybackTimeBuilderParams): boolean {
  return params.totalTime >= 3600000
}

@ComponentV2
export struct PlaybackProgressSliderComponent {
  @Param playTime: number = 0
  @Param totalTime: number = 0
  @Event onSliderChange: (_value: number) => void = () => {
  }
  @Event onSliderTouch: (_event: TouchEvent) => void = () => {
  }

  build() {
    Slider({
      value: this.clampedPlayTime(),
      min: 0,
      max: Math.max(this.totalTime, 1),
      style: SliderStyle.NONE
    })
      .trackThickness(12)
      .selectedBorderRadius(16)
      .onChange((value: number) => this.onSliderChange(value))
      .onTouch((event: TouchEvent) => this.onSliderTouch(event))
      .animation({ duration: 100, curve: Curve.Smooth })
      .selectedColor('#e0e0e0')
      .blockColor(Color.White)
      .height(40)
      .width('100%')
      .opacity(0.9)
  }

  private clampedPlayTime(): number {
    return Math.max(0, Math.min(this.playTime, Math.max(this.totalTime, 0)))
  }
}
