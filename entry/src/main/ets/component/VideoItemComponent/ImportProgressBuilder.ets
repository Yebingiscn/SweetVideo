export class ImportProgressBuilderParams {
  processedItems: number = 0
  totalItems: number = 0
}

@Builder
export function ImportProgressBuilder(params: ImportProgressBuilderParams) {
  Stack() {
    Column() {
      Progress({ value: params.processedItems, total: params.totalItems, type: ProgressType.Ring })
        .width(100)
        .height(100)
        .color(new LinearGradient([{ color: $r('app.color.sweet_music_color'), offset: 0.5 },
          { color: $r('app.color.main_color'), offset: 1.0 }]))
        .style({ strokeWidth: 15, enableSmoothEffect: true, shadow: true })
        .margin({ bottom: 8 }) // 添加底部间距分隔文字
      Text(params.processedItems + '/' + params.totalItems)
        .fontSize(16)
        .fontColor($r('app.color.main_color'))
    }
    .animation({ duration: 150, curve: Curve.Sharp })
    .padding(30)
    .borderRadius(16)
    .shadow({ radius: 26, color: $r('app.color.shadow_color') })
    .backgroundColor($r('app.color.start_window_background_blur'))
    .backdropBlur(150)
  }.width('100%')
  .height('100%')
}