import MediaSortUtil from '../../utils/MediaSortUtil'
import { VideoList, VideoListController } from './VideoItemComponent'
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import { SideBarController } from '../SideBarComponent/SideBar'
import { motion } from '@kit.MultimodalAwarenessKit'
import {
  ButtonFancyModifier,
  DefaultDialogShadow,
  MenuFancyModifier,
  SearchShadowModifier,
  SymbolGlyphFancyModifier
} from '../../common/AttributeModifierConfig'
import { PathUtils } from '../../utils/PathUtils'
import DataSyncUtil from '../../utils/DataSyncUtil'
import { FileFolderDataSource } from '../../utils/DataUtil'
import VideoUtils from '../../utils/VideoUtil'
import FileFolderUtil from '../../utils/FileFolderUtil'
import { FileFolder } from '../../interfaces/FileFolderInterface'
import { BatchVideoDeleteDialog } from '../Dialog/BatchVideoDeleteDialog'
import { DeleteType } from '../../common/enum/DeleteType'
import { SortField } from '../../common/enum/SortField'
import NavigationAddress from '../../common/NavigationCommon'
import Preferences from '../../database/Preferences'
import { FolderOperator } from '../../database/VideoMetaData'
import { XAnimation } from '../../utils/AnimationUtil'
import { DebounceUtil } from '../../utils/DebounceUtil'
import { SafeHeight, Setting } from '../../utils/ObservedUtil'
import SelectFileUtil from '../../utils/SelectFileUtil'
import ToolsUtil from '../../utils/ToolsUtil'
import { FileFolderMenu } from '../FileFolderComponent/FileFolderMenu'
import { MaskComponent } from '../SideBarComponent/MaskComponent'
import { SearchComponent } from './SearchComponent'
import { SortMenuComponent } from '../common/SortMenuComponent'
import { SymbolGlyphModifier } from '@kit.ArkUI'

@ComponentV2
export struct VideoView {
  searchController: SearchController = new SearchController()
  @Param loading: boolean = false
  @Param holdingHand: motion.HoldingHandStatus | null = null
  @Local is_edit: boolean = false
  @Local searchBarHidden: boolean = false
  @Param searchValue: string = ''
  @Local _searchValue: string = ''
  @Param videoListController: VideoListController = new VideoListController()
  @Consumer() file_folder_list: FileFolder[] = []
  @Consumer() sideBarController: SideBarController = new SideBarController()
  @Consumer('pathStack') pathStack: NavPathStack = new NavPathStack()
  @Consumer() fileFolderSource: FileFolderDataSource = new FileFolderDataSource([])
  @Local delMultipleList: VideoMetadata[] = DataSyncUtil.delMultipleList
  batchDelConfirmDialog: CustomDialogController = new CustomDialogController({
    builder: BatchVideoDeleteDialog({
      videoList: this.delMultipleList,
      confirm: async (deleteType: DeleteType) => {
        try {
          if (this.delMultipleList.length > 0) {
            await FileFolderUtil.delVideosFileFolder(PathUtils.appContext!, this.videoListController,
              this.fileFolderSource, deleteType)
          }
        } finally {
          VideoUtils.refresh(this.videoListController, this.fileFolderSource, this.videoListController.folder)
          this.videoListController.closeMultipleChoose()
        }
      }
    }), cornerRadius: 20, shadow: DefaultDialogShadow
  })
  @Local currentSortField: SortField | '' = ''
  @Local currentSortAsc: boolean = true
  @Local pinyinSort: boolean = true
  @Param scrollToFolderDate: string = ''
  private passwd: string = 'passwd'
  private breadcrumbScroller: Scroller = new Scroller()
  private searchBarFolderKey: string = ''
  private readonly FOLDER_TAB_MIN_WIDTH: number = 64
  private readonly FOLDER_TAB_HEIGHT: number = 32
  @Event onSearchValueChange: (v: string) => void = () => {
  }

  @Monitor('delMultipleList')
  SyncDelMultipleList() {
    DataSyncUtil.delMultipleList = this.delMultipleList
  }

  @Event onScrollToFolderDateChange: (v: string) => void = () => {
  }

  @Monitor('scrollToFolderDate')
  onFolderChanged() {
    if (this.videoListController.directoryMode) {
      this.breadcrumbScroller.scrollEdge(Edge.End)
      return
    }
    const treeFolders = FileFolderUtil.flattenTree(this.file_folder_list)
    const newIndex = treeFolders.findIndex(f => f.date === this.scrollToFolderDate)
    if (newIndex !== -1) {
      this.scrollToCurrentFolder(newIndex)
    }
  }

  aboutToAppear(): void {
    this._searchValue = this.searchValue
    this.onSearchBarContextChanged()
    const savedField = Preferences.getSortField(PathUtils.appContext!)
    if (savedField === SortField.NAME || savedField === SortField.DATETIME || savedField === SortField.TIME ||
      savedField === SortField.RECENT_PLAY) {
      this.currentSortField = savedField as SortField
    }
    this.currentSortAsc = Preferences.getSortAsc(PathUtils.appContext!)
    this.pinyinSort = Preferences.getPinyinSort(PathUtils.appContext!)
  }

  @Monitor('searchValue')
  onSearchValueMonitor() {
    this._searchValue = this.searchValue
  }

  @Monitor('videoListController.folder', 'videoListController.directoryMode',
    'videoListController.directoryOverview', 'videoListController.videoMetaDataList', '_searchValue')
  onSearchBarContextChanged(): void {
    const folderKey = `${this.videoListController.folder.date}:${this.videoListController.directoryMode}:${this.videoListController.directoryOverview}`
    if (folderKey !== this.searchBarFolderKey ||
      (!this.videoListController.directoryMode && this.videoListController.videoDataSource.totalCount() === 0)) {
      this.searchBarHidden = false
    }
    this.searchBarFolderKey = folderKey
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      if (this.sideBarController.overlay &&
        this.sideBarController.visibility !== Visibility.Hidden &&
        this.sideBarController.mode === SideBarContainerType.Overlay) {
        MaskComponent({ sideBarController: this.sideBarController })
      }
      VideoList({
        videoListController: this.videoListController,
        directoryVideos: this.videoListController.videoDataSource.data,
        directoryLayout: Setting.listDisplayMode,
        directoryCoverLayout: Setting.coverLayout,
        holdingHand: this.holdingHand,
        delMultipleList: this.delMultipleList,
        onDelMultipleListChange: (v: VideoMetadata[]) => {
          this.delMultipleList = v
        },
        searchValue: this._searchValue,
        onSearchValueChange: (v: string) => {
          this._searchValue = v
          this.onSearchValueChange(v)
        },
        currentSortField: this.currentSortField,
        currentSortAsc: this.currentSortAsc,
        pinyinSort: this.pinyinSort,
        searchBarHidden: this.searchBarHidden,
        onScrollDirectionChange: (isUp: boolean) => {
          if (this.is_edit || this.searchBarHidden === isUp) {
            return
          }
          animateToImmediately({ duration: 300, curve: Curve.Ease }, () => {
            this.searchBarHidden = isUp
          })
        },
        onDirectoryFolderChange: (date: string) => {
          this.onScrollToFolderDateChange(date)
        }
      })

      if (!this.videoListController.directoryMode && !this.loading &&
        this.videoListController.openSideBarTip(this._searchValue)) {
        Column() {
          Text($r('app.string.nothing')).fontSize(25).fontWeight(FontWeight.Bold)
          Text($r('app.string.open_side_bar_tip'))
            .fontSize(15)
            .textAlign(TextAlign.Center)
            .fontWeight(FontWeight.Lighter)
            .margin({ top: 20 })
        }
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .animation({ duration: 150, curve: Curve.Ease })
      } else if (!this.videoListController.directoryMode && !this.loading &&
        this.videoListController.isSearchEmpty(this._searchValue)) {
        Column() {
          Text($r('app.string.search_no_match_title')).fontSize(25).fontWeight(FontWeight.Bold)
          Text($r('app.string.search_no_match_in_folder', this._searchValue))
            .fontSize(15)
            .textAlign(TextAlign.Center)
            .fontWeight(FontWeight.Lighter)
            .margin({ top: 20 })
        }
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .animation({ duration: 150, curve: Curve.Ease })
      }
      if (this.canShowRecentPlayButton()) {
        this.RecentPlayButtonBuilder()
      }
      this.TopToolBarBuilder()
    }.width('100%')
  }

  @Builder
  TopToolBarBuilder() {
    Column() {
      Row({ space: 15 }) {
        if (!this.is_edit) {
          Button({ type: ButtonType.Circle, stateEffect: true }) {
            SymbolGlyph(
              this.sideBarController.isShow ? $r('sys.symbol.indentation_left') : $r('sys.symbol.close_sidebar'))
              .attributeModifier(new SymbolGlyphFancyModifier(25, '', ''))
          }
          .attributeModifier(new ButtonFancyModifier(40, 40))
          .animation({ duration: 300, curve: Curve.Ease })
          .onClick(() => {
            if (this.sideBarController.isShow) {
              this.sideBarController.close(true)
            } else {
              this.sideBarController.open()
            }
            if (this.sideBarController.mode === SideBarContainerType.Embed) {
              Preferences.saveEmbedSidebarVisible(PathUtils.appContext!, this.sideBarController.isShow)
            }
          })
          .attributeModifier(new SearchShadowModifier())
          .transition(XAnimation.getAnimation('left', 0, false))
        }

        SearchComponent({
          controller: this.searchController,
          searchValue: this._searchValue,
          onSearchValueChange: (v: string) => {
            this._searchValue = v
            this.onSearchValueChange(v)
          },
          onChange: () => {
            DebounceUtil.debounce('search', () => {
              if (this._searchValue === '') {
                const videoMetaDataList: VideoMetadata[] =
                  FolderOperator.getFolderByDate(this.videoListController.folder.date)!.video_list
                this.videoListController.videoDataSource.updateData(videoMetaDataList)
                this.videoListController.updateData(this.videoListController.videoDataSource,
                  this.videoListController.folder)
              } else {
                const videoMetaDataList: VideoMetadata[] =
                  SelectFileUtil.getItemFromSearch(
                    FolderOperator.getFolderByDate(this.videoListController.folder.date)!
                      .video_list, this._searchValue)
                this.videoListController.videoDataSource.updateData(videoMetaDataList)
                this.videoListController.updateData(this.videoListController.videoDataSource,
                  this.videoListController.folder)
              }
            }, 300)
          },
          onSubmit: (value: string) => {
            if (value == '') {
              if (!this.videoListController.directoryMode && this.videoListController.videoMetaDataList.length == 0) {
                ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.add_video_first').id))
                return
              }
              this.searchController.stopEditing()
              return
            }
            if (value == this.passwd) {
              this.pathStack.pushPathByName(NavigationAddress.PRIVACY_SPACE, null)
              this._searchValue = ''
              this.onSearchValueChange('')
              return
            }
            if (!this.videoListController.directoryMode && this.videoListController.videoMetaDataList.length == 0) {
              ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.add_video_first').id))
            }
          },
          onEditChange: (isEditing: boolean) => {
            XAnimation.runWithAnimation(() => {
              this.is_edit = isEditing
            })
            if (isEditing && this.searchBarHidden) {
              animateToImmediately({ duration: 300, curve: Curve.Ease }, () => {
                this.searchBarHidden = false
              })
            }
          },
          onSearchFocus: () => {
            this.passwd = Preferences.getPassword(PathUtils.appContext!)
          }
        })

        if (!this.is_edit) {
          Button({ type: ButtonType.Circle, stateEffect: true }) {
            SymbolGlyph($r('sys.symbol.text_and_arrow_down'))
              .attributeModifier(new SymbolGlyphFancyModifier(25, '', ''))
          }
          .attributeModifier(new ButtonFancyModifier(40, 40))
          .bindMenu(this.SortMenuBuilder,
            {
              backgroundBlurStyle: BlurStyle.Regular,
              hapticFeedbackMode: HapticFeedbackMode.ENABLED
            })
          .attributeModifier(new SearchShadowModifier())
          .transition(XAnimation.getAnimation('right', 0, false))

          if (this.videoListController.multipleChooseState === Visibility.Visible) {
            Button({ type: ButtonType.Circle, stateEffect: true }) {
              SymbolGlyph($r('sys.symbol.checkmark_square_on_square'))
                .attributeModifier(new SymbolGlyphFancyModifier(25, '', ''))
            }
            .attributeModifier(new ButtonFancyModifier(40, 40))
            .bindMenu(this.SelectItemMenuBuilder,
              {
                backgroundBlurStyle: BlurStyle.Regular,
                hapticFeedbackMode: HapticFeedbackMode.ENABLED
              })
            .attributeModifier(new SearchShadowModifier())
            .transition(XAnimation.getAnimation('right', 0, false))
          }
        }
      }
      .width('100%')

      this.FolderNavigationBuilder()
    }
    .width('100%')
    .padding({ top: SafeHeight.topSafeHeight, left: 16, right: 16 })
    .translate({ y: this.searchBarHidden ? -(SafeHeight.topSafeHeight + 100) : 0 })
    .animation({ duration: 300, curve: Curve.Ease })
  }

  private toggleDirectoryView(): void {
    if (this.loading || this.videoListController.directoryTransitioning ||
      this.videoListController.multipleChooseState === Visibility.Visible) { return }
    this.searchBarHidden = false
    this.videoListController.setDirectoryView(!this.videoListController.directoryMode)
  }

  @Builder
  DirectoryBreadcrumbBuilder() {
    Scroll(this.breadcrumbScroller) {
      Row({ space: 8 }) {
        Button($r('app.string.directory_all_folders'), { type: ButtonType.Normal })
          .fontSize(13).fontColor(this.videoListController.directoryOverview ?
            $r('app.color.main_color') : $r('app.color.text_color'))
          .backgroundColor(Color.Transparent).padding({ left: 4, right: 4 })
          .onClick(() => { this.videoListController.requestDirectory(null) })
        if (!this.videoListController.directoryOverview) {
          Repeat<FileFolder>(FileFolderUtil.getFolderPathChain(PathUtils.appContext!,
            this.videoListController.folder?.date ?? ''))
            .each((folder: RepeatItem<FileFolder>) => {
              Row({ space: 8 }) {
                SymbolGlyph($r('sys.symbol.chevron_right'))
                  .fontSize(10).fontColor([$r('sys.color.font_tertiary')])
                Button(folder.item.name, { type: ButtonType.Normal })
                  .fontSize(13).fontColor(this.videoListController.folder?.date === folder.item.date ?
                    $r('app.color.main_color') : $r('app.color.text_color'))
                  .backgroundColor(Color.Transparent).padding({ left: 4, right: 4 })
                  .constraintSize({ maxWidth: 160 })
                  .onClick(() => { this.videoListController.requestDirectory(folder.item.date) })
              }.height(36)
            })
            .key((folder: FileFolder) => folder.date + folder.name)
        }
      }.height(36).justifyContent(FlexAlign.Start)
    }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%')
    .align(Alignment.Start)
  }

  @Builder
  FolderNavigationBuilder() {
    Row({ space: 8 }) {
      Button({ type: ButtonType.Circle }) {
        SymbolGlyph($r('sys.symbol.doc_plaintext_and_folder'))
          .fontSize(19).fontColor([this.videoListController.directoryMode ?
            $r('sys.color.white') : $r('app.color.text_color')])
      }
      .width(32).height(32)
      .backgroundColor(this.videoListController.directoryMode ? $r('app.color.main_color') :
        $r('app.color.search_component_blur'))
      .accessibilityText(this.videoListController.directoryMode ? $r('app.string.directory_disable') :
        $r('app.string.directory_enable'))
      .enabled(!this.loading && !this.videoListController.directoryTransitioning &&
        this.videoListController.multipleChooseState !== Visibility.Visible)
      .onClick(() => { this.toggleDirectoryView() })
      Row() {
        if (this.videoListController.directoryMode) {
          this.DirectoryBreadcrumbBuilder()
        } else if (Setting.showToast && this.file_folder_list.length > 1) {
          this.FolderTabsBuilder()
        } else {
          Text(this.videoListController.folder?.name ?? '')
            .fontSize(13).fontColor($r('app.color.text_color'))
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }.layoutWeight(1).height(36).alignItems(VerticalAlign.Center)

    }.width('100%').height(36).alignItems(VerticalAlign.Center).margin({ top: 4 })
  }

  @Builder
  SortMenuBuilder() {
    SortMenuComponent({
      currentSortField: this.currentSortField,
      currentSortAsc: this.currentSortAsc,
      pinyinSort: this.pinyinSort,
      pinyinSortField: SortField.NAME,
      items: [
        {
          field: SortField.RECENT_PLAY,
          icon: $r('sys.symbol.play_circle'),
          textResource: $r('app.string.sort_by_recent_play'),
          onAction: (): void => this.handleSort(SortField.RECENT_PLAY, false)
        },
        {
          field: SortField.DATETIME,
          icon: $r('sys.symbol.calendar'),
          textResource: $r('app.string.sort_by_datetime'),
          onAction: (): void => this.handleSort(SortField.DATETIME, false)
        },
        {
          field: SortField.TIME,
          icon: $r('sys.symbol.clock'),
          textResource: $r('app.string.sort_by_time'),
          onAction: (): void => this.handleSort(SortField.TIME, false)
        },
        {
          field: SortField.NAME,
          icon: $r('sys.symbol.textformat'),
          textResource: $r('app.string.sort_by_name'),
          onAction: (): void => this.handleSort(SortField.NAME, true)
        }
      ],
      onPinyinSortChange: (value: boolean): void => this.handlePinyinSortChange(value)
    })
  }

  @Builder
  SelectItemMenuBuilder() {
    Menu() {
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.xmark')),
        content: $r('app.string.cancel')
      })
        .onClick(() => {
          this.videoListController.closeMultipleChoose()
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.checkmark_square_on_square')),
        content: this.delMultipleList.length === this.videoListController.videoMetaDataList.length &&
          this.videoListController.videoMetaDataList.length > 0 ? $r('app.string.deselect_all') : $r('app.string.select_all')
      })
        .onClick(() => {
          if (this.delMultipleList.length === this.videoListController.videoMetaDataList.length &&
            this.videoListController.videoMetaDataList.length > 0) {
            this.delMultipleList = []
          } else {
            this.delMultipleList = [...this.videoListController.videoMetaDataList]
          }
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.trash_fill')),
        content: $r('app.string.delete_selected')
      })
        .onClick(() => {
          this.batchDelConfirmDialog.open()
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.arrow_right_folder_circle')),
        content: $r('app.string.move_to_folder'),
        builder: (): void => this.MoveToFolderMenuBuilder()
      })
    }.attributeModifier(new MenuFancyModifier())
  }

  @Builder
  MoveToFolderMenuBuilder() {
    FileFolderMenu({ video_item: undefined })
  }

  @Builder
  FolderTabsBuilder() {
    List({ scroller: this.breadcrumbScroller, space: 8 }) {
      Repeat<FileFolder>(FileFolderUtil.flattenTree(this.file_folder_list))
        .each((repeatItem: RepeatItem<FileFolder>) => {
          ListItem() {
            Row() {
              Text(repeatItem.item.name)
                .fontSize(13)
                .fontWeight(this.videoListController?.folder?.date === repeatItem.item.date ? FontWeight.Bold :
                  FontWeight.Medium)
                .fontColor(this.videoListController?.folder?.date === repeatItem.item.date ?
                  $r('sys.color.white') : $r('app.color.text_color'))
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .maxLines(1)
                .padding({ left: 16, right: 16 })
            }
            .backgroundEffect({ radius: 100 })
            .useEffect(true, EffectType.WINDOW_EFFECT)
            .backgroundColor(this.videoListController?.folder?.date === repeatItem.item.date ?
              $r('app.color.main_color') : $r('app.color.search_component_blur'))
            .height(this.FOLDER_TAB_HEIGHT)
            .constraintSize({ minWidth: this.FOLDER_TAB_MIN_WIDTH })
            .borderRadius(16)
            .justifyContent(FlexAlign.Center)
            .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
            .onClick(() => {
              if (this.videoListController.multipleChooseState === Visibility.Visible) {
                return
              }
              if (this.videoListController?.folder?.date !== repeatItem.item.date) {
                const treeFolders = FileFolderUtil.flattenTree(this.file_folder_list)
                const targetIndex = treeFolders.findIndex(f => f.date === repeatItem.item.date)
                if (targetIndex !== -1) {
                  this.switchToFolderByIndex(targetIndex)
                }
              }
            })
          }.height(this.FOLDER_TAB_HEIGHT)
        })
        .key((item: FileFolder) => item.date)
        .virtualScroll()
    }
    .padding({ right: 4 })
    .width('100%')
    .height(36)
    .listDirection(Axis.Horizontal)
    .alignListItem(ListItemAlign.Center)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  private handleSort(field: SortField, defaultAsc: boolean) {
    if (this.currentSortField === field) {
      this.currentSortAsc = !this.currentSortAsc
    } else {
      this.currentSortField = field
      this.currentSortAsc = defaultAsc
    }
    Preferences.saveSortField(PathUtils.appContext!, this.currentSortField)
    Preferences.saveSortAsc(PathUtils.appContext!, this.currentSortAsc)
    const currentFolderDate = this.videoListController.folder?.date
    const latestFolders = Preferences.getFileFolder(PathUtils.appContext!)
    const latestFolder = currentFolderDate
      ? latestFolders.find(f => f.date === currentFolderDate) ?? latestFolders[0]
      : latestFolders[0]
    latestFolder.video_list = ToolsUtil.sortBy(PathUtils.appContext!, latestFolder.video_list,
      latestFolder, field, this.currentSortAsc, this.pinyinSort)
    VideoUtils.refresh(this.videoListController, this.fileFolderSource, latestFolder)
  }

  private handlePinyinSortChange(value: boolean) {
    this.pinyinSort = value
    Preferences.savePinyinSort(PathUtils.appContext!, this.pinyinSort)
    if (this.currentSortField === SortField.NAME) {
      const currentFolderDate = this.videoListController.folder?.date
      const latestFolders = Preferences.getFileFolder(PathUtils.appContext!)
      const latestFolder = currentFolderDate
        ? latestFolders.find(f => f.date === currentFolderDate) ?? latestFolders[0]
        : latestFolders[0]
      latestFolder.video_list = ToolsUtil.sortBy(PathUtils.appContext!, latestFolder.video_list,
        latestFolder, SortField.NAME, this.currentSortAsc, this.pinyinSort)
      VideoUtils.refresh(this.videoListController, this.fileFolderSource, latestFolder)
    }
  }

  /**
   * 通过索引切换文件夹
   */
  private switchToFolderByIndex(index: number): void {
    const treeFolders = FileFolderUtil.flattenTree(this.file_folder_list)
    const result = VideoUtils.switchFolder(
      index, treeFolders, this.videoListController, this.fileFolderSource, this._searchValue
    )
    if (!result) {
      return
    }
    this.file_folder_list = result.refreshedFolders
    this.scrollToCurrentFolder(index)
    this.sideBarController.closeIfOverlay(true)
    this.onScrollToFolderDateChange(result.currentFolder!.date)
  }

  /**
   * 滚动面包屑使当前文件夹可见
   */
  private scrollToCurrentFolder(index: number): void {
    // 计算目标位置，使当前文件夹居中显示
    const estimatedItemWidth = 80
    const spacing = 8
    const targetOffset = Math.max(0, index * (estimatedItemWidth + spacing) - 100)
    XAnimation.runWithAnimation(() => {
      this.breadcrumbScroller.scrollTo({
        xOffset: targetOffset,
        yOffset: 0,
        animation: { duration: 200, curve: Curve.Ease }
      })
    })
  }

  /**
   * 右下角「最近播放」悬浮按钮的显示条件：非导入中、非搜索/多选状态、且当前文件夹有视频
   */
  private canShowRecentPlayButton(): boolean {
    return !this.videoListController.directoryOverview && !this.loading && !this.is_edit && this._searchValue.length === 0 &&
      this.videoListController.multipleChooseState !== Visibility.Visible &&
      this.videoListController.videoMetaDataList.length > 0
  }

  /**
   * 播放当前文件夹里最近一次实际播放时间最新的视频
   */
  private async playMostRecentlyPlayedVideo(): Promise<void> {
    const currentFolder = this.videoListController.folder
    const latestFolders = Preferences.getFileFolder(PathUtils.appContext!)
    const folder = currentFolder
      ? latestFolders.find(f => f.date === currentFolder.date) ?? latestFolders[0]
      : latestFolders[0]
    const videoList: VideoMetadata[] = folder?.video_list ?? []
    const target = MediaSortUtil.getMostRecentlyPlayed(videoList)
    if (!target) {
      ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.no_play_record_in_folder').id))
      return
    }
    if (ToolsUtil.isNetworkUrl(target.uri) || await SelectFileUtil.isFileExist(target.uri, true)) {
      await ToolsUtil.routerWhere(this.pathStack, target, videoList)
      return
    }
    ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.invalid_file_reimport').id))
  }

  @Builder
  RecentPlayButtonBuilder() {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph($r('sys.symbol.play_circle'))
        .attributeModifier(new SymbolGlyphFancyModifier(26, '', ''))
    }
    .attributeModifier(new ButtonFancyModifier(52, 52))
    .attributeModifier(new SearchShadowModifier())
    .position({ right: 20, bottom: (SafeHeight.bottomSafeHeight + 16) * 2 })
    .onClick(async () => {
      await this.playMostRecentlyPlayedVideo()
    })
  }
}
