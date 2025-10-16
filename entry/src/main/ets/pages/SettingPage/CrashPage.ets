import { hiAppEvent } from '@kit.PerformanceAnalysisKit';
import { pasteboard } from '@kit.BasicServicesKit';
import ToolsUtil from '../../utils/ToolsUtil';

@Component
export struct CrashPage {
  @StorageProp('topSafeHeight') topSafeHeight: number = 0
  @StorageProp('bottomSafeHeight') bottomSafeHeight: number = 0
  @StorageLink('backgroundImageSrc') backgroundImageSrc: string = ''
  @StorageLink('backgroundDropBlur') backgroundDropBlur: number = 0
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
        Column() {
          Text(this.appEventGroups.length > 0 ? '流心崩溃日志' : '流心正常运行中...( •̀ ω •́ )✧')
          ForEach(this.appEventGroups, (eventGroup: hiAppEvent.AppEventGroup) => {
            Text('事件名：' + eventGroup.name)
            ForEach(eventGroup.appEventInfos, (eventInfo: hiAppEvent.AppEventInfo) => {
              Text() {
                Span(`HiAppEvent eventInfo.domain=${eventInfo.domain}\n` +
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
                  `HiAppEvent eventInfo.params.test_data=${eventInfo.params['test_data']}`)
              }
            })
          })
        }
        .backgroundColor($r('app.color.start_window_background_blur'))
        .height('100%')
        .width('100%')
        .borderRadius(8)
      }
      .margin({ left: 16, right: 16, bottom: 16 })
      .layoutWeight(1)
      .align(Alignment.Top)
      .height('100%')
      .width('100%')
      .borderRadius(8)
      .clip(true)
      .scrollBar(BarState.Off)
      .scrollable(ScrollDirection.Vertical) // 启用垂直滚动
      .edgeEffect(EdgeEffect.Spring) // 滚动边缘效果
      Button('复制给开发者')
        .onClick(() => {
          this.appEventGroups.toString().length > 0 ? copyText(JSON.stringify(this.appEventGroups)) :
            ToolsUtil.showToast('还没有日志可以复制喔')
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
    }
    .hideToolBar(true)
    .title('流心崩溃日志')
    .backgroundColor($r('app.color.start_window_background'))
    .padding({ top: this.topSafeHeight, bottom: this.bottomSafeHeight })
    .backgroundImage(this.backgroundImageSrc, ImageRepeat.NoRepeat)
    .backgroundImageSize(ImageSize.Cover)
    .backdropBlur(this.backgroundDropBlur)
    .backgroundImagePosition(Alignment.Center)
  }
}

function copyText(text: string) {
  const infoText = '反馈 QQ群 973792610，作者邮箱 1309932526@qq.com：'
  // Create clipboard content object
  const pasteboardData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, infoText + text);
  // Get system clipboard object
  const systemPasteboard = pasteboard.getSystemPasteboard();
  systemPasteboard.setData(pasteboardData).then(() => {
    ToolsUtil.showToast('日志复制成功' + infoText)
  })?.catch(() => {
    ToolsUtil.errorCatchExec('复制失败')
  }); // Put data into clipboard
}