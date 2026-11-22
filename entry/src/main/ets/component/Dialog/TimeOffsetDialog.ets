import { ButtonFancyModifier } from '../../common/AttributeModifierConfig'

@CustomDialog
export struct TimeOffsetDialog {
  confirm?: (value: number) => void
  onOffsetPreview?: (offset: number) => void
  onCloseButton?: () => void
  onPrevSubtitle?: (currentOffset: number) => number | undefined
  onNextSubtitle?: (currentOffset: number) => number | undefined
  showSubtitleNavigation?: () => boolean
  controller?: CustomDialogController
  getCurrentValue?: () => number
  title: ResourceStr = $r('app.string.subtitle_offset_time')
  @State inputText: string = ''
  inputController: TextInputController = new TextInputController()
  minOffset: number = -50000
  maxOffset: number = 50000
  inputId: string = 'time_offset_input'
  fineStepMs: number = 100
  coarseStepMs: number = 1000
  previewOnInput: boolean = false
  helpText?: ResourceStr
  quickBtnFontSize: number = 14

  aboutToAppear(): void {
    const currentOffset = this.getCurrentValue ? this.getCurrentValue() : 0
    this.inputText = currentOffset.toString()
  }

  build() {
    Column({ space: 8 }) {
      Text(this.title)
        .fontSize(20)
        .fontColor($r('app.color.text_color'))
        .fontWeight(FontWeight.Bold)
        .margin({ top: 0, bottom: 5 })

      Row() {
        Stack({ alignContent: Alignment.End }) {
          TextInput({
            text: this.inputText,
            placeholder: `${this.getCurrentValue ? this.getCurrentValue() : 0}`,
            controller: this.inputController
          })
            .keyboardAppearance(KeyboardAppearance.IMMERSIVE)
            .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
            .onChange((input: string) => {
              const next = input.trim()
              if (next === this.inputText) {
                return
              }
              this.inputText = next
              const value = this.getParsedValue()
              if (this.previewOnInput && value >= this.minOffset && value <= this.maxOffset) {
                this.onOffsetPreview?.(value)
              }
            })
            .inputFilter('^[-+]?\\d*$')
            .type(InputType.NUMBER_DECIMAL)
            .enableAutoFill(true)
            .id(this.inputId)
            .height(36)
            .maxLength(10)
            .maxLines(1)
            .enterKeyType(EnterKeyType.Done)
            .padding({ right: 26 })

          Text('ms')
            .fontSize(13)
            .fontColor('#909399')
            .margin({ right: 10 })
        }
        .height(36)
        .layoutWeight(1)

        Row({ space: 6 }) {
          Button({ type: ButtonType.Normal, stateEffect: true }) {
            SymbolGlyph($r('sys.symbol.xmark'))
              .fontSize(16)
              .fontColor([$r('app.color.text_color')])
          }
          .attributeModifier(new ButtonFancyModifier(36, 36))
          .backgroundColor($r('sys.color.titlebar_icon_background_color'))
          .onClick(() => {
            if (this.onCloseButton) {
              this.onCloseButton()
              return
            }
            this.controller?.close()
          })

          Button({ type: ButtonType.Normal, stateEffect: true }) {
            SymbolGlyph($r('sys.symbol.checkmark'))
              .fontSize(16)
              .fontColor([$r('app.color.text_color')])
          }
          .attributeModifier(new ButtonFancyModifier(36, 36))
          .backgroundColor($r('sys.color.titlebar_icon_background_color'))
          .onClick(() => {
            this.confirm?.(this.getParsedValue())
          })
        }
        .margin({ left: 8 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row({ space: 4 }) {
        Button(`-${this.coarseStepMs}`)
          .attributeModifier(new ButtonFancyModifier('', 36))
          .fontSize(this.quickBtnFontSize)
          .fontColor($r('app.color.text_color'))
          .layoutWeight(1)
          .backgroundColor($r('sys.color.titlebar_icon_background_color'))
          .padding({ left: 2, right: 2 })
          .onClick(() => {
            this.stepBy(-this.coarseStepMs)
          })

        Button(`-${this.fineStepMs}`)
          .fontSize(this.quickBtnFontSize)
          .attributeModifier(new ButtonFancyModifier('', 36))
          .fontColor($r('app.color.text_color'))
          .layoutWeight(1)
          .backgroundColor($r('sys.color.titlebar_icon_background_color'))
          .padding({ left: 2, right: 2 })
          .onClick(() => {
            this.stepBy(-this.fineStepMs)
          })

        Button($r('app.string.reset'))
          .fontSize(this.quickBtnFontSize)
          .fontColor($r('app.color.text_color'))
          .attributeModifier(new ButtonFancyModifier('', 36))
          .layoutWeight(1)
          .backgroundColor($r('sys.color.titlebar_icon_background_color'))
          .padding({ left: 2, right: 2 })
          .onClick(() => {
            this.resetValue()
          })

        Button(`+${this.fineStepMs}`)
          .fontSize(this.quickBtnFontSize)
          .fontColor($r('app.color.text_color'))
          .layoutWeight(1)
          .attributeModifier(new ButtonFancyModifier('', 36))
          .backgroundColor($r('sys.color.titlebar_icon_background_color'))
          .padding({ left: 2, right: 2 })
          .onClick(() => {
            this.stepBy(this.fineStepMs)
          })

        Button(`+${this.coarseStepMs}`)
          .fontSize(this.quickBtnFontSize)
          .fontColor($r('app.color.text_color'))
          .layoutWeight(1)
          .attributeModifier(new ButtonFancyModifier('', 36))
          .backgroundColor($r('sys.color.titlebar_icon_background_color'))
          .padding({ left: 2, right: 2 })
          .onClick(() => {
            this.stepBy(this.coarseStepMs)
          })
      }
      .width('100%')

      if (this.showSubtitleNavigation?.() ?? false) {
        Row({ space: 6 }) {
          Button($r('app.string.prev_subtitle'))
            .fontSize(this.quickBtnFontSize)
            .fontColor($r('app.color.text_color'))
            .layoutWeight(1)
            .backgroundColor($r('sys.color.titlebar_icon_background_color'))
            .attributeModifier(new ButtonFancyModifier('', 36))
            .padding({ left: 2, right: 2 })
            .onClick(() => {
              this.moveToPrevSubtitle()
            })

          Button($r('app.string.next_subtitle'))
            .fontSize(this.quickBtnFontSize)
            .fontColor($r('app.color.text_color'))
            .attributeModifier(new ButtonFancyModifier('', 36))
            .layoutWeight(1)
            .backgroundColor($r('sys.color.titlebar_icon_background_color'))
            .padding({ left: 2, right: 2 })
            .onClick(() => {
              this.moveToNextSubtitle()
            })
        }
        .width('100%')
      }
      if (this.helpText !== undefined) {
        Text(this.helpText)
          .fontSize(12)
          .fontColor($r('sys.color.font_secondary'))
      }
    }
    .padding({
      top: 10,
      bottom: 10,
      left: 15,
      right: 15
    })
  }

  private getCurrentValueForStep(): number {
    const currentInput = this.getParsedValue()
    if (!Number.isNaN(currentInput)) {
      return currentInput
    }
    return this.getCurrentValue ? this.getCurrentValue() : 0
  }

  private stepBy(delta: number): void {
    this.setOffsetValue(this.getCurrentValueForStep() + delta)
  }

  private resetValue(): void {
    this.inputText = '0'
    this.onOffsetPreview?.(0)
  }

  private setOffsetValue(nextOffset: number | undefined): void {
    if (nextOffset == undefined || Number.isNaN(nextOffset)) {
      return
    }
    const clamped = Math.max(this.minOffset, Math.min(this.maxOffset, nextOffset))
    this.inputText = clamped.toString()
    this.onOffsetPreview?.(clamped)
  }

  private moveToPrevSubtitle(): void {
    this.setOffsetValue(this.onPrevSubtitle?.(this.getCurrentValueForStep()))
  }

  private moveToNextSubtitle(): void {
    this.setOffsetValue(this.onNextSubtitle?.(this.getCurrentValueForStep()))
  }

  private getParsedValue(): number {
    const value = this.inputText.trim()
    if (value.length === 0 || value === '-' || value === '+') {
      return Number.NaN
    }
    return parseInt(value, 10)
  }
}
