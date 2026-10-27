import type { PlayerControllerInterface } from '../../controller/PlayerControllerFactory'
import { AVPlayerController } from '../../controller/AVPlayerController/AVPlayerController'
import { MpvController } from '../../controller/MpvController/MpvController'
import { SymbolGlyphModifier } from '@kit.ArkUI'
import { MpvDiscTitle } from '../../controller/MpvController/MpvTypes'
import { PlayerEngine } from '../../common/NavigationCommon'
import { SleepTimerController } from '../../controller/SleepTimerController'
import { AbLoopController } from '../../controller/AbLoopController'
import { PlaybackPolicyMenuComponent } from './PlaybackPolicyMenuComponent'
import { PlaybackOpeningEndingRange } from '../../controller/PlaybackOpeningEndingRange'

@ComponentV2
export struct VideoSettingComponent {
  @Require @Param sleepTimer: SleepTimerController
  @Require @Param abLoop: AbLoopController
  @Require @Param openingEnding: PlaybackOpeningEndingRange
  @Require @Param player: PlayerControllerInterface

  @Event onEditRange: (mode: 'ab' | 'oped') => void = () => {
  }

  @Event onSetIntro: () => void = () => {
  }

  @Event onSetOutro: () => void = () => {
  }

  @Event onClearOpeningEnding: () => void = () => {
  }

  @Event forward_80_s: (_time: number) => void = () => {
  }
  @Event onStartTimer: (_time: number) => void = () => {
  }
  @Event onCancelTimer: () => void = () => {
  }
  @Event onEndCurrent: () => void = () => {
  }
  @Event onCustomTimer: () => void = () => {
  }
  @Event toggleListenVideo: () => void = () => {
  }
  @Event captureScreen: () => void = () => {
  }
  @Event onSetPointA: () => void = () => {
  }
  @Event onSetPointB: () => void = () => {
  }
  @Event onClearAbLoop: () => void = () => {
  }
  @Event onScreenMirror: () => void = () => {
  }
  @Event onABCircleStatusClick: () => void = () => {
  }
  @Event onSwitchPlayerEngine: (_targetEngine: string) => void = () => {
  }

  build() {
    PlaybackPolicyMenuComponent({
      sleepTimer: this.sleepTimer,
      abLoop: this.abLoop,
      openingEnding: this.openingEnding,
      onEditRange: (mode: 'ab' | 'oped'): void => this.onEditRange(mode),
      onSetIntro: (): void => this.onSetIntro(),
      onSetOutro: (): void => this.onSetOutro(),
      onClearOpeningEnding: (): void => this.onClearOpeningEnding(),
      onStartTimer: (time: number): void => this.onStartTimer(time),
      onCancelTimer: (): void => this.onCancelTimer(),
      onEndCurrent: (): void => this.onEndCurrent(),
      onCustomTimer: (): void => this.onCustomTimer(),
      onSetPointA: (): void => this.onSetPointA(),
      onSetPointB: (): void => this.onSetPointB(),
      onClearAbLoop: (): void => this.onClearAbLoop(),
      onABCircleStatusClick: (): void => this.onABCircleStatusClick(),
      additionalItems: (): void => this.PlayerMenuItems()
    })
  }

  @Builder
  DiscTitleMenu() {
    List() {
      if (this.player instanceof MpvController) {
        Repeat<MpvDiscTitle>(this.player.discTitles)
          .each((entry: RepeatItem<MpvDiscTitle>) => {
            ListItem() {
              Row({ space: 8 }) {
                Column({ space: 4 }) {
                  Text($r('app.string.bluray_title_number', entry.item.id + 1))
                    .fontSize(14)
                    .fontWeight(entry.item.selected ? FontWeight.Bold : FontWeight.Normal)
                    .fontColor(entry.item.selected ? $r('sys.color.white') : $r('app.color.text_color'))
                  Text(entry.item.title)
                    .fontSize(12)
                    .fontColor(entry.item.selected ? $r('sys.color.white') : $r('app.color.text_color'))
                    .opacity(0.7)
                    .maxLines(2)
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              }
              .padding(12)
              .width('100%')
              .borderRadius(16)
              .backgroundColor(entry.item.selected ? $r('app.color.main_color') : Color.Transparent)
            }.onClick(() => {
              if (this.player instanceof MpvController) {
                this.player.selectDiscTitle(entry.item)
              }
            })
          })
          .key((title: MpvDiscTitle) => title.requestId + ':' + title.id)
          .virtualScroll()
      }
    }.width(300).height('100%').constraintSize({ maxHeight: 320 }).scrollBar(BarState.Auto)
  }

  @Builder
  PlayerMenuItems() {
    if (this.player instanceof MpvController && this.player.discTitles.length > 0) {
      MenuItem({ content: $r('app.string.bluray_titles'), builder: (): void => this.DiscTitleMenu() })
    }
    MenuItem({
      symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.fast_forward')),
      content: $r('app.string.forward_80s')
    }).onClick(() => {
      this.forward_80_s(this.player.playTime + 80 * 1000)
    })
    MenuItem({
      symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.trapezoid_and_line_vertical')),
      content: $r('app.string.screen_mirror')
    }).onClick(() => {
      this.onScreenMirror()
    })
    MenuItem({
      symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.arrow_left_arrow_right')),
      content: this.player.isMpvPlayer() ? $r('app.string.switch_to_system_player') :
        $r('app.string.switch_to_mpv_player')
    }).onClick(() => {
      this.onSwitchPlayerEngine(this.player.isMpvPlayer() ? PlayerEngine.AV_PLAYER : PlayerEngine.MPV_PLAYER)
    })

    if (this.player instanceof AVPlayerController || this.player instanceof MpvController) {
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.headphones')),
        content: $r('app.string.listen_video')
      }).onClick(() => {
        this.toggleListenVideo()
      })
    }
    MenuItem({
      symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.camera_master_ai')),
      content: this.player.superResolutionState ? $r('app.string.disable_super_resolution') :
        $r('app.string.enable_super_resolution'),
    }).onClick(() => {
      this.player.setSuperResolutionState(!this.player.superResolutionState)
    })
    if (this.player instanceof MpvController) {
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.doc_plaintext')),
        content: this.player.debugInfoVisible ? $r('app.string.hide_debug_info') : $r('app.string.show_debug_info'),
      }).onClick(() => {
        if (this.player instanceof MpvController) {
          this.player.toggleDebugInfo()
        }
      })
    }
  }
}
