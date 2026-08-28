import NavigationAddress, { IPTVChannelParams, PlayerEngine, PlayerParams } from '../../common/NavigationCommon'
import Preferences from '../../database/Preferences'
import { IPTVChannel, IPTVLine, IPTVSource } from '../../interfaces/IPTVInterface'
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import IPTVUtil from '../../utils/IPTVUtil'
import { PathUtils } from '../../utils/PathUtils'
import { SafeHeight, Setting } from '../../utils/ObservedUtil'
import { LengthMetrics } from '@kit.ArkUI'
import { hdsMaterial, HdsNavDestination, HideMode, ScrollEffectType } from '@kit.UIDesignKit'
import { salmonLogger } from 'salmonlogger'
import { ImageFancyModifier } from '../../common/AttributeModifierConfig'
import { SearchComponent } from '../../component/VideoItemComponent/SearchComponent'

const ALL_CHANNELS = '全部频道'
const TAG = 'IPTVChannelPage'
const EPG_REFRESH_INTERVAL = 30 * 60 * 1000

class IPTVChannelCardParams {
  channel: IPTVChannel | undefined = undefined
}

@ComponentV2
export struct IPTVChannelPage {
  @Consumer('pathStack') pathStack: NavPathStack = new NavPathStack()
  @Local source: IPTVSource | undefined = undefined
  @Local groups: string[] = []
  @Local selectedGroup: string = ALL_CHANNELS
  @Local visibleChannels: IPTVChannel[] = []
  @Local searchValue: string = ''
  private channelScroller: Scroller = new Scroller()
  private groupScroller: Scroller = new Scroller()
  private searchController: SearchController = new SearchController()
  private syncingFromGroup: boolean = false
  private targetChannelIndex: number = -1
  private epgRefreshRunning: boolean = false

  aboutToAppear(): void {
    this.loadSource()
    this.refreshEpgIfNeeded()
  }

  build() {
    HdsNavDestination() {
      Column() {
        if (!this.source || this.source.channels.length === 0) {
          Column({ space: 8 }) {
            Text('没有可播放的频道').fontSize(18).opacity(0.6)
            Text('请返回刷新节目源').fontSize(14).opacity(0.4)
          }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
        } else {
          Row() {
            this.GroupList()
            this.ChannelList()
          }
          .layoutWeight(1)
          .width('100%')
          .alignItems(VerticalAlign.Top)
        }
      }
      .width('100%')
      .height('100%')
    }
    .titleBar({
      avoidLayoutSafeArea: true,
      enableComponentSafeArea: true,
      padding: { start: LengthMetrics.vp(5), end: LengthMetrics.vp(5) },
      style: {
        // 设置导航组件标题栏样式，推荐使用默认样式
        // 标题栏动态模糊样式，包括是否使能滚动动态模糊，动态模糊类型，动态模糊生效的滚动距离等
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
          // 内容区滚动前初始样式设置
          backgroundStyle: {
            // 标题栏背板样式设置
            backgroundColor: $r('sys.color.ohos_id_color_background'),
          },
          contentStyle: {
            // 标题栏内容区样式设置，包括标题区域，菜单区域，返回按钮区域
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
          // 内容区滚动超过blurEffectiveEndOffset后样式设置
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
        title: { mainTitle: this.pageTitle(), subTitle: this.pageSubTitle() },
        bottomBuilder: { builder: (): void => this.SearchBuilder() }
      }
    })
    .backgroundColor($r('app.color.start_window_background'))
    .backgroundImage(Setting.backgroundDropBlur > 0 && Setting.backgroundBlurImageSrc.length > 0 ?
      Setting.backgroundBlurImageSrc : Setting.backgroundImageSrc, ImageRepeat.NoRepeat)
    .backgroundImageSize(ImageSize.Cover)
    .backgroundImagePosition(Alignment.Center)
    .onShown(() => {
      this.loadSource()
      this.refreshEpgIfNeeded()
    })
    .onBackPressed(() => {
      if (this.searchValue.length > 0) {
        this.searchValue = ''
        this.rebuildChannels()
        return true
      }
      return false
    })
    .bindToScrollable([this.groupScroller, this.channelScroller]) // 绑定导航组件和可滚动容器组件
    .dynamicHideTitleBar({
      hideTitleArea: false,
      hideBottomBuilder: true,
      hideStatusBar: false,
      mode: HideMode.SCROLL_UP
    })
  }

  @Builder
  SearchBuilder() {
    Row({ space: 10 }) {
      SearchComponent({
        controller: this.searchController,
        searchValue: this.searchValue,
        onSearchValueChange: (v: string) => {
          this.searchValue = v
        },
        onChange: () => {
          this.rebuildChannels()
        }
      })
    }
    .width('95%')
    .justifyContent(FlexAlign.Start)
    .animation({ duration: 300, curve: Curve.Ease })
  }

  @Builder
  GroupList() {
    List({ scroller: this.groupScroller, space: 5 }) {
      Repeat<string>(this.groups)
        .each((item: RepeatItem<string>) => {
          ListItem() {
            Text(this.groupLabel(item.item))
              .fontSize(13)
              .fontWeight(this.selectedGroup === item.item ? FontWeight.Medium : FontWeight.Normal)
              .fontColor(this.selectedGroup === item.item ? Color.White : $r('app.color.text_color'))
              .padding({ left: 10, right: 10 })
              .width('100%')
              .height(44)
              .borderRadius(12)
              .backgroundColor(this.selectedGroup === item.item ? $r('app.color.main_color') : Color.Transparent)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .maxLines(1)
          }
          .onClick(() => this.scrollToGroup(item.item))
          .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.96 })
        })
        .key((group: string) => group)
    }
    .clip(false)
    .borderRadius(12)
    .width(124)
    .height('100%')
    .padding({ left: 10, right: 6 })
    .contentEndOffset(SafeHeight.bottomSafeHeight)
    .scrollBar(BarState.Off)
    .backgroundColor($r('app.color.list_item_background'))
  }

  @Builder
  ChannelList() {
    List({ scroller: this.channelScroller, space: 8 }) {
      Repeat<IPTVChannel>(this.visibleChannels)
        .each((item: RepeatItem<IPTVChannel>) => {
          ListItem() {
            this.ChannelCard({ channel: item.item })
          }
          .onClick(() => this.play(item.item))
          .clickEffect({ level: ClickEffectLevel.HEAVY, scale: 0.9 })
        })
        .key((item: IPTVChannel) => item.id)
        .virtualScroll()
    }
    .clip(false)
    .borderRadius(16)
    .layoutWeight(1)
    .width('100%')
    .height('100%')
    .padding({ left: 10, right: 16 })
    .contentEndOffset(SafeHeight.bottomSafeHeight)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .onScrollIndex((start: number, end: number) => this.syncGroupFromScroll(start, end))
    .onScrollStop(() => this.finishGroupScroll())
  }

  @Builder
  ChannelCard(params: IPTVChannelCardParams) {
    Row({ space: 12 }) {
      if (params.channel!.logoUrl) {
        Image(params.channel!.logoUrl)
          .objectFit(ImageFit.Contain)
          .attributeModifier(new ImageFancyModifier(12, 46, 46))
      } else {
        Image($r('app.media.sweet_video_alt')).attributeModifier(new ImageFancyModifier(12, 46, 46))
      }

      Column({ space: 5 }) {
        Text(params.channel!.name)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_color'))
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        if (params.channel!.currentProgram && params.channel!.currentProgram!.endTime > Date.now()) {
          Text(`正在播放：${params.channel!.currentProgram!.title}`)
            .fontSize(13)
            .fontColor($r('app.color.text_color'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.MARQUEE })
          Progress({ value: this.programProgress(params.channel!), total: 100, type: ProgressType.Linear })
            .height(3).color($r('app.color.main_color')).width('100%')
        } else if (params.channel!.nextProgram && params.channel!.nextProgram!.startTime > Date.now()) {
          Text(`下一节目：${params.channel!.nextProgram!.title}`)
            .fontSize(12).opacity(0.45).maxLines(1).textOverflow({ overflow: TextOverflow.MARQUEE })
        } else {
          Text('暂无节目单信息')
            .fontSize(12).opacity(0.45).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        if (this.lineCount(params.channel!) > 1) {
          Row() {
            Button(`线路 ${this.selectedLineNumber(params.channel!)}/${this.lineCount(params.channel!)}`)
              .height(28)
              .fontSize(11)
              .fontColor($r('app.color.text_color'))
              .backgroundColor($r('sys.color.button_background_color_transparent'))
              .borderRadius(10)
              .bindMenu(this.LineMenu(params.channel!), {
                placement: Placement.BottomRight,
                showInSubWindow: false,
                backgroundBlurStyle: BlurStyle.COMPONENT_THIN
              })
          }
          .width('100%')
          .justifyContent(FlexAlign.End)
        }
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
    }
    .padding(12)
    .width('100%')
    .borderRadius(16)
    .backgroundColor($r('app.color.list_item_background'))
  }

  @Builder
  LineMenu(channel: IPTVChannel) {
    Menu() {
      Repeat<IPTVLine>(IPTVUtil.channelLines(channel))
        .each((item: RepeatItem<IPTVLine>) => {
          MenuItem({
            content: `线路 ${item.index + 1}`,
            labelInfo: item.index === (channel.selectedLineIndex ?? 0) ? '当前' : this.lineHost(item.item)
          }).onClick(() => this.selectLine(channel, item.index))
        })
        .key((line: IPTVLine, index: number) => `${line.url}_${index}`)
    }
  }

  private loadSource(): void {
    const params = this.pathStack.getParamByName(NavigationAddress.IPTV_CHANNEL_PAGE) as IPTVChannelParams[]
    const sourceId = params.length > 0 ? params[0].sourceId : ''
    const sources = Preferences.getIPTVSources(PathUtils.appContext!)
    this.source = sources.find(item => item.id === sourceId)
    if (!this.source) {
      this.groups = []
      this.visibleChannels = []
      return
    }
    const sourceChannelIds = new Set<string>()
    const hasDuplicateIds = this.source.channels.some(channel => {
      if (sourceChannelIds.has(channel.id)) {
        return true
      }
      sourceChannelIds.add(channel.id)
      return false
    })
    const deduplicated = IPTVUtil.deduplicateChannels(this.source.channels)
    if (deduplicated.length !== this.source.channels.length || hasDuplicateIds) {
      this.source.channels = deduplicated
      this.source.channelCount = deduplicated.length
      this.source.groupCount = new Set(deduplicated.map(channel => channel.groupName)).size
      Preferences.saveIPTVSources(PathUtils.appContext!, sources)
    }
    this.promoteCachedPrograms()
    const uniqueGroups = Array.from(new Set(this.source.channels.map(channel => channel.groupName)))
    this.groups = [ALL_CHANNELS, ...uniqueGroups]
    if (!this.groups.includes(this.selectedGroup)) {
      this.selectedGroup = ALL_CHANNELS
    }
    this.rebuildChannels()
  }

  private promoteCachedPrograms(): void {
    if (!this.source) {
      return
    }
    const now = Date.now()
    this.source.channels.forEach(channel => {
      const current = channel.currentProgram
      if (!current || current.startTime > now || current.endTime <= now) {
        channel.currentProgram = undefined
        const next = channel.nextProgram
        if (next && next.startTime <= now && next.endTime > now) {
          channel.currentProgram = next
          channel.nextProgram = undefined
        } else if (next && next.endTime <= now) {
          channel.nextProgram = undefined
        }
      }
    })
  }

  private refreshEpgIfNeeded(): void {
    const source = this.source
    if (!source?.epgUrl?.trim() || source.channels.length === 0 || this.epgRefreshRunning ||
      !this.shouldRefreshEpg(source)) {
      return
    }
    this.epgRefreshRunning = true
    IPTVUtil.refreshEpg(source).then(refreshed => {
      const sources = Preferences.getIPTVSources(PathUtils.appContext!)
      const savedSource = sources.find(item => item.id === refreshed.id)
      if (!savedSource || savedSource.epgUrl?.trim() !== refreshed.epgUrl?.trim()) {
        return
      }
      const refreshedChannels = new Map<string, IPTVChannel>()
      refreshed.channels.forEach(channel => refreshedChannels.set(channel.id, channel))
      savedSource.channels.forEach(channel => {
        const epgChannel = refreshedChannels.get(channel.id)
        if (epgChannel) {
          channel.currentProgram = epgChannel.currentProgram
          channel.nextProgram = epgChannel.nextProgram
        }
      })
      savedSource.epgMatchedCount = refreshed.epgMatchedCount
      savedSource.lastEpgRefreshTime = refreshed.lastEpgRefreshTime
      Preferences.saveIPTVSources(PathUtils.appContext!, sources)
      if (this.source?.id === savedSource.id) {
        this.source = savedSource
        this.promoteCachedPrograms()
        this.rebuildChannels()
      }
    }).catch((error: Error) => {
      salmonLogger.addLog(TAG, `EPG refresh failed: ${error.message}`, true)
    }).finally(() => {
      this.epgRefreshRunning = false
    })
  }

  private shouldRefreshEpg(source: IPTVSource): boolean {
    const now = Date.now()
    if (!source.lastEpgRefreshTime || now - source.lastEpgRefreshTime >= EPG_REFRESH_INTERVAL) {
      return true
    }
    const availableCount = source.channels.filter(channel =>
    !!channel.currentProgram && channel.currentProgram.endTime > now ||
      !!channel.nextProgram && channel.nextProgram.endTime > now).length
    const matchedCount = source.epgMatchedCount ?? 0
    return matchedCount > 0 && availableCount * 4 < matchedCount * 3
  }

  private rebuildChannels(): void {
    if (!this.source) {
      this.visibleChannels = []
      return
    }
    const query = this.searchValue.trim().toLowerCase()
    const channels: IPTVChannel[] = []
    for (const group of this.groups) {
      if (group === ALL_CHANNELS) {
        continue
      }
      this.source.channels.filter(channel => channel.groupName === group && (!query ||
        channel.name.toLowerCase().includes(query) || channel.groupName.toLowerCase().includes(query)))
        .forEach(channel => channels.push(channel))
    }
    this.visibleChannels = channels
  }

  private scrollToGroup(group: string): void {
    this.selectedGroup = group
    const targetGroup = group === ALL_CHANNELS ? this.firstVisibleGroup() : group
    const index = this.visibleChannels.findIndex(channel => channel.groupName === targetGroup)
    if (index < 0) {
      return
    }
    this.syncingFromGroup = true
    this.targetChannelIndex = index
    this.channelScroller.scrollToIndex(index, false, ScrollAlign.START)
  }

  private syncGroupFromScroll(start: number, end: number): void {
    if (start < 0 || start >= this.visibleChannels.length) {
      return
    }
    if (this.syncingFromGroup) {
      if (this.targetChannelIndex >= start && this.targetChannelIndex <= end) {
        this.finishGroupScroll()
      }
      return
    }
    const group = this.visibleChannels[start].groupName
    if (group && this.selectedGroup !== group) {
      this.selectedGroup = group
      const groupIndex = this.groups.indexOf(group)
      if (groupIndex >= 0) {
        this.groupScroller.scrollToIndex(groupIndex, false, ScrollAlign.CENTER)
      }
    }
  }

  private finishGroupScroll(): void {
    this.syncingFromGroup = false
    this.targetChannelIndex = -1
  }

  private firstVisibleGroup(): string {
    return this.visibleChannels.length > 0 ? this.visibleChannels[0].groupName : ''
  }

  private pageTitle(): string {
    return this.source ? this.source.name : 'IPTV'
  }

  private pageSubTitle(): string {
    if (!this.source) {
      return '0 个频道'
    }
    const multiLineCount = this.source.channels.filter(channel => this.lineCount(channel) > 1).length
    return multiLineCount > 0 ? `${this.source.channelCount} 个频道 · ${multiLineCount} 个支持多线路` :
      `${this.source.channelCount} 个频道`
  }

  private groupLabel(group: string): string {
    if (group === ALL_CHANNELS && this.source) {
      return `${group}  ${this.source.channelCount}`
    }
    return group
  }

  private play(channel: IPTVChannel): void {
    if (!this.source) {
      return
    }
    const metadataList = this.source.channels.map(item => this.toMetadata(item))
    const metadata = this.toMetadata(channel)
    salmonLogger.addLog(TAG,
      `play channel=${channel.name}, id=${channel.id}, line=${(channel.selectedLineIndex ?? 0) + 1}/${this.lineCount(
        channel)}, url=${metadata.uri}`,
      false)
    const params = new PlayerParams(metadata, metadataList, undefined, true, PlayerEngine.MPV_PLAYER)
    this.pathStack.pushPathByName(NavigationAddress.VIDEO_PLAYER, params, true)
  }

  private selectLine(channel: IPTVChannel, index: number): void {
    if (!this.source) {
      return
    }
    IPTVUtil.selectLine(channel, index)
    const sources = Preferences.getIPTVSources(PathUtils.appContext!)
    const savedSource = sources.find(item => item.id === this.source!.id)
    const savedChannel = savedSource?.channels.find(item => item.id === channel.id)
    if (savedSource && savedChannel) {
      IPTVUtil.selectLine(savedChannel, index)
      Preferences.saveIPTVSources(PathUtils.appContext!, sources)
    }
    this.rebuildChannels()
  }

  private lineCount(channel: IPTVChannel): number {
    return IPTVUtil.channelLines(channel).length
  }

  private selectedLineNumber(channel: IPTVChannel): number {
    const count = this.lineCount(channel)
    return Math.max(0, Math.min(channel.selectedLineIndex ?? 0, count - 1)) + 1
  }

  private lineHost(line: IPTVLine): string {
    const match = line.url.match(/^[a-z]+:\/\/([^/?#]+)/i)
    return match ? match[1] : ''
  }

  private toMetadata(channel: IPTVChannel): VideoMetadata {
    const selectedLine = IPTVUtil.selectedLine(channel)
    return {
      uri: selectedLine.url,
      title: this.activeProgramTitle(channel),
      date: channel.id,
      size: [0, 0],
      time: 0,
      last_play: 0,
      format: 'm3u8',
      video_size: '',
      hdr_type: 0,
      audio_type: 0,
      frame_rate: 0,
      start_time: 0,
      end_time: 0,
      external_subtitle_format: '',
      pointA: 0,
      pointB: 0,
      network_user_agent: selectedLine.userAgent
    }
  }

  private activeProgramTitle(channel: IPTVChannel): string {
    if (channel.currentProgram && channel.currentProgram.endTime > Date.now()) {
      return `${channel.name} · ${channel.currentProgram.title}`
    }
    if (channel.nextProgram && channel.nextProgram.startTime <= Date.now()) {
      return `${channel.name} · ${channel.nextProgram.title}`
    }
    return channel.name
  }

  private programProgress(channel: IPTVChannel): number {
    const program = channel.currentProgram
    if (!program || program.endTime <= program.startTime) {
      return 0
    }
    return Math.max(0, Math.min(100, (Date.now() - program.startTime) * 100 /
      (program.endTime - program.startTime)))
  }
}
