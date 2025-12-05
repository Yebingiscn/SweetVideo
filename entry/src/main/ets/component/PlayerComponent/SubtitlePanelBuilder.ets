import { SubtitleMode } from '../../common/enum/SubtitleMode'
import ToolsUtil from '../../utils/ToolsUtil'
import { deviceInfo } from '@kit.BasicServicesKit'

class SubtitlePanelValue {
  subTitleVisibility: Visibility = Visibility.None
  isAIAsrShown: boolean = false
  subtitleSelected: SubtitleMode = SubtitleMode.INNER_SUBTITLE
}

@Builder
export function SubtitlePanelBuilder(subtitlePanelValue: SubtitlePanelValue) {
  List() {
    ListItem() {
      Text('内嵌字幕：' + (subtitlePanelValue.subTitleVisibility === Visibility.Visible ? '显示（如果有）' : '字幕隐藏'))
        .fontColor(subtitlePanelValue.subtitleSelected === SubtitleMode.INNER_SUBTITLE ? $r('sys.color.white') :
          $r('app.color.text_color'))
    }
    .onClick(() => {
      subtitlePanelValue.isAIAsrShown = false
      subtitlePanelValue.subTitleVisibility === Visibility.Visible &&
        subtitlePanelValue.subtitleSelected === SubtitleMode.INNER_SUBTITLE ?
        subtitlePanelValue.subTitleVisibility = Visibility.None :
        subtitlePanelValue.subTitleVisibility = Visibility.Visible
      subtitlePanelValue.subtitleSelected = SubtitleMode.INNER_SUBTITLE
    })
    .height(40)
    .backgroundColor(subtitlePanelValue.subtitleSelected === SubtitleMode.INNER_SUBTITLE ? $r('app.color.main_color') :
      '')
    .borderRadius(16)
    .width('100%')

    ListItem() {
      Text('外挂字幕' + (subtitlePanelValue.subTitleVisibility === Visibility.Visible ? '显示（如果有）' : '字幕隐藏'))
        .fontColor(subtitlePanelValue.subtitleSelected === SubtitleMode.EXTERNAL_SUBTITLE ? $r('sys.color.white') :
          $r('app.color.text_color'))
    }
    .onClick(() => {
      subtitlePanelValue.isAIAsrShown = false
      subtitlePanelValue.subTitleVisibility === Visibility.Visible &&
        subtitlePanelValue.subtitleSelected === SubtitleMode.EXTERNAL_SUBTITLE ?
        subtitlePanelValue.subTitleVisibility = Visibility.None :
        subtitlePanelValue.subTitleVisibility = Visibility.Visible
      subtitlePanelValue.subtitleSelected = SubtitleMode.EXTERNAL_SUBTITLE
    })
    .height(40)
    .backgroundColor(subtitlePanelValue.subtitleSelected === SubtitleMode.EXTERNAL_SUBTITLE ?
      $r('app.color.main_color') : '')
    .borderRadius(16)
    .width('100%')

    if (deviceInfo.sdkApiVersion >= 18 && canIUse('SystemCapability.AI.AICaption')) {
      ListItem() {
        Text('AI 字幕：' + (subtitlePanelValue.isAIAsrShown ? '显示' : '隐藏'))
          .fontColor(subtitlePanelValue.subtitleSelected === SubtitleMode.AI_SUBTITLE ? $r('sys.color.white') :
            $r('app.color.text_color'))
      }
      .onClick(() => {
        subtitlePanelValue.isAIAsrShown = !subtitlePanelValue.isAIAsrShown
        if (subtitlePanelValue.isAIAsrShown) {
          ToolsUtil.showToast('AI 字幕将在控制栏隐藏后出现')
        }
        subtitlePanelValue.subTitleVisibility = Visibility.None
        subtitlePanelValue.subtitleSelected = SubtitleMode.AI_SUBTITLE
      })
      .height(40)
      .backgroundColor(subtitlePanelValue.subtitleSelected === SubtitleMode.AI_SUBTITLE ? $r('app.color.main_color') :
        '')
      .borderRadius(16)
      .width('100%')
    }
  }
  .width(200).height('auto').scrollBar(BarState.Off)
}
