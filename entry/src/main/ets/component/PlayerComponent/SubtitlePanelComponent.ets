import { Subtitle3DMode } from '../../common/enum/SubtitleMode'
import { AVPlayerController } from '../../controller/AVPlayerController'
import { MpvController } from '../../controller/MpvController/MpvController'
import { MpvSubtitleTrack } from '../../controller/MpvController/MpvTypes'
import { SubtitleTrack } from '../../interfaces/AudioTrackInterface'
import { InnerSubtitleDataSource } from '../../utils/DataUtil'

@ComponentV2
export struct SubtitlePanelComponent {
  @Param subtitleVisibility: Visibility = Visibility.None
  @Param isAIAsrShown: boolean = false
  @Param subtitle3DMode: Subtitle3DMode = Subtitle3DMode.DISABLED
  @Local _subtitle3DMode: Subtitle3DMode = Subtitle3DMode.DISABLED
  @Local innerSubtitleMenu: InnerSubtitleDataSource = new InnerSubtitleDataSource([])
  @Consumer('player') player: AVPlayerController | MpvController = new AVPlayerController()
  @Consumer('pathStack') pathStack: NavPathStack = new NavPathStack()
  @Event onSubtitle3DModeChange: (v: Subtitle3DMode) => void = () => {
  }
  @Event onSubtitleOffClick: () => void = () => {
  }
  @Event onSubtitleOffsetTime: () => void = () => {
  }
  @Event onInnerSubtitleClick: () => void = () => {
  }
  @Event onExternalSubtitleClick: () => void = () => {
  }
  @Event onAIAsrClick: () => void = () => {
  }

  aboutToAppear(): void {
    this.innerSubtitleMenu = new InnerSubtitleDataSource(this.player.subtitleTrack)
    this._subtitle3DMode = this.subtitle3DMode
  }

  @Monitor('subtitle3DMode')
  onSubtitle3DModeMonitor() {
    this._subtitle3DMode = this.subtitle3DMode
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
          .onClick(() => {
            this.onExternalSubtitleClick()
          })
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
        .contentFontColor(this._subtitle3DMode !== Subtitle3DMode.DISABLED ? $r('sys.color.white') :
          $r('app.color.text_color'))
        .backgroundColor(this._subtitle3DMode !== Subtitle3DMode.DISABLED ? $r('app.color.main_color') : '')
        .menuItemExtend()

      if (this.player instanceof AVPlayerController) {
        MenuItem({
          content: '内嵌字幕未显示？切换至 MPV 核心'
        })
          .menuItemExtend()
          .contentFontColor($r('app.color.text_color'))
          .onClick(() => {
            this.switchToMpvPlayer()
          })
      }
    }
    .width(240)
    .height('auto')
    .subMenuExpandingMode(SubMenuExpandingMode.STACK_EXPAND)
  }

  @Builder
  ExternalSubtitleSubmenu() {
    Menu() {
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
        .contentFontColor(this._subtitle3DMode === Subtitle3DMode.DISABLED ? $r('sys.color.white') :
          $r('app.color.text_color'))
        .onClick(() => {
          this._subtitle3DMode = Subtitle3DMode.DISABLED
          this.onSubtitle3DModeChange(Subtitle3DMode.DISABLED)
        })
        .backgroundColor(this._subtitle3DMode === Subtitle3DMode.DISABLED ? $r('app.color.main_color') : '')

      MenuItem({
        content: "左/右"
      })
        .menuItemExtend()
        .contentFontColor(this._subtitle3DMode === Subtitle3DMode.SIDE_BY_SIDE ? $r('sys.color.white') :
          $r('app.color.text_color'))
        .onClick(() => {
          this._subtitle3DMode = Subtitle3DMode.SIDE_BY_SIDE
          this.onSubtitle3DModeChange(Subtitle3DMode.SIDE_BY_SIDE)
        })
        .backgroundColor(this._subtitle3DMode === Subtitle3DMode.SIDE_BY_SIDE ? $r('app.color.main_color') : '')

      MenuItem({
        content: "上/下"
      })
        .menuItemExtend()
        .contentFontColor(this._subtitle3DMode === Subtitle3DMode.TOP_AND_BOTTOM ? $r('sys.color.white') :
          $r('app.color.text_color'))
        .onClick(() => {
          this._subtitle3DMode = Subtitle3DMode.TOP_AND_BOTTOM
          this.onSubtitle3DModeChange(Subtitle3DMode.TOP_AND_BOTTOM)
        })
        .backgroundColor(this._subtitle3DMode === Subtitle3DMode.TOP_AND_BOTTOM ? $r('app.color.main_color') : '')
    }
    .width(100).height('auto')
  }

  @Builder
  InnerSubtitleMenu() {
    Menu() {
      Repeat<MpvSubtitleTrack | SubtitleTrack>(this.innerSubtitleMenu.data)
        .each((repeatItem: RepeatItem<MpvSubtitleTrack | SubtitleTrack>) => {
          MenuItem({
            content: `${repeatItem.item.id} : ${this.getFormattedSubtitleName(repeatItem.item)}`
          })
            .menuItemExtend()
            .contentFontColor(this.player.subtitleTrackSelected === repeatItem.item.id ? $r('sys.color.white') :
              $r('app.color.text_color'))
            .backgroundColor(this.player.subtitleTrackSelected === repeatItem.item.id ? $r('app.color.main_color') : '')
            .onClick(() => {
              this.player.selectSubtitleTrack(repeatItem.item.id)
              this.onInnerSubtitleClick()
            })
        })
        .key((item: MpvSubtitleTrack | SubtitleTrack, _index: number) => `${item.id}`)
    }
  }

  private getFormattedSubtitleName(item: MpvSubtitleTrack | SubtitleTrack): string {
    const langName = VideoOperateUtil.getLanguageName(item.lang)
    const titleName = VideoOperateUtil.getLanguageName(item.title)
    if (titleName && titleName !== '未知' && titleName !== langName) {
      return titleName + (langName ? ` (${langName})` : '')
    }
    if (langName) {
      return langName
    }
    if (item.title) {
      return item.title
    }
    return `Track ${item.id}`
  }

  private hasExternalSubtitle(): boolean {
    return (this.player.nowPlaying?.external_subtitle_format?.length ?? 0) > 0
  }

  private switchToMpvPlayer(): void {
    const avPlayer = this.player as AVPlayerController
    VideoOperateUtil.playErrorExecute(this.pathStack, avPlayer.videoMetaDataList,
      avPlayer.nowPlaying?.date!, NavigationAddress.MPV_PLAYER, avPlayer.playTime)
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
}

@Extend(MenuItem)
function menuItemExtend() {
  .height(40)
  .borderRadius(16)
  .width('100%')
}
