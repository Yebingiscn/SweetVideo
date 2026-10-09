import ImageStorage from '../../utils/ImageStorage'
import { smbClose, SmbEntry } from 'libmpvnative.so'
import { fileIo as fs } from '@kit.CoreFileKit'
import { ListDisplayMode } from '../../common/enum/DisplayMode'
import { PathUtils } from '../../utils/PathUtils'
import FFmpegThumbnailUtil from '../../utils/FFmpegThumbnailUtil'
import { salmonLogger } from 'salmonlogger'
import { DefaultDialogShadow } from '../../common/AttributeModifierConfig'
import { InfoConfirmDialog } from '../../component/Dialog/InfoConfirmDialog'
import { SmbServerDialog } from '../../component/Dialog/SmbServerDialog'
import { SmbServer } from '../../interfaces/SmbInterface'
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import { SafeHeight, Setting } from '../../utils/ObservedUtil'
import RecentPlayUtil from '../../utils/RecentPlayUtil'
import SmbUtil from '../../utils/SmbUtil'
import ToolsUtil from '../../utils/ToolsUtil'
import VideoInfoUtil from '../../utils/VideoInfoUtil'
import { hdsMaterial, HdsNavDestination, HideMode, ScrollEffectType } from '@kit.UIDesignKit'
import { LengthMetrics } from '@kit.ArkUI'
import { SuppressWarnings, SuppressWarningsType } from '@kit.BasicServicesKit'

@ComponentV2
export struct SmbPage {
  @Consumer('pathStack') pathStack: NavPathStack = new NavPathStack()
  @Local servers: SmbServer[] = []
  @Local server: SmbServer | undefined = undefined
  @Local entries: SmbEntry[] = []
  @Local folder: string = ''
  @Local loading: boolean = false
  @Local error: string = ''
  @Local contentWidth: number = 360
  @Local directoryVersion: number = 0
  @Local covers: Record<string, string> = {}
  @Local coverRatios: Record<string, number> = {}
  private thumbnailVersion: number = 0
  private thumbnailRunning: boolean = false
  private thumbnailQueue: SmbEntry[] = []
  private thumbnailVisible: Set<string> = new Set()
  private thumbnailAttempted: Set<string> = new Set()
  private thumbnailUrl: string = ''
  private thumbnailActive: boolean = true
  private allEntries: SmbEntry[] = []
  private recentItems: Map<string, VideoMetadata> = new Map()
  private requestVersion: number = 0
  private pendingDelete: SmbServer | undefined = undefined
  private scroller: Scroller = new Scroller()
  private dialog: CustomDialogController = new CustomDialogController({
    builder: SmbServerDialog({ onSaved: () => this.reloadServers() }),
    cornerRadius: 20,
    shadow: DefaultDialogShadow,
    autoCancel: false
  })
  private deleteDialog: CustomDialogController = new CustomDialogController({
    builder: InfoConfirmDialog(
      { textInfo: $r('app.string.delete_smb_connection'), confirm: () => this.removeServer() }),
    cornerRadius: 20, shadow: DefaultDialogShadow
  })

  aboutToAppear(): void {
    this.reloadServers()
  }

  aboutToDisappear(): void {
    this.requestVersion++
    this.stopThumbnails()
  }

  private columns(): number {
    return Math.max(1, Math.floor(this.contentWidth / 500) +
      (Setting.listDisplayMode === ListDisplayMode.LIST_DISPLAY ? 1 : 2))
  }

  @Builder
  EntryCover(entry: SmbEntry, list: boolean) {
    Stack() {
      SymbolGlyph(entry.directory ? $r('sys.symbol.folder') : $r('sys.symbol.play_round_triangle'))
        .fontSize(32).fontColor([$r('app.color.main_color')])
      if (!entry.directory && this.covers[entry.name]) {
        Image(this.covers[entry.name]).width('100%').height('100%').objectFit(ImageFit.Cover)
          .onComplete((event) => {
            if (event && event.width > 0 && event.height > 0) {
              const ratio = Math.max(0.6, Math.min(2.4, event.width / event.height))
              if (this.coverRatios[entry.name] !== ratio) {
                const ratios: Record<string, number> = {}
                Object.keys(this.coverRatios).forEach((key: string) => { ratios[key] = this.coverRatios[key] })
                ratios[entry.name] = ratio
                this.coverRatios = ratios
              }
            }
          })
      }
    }
    .width(list ? 112 : '100%')
    .aspectRatio(list || Setting.listDisplayMode === ListDisplayMode.GRID_DISPLAY ? 16 / 9 :
      (this.coverRatios[entry.name] ?? 16 / 9))
    .backgroundColor($r('app.color.list_item_background')).borderRadius(12).clip(true)
  }

  @Builder
  EntryText(entry: SmbEntry) {
    Column({ space: 6 }) {
      Text(entry.name).fontSize(16).fontColor($r('app.color.text_color'))
        .maxLines(Setting.listDisplayMode === ListDisplayMode.GRID_DISPLAY ? 1 : 3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(entry.directory ? $r('app.string.folder') : ToolsUtil.formatFileSize(entry.size))
        .fontSize(13).fontColor($r('app.color.text_color')).opacity(0.6)
    }.alignItems(HorizontalAlign.Start).width('100%')
  }

  @Builder
  EntryItem(entry: SmbEntry, list: boolean) {
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
  ServerMenu(server: SmbServer) {
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
            Text(`${this.server.name} / ${this.server.share}${this.folder ? '/' + this.folder : ''}`)
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
            Text($r('app.string.smb_empty_title')).fontSize(18).fontColor($r('app.color.text_color'))
            Text($r('app.string.smb_empty_desc'))
              .fontSize(14).fontColor($r('app.color.text_color')).opacity(0.6).textAlign(TextAlign.Center)
          }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center).padding(24)
        } else if (this.server && Setting.listDisplayMode !== ListDisplayMode.LIST_DISPLAY) {
          WaterFlow({ scroller: this.scroller, layoutMode: WaterFlowLayoutMode.SLIDING_WINDOW }) {
            Repeat<SmbEntry>(this.entries).each((item: RepeatItem<SmbEntry>) => {
              FlowItem() { this.EntryItem(item.item, false) }
                .onClick(() => this.select(item.item)).enabled(!this.loading)
                .onVisibleAreaChange([0], (visible: boolean) => this.thumbnailVisibility(item.item, visible))
            }).key((item: SmbEntry) => `${this.directoryVersion}/${this.server?.id}/${this.folder}/${item.name}`).virtualScroll()
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
              Repeat<SmbServer>(this.servers)
                .each((item: RepeatItem<SmbServer>) => {
                  ListItem() {
                    Row({ space: 14 }) {
                      SymbolGlyph($r('sys.symbol.folder')).fontSize(28).fontColor([$r('app.color.main_color')])
                      Column({ space: 6 }) {
                        Text(item.item.name).fontSize(17).fontColor($r('app.color.text_color'))
                        Text(`${item.item.host} / ${item.item.share}`)
                          .fontSize(13)
                          .fontColor($r('app.color.text_color'))
                          .opacity(0.6)
                      }.layoutWeight(1).alignItems(HorizontalAlign.Start)

                      Button($r('app.string.edit')).onClick(() => this.edit(item.item))
                      SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(16)
                    }.padding(16).width('100%').backgroundColor($r('app.color.list_item_background')).borderRadius(16)
                  }.onClick(() => this.browse(item.item, item.item.initialPath ?? '')).enabled(!this.loading)
                  .bindContextMenu(this.ServerMenu(item.item), ResponseType.LongPress)
                  .bindContextMenu(this.ServerMenu(item.item), ResponseType.RightClick)
                })
                .key((item: SmbServer) => item.id).virtualScroll()
            } else {
              Repeat<SmbEntry>(this.entries)
                .each((item: RepeatItem<SmbEntry>) => {
                  ListItem() { this.EntryItem(item.item, true) }
                    .onClick(() => this.select(item.item)).enabled(!this.loading)
                    .onVisibleAreaChange([0], (visible: boolean) => this.thumbnailVisibility(item.item, visible))
                })
                .key((item: SmbEntry) => `${this.directoryVersion}/${this.server?.id}/${this.folder}/${item.name}`).virtualScroll()
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
        title: { mainTitle: 'SMB' }, menu: {
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
        this.loading = false
        return true
      }
      if (this.server) {
        this.back();
        return true
      }
      return false
    })
    .onHidden(() => this.stopThumbnails())
    .onShown(() => {
      this.thumbnailActive = true
      this.entries.forEach((entry: SmbEntry) => {
        if (!this.covers[entry.name]) this.thumbnailAttempted.delete(entry.name)
        if (this.thumbnailVisible.has(entry.name)) this.thumbnailVisibility(entry, true)
      })
    })
  }

  private reloadServers(): void {
    try {
      this.servers = SmbUtil.servers()
    } catch (error) {
      this.error = ToolsUtil.getStringResource($r('app.string.read_servers_failed').id)
    }
  }

  private edit(server?: SmbServer): void {
    SmbUtil.editingServer = server
    this.dialog.open()
  }

  private async removeServer(): Promise<void> {
    const server = this.pendingDelete
    if (!server) {
      return
    }
    try {
      await SmbUtil.remove(server.id)
      this.reloadServers()
    } catch (error) {
      this.error = ToolsUtil.getStringResource($r('app.string.delete_failed_retry').id)
    }
    this.pendingDelete = undefined
  }

  private async browse(server: SmbServer, folder: string): Promise<void> {
    const version = ++this.requestVersion
    this.loading = true
    this.error = ''
    try {
      const entries = await SmbUtil.list(server, folder)
      if (version !== this.requestVersion) {
        return
      }
      this.server = server
      this.stopThumbnails()
      this.thumbnailActive = true
      this.thumbnailVisible.clear()
      this.thumbnailAttempted.clear()
      this.covers = {}
      this.coverRatios = {}
      this.directoryVersion++
      this.folder = folder
      this.allEntries = entries
      this.entries = entries.filter((entry: SmbEntry) => entry.directory || SmbUtil.playable(entry.name))
      this.scroller.scrollTo({ xOffset: 0, yOffset: 0 })
    } catch (error) {
      if (version === this.requestVersion) {
        this.error = error instanceof Error ? error.message : ToolsUtil.getStringResource($r('app.string.read_share_failed').id)
      }
    } finally {
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
      this.stopThumbnails()
      this.server = undefined
      this.entries = []
      this.error = ''
      this.loading = false
    }
  }

  private async metadata(entry: SmbEntry): Promise<VideoMetadata> {
    const server = this.server!
    const path = this.folder ? `${this.folder}/${entry.name}` : entry.name
    const uri = SmbUtil.uri(server, path)
    const previous = this.recentItems.get(uri)
    if (previous) {
      return previous
    }
    const base = VideoInfoUtil.getVideoTitle(entry.name).toLowerCase()
    const subtitles = this.allEntries.filter((file: SmbEntry) => {
      const lower = file.name.toLowerCase()
      const stem = VideoInfoUtil.splitFileName(lower).stem
      return !file.directory && file.size <= 8 * 1024 * 1024 && /\.(srt|ass|vtt)$/.test(lower) &&
        (stem === base || stem.startsWith(base + '.'))
    })
    const subtitle =
      subtitles.find((file: SmbEntry) => VideoInfoUtil.splitFileName(file.name).stem.toLowerCase() === base) ??
        subtitles[0]
    const subtitlePath = subtitle ? (this.folder ? `${this.folder}/${subtitle.name}` : subtitle.name) : ''
    const metadata = VideoInfoUtil.buildNetworkVideoMetadata(uri, await SmbUtil.fileId(uri), entry.name,
      ToolsUtil.formatFileSize(entry.size), [1, 1])
    metadata.smb_subtitle_uri = subtitle ? SmbUtil.uri(server, subtitlePath) : undefined
    metadata.external_subtitle_format = subtitle ? VideoInfoUtil.getExtension(subtitle.name) : ''
    return metadata
  }

  private async select(entry: SmbEntry): Promise<void> {
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
      const list = await Promise.all(this.entries.filter((file: SmbEntry) => !file.directory)
        .map((file: SmbEntry) => this.metadata(file)))
      if (version !== this.requestVersion) {
        return
      }
      const selectedPath = folder ? `${folder}/${entry.name}` : entry.name
      const item = list.find((file: VideoMetadata) => file.uri === SmbUtil.uri(server, selectedPath))!
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

  private stopThumbnails(): void {
    this.thumbnailVersion++
    this.thumbnailActive = false
    this.thumbnailQueue = []
    if (this.thumbnailUrl) {
      smbClose(this.thumbnailUrl)
      this.thumbnailUrl = ''
    }
  }

  private thumbnailVisibility(entry: SmbEntry, visible: boolean): void {
    if (entry.directory) return
    if (!visible) {
      this.thumbnailVisible.delete(entry.name)
      this.thumbnailQueue = this.thumbnailQueue.filter((file: SmbEntry) => file.name !== entry.name)
      return
    }
    this.thumbnailVisible.add(entry.name)
    if (!this.thumbnailActive || this.covers[entry.name] || this.thumbnailAttempted.has(entry.name) ||
      this.thumbnailQueue.some((file: SmbEntry) => file.name === entry.name)) return
    this.thumbnailQueue.push(entry)
    this.loadThumbnails()
  }

  private async loadThumbnails(): Promise<void> {
    if (this.thumbnailRunning) return
    this.thumbnailRunning = true
    try {
      while (this.thumbnailActive && this.server && this.thumbnailQueue.length > 0) {
        const entry = this.thumbnailQueue.shift()!
        if (!this.thumbnailVisible.has(entry.name)) continue
        const version = this.thumbnailVersion
        const path = this.folder ? `${this.folder}/${entry.name}` : entry.name
        const uri = SmbUtil.uri(this.server, path)
        this.thumbnailAttempted.add(entry.name)
        let url = ''
        try {
          const id = await SmbUtil.fileId(`${uri}:${entry.size}`)
          if (!id || version !== this.thumbnailVersion) continue
          const root = PathUtils.appContext!.cacheDir + '/'
          const filename = 'smb_cover_' + id + '.webp'
          let cached = false
          try { cached = await fs.access(root + filename) } catch (_) {}
          if (!cached) {
            url = await SmbUtil.open(uri)
            if (version !== this.thumbnailVersion) continue
            this.thumbnailUrl = url
            const result = await FFmpegThumbnailUtil.extractNetworkCover(url, 360)
            if (result.pixelMap) {
              if (version !== this.thumbnailVersion) {
                result.pixelMap.release()
                continue
              }
              cached = (await ImageStorage.savePixelMapToFile(root, filename, result.pixelMap,
                { releasePixelMap: true, deleteOnFail: true })).length > 0
            }
          }
          if (cached && version === this.thumbnailVersion) {
            const covers: Record<string, string> = {}
            Object.keys(this.covers).forEach((key: string) => { covers[key] = this.covers[key] })
            covers[entry.name] = PathUtils.pathToUri(root + filename)
            this.covers = covers
          }
        } catch (_) {
          // Keep the placeholder; retry only on an explicit directory refresh.
          if (version === this.thumbnailVersion) salmonLogger.addLog('SmbPage', 'SMB 缩略图读取失败', true)
        } finally {
          if (url) smbClose(url)
          if (this.thumbnailUrl === url) this.thumbnailUrl = ''
        }
      }
    } finally {
      this.thumbnailRunning = false
    }
  }
}
