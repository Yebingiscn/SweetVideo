import { DialogButtonBar } from './DialogButtonBar'

@CustomDialog
export struct NumberInputDialog {
  confirm?: (name: number) => void
  controller?: CustomDialogController
  name: string | undefined = undefined
  title: string = ''
  input: number = 0
  placeholderColor: string = ''

  build() {
    Column({ space: 16 }) {
      Text(this.title)
        .fontSize(20)
        .fontColor($r('app.color.text_color'))
        .fontWeight(FontWeight.Bold)

      TextInput({ placeholder: this.placeholderColor })
        .keyboardAppearance(KeyboardAppearance.IMMERSIVE)
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
        .onChange((input: string) => this.input = parseInt(input))
        .inputFilter('^[-+]?\\d+$')
        .type(InputType.Number)
        .enableAutoFill(true)
        .id('input')
        .height(44)
        .width('100%')
        .borderRadius(16)
        .onAppear(() => {
          focusControl.requestFocus('input')
        })
        .maxLength(10)
        .maxLines(1)
        .enterKeyType(EnterKeyType.Done)

      DialogButtonBar(
        (): void => {
          this.controller?.close()
        },
        (): void => {
          this.controller?.close()
          this.confirm?.(this.input)
        }
      )
    }
    .padding(20)
  }
}
