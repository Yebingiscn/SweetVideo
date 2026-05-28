import TimeUtil from '../../utils/TimeUtil'

export class ImportProgressBuilderParams {
  processedItems: number = 0
  totalItems: number = 0
  currentFileName: string = '' // 当前处理的文件名
  currentStage: 'extracting' | 'cover' | 'saving' = 'extracting' // 当前处理阶段
  speed: number = 0 // 处理速度（个/秒）
  elapsedTime: number = 0 // 已耗时（毫秒）
  failedCount: number = 0 // 失败文件数
}

@Builder
export function ImportProgressBuilder(params: ImportProgressBuilderParams) {
  Column() {
    // 进度环
    Progress({ value: params.processedItems, total: params.totalItems, type: ProgressType.Ring })
      .width(100)
      .height(100)
      .color(new LinearGradient([{ color: $r('app.color.sweet_music_color'), offset: 0.5 },
        { color: $r('app.color.main_color'), offset: 1.0 }]))
      .style({ strokeWidth: 15, enableSmoothEffect: true, shadow: true })
      .margin({ bottom: 8 })

    // 进度数字
    Text(params.processedItems + '/' + params.totalItems)
      .fontSize(16)
      .fontColor($r('app.color.main_color'))
      .margin({ bottom: 8 })

    // 当前文件名（如果有）
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

    // 处理速度和耗时
    if (params.speed > 0 || params.elapsedTime > 0) {
      Row() {
        if (params.speed > 0) {
          Text(`速度: ${params.speed.toFixed(1)} 个/秒`)
            .fontSize(12)
            .fontColor($r('app.color.text_color'))
        }
        if (params.elapsedTime > 0) {
          Text(`耗时: ${TimeUtil.convertMSToChinese(params.elapsedTime)}`)
            .fontSize(12)
            .fontColor($r('app.color.text_color'))
            .margin({ left: params.speed > 0 ? 8 : 0 })
        }
      }
      .margin({ bottom: 4 })
    }

    // 失败文件数（如果有）
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

// 获取阶段文本
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