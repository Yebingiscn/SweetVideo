import { Subtitle3DMode, SubtitleMode } from '../../common/enum/SubtitleMode'
import { AVPlayerController } from '../../controller/AVPlayerController'
import { MpvController } from '../../controller/MpvController/MpvController'
import { MpvSubtitleTrack } from '../../controller/MpvController/MpvTypes'
import { SubtitleTrack } from '../../interfaces/AudioTrackInterface'
import { InnerSubtitleDataSource } from '../../utils/DataUtil'
import VideoOperateUtil from '../../utils/VideoOperateUtil'
import ToolsUtil from '../../utils/ToolsUtil'

@Component
export struct SubtitlePanelComponent {
  @Link subtitleVisibility: Visibility
  @Link isAIAsrShown: boolean
  @Link subtitle3DMode: Subtitle3DMode
  @State innerSubtitleMenu: InnerSubtitleDataSource = new InnerSubtitleDataSource([])
  @Consume('player') player: AVPlayerController | MpvController
  onSubtitleOffClick = () => {
  }
  onSubtitleOffsetTime = () => {
  }
  onInnerSubtitleClick = () => {
  }
  onExternalSubtitleClick = () => {
  }
  onExternalSubtitleOffClick = () => {
  }
  onAIAsrClick = () => {
  }

  aboutToAppear(): void {
    this.innerSubtitleMenu = new InnerSubtitleDataSource(this.player.subtitleTrack)
  }

  private hasExternalSubtitle(): boolean {
    return (this.player.nowPlaying?.external_subtitle_format?.length ?? 0) > 0
  }

  private isExternalSubtitleActive(): boolean {
    return this.subtitleVisibility === Visibility.Visible &&
      this.player.subtitleSelected === SubtitleMode.EXTERNAL_SUBTITLE
  }

  private isSubtitleOffActive(): boolean {
    return this.subtitleVisibility === Visibility.None && !this.isAIAsrShown
  }

  private isInnerSubtitleActive(): boolean {
    return this.subtitleVisibility === Visibility.Visible &&
      this.player.subtitleSelected === SubtitleMode.INNER_SUBTITLE
  }

  build() {
    Menu() {
      MenuItem({
        content: '关闭字幕'
      })
        .contentFontColor(this.isSubtitleOffActive() ? $r('sys.color.white') :
          $r('app.color.text_color'))
        .onClick(() => {
          this.onSubtitleOffClick()
        })
        .height(40)
        .backgroundColor(this.isSubtitleOffActive() ? $r('app.color.main_color') :
          '')
        .borderRadius(16)
        .width('100%')

      if (this.player.subtitleTrack.length > 0) {
        MenuItem({
          content: '内嵌字幕',
          builder: this.InnerSubtitleMenu,
        })
          .contentFontColor(this.isInnerSubtitleActive() ? $r('sys.color.white') :
            $r('app.color.text_color'))
          .onClick(() => {
            this.onInnerSubtitleClick()
          })
          .height(40)
          .backgroundColor(this.isInnerSubtitleActive() ? $r('app.color.main_color') : '')
          .borderRadius(16)
          .width('100%')
      } else {
        MenuItem({
          content: '无内嵌字幕'
        })
          .contentFontColor($r('app.color.text_color'))
          .onClick(() => {
            ToolsUtil.showToast('当前视频没有内嵌字幕')
          })
          .height(40)
          .borderRadius(16)
          .width('100%')
      }

      if (this.hasExternalSubtitle()) {
        MenuItem({
          content: '外挂字幕',
          builder: this.ExternalSubtitleSubmenu
        })
          .contentFontColor(this.isExternalSubtitleActive() ? $r('sys.color.white') :
            $r('app.color.text_color'))
          .height(40)
          .backgroundColor(this.isExternalSubtitleActive() ? $r('app.color.main_color') : '')
          .borderRadius(16)
          .width('100%')
      } else {
        MenuItem({
          content: '无外挂字幕'
        })
          .contentFontColor($r('app.color.text_color'))
          .onClick(() => {
            ToolsUtil.showToast('当前视频没有外挂字幕')
          })
          .height(40)
          .borderRadius(16)
          .width('100%')
      }

      if (canIUse('SystemCapability.AI.AICaption')) {
        MenuItem({
          content: 'AI 字幕'
        })
          .contentFontColor(this.isAIAsrShown ? $r('sys.color.white') :
            $r('app.color.text_color'))
          .onClick(() => {
            this.onAIAsrClick()
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
        .contentFontColor(this.subtitle3DMode !== Subtitle3DMode.DISABLED ? $r('sys.color.white') :
          $r('app.color.text_color'))
        .backgroundColor(this.subtitle3DMode !== Subtitle3DMode.DISABLED ? $r('app.color.main_color') : '')
        .menuItemExtend()
    }
    .width(240)
    .height('auto')
    .subMenuExpandingMode(SubMenuExpandingMode.STACK_EXPAND)
  }

  @Builder
  ExternalSubtitleSubmenu() {
    Menu() {
      MenuItem({
        content: this.isExternalSubtitleActive() ? "关闭外挂字幕" : "启用外挂字幕"
      })
        .menuItemExtend()
        .onClick(() => {
          if (this.isExternalSubtitleActive()) {
            this.onExternalSubtitleOffClick()
            return
          }
          this.onExternalSubtitleClick()
        })

      MenuItem({
        content: "字幕偏移"
      })
        .menuItemExtend()
        .onClick(() => {
          this.onSubtitleOffsetTime()
        })
    }
    .width(140)
    .height('auto')
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
          .menuItemExtend()
          .contentFontColor(this.player.subtitleTrackSelected === item.id ? $r('sys.color.white') :
            $r('app.color.text_color'))
          .backgroundColor(this.player.subtitleTrackSelected === item.id ? $r('app.color.main_color') : '')
          .onClick(() => {
            this.player.selectSubtitleTrack(item.id)
            this.onInnerSubtitleClick()
          })
      }, (item: MpvSubtitleTrack | SubtitleTrack) => `${item.id}`)
    }
  }
}

@Extend(MenuItem)
function menuItemExtend() {
  .height(40)
  .borderRadius(16)
  .width('100%')
}
