@ObservedV2
export class ImportProgressBuilderParams {
  @Trace processedItems: number = 0
  @Trace totalItems: number = 0
  @Trace currentFileName: string = ''
  @Trace currentStage: 'extracting' | 'cover' | 'saving' = 'extracting'
  @Trace failedCount: number = 0
}


@Builder
export function ImportProgressBuilder(params: ImportProgressBuilderParams) {
  Column() {
    Progress({ value: params.processedItems, total: params.totalItems, type: ProgressType.Ring })
      .width(100)
      .height(100)
      .color(new LinearGradient([{ color: $r('app.color.sweet_music_color'), offset: 0.5 },
        { color: $r('app.color.main_color'), offset: 1.0 }]))
      .style({ strokeWidth: 15, enableSmoothEffect: true, shadow: true })
      .margin({ bottom: 8 })

    Row() {
      Text(params.processedItems.toString())
        .fontSize(16)
        .fontColor($r('app.color.main_color'))
        .contentTransition({ flipDirection: FlipDirection.DOWN, enableBlur: true })
      Text('/')
        .fontSize(16)
        .fontColor($r('app.color.main_color'))
      Text(params.totalItems.toString())
        .fontSize(16)
        .fontColor($r('app.color.main_color'))
        .contentTransition({ flipDirection: FlipDirection.DOWN, enableBlur: true })
    }
    .margin({ bottom: 8 })

    if (params.currentFileName) {
      Text(getStageText(params.currentStage) + params.currentFileName)
        .fontSize(12)
        .fontColor($r('app.color.text_color'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('80%')
        .textAlign(TextAlign.Center)
        .margin({ bottom: 4 })
    }

    if (params.failedCount > 0) {
      Text(`失败: ${params.failedCount} 个`)
        .fontSize(12)
        .fontColor($r('app.color.text_color'))
    }
  }
  .animation({ duration: 150, curve: Curve.Sharp })
  .padding(30)
  .borderRadius(16)
  .shadow({ radius: 26, color: $r('app.color.shadow_color') })
  .backgroundColor($r('app.color.start_window_background_blur'))
  .backdropBlur(150)
}

function getStageText(stage: 'extracting' | 'cover' | 'saving'): string {
  switch (stage) {
    case 'extracting':
      return '正在提取: '
    case 'cover':
      return '正在生成封面: '
    case 'saving':
      return '正在保存: '
    default:
      return '正在处理: '
  }
}