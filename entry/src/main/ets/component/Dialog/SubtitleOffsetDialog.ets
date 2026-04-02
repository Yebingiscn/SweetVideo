@CustomDialog
export struct SubtitleOffsetDialog {
  confirm?: (value: number) => void
  controller?: CustomDialogController
  getCurrentValue?: () => number
  title: string = '外挂字幕偏移时间'
  @State inputText: string = ''
  inputController: TextInputController = new TextInputController()
  minOffset: number = -50000
  maxOffset: number = 50000
  inputId: string = 'subtitle_offset_input'
  quickBtnFontSize: number = 14

  aboutToAppear(): void {
    const currentOffset = this.getCurrentValue ? this.getCurrentValue() : 0
    this.inputText = currentOffset.toString()
  }

  private getCurrentValueForStep(): number {
    const currentInput = this.getParsedValue()
    if (!Number.isNaN(currentInput)) {
      return currentInput
    }
    return this.getCurrentValue ? this.getCurrentValue() : 0
  }

  private stepBy(delta: number): void {
    const nextValue = this.getCurrentValueForStep() + delta
    this.inputText = nextValue.toString()
  }

  private resetValue(): void {
    this.inputText = '0'
  }

  private getParsedValue(): number {
    const value = this.inputText.trim()
    if (value.length === 0 || value === '-' || value === '+') {
      return Number.NaN
    }
    return parseInt(value, 10)
  }

  build() {
    Column({ space: 8 }) {
      Text(this.title)
        .fontSize(20)
        .fontColor($r('app.color.text_color'))
        .fontWeight(FontWeight.Bold)
        .margin({ top: 0, bottom: 5 })

      Row() {
        TextInput({
          text: this.inputText,
          placeholder: `${this.getCurrentValue ? this.getCurrentValue() : 0}`,
          controller: this.inputController
        })
          .keyboardAppearance(KeyboardAppearance.IMMERSIVE)
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
          .onChange((input: string) => this.inputText = input.trim())
          .inputFilter('^[-+]?\\d*$')
          .type(InputType.NUMBER_DECIMAL)
          .enableAutoFill(true)
          .id(this.inputId)
          .height(36)
          .layoutWeight(1)
          .maxLength(10)
          .maxLines(1)
          .enterKeyType(EnterKeyType.Done)

        Row({ space: 6 }) {
          Button({ type: ButtonType.Normal, stateEffect: true }) {
            SymbolGlyph($r('sys.symbol.xmark'))
              .fontSize(16)
              .fontColor([$r('app.color.text_color')])
          }
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
          .backgroundColor($r('sys.color.titlebar_icon_background_color'))
          .borderRadius(16)
          .width(36)
          .height(36)
          .onClick(() => this.controller?.close())

          Button({ type: ButtonType.Normal, stateEffect: true }) {
            SymbolGlyph($r('sys.symbol.checkmark'))
              .fontSize(16)
              .fontColor([$r('app.color.text_color')])
          }
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
          .backgroundColor($r('sys.color.titlebar_icon_background_color'))
          .borderRadius(16)
          .width(36)
          .height(36)
          .onClick(() => {
            this.confirm?.(this.getParsedValue())
          })
        }
        .margin({ left: 8 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row({ space: 4 }) {
        Button('-1000')
          .fontSize(this.quickBtnFontSize)
          .fontColor($r('app.color.text_color'))
          .height(32)
          .layoutWeight(1)
          .backgroundColor($r('sys.color.titlebar_icon_background_color'))
          .borderRadius(12)
          .padding({ left: 2, right: 2 })
          .onClick(() => {
            this.stepBy(-1000)
          })

        Button('-100')
          .fontSize(this.quickBtnFontSize)
          .fontColor($r('app.color.text_color'))
          .height(32)
          .layoutWeight(1)
          .backgroundColor($r('sys.color.titlebar_icon_background_color'))
          .borderRadius(12)
          .padding({ left: 2, right: 2 })
          .onClick(() => {
            this.stepBy(-100)
          })

        Button('重置')
          .fontSize(this.quickBtnFontSize)
          .fontColor($r('app.color.text_color'))
          .height(32)
          .layoutWeight(1)
          .backgroundColor($r('sys.color.titlebar_icon_background_color'))
          .borderRadius(12)
          .padding({ left: 2, right: 2 })
          .onClick(() => {
            this.resetValue()
          })

        Button('+100')
          .fontSize(this.quickBtnFontSize)
          .fontColor($r('app.color.text_color'))
          .height(32)
          .layoutWeight(1)
          .backgroundColor($r('sys.color.titlebar_icon_background_color'))
          .borderRadius(12)
          .padding({ left: 2, right: 2 })
          .onClick(() => {
            this.stepBy(100)
          })

        Button('+1000')
          .fontSize(this.quickBtnFontSize)
          .fontColor($r('app.color.text_color'))
          .height(32)
          .layoutWeight(1)
          .backgroundColor($r('sys.color.titlebar_icon_background_color'))
          .borderRadius(12)
          .padding({ left: 2, right: 2 })
          .onClick(() => {
            this.stepBy(1000)
          })
      }
      .width('100%')
    }
    .padding({
      top: 10,
      bottom: 10,
      left: 15,
      right: 15
    })
  }
}
