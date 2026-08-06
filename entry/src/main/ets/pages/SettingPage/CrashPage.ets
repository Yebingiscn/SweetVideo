import { hiAppEvent } from '@kit.PerformanceAnalysisKit'
import { salmonLogger, SalmonLogLine } from 'salmonlogger'
import { SweetLogDataSource } from '../../utils/DataUtil'
import { SafeHeight, Setting } from '../../utils/ObservedUtil'
import { PathUtils } from '../../utils/PathUtils'
import ToolsUtil from '../../utils/ToolsUtil'
import { systemShare } from '@kit.ShareKit'
import { uniformTypeDescriptor } from '@kit.ArkData'
import { fileIo } from '@kit.CoreFileKit'
import { HdsNavDestination, ScrollEffectType } from '@kit.UIDesignKit'
import {
  CapsuleSegmentButtonV2,
  ColorMetrics,
  LengthMetrics,
  SegmentButtonV2ItemOptions,
  SegmentButtonV2Items
} from '@kit.ArkUI'
import { deviceInfo } from '@kit.BasicServicesKit'

const TAG = 'CrashPage'

@ComponentV2
export struct CrashPage {
  @Local sweetLogDataSource: SweetLogDataSource = new SweetLogDataSource([])
  @Local currentTabIndex: number = 0
  @Local segmentItems: SegmentButtonV2Items = new SegmentButtonV2Items([])
  @Local itemSelectedBackgroundColor: ColorMetrics | undefined = undefined
  @Local itemSelectedFontColor: ColorMetrics | undefined = undefined
  @Consumer('pathStack') pathStack: NavPathStack = new NavPathStack()
  private appEventGroups: Array<hiAppEvent.AppEventGroup> | [] = []
  private listScroller: Scroller = new Scroller()

  aboutToAppear(): void {
    const crashLog = AppStorage.get('crashLog') as Array<hiAppEvent.AppEventGroup>
    if (crashLog) {
      this.appEventGroups = crashLog
      this.currentTabIndex = 1
    }
    this.sweetLogDataSource = new SweetLogDataSource(salmonLogger.logs)
    this.initSegmentItems()
    this.getColor()
  }

  aboutToDisappear(): void {
    AppStorage.setOrCreate('crashLog', [])
  }

  build() {
    HdsNavDestination() {
      Column() {
        CapsuleSegmentButtonV2({
          items: this.segmentItems,
          selectedIndex: this.currentTabIndex,
          buttonBackgroundBlurStyle: BlurStyle.BACKGROUND_THICK,
          itemSelectedFontColor: this.itemSelectedFontColor,
          itemSelectedBackgroundColor: this.itemSelectedBackgroundColor,
          onItemClicked: (index: number) => {
            this.currentTabIndex = index
          }
        })
          .margin({ top: 8, bottom: 8 })

        Swiper() {
          Column() {
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

            List({ scroller: this.listScroller, space: 10 }) {
              Repeat<SalmonLogLine>(this.sweetLogDataSource.data)
                .each((repeatItem: RepeatItem<SalmonLogLine>) => {
                  ListItem() {
                    Column() {
                      Row() {
                        Text(repeatItem.item.isError ? 'ERROR' : 'INFO')
                          .fontSize(9)
                          .fontColor($r('sys.color.white'))
                          .fontWeight(FontWeight.Bold)
                          .padding({
                            left: 6,
                            right: 6,
                            top: 2,
                            bottom: 2
                          })
                          .backgroundColor(repeatItem.item.isError ? '#26ff4d4f' : '#2652c41a')
                          .backdropBlur(12)
                          .borderRadius(4)

                        Text(`[${new Date(repeatItem.item.time).toLocaleTimeString(undefined, { hour12: false })}]`)
                          .fontSize(10)
                          .fontColor($r('app.color.text_color'))
                          .opacity(0.7)
                          .margin({ left: 8 })

                        Text(repeatItem.item.tag)
                          .fontSize(10)
                          .fontColor(repeatItem.item.isError ? '#ff4d4f' : $r('app.color.text_color'))
                          .opacity(0.6)
                          .layoutWeight(1)
                          .margin({ left: 8 })
                      }
                      .width('100%')

                      Text(repeatItem.item.text)
                        .fontSize(12)
                        .fontColor(repeatItem.item.isError ? '#ff4d4f' : $r('app.color.text_color'))
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
                })
                .key((_item: SalmonLogLine, index: number) => index.toString())
                .virtualScroll()
            }
            .chainAnimation(true)
            .onAppear(() => {
              setTimeout(() => {
                const targetIndex = salmonLogger.logs.length - 1
                if (targetIndex >= 0) {
                  this.listScroller.scrollToIndex(targetIndex, false)
                }
              }, 50)
            })
            .layoutWeight(1)
            .width('100%')
            .height('100%')
            .padding({ left: 8, right: 8, bottom: 8 })
            .scrollBar(BarState.Auto)
          }.backgroundColor($r('app.color.start_window_background_blur'))
          .borderRadius(16)
          .width('100%')
          .height('100%')

          if (this.appEventGroups.length > 0) {
            Column() {
              List() {
                Repeat<hiAppEvent.AppEventGroup>(this.appEventGroups)
                  .each((repeatItem: RepeatItem<hiAppEvent.AppEventGroup>) => {
                    ListItem() {
                      Column() {
                        Text('事件名：' + repeatItem.item.name)
                          .fontColor($r('app.color.text_color'))
                          .fontSize(16)
                          .fontWeight(FontWeight.Medium)
                          .margin({ bottom: 8 })

                        Repeat<hiAppEvent.AppEventInfo>(repeatItem.item.appEventInfos)
                          .each((repeatItem2: RepeatItem<hiAppEvent.AppEventInfo>) => {
                            Column() {
                              this.EventInfoText('domain', repeatItem2.item.domain)
                              this.EventInfoText('name', repeatItem2.item.name)
                              this.EventInfoText('eventType', repeatItem2.item.eventType)
                              this.EventInfoText('time', repeatItem2.item.params['time'])
                              this.EventInfoText('crash_type', repeatItem2.item.params['crash_type'])
                              this.EventInfoText('foreground', repeatItem2.item.params['foreground'])
                              this.EventInfoText('bundle_version', repeatItem2.item.params['bundle_version'])
                              this.EventInfoText('bundle_name', repeatItem2.item.params['bundle_name'])
                              this.EventInfoText('pid', repeatItem2.item.params['pid'])
                              this.EventInfoText('uid', repeatItem2.item.params['uid'])
                              this.EventInfoText('uuid', repeatItem2.item.params['uuid'])
                              this.EventInfoText('exception', JSON.stringify(repeatItem2.item.params['exception']))
                              this.EventInfoText('hilog.size', repeatItem2.item.params['hilog']?.length)
                              this.EventInfoText('external_log',
                                JSON.stringify(repeatItem2.item.params['external_log']))
                              this.EventInfoText('log_over_limit', repeatItem2.item.params['log_over_limit'])
                              this.EventInfoText('test_data', repeatItem2.item.params['test_data'])
                            }
                            .width('100%')
                            .padding(8)
                            .margin({ top: 8 })
                          })
                          .key((_item: hiAppEvent.AppEventInfo, index2: number) => index2.toString())
                      }
                      .width('100%')
                      .padding(12)
                    }
                  })
                  .key((item: hiAppEvent.AppEventGroup, index: number) => item.name + (index ?? 0))
                  .virtualScroll()
              }
              .backgroundColor($r('app.color.start_window_background_blur'))
              .borderRadius(16)
              .width('100%')
              .height('100%')
              .layoutWeight(1)
              .padding({ left: 8, right: 8 })
              .scrollBar(BarState.Auto)
              .chainAnimation(true)
            }.width('100%')
            .height('100%')
          }
        }
        .index(this.currentTabIndex)
        .indicator(false)
        .layoutWeight(1)
        .width('100%')
        .onChange((index: number) => {
          this.currentTabIndex = index
        })

        Button('分享给开发者')
          .onClick(async () => {
            let logText = ''
            if (this.appEventGroups.length > 0) {
              logText += '=== 崩溃日志 ===\n' + JSON.stringify(this.appEventGroups) + '\n\n'
            }
            logText += '=== 运行日志 ===\n' + JSON.stringify(salmonLogger.logs)
            await this.shareText(logText)
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
    .titleBar({
      enableComponentSafeArea: true,
      padding: {
        start: LengthMetrics.vp(5),
        end: LengthMetrics.vp(5)
      },
      style: {
        scrollEffectOpts: {
          enableScrollEffect: true,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
          blurEffectiveStartOffset: LengthMetrics.vp(0),
          blurEffectiveEndOffset: LengthMetrics.vp(20)
        },
        originalStyle: {
          backgroundStyle: {
            backgroundColor: $r('sys.color.ohos_id_color_background'),
          },
          contentStyle: {
            titleStyle: {
              mainTitleColor: $r('sys.color.font_primary'),
              subTitleColor: $r('sys.color.font_secondary')
            },
            menuStyle: {
              backgroundColor: $r('sys.color.comp_background_tertiary'),
              iconColor: $r('sys.color.icon_primary')
            },
            backIconStyle: {
              backgroundColor: $r('sys.color.comp_background_tertiary'),
              iconColor: $r('sys.color.icon_primary')
            }
          }
        },
        scrollEffectStyle: {
          backgroundStyle: {
            backgroundColor: $r('sys.color.ohos_id_color_background_transparent'),
          },
          contentStyle: {
            titleStyle: {
              mainTitleColor: $r('sys.color.font_primary'),
              subTitleColor: $r('sys.color.font_secondary')
            },
            menuStyle: {
              backgroundColor: $r('sys.color.comp_background_tertiary'),
              iconColor: $r('sys.color.icon_primary')
            },
            backIconStyle: {
              backgroundColor: $r('sys.color.comp_background_tertiary'),
              iconColor: $r('sys.color.icon_primary')
            }
          }
        }
      },
      content: {
        title: {
          mainTitle: '流心运行日志',
        }
      },
    })
    .backgroundColor($r('app.color.start_window_background'))
    .padding({ top: SafeHeight.topSafeHeight, bottom: SafeHeight.bottomSafeHeight })
    .backgroundImage(
      Setting.backgroundDropBlur > 0 && Setting.backgroundBlurImageSrc.length > 0 ? Setting.backgroundBlurImageSrc :
        Setting.backgroundImageSrc, ImageRepeat.NoRepeat)
    .backgroundImageSize(ImageSize.Cover)
    .backgroundImagePosition(Alignment.Center)
    .hideBackButton(false)
    .bindToScrollable([this.listScroller])
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
    const appVersion = await ToolsUtil.getVersionName()
    const infoText =
      `反馈 QQ群 973792610，系统版本: ${deviceInfo.osFullName}，应用版本：${appVersion}，型号：${deviceInfo.productModel}，API版本：${deviceInfo.sdkApiVersion}`
    const fullText = infoText + '\n' + text
    try {
      const context = PathUtils.appContext
      const tempDir = PathUtils.tempPath
      const timestamp = new Date().getTime()
      const fileName = `crash_log_${timestamp}.txt`
      const filePath = `${tempDir}/${fileName}`
      salmonLogger.addLog(this.pathStack.getAllPathName()[0], '开始写入日志文件: ' + filePath, false)
      const file =
        fileIo.openSync(filePath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC)
      fileIo.writeSync(file.fd, fullText)
      const filePathString = file.path
      salmonLogger.addLog(this.pathStack.getAllPathName()[0], '文件写入完成: ' + filePathString, false)
      let shareData = new systemShare.SharedData({
        utd: uniformTypeDescriptor.UniformDataType.PLAIN_TEXT,
        uri: PathUtils.pathToUri(filePath),
        title: fileName,
        description: '流心播放器日志'
      })
      let controller1 = new systemShare.ShareController(shareData)
      await controller1.show(context, {
        previewMode: systemShare.SharePreviewMode.DETAIL,
        selectionMode: systemShare.SelectionMode.SINGLE
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

  private initSegmentItems() {
    const tips: ResourceStr[] = this.appEventGroups.length > 0
      ? ['运行日志', '崩溃日志']
      : ['运行日志']
    const buttonItems: SegmentButtonV2ItemOptions[] = tips.map((tip: ResourceStr) =>
    ({ text: tip } as SegmentButtonV2ItemOptions)
    )
    this.segmentItems = new SegmentButtonV2Items(buttonItems)
  }

  private getColor() {
    try {
      this.itemSelectedBackgroundColor = ColorMetrics.resourceColor($r('app.color.main_color'))
      this.itemSelectedFontColor = ColorMetrics.resourceColor($r('sys.color.white'))
    } catch (error) {
      salmonLogger.addLog(TAG, 'getColor error', true)
    }
  }
}
