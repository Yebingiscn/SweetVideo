import PrivacySpaceUtil from '../../utils/PrivacySpaceUtil'
import { DIALOG_TITLE_FONT_SIZE } from '../../common/Constants'
import { DialogButtonBar } from './DialogButtonBar'

@CustomDialog
export struct EditPasswordDialog {
  confirm?: (name: string | undefined) => void
  controller?: CustomDialogController
  passwd: string | undefined = undefined

  build() {
    Column({ space: 25 }) {
      Text(PrivacySpaceUtil.getPrivacyMode() ? '修改密码 (/▽＼)' : $r('app.string.set_passwd'))
        .fontSize(DIALOG_TITLE_FONT_SIZE)
        .fontColor($r('app.color.text_color'))
        .fontWeight(FontWeight.Bold)
        .margin({ top: 10 })
      TextInput()
        .keyboardAppearance(KeyboardAppearance.IMMERSIVE)
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
        .onChange((input: string) => this.passwd = input)
        .type(InputType.NEW_PASSWORD)
        .enableAutoFill(true)
        .id('input_pwd')
        .onAppear(() => {
          focusControl.requestFocus('input_pwd')
        })

      DialogButtonBar(
        () => {
          this.controller?.close()
        },
        () => {
          this.controller?.close()
          if (this.confirm) {
            this.confirm(this.passwd)
          }
        }
      )
    }.padding(20)
  }
}
