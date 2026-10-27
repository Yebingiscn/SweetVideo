import { SymbolGlyphModifier } from '@kit.ArkUI'
import { AbLoopController } from '../../controller/AbLoopController'
import { SleepTimerController } from '../../controller/SleepTimerController'
import TimeUtil from '../../utils/TimeUtil'
import ToolsUtil from '../../utils/ToolsUtil'
import { PlaybackOpeningEndingRange } from '../../controller/PlaybackOpeningEndingRange'

// 同一个菜单同时供普通播放器和短视频使用，菜单只发送操作意图。
@ComponentV2
export struct PlaybackPolicyMenuComponent {
  @Require @Param sleepTimer: SleepTimerController
  @Require @Param abLoop: AbLoopController
  @Require @Param openingEnding: PlaybackOpeningEndingRange
  @Event onEditRange: (mode: 'ab' | 'oped') => void = () => {}
  @Event onSetIntro: () => void = () => {}
  @Event onSetOutro: () => void = () => {}
  @Event onClearOpeningEnding: () => void = () => {}
  @Event onStartTimer: (_time: number) => void = () => {}
  @Event onCancelTimer: () => void = () => {}
  @Event onEndCurrent: () => void = () => {}
  @Event onCustomTimer: () => void = () => {}
  @Event onSetPointA: () => void = () => {}
  @Event onSetPointB: () => void = () => {}
  @Event onClearAbLoop: () => void = () => {}
  @Event onABCircleStatusClick: () => void = () => {}
  @BuilderParam additionalItems: () => void = this.emptyItems
  private timerDisplayTask: number | undefined = undefined

  aboutToAppear(): void {
    this.sleepTimer.checkDeadline()
    // 只在菜单展示时刷新剩余时间，不为每个播放器增加常驻轮询。
    if (this.timerDisplayTask !== undefined) { clearInterval(this.timerDisplayTask) }
    this.timerDisplayTask = setInterval((): void => { this.sleepTimer.checkDeadline() }, 1000)
  }

  aboutToDisappear(): void {
    if (this.timerDisplayTask !== undefined) { clearInterval(this.timerDisplayTask) }
    this.timerDisplayTask = undefined
  }

  @Builder
  emptyItems() {}

  build() {
    Menu() {
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.clock')),
        content: $r('app.string.timer'),
        labelInfo: this.sleepTimer.mode === 'countdown' ? TimeUtil.convertMSToHHMMSS(this.sleepTimer.remainingMs) :
          (this.sleepTimer.mode === 'end-current' ? $r('app.string.play_episode_end') : ''),
        builder: (): void => this.TimerMenuExtend()
      })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.time_lapse')),
        content: $r('app.string.ab_loop'),
        builder: (): void => this.ABMenuExtend()
      })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.time_lapse')),
        content: $r('app.string.op_ed_time'),
        builder: (): void => this.OpeningEndingMenuExtend()
      })
      this.additionalItems()
    }
  }

  @Builder
  TimerMenuExtend() {
    Menu() {
      Repeat<number>([15, 30, 60]).each((item: RepeatItem<number>) => {
        MenuItem({
          symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.clock')),
          content: `${item.item}min`
        }).onClick(() => {
          this.onStartTimer(item.item * 60000)
          ToolsUtil.showToast(ToolsUtil.getStringResourceArgs($r('app.string.timer_set_minutes').id, item.item))
        })
      })
        .key((minutes: number) => minutes.toString())
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.clock')),
        content: $r('app.string.timer_custom_minutes')
      }).onClick(() => this.onCustomTimer())
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.clock')),
        content: $r('app.string.play_episode_end')
      }).onClick(() => {
        ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.timer_set_episode_end').id))
        this.onEndCurrent()
      })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.clock')),
        content: $r('app.string.not_enabled')
      }).onClick(() => {
        this.onCancelTimer()
        ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.timer_cleared').id))
      })
    }
  }

  @Builder
  ABMenuExtend() {
    Menu() {
      MenuItem({ content: $r('app.string.edit_ab_range') })
        .onClick(() => this.onEditRange('ab'))
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.time_lapse')),
        content: this.abLoop.enabled ? $r('app.string.stop_ab_loop') : $r('app.string.start_ab_loop')
      }).onClick(() => this.onABCircleStatusClick())
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.time_lapse')),
        content: $r('app.string.set_point_a_time', TimeUtil.convertMSToHHMMSS(this.abLoop.pointA)),
      }).onClick(() => this.onSetPointA())
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.time_lapse')),
        content: $r('app.string.set_point_b_time', TimeUtil.convertMSToHHMMSS(this.abLoop.pointB)),
      }).onClick(() => this.onSetPointB())
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.time_lapse')),
        content: $r('app.string.cancel_ab_time')
      }).onClick(() => this.onClearAbLoop())
    }
  }

  @Builder
  OpeningEndingMenuExtend() {
    Menu() {
      MenuItem({ content: $r('app.string.edit_oped_range') })
        .onClick(() => this.onEditRange('oped'))
      MenuItem({ content: $r('app.string.set_intro_time', TimeUtil.convertMSToHHMMSS(this.openingEnding.startTime)) })
        .onClick(() => this.onSetIntro())
      MenuItem({ content: $r('app.string.set_outro_time', TimeUtil.convertMSToHHMMSS(this.openingEnding.endTime)) })
        .onClick(() => this.onSetOutro())
      MenuItem({ content: $r('app.string.cancel_op_ed_time') })
        .onClick(() => this.onClearOpeningEnding())
    }
  }
}
