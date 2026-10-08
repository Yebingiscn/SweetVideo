import ImageFileUtil from '../../utils/ImageFileUtil'
import MediaSortUtil from '../../utils/MediaSortUtil'
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import { FileFolderDataSource, VideoDataSource } from '../../utils/DataUtil'
import { PathUtils } from '../../utils/PathUtils'
import ToolsUtil from '../../utils/ToolsUtil'
import SelectFileUtil from '../../utils/SelectFileUtil'
import { SortField } from '../../common/enum/SortField'
import DataSyncUtil from '../../utils/DataSyncUtil'
import { VideoDetailSheetBuilder } from '../../component/Dialog/VideoDetailDialog'
import { DefaultDialogShadow, MenuFancyModifier } from '../../common/AttributeModifierConfig'
import { RenameDialog } from '../../component/Dialog/RenameDialog'
import { FileFolder } from '../../interfaces/FileFolderInterface'
import { SideBarController } from '../SideBarComponent/SideBar'
import { VideoMetaDataOperator } from '../../database/VideoMetaData'
import VideoUtils from '../../utils/VideoUtil'
import { InfoConfirmDialog } from '../../component/Dialog/InfoConfirmDialog'
import FileFolderUtil from '../../utils/FileFolderUtil'
import { VideoDeleteDialog } from '../Dialog/VideoDeleteDialog'
import { BatchVideoDeleteDialog } from '../Dialog/BatchVideoDeleteDialog'
import { DeleteType } from '../../common/enum/DeleteType'
import { CoverLayoutMode, ListDisplayMode } from '../../common/enum/DisplayMode'
import { motion } from '@kit.MultimodalAwarenessKit'
import { salmonLogger } from 'salmonlogger'
import { DELAY_JUMP_TO_PLAYER, FULL_ALPHABET } from '../../common/Constants'
import Preferences from '../../database/Preferences'
import { XAnimation } from '../../utils/AnimationUtil'
import IntellectualGripPostureUtil from '../../utils/IntellectualGripPostureUtil'
import { SafeHeight, Setting } from '../../utils/ObservedUtil'
import SubtitleUtil from '../../utils/SubtitleUtil'
import VideoOperateUtil from '../../utils/VideoOperateUtil'
import WantProcess from '../../utils/WantProcessUtil'
import ShareUtil from '../../utils/ShareUtil'
import { FileFolderMenu } from '../FileFolderComponent/FileFolderMenu'
import { ScrollBarBuilder } from './ScrollBarBuilder'
import VideoCardItem from './VideoCardItemComponent'
import { VideoItemPreviewBuilder } from './VideoItemPreviewBuilder'
import VideoListItem from './VideoListItemComponent'
import { Binding, curves, SymbolGlyphModifier, UIUtils } from '@kit.ArkUI'
import KnockShareUtil from '../../utils/KnockShareUtil'
import FolderDirectory, { DirectoryEntry } from '../../utils/FolderDirectory'
import accessibility from '@ohos.accessibility'
import DirectoryHero, { DirectoryRect } from '../../utils/DirectoryHero'

@ObservedV2
export class VideoListController {
  @Trace public folder: FileFolder
  @Trace homeReady: boolean = false
  @Trace directoryMode: boolean = false
  @Trace directoryOverview: boolean = false
  @Trace directoryTransitioning: boolean = false
  @Trace directoryTarget: string = ''
  @Trace directoryRequest: number = 0
  listScroller: ListScroller = new ListScroller()
  waterFlowScroller: ListScroller = new ListScroller()
  directoryScroller: ListScroller = new ListScroller()
  directoryWaterFlowScroller: ListScroller = new ListScroller()
  directoryOffsets: Map<string, number> = new Map()
  directoryFirstIndexes: Map<string, number> = new Map()
  @Trace videoMetaDataList: VideoMetadata[]
  @Trace multipleChooseState: Visibility = Visibility.None
  @Trace listLine: number = 1
  @Trace videoDataSource: VideoDataSource
  private listeners: DataChangeListener[] = []

  constructor(folder?: FileFolder) {
    if (folder) {
      this.folder = folder
    } else {
      this.folder = Preferences.getFileFolder(PathUtils.appContext!)[0]
    }
    this.videoMetaDataList = this.folder?.video_list || []
    this.videoDataSource = new VideoDataSource(this.videoMetaDataList)
  }

  getActiveScroller(): ListScroller {
    if (this.directoryMode) {
      return Setting.listDisplayMode === ListDisplayMode.CARD_DISPLAY ? this.directoryWaterFlowScroller :
        this.directoryScroller
    }
    return Setting.listDisplayMode === ListDisplayMode.LIST_DISPLAY ? this.listScroller : this.waterFlowScroller
  }

  setDirectoryView(enabled: boolean): void {
    if (this.directoryMode === enabled) { return }
    this.closeMultipleChoose()
    this.directoryOverview = false
    this.directoryMode = enabled
    Preferences.saveDirectoryView(PathUtils.appContext!, enabled)
  }

  requestDirectory(date: string | null): void {
    if (!this.directoryMode || this.directoryTransitioning || this.multipleChooseState === Visibility.Visible) {
      return
    }
    this.directoryTarget = date ?? ''
    this.directoryRequest++
  }

  requestDirectoryBack(): void {
    if (!this.directoryOverview) {
      this.requestDirectory(this.folder?.parent_date ?? null)
    }
  }

  openSideBarTip(searchValue: string = ''): boolean {
    // 如果有搜索值但结果为空，是搜索无结果，不显示提示
    if (searchValue.length > 0) {
      return false
    }
    // 文件夹真正为空时显示提示
    if (this.videoDataSource.totalCount() == 0) {
      return true
    }
    return false
  }

  /**
   * 检查是否是搜索无结果状态
   */
  isSearchEmpty(searchValue: string): boolean {
    // 有搜索值且结果为空
    return searchValue.length > 0 && this.videoDataSource.totalCount() == 0
  }

  // 公共方法实现
  registerDataChangeListener(listener: DataChangeListener): void {
    this.listeners.push(listener)
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const index = this.listeners.indexOf(listener)
    if (index >= 0) {
      this.listeners.splice(index, 1)
    }
  }

  updateData(videoDataSource: VideoDataSource | undefined, folder: FileFolder): void {
    this.folder = folder
    this.videoMetaDataList = folder.video_list
    if (videoDataSource) {
      this.videoDataSource.updateData(videoDataSource.getAllData())
    } else {
      this.videoDataSource.updateData(this.videoMetaDataList)
    }
    this.notifyDataReloaded()
  }

  public closeMultipleChoose() {
    XAnimation.runWithAnimation(() => {
      this.multipleChooseState = Visibility.None
    })
    DataSyncUtil.delMultipleList = []
  }

  public refresh(width: number, listDisplayMode: ListDisplayMode) {
    const base = Math.floor(Math.abs(width) / 500)
    let listLine = listDisplayMode === ListDisplayMode.LIST_DISPLAY ? base + 1 : base + 2
    this.listLine = Math.min(listLine, Setting.maxListLine)
    try {
      const scroller = this.getActiveScroller()
      if (scroller.currentOffset()?.yOffset == -90) {
        scroller.scrollEdge(Edge.Top)
      }
    } catch (_error) {
      // scroller 未绑定组件时 currentOffset 可能异常，忽略
    }
  }

  // 通知方法
  protected notifyDataReloaded(): void {
    this.listeners.forEach(listener => listener.onDataReloaded())
  }

  protected notifyDataDelete(index: number): void {
    this.listeners.forEach(listener => listener.onDataDelete(index))
  }
}

@ComponentV2
export struct VideoList {
  @Param searchValue: string = ''
  @Local _searchValue: string = ''
  @Param currentSortField: SortField | '' = ''
  @Param currentSortAsc: boolean = true
  @Param pinyinSort: boolean = true
  @Param searchBarHidden: boolean = false
  @Param holdingHand: motion.HoldingHandStatus | null = null
  @Param videoListController: VideoListController = new VideoListController()
  delConfirmDialog: CustomDialogController = new CustomDialogController({
    builder: VideoDeleteDialog({
      confirm: async (deleteType: DeleteType) => {
        try {
          await VideoMetaDataOperator.deleteItem(this.videoListController, this.fileFolderSource, deleteType,
            DataSyncUtil.editingVideo!)
        } catch (e) {
          ToolsUtil.showToast(`删除失败:${e}`)
        } finally {
          VideoUtils.refresh(this.videoListController, this.fileFolderSource, this.videoListController.folder)
        }
      }
    }), cornerRadius: 20, shadow: DefaultDialogShadow
  })
  // 显式接收结果数组，避免 @Monitor 依赖跨继承层的数据源路径。
  @Param directoryVideos: VideoMetadata[] = []
  @Param directoryLayout: ListDisplayMode = Setting.listDisplayMode
  @Param directoryCoverLayout: CoverLayoutMode = Setting.coverLayout
  @Local activeAlphabet: string[] = []
  @Local indexerSelected: number = 0
  // 累计修改封面时通知对应列表项重新读取封面文件
  @Local coverRefreshDate: string = ''
  @Local coverRefreshToken: number = 0
  @Consumer() fileFolderSource: FileFolderDataSource = new FileFolderDataSource([])
  editMetadataDialogController: CustomDialogController = new CustomDialogController({
    builder: RenameDialog({
      title: $r('app.string.rename'),
      renameTarget: 'video',
      preserveExtension: true,
      onConfirm: (title: string) => {
        const editingVideo = DataSyncUtil.editingVideo!
        const targetIndex = SelectFileUtil.getItemIndex(this.videoListController.videoMetaDataList, editingVideo)
        if (targetIndex === -1) {
          return
        }
        if (this.videoListController.videoMetaDataList.some((v, index) => index !== targetIndex &&
          v.title === title)) {
          return
        }
        const original = this.videoListController.videoMetaDataList[targetIndex]
        const updatedVideo: VideoMetadata = {
          uri: original.uri,
          title: title as string,
          artist: original.artist,
          album: original.album,
          date: original.date,
          size: original.size,
          cover_size: original.cover_size,
          has_video_track: original.has_video_track,
          time: original.time,
          last_play: original.last_play,
          last_played_at: original.last_played_at,
          format: original.format,
          video_size: original.video_size,
          bit_rate: original.bit_rate,
          hdr_type: original.hdr_type,
          audio_type: original.audio_type,
          frame_rate: original.frame_rate,
          start_time: original.start_time,
          end_time: original.end_time,
          end_time_is_duration: original.end_time_is_duration,
          external_subtitle_format: original.external_subtitle_format,
          pointA: original.pointA,
          pointB: original.pointB,
          subtitle_mode: original.subtitle_mode,
          subtitle_visible: original.subtitle_visible,
          subtitle_ai_asr_shown: original.subtitle_ai_asr_shown,
          subtitle_3d_mode: original.subtitle_3d_mode,
          subtitle_offset_millis: original.subtitle_offset_millis,
          subtitle_track_id: original.subtitle_track_id
        }
        this.videoListController.videoMetaDataList[targetIndex] = updatedVideo
        DataSyncUtil.editingVideo = updatedVideo
        this.videoListController.videoDataSource.updateItem(targetIndex, updatedVideo)
        FileFolderUtil.updateVideoInFileFolder(PathUtils.appContext!, this.videoListController, this.fileFolderSource)
      },
    }), cornerRadius: 20, shadow: DefaultDialogShadow
  })
  @Consumer() file_folder_list: FileFolder[] = []
  @Consumer() sideBarController: SideBarController = new SideBarController()
  searchController: SearchController = new SearchController()
  @Consumer('pathStack') pathStack: NavPathStack = new NavPathStack()
  @Param delMultipleList: VideoMetadata[] = []
  @Local _delMultipleList: VideoMetadata[] = []
  @Local batchDelList: VideoMetadata[] = []
  batchDelConfirmDialog: CustomDialogController = new CustomDialogController({
    builder: BatchVideoDeleteDialog({
      videoList: this.batchDelList,
      confirm: async (deleteType: DeleteType) => {
        try {
          DataSyncUtil.delMultipleList = this.batchDelList
          await FileFolderUtil.delVideosFileFolder(PathUtils.appContext!, this.videoListController,
            this.fileFolderSource, deleteType)
        } catch (e) {
          ToolsUtil.showToast(`删除失败:${e}`)
        } finally {
          VideoUtils.refresh(this.videoListController, this.fileFolderSource, this.videoListController.folder)
          this.videoListController.closeMultipleChoose()
        }
      }
    }), cornerRadius: 20, shadow: DefaultDialogShadow
  })
  @Local showDetailSheet: boolean = false
  @Local detailMetadata: VideoMetadata | undefined = undefined
  @Local directoryEntries: DirectoryEntry[] = []
  @Local directoryHero: DirectoryHero | undefined = undefined
  @Local directorySharedFolderDate: string = ''
  @Local homeEntranceProgress: number = 0
  private homeEntranceTimer: number | undefined = undefined
  private homeEntranceStarted: boolean = false
  private directoryIndex: FolderDirectory = new FolderDirectory([])
  private directoryRestoreTimer: number | undefined = undefined
  private directoryNavigationTimer: number | undefined = undefined
  private directoryHeroTimer: number | undefined = undefined
  private directoryAlive: boolean = false
  private directoryReduceMotion: boolean = false
  private outerScroller: Scroller = new Scroller()
  private _invalidItem: VideoMetadata | null = null
  invalidFileDialog: CustomDialogController = new CustomDialogController({
    builder: InfoConfirmDialog({
      textInfo: $r('app.string.invalid_file_clear_confirm'),
      confirm: async () => {
        await this.videoListController.videoDataSource.deleteUnExistFile(this._invalidItem!, this.videoListController,
          this.fileFolderSource)
      }
    }), cornerRadius: 20, shadow: DefaultDialogShadow
  })
  @Event onSearchValueChange: (v: string) => void = () => {
  }
  @Event onDelMultipleListChange: (v: VideoMetadata[]) => void = () => {
  }
  @Event onScrollDirectionChange: (isUp: boolean) => void = () => {
  }
  @Event onDirectoryFolderChange: (date: string) => void = () => {
  }

  aboutToAppear(): void {
    this._searchValue = this.searchValue
    this.directoryAlive = true
    this.directoryIndex = new FolderDirectory(this.file_folder_list)
    this.readDirectoryMotionPreference()
    this.rebuildDirectory()
    this.playHomeEntrance()
  }

  aboutToDisappear(): void {
    this.directoryAlive = false
    this.clearHomeEntranceTimer()
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

  private clearHomeEntranceTimer(): void {
    if (this.homeEntranceTimer !== undefined) {
      clearTimeout(this.homeEntranceTimer)
      this.homeEntranceTimer = undefined
    }
  }

  @Monitor('videoListController.homeReady', 'videoListController.directoryMode')
  playHomeEntrance(): void {
    if (!this.directoryAlive) { return }
    this.clearHomeEntranceTimer()
    this.readDirectoryMotionPreference()
    // 整个内容区以左上角为固定起点展开并淡入，不给虚拟列表项叠加入场动画。
    this.getUIContext().animateTo({ duration: 0 }, () => {
      this.homeEntranceProgress = this.videoListController.homeReady && this.directoryReduceMotion ? 1 : 0
    })
    if (!this.videoListController.homeReady || this.directoryReduceMotion) { return }
    this.homeEntranceTimer = setTimeout(() => {
      this.homeEntranceTimer = undefined
      if (!this.directoryAlive || !this.videoListController.homeReady) { return }
      this.homeEntranceStarted = true
      this.getUIContext().animateTo({ duration: 180, curve: Curve.Ease }, () => {
        this.homeEntranceProgress = 1
      })
    }, this.homeEntranceStarted ? 32 : 250)
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

  @Monitor('searchValue')
  onSearchValueMonitor() {
    this._searchValue = this.searchValue
  }

  @Monitor('delMultipleList')
  onDelMultipleListMonitor() {
    this._delMultipleList = [...this.delMultipleList]
  }

  @Monitor('videoListController.videoMetaDataList', 'currentSortField', 'currentSortAsc', 'pinyinSort')
  onVideoListChanged() {
    if (this.currentSortField === SortField.NAME && this.pinyinSort) {
      this.updateActiveAlphabet()
    } else {
      this.activeAlphabet = []
    }
  }

  build() {
    if (this.videoListController.directoryMode) {
      this.DirectoryBuilder()
    } else if (Setting.listDisplayMode === ListDisplayMode.LIST_DISPLAY) {
      Stack({
        alignContent: IntellectualGripPostureUtil.isLeftHoldHand(this.holdingHand) ? Alignment.TopStart :
          Alignment.TopEnd
      }) {
        List({ scroller: this.videoListController.listScroller }) {
          Repeat<VideoMetadata>(this.videoListController.videoDataSource.data)
            .each((repeatItem: RepeatItem<VideoMetadata>) => {
              ListItem() {
                VideoListItem({
                  item: repeatItem.item,
                  delMultipleList: this._delMultipleList,
                  coverRefreshDate: this.coverRefreshDate,
                  coverRefreshToken: this.coverRefreshToken,
                  coverTransition: !this.directoryReduceMotion
                })
              }
              .borderRadius(12)
              .backgroundColor(Setting.listItemBackgroundBlur ? undefined :
                (Setting.backgroundImageSrc.length > 0 ? $r('app.color.start_window_background_blur') :
                  $r('app.color.start_window_background')))
              .onAreaChange((_oldValue: Area, newValue: Area) => {
                KnockShareUtil.updateVideoRegion(repeatItem.item, newValue)
              })
              .onVisibleAreaChange([0], (visible: boolean) => {
                KnockShareUtil.setVideoRegionVisible(repeatItem.item.date, visible)
              })

              .margin({ bottom: 20 })
              .clickEffect(this.videoClickEffect(repeatItem.item))
              .transition(TransitionEffect.OPACITY.animation({ duration: 150, curve: Curve.Sharp }))
              .width(this.videoListController.listLine === 1 ? '100%' : '95%')
              .height('auto')
              .bindContextMenu(this.MenuBuilder(repeatItem.item), ResponseType.LongPress,
                this.videoMenuOptions(repeatItem.item, ResponseType.LongPress))
              .bindContextMenu(this.MenuBuilder(repeatItem.item), ResponseType.RightClick,
                this.videoMenuOptions(repeatItem.item, ResponseType.RightClick))
              .gesture(
                TapGesture({ count: 1, fingers: 1 })
                  .onAction(async () => {
                    await this.handleVideoItemTap(repeatItem.item)
                  })
              )
            })
            .key((item: VideoMetadata, _index: number) => item.date.toString() + item.last_play + item.title +
              item.size.toString() +
              this.videoListController.folder.name + item.time)
            .virtualScroll()
        }
        .clip(false)
        .padding({ left: 16, right: 16 })
        .contentStartOffset(
          SafeHeight.topSafeHeight + 100)
        .contentEndOffset(SafeHeight.bottomSafeHeight)
        .lanes(this.videoListController.listLine)
        .animation({ duration: 300, curve: Curve.Smooth })
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true }) // 滚动边缘效果
        .chainAnimation(true)
        .width('100%')
        .height('100%')
        .fadingEdge(true)
        .onAppear(() => {
          this.videoListController.listScroller.scrollEdge(Edge.Top)
        })
        .onScrollIndex((start: number) => {
          if (this.currentSortField === SortField.NAME && this.pinyinSort) {
            this.updateIndexerOnScroll(start)
          }
        })
        .onDidScroll((scrollOffset: number, scrollState: ScrollState) => {
          this.syncSearchBarVisible(scrollOffset, scrollState,
            this.videoListController.listScroller.currentOffset()?.yOffset, SafeHeight.topSafeHeight + 100)
        })
        .onReachStart(() => {
          this.onScrollDirectionChange(false)
        })

        if (this.currentSortField === 'name' && this.pinyinSort && this.activeAlphabet.length > 0) {
          AlphabetIndexer({ arrayValue: this.activeAlphabet, selected: this.indexerSelected })
            .onSelect((index: number) => {
              this.scrollToLetter(this.activeAlphabet[index])
            })
            .color($r('app.color.text_color'))
            .selectedColor($r('sys.color.white'))
            .popupColor($r('app.color.main_color'))
            .selectedBackgroundColor($r('app.color.main_color'))
            .popupBackground($r('app.color.start_window_background'))
            .itemSize(20)
            .height('100%')
            .margin(IntellectualGripPostureUtil.isLeftHoldHand(this.holdingHand) ? { left: 2 } : { right: 2 })
        }

        if (this.currentSortField !== SortField.NAME || !this.pinyinSort) {
          ScrollBarBuilder({
            videoListController: this.videoListController.listScroller,
            fileFolderLength: this.file_folder_list.length
          })
        }
      }
      .width('100%')
      .height('100%')
      .animation({ duration: 300, curve: Curve.Ease })
      .opacity(this.homeEntranceProgress)
      .scale({
        x: this.homeEntranceProgress, y: this.homeEntranceProgress,
        centerX: 16, centerY: SafeHeight.topSafeHeight + 100
      })
      .transition(TransitionEffect.IDENTITY)
      .bindSheet(this.showDetailSheet, this.DetailSheetBuilder, {
        detents: [SheetSize.LARGE],
        backgroundColor: $r('app.color.start_window_background'),
        blurStyle: BlurStyle.COMPONENT_ULTRA_THIN,
        showClose: true,
        onWillDismiss: () => {
          this.showDetailSheet = false
        }
      })
    } else {
      Stack({
        alignContent: IntellectualGripPostureUtil.isLeftHoldHand(this.holdingHand) ? Alignment.TopStart :
          Alignment.TopEnd
      }) {
        Scroll(this.outerScroller) {
          Column() {
            Blank().height(SafeHeight.topSafeHeight + 100)
            WaterFlow({
              scroller: this.videoListController.waterFlowScroller,
              layoutMode: WaterFlowLayoutMode.SLIDING_WINDOW
            }) {
              Repeat<VideoMetadata>(this.videoListController.videoDataSource.data)
                .each((repeatItem: RepeatItem<VideoMetadata>) => {
                  FlowItem() {
                    VideoCardItem({
                      item: repeatItem.item,
                      delMultipleList: this._delMultipleList,
                      coverRefreshDate: this.coverRefreshDate,
                      coverRefreshToken: this.coverRefreshToken,
                      coverTransition: !this.directoryReduceMotion
                    }).width('100%')
                  }
                  .backgroundColor(
                    Setting.listItemBackgroundBlur ? undefined :
                      (Setting.backgroundImageSrc.length > 0 ? $r('app.color.start_window_background_blur') :
                        $r('app.color.start_window_background')))

                  .borderRadius(12)
                  .width('100%')
                  .onAreaChange((_oldValue: Area, newValue: Area) => {
                    KnockShareUtil.updateVideoRegion(repeatItem.item, newValue)
                  })
                  .onVisibleAreaChange([0], (visible: boolean) => {
                    KnockShareUtil.setVideoRegionVisible(repeatItem.item.date, visible)
                  })
                  .clickEffect(this.videoClickEffect(repeatItem.item))
                  .bindContextMenu(this.MenuBuilder(repeatItem.item), ResponseType.LongPress,
                    this.videoMenuOptions(repeatItem.item, ResponseType.LongPress))
                  .bindContextMenu(this.MenuBuilder(repeatItem.item), ResponseType.RightClick,
                    this.videoMenuOptions(repeatItem.item, ResponseType.RightClick))
                  .gesture(
                    TapGesture({ count: 1, fingers: 1 })
                      .onAction(async () => {
                        await this.handleVideoItemTap(repeatItem.item)
                      })
                  )
                })
                .key((item: VideoMetadata, _index: number) => item.date + item.last_play + item.title +
                  item.size.toString() +
                  this.videoListController.folder.name + item.time)
                .virtualScroll()
            }
            .fadingEdge(true)
            .clip(false)
            .columnsTemplate('1fr '.repeat(this.videoListController.listLine).trim())
            .columnsGap(16) // 列间距
            .rowsGap(16) // 行间距
            .scrollBar(BarState.Off)
            .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
            .width('100%')
            .height('100%')
            .padding({ left: 16, right: 16 })
            .onAppear(() => {
              this.videoListController.waterFlowScroller.scrollEdge(Edge.Top)
            })
            .nestedScroll({
              scrollForward: NestedScrollMode.PARENT_FIRST,
              scrollBackward: NestedScrollMode.SELF_FIRST
            })
            .onScrollIndex((first: number) => {
              if (this.currentSortField === SortField.NAME && this.pinyinSort) {
                this.updateIndexerOnScroll(first)
              }
            })
            .onDidScroll((scrollOffset: number, scrollState: ScrollState) => {
              this.syncSearchBarVisible(scrollOffset, scrollState,
                (this.videoListController.waterFlowScroller.currentOffset()?.yOffset ?? 0) +
                (this.outerScroller.currentOffset()?.yOffset ?? 0))
            })
          }
          .clip(false)
        }
        .clip(false)
        .scrollBar(BarState.Off)
        .width('100%')
        .height('100%')
        .onDidScroll((_xOffset: number, yOffset: number, scrollState: ScrollState) => {
          this.syncSearchBarVisible(yOffset, scrollState,
            (this.outerScroller.currentOffset()?.yOffset ?? 0) +
            (this.videoListController.waterFlowScroller.currentOffset()?.yOffset ?? 0))
        })
        .onScrollEdge((edge: Edge) => {
          if (edge === Edge.Top) {
            this.onScrollDirectionChange(false)
          }
        })

        if (this.currentSortField === 'name' && this.pinyinSort && this.activeAlphabet.length > 0) {
          AlphabetIndexer({ arrayValue: this.activeAlphabet, selected: this.indexerSelected })
            .onSelect((index: number) => {
              this.scrollToLetter(this.activeAlphabet[index])
            })
            .color($r('app.color.text_color'))
            .selectedColor($r('sys.color.white'))
            .popupColor($r('app.color.main_color'))
            .selectedBackgroundColor($r('app.color.main_color'))
            .popupBackground($r('app.color.start_window_background'))
            .itemSize(20)
            .height('100%')
            .margin(IntellectualGripPostureUtil.isLeftHoldHand(this.holdingHand) ? { left: 2 } : { right: 2 })
        }

        if (this.currentSortField !== SortField.NAME || !this.pinyinSort) {
          ScrollBarBuilder({
            videoListController: this.videoListController.waterFlowScroller,
            fileFolderLength: this.file_folder_list.length
          })
        }
      }
      .width('100%')
      .height('100%')
      .animation({ duration: 300, curve: Curve.Ease })
      .opacity(this.homeEntranceProgress)
      .scale({
        x: this.homeEntranceProgress, y: this.homeEntranceProgress,
        centerX: 16, centerY: SafeHeight.topSafeHeight + 100
      })
      .transition(TransitionEffect.IDENTITY)
      .bindSheet(this.showDetailSheet, this.DetailSheetBuilder, {
        detents: [SheetSize.LARGE],
        backgroundColor: $r('app.color.start_window_background'),
        blurStyle: BlurStyle.COMPONENT_ULTRA_THIN,
        showClose: true,
        onWillDismiss: () => {
          this.showDetailSheet = false
        }
      })
    }
  }

  @Builder
  DirectoryCoverBuilder(folder: Binding<FileFolder>) {
    Stack({ alignContent: Alignment.BottomEnd }) {
      SymbolGlyph($r('sys.symbol.folder'))
        .fontSize(36)
        .fontColor([$r('app.color.main_color')])
        .width('100%')
        .height('100%')
      if (this.directoryIndex.coverDates(folder.value.date).length === 1) {
        Image(PathUtils.coverUri(this.directoryIndex.coverDates(folder.value.date)[0]))
          .draggable(false)
          .autoResize(false)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
      } else if (this.directoryIndex.coverDates(folder.value.date).length > 1) {
        // 按实际封面数量排布：两张左右分栏，三张左大右小，四张四格。
        Repeat<string>(this.directoryIndex.coverDates(folder.value.date))
          .each((cover: RepeatItem<string>) => {
            Image(PathUtils.coverUri(cover.item))
              .draggable(false)
              .autoResize(false)
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
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.search_component_blur'))
    .borderRadius(12)
    .clip(true)
  }

  @Builder
  DirectoryFolderListBuilder(folder: Binding<FileFolder>) {
    Row({ space: 16 }) {
      Stack() {
        this.DirectoryCoverBuilder(folder)
      }
      .width(this.directoryCoverLayout === CoverLayoutMode.VERTICAL_PLATE ? 85 : 110)
      .height(110)
      .borderRadius(12)
      .clip(true)
      .id(`directory-card:${folder.value.date}:cover`)
      .opacity(this.directoryHero?.folder.date === folder.value.date && this.directoryHero.contentHidden ? 0 : 1)

      Column({ space: 8 }) {
        Text(folder.value.name)
          .fontSize(16).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_color'))
          .width('100%').maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
          .id(`directory-card:${folder.value.date}:title`)
          .opacity(this.directoryHero?.folder.date === folder.value.date && this.directoryHero.contentHidden ? 0 : 1)
        Text($r('app.string.directory_item_count', folder.value.video_list.length,
          this.directoryIndex.childFolders(folder.value.date).length))
          .fontSize(12).fontColor($r('sys.color.font_secondary'))
          .width('100%')
          .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
          .id(`directory-card:${folder.value.date}:info`)
          .opacity(this.directoryHero?.folder.date === folder.value.date && this.directoryHero.contentHidden ? 0 : 1)
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .accessibilityText($r('app.string.directory_folder_accessibility', folder.value.name,
      folder.value.video_list.length, this.directoryIndex.childFolders(folder.value.date).length))
    .gesture(GestureGroup(GestureMode.Exclusive,
      LongPressGesture({ repeat: false }).onAction(() => {
      }),
      TapGesture().onAction(() => {
        this.videoListController.requestDirectory(folder.value.date)
      })))
  }

  @Builder
  DirectoryFolderCardBuilder(folder: Binding<FileFolder>) {
    Column({ space: 6 }) {
      Stack() {
        this.DirectoryCoverBuilder(folder)
      }
      .width('100%')
      .height(this.directoryLayout === ListDisplayMode.GRID_DISPLAY ? 100 : 200)
      .borderRadius(12)
      .clip(true)
      .id(`directory-card:${folder.value.date}:cover`)
      .opacity(this.directoryHero?.folder.date === folder.value.date && this.directoryHero.contentHidden ? 0 : 1)

      Text(folder.value.name)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_color'))
        .width('100%')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .id(`directory-card:${folder.value.date}:title`)
        .opacity(this.directoryHero?.folder.date === folder.value.date && this.directoryHero.contentHidden ? 0 : 1)
      Text($r('app.string.directory_item_count', folder.value.video_list.length,
        this.directoryIndex.childFolders(folder.value.date).length))
        .fontSize(12)
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .id(`directory-card:${folder.value.date}:info`)
        .opacity(this.directoryHero?.folder.date === folder.value.date && this.directoryHero.contentHidden ? 0 : 1)
    }
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
              Stack() {
                this.DirectoryCoverBuilder(UIUtils.makeBinding<FileFolder>(() => folder.item))
              }
              .width(72)
              .height(72)
              .borderRadius(12)
              .clip(true)
              .id('directory-header:cover')
              .opacity(this.directoryHero?.folder.date === folder.item.date && this.directoryHero.contentHidden ? 0 : 1)

              Column({ space: 6 }) {
                Text(folder.item.name)
                  .fontSize(22)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.text_color'))
                  .width('100%')
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .id('directory-header:title')
                  .opacity(this.directoryHero?.folder.date === folder.item.date && this.directoryHero.contentHidden ? 0 : 1)
                Text($r('app.string.directory_item_count', folder.item.video_list.length,
                  this.directoryIndex.childFolders(folder.item.date).length))
                  .fontSize(13).fontColor($r('sys.color.font_secondary'))
                  .width('100%').maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
                  .id('directory-header:info')
                  .opacity(this.directoryHero?.folder.date === folder.item.date && this.directoryHero.contentHidden ? 0 : 1)
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            }.width('100%')
          })
          .key((folder: FileFolder) => folder.date + folder.name)
      }
    }
    .width('100%').height(88).padding({ left: 16, right: 16, bottom: 16 })
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
        .bindContextMenu(this.MenuBuilder(video.value), ResponseType.LongPress,
          this.videoMenuOptions(video.value, ResponseType.LongPress))
        .bindContextMenu(this.MenuBuilder(video.value), ResponseType.RightClick,
          this.videoMenuOptions(video.value, ResponseType.RightClick))
    } else {
      VideoCardItem({
        item: video.value,
        delMultipleList: this._delMultipleList,
        coverRefreshDate: this.coverRefreshDate,
        coverRefreshToken: this.coverRefreshToken,
        coverTransition: false
      })
        .bindContextMenu(this.MenuBuilder(video.value), ResponseType.LongPress,
          this.videoMenuOptions(video.value, ResponseType.LongPress))
        .bindContextMenu(this.MenuBuilder(video.value), ResponseType.RightClick,
          this.videoMenuOptions(video.value, ResponseType.RightClick))
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
          await this.handleVideoItemTap(entry.item.video)
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
          await this.handleVideoItemTap(entry.item.video)
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

  @Builder
  DirectoryContentBuilder() {
    Column() {
      this.DirectoryHeaderBuilder()
      if (this.directoryEntries.length === 0) {
        Column({ space: 12 }) {
          SymbolGlyph($r('sys.symbol.folder')).fontSize(44).fontColor([$r('sys.color.font_tertiary')])
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
          .key((key: string) => key)
      }
    }
    .padding({ top: SafeHeight.topSafeHeight + 100 })
    .width('100%').height('100%')
  }

  @Builder
  DirectoryBuilder() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.DirectoryContentBuilder()
      if (this.directoryHero) {
        this.DirectoryHeroBuilder(this.directoryHero)
      }
    }
    .width('100%').height('100%').id('directory-motion-root')
    .opacity(this.homeEntranceProgress)
    .scale({
      x: this.homeEntranceProgress, y: this.homeEntranceProgress,
      centerX: 16, centerY: SafeHeight.topSafeHeight + 100
    })
    .transition(TransitionEffect.IDENTITY)
    .bindSheet(this.showDetailSheet, this.DetailSheetBuilder, {
      detents: [SheetSize.LARGE],
      backgroundColor: $r('app.color.start_window_background'),
      blurStyle: BlurStyle.COMPONENT_ULTRA_THIN,
      showClose: true,
      onWillDismiss: () => {
        this.showDetailSheet = false
      }
    })
  }

  @Builder
  DirectoryHeroBuilder(hero: DirectoryHero) {
    Stack({ alignContent: Alignment.TopStart }) {
      Stack() {
        this.DirectoryCoverBuilder(UIUtils.makeBinding<FileFolder>(() => hero.folder))
      }
      .width(hero.coverWidth)
      .height(hero.coverHeight)
      .position({ x: hero.coverX, y: hero.coverY })
      .borderRadius(12)
      .clip(true)

      Text(hero.folder.name)
        .fontSize(hero.titleFontSize)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_color'))
        .width(hero.titleWidth)
        .maxLines(hero.titleMaxLines)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .scale({ x: hero.titleScale, y: hero.titleScale, centerX: 0, centerY: 0 })
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
    .width('100%').height('100%').hitTestBehavior(HitTestMode.None).zIndex(2)
    .opacity(hero.contentHidden ? 1 : 0)
  }

  async clickItem(item: VideoMetadata | undefined, reverse: boolean = false) {
    if (!item || !this.videoListController.videoDataSource.getAllData().some(i => i.date == item?.date!)) {
      ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.data_loading_retry').id))
      this.videoListController.videoDataSource.refreshData(this.videoListController.folder)
      return
    }
    try {
      if (!this.videoListController.directoryMode && Setting.listDisplayMode === ListDisplayMode.LIST_DISPLAY) {
        this.videoListController.listScroller.closeAllSwipeActions()
      }
    } catch (error) {
      salmonLogger.addLog(this.pathStack.getAllPathName()[0],
        'closeAllSwipeActions failed: ' + error.code + ':' + error.message, true)
    }
    if (this._searchValue) {
      setTimeout(() => {
        AppStorage.setOrCreate('searchValue', this._searchValue)
        this._searchValue = ''
        this.onSearchValueChange('')
      }, 500)
    }
    if (ToolsUtil.isNetworkUrl(item.uri) || await SelectFileUtil.isFileExist(item.uri, true)) {
      await ToolsUtil.routerWhere(this.pathStack, item,
        this.videoListController.videoDataSource.getAllData(), reverse, false)
    } else {
      this._invalidItem = item
      this.invalidFileDialog.open()
    }
  }

  @Builder
  MenuBuilder(item: VideoMetadata | undefined) {
    Menu() {
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.rename')), content: $r('app.string.edit')
      })
        .onClick(() => {
          DataSyncUtil.editingVideo = item
          this.editMetadataDialogController.open()
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.picture')), content: $r('app.string.change_cover')
      })
        .onClick(() => {
          this.changeVideoCover(item)
        })
      // TODO 调整文件夹转移
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.arrow_right_folder_circle')),
        content: $r('app.string.move_to_folder'),
        builder: (): void => this.FileFolderMenuBuilder(item)
      })
      // TODO  调整删除的方法
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.trash_fill')), content: $r('app.string.delete')
      })
        .onClick(() => {
          if (this.videoListController.multipleChooseState === Visibility.Visible) {
            const isSelected = this._delMultipleList.some(v => v.uri === item?.uri)
            if (isSelected) {
              this.batchDelList = [...this._delMultipleList]
            } else {
              this.batchDelList = [...this._delMultipleList, item!]
              this._delMultipleList = this.batchDelList
              this.onDelMultipleListChange([...this._delMultipleList])
            }
            this.batchDelConfirmDialog.open()
          } else {
            DataSyncUtil.editingVideo = item!
            this.delConfirmDialog.open()
          }
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.checkmark_square_on_square')),
        content: this.videoListController.multipleChooseState === Visibility.Visible ?
          $r('app.string.exit_multiple_choice') :
          $r('app.string.multiple_choice')
      })
        .onClick(() => {
          XAnimation.runWithAnimation(() => {
            this.videoListController.multipleChooseState =
              this.videoListController.multipleChooseState == Visibility.None ? Visibility.Visible : Visibility.None
          })
          this._delMultipleList = item ? [item] : []
          this.onDelMultipleListChange([...this._delMultipleList])
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.play_round_triangle')),
        content: VideoOperateUtil.getPlayerName(Setting.defaultPlayerEngine, true)
      })
        .onClick(() => {
          setTimeout(async () => { //延迟跳转，确保弹窗关闭，防止系统误识别为子窗口导致播放器异常
            const videoItem = SelectFileUtil.getItem(this.videoListController.videoMetaDataList, item?.date!)
            await this.clickItem(videoItem, true)
          }, DELAY_JUMP_TO_PLAYER)
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.play_round_rectangle')),
        content: $r('app.string.menu_short_video_play')
      })
        .onClick(() => {
          setTimeout(async () => {
            const videoItem = SelectFileUtil.getItem(this.videoListController.videoMetaDataList, item?.date!)
            if (videoItem) {
              await ToolsUtil.routerToShortVideo(this.pathStack, videoItem,
                this.videoListController.videoDataSource.getAllData(), false)
            }
          }, DELAY_JUMP_TO_PLAYER)
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.info_circle')),
        content: $r('app.string.menu_detail')
      })
        .onClick(() => {
          setTimeout(() => {
            this.detailMetadata = item
            this.showDetailSheet = true
          }, DELAY_JUMP_TO_PLAYER)
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.textformat_size_square')),
        content: $r('app.string.menu_import_subtitle')
      })
        .onClick(async () => {
          DataSyncUtil.editingVideo = item!
          await SubtitleUtil.importOrDeleteSubtitleProcess(item!)
          const targetIndex = SelectFileUtil.getItemIndex(this.videoListController.videoMetaDataList, item!)
          if (targetIndex !== -1) {
            this.videoListController.videoMetaDataList[targetIndex] = item!
            // 使用增量更新而不是全量重载，提升性能
            this.videoListController.videoDataSource.updateItem(targetIndex, item!)
            FileFolderUtil.updateVideoInFileFolder(PathUtils.appContext!, this.videoListController,
              this.fileFolderSource)
          }
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.folder_badge_arrow_left')),
        content: $r('app.string.menu_open_file_location')
      })
        .onClick(async () => {
          await WantProcess.linkToVideoSource(item!.uri)
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.share')),
        content: $r('app.string.share')
      })
        .onClick(async () => {
          await ShareUtil.shareVideo(item!.uri, item!.title)
        })
    }.attributeModifier(new MenuFancyModifier())
  }

  @Builder
  DetailSheetBuilder() {
    VideoDetailSheetBuilder(this.detailMetadata)
  }

  @Builder
  FileFolderMenuBuilder(video_item: VideoMetadata | undefined) {
    FileFolderMenu({ video_item: video_item })
  }

  private directoryKey(): string {
    const folderKey = this.videoListController.directoryOverview ? '__directory_root__' :
      this.videoListController.folder?.date ?? ''
    return `${folderKey}:${this.directoryLayout}:${this.directoryCoverLayout}:${this.videoListController.listLine}`
  }

  private readDirectoryMotionPreference(): void {
    try {
      if (canIUse("SystemCapability.BarrierFree.Accessibility.Core")) {
        this.directoryReduceMotion = canIUse('SystemCapability.BarrierFree.Accessibility.Core') &&
          accessibility.isAnimationReduceEnabledSync()
      } else {
        this.directoryReduceMotion = true
      }
    } catch (_) {
      this.directoryReduceMotion = true
    }
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
    // 能力可缺失；系统要求减少动态效果时直接切换目录。
    this.readDirectoryMotionPreference()
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
    if (!this.directoryReduceMotion && sharedFolder && sourceCover && sourceTitle && sourceInfo) {
      this.directoryHero = new DirectoryHero(sharedFolder, sourceCover, sourceTitle, returning ? 22 : folderTitleFontSize,
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
          curve: curves.springMotion(0.4, 0.9),
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

  @Builder
  VideoPreviewBuilder(video: VideoMetadata) {
    VideoItemPreviewBuilder(video)
  }

  private videoMenuOptions(video: VideoMetadata, response: ResponseType): ContextMenuOptions {
    return {
      backgroundBlurStyle: BlurStyle.COMPONENT_ULTRA_THIN,
      preview: () => {
        this.VideoPreviewBuilder(video)
      },
      previewAnimationOptions: { scale: [1.0, 0.95], hoverScale: [1.0, 1.2] },
      layoutRegionMargin: { left: 16, right: 16, top: 16, bottom: 4 },
      hapticFeedbackMode: response === ResponseType.LongPress ? HapticFeedbackMode.ENABLED : undefined,
      mask: (Setting.listDisplayMode === ListDisplayMode.LIST_DISPLAY ? response === ResponseType.RightClick :
        response === ResponseType.LongPress) ? true : undefined
    }
  }

  private async handleVideoItemTap(video: VideoMetadata): Promise<void> {
    if (this.videoListController.directoryMode && this.videoListController.directoryTransitioning) {
      return
    }
    if (this.videoListController.multipleChooseState !== Visibility.Visible) {
      const currentVideo = Setting.listDisplayMode === ListDisplayMode.LIST_DISPLAY ?
        SelectFileUtil.getItem(this.videoListController.videoMetaDataList, video.date) : video
      await this.clickItem(currentVideo)
      return
    }
    if (this._delMultipleList.some(item => item.date === video.date)) {
      this._delMultipleList = this._delMultipleList.filter(item => item.date !== video.date)
    } else {
      this._delMultipleList = [...this._delMultipleList, video]
    }
    this.onDelMultipleListChange([...this._delMultipleList])
  }

  private updateActiveAlphabet(): void {
    const list = this.videoListController.videoDataSource.getAllData()
    const letterSet = new Set<string>()
    for (const item of list) {
      letterSet.add(MediaSortUtil.getFirstLetter(item.title || ''))
    }
    let alphabet = FULL_ALPHABET.filter(letter => letterSet.has(letter))
    if (!this.currentSortAsc) {
      alphabet = alphabet.reverse()
    }
    this.activeAlphabet = alphabet
  }

  private scrollToLetter(letter: string): void {
    const list = this.videoListController.videoDataSource.getAllData()
    for (let i = 0; i < list.length; i++) {
      if (MediaSortUtil.getFirstLetter(list[i].title || '') === letter) {
        this.videoListController.getActiveScroller().scrollToIndex(i)
        return
      }
    }
  }

  private updateIndexerOnScroll(index: number): void {
    const list = this.videoListController.videoDataSource.getAllData()
    if (index < 0 || index >= list.length) {
      return
    }
    const letter = MediaSortUtil.getFirstLetter(list[index].title || '')
    const targetIndex = this.activeAlphabet.indexOf(letter)
    if (targetIndex !== -1 && targetIndex !== this.indexerSelected) {
      this.indexerSelected = targetIndex
    }
  }

  /**
   * 从相册选一张图片替换该视频的封面
   */
  private async changeVideoCover(item: VideoMetadata | undefined): Promise<void> {
    if (!item?.date) {
      return
    }
    const imageUris = await SelectFileUtil.selectPhoto()
    if (imageUris.length === 0) {
      return
    }
    if (!ImageFileUtil.savePickedCover(imageUris[0], item.date)) {
      ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.cover_update_failed').id))
      return
    }
    // 封面文件名不变，先让对应列表项清空再重设图片地址，强制重新读取文件
    this.coverRefreshDate = item.date
    this.coverRefreshToken++
    ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.cover_updated').id))
  }

  /**
   * 空列表始终显示顶部栏；布局调整和非动画的程序滚动不改变显隐。
   * List 顶部包含 contentStartOffset，卡片模式使用内外层的合计偏移。
   */
  private syncSearchBarVisible(scrollOffset: number, scrollState: ScrollState,
    yOffset: number | undefined, contentStartOffset: number = 0): void {
    if (this.videoListController.videoDataSource.totalCount() === 0) {
      this.onScrollDirectionChange(false)
      return
    }
    if (scrollState === ScrollState.Idle) {
      return
    }
    if (yOffset === undefined || Math.abs(yOffset) <= 5 || Math.abs(yOffset + contentStartOffset) <= 5) {
      this.onScrollDirectionChange(false)
      return
    }
    if (scrollOffset > 1) {
      this.onScrollDirectionChange(true)
    } else if (scrollOffset < -1) {
      this.onScrollDirectionChange(false)
    }
  }
}
