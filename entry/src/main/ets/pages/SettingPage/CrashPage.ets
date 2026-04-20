import { hiAppEvent } from '@kit.PerformanceAnalysisKit'
import { salmonLogger, SalmonLogLine } from 'salmonlogger'
import { SafeHeight, Setting } from '../../utils/ObservedUtil'
import { PathUtils } from '../../utils/PathUtils'
import ToolsUtil from '../../utils/ToolsUtil'
import { fileIo as fs } from '@kit.CoreFileKit'
import { systemShare } from '@kit.ShareKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { uniformTypeDescriptor } from '@kit.ArkData'
import { fileUri } from '@kit.CoreFileKit';
import { SweetLogDataSource } from '../../utils/DataUtil'

const TAG = 'CrashPage'

@Component
export struct CrashPage {
  @State sweetLogDataSource: SweetLogDataSource = new SweetLogDataSource([])
  @Consume('pathStack') pathStack: NavPathStack
  private appEventGroups: Array<hiAppEvent.AppEventGroup> | [] = []
  private listScroller: Scroller = new Scroller()

  aboutToAppear(): void {
    const crashLog = AppStorage.get('crashLog') as Array<hiAppEvent.AppEventGroup>
    if (crashLog) {
      this.appEventGroups = crashLog
    }
    this.sweetLogDataSource = new SweetLogDataSource(salmonLogger.logs)
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
                  .onClick(() => {
                    salmonLogger.clearLog()
                    this.sweetLogDataSource.updateData(salmonLogger.logs)
                  })
                Circle()
                  .width(16)
                  .height(16)
                  .fill('#ffbd2e')
                  .onClick(() => ToolsUtil.showToast("红色按钮清空日志，绿色按钮导出日志"))
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
            List({ scroller: this.listScroller, space: 10 }) {
              LazyForEach(this.sweetLogDataSource, (log: SalmonLogLine) => {
                ListItem() {
                  Column() {
                    Row() {
                      // 日志类型徽章
                      Stack() {
                        Text(log.isError ? 'ERROR' : 'INFO')
                          .fontSize(9)
                          .fontColor($r('sys.color.white'))
                          .fontWeight(FontWeight.Bold)
                          .padding({
                            left: 6,
                            right: 6,
                            top: 2,
                            bottom: 2
                          })
                      }
                      .backgroundColor(log.isError ? '#26ff4d4f' : '#2652c41a')
                      .backdropBlur(12)
                      .borderRadius(4)

                      Text(`[${new Date(log.time).toLocaleTimeString(undefined, { hour12: false })}]`)
                        .fontSize(10)
                        .fontColor($r('app.color.text_color'))
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
                      .align(Alignment.Start)
                  }.margin({ right: 24 })
                }.width('100%')
                .padding({ top: 6, bottom: 6, right: 12 })
                .borderRadius(16)
              }, (_log: SalmonLogLine, index: number) => index.toString())
            }
            .onAppear(() => {
              setTimeout(() => {
                const targetIndex = salmonLogger.logs.length - 1
                if (targetIndex >= 0) {
                  this.listScroller.scrollToIndex(targetIndex, false)
                }
              }, 50)
            })
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
            Text('流心崩溃日志')
              .fontColor($r('app.color.text_color'))
              .margin(10)
            ForEach(this.appEventGroups, (eventGroup: hiAppEvent.AppEventGroup) => {
              Text('事件名：' + eventGroup.name)
                .fontColor($r('app.color.text_color'))
              ForEach(eventGroup.appEventInfos, (eventInfo: hiAppEvent.AppEventInfo) => {
                Column() {
                  Text(`HiAppEvent eventInfo.domain=${eventInfo.domain}`).fontColor($r('app.color.text_color'))
                  Text(`HiAppEvent eventInfo.name=${eventInfo.name}`).fontColor($r('app.color.text_color'))
                  Text(`HiAppEvent eventInfo.eventType=${eventInfo.eventType}`).fontColor($r('app.color.text_color'))
                  Text(`HiAppEvent eventInfo.params.time=${eventInfo.params['time']}`)
                    .fontColor($r('app.color.text_color'))
                  Text(`HiAppEvent eventInfo.params.crash_type=${eventInfo.params['crash_type']}`)
                    .fontColor($r('app.color.text_color'))
                  Text(`HiAppEvent eventInfo.params.foreground=${eventInfo.params['foreground']}`)
                    .fontColor($r('app.color.text_color'))
                  Text(`HiAppEvent eventInfo.params.bundle_version=${eventInfo.params['bundle_version']}`)
                    .fontColor($r('app.color.text_color'))
                  Text(`HiAppEvent eventInfo.params.bundle_name=${eventInfo.params['bundle_name']}`)
                    .fontColor($r('app.color.text_color'))
                  Text(`HiAppEvent eventInfo.params.pid=${eventInfo.params['pid']}`)
                    .fontColor($r('app.color.text_color'))
                  Text(`HiAppEvent eventInfo.params.uid=${eventInfo.params['uid']}`)
                    .fontColor($r('app.color.text_color'))
                  Text(`HiAppEvent eventInfo.params.uuid=${eventInfo.params['uuid']}`)
                    .fontColor($r('app.color.text_color'))
                  Text(`HiAppEvent eventInfo.params.exception=${JSON.stringify(eventInfo.params['exception'])}`)
                    .fontColor($r('app.color.text_color'))
                  Text(`HiAppEvent eventInfo.params.hilog.size=${eventInfo.params['hilog']?.length}`)
                    .fontColor($r('app.color.text_color'))
                  Text(`HiAppEvent eventInfo.params.external_log=${JSON.stringify(eventInfo.params['external_log'])}`)
                    .fontColor($r('app.color.text_color'))
                  Text(`HiAppEvent eventInfo.params.log_over_limit=${eventInfo.params['log_over_limit']}`)
                    .fontColor($r('app.color.text_color'))
                  Text(`HiAppEvent eventInfo.params.external_log=${JSON.stringify(eventInfo.params['external_log'])}`)
                  Text(`HiAppEvent eventInfo.params.external_log=${JSON.stringify(eventInfo.params['external_log'])}`)
                    .fontColor($r('app.color.text_color'))
                  Text(`HiAppEvent eventInfo.params.log_over_limit=${eventInfo.params['log_over_limit']}`)
                    .fontColor($r('app.color.text_color'))
                  Text(`HiAppEvent eventInfo.params.test_data=${eventInfo.params['test_data']}`)
                    .fontColor($r('app.color.text_color'))
                  Text(`HiAppEvent eventInfo.params.test_data=${eventInfo.params['test_data']}`)
                    .fontColor($r('app.color.text_color'))
                }.width('80%')
              }, (_eventInfo: hiAppEvent.AppEventInfo, index: number) => index.toString())
            }, (eventGroup: hiAppEvent.AppEventGroup, index: number) => eventGroup.name + index)
          }
          .backgroundColor($r('app.color.start_window_background_blur'))
          .height('100%')
          .width('100%')
          .borderRadius(16)
          .padding({ left: 12, right: 12 })
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

      Button('分享给开发者')
        .onClick(async () => {
          this.appEventGroups.toString().length > 0 ? await this.shareText(JSON.stringify(this.appEventGroups)) :
            await this.shareText(JSON.stringify(salmonLogger.logs))
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

  async shareText(text: string) {
    const infoText = '反馈 QQ群 973792610'
    const fullText = infoText + '\n' + text
    try {
      // 获取临时目录
      const context = PathUtils.appContext
      const tempDir = PathUtils.tempPath
      // 创建临时文件路径
      const timestamp = new Date().getTime()
      const fileName = `crash_log_${timestamp}.txt`
      const filePath = `${tempDir}/${fileName}`
      salmonLogger.addLog(this.pathStack.getAllPathName()[0], '开始写入日志文件: ' + filePath, false)
      // 写入临时文件
      const file = fs.openSync(filePath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC)
      fs.writeSync(file.fd, fullText)
      const filePathString = file.path
      salmonLogger.addLog(this.pathStack.getAllPathName()[0], '文件写入完成: ' + filePathString, false)
      let shareData = new systemShare.SharedData({
        utd: uniformTypeDescriptor.UniformDataType.PLAIN_TEXT,
        uri: fileUri.getUriFromPath(filePath),
        title: fileName,
        description: '流心播放器日志'
      })
      // 调用系统分享接口
      let controller1 = new systemShare.ShareController(shareData)
      await controller1.show(context, {
        previewMode: systemShare.SharePreviewMode.DETAIL, // 详细预览模式
        selectionMode: systemShare.SelectionMode.SINGLE   // 单选模式
      })
      fs.closeSync(file)
      salmonLogger.addLog(this.pathStack.getAllPathName()[0], '日志分享成功', false)
      ToolsUtil.showToast('日志分享成功')

    } catch (error) {
      const err = error as BusinessError
      const errorMsg = `分享失败: code=${err.code}, message=${err.message}`
      salmonLogger.addLog(this.pathStack.getAllPathName()[0], errorMsg, true)
      salmonLogger.addLog(TAG, errorMsg, true)
      ToolsUtil.showToast('分享失败: ' + err.message)
    }
  }
}
