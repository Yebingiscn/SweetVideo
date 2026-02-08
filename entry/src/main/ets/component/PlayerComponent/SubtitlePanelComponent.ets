import { deviceInfo } from '@kit.BasicServicesKit'
import { Subtitle3DMode, SubtitleMode } from '../../common/enum/SubtitleMode'
import { MpvController } from '../../controller/MpvController/MpvController'
import { MpvSubtitleTrack } from '../../controller/MpvController/MpvTypes'
import { InnerSubtitleDataSource } from '../../utils/DataUtil'
import ToolsUtil from '../../utils/ToolsUtil'
import VideoOperateUtil from '../../utils/VideoOperateUtil'

@Component
export struct SubtitlePanelComponent {
  @Link subTitleVisibility: Visibility
  @Link isAIAsrShown: boolean
  @Link subtitle3DMode: Subtitle3DMode
  @Prop subtitleSelected: SubtitleMode
  @Prop innerSubtitleData: MpvSubtitleTrack[] | []
  @State threeDSubtitleValue: string[] = ["不使用", "左/右", "上/下"]
  @State innerSubtitleMenu: InnerSubtitleDataSource = new InnerSubtitleDataSource([])
  @ObjectLink mpv: MpvController | null

  aboutToAppear(): void {
    if (this.innerSubtitleData.length > 0) {
      this.innerSubtitleMenu = new InnerSubtitleDataSource(this.innerSubtitleData)
    }
  }

  build() {
    Menu() {
      MenuItem({
        content: '内嵌字幕：' + (this.subTitleVisibility === Visibility.Visible ? '显示（如果有）' : '字幕隐藏'),
        builder: this.InnerSubtitleMenu,
      })
        .contentFontColor(this.subtitleSelected === SubtitleMode.INNER_SUBTITLE ? $r('sys.color.white') :
          $r('app.color.text_color'))
        .height(40)
        .backgroundColor(this.subtitleSelected === SubtitleMode.INNER_SUBTITLE ? $r('app.color.main_color') : '')
        .borderRadius(16)
        .width('100%')

      MenuItem({
        content: '外挂字幕：' + (this.subTitleVisibility === Visibility.Visible ? '显示（如果有）' : '字幕隐藏')
      })
        .contentFontColor(this.subtitleSelected === SubtitleMode.EXTERNAL_SUBTITLE ? $r('sys.color.white') :
          $r('app.color.text_color'))
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
        MenuItem({
          content: 'AI 字幕：' + (this.isAIAsrShown ? '显示' : '隐藏')
        })
          .contentFontColor(this.isAIAsrShown ? $r('sys.color.white') :
            $r('app.color.text_color'))
          .onClick(() => {
            this.isAIAsrShown = !this.isAIAsrShown
            if (this.isAIAsrShown) {
              ToolsUtil.showToast('AI 字幕将在控制栏隐藏后出现')
            }
            this.subTitleVisibility = Visibility.None
            this.subtitleSelected = SubtitleMode.AI_SUBTITLE
          })
          .height(40)
          .backgroundColor(this.isAIAsrShown ? $r('app.color.main_color') : '')
          .borderRadius(16)
          .width('100%')
      }

      MenuItem({
        content: "3D 字幕",
        builder: this.ThreeDSubtitleSubmenu,
      })
        .contentFontColor($r('app.color.text_color'))
        .menuItemExtend()
    }
    .width(240)
    .height('auto')
    .subMenuExpandingMode(SubMenuExpandingMode.STACK_EXPAND)
  }

  @Builder
  ThreeDSubtitleSubmenu() {
    Menu() {
      MenuItem({
        content: "不使用"
      })
        .menuItemExtend()
        .contentFontColor(this.subtitle3DMode === Subtitle3DMode.DISABLED ? $r('sys.color.white') :
          $r('app.color.text_color'))
        .onClick(() => {
          this.subtitle3DMode = Subtitle3DMode.DISABLED
        })
        .backgroundColor(this.subtitle3DMode === Subtitle3DMode.DISABLED ? $r('app.color.main_color') : '')

      MenuItem({
        content: "左/右"
      })
        .menuItemExtend()
        .contentFontColor(this.subtitle3DMode === Subtitle3DMode.SIDE_BY_SIDE ? $r('sys.color.white') :
          $r('app.color.text_color'))
        .onClick(() => {
          this.subtitle3DMode = Subtitle3DMode.SIDE_BY_SIDE
        })
        .backgroundColor(this.subtitle3DMode === Subtitle3DMode.SIDE_BY_SIDE ? $r('app.color.main_color') : '')

      MenuItem({
        content: "上/下"
      })
        .menuItemExtend()
        .contentFontColor(this.subtitle3DMode === Subtitle3DMode.TOP_AND_BOTTOM ? $r('sys.color.white') :
          $r('app.color.text_color'))
        .onClick(() => {
          this.subtitle3DMode = Subtitle3DMode.TOP_AND_BOTTOM;
        })
        .backgroundColor(this.subtitle3DMode === Subtitle3DMode.TOP_AND_BOTTOM ? $r('app.color.main_color') : '')
    }
    .width(100).height('auto')
  }

  @Builder
  InnerSubtitleMenu() {
    Menu() {
      LazyForEach(this.innerSubtitleMenu, (item: MpvSubtitleTrack) => {
        MenuItem({
          content: item.id + " " + VideoOperateUtil.getLanguageName(item.title) + " " +
          VideoOperateUtil.getLanguageName(item.lang)
        })
          .onClick(() => {
            this.mpv?.selectSubtitleTrack(item.id)
          })
      }, (item: MpvSubtitleTrack) => item.title)
    }
  }
}

@Extend(MenuItem)
function menuItemExtend() {
  .height(40)
  .borderRadius(16)
  .width('100%')
}
