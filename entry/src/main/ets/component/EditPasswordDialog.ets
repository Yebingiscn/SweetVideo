@CustomDialog
export struct editPasswordDialog { //编辑元数据弹窗
  confirm?: (name: string | undefined) => void
  controller?: CustomDialogController
  passwd: string | undefined = undefined
  @State passwordState: boolean = false

  build() {
    Column({ space: 25 }) {
      Text($r('app.string.set_passwd'))
        .fontSize(25)
        .fontColor($r('app.color.text_color'))
        .fontWeight(FontWeight.Bold)
        .margin({ top: 10 })
      TextInput()
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
        .onChange((input: string) => this.passwd = input)
        .showPassword(this.passwordState)
        .type(InputType.Password)
        .showPasswordIcon(true)
        .onSecurityStateChange((isShowPassword: boolean) => {
          this.passwordState = isShowPassword
        })
        .id('input_pwd')
        .onAppear(() => {
          focusControl.requestFocus('input_pwd')
        })

      Flex({ justifyContent: FlexAlign.SpaceAround }) {
        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Row({ space: 5 }) {
            SymbolGlyph($r('sys.symbol.xmark')).fontSize(18).fontColor([$r('app.color.text_color')])
            Text($r('app.string.cancel'))
              .fontSize(18)
              .fontColor($r('app.color.text_color'))
              .fontWeight(FontWeight.Medium)
          }.alignItems(VerticalAlign.Center).padding({ left: 12, right: 12 })
        }
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
        .backgroundColor('#00000000')
        .borderRadius(8)
        .height(40)
        .onClick(() => this.controller?.close())

        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Row({ space: 5 }) {
            SymbolGlyph($r('sys.symbol.checkmark')).fontSize(18).fontColor([$r('app.color.text_color')])
            Text($r('app.string.sure')).fontSize(18).fontColor($r('app.color.text_color')).fontWeight(FontWeight.Medium)
          }.alignItems(VerticalAlign.Center).padding({ left: 12, right: 12 })
        }
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
        .backgroundColor('#00000000')
        .borderRadius(8)
        .height(40)
        .onClick(() => {
          this.controller?.close()
          if (this.confirm) {
            this.confirm(this.passwd)
          }
        })
      }.margin({ bottom: 10 })
    }.padding(20)
  }
}