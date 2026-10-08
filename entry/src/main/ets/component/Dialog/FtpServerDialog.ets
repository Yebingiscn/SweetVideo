import { util } from '@kit.ArkTS'
import { FtpServer } from '../../interfaces/FtpInterface'
import FtpUtil, { FtpRequest } from '../../utils/FtpUtil'
import FtpAddress from '../../utils/FtpAddress'
import ToolsUtil from '../../utils/ToolsUtil'
import { ButtonFancyModifier } from '../../common/AttributeModifierConfig'

@CustomDialog
export struct FtpServerDialog {
  controller?: CustomDialogController
  onSaved?: () => void
  @State name: string = ''
  @State address: string = ''
  @State user: string = ''
  @State password: string = ''
  @State busy: boolean = false
  @State message: string = ''
  private serverId: string = ''
  private active: boolean = false
  private request: FtpRequest | undefined = undefined

  async aboutToAppear(): Promise<void> {
    this.active = true
    const server = FtpUtil.editingServer
    this.serverId = server?.id ?? util.generateRandomUUID(true)
    this.name = server?.name ?? ''; this.address = server?.baseUrl ?? ''
    this.user = server?.user ?? ''; this.password = ''; this.message = ''
    if (server) {
      this.busy = true
      try {
        const password = await FtpUtil.password(server.id)
        if (this.active) this.password = password
      } catch (_) { if (this.active) this.message = ToolsUtil.getStringResource($r('app.string.reenter_password_save').id) }
      finally { if (this.active) this.busy = false }
    }
  }

  aboutToDisappear(): void {
    this.active = false
    this.request?.close()
    this.password = ''
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        Text(FtpUtil.editingServer ? $r('app.string.edit_ftp_server') : $r('app.string.add_ftp_server'))
          .fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_color')).width('100%')
        TextInput({ placeholder: $r('app.string.name_optional'), text: this.name }).height(44).borderRadius(16)
          .onChange((value: string) => this.name = value)
        TextArea({ placeholder: $r('app.string.ftp_address_placeholder'), text: this.address })
          .height(96).borderRadius(16).onChange((value: string) => this.address = value)
        TextInput({ placeholder: $r('app.string.ftp_user_placeholder'), text: this.user }).height(44).borderRadius(16)
          .onChange((value: string) => this.user = value)
        TextInput({ placeholder: $r('app.string.password_label'), text: this.password }).height(44).borderRadius(16)
          .type(InputType.Password).onChange((value: string) => this.password = value)
        Text($r('app.string.ftp_hint'))
          .fontSize(13).fontColor($r('app.color.text_color')).opacity(0.6).width('100%')
        if (this.message) {
          Text(this.message).fontSize(13).fontColor($r('app.color.text_color')).width('100%')
        }
        if (this.busy) { LoadingProgress().width(24).height(24) }
        Row({ space: 10 }) {
          Button($r('app.string.cancel')).layoutWeight(1).attributeModifier(new ButtonFancyModifier('', 44))
            .backgroundColor($r('sys.color.button_background_color_transparent'))
            .fontColor($r('app.color.text_color')).enabled(!this.busy)
            .onClick(() => this.controller?.close())
          Button($r('app.string.test')).layoutWeight(1).attributeModifier(new ButtonFancyModifier('', 44))
            .backgroundColor($r('app.color.sweet_music_color')).enabled(!this.busy)
            .onClick(() => this.run(false))
          Button($r('app.string.save')).layoutWeight(1).attributeModifier(new ButtonFancyModifier('', 44))
            .backgroundColor($r('app.color.main_color')).fontColor(Color.White).enabled(!this.busy)
            .onClick(() => this.run(true))
        }
      }.padding(20).width('100%')
    }.scrollBar(BarState.Off).constraintSize({ maxHeight: '90%' })
  }

  private async run(save: boolean): Promise<void> {
    if (this.busy) return
    this.busy = true; this.message = ''
    const request = new FtpRequest()
    this.request = request
    try {
      const baseUrl = FtpAddress.base(this.address)
      const server: FtpServer = { id: this.serverId, name: this.name.trim() || baseUrl,
        baseUrl: baseUrl, user: this.user.trim() }
      FtpAddress.credentials(server.user, this.password)
      if (save) {
        await FtpUtil.save(server, this.password)
        if (this.active) { this.onSaved?.(); this.controller?.close() }
      } else {
        await FtpUtil.list(server, '', this.password, request)
        if (this.active) this.message = ToolsUtil.getStringResource($r('app.string.ftp_connect_success').id)
      }
    } catch (error) {
      if (this.active) this.message = error instanceof Error ? error.message : ToolsUtil.getStringResource($r('app.string.ftp_operation_failed').id)
    } finally {
      request.close()
      if (this.request === request) this.request = undefined
      if (this.active) this.busy = false
    }
  }
}
