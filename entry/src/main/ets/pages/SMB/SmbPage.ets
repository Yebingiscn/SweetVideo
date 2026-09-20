import { SmbEntry } from 'libmpvnative.so'
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
      { textInfo: '删除此 SMB 连接？服务器上的文件不会被删除。', confirm: () => this.removeServer() }),
    cornerRadius: 20, shadow: DefaultDialogShadow
  })

  aboutToAppear(): void {
    this.reloadServers()
  }

  aboutToDisappear(): void {
    this.requestVersion++
  }

  @Builder
  ServerMenu(server: SmbServer) {
    Menu() {
      MenuItem({ content: '编辑' }).onClick(() => this.edit(server))
      MenuItem({ content: '删除连接' }).onClick(() => {
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
            Button(this.folder ? '上一级' : '服务器').onClick(() => this.back()).enabled(!this.loading)
            Text(`${this.server.name} / ${this.server.share}${this.folder ? '/' + this.folder : ''}`)
              .fontSize(14)
              .fontColor($r('app.color.text_color'))
              .layoutWeight(1)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Button('刷新').onClick(() => this.browse(this.server!, this.folder)).enabled(!this.loading)
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
            Text('连接你的 NAS 或电脑共享').fontSize(18).fontColor($r('app.color.text_color'))
            Text('添加 SMB 服务器，浏览并播放共享中的视频和音乐')
              .fontSize(14).fontColor($r('app.color.text_color')).opacity(0.6).textAlign(TextAlign.Center)
          }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center).padding(24)
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

                      Button('编辑').onClick(() => this.edit(item.item))
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
                  ListItem() {
                    Row({ space: 14 }) {
                      SymbolGlyph(item.item.directory ? $r('sys.symbol.folder') : $r('sys.symbol.play_round_triangle'))
                        .fontSize(28).fontColor([$r('app.color.main_color')])
                      Column({ space: 6 }) {
                        Text(item.item.name).fontSize(16).fontColor($r('app.color.text_color'))
                          .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
                        Text(item.item.directory ? '文件夹' : ToolsUtil.formatFileSize(item.item.size))
                          .fontSize(13).fontColor($r('app.color.text_color')).opacity(0.6)
                      }.layoutWeight(1).alignItems(HorizontalAlign.Start)

                      SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(16)
                    }.padding(16).width('100%').backgroundColor($r('app.color.list_item_background')).borderRadius(16)
                  }.onClick(() => this.select(item.item)).enabled(!this.loading)
                })
                .key((item: SmbEntry) => `${this.folder}/${item.name}`).virtualScroll()
              if (!this.loading && this.entries.length === 0) {
                ListItem() {
                  Text('此目录没有可播放的文件').fontColor($r('app.color.text_color')).padding(24)
                }
              }
            }
          }
          .clip(false)
          .layoutWeight(1)
          .height('100%')
          .width('100%')
          .padding({ left: 16, right: 16 })
          .contentEndOffset(SafeHeight.bottomSafeHeight)
          .scrollBar(BarState.Off)
        }
      }.width('100%').height('100%').clip(false)
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
              label: '添加服务器',
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
  }

  private reloadServers(): void {
    try {
      this.servers = SmbUtil.servers()
    } catch (error) {
      this.error = '无法读取已保存的服务器'
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
      this.error = '删除失败，请重试'
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
      this.folder = folder
      this.allEntries = entries
      this.entries = entries.filter((entry: SmbEntry) => entry.directory || SmbUtil.playable(entry.name))
      this.scroller.scrollTo({ xOffset: 0, yOffset: 0 })
    } catch (error) {
      if (version === this.requestVersion) {
        this.error = error instanceof Error ? error.message : '无法读取共享目录'
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
        this.error = error instanceof Error ? error.message : '无法打开视频'
      }
    } finally {
      if (version === this.requestVersion) {
        this.loading = false
      }
    }
  }
}
