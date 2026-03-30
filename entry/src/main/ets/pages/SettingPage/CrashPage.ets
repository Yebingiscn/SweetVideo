import { hiAppEvent } from '@kit.PerformanceAnalysisKit'
import { salmonLogger, SalmonLogLine } from 'salmonlogger'
import { SafeHeight, Setting } from '../../utils/ObservedUtil'
import { PathUtils } from '../../utils/PathUtils'
import ToolsUtil from '../../utils/ToolsUtil'
import { pasteboard } from '@kit.BasicServicesKit'

@Component
export struct CrashPage {
  @Consume('pathStack') pathStack: NavPathStack
  private appEventGroups: Array<hiAppEvent.AppEventGroup> | [] = []

  aboutToAppear(): void {
    const crashLog = AppStorage.get('crashLog') as Array<hiAppEvent.AppEventGroup>
    if (crashLog) {
      this.appEventGroups = crashLog
    }
  }

  aboutToDisappear(): void {
    AppStorage.setOrCreate('crashLog', [])
  }

  build() {
    NavDestination() {
      Scroll() {
        if (this.appEventGroups.length === 0) {
          // 简洁日志组件，支持自动换行
          Column() {
            // Mac 风格标题栏
            Row() {
              // 红黄绿三个圆形按钮
              Row({ space: 8 }) {
                Circle()
                  .width(16)
                  .height(16)
                  .fill('#ff5f56')
                  .onClick(() => salmonLogger.clearLog())
                Circle()
                  .width(16)
                  .height(16)
                  .fill('#ffbd2e')
                Circle()
                  .width(16)
                  .height(16)
                  .fill('#27c93f')
                  .onClick(() => salmonLogger.exportLog('sweet_video', PathUtils.appContext!))
              }
            }
            .width('100%')
            .padding(12)

            // 日志列表，支持自动换行
            List() {
              ForEach(salmonLogger.logs, (log: SalmonLogLine) => {
                ListItem() {
                  Column() {
                    Row() {
                      // 日志类型徽章
                      Text(log.isError ? 'ERROR' : 'INFO')
                        .fontSize(9)
                        .fontColor(log.isError ? '#ff4d4f' : '#52c41a')
                        .fontWeight(FontWeight.Bold)
                        .padding({
                          left: 6,
                          right: 6,
                          top: 2,
                          bottom: 2
                        })
                        .backgroundColor(log.isError ? '#ff4d4f' : '#52c41a')
                        .opacity(0.15)
                        .borderRadius(4)

                      Text(`[${new Date(log.time).toLocaleTimeString(undefined, { hour12: false })}]`)
                        .fontSize(10)
                        .fontColor(log.isError ? '#ff4d4f' : $r('app.color.text_color'))
                        .opacity(0.7)
                        .margin({ left: 8 })

                      Text(log.tag)
                        .fontSize(10)
                        .fontColor(log.isError ? '#ff4d4f' : $r('app.color.text_color'))
                        .opacity(0.6)
                        .layoutWeight(1)
                        .margin({ left: 8 })
                    }
                    .width('100%')

                    Text(log.text)
                      .fontSize(12)
                      .fontColor(log.isError ? '#ff4d4f' : $r('app.color.text_color'))
                      .width('100%')
                      .wordBreak(WordBreak.BREAK_ALL)
                      .margin({ top: 6 })
                  }
                  .width('100%')
                  .padding({ top: 8, bottom: 8 })
                  .borderRadius(16)
                }
              }, (_log: SalmonLogLine, index: number) => index.toString())
            }
            .height('100%')
            .width('100%')
            .layoutWeight(1)
            .padding({ left: 12, right: 12, bottom: 12 })
            .scrollBar(BarState.Auto)
          }
          .width('100%')
          .height('100%')
          .backgroundColor($r('app.color.start_window_background_blur'))
          .borderRadius(16)
        } else {
          Column() {
            Text('流心崩溃日志').margin(10)
            ForEach(this.appEventGroups, (eventGroup: hiAppEvent.AppEventGroup) => {
              Text('事件名：' + eventGroup.name)
              ForEach(eventGroup.appEventInfos, (eventInfo: hiAppEvent.AppEventInfo) => {
                Text(`HiAppEvent eventInfo.domain=${eventInfo.domain}\n` +
                  `HiAppEvent eventInfo.name=${eventInfo.name}\n` +
                  `HiAppEvent eventInfo.eventType=${eventInfo.eventType}\n` +
                  `HiAppEvent eventInfo.params.time=${eventInfo.params['time']}\n` +
                  `HiAppEvent eventInfo.params.crash_type=${eventInfo.params['crash_type']}\n` +
                  `HiAppEvent eventInfo.params.foreground=${eventInfo.params['foreground']}\n` +
                  `HiAppEvent eventInfo.params.bundle_version=${eventInfo.params['bundle_version']}\n` +
                  `HiAppEvent eventInfo.params.bundle_name=${eventInfo.params['bundle_name']}\n` +
                  `HiAppEvent eventInfo.params.pid=${eventInfo.params['pid']}\n` +
                  `HiAppEvent eventInfo.params.uid=${eventInfo.params['uid']}\n` +
                  `HiAppEvent eventInfo.params.uuid=${eventInfo.params['uuid']}\n` +
                  `HiAppEvent eventInfo.params.exception=${JSON.stringify(eventInfo.params['exception'])}\n` +
                  `HiAppEvent eventInfo.params.hilog.size=${eventInfo.params['hilog']?.length}\n` +
                  `HiAppEvent eventInfo.params.external_log=${JSON.stringify(eventInfo.params['external_log'])}\n` +
                  `HiAppEvent eventInfo.params.log_over_limit=${eventInfo.params['log_over_limit']}\n` +
                  `HiAppEvent eventInfo.params.test_data=${eventInfo.params['test_data']}`).width('80%').height('auto')
              }, (_eventInfo: hiAppEvent.AppEventInfo, index: number) => index.toString())
            }, (eventGroup: hiAppEvent.AppEventGroup, index: number) => eventGroup.name + index)
          }.backgroundColor($r('app.color.start_window_background_blur'))
          .height('100%')
          .width('100%')
          .borderRadius(16)
        }
      }
      .margin({ left: 16, right: 16, bottom: 16 })
      .layoutWeight(1)
      .align(Alignment.Top)
      .height('100%')
      .width('100%')
      .borderRadius(16)
      .clip(true)
      .scrollBar(BarState.Off)
      .scrollable(ScrollDirection.Vertical) // 启用垂直滚动
      .edgeEffect(EdgeEffect.Spring) // 滚动边缘效果

      Button('复制给开发者')
        .onClick(() => {
          this.appEventGroups.toString().length > 0 ? this.copyText(JSON.stringify(this.appEventGroups)) :
            this.copyText(JSON.stringify(salmonLogger.logs))
        })
        .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
        .fontColor($r('sys.color.white'))
        .fontSize(17)
        .linearGradient({
          direction: GradientDirection.Right,
          colors: [[$r('app.color.main_color'), 0.0], ['#ff48cdf6', 1.0]]
        })
        .width('40%')
        .borderRadius(24)
        .margin({ bottom: 15 })
    }
    .hideToolBar(true)
    .title('流心运行日志')
    .backgroundColor($r('app.color.start_window_background'))
    .padding({ top: SafeHeight.topSafeHeight, bottom: SafeHeight.bottomSafeHeight })
    .backgroundImage(Setting.backgroundImageSrc, ImageRepeat.NoRepeat)
    .backgroundImageSize(ImageSize.Cover)
    .backdropBlur(Setting.backgroundDropBlur)
    .backgroundImagePosition(Alignment.Center)
  }

  copyText(text: string) {
    const infoText = '反馈 QQ群 973792610，作者邮箱 1309932526@qq.com'
    // Create clipboard content object
    const pasteboardData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, infoText + '\n' + text)
    // Get system clipboard object
    const systemPasteboard = pasteboard.getSystemPasteboard()
    systemPasteboard.setData(pasteboardData).then(() => {
      ToolsUtil.showToast('日志复制成功' + infoText)
      salmonLogger.addLog(this.pathStack.getAllPathName()[0], '复制日志成功', false)
    })?.catch(() => {
      this.pathStack.getAllPathName()[0]
      salmonLogger.addLog(this.pathStack.getAllPathName()[0], '复制失败', true)
      ToolsUtil.showToast('复制失败')
    }) // Put data into clipboard
  }
}