import { hiAppEvent } from '@kit.PerformanceAnalysisKit'
import { salmonLogger, SalmonLogLine } from 'salmonlogger'
import { SweetLogDataSource } from '../../utils/DataUtil'
import { SafeHeight, Setting } from '../../utils/ObservedUtil'
import { PathUtils } from '../../utils/PathUtils'
import ToolsUtil from '../../utils/ToolsUtil'
import { systemShare } from '@kit.ShareKit'
import { uniformTypeDescriptor } from '@kit.ArkData'
import { fileIo, fileUri } from '@kit.CoreFileKit'

const TAG = 'CrashPage'

@ComponentV2
export struct CrashPage {
  @Local sweetLogDataSource: SweetLogDataSource = new SweetLogDataSource([])
  @Consumer('pathStack') pathStack: NavPathStack = new NavPathStack()
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
      Column() {
        if (this.appEventGroups.length === 0) {
          // 简洁日志组件
          Column() {
            // Mac 风格标题栏 - 扁平化为一行
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
            .width('100%')
            .padding(12)

            // 日志列表
            List({ scroller: this.listScroller, space: 10 }) {
              LazyForEach(this.sweetLogDataSource, (log: SalmonLogLine) => {
                ListItem() {
                  Column() {
                    Row() {
                      // 日志类型徽章 - 简化 Stack 为 Text
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
                  }
                  .width('100%')
                  .padding({
                    top: 6,
                    bottom: 6,
                    left: 12,
                    right: 12
                  })
                }
              }, (_log: SalmonLogLine, index: number) => index.toString())
            }
            .cachedCount(8)
            .onAppear(() => {
              setTimeout(() => {
                const targetIndex = salmonLogger.logs.length - 1
                if (targetIndex >= 0) {
                  this.listScroller.scrollToIndex(targetIndex, false)
                }
              }, 50)
            })
            .layoutWeight(1)
            .height('100%')
            .width('100%')
            .padding({ left: 8, right: 8, bottom: 8 })
            .scrollBar(BarState.Auto)
          }
          .width('100%')
          .layoutWeight(1)
          .backgroundColor($r('app.color.start_window_background_blur'))
          .borderRadius(16)
        } else {
          // 崩溃日志
          List() {
            ForEach(this.appEventGroups, (eventGroup: hiAppEvent.AppEventGroup) => {
              ListItem() {
                Column() {
                  Text('事件名：' + eventGroup.name)
                    .fontColor($r('app.color.text_color'))
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                    .margin({ bottom: 8 })

                  ForEach(eventGroup.appEventInfos, (eventInfo: hiAppEvent.AppEventInfo) => {
                    Column() {
                      this.EventInfoText('domain', eventInfo.domain)
                      this.EventInfoText('name', eventInfo.name)
                      this.EventInfoText('eventType', eventInfo.eventType)
                      this.EventInfoText('time', eventInfo.params['time'])
                      this.EventInfoText('crash_type', eventInfo.params['crash_type'])
                      this.EventInfoText('foreground', eventInfo.params['foreground'])
                      this.EventInfoText('bundle_version', eventInfo.params['bundle_version'])
                      this.EventInfoText('bundle_name', eventInfo.params['bundle_name'])
                      this.EventInfoText('pid', eventInfo.params['pid'])
                      this.EventInfoText('uid', eventInfo.params['uid'])
                      this.EventInfoText('uuid', eventInfo.params['uuid'])
                      this.EventInfoText('exception', JSON.stringify(eventInfo.params['exception']))
                      this.EventInfoText('hilog.size', eventInfo.params['hilog']?.length)
                      this.EventInfoText('external_log', JSON.stringify(eventInfo.params['external_log']))
                      this.EventInfoText('log_over_limit', eventInfo.params['log_over_limit'])
                      this.EventInfoText('test_data', eventInfo.params['test_data'])
                    }
                    .width('100%')
                    .padding(8)
                    .margin({ top: 8 })
                  }, (_eventInfo: hiAppEvent.AppEventInfo, index: number) => index.toString())
                }
                .width('100%')
                .padding(12)
              }
            }, (eventGroup: hiAppEvent.AppEventGroup, index: number) => eventGroup.name + index)
          }
          .height('100%')
          .width('100%')
          .layoutWeight(1)
          .backgroundColor($r('app.color.start_window_background_blur'))
          .borderRadius(16)
          .padding({ left: 8, right: 8 })
          .scrollBar(BarState.Auto)
        }

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
          .margin({ top: 10, bottom: 15 })
      }
      .width('100%')
      .height('100%')
      .padding({ left: 16, right: 16 })
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

  @Builder
  EventInfoText(label: string, value: string | number) {
    Row() {
      Text(`${label}:`)
        .fontSize(11)
        .fontColor($r('app.color.text_color'))
        .opacity(0.6)
        .width(100)
      Text(`${value}`)
        .fontSize(11)
        .fontColor($r('app.color.text_color'))
        .layoutWeight(1)
        .wordBreak(WordBreak.BREAK_ALL)
    }
    .width('100%')
    .margin({ top: 4 })
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
      const file =
        fileIo.openSync(filePath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC)
      fileIo.writeSync(file.fd, fullText)
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
      fileIo.closeSync(file)
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
