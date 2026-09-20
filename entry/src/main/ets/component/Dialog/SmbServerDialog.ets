import { util } from '@kit.ArkTS'
import { SmbServer } from '../../interfaces/SmbInterface'
import SmbUtil from '../../utils/SmbUtil'
import SmbAddress from '../../utils/SmbAddress'
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
          this.message = '请重新输入密码后保存'
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
        Text(SmbUtil.editingServer ? '编辑 SMB 服务器' : '添加 SMB 服务器')
          .fontSize(20).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_color')).width('100%')
        TextInput({ placeholder: '名称（可选）', text: this.name }).height(44).borderRadius(16)
          .onChange((value: string) => this.name = value).clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
        TextArea({ placeholder: 'IP、主机名或 smb://服务器/共享/目录', text: this.host }).height(72).borderRadius(16)
          .onChange((value: string) => this.host = value).onBlur(() => this.parseAddress())
        Row({ space: 10 }) {
          TextInput({ placeholder: '端口', text: this.port })
            .type(InputType.Number)
            .height(44)
            .borderRadius(16)
            .onChange((value: string) => this.port = value)
            .layoutWeight(1)
          TextInput({ placeholder: '共享名，例如 Movies', text: this.share }).height(44).borderRadius(16)
            .onChange((value: string) => this.share = value).layoutWeight(2)
        }.width('100%')

        TextInput({ placeholder: '起始目录（可选）', text: this.initialPath }).height(44).borderRadius(16)
          .onChange((value: string) => this.initialPath = value)
        TextInput({ placeholder: '用户名（访客访问可留空）', text: this.user }).height(44).borderRadius(16)
          .onChange((value: string) => this.user = value)
        TextInput({ placeholder: '密码', text: this.password }).height(44).borderRadius(16)
          .type(InputType.Password)
          .onChange((value: string) => this.password = value)
        TextInput({ placeholder: '域 / 工作组（可选）', text: this.domain }).height(44).borderRadius(16)
          .onChange((value: string) => this.domain = value)
        Row() {
          Text('要求 SMB3 加密').fontColor($r('app.color.text_color')).layoutWeight(1)
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
          Button('取消')
            .layoutWeight(1)
            .attributeModifier(new ButtonFancyModifier('', 44))
            .backgroundColor($r('sys.color.button_background_color_transparent'))
            .fontColor($r('app.color.text_color'))
            .onClick(() => this.controller?.close())
          Button(this.busy ? '测试中…' : '测试')
            .layoutWeight(1)
            .attributeModifier(new ButtonFancyModifier('', 44))
            .backgroundColor($r('app.color.sweet_music_color'))
            .enabled(!this.busy)
            .onClick(() => this.run(false))
          Button(this.busy ? '保存中…' : '保存')
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
      this.password = address.password
    }
    this.message = '已解析 SMB 地址，可继续填写或修改连接信息'
  }

  private parseAddress(): void {
    try {
      this.applyAddress()
    } catch (error) {
      this.message = error instanceof Error ? error.message : 'SMB 地址无效'
    }
  }

  private server(): SmbServer {
    this.applyAddress()
    const host = this.host.trim()
    const share = this.share.trim()
    const port = Number(this.port)
    if (!host || /[\s/\\?#@]/.test(host)) {
      throw new Error('请输入有效的 IP、主机名或 smb:// 地址')
    }
    if (!share || /[/\\]/.test(share) || share === '.' || share === '..') {
      throw new Error(
        '请输入共享名，例如 Movies；子目录可在连接后浏览')
    }
    if (!Number.isInteger(port) || port < 1 || port > 65535) {
      throw new Error('端口应为 1–65535，默认 445')
    }
    return {
      id: this.serverId,
      name: this.name.trim() || host,
      host: host,
      port: port,
      share: share,
      user: this.user.trim(),
      domain: this.domain.trim(),
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
          this.message = '连接成功，可以访问共享目录'
        }
      }
    } catch (error) {
      if (this.active) {
        this.message = error instanceof Error ? error.message : '操作失败，请检查连接或安全存储设置'
      }
    } finally {
      this.busy = false
    }
  }
}
