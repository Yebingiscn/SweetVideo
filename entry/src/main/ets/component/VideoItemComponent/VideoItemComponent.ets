import ImageFileUtil from '../../utils/ImageFileUtil'
import MediaSortUtil from '../../utils/MediaSortUtil'
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import { FileFolderDataSource } from '../../utils/DataUtil'
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
import { SymbolGlyphModifier } from '@kit.ArkUI'
import KnockShareUtil from '../../utils/KnockShareUtil'
import { DirectoryView } from './DirectoryView'
import { VideoListController } from '../../controller/VideoListController'
import MediaLibraryService from '../../utils/MediaLibraryService'

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
        const targetIndex = MediaLibraryService.getItemIndex(this.videoListController.videoMetaDataList, editingVideo)
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
  @Local homeEntranceProgress: number = 0
  private homeEntranceTimer: number | undefined = undefined
  private homeEntranceStarted: boolean = false
  private directoryAlive: boolean = false
  private coverChangeRunning: boolean = false
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
    this.playHomeEntrance()
  }

  aboutToDisappear(): void {
    this.directoryAlive = false
    this.clearHomeEntranceTimer()
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
    // 整个内容区以左上角为固定起点展开并淡入，不给虚拟列表项叠加入场动画。
    this.getUIContext().animateTo({ duration: 0 }, () => {
      this.homeEntranceProgress = 0
    })
    if (!this.videoListController.homeReady) { return }
    this.homeEntranceTimer = setTimeout(() => {
      this.homeEntranceTimer = undefined
      if (!this.directoryAlive || !this.videoListController.homeReady) { return }
      this.homeEntranceStarted = true
      this.getUIContext().animateTo({ duration: 180, curve: Curve.Ease }, () => {
        this.homeEntranceProgress = 1
      })
    }, this.homeEntranceStarted ? 32 : 250)
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
      DirectoryView({
        videoListController: this.videoListController,
        searchValue: this.searchValue,
        directoryVideos: this.directoryVideos,
        directoryLayout: this.directoryLayout,
        directoryCoverLayout: this.directoryCoverLayout,
        _delMultipleList: this._delMultipleList,
        coverRefreshDate: this.coverRefreshDate,
        coverRefreshToken: this.coverRefreshToken,
        menuBuilder: (item: VideoMetadata | undefined) => { this.MenuBuilder(item) },
        menuOptions: (item: VideoMetadata, response: ResponseType) => this.videoMenuOptions(item, response),
        onVideoTap: (item: VideoMetadata) => this.handleVideoItemTap(item),
        onSearchValueChange: (value: string) => this.onSearchValueChange(value),
        onScrollDirectionChange: (isUp: boolean) => this.onScrollDirectionChange(isUp),
        onDirectoryFolderChange: (date: string) => this.onDirectoryFolderChange(date)
      })
      .opacity(this.homeEntranceProgress)
      .scale({ x: this.homeEntranceProgress, y: this.homeEntranceProgress,
        centerX: 16, centerY: SafeHeight.topSafeHeight + 100 })
      .transition(TransitionEffect.IDENTITY)
      .bindSheet(this.showDetailSheet, this.DetailSheetBuilder, {
        detents: [SheetSize.LARGE],
        backgroundColor: $r('app.color.start_window_background'),
        blurStyle: BlurStyle.COMPONENT_ULTRA_THIN,
        showClose: true,
        onWillDismiss: () => { this.showDetailSheet = false }
      })
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
                  coverTransition: true
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
                      coverTransition: true
                    })
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
            const videoItem = MediaLibraryService.getItem(this.videoListController.videoMetaDataList, item?.date!)
            await this.clickItem(videoItem, true)
          }, DELAY_JUMP_TO_PLAYER)
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.play_round_rectangle')),
        content: $r('app.string.menu_short_video_play')
      })
        .onClick(() => {
          setTimeout(async () => {
            const videoItem = MediaLibraryService.getItem(this.videoListController.videoMetaDataList, item?.date!)
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
          const targetIndex = MediaLibraryService.getItemIndex(this.videoListController.videoMetaDataList, item!)
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
        MediaLibraryService.getItem(this.videoListController.videoMetaDataList, video.date) : video
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
    if (!item?.date || this.coverChangeRunning) {
      return
    }
    this.coverChangeRunning = true
    try {
      const imageUris = await SelectFileUtil.selectPhoto()
      if (imageUris.length === 0) {
        return
      }
      const saved = await ImageFileUtil.savePickedCover(imageUris[0], item.date)
      if (!this.directoryAlive) {
        return
      }
      if (!saved) {
        ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.cover_update_failed').id))
        return
      }
      // 封面文件名不变，先让对应列表项清空再重设图片地址，强制重新读取文件
      this.coverRefreshDate = item.date
      this.coverRefreshToken++
      ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.cover_updated').id))
    } finally {
      this.coverChangeRunning = false
    }
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

export { VideoListController }
