import { ButtonFancyModifier } from '../../common/AttributeModifierConfig'
import TimeUtil from '../../utils/TimeUtil'

export type PlaybackRangeMode = 'ab' | 'oped'

export interface PlaybackRangeValues {
  start: number
  end: number
}

export interface PlaybackRangeDialogOptions {
  mode: PlaybackRangeMode
  getDuration: () => number
  getCurrentPosition: () => number
  getRange: () => PlaybackRangeValues
  onSave: (start: number, end: number) => boolean
  onClear: () => boolean
}

// 草稿独立于父组件输入：拖动不 seek、不持久化，只有保存/清除才提交给宿主。
@ObservedV2
export class PlaybackRangeDraft {
  @Trace mode: PlaybackRangeMode = 'ab'
  @Trace start: number = 0
  @Trace end: number = 0
  @Trace duration: number = 0
  @Trace error: string = ''
  private loaded: boolean = false

  load(options: PlaybackRangeDialogOptions): void {
    this.mode = options.mode
    this.error = ''
    this.duration = 0
    this.start = 0
    this.end = 0
    this.loaded = false
    try {
      const duration = options.getDuration()
      this.duration = Number.isFinite(duration) && duration > 0 ? duration : 0
      const range = options.getRange()
      this.start = this.clamp(range.start)
      this.end = this.clamp(range.end)
      this.loaded = true
    } catch (_) {
      this.error = 'invalid'
    }
  }

  setStart(value: number): void {
    if (!Number.isFinite(value)) { this.error = 'invalid'; return }
    this.start = this.clamp(value)
    this.error = ''
  }

  setEnd(value: number): void {
    if (!Number.isFinite(value)) { this.error = 'invalid'; return }
    this.end = this.clamp(value)
    this.error = ''
  }

  useCurrent(options: PlaybackRangeDialogOptions, isStart: boolean): void {
    try {
      const position = options.getCurrentPosition()
      if (isStart) { this.setStart(position) } else { this.setEnd(position) }
    } catch (_) {
      this.error = 'invalid'
    }
  }

  save(options: PlaybackRangeDialogOptions): boolean {
    if (!this.validRange()) { this.error = 'invalid'; return false }
    try {
      if (options.onSave(this.start, this.end)) {
        this.error = ''
        return true
      }
    } catch (_) {
      // 宿主处理持久化和会话校验，失败时保留草稿，允许重试。
    }
    this.error = 'save-failed'
    return false
  }

  clear(options: PlaybackRangeDialogOptions): boolean {
    try {
      if (options.onClear()) {
        this.start = 0
        this.end = 0
        this.error = ''
        return true
      }
    } catch (_) {
      // 清除也由宿主原子提交，不能先擦掉未保存的草稿。
    }
    this.error = 'save-failed'
    return false
  }

  validRange(): boolean {
    if (!this.loaded || !Number.isFinite(this.duration) || this.duration <= 0 ||
      !Number.isFinite(this.start) || !Number.isFinite(this.end) ||
      this.start < 0 || this.start >= this.duration || this.end < 0 || this.end > this.duration) {
      return false
    }
    // 片尾位置为 0 表示未单独设置，遵循现有的全局跳过设置。
    return this.mode === 'oped' && this.end === 0 || this.start < this.end
  }

  private clamp(value: number): number {
    return Number.isFinite(value) ? Math.min(this.duration, Math.max(0, value)) : 0
  }
}

// CustomDialogController 沿用项目的 V1 外壳；编辑器使用 V2 单向输入和本地草稿。
@CustomDialog
export struct PlaybackRangeDialog {
  controller?: CustomDialogController
  options: PlaybackRangeDialogOptions = {
    mode: 'ab',
    getDuration: (): number => 0,
    getCurrentPosition: (): number => 0,
    getRange: (): PlaybackRangeValues => ({ start: 0, end: 0 }),
    onSave: (_start: number, _end: number): boolean => false,
    onClear: (): boolean => false
  }

  build() {
    PlaybackRangeEditor({ options: this.options, onClose: (): void => this.controller?.close() })
  }
}

@ComponentV2
struct PlaybackRangeEditor {
  @Require @Param options: PlaybackRangeDialogOptions
  @Event onClose: () => void = () => {}
  @Local draft: PlaybackRangeDraft = new PlaybackRangeDraft()

  aboutToAppear(): void {
    this.draft.load(this.options)
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        Text(this.options.mode === 'ab' ? $r('app.string.edit_ab_range') : $r('app.string.edit_oped_range'))
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_color'))
          .width('100%')

        if (this.options.mode === 'oped') {
          Text($r('app.string.playback_range_oped_hint'))
            .fontSize(13)
            .fontColor($r('app.color.text_color'))
            .opacity(0.6)
            .width('100%')
        }

        Column({ space: 4 }) {
          Row() {
            Text(this.options.mode === 'ab' ? 'A' : $r('app.string.playback_range_start'))
              .fontSize(15)
              .fontColor($r('app.color.text_color'))
              .layoutWeight(1)
            Text(TimeUtil.convertMSToHHMMSS(this.draft.start))
              .fontSize(15)
              .fontColor($r('app.color.text_color'))
          }.width('100%')
          Slider({
            value: this.draft.start,
            min: 0,
            max: Math.max(1, this.draft.duration),
            step: 1,
            style: SliderStyle.OutSet
          })
            .width('100%')
            .selectedColor($r('app.color.main_color'))
            .enabled(this.draft.duration > 0)
            .onChange((value: number): void => this.draft.setStart(value))
          Button($r('app.string.playback_range_use_current'))
            .attributeModifier(new ButtonFancyModifier('', 36))
            .fontSize(14)
            .fontColor($r('app.color.text_color'))
            .backgroundColor($r('sys.color.titlebar_icon_background_color'))
            .onClick((): void => this.draft.useCurrent(this.options, true))
        }.width('100%')

        Column({ space: 4 }) {
          Row() {
            Text(this.options.mode === 'ab' ? 'B' : $r('app.string.playback_range_end'))
              .fontSize(15)
              .fontColor($r('app.color.text_color'))
              .layoutWeight(1)
            Text(TimeUtil.convertMSToHHMMSS(this.draft.end))
              .fontSize(15)
              .fontColor($r('app.color.text_color'))
          }.width('100%')
          Slider({
            value: this.draft.end,
            min: 0,
            max: Math.max(1, this.draft.duration),
            step: 1,
            style: SliderStyle.OutSet
          })
            .width('100%')
            .selectedColor($r('app.color.main_color'))
            .enabled(this.draft.duration > 0)
            .onChange((value: number): void => this.draft.setEnd(value))
          Button($r('app.string.playback_range_use_current'))
            .attributeModifier(new ButtonFancyModifier('', 36))
            .fontSize(14)
            .fontColor($r('app.color.text_color'))
            .backgroundColor($r('sys.color.titlebar_icon_background_color'))
            .onClick((): void => this.draft.useCurrent(this.options, false))
        }.width('100%')

        if (this.draft.error.length > 0) {
          Text(this.draft.error === 'invalid' ? $r('app.string.range_invalid') : $r('app.string.range_save_failed'))
            .fontSize(13)
            .fontColor($r('app.color.text_color'))
            .width('100%')
        }

        Row({ space: 8 }) {
          Button($r('app.string.reset'))
            .attributeModifier(new ButtonFancyModifier('', 40))
            .fontSize(15)
            .fontColor($r('app.color.text_color'))
            .backgroundColor($r('sys.color.titlebar_icon_background_color'))
            .layoutWeight(1)
            .onClick((): void => { if (this.draft.clear(this.options)) { this.onClose() } })
          Button($r('app.string.cancel'))
            .attributeModifier(new ButtonFancyModifier('', 40))
            .fontSize(15)
            .fontColor($r('app.color.text_color'))
            .backgroundColor($r('sys.color.titlebar_icon_background_color'))
            .layoutWeight(1)
            .onClick((): void => this.onClose())
          Button($r('app.string.save'))
            .attributeModifier(new ButtonFancyModifier('', 40))
            .fontSize(15)
            .fontColor(Color.White)
            .backgroundColor($r('app.color.main_color'))
            .layoutWeight(1)
            .onClick((): void => { if (this.draft.save(this.options)) { this.onClose() } })
        }.width('100%')
      }
      .width('100%')
      .padding(20)
    }
    .width('100%')
    .constraintSize({ maxHeight: '90%' })
    .scrollBar(BarState.Auto)
  }
}
