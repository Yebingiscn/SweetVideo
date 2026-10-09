import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import { FileFolderDataSource } from '../../utils/DataUtil'
import { PathUtils } from '../../utils/PathUtils'
import { FileFolder } from '../../interfaces/FileFolderInterface'
import VideoUtils from '../../utils/VideoUtil'
import { CoverLayoutMode, ListDisplayMode } from '../../common/enum/DisplayMode'
import { SafeHeight, Setting } from '../../utils/ObservedUtil'
import VideoCardItem from './VideoCardItemComponent'
import VideoListItem from './VideoListItemComponent'
import { Binding, curves, UIUtils } from '@kit.ArkUI'
import KnockShareUtil from '../../utils/KnockShareUtil'
import FolderDirectory, { DirectoryEntry } from '../../utils/FolderDirectory'
import DirectoryHero, { DirectoryRect } from '../../utils/DirectoryHero'
import { VideoListController } from '../../controller/VideoListController'
import { ImageFancyModifier } from '../../common/AttributeModifierConfig'

enum DirectoryCoverPlacement {
  LIST,
  CARD,
  HEADER,
  HERO
}

@ComponentV2
export struct DirectoryView {
  @Param videoListController: VideoListController = new VideoListController()
  @Param searchValue: string = ''
  @Local _searchValue: string = ''
  @Param directoryVideos: VideoMetadata[] = []
  @Param directoryLayout: ListDisplayMode = Setting.listDisplayMode
  @Param directoryCoverLayout: CoverLayoutMode = Setting.coverLayout
  @Param _delMultipleList: VideoMetadata[] = []
  @Param coverRefreshDate: string = ''
  @Param coverRefreshToken: number = 0
  @Consumer() fileFolderSource: FileFolderDataSource = new FileFolderDataSource([])
  @Consumer() file_folder_list: FileFolder[] = []
  @BuilderParam menuBuilder: (item: VideoMetadata | undefined) => void
  @Event onVideoTap: (item: VideoMetadata) => Promise<void> = async () => {
  }
  @Local directoryEntries: DirectoryEntry[] = []
  @Local directoryHero: DirectoryHero | undefined = undefined
  @Local directorySharedFolderDate: string = ''
  private directoryIndex: FolderDirectory = new FolderDirectory([])
  private directoryRestoreTimer: number | undefined = undefined
  private directoryNavigationTimer: number | undefined = undefined
  private directoryHeroTimer: number | undefined = undefined
  private directoryAlive: boolean = false
  @Event menuOptions: (item: VideoMetadata, response: ResponseType) => ContextMenuOptions = () => ({})
  @Event onSearchValueChange: (v: string) => void = () => {
  }
  @Event onScrollDirectionChange: (isUp: boolean) => void = () => {
  }
  @Event onDirectoryFolderChange: (date: string) => void = () => {
  }

  aboutToAppear(): void {
    this._searchValue = this.searchValue
    this.directoryAlive = true
    this.rebuildDirectory()
  }

  aboutToDisappear(): void {
    this.directoryAlive = false
    if (this.directoryRestoreTimer !== undefined) {
      clearTimeout(this.directoryRestoreTimer)
    }
    if (this.directoryNavigationTimer !== undefined) {
      clearTimeout(this.directoryNavigationTimer)
    }
    if (this.directoryHeroTimer !== undefined) {
      clearTimeout(this.directoryHeroTimer)
    }
    this.directoryHero = undefined
    this.videoListController.directoryTransitioning = false
  }

  @Monitor('searchValue')
  onSearchValueMonitor(): void {
    this._searchValue = this.searchValue
  }

  @Monitor('file_folder_list', 'videoListController.folder', 'directoryVideos',
    'videoListController.directoryOverview', 'videoListController.directoryMode', '_searchValue')
  rebuildDirectory(): void {
    if (!this.videoListController.directoryMode) {
      if (this.directoryHeroTimer !== undefined) {
        clearTimeout(this.directoryHeroTimer)
        this.directoryHeroTimer = undefined
      }
      this.directoryHero = undefined
      this.videoListController.directoryTransitioning = false
      return
    }
    this.directoryIndex = new FolderDirectory(this.file_folder_list)
    const folderDate = this.videoListController.directoryOverview ? null : this.videoListController.folder?.date ?? null
    this.directoryEntries = this.directoryIndex.entries(folderDate,
      this.videoListController.videoDataSource.data, this._searchValue)
    if (this.directoryEntries.length > 0) {
      // Repeat 会复用目录滚动节点，切换后主动恢复位置，不依赖 onAppear 再次触发。
      this.restoreDirectoryScroll(this.directoryKey())
    }
  }

  @Monitor('videoListController.directoryRequest')
  onDirectoryRequested(): void {
    if (this.directoryNavigationTimer !== undefined) {
      clearTimeout(this.directoryNavigationTimer)
    }
    // 退出本次状态监听的刷新周期后再切换，让起止布局都在显式动画中配对。
    this.directoryNavigationTimer = setTimeout(() => {
      this.directoryNavigationTimer = undefined
      if (this.directoryAlive) {
        this.navigateDirectory(this.videoListController.directoryTarget || null)
      }
    }, 0)
  }

  @Monitor('directoryLayout', 'directoryCoverLayout', 'videoListController.listLine')
  onDirectoryLayoutChanged(): void {
    if (this.videoListController.directoryMode && this.directoryEntries.length > 0) {
      this.restoreDirectoryScroll(this.directoryKey())
    }
  }

  @Builder
  DirectoryCoverBuilder(folder: Binding<FileFolder>, placement: DirectoryCoverPlacement) {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Image($r('app.media.sweet_video_alt'))
        .attributeModifier(new ImageFancyModifier(16, '100%', '100%'))
      if (this.directoryIndex.coverDates(folder.value.date).length === 1) {
        Image(PathUtils.coverUri(this.directoryIndex.coverDates(folder.value.date)[0]))
          .attributeModifier(new ImageFancyModifier(16, '100%', '100%'))
      } else if (this.directoryIndex.coverDates(folder.value.date).length > 1) {
        // 按实际封面数量排布：两张左右分栏，三张左大右小，四张四格。
        Repeat<string>(this.directoryIndex.coverDates(folder.value.date))
          .each((cover: RepeatItem<string>) => {
            Image(PathUtils.coverUri(cover.item))
              .draggable(false)
              .autoResize(true)
              .width('50%')
              .height(this.directoryIndex.coverDates(folder.value.date).length === 2 ||
                (this.directoryIndex.coverDates(folder.value.date).length === 3 && cover.index === 0) ? '100%' : '50%')
              .objectFit(ImageFit.Cover)
              .position({
                x: `${this.directoryIndex.coverDates(folder.value.date).length === 3 ? (cover.index === 0 ? 0 : 50) :
                  (cover.index % 2) * 50}%`,
                y: `${this.directoryIndex.coverDates(folder.value.date).length === 2 || cover.index === 0 ? 0 :
                  (this.directoryIndex.coverDates(folder.value.date).length === 3 ? cover.index - 1 :
                    Math.floor(cover.index / 2)) * 50}%`
              })
          })
          .key((date: string) => date)
      }
      SymbolGlyph($r('sys.symbol.folder'))
        .fontSize(14)
        .fontColor([$r('app.color.main_color')])
        .padding(5)
        .backgroundColor($r('app.color.start_window_background'))
        .borderRadius(10)
        .margin(6)
    }
    .width(placement === DirectoryCoverPlacement.LIST ?
      (this.directoryCoverLayout === CoverLayoutMode.VERTICAL_PLATE ? 85 : 110) :
      placement === DirectoryCoverPlacement.HEADER ? 72 :
        placement === DirectoryCoverPlacement.HERO ? this.directoryHero?.coverWidth ?? 0 : '100%')
    .height(placement === DirectoryCoverPlacement.LIST ? 110 :
      placement === DirectoryCoverPlacement.HEADER ? 72 :
        placement === DirectoryCoverPlacement.HERO ? this.directoryHero?.coverHeight ?? 0 :
          this.directoryLayout === ListDisplayMode.GRID_DISPLAY ? 100 : 200)
    .position(placement === DirectoryCoverPlacement.HERO ?
      { x: this.directoryHero?.coverX ?? 0, y: this.directoryHero?.coverY ?? 0 } : undefined)
    .id(placement === DirectoryCoverPlacement.HEADER ? 'directory-header:cover' :
      placement === DirectoryCoverPlacement.HERO ? 'directory-hero:cover' : `directory-card:${folder.value.date}:cover`)
    .opacity(placement !== DirectoryCoverPlacement.HERO &&
      this.directoryHero?.folder.date === folder.value.date && this.directoryHero.contentHidden ? 0 : 1)
    .backgroundColor($r('app.color.search_component_blur'))
    .borderRadius(12)
    .clip(true)
  }

  @Builder
  DirectoryFolderListBuilder(folder: Binding<FileFolder>) {
    Row({ space: 16 }) {
      this.DirectoryCoverBuilder(folder, DirectoryCoverPlacement.LIST)

      Column({ space: 8 }) {
        Text(folder.value.name)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_color'))
          .width('100%')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .id(`directory-card:${folder.value.date}:title`)
          .opacity(this.directoryHero?.folder.date === folder.value.date && this.directoryHero.contentHidden ? 0 : 1)
        Text($r('app.string.directory_item_count', folder.value.video_list.length,
          this.directoryIndex.childFolders(folder.value.date).length))
          .fontSize(12)
          .fontColor($r('sys.color.font_secondary'))
          .width('100%')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .id(`directory-card:${folder.value.date}:info`)
          .opacity(this.directoryHero?.folder.date === folder.value.date && this.directoryHero.contentHidden ? 0 : 1)
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }
    .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
    .width('100%')
    .accessibilityText($r('app.string.directory_folder_accessibility', folder.value.name,
      folder.value.video_list.length, this.directoryIndex.childFolders(folder.value.date).length))
    .gesture(GestureGroup(GestureMode.Exclusive,
      LongPressGesture({ repeat: false }).onAction(() => {
      }),
      TapGesture().onAction(() => {
        this.videoListController.requestDirectory(folder.value.date)
      })))
    .backdropBlur(Setting.listItemBackgroundBlur ? 150 : 0)
    .borderRadius(12)
  }

  @Builder
  DirectoryFolderCardBuilder(folder: Binding<FileFolder>) {
    Column({ space: 6 }) {
      this.DirectoryCoverBuilder(folder, DirectoryCoverPlacement.CARD)

      Text(folder.value.name)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_color'))
        .width('100%')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .id(`directory-card:${folder.value.date}:title`)
        .opacity(this.directoryHero?.folder.date === folder.value.date && this.directoryHero.contentHidden ? 0 : 1)
        .padding({ left: 5 })
      Text($r('app.string.directory_item_count', folder.value.video_list.length,
        this.directoryIndex.childFolders(folder.value.date).length))
        .fontSize(12)
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .id(`directory-card:${folder.value.date}:info`)
        .opacity(this.directoryHero?.folder.date === folder.value.date && this.directoryHero.contentHidden ? 0 : 1)
        .padding({ left: 5 })
    }
    .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
    .borderRadius(12)
    .backdropBlur(Setting.listItemBackgroundBlur ? 150 : 0)
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ bottom: 12 })
    .accessibilityText($r('app.string.directory_folder_accessibility', folder.value.name,
      folder.value.video_list.length, this.directoryIndex.childFolders(folder.value.date).length))
    // 单击与长按互斥：长按保持当前目录，单击进入文件夹。
    .gesture(GestureGroup(GestureMode.Exclusive,
      LongPressGesture({ repeat: false }).onAction(() => {
      }),
      TapGesture().onAction(() => {
        this.videoListController.requestDirectory(folder.value.date)
      })))
  }

  @Builder
  DirectoryHeaderBuilder() {
    Row({ space: 14 }) {
      if (this.videoListController.directoryOverview) {
        Column({ space: 6 }) {
          Text($r('app.string.directory_all_folders'))
            .fontSize(22).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_color'))
          Text($r('app.string.directory_root_count', this.directoryIndex.childFolders(null).length))
            .fontSize(13).fontColor($r('sys.color.font_secondary'))
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      } else {
        Repeat<FileFolder>([this.videoListController.folder])
          .each((folder: RepeatItem<FileFolder>) => {
            Row({ space: 14 }) {
              this.DirectoryCoverBuilder(UIUtils.makeBinding<FileFolder>(() => folder.item),
                DirectoryCoverPlacement.HEADER)

              Column({ space: 6 }) {
                Text(folder.item.name)
                  .fontSize(22)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.text_color'))
                  .width('100%')
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .id('directory-header:title')
                  .opacity(
                    this.directoryHero?.folder.date === folder.item.date && this.directoryHero.contentHidden ? 0 : 1)
                Text($r('app.string.directory_item_count', folder.item.video_list.length,
                  this.directoryIndex.childFolders(folder.item.date).length))
                  .fontSize(13)
                  .fontColor($r('sys.color.font_secondary'))
                  .width('100%')
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .id('directory-header:info')
                  .opacity(
                    this.directoryHero?.folder.date === folder.item.date && this.directoryHero.contentHidden ? 0 : 1)
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            }.width('100%')
          })
          .key((folder: FileFolder) => folder.date + folder.name)
      }
    }
    .width('100%')
    .height(88)
    .padding({ left: 16, right: 16, bottom: 16 })
    .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
    .onClick(() => {
      this.videoListController.requestDirectoryBack()
    })
  }

  @Builder
  DirectoryVideoBuilder(video: Binding<VideoMetadata>) {
    if (this.directoryLayout === ListDisplayMode.LIST_DISPLAY) {
      VideoListItem({
        item: video.value,
        delMultipleList: this._delMultipleList,
        coverRefreshDate: this.coverRefreshDate,
        coverRefreshToken: this.coverRefreshToken,
        coverTransition: false
      })
        .bindContextMenu(this.menuBuilder(video.value), ResponseType.LongPress,
          this.menuOptions(video.value, ResponseType.LongPress))
        .bindContextMenu(this.menuBuilder(video.value), ResponseType.RightClick,
          this.menuOptions(video.value, ResponseType.RightClick))
    } else {
      VideoCardItem({
        item: video.value,
        delMultipleList: this._delMultipleList,
        coverRefreshDate: this.coverRefreshDate,
        coverRefreshToken: this.coverRefreshToken,
        coverTransition: false
      })
        .bindContextMenu(this.menuBuilder(video.value), ResponseType.LongPress,
          this.menuOptions(video.value, ResponseType.LongPress))
        .bindContextMenu(this.menuBuilder(video.value), ResponseType.RightClick,
          this.menuOptions(video.value, ResponseType.RightClick))
    }
  }

  @Builder
  DirectoryEntryContentBuilder(entry: RepeatItem<DirectoryEntry>) {
    if (entry.item.folder) {
      if (this.directoryLayout === ListDisplayMode.LIST_DISPLAY) {
        this.DirectoryFolderListBuilder(UIUtils.makeBinding<FileFolder>(() => entry.item.folder!))
      } else {
        this.DirectoryFolderCardBuilder(UIUtils.makeBinding<FileFolder>(() => entry.item.folder!))
      }
    } else if (entry.item.video) {
      this.DirectoryVideoBuilder(UIUtils.makeBinding<VideoMetadata>(() => entry.item.video!))
    }
  }

  @Builder
  DirectoryFlowEntryBuilder(entry: RepeatItem<DirectoryEntry>) {
    FlowItem() {
      this.DirectoryEntryContentBuilder(entry)
    }
    .width('100%')
    .borderRadius(12)
    .backgroundColor(Setting.listItemBackgroundBlur ? undefined :
      (Setting.backgroundImageSrc.length > 0 ? $r('app.color.start_window_background_blur') :
        $r('app.color.start_window_background')))
    .clickEffect(this.videoClickEffect(entry.item.video))
    .gesture(
      TapGesture({ count: 1, fingers: 1 }).onAction(async () => {
        if (entry.item.folder) {
          this.videoListController.requestDirectory(entry.item.folder.date)
        } else if (entry.item.video) {
          await this.onVideoTap(entry.item.video)
        }
      })
    )
    .onAreaChange((_old: Area, area: Area) => {
      if (entry.item.video) {
        KnockShareUtil.updateVideoRegion(entry.item.video, area)
      }
    })
    .onVisibleAreaChange([0], (visible: boolean) => {
      if (entry.item.video) {
        KnockShareUtil.setVideoRegionVisible(entry.item.video.date, visible)
      }
    })
  }

  @Builder
  DirectoryEntryBuilder(entry: RepeatItem<DirectoryEntry>) {
    ListItem() {
      this.DirectoryEntryContentBuilder(entry)
    }
    .width('100%')
    .borderRadius(12)
    .backgroundColor(Setting.listItemBackgroundBlur ? undefined :
      (Setting.backgroundImageSrc.length > 0 ? $r('app.color.start_window_background_blur') :
        $r('app.color.start_window_background')))
    .clickEffect(this.videoClickEffect(entry.item.video))
    .gesture(
      TapGesture({ count: 1, fingers: 1 }).onAction(async () => {
        if (entry.item.folder) {
          this.videoListController.requestDirectory(entry.item.folder.date)
        } else if (entry.item.video) {
          await this.onVideoTap(entry.item.video)
        }
      })
    )
    .onAreaChange((_old: Area, area: Area) => {
      if (entry.item.video) {
        KnockShareUtil.updateVideoRegion(entry.item.video, area)
      }
    })
    .onVisibleAreaChange([0], (visible: boolean) => {
      if (entry.item.video) {
        KnockShareUtil.setVideoRegionVisible(entry.item.video.date, visible)
      }
    })
  }

  @Builder
  DirectoryRepeatedEntryBuilder(entry: RepeatItem<DirectoryEntry>) {
    if (this.directoryLayout === ListDisplayMode.CARD_DISPLAY) {
      this.DirectoryFlowEntryBuilder(entry)
    } else {
      this.DirectoryEntryBuilder(entry)
    }
  }

  @Builder
  DirectoryEntriesBuilder() {
    Repeat<DirectoryEntry>(this.directoryEntries)
      .each((entry: RepeatItem<DirectoryEntry>) => {
        this.DirectoryRepeatedEntryBuilder(entry)
      })
      .template('folder', (entry: RepeatItem<DirectoryEntry>) => {
        this.DirectoryRepeatedEntryBuilder(entry)
      })
      .template('video', (entry: RepeatItem<DirectoryEntry>) => {
        this.DirectoryRepeatedEntryBuilder(entry)
      })
      .templateId((entry: DirectoryEntry) => entry.folder ? 'folder' : 'video')
      .key((entry: DirectoryEntry) => entry.key)
      .virtualScroll()
  }

  @Builder
  DirectoryBottomSpaceBuilder() {
    Blank().height(SafeHeight.bottomSafeHeight + 80)
  }

  @Builder
  DirectoryContentBuilder() {
    Column() {
      this.DirectoryHeaderBuilder()
      if (this.directoryEntries.length === 0) {
        Column({ space: 12 }) {
          Text(this._searchValue.length > 0 ? $r('app.string.directory_search_empty') :
            $r('app.string.directory_empty'))
            .fontSize(17).fontColor($r('sys.color.font_secondary'))
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        Repeat<string>([this.directoryKey()])
          .each((directory: RepeatItem<string>) => {
            if (this.directoryLayout === ListDisplayMode.CARD_DISPLAY) {
              WaterFlow({
                scroller: this.videoListController.directoryWaterFlowScroller,
                layoutMode: WaterFlowLayoutMode.SLIDING_WINDOW,
                footer: this.DirectoryBottomSpaceBuilder
              }) {
                this.DirectoryEntriesBuilder()
              }
              .columnsTemplate('1fr '.repeat(this.videoListController.listLine).trim())
              .columnsGap(16)
              .rowsGap(16)
              .padding({ left: 16, right: 16 })
              .scrollBar(BarState.Off)
              .edgeEffect(EdgeEffect.Spring)
              .width('100%')
              .height('100%')
              .layoutWeight(1)
              .onAppear(() => {
                this.restoreDirectoryScroll(directory.item)
              })
              .onScrollIndex((first: number) => {
                this.saveDirectoryScrollIndex(directory.item, first)
              })
              .onDidScroll(() => {
                this.saveDirectoryScrollOffset(directory.item)
              })
            } else {
              List({
                scroller: this.videoListController.directoryScroller, space: 16,
                initialIndex: Math.min(this.videoListController.directoryFirstIndexes.get(directory.item) ?? 0,
                  this.directoryEntries.length - 1)
              }) {
                this.DirectoryEntriesBuilder()
              }
              .lanes(this.videoListController.listLine, 16)
              .padding({ left: 16, right: 16 })
              .contentEndOffset(SafeHeight.bottomSafeHeight + 80)
              .scrollBar(BarState.Off)
              .edgeEffect(EdgeEffect.Spring)
              .width('100%')
              .height('100%')
              .layoutWeight(1)
              .onAppear(() => {
                this.restoreDirectoryScroll(directory.item)
              })
              .onScrollIndex((first: number) => {
                this.saveDirectoryScrollIndex(directory.item, first)
              })
              .onDidScroll(() => {
                this.saveDirectoryScrollOffset(directory.item)
              })
            }
          })
          // 这里只按目录 key 重建滚动容器；虚拟化由容器内部的条目 Repeat 负责。
          .key((key: string) => key)
      }
    }
    .padding({ top: SafeHeight.topSafeHeight + 100 })
    .width('100%').height('100%')
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.DirectoryContentBuilder()
      if (this.directoryHero) {
        this.DirectoryHeroBuilder(this.directoryHero)
      }
    }
    .width('100%').height('100%').id('directory-motion-root')
  }

  @Builder
  DirectoryHeroBuilder(hero: DirectoryHero) {
    Stack({ alignContent: Alignment.TopStart }) {
      this.DirectoryCoverBuilder(UIUtils.makeBinding<FileFolder>(() => hero.folder), DirectoryCoverPlacement.HERO)

      Text(hero.folder.name)
        .fontSize(hero.titleFontSize)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_color'))
        .width(hero.titleWidth)
        .maxLines(hero.titleMaxLines)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .scale({
          x: hero.titleScale,
          y: hero.titleScale,
          centerX: 0,
          centerY: 0
        })
        .position({ x: hero.titleX, y: hero.titleY })

      Text($r('app.string.directory_item_count', hero.folder.video_list.length, hero.childFolderCount))
        .fontSize(hero.infoFontSize)
        .fontColor($r('sys.color.font_secondary'))
        .width(hero.infoWidth)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .position({ x: hero.infoX, y: hero.infoY })
        .id('directory-hero:info')
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.None)
    .zIndex(2)
    .opacity(hero.contentHidden ? 1 : 0)
  }

  private saveDirectoryScrollIndex(key: string, first: number): void {
    if (key === this.directoryKey() && !this.videoListController.directoryTransitioning &&
      this.directoryRestoreTimer === undefined) {
      this.videoListController.directoryFirstIndexes.set(key, first)
    }
  }

  private saveDirectoryScrollOffset(key: string): void {
    if (key === this.directoryKey() && !this.videoListController.directoryTransitioning &&
      this.directoryRestoreTimer === undefined) {
      this.videoListController.directoryOffsets.set(key,
        Math.abs(this.videoListController.getActiveScroller().currentOffset().yOffset))
    }
  }

  private directoryKey(): string {
    const folderKey = this.videoListController.directoryOverview ? '__directory_root__' :
      this.videoListController.folder?.date ?? ''
    return `${folderKey}:${this.directoryLayout}:${this.directoryCoverLayout}:${this.videoListController.listLine}`
  }

  private navigateDirectory(date: string | null): void {
    const controller = this.videoListController
    if (!controller.directoryMode || controller.directoryTransitioning ||
      controller.multipleChooseState === Visibility.Visible ||
      (date === null ? controller.directoryOverview :
        !controller.directoryOverview && controller.folder?.date === date)) {
      return
    }
    const target = date ? this.file_folder_list.find(folder => folder.date === date) : undefined
    if (date && !target) {
      return
    }
    if (this.directoryEntries.length > 0) {
      this.videoListController.directoryOffsets.set(this.directoryKey(),
        Math.abs(this.videoListController.getActiveScroller().currentOffset().yOffset))
    }
    // 返回时由当前目录头部回到父目录卡片；进入时由目标卡片移到头部。
    this.directorySharedFolderDate = date === null || controller.folder?.parent_date === date ?
      controller.folder?.date ?? '' : target?.date ?? ''
    const returning = date === null || controller.folder?.parent_date === date
    const sharedFolder = this.file_folder_list.find(folder => folder.date === this.directorySharedFolderDate)
    const sourcePrefix = returning ? 'directory-header' : `directory-card:${this.directorySharedFolderDate}`
    const sourceCover = this.readDirectoryRect(`${sourcePrefix}:cover`)
    const sourceTitle = this.readDirectoryRect(`${sourcePrefix}:title`)
    const sourceInfo = this.readDirectoryRect(`${sourcePrefix}:info`)
    const folderTitleFontSize = this.directoryLayout === ListDisplayMode.LIST_DISPLAY ? 16 : 15
    const folderTitleMaxLines = this.directoryLayout === ListDisplayMode.LIST_DISPLAY ? 2 : 1
    if (sharedFolder && sourceCover && sourceTitle && sourceInfo) {
      this.directoryHero =
        new DirectoryHero(sharedFolder, sourceCover, sourceTitle, returning ? 22 : folderTitleFontSize,
          sourceInfo, returning ? 13 : 12, this.directoryIndex.childFolders(sharedFolder.date).length,
          returning ? 2 : folderTitleMaxLines)
    }
    controller.directoryTransitioning = true
    this.onScrollDirectionChange(false)
    // 先提交新目录，不给虚拟列表的复用节点叠加退场或布局动画；仅过渡层执行共享动画。
    this._searchValue = ''
    this.onSearchValueChange('')
    if (target) {
      this.file_folder_list = VideoUtils.refresh(controller, this.fileFolderSource, target)
      this.onDirectoryFolderChange(target.date)
    }
    controller.directoryOverview = date === null
    this.rebuildDirectory()
    if (this.directoryHero) {
      // 新目录先完成布局及滚动恢复，再量取真实终点；过渡层始终保留起点画面。
      this.directoryHeroTimer = setTimeout(() => {
        this.directoryHeroTimer = undefined
        if (!this.directoryAlive || !controller.directoryMode) {
          return
        }
        const prefix = returning ? `directory-card:${this.directorySharedFolderDate}` : 'directory-header'
        const cover = this.readDirectoryRect(`${prefix}:cover`)
        const title = this.readDirectoryRect(`${prefix}:title`)
        const info = this.readDirectoryRect(`${prefix}:info`)
        const hero = this.directoryHero
        if (!hero || !cover || !title || !info) {
          this.directoryHero = undefined
          controller.directoryTransitioning = false
          return
        }
        this.getUIContext().animateTo({
          curve: curves.springMotion(0.2, 0.9),
          onFinish: () => {
            if (this.directoryAlive && this.directoryHero === hero) {
              // 同一个状态在同一帧显露真实内容、隐藏过渡层，下一帧之后再回收节点。
              this.getUIContext().animateTo({ duration: 0 }, () => {
                hero.contentHidden = false
              })
              this.directoryHeroTimer = setTimeout(() => {
                this.directoryHeroTimer = undefined
                if (this.directoryAlive && this.directoryHero === hero) {
                  this.directoryHero = undefined
                  controller.directoryTransitioning = false
                }
              }, 32)
            }
          }
        }, () => {
          hero.moveTo(cover, title, returning ? folderTitleFontSize : 22, info, returning ? 12 : 13,
            returning ? folderTitleMaxLines : 2)
        })
      }, 64)
    } else {
      controller.directoryTransitioning = false
    }
  }

  private readDirectoryRect(id: string): DirectoryRect | undefined {
    try {
      const utils = this.getUIContext().getComponentUtils()
      const bounds = utils.getRectangleById(id)
      const root = utils.getRectangleById('directory-motion-root')
      if (bounds.size.width <= 0 || bounds.size.height <= 0) {
        return undefined
      }
      return {
        x: this.getUIContext().px2vp(bounds.windowOffset.x - root.windowOffset.x),
        y: this.getUIContext().px2vp(bounds.windowOffset.y - root.windowOffset.y),
        width: this.getUIContext().px2vp(bounds.size.width),
        height: this.getUIContext().px2vp(bounds.size.height)
      }
    } catch (_) {
      return undefined
    }
  }

  private restoreDirectoryScroll(key: string): void {
    if (this.directoryRestoreTimer !== undefined) {
      clearTimeout(this.directoryRestoreTimer)
    }
    this.directoryRestoreTimer = setTimeout(() => {
      this.directoryRestoreTimer = undefined
      if (!this.directoryAlive || !this.videoListController.directoryMode || key !== this.directoryKey()) {
        return
      }
      this.videoListController.getActiveScroller().scrollTo(
        { xOffset: 0, yOffset: this.videoListController.directoryOffsets.get(key) ?? 0, animation: false })
    }, 32)
  }

  private videoClickEffect(video: VideoMetadata | undefined): ClickEffect | undefined {
    return video ? { level: ClickEffectLevel.LIGHT, scale: 0.9 } : undefined
  }
}
