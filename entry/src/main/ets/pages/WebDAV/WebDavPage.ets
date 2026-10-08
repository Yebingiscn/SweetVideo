import { ListDisplayMode } from '../../common/enum/DisplayMode'
import { DefaultDialogShadow } from '../../common/AttributeModifierConfig'
import { InfoConfirmDialog } from '../../component/Dialog/InfoConfirmDialog'
import { WebDavServerDialog } from '../../component/Dialog/WebDavServerDialog'
import { WebDavEntry, WebDavServer } from '../../interfaces/WebDavInterface'
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import { SafeHeight, Setting } from '../../utils/ObservedUtil'
import RecentPlayUtil from '../../utils/RecentPlayUtil'
import WebDavUtil, { WebDavRequest } from '../../utils/WebDavUtil'
import WebDavAddress from '../../utils/WebDavAddress'
import SmbUtil from '../../utils/SmbUtil'
import ToolsUtil from '../../utils/ToolsUtil'
import VideoInfoUtil from '../../utils/VideoInfoUtil'
import { hdsMaterial, HdsNavDestination, HideMode, ScrollEffectType } from '@kit.UIDesignKit'
import { LengthMetrics } from '@kit.ArkUI'
import { SuppressWarnings, SuppressWarningsType } from '@kit.BasicServicesKit'

@ComponentV2
export struct WebDavPage {
  @Consumer('pathStack') pathStack: NavPathStack = new NavPathStack()
  @Local servers: WebDavServer[] = []
  @Local server: WebDavServer | undefined = undefined
  @Local entries: WebDavEntry[] = []
  @Local folder: string = ''
  @Local loading: boolean = false
  @Local error: string = ''
  @Local contentWidth: number = 360
  @Local directoryVersion: number = 0
  private request: WebDavRequest | undefined = undefined
  private allEntries: WebDavEntry[] = []
  private recentItems: Map<string, VideoMetadata> = new Map()
  private requestVersion: number = 0
  private pendingDelete: WebDavServer | undefined = undefined
  private scroller: Scroller = new Scroller()
  private dialog: CustomDialogController = new CustomDialogController({
    builder: WebDavServerDialog({ onSaved: () => this.reloadServers() }),
    cornerRadius: 20,
    shadow: DefaultDialogShadow,
    autoCancel: false
  })
  private deleteDialog: CustomDialogController = new CustomDialogController({
    builder: InfoConfirmDialog(
      { textInfo: $r('app.string.delete_webdav_connection'), confirm: () => this.removeServer() }),
    cornerRadius: 20, shadow: DefaultDialogShadow
  })

  aboutToAppear(): void {
    this.reloadServers()
  }

  aboutToDisappear(): void {
    this.requestVersion++
    this.request?.close()
  }

  private columns(): number {
    return Math.max(1, Math.floor(this.contentWidth / 500) +
      (Setting.listDisplayMode === ListDisplayMode.LIST_DISPLAY ? 1 : 2))
  }

  @Builder
  EntryCover(entry: WebDavEntry, list: boolean) {
    Stack() {
      SymbolGlyph(entry.directory ? $r('sys.symbol.folder') : $r('sys.symbol.play_round_triangle'))
        .fontSize(32).fontColor([$r('app.color.main_color')])
    }
    .width(list ? 112 : '100%')
    .aspectRatio(16 / 9)
    .backgroundColor($r('app.color.list_item_background')).borderRadius(12).clip(true)
  }

  @Builder
  EntryText(entry: WebDavEntry) {
    Column({ space: 6 }) {
      Text(entry.name).fontSize(16).fontColor($r('app.color.text_color'))
        .maxLines(Setting.listDisplayMode === ListDisplayMode.GRID_DISPLAY ? 1 : 3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(entry.directory ? $r('app.string.folder') : ToolsUtil.formatFileSize(entry.size))
        .fontSize(13).fontColor($r('app.color.text_color')).opacity(0.6)
    }.alignItems(HorizontalAlign.Start).width('100%')
  }

  @Builder
  EntryItem(entry: WebDavEntry, list: boolean) {
    if (list) {
      Row({ space: 12 }) {
        this.EntryCover(entry, true)
        Column() { this.EntryText(entry) }.layoutWeight(1)
      }.width('100%').padding(10).borderRadius(12)
      .backgroundColor($r('app.color.list_item_background'))
    } else {
      Column({ space: 8 }) {
        this.EntryCover(entry, false)
        Column() { this.EntryText(entry) }.padding({ left: 8, right: 8, bottom: 10 })
      }.width('100%').borderRadius(12).backgroundColor($r('app.color.list_item_background'))
    }
  }

  @Builder
  ServerMenu(server: WebDavServer) {
    Menu() {
      MenuItem({ content: $r('app.string.edit') }).onClick(() => this.edit(server))
      MenuItem({ content: $r('app.string.delete_connection') }).onClick(() => {
        this.pendingDelete = server
        this.deleteDialog.open()
      })
    }
  }

  @SuppressWarnings({ rules: [SuppressWarningsType.SYSCAP] })
  build() {
    HdsNavDestination() {
      Column({ space: 12 }) {
        if (this.server) {
          Row({ space: 12 }) {
            Button(this.folder ? $r('app.string.go_up') : $r('app.string.server')).onClick(() => this.back()).enabled(!this.loading)
            Text(`${this.server.name} / ${this.folder || ToolsUtil.getStringResource($r('app.string.root_folder').id)}`)
              .fontSize(14)
              .fontColor($r('app.color.text_color'))
              .layoutWeight(1)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Button($r('app.string.refresh')).onClick(() => this.browse(this.server!, this.folder)).enabled(!this.loading)
          }.width('100%').padding({ left: 16, right: 16 })
        }
        if (this.error) {
          Text(this.error).fontSize(14).fontColor($r('app.color.text_color')).padding(16).width('100%')
        }
        if (this.loading) {
          LoadingProgress().width(32).height(32)
        }
        if (!this.server && this.servers.length === 0) {
          Column({ space: 12 }) {
            Text($r('app.string.webdav_empty_title')).fontSize(18).fontColor($r('app.color.text_color'))
            Text($r('app.string.webdav_empty_desc'))
              .fontSize(14).fontColor($r('app.color.text_color')).opacity(0.6).textAlign(TextAlign.Center)
          }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center).padding(24)
        } else if (this.server && Setting.listDisplayMode !== ListDisplayMode.LIST_DISPLAY) {
          WaterFlow({ scroller: this.scroller, layoutMode: WaterFlowLayoutMode.SLIDING_WINDOW }) {
            Repeat<WebDavEntry>(this.entries).each((item: RepeatItem<WebDavEntry>) => {
              FlowItem() { this.EntryItem(item.item, false) }
                .onClick(() => this.select(item.item)).enabled(!this.loading)
            }).key((item: WebDavEntry) => `${this.directoryVersion}/${this.server?.id}/${this.folder}/${item.name}`).virtualScroll()
          }
          .columnsTemplate('1fr '.repeat(this.columns()).trim()).columnsGap(16).rowsGap(16)
          .width('100%').layoutWeight(1).padding({ left: 16, right: 16, bottom: SafeHeight.bottomSafeHeight })
          .scrollBar(BarState.Off)
          if (!this.loading && this.entries.length === 0) {
            Text($r('app.string.no_playable_files')).fontColor($r('app.color.text_color')).padding(24)
          }
        } else {
          List({ scroller: this.scroller, space: 10 }) {
            if (!this.server) {
              Repeat<WebDavServer>(this.servers)
                .each((item: RepeatItem<WebDavServer>) => {
                  ListItem() {
                    Row({ space: 14 }) {
                      SymbolGlyph($r('sys.symbol.folder')).fontSize(28).fontColor([$r('app.color.main_color')])
                      Column({ space: 6 }) {
                        Text(item.item.name).fontSize(17).fontColor($r('app.color.text_color'))
                        Text(`${item.item.baseUrl}`)
                          .fontSize(13)
                          .fontColor($r('app.color.text_color'))
                          .opacity(0.6)
                      }.layoutWeight(1).alignItems(HorizontalAlign.Start)

                      Button($r('app.string.edit')).onClick(() => this.edit(item.item))
                      SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(16)
                    }.padding(16).width('100%').backgroundColor($r('app.color.list_item_background')).borderRadius(16)
                  }.onClick(() => this.browse(item.item, '')).enabled(!this.loading)
                  .bindContextMenu(this.ServerMenu(item.item), ResponseType.LongPress)
                  .bindContextMenu(this.ServerMenu(item.item), ResponseType.RightClick)
                })
                .key((item: WebDavServer) => item.id).virtualScroll()
            } else {
              Repeat<WebDavEntry>(this.entries)
                .each((item: RepeatItem<WebDavEntry>) => {
                  ListItem() { this.EntryItem(item.item, true) }
                    .onClick(() => this.select(item.item)).enabled(!this.loading)
                })
                .key((item: WebDavEntry) => `${this.directoryVersion}/${this.server?.id}/${this.folder}/${item.name}`).virtualScroll()
              if (!this.loading && this.entries.length === 0) {
                ListItem() {
                  Text($r('app.string.no_playable_files')).fontColor($r('app.color.text_color')).padding(24)
                }
              }
            }
          }
          .clip(false)
          .lanes(this.server ? this.columns() : Math.max(1, Math.floor(this.contentWidth / 500) + 1))
          .layoutWeight(1)
          .height('100%')
          .width('100%')
          .padding({ left: 16, right: 16 })
          .contentEndOffset(SafeHeight.bottomSafeHeight)
          .scrollBar(BarState.Off)
        }
      }.width('100%').height('100%').clip(false)
      .onAreaChange((_old: Area, area: Area) => { this.contentWidth = Number(area.width) })
    }
    .titleBar({
      avoidLayoutSafeArea: true,
      enableComponentSafeArea: true,
      padding: { start: LengthMetrics.vp(5), end: LengthMetrics.vp(5) },
      style: {
        scrollEffectOpts: {
          enableScrollEffect: true,
          scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR,
          blurEffectiveStartOffset: LengthMetrics.vp(0),
          blurEffectiveEndOffset: LengthMetrics.vp(20)
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        },
        originalStyle: {
          backgroundStyle: {
            backgroundColor: $r('sys.color.ohos_id_color_background'),
          },
          contentStyle: {
            titleStyle: {
              mainTitleColor: $r('sys.color.font_primary'),
              subTitleColor: $r('sys.color.font_secondary')
            },
            menuStyle: {
              backgroundColor: $r('sys.color.comp_background_tertiary'),
              iconColor: $r('sys.color.icon_primary')
            },
            backIconStyle: {
              backgroundColor: $r('sys.color.comp_background_tertiary'),
              iconColor: $r('sys.color.icon_primary')
            }
          }
        },
        scrollEffectStyle: {
          backgroundStyle: {
            backgroundColor: $r('sys.color.ohos_id_color_background_transparent'),
          },
          contentStyle: {
            titleStyle: {
              mainTitleColor: $r('sys.color.font_primary'),
              subTitleColor: $r('sys.color.font_secondary')
            },
            menuStyle: {
              backgroundColor: $r('sys.color.comp_background_tertiary'),
              iconColor: $r('sys.color.icon_primary')
            },
            backIconStyle: {
              backgroundColor: $r('sys.color.comp_background_tertiary'),
              iconColor: $r('sys.color.icon_primary')
            }
          }
        }
      },
      content: {
        title: { mainTitle: 'WebDAV' }, menu: {
          value: [{
            content: {
              label: $r('app.string.add_server'),
              icon: $r('sys.symbol.plus'),
              isEnabled: !this.loading,
              action: () => this.edit()
            }
          }]
        }
      }
    })
    .backgroundImage(
      Setting.backgroundDropBlur > 0 && Setting.backgroundBlurImageSrc.length > 0 ? Setting.backgroundBlurImageSrc :
        Setting.backgroundImageSrc, ImageRepeat.NoRepeat)
    .backgroundImageSize(ImageSize.Cover)
    .backgroundImagePosition(Alignment.Center)
    .backgroundColor($r('app.color.start_window_background'))
    .bindToScrollable([this.scroller]) // 绑定导航组件和可滚动容器组件
    .dynamicHideTitleBar({
      hideTitleArea: false,
      hideBottomBuilder: true,
      hideStatusBar: false,
      mode: HideMode.SCROLL_UP
    })
    .onBackPressed(() => {
      if (this.loading) {
        this.requestVersion++
        this.request?.close()
        this.loading = false
        return true
      }
      if (this.server) {
        this.back();
        return true
      }
      return false
    })
    .onHidden(() => {
      this.requestVersion++
      this.request?.close()
      this.loading = false
    })
  }

  private reloadServers(): void {
    try {
      this.servers = WebDavUtil.servers()
    } catch (error) {
      this.error = ToolsUtil.getStringResource($r('app.string.read_servers_failed').id)
    }
  }

  private edit(server?: WebDavServer): void {
    WebDavUtil.editingServer = server
    this.dialog.open()
  }

  private async removeServer(): Promise<void> {
    const server = this.pendingDelete
    if (!server) {
      return
    }
    try {
      await WebDavUtil.remove(server.id)
      this.reloadServers()
    } catch (error) {
      this.error = ToolsUtil.getStringResource($r('app.string.delete_failed_retry').id)
    }
    this.pendingDelete = undefined
  }

  private async browse(server: WebDavServer, folder: string): Promise<void> {
    this.request?.close()
    const request = new WebDavRequest()
    this.request = request
    const version = ++this.requestVersion
    this.loading = true
    this.error = ''
    try {
      const entries = await WebDavUtil.list(server, folder, undefined, request)
      if (version !== this.requestVersion) {
        return
      }
      this.server = server
      this.directoryVersion++
      this.folder = folder
      this.allEntries = entries
      this.entries = entries.filter((entry: WebDavEntry) => entry.directory || SmbUtil.playable(entry.name))
      this.scroller.scrollTo({ xOffset: 0, yOffset: 0 })
    } catch (error) {
      if (version === this.requestVersion) {
        this.error = error instanceof Error ? error.message : ToolsUtil.getStringResource($r('app.string.read_webdav_failed').id)
      }
    } finally {
      request.close()
      if (version === this.requestVersion) {
        this.loading = false
      }
    }
  }

  private back(): void {
    if (this.server && this.folder) {
      const slash = this.folder.lastIndexOf('/')
      this.browse(this.server, slash < 0 ? '' : this.folder.substring(0, slash))
    } else {
      this.requestVersion++
      this.request?.close()
      this.server = undefined
      this.entries = []
      this.error = ''
      this.loading = false
    }
  }

  private async metadata(entry: WebDavEntry): Promise<VideoMetadata> {
    const server = this.server!
    const path = this.folder ? `${this.folder}/${entry.name}` : entry.name
    const uri = WebDavAddress.uri(server, path)
    const previous = this.recentItems.get(uri)
    const base = VideoInfoUtil.getVideoTitle(entry.name).toLowerCase()
    const subtitles = this.allEntries.filter((file: WebDavEntry) => {
      const lower = file.name.toLowerCase()
      const stem = VideoInfoUtil.splitFileName(lower).stem
      return !file.directory && file.size <= 8 * 1024 * 1024 && /\.(srt|ass|vtt)$/.test(lower) &&
        (stem === base || stem.startsWith(base + '.'))
    })
    const subtitle =
      subtitles.find((file: WebDavEntry) => VideoInfoUtil.splitFileName(file.name).stem.toLowerCase() === base) ??
        subtitles[0]
    const subtitlePath = subtitle ? (this.folder ? `${this.folder}/${subtitle.name}` : subtitle.name) : ''
    const metadata = previous ?? VideoInfoUtil.buildNetworkVideoMetadata(uri, await WebDavUtil.fileId(uri), entry.name,
      ToolsUtil.formatFileSize(entry.size), [1, 1])
    metadata.webdav_subtitle_uri = subtitle ? WebDavAddress.uri(server, subtitlePath) : undefined
    metadata.external_subtitle_format = subtitle ? VideoInfoUtil.getExtension(subtitle.name) : ''
    return metadata
  }

  private async select(entry: WebDavEntry): Promise<void> {
    if (!this.server || this.loading) {
      return
    }
    if (entry.directory) {
      await this.browse(this.server, this.folder ? `${this.folder}/${entry.name}` : entry.name)
      return
    }
    const version = ++this.requestVersion
    const server = this.server
    const folder = this.folder
    this.loading = true
    try {
      this.recentItems.clear()
      RecentPlayUtil.getRecentPlaybacks().forEach((file: VideoMetadata) => this.recentItems.set(file.uri, file))
      const list = await Promise.all(this.entries.filter((file: WebDavEntry) => !file.directory)
        .map((file: WebDavEntry) => this.metadata(file)))
      if (version !== this.requestVersion) {
        return
      }
      const selectedPath = folder ? `${folder}/${entry.name}` : entry.name
      const item = list.find((file: VideoMetadata) => file.uri === WebDavAddress.uri(server, selectedPath))!
      await ToolsUtil.routerWhere(this.pathStack, item, list)
    } catch (error) {
      if (version === this.requestVersion) {
        this.error = error instanceof Error ? error.message : ToolsUtil.getStringResource($r('app.string.open_video_failed').id)
      }
    } finally {
      if (version === this.requestVersion) {
        this.loading = false
      }
    }
  }

}
