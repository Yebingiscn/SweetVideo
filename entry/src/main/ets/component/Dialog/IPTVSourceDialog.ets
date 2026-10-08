import { fileIo as fs, picker } from '@kit.CoreFileKit'
import { CapsuleSegmentButtonV2, ColorMetrics, SegmentButtonV2ItemOptions, SegmentButtonV2Items } from '@kit.ArkUI'
import { IPTVSource, IPTVSourceType } from '../../interfaces/IPTVInterface'
import IPTVUtil from '../../utils/IPTVUtil'
import { PathUtils } from '../../utils/PathUtils'
import PermissionUtil from '../../utils/PermissionUtil'
import ToolsUtil from '../../utils/ToolsUtil'
import { salmonLogger } from 'salmonlogger'
import { ButtonFancyModifier } from '../../common/AttributeModifierConfig'

@CustomDialog
export struct IPTVSourceDialog {
  controller?: CustomDialogController = undefined
  @State sourceName: string = ''
  @State sourceType: IPTVSourceType = 'url'
  @State location: string = ''
  @State fileName: string = ''
  @State userAgent: string = ''
  @State epgUrl: string = ''
  @State testing: boolean = false
  @State saving: boolean = false
  @State testMessage: string = ''
  @State testSuccess: boolean = false
  onSaved?: (source: IPTVSource) => void
  private preparedSource: IPTVSource | undefined = undefined
  private preparedSignature: string = ''
  private segmentItems: SegmentButtonV2Items = new SegmentButtonV2Items([
    { text: 'URL' } as SegmentButtonV2ItemOptions,
    { text: ToolsUtil.getStringResource($r('app.string.local_file').id) } as SegmentButtonV2ItemOptions
  ])
  private itemSelectedBackgroundColor: ColorMetrics | undefined = undefined
  private itemSelectedFontColor: ColorMetrics | undefined = undefined

  private static fileDisplayName(uri: string): string {
    try {
      const file = fs.openSync(uri, fs.OpenMode.READ_ONLY)
      const name = file.name
      fs.closeSync(file)
      return name
    } catch (_error) {
      return ToolsUtil.fileNameFromUri(uri)
    }
  }

  aboutToAppear(): void {
    const editing = IPTVUtil.editingSource
    if (editing) {
      this.sourceName = editing.name
      this.sourceType = editing.sourceType
      this.location = editing.location
      this.fileName = editing.sourceType === 'file' ? IPTVSourceDialog.fileDisplayName(editing.location) : ''
      this.userAgent = editing.userAgent ?? ''
      this.epgUrl = editing.epgUrl ?? ''
    } else {
      this.sourceName = ''
      this.sourceType = 'url'
      this.location = ''
      this.fileName = ''
      this.userAgent = ''
      this.epgUrl = ''
    }
    this.testMessage = ''
    this.testSuccess = false
    this.preparedSource = undefined
    this.preparedSignature = ''
    try {
      this.itemSelectedBackgroundColor = ColorMetrics.resourceColor($r('app.color.main_color'))
      this.itemSelectedFontColor = ColorMetrics.resourceColor($r('sys.color.white'))
    } catch (error) {
      salmonLogger.addLog('ColorMetrics ERROR')
    }
  }

  build() {
    Scroll() {
      Column({ space: 16 }) {
        Text(IPTVUtil.editingSource ? $r('app.string.edit_iptv_source') : $r('app.string.add_iptv_source'))
          .fontSize(20)
          .fontColor($r('app.color.text_color'))
          .fontWeight(FontWeight.Bold)
          .width('100%')

        CapsuleSegmentButtonV2({
          items: this.segmentItems,
          selectedIndex: this.sourceType === 'url' ? 0 : 1,
          buttonBackgroundBlurStyle: BlurStyle.BACKGROUND_THICK,
          itemSelectedFontColor: this.itemSelectedFontColor,
          itemSelectedBackgroundColor: this.itemSelectedBackgroundColor,
          onItemClicked: (index: number) => {
            this.switchType(index === 0 ? 'url' : 'file')
          }
        })
          .width('100%')


        TextInput({ placeholder: $r('app.string.iptv_source_name'), text: this.sourceName })
          .height(44)
          .borderRadius(16)
          .onChange((value: string) => {
            this.sourceName = value
            this.invalidatePreparedSource()
          })
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })

        if (this.sourceType === 'url') {
          TextArea({ placeholder: $r('app.string.iptv_source_url'), text: this.location })
            .borderRadius(16)
            .height(96)
            .onChange((value: string) => {
              this.location = value
              this.invalidatePreparedSource()
            })
            .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
        } else {
          Button({ type: ButtonType.Normal, stateEffect: true }) {
            Row() {
              SymbolGlyph($r('sys.symbol.doc_plaintext'))
                .fontSize(22)
                .margin({ left: 10 })
                .fontColor([$r('app.color.text_color')])
              Text(this.fileName || ToolsUtil.getStringResource($r('app.string.select_iptv_file').id))
                .fontSize(15)
                .fontColor($r('app.color.text_color'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .margin({ left: 10 })
            }.width('100%')
          }
          .attributeModifier(new ButtonFancyModifier('100%', 40))
          .backgroundColor($r('sys.color.button_background_color_transparent'))
          .onClick(async () => await this.selectFile())
        }

        TextInput({ placeholder: $r('app.string.user_agent_optional'), text: this.userAgent })
          .height(44)
          .borderRadius(16)
          .onChange((value: string) => {
            this.userAgent = value
            this.invalidatePreparedSource()
          })
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })

        TextInput({ placeholder: $r('app.string.epg_url_optional'), text: this.epgUrl })
          .height(44)
          .borderRadius(16)
          .onChange((value: string) => {
            this.epgUrl = value
            this.invalidatePreparedSource()
          })
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })

        if (this.testMessage) {
          Text(this.testMessage)
            .fontSize(13)
            .fontColor(this.testSuccess ? '#2E7D32' : '#C62828')
            .width('100%')
            .padding(12)
            .backgroundColor($r('app.color.list_item_background'))
            .borderRadius(12)
        }

        Row({ space: 10 }) {
          Button($r('app.string.cancel'))
            .layoutWeight(1)
            .attributeModifier(new ButtonFancyModifier('', 44))
            .backgroundColor($r('sys.color.button_background_color_transparent'))
            .fontColor($r('app.color.text_color'))
            .onClick(() => this.closeDialog())
          Button(this.testing ? $r('app.string.testing') : $r('app.string.test'))
            .layoutWeight(1)
            .attributeModifier(new ButtonFancyModifier('', 44))
            .backgroundColor($r('app.color.sweet_music_color'))
            .enabled(!this.testing && !this.saving)
            .onClick(async () => await this.test())
          Button(this.saving ? $r('app.string.saving') : $r('app.string.save'))
            .layoutWeight(1)
            .attributeModifier(new ButtonFancyModifier('', 44))
            .backgroundColor($r('app.color.main_color'))
            .fontColor(Color.White)
            .enabled(!this.testing && !this.saving)
            .onClick(async () => await this.save())
        }.width('100%')
      }
      .padding(20)
      .width('100%')
    }
    .scrollBar(BarState.Off)
    .constraintSize({ maxHeight: '90%' })
  }

  private switchType(type: IPTVSourceType): void {
    if (this.sourceType === type) {
      return
    }
    this.sourceType = type
    this.location = ''
    this.fileName = ''
    this.invalidatePreparedSource()
  }

  private async selectFile(): Promise<void> {
    const options = new picker.DocumentSelectOptions()
    options.maxSelectNumber = 1
    options.fileSuffixFilters = [ToolsUtil.getStringResource($r('app.string.iptv_source_filter').id) + '|.m3u,.m3u8,.txt', 'm3u', 'm3u8', 'txt']
    try {
      const uris = await new picker.DocumentViewPicker(PathUtils.appContext!).select(options)
      if (uris.length > 0) {
        this.location = uris[0]
        this.fileName = IPTVSourceDialog.fileDisplayName(uris[0])
        await PermissionUtil.persistPermission(uris[0])
        this.invalidatePreparedSource()
      }
    } catch (_error) {
    }
  }

  private buildSource(): IPTVSource | undefined {
    const name = this.sourceName.trim()
    const location = this.location.trim()
    if (!name || !location) {
      ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.iptv_fill_required').id))
      return undefined
    }
    const editing = IPTVUtil.editingSource
    const now = Date.now()
    return {
      id: editing?.id ?? `iptv_${now}`,
      name: name,
      sourceType: this.sourceType,
      location: location,
      userAgent: this.userAgent.trim() || undefined,
      epgUrl: this.epgUrl.trim() || undefined,
      channels: editing?.channels ?? [],
      channelCount: editing?.channelCount ?? 0,
      groupCount: editing?.groupCount ?? 0,
      createdTime: editing?.createdTime ?? now,
      updatedTime: now,
      lastRefreshTime: editing?.lastRefreshTime,
      lastEpgRefreshTime: editing?.lastEpgRefreshTime,
      lastRefreshStatus: editing?.lastRefreshStatus ?? 'idle',
      lastError: editing?.lastError,
      epgMatchedCount: editing?.epgMatchedCount
    }
  }

  private async test(): Promise<void> {
    const source = this.buildSource()
    if (!source) {
      return
    }
    this.testing = true
    this.testMessage = ToolsUtil.getStringResource($r('app.string.iptv_parsing_source').id)
    const result = await IPTVUtil.testSource(source)
    this.testSuccess = result.success
    if (result.success && result.preparedSource) {
      this.preparedSource = result.preparedSource
      this.preparedSignature = this.sourceSignature(source)
    } else {
      this.preparedSource = undefined
      this.preparedSignature = ''
    }
    this.testMessage = result.message + (result.invalidCount > 0 ? ToolsUtil.getStringResourceArgs($r('app.string.iptv_invalid_count').id, result.invalidCount) : '') +
      (source.epgUrl ? ToolsUtil.getStringResourceArgs($r('app.string.iptv_epg_matched').id, result.epgMatchedCount) : '')
    this.testing = false
  }

  private async save(): Promise<void> {
    const source = this.buildSource()
    if (!source) {
      return
    }
    this.saving = true
    this.testMessage = ToolsUtil.getStringResource($r('app.string.iptv_saving_channels').id)
    try {
      const signature = this.sourceSignature(source)
      const saved = this.preparedSource && this.preparedSignature === signature ?
        this.preparedSource : await IPTVUtil.refreshSource(source)
      this.onSaved?.(saved)
      ToolsUtil.showToast(ToolsUtil.getStringResourceArgs($r('app.string.iptv_added_channels').id, saved.channelCount))
      this.closeDialog()
    } catch (error) {
      this.testSuccess = false
      this.testMessage = error instanceof Error ? error.message : String(error)
    } finally {
      this.saving = false
    }
  }

  private closeDialog(): void {
    this.preparedSource = undefined
    this.preparedSignature = ''
    IPTVUtil.editingSource = undefined
    this.controller?.close()
  }

  private invalidatePreparedSource(): void {
    this.preparedSource = undefined
    this.preparedSignature = ''
    this.testMessage = ''
    this.testSuccess = false
  }

  private sourceSignature(source: IPTVSource): string {
    return JSON.stringify([
      source.id,
      source.name,
      source.sourceType,
      source.location,
      source.userAgent ?? '',
      source.epgUrl ?? ''
    ])
  }
}
