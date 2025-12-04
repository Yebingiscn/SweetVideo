import { deviceInfo } from '@kit.BasicServicesKit'
import { SubtitleMode } from '../../common/enum/SubtitleMode'
import ToolsUtil from '../../utils/ToolsUtil'

@Component
export struct SubtitlePanelComponent {
  @Prop subTitleVisibility: Visibility
  @Link isAIAsrShown: boolean
  @Prop subtitleSelected: SubtitleMode

  build() {
    List() {
      ListItem() {
        Text('内嵌字幕：' + (this.subTitleVisibility === Visibility.Visible ? '显示（如果有）' : '字幕隐藏'))
          .fontColor(this.subtitleSelected === SubtitleMode.INNER_SUBTITLE ? $r('sys.color.white') :
            $r('app.color.text_color'))
      }
      .onClick(() => {
        this.isAIAsrShown = false
        this.subTitleVisibility === Visibility.Visible && this.subtitleSelected === SubtitleMode.INNER_SUBTITLE ?
          this.subTitleVisibility = Visibility.None :
          this.subTitleVisibility = Visibility.Visible
        this.subtitleSelected = SubtitleMode.INNER_SUBTITLE
      })
      .height(40)
      .backgroundColor(this.subtitleSelected === SubtitleMode.INNER_SUBTITLE ? $r('app.color.main_color') : '')
      .borderRadius(16)
      .width('100%')

      ListItem() {
        Text('外挂字幕' + (this.subTitleVisibility === Visibility.Visible ? '显示（如果有）' : '字幕隐藏'))
          .fontColor(this.subtitleSelected === SubtitleMode.EXTERNAL_SUBTITLE ? $r('sys.color.white') :
            $r('app.color.text_color'))
      }
      .onClick(() => {
        this.isAIAsrShown = false
        this.subTitleVisibility === Visibility.Visible && this.subtitleSelected === SubtitleMode.EXTERNAL_SUBTITLE ?
          this.subTitleVisibility = Visibility.None :
          this.subTitleVisibility = Visibility.Visible
        this.subtitleSelected = SubtitleMode.EXTERNAL_SUBTITLE
      })
      .height(40)
      .backgroundColor(this.subtitleSelected === SubtitleMode.EXTERNAL_SUBTITLE ? $r('app.color.main_color') : '')
      .borderRadius(16)
      .width('100%')

      if (deviceInfo.sdkApiVersion >= 18 && canIUse('SystemCapability.AI.AICaption')) {
        ListItem() {
          Text('AI 字幕：' + (this.isAIAsrShown ? '显示' : '隐藏'))
            .fontColor(this.subtitleSelected === SubtitleMode.AI_SUBTITLE ? $r('sys.color.white') :
              $r('app.color.text_color'))
        }
        .onClick(() => {
          this.isAIAsrShown = !this.isAIAsrShown
          if (this.isAIAsrShown) {
            ToolsUtil.showToast('AI 字幕将在控制栏隐藏后出现')
          }
          this.subTitleVisibility = Visibility.None
          this.subtitleSelected = SubtitleMode.AI_SUBTITLE
        })
        .height(40)
        .backgroundColor(this.subtitleSelected === SubtitleMode.AI_SUBTITLE ? $r('app.color.main_color') : '')
        .borderRadius(16)
        .width('100%')
      }
    }
    .width(200).height('auto').scrollBar(BarState.Off)
  }
}