import { Subtitle3DMode } from '../../common/enum/SubtitleMode'
import { AVPlayerController } from '../../controller/AVPlayerController'
import { MpvController } from '../../controller/MpvController/MpvController'
import { InnerSubtitleDataSource } from '../../utils/DataUtil'

@Component
export struct SubtitlePanelComponent {
  @Link subTitleVisibility: Visibility
  @Link isAIAsrShown: boolean
  @Link subtitle3DMode: Subtitle3DMode
  @State threeDSubtitleValue: string[] = ["不使用", "左/右", "上/下"]
  @State innerSubtitleMenu: InnerSubtitleDataSource = new InnerSubtitleDataSource([])
  @Consume('player') player: AVPlayerController | MpvController

  aboutToAppear(): void {
    if (this.player.subtitleTrack.length > 0) {
      this.innerSubtitleMenu = new InnerSubtitleDataSource(this.player.subtitleTrack)
    }
  }

  // TODO: 此处有bug，需要暴露方法
  build() {
    Menu() {
      MenuItem({
        content: '内嵌字幕：' + (this.subTitleVisibility === Visibility.Visible ? '显示' : '字幕隐藏'),
        builder: this.InnerSubtitleMenu,
      })
        .contentFontColor(this.player.subtitleSelected === SubtitleMode.INNER_SUBTITLE ? $r('sys.color.white') :
          $r('app.color.text_color'))
        .height(40)
        .backgroundColor(this.player.subtitleSelected === SubtitleMode.INNER_SUBTITLE ? $r('app.color.main_color') : '')
        .borderRadius(16)
        .width('100%')

      MenuItem({
        content: '外挂字幕：' + (this.subTitleVisibility === Visibility.Visible ? '显示' : '字幕隐藏')
      })
        .contentFontColor(this.player.subtitleSelected === SubtitleMode.EXTERNAL_SUBTITLE ? $r('sys.color.white') :
          $r('app.color.text_color'))
        .onClick(() => {
          this.isAIAsrShown = false
          this.subTitleVisibility === Visibility.Visible &&
            this.player.subtitleSelected === SubtitleMode.EXTERNAL_SUBTITLE ?
            this.subTitleVisibility = Visibility.None :
            this.subTitleVisibility = Visibility.Visible
          this.player.subtitleSelected = SubtitleMode.EXTERNAL_SUBTITLE
        })
        .height(40)
        .backgroundColor(this.player.subtitleSelected === SubtitleMode.EXTERNAL_SUBTITLE ? $r('app.color.main_color') :
          '')
        .borderRadius(16)
        .width('100%')

      if (canIUse('SystemCapability.AI.AICaption')) {
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
            this.player.subtitleSelected = SubtitleMode.AI_SUBTITLE
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
      LazyForEach(this.innerSubtitleMenu, (item: MpvSubtitleTrack | SubtitleTrack) => {
        MenuItem({
          content: item.id + " " + VideoOperateUtil.getLanguageName(item.title) + " " +
            VideoOperateUtil.getLanguageName(item.lang)
        })
          .onClick(() => {
            if (this.player instanceof MpvController) {
              this.player?.selectSubtitleTrack(item.id)
            }
            if (this.player instanceof AVPlayerController) {
              this.player?.selectSubtitleTrack(item.id)
            }
          })
      }, (item: MpvSubtitleTrack | SubtitleTrack) => item.title)
    }
  }
}

@Extend(MenuItem)
function menuItemExtend() {
  .height(40)
  .borderRadius(16)
  .width('100%')
}
