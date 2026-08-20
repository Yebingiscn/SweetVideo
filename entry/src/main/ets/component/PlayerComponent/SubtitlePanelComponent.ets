import { Subtitle3DMode } from '../../common/enum/SubtitleMode'
import { PlayerControllerFactory, PlayerControllerInterface } from '../../controller/PlayerControllerFactory'
import { AVPlayerController } from '../../controller/AVPlayerController/AVPlayerController'
import { MpvController } from '../../controller/MpvController/MpvController'
import { MpvSubtitleTrack } from '../../controller/MpvController/MpvTypes'
import { SubtitleTrack } from '../../interfaces/AudioTrackInterface'
import { InnerSubtitleDataSource } from '../../utils/DataUtil'
import { SubtitleManager } from '../../utils/SubtitleManager'
import { PlayerEngine } from '../../common/NavigationCommon'
import ToolsUtil from '../../utils/ToolsUtil'
import VideoOperateUtil from '../../utils/VideoOperateUtil'
import { ButtonFancyModifier } from '../../common/AttributeModifierConfig'
import { Setting } from '../../utils/ObservedUtil'

@ComponentV2
export struct SubtitlePanelComponent {
  @Param subtitleManager: SubtitleManager = new SubtitleManager(new AVPlayerController())
  @Local _subtitle3DMode: Subtitle3DMode = Subtitle3DMode.DISABLED
  @Local innerSubtitleMenu: InnerSubtitleDataSource = new InnerSubtitleDataSource([])
  @Consumer('player') player: PlayerControllerInterface =
    PlayerControllerFactory.createAVPlayerController() as PlayerControllerInterface
  @Event onSubtitleOffsetTime: (_useMpvSubtitle: boolean) => void = (_useMpvSubtitle: boolean) => {
  }
  @Event onSwitchPlayerEngine: (_targetEngine: string) => void = () => {
  }

  aboutToAppear(): void {
    this.subtitleManager.syncFromPlayer()
    this.innerSubtitleMenu = new InnerSubtitleDataSource(this.player.subtitleTrack)
    this._subtitle3DMode = this.subtitleManager.subtitle3DMode
  }

  @Monitor('subtitleManager.subtitle3DMode')
  onSubtitle3DModeMonitor() {
    this._subtitle3DMode = this.subtitleManager.subtitle3DMode
  }

  build() {
    Menu() {
      MenuItem({
        content: '关闭字幕'
      })
        .contentFontColor(this.subtitleManager.isSubtitleOff ? $r('sys.color.white') :
          $r('app.color.text_color'))
        .onClick(() => {
          this.subtitleManager.switchToNone()
        })
        .height(40)
        .backgroundColor(this.subtitleManager.isSubtitleOff ? $r('app.color.main_color') :
          Color.Transparent)
        .borderRadius(16)
        .width('100%')

      if (this.player.subtitleTrack.length > 0) {
        MenuItem({
          content: '内嵌字幕',
          builder: this.InnerSubtitleMenu,
        })
          .contentFontColor(this.subtitleManager.isInnerSubtitleActive ? $r('sys.color.white') :
            $r('app.color.text_color'))
          .height(40)
          .backgroundColor(
            this.subtitleManager.isInnerSubtitleActive ? $r('app.color.main_color') : Color.Transparent)
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

      if (this.player instanceof MpvController && this.player.subtitleTrack.length > 1) {
        MenuItem({
          content: '副字幕',
          builder: this.SecondarySubtitleMenu,
        })
          .contentFontColor(this.player.secondarySubtitleTrackSelected >= 0 ? $r('sys.color.white') :
            $r('app.color.text_color'))
          .height(40)
          .backgroundColor(this.player.secondarySubtitleTrackSelected >= 0 ?
            $r('app.color.main_color') : Color.Transparent)
          .borderRadius(16)
          .width('100%')
      }

      if (this.hasExternalSubtitle()) {
        MenuItem({
          content: '外挂字幕',
        })
          .contentFontColor(this.subtitleManager.isExternalSubtitleActive ? $r('sys.color.white') :
            $r('app.color.text_color'))
          .onClick(() => {
            this.subtitleManager.switchToExternal()
          })
          .height(40)
          .backgroundColor(
            this.subtitleManager.isExternalSubtitleActive ? $r('app.color.main_color') : Color.Transparent)
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
          .contentFontColor(this.subtitleManager.isAIAsrShown ? $r('sys.color.white') :
            $r('app.color.text_color'))
          .onClick(() => {
            this.subtitleManager.switchToAI()
          })
          .height(40)
          .backgroundColor(this.subtitleManager.isAIAsrShown ? $r('app.color.main_color') : Color.Transparent)
          .borderRadius(16)
          .width('100%')
      }

      if (this.canShow3DSubtitleMenu()) {
        MenuItem({
          content: "3D 字幕",
          builder: this.ThreeDSubtitleSubmenu,
        })
          .contentFontColor(this._subtitle3DMode !== Subtitle3DMode.DISABLED ? $r('sys.color.white') :
            $r('app.color.text_color'))
          .backgroundColor(
            this._subtitle3DMode !== Subtitle3DMode.DISABLED ? $r('app.color.main_color') : Color.Transparent)
          .menuItemExtend()
      }

      if (this.hasExternalSubtitle() ||
        (this.player instanceof MpvController && this.player.subtitleTrack.length > 0)) {
        MenuItem({
          content: '字幕偏移'
        })
          .menuItemExtend()
          .contentFontColor($r('app.color.text_color'))
          .onClick(() => {
            this.onSubtitleOffsetTime(this.shouldAdjustMpvSubtitle())
          })
      }

      if (this.player instanceof AVPlayerController) {
        MenuItem({
          content: '内嵌字幕未显示？切换至 MPV 核心'
        })
          .menuItemExtend()
          .contentFontColor($r('app.color.text_color'))
          .onClick(() => {
            this.onSwitchPlayerEngine(PlayerEngine.MPV_PLAYER)
          })
      }

      MenuItemGroup({
        header: this.SubtitlePositionSlider,
        footer: this.SubtitleSizeSlider
      }) {
      }
    }
    .width(270)
    .height('auto')
    .subMenuExpandingMode(SubMenuExpandingMode.STACK_EXPAND)
  }

  @Builder
  SubtitlePositionSlider() {
    Row() {
      Text(`位置 ${Math.round(this.player.subtitlePosition)}%`)
        .fontSize(14)
        .fontColor($r('app.color.text_color'))
        .width(68)
      Slider({
        value: this.player.subtitlePosition,
        min: 5,
        max: 100,
        step: 1,
        style: SliderStyle.NONE
      })
        .onChange((value: number) => {
          this.player.setSubtitlePosition(value)
        })
        .selectedColor($r('app.color.main_color'))
        .enableHapticFeedback(true)
        .layoutWeight(1)
        .trackBorderRadius(16)
        .trackThickness(20)
        .selectedBorderRadius(16)
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.undo'))
          .fontSize(16)
          .fontColor([$r('app.color.text_color')])
      }
      .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
      .attributeModifier(new ButtonFancyModifier(28, 28))
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        this.player.setSubtitlePosition(Setting.subtitlePosition)
      })
    }
    .padding({
      left: 8,
      right: 8,
      top: 4,
      bottom: 4
    })
    .width('100%')
  }

  @Builder
  SubtitleSizeSlider() {
    Row() {
      Text(`大小 ${Math.round(this.player.subtitleSize)}号`)
        .fontSize(14)
        .fontColor($r('app.color.text_color'))
        .width(68)
      Slider({
        value: this.player.subtitleSize,
        min: 14,
        max: 48,
        step: 1,
        style: SliderStyle.NONE
      })
        .onChange((value: number) => {
          this.player.setSubtitleSize(value)
        })
        .selectedColor($r('app.color.main_color'))
        .enableHapticFeedback(true)
        .layoutWeight(1)
        .trackBorderRadius(16)
        .trackThickness(20)
        .selectedBorderRadius(16)
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.undo'))
          .fontSize(16)
          .fontColor([$r('app.color.text_color')])
      }
      .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
      .attributeModifier(new ButtonFancyModifier(28, 28))
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        this.player.setSubtitleSize(Number(Setting.subtitleSize))
      })
    }
    .padding({
      left: 8,
      right: 8,
      top: 4,
      bottom: 4
    })
    .width('100%')
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
          this.subtitleManager.set3DMode(Subtitle3DMode.DISABLED)
        })
        .backgroundColor(
          this._subtitle3DMode === Subtitle3DMode.DISABLED ? $r('app.color.main_color') : Color.Transparent)

      MenuItem({
        content: "左/右"
      })
        .menuItemExtend()
        .contentFontColor(this._subtitle3DMode === Subtitle3DMode.SIDE_BY_SIDE ? $r('sys.color.white') :
          $r('app.color.text_color'))
        .onClick(() => {
          this._subtitle3DMode = Subtitle3DMode.SIDE_BY_SIDE
          this.subtitleManager.set3DMode(Subtitle3DMode.SIDE_BY_SIDE)
        })
        .backgroundColor(
          this._subtitle3DMode === Subtitle3DMode.SIDE_BY_SIDE ? $r('app.color.main_color') : Color.Transparent)

      MenuItem({
        content: "上/下"
      })
        .menuItemExtend()
        .contentFontColor(this._subtitle3DMode === Subtitle3DMode.TOP_AND_BOTTOM ? $r('sys.color.white') :
          $r('app.color.text_color'))
        .onClick(() => {
          this._subtitle3DMode = Subtitle3DMode.TOP_AND_BOTTOM
          this.subtitleManager.set3DMode(Subtitle3DMode.TOP_AND_BOTTOM)
        })
        .backgroundColor(
          this._subtitle3DMode === Subtitle3DMode.TOP_AND_BOTTOM ? $r('app.color.main_color') : Color.Transparent)
    }
    .width(100).height('auto')
  }

  @Builder
  InnerSubtitleMenu() {
    Menu() {
      MenuItem({
        content: '关闭'
      })
        .menuItemExtend()
        .contentFontColor(!this.subtitleManager.isInnerSubtitleActive ? $r('sys.color.white') :
          $r('app.color.text_color'))
        .backgroundColor(!this.subtitleManager.isInnerSubtitleActive ? $r('app.color.main_color') : Color.Transparent)
        .onClick(() => {
          this.subtitleManager.switchToNone()
        })

      Repeat<MpvSubtitleTrack | SubtitleTrack>(this.innerSubtitleMenu.data)
        .each((repeatItem: RepeatItem<MpvSubtitleTrack | SubtitleTrack>) => {
          MenuItem({
            content: `${repeatItem.item.id} : ${this.getFormattedSubtitleName(repeatItem.item)}`
          })
            .menuItemExtend()
            .contentFontColor(this.subtitleManager.isInnerSubtitleActive &&
              this.player.subtitleTrackSelected === repeatItem.item.id ? $r('sys.color.white') :
              $r('app.color.text_color'))
            .backgroundColor(this.subtitleManager.isInnerSubtitleActive &&
              this.player.subtitleTrackSelected === repeatItem.item.id ? $r('app.color.main_color') : Color.Transparent)
            .onClick(() => {
              this.player.selectSubtitleTrack(repeatItem.item.id)
              this.subtitleManager.switchToInner()
              if (!this.player.supportsSubtitle3D()) {
                this.subtitleManager.set3DMode(Subtitle3DMode.DISABLED)
              }
            })
        })
        .key((item: MpvSubtitleTrack | SubtitleTrack, _index: number) => `${item.id}`)
    }
  }

  @Builder
  SecondarySubtitleMenu() {
    Menu() {
      MenuItem({
        content: '关闭'
      })
        .menuItemExtend()
        .contentFontColor(this.player.secondarySubtitleTrackSelected < 0 ? $r('sys.color.white') :
          $r('app.color.text_color'))
        .backgroundColor(this.player.secondarySubtitleTrackSelected < 0 ?
          $r('app.color.main_color') : Color.Transparent)
        .onClick(() => {
          this.player.selectSecondarySubtitleTrack(-1)
        })

      Repeat<MpvSubtitleTrack | SubtitleTrack>(this.innerSubtitleMenu.data)
        .each((repeatItem: RepeatItem<MpvSubtitleTrack | SubtitleTrack>) => {
          if (repeatItem.item.id !== this.player.subtitleTrackSelected) {
            MenuItem({
              content: `${repeatItem.item.id} : ${this.getFormattedSubtitleName(repeatItem.item)}`
            })
              .menuItemExtend()
              .contentFontColor(this.player.secondarySubtitleTrackSelected === repeatItem.item.id ?
                $r('sys.color.white') : $r('app.color.text_color'))
              .backgroundColor(this.player.secondarySubtitleTrackSelected === repeatItem.item.id ?
                $r('app.color.main_color') : Color.Transparent)
              .onClick(() => {
                this.subtitleManager.switchToInner()
                this.player.selectSecondarySubtitleTrack(repeatItem.item.id)
                if (!this.player.supportsSubtitle3D()) {
                  this.subtitleManager.set3DMode(Subtitle3DMode.DISABLED)
                }
              })
          }
        })
        .key((item: MpvSubtitleTrack | SubtitleTrack, _index: number) => `secondary-${item.id}`)
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

  private shouldAdjustMpvSubtitle(): boolean {
    return this.player instanceof MpvController &&
      (this.subtitleManager.isInnerSubtitleActive || !this.hasExternalSubtitle())
  }

  private canShow3DSubtitleMenu(): boolean {
    if (this.player instanceof MpvController && this.subtitleManager.isInnerSubtitleActive) {
      return this.player.supportsSubtitle3D()
    }
    return this.subtitleManager.subtitleVisibility === Visibility.Visible
  }
}

@Extend(MenuItem)
function menuItemExtend() {
  .height(40)
  .borderRadius(16)
  .width('100%')
}
