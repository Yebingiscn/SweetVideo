import { util } from '@kit.ArkTS'
import { SmbServer } from '../../interfaces/SmbInterface'
import SmbUtil from '../../utils/SmbUtil'
import SmbAddress from '../../utils/SmbAddress'
import ToolsUtil from '../../utils/ToolsUtil'
import { ButtonFancyModifier } from '../../common/AttributeModifierConfig'

@CustomDialog
export struct SmbServerDialog {
  controller?: CustomDialogController
  onSaved?: () => void
  @State name: string = ''
  @State host: string = ''
  @State port: string = '445'
  @State share: string = ''
  @State initialPath: string = ''
  @State user: string = ''
  @State password: string = ''
  @State domain: string = ''
  @State seal: boolean = false
  @State busy: boolean = false
  @State message: string = ''
  private serverId: string = ''
  private active: boolean = false

  async aboutToAppear(): Promise<void> {
    this.active = true
    const server = SmbUtil.editingServer
    this.serverId = server?.id ?? util.generateRandomUUID(true)
    this.name = server?.name ?? ''
    this.host = server?.host ?? ''
    this.port = `${server?.port ?? 445}`
    this.share = server?.share ?? ''
    this.initialPath = server?.initialPath ?? ''
    this.user = server?.user ?? ''
    this.domain = server?.domain ?? ''
    this.seal = server?.seal ?? false
    this.password = ''
    this.message = ''
    if (server) {
      this.busy = true
      try {
        const password = await SmbUtil.password(server.id)
        if (this.active) {
          this.password = password
        }
      } catch (error) {
        if (this.active) {
          this.message = ToolsUtil.getStringResource($r('app.string.reenter_password_save').id)
        }
      } finally {
        this.busy = false
      }
    }
  }

  aboutToDisappear(): void {
    this.active = false
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        Text(SmbUtil.editingServer ? $r('app.string.edit_smb_server') : $r('app.string.add_smb_server'))
          .fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_color')).width('100%')
        TextInput({ placeholder: $r('app.string.name_optional'), text: this.name }).height(44).borderRadius(16)
          .onChange((value: string) => this.name = value).clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
        TextArea({ placeholder: $r('app.string.smb_host_placeholder'), text: this.host }).height(96).borderRadius(16)
          .onChange((value: string) => this.host = value).onBlur(() => this.parseAddress())
        Row({ space: 10 }) {
          TextInput({ placeholder: $r('app.string.port'), text: this.port })
            .type(InputType.Number)
            .height(44)
            .borderRadius(16)
            .onChange((value: string) => this.port = value)
            .layoutWeight(1)
          TextInput({ placeholder: $r('app.string.smb_share_placeholder'), text: this.share }).height(44).borderRadius(16)
            .onChange((value: string) => this.share = value).layoutWeight(2)
        }.width('100%')

        TextInput({ placeholder: $r('app.string.initial_path_optional'), text: this.initialPath }).height(44).borderRadius(16)
          .onChange((value: string) => this.initialPath = value)
        TextInput({ placeholder: $r('app.string.smb_user_placeholder'), text: this.user }).height(44).borderRadius(16)
          .onChange((value: string) => this.user = value)
        TextInput({ placeholder: $r('app.string.password_label'), text: this.password }).height(44).borderRadius(16)
          .type(InputType.Password)
          .onChange((value: string) => this.password = value)
        TextInput({ placeholder: $r('app.string.smb_domain_placeholder'), text: this.domain }).height(44).borderRadius(16)
          .onChange((value: string) => this.domain = value)
        Row() {
          Text($r('app.string.smb3_encryption')).fontColor($r('app.color.text_color')).layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.seal })
            .onChange((value: boolean) => this.seal = value)
            .selectedColor($r('app.color.main_color'))
        }.width('100%')

        if (this.message) {
          Text(this.message).fontSize(13).fontColor($r('app.color.text_color')).width('100%')
        }
        if (this.busy) {
          LoadingProgress().width(24).height(24)
        }
        Row({ space: 10 }) {
          Button($r('app.string.cancel'))
            .layoutWeight(1)
            .attributeModifier(new ButtonFancyModifier('', 44))
            .backgroundColor($r('sys.color.button_background_color_transparent'))
            .fontColor($r('app.color.text_color'))
            .onClick(() => this.controller?.close())
          Button(this.busy ? $r('app.string.testing') : $r('app.string.test'))
            .layoutWeight(1)
            .attributeModifier(new ButtonFancyModifier('', 44))
            .backgroundColor($r('app.color.sweet_music_color'))
            .enabled(!this.busy)
            .onClick(() => this.run(false))
          Button(this.busy ? $r('app.string.saving') : $r('app.string.save'))
            .layoutWeight(1)
            .attributeModifier(new ButtonFancyModifier('', 44))
            .backgroundColor($r('app.color.main_color'))
            .fontColor(Color.White)
            .enabled(!this.busy)
            .onClick(() => this.run(true))
        }
      }.padding(20).width('100%')
    }.scrollBar(BarState.Off).constraintSize({ maxHeight: '90%' })
  }

  private applyAddress(): void {
    if (!SmbAddress.isSmb(this.host)) {
      return
    }
    const address = SmbAddress.parse(this.host)
    this.host = address.host
    this.port = `${address.port}`
    this.share = address.share || this.share
    this.initialPath = address.path
    if (address.hasUser) {
      this.user = address.user
      this.domain = address.domain
      if (address.hasPassword) this.password = address.password
    }
    this.message = ToolsUtil.getStringResource($r('app.string.smb_address_parsed').id)
  }

  private parseAddress(): void {
    try {
      this.applyAddress()
    } catch (error) {
      this.message = error instanceof Error ? error.message : ToolsUtil.getStringResource($r('app.string.invalid_smb_address').id)
    }
  }

  private server(): SmbServer {
    this.applyAddress()
    const host = this.host.trim()
    const share = this.share.trim()
    const port = Number(this.port)
    const login = SmbAddress.login(this.user, this.domain)
    if (!host || /[\s/\\?#@]/.test(host)) {
      throw new Error(ToolsUtil.getStringResource($r('app.string.smb_address_required').id))
    }
    if (!share || /[/\\]/.test(share) || share === '.' || share === '..') {
      throw new Error(
        ToolsUtil.getStringResource($r('app.string.smb_share_required').id))
    }
    if (!Number.isInteger(port) || port < 1 || port > 65535) {
      throw new Error(ToolsUtil.getStringResource($r('app.string.smb_port_invalid').id))
    }
    return {
      id: this.serverId,
      name: this.name.trim() || host,
      host: host,
      port: port,
      share: share,
      user: login.user,
      domain: login.domain,
      seal: this.seal,
      initialPath: SmbAddress.path(this.initialPath.trim())
    }
  }

  private async run(save: boolean): Promise<void> {
    if (this.busy) {
      return
    }
    this.busy = true
    this.message = ''
    try {
      const server = this.server()
      if (save) {
        await SmbUtil.save(server, this.password)
        if (!this.active) {
          return
        }
        this.onSaved?.()
        this.controller?.close()
      } else {
        await SmbUtil.list(server, server.initialPath ?? '', this.password)
        if (this.active) {
          this.message = ToolsUtil.getStringResource($r('app.string.smb_connect_success').id)
        }
      }
    } catch (error) {
      if (this.active) {
        this.message = error instanceof Error ? error.message : ToolsUtil.getStringResource($r('app.string.smb_operation_failed').id)
      }
    } finally {
      this.busy = false
    }
  }
}
