import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import { FileFolderDataSource, VideoDataSource } from '../../utils/DataUtil'
import { PathUtils } from '../../utils/PathUtils'
import ToolsUtil from '../../utils/ToolsUtil'
import SelectFileUtil from '../../utils/SelectFileUtil'
import { SortField } from '../../common/enum/SortField'
import DataSyncUtil from '../../utils/DataSyncUtil'
import { VideoDetailDialog } from '../../component/Dialog//VideoDetailDialog'
import { DefaultDialogShadow, MenuFancyModifier } from '../../common/AttributeModifierConfig'
import { EditMetadataDialog } from '../../component/Dialog//EditMetadataDialog'
import { FileFolder } from '../../interfaces/FileFolderInterface'
import { SideBarController } from '../SideBarComponent/SideBar'
import { VideoMetaDataOperator } from '../../database/VideoMetaData'
import VideoUtils from '../../utils/VideoUtil'
import { InfoConfirmDialog } from '../../component/Dialog/InfoConfirmDialog'
import FileFolderUtil from '../../utils/FileFolderUtil'
import { VideoDeleteDialog } from '../Dialog/VideoDeleteDialog'
import { BatchVideoDeleteDialog } from '../Dialog/BatchVideoDeleteDialog'
import { DeleteType } from '../../common/enum/DeleteType'
import { ListDisplayMode } from '../../common/enum/DisplayMode'
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
import { FileFolderMenu } from '../FileFolderComponent/FileFolderMenu'
import { ScrollBarBuilder } from './ScrollBarBuilder'
import VideoCardItem from './VideoCardItemComponent'
import { VideoItemPreviewBuilder } from './VideoItemPreviewBuilder'
import VideoListItem from './VideoListItemComponent'
import { SymbolGlyphModifier } from '@kit.ArkUI'

@ObservedV2
export class VideoListController {
  @Trace public folder: FileFolder
  listScroller: ListScroller = new ListScroller()
  @Trace videoMetaDataList: VideoMetadata[]
  @Trace multipleChooseState: Visibility = Visibility.None
  @Trace listLine: number = 1
  videoDataSource: VideoDataSource
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
    // TODO 这里的处理太粗暴了，应该定义每个元素的MaxWidth 来计算格子，或者根据尺寸做响应式布局
    const base = Math.floor(Math.abs(width) / 500)
    this.listLine = listDisplayMode === ListDisplayMode.LIST_DISPLAY ? base + 1 : base + 2
    // 增加判断，旋转时保持滚动位置不变
    if (this.listScroller.currentOffset()?.yOffset == -90) {
      this.listScroller.scrollEdge(Edge.Top)
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
  @Param holdingHand: motion.HoldingHandStatus | null = null
  @Param videoListController: VideoListController = new VideoListController()
  @Local activeAlphabet: string[] = []
  @Local indexerSelected: number = 0
  @Consumer() fileFolderSource: FileFolderDataSource = new FileFolderDataSource([])
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
  editMetadataDialogController: CustomDialogController = new CustomDialogController({
    builder: EditMetadataDialog({
      confirm: (title: string | undefined) => {
        if (!title?.trim()) {
          return
        }
        const editingVideo = DataSyncUtil.editingVideo!
        const targetIndex = SelectFileUtil.getItemIndex(this.videoListController.videoMetaDataList, editingVideo)
        if (targetIndex === -1) {
          return
        }
        if (this.videoListController.videoMetaDataList.some((v, index) => index !== targetIndex &&
          v.title === title.trim())) {
          return
        }
        const original = this.videoListController.videoMetaDataList[targetIndex]
        const updatedVideo: VideoMetadata = {
          uri: original.uri,
          title: title.trim() as string,
          date: original.date,
          size: original.size,
          time: original.time,
          last_play: original.last_play,
          format: original.format,
          video_size: original.video_size,
          hdr_type: original.hdr_type,
          frame_rate: original.frame_rate,
          start_time: original.start_time,
          end_time: original.end_time,
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
  VideoDetailDialog: CustomDialogController = new CustomDialogController({
    builder: VideoDetailDialog(), cornerRadius: 20,
    shadow: DefaultDialogShadow
  })
  private _invalidItem: VideoMetadata | null = null
  invalidFileDialog: CustomDialogController = new CustomDialogController({
    builder: InfoConfirmDialog({
      textInfo: '该视频文件已失效，是否清除？',
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

  aboutToAppear(): void {
    this._searchValue = this.searchValue
  }

  @Monitor('searchValue')
  onSearchValueMonitor() {
    this._searchValue = this.searchValue
  }

  @Monitor('delMultipleList')
  onDelMultipleListMonitor() {
    this._delMultipleList = [...this.delMultipleList]
  }

  @Monitor('videoListController.videoMetaDataList', 'currentSortField', 'currentSortAsc')
  onVideoListChanged() {
    if (this.currentSortField === SortField.NAME) {
      this.updateActiveAlphabet()
    } else {
      this.activeAlphabet = []
    }
  }

  build() {
    if (Setting.listDisplayMode === ListDisplayMode.LIST_DISPLAY) {
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
                  delMultipleList: this._delMultipleList
                })
              }
              .borderRadius(16)
              .backgroundColor(Setting.backgroundImageSrc.length > 0 ? $r('app.color.start_window_background_blur') :
                $r('app.color.start_window_background'))
              .margin({ bottom: 20 })
              .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
              .transition(TransitionEffect.OPACITY.animation({ duration: 150, curve: Curve.Sharp }))
              .width(this.videoListController.listLine === 1 ? '100%' : '95%')
              .height('auto')
              .bindContextMenu(this.MenuBuilder(repeatItem.item), ResponseType.LongPress,
                {
                  backgroundBlurStyle: BlurStyle.COMPONENT_ULTRA_THIN,
                  preview: VideoItemPreviewBuilder(repeatItem.item),
                  previewAnimationOptions: { scale: [1.0, 0.95], hoverScale: [1.0, 1.2] },
                  layoutRegionMargin: {
                    left: 16,
                    right: 16,
                    top: 16,
                    bottom: 4
                  },
                  hapticFeedbackMode: HapticFeedbackMode.ENABLED
                })
              .bindContextMenu(this.MenuBuilder(repeatItem.item), ResponseType.RightClick,
                {
                  backgroundBlurStyle: BlurStyle.COMPONENT_ULTRA_THIN,
                  preview: VideoItemPreviewBuilder(repeatItem.item),
                  previewAnimationOptions: { scale: [1.0, 0.95], hoverScale: [1.0, 1.2] },
                  layoutRegionMargin: {
                    left: 16,
                    right: 16,
                    top: 16,
                    bottom: 4
                  },
                  mask: true
                })
              .gesture(
                TapGesture({ count: 1, fingers: 1 })
                  .onAction(async () => {
                    if (this.videoListController.multipleChooseState !== Visibility.Visible) {
                      const videoItem =
                        SelectFileUtil.getItem(this.videoListController.videoMetaDataList, repeatItem.item?.date!)
                      await this.clickItem(videoItem,
                        VideoOperateUtil.getPlayerNavigationAddress(Setting.defaultPlayerEngine))
                      return
                    } else {
                      if (this._delMultipleList.some(video => video.date === repeatItem.item.date)) {
                        this._delMultipleList =
                          this._delMultipleList.filter(video => video.date !== repeatItem.item.date)
                        this.onDelMultipleListChange([...this._delMultipleList])
                      } else {
                        this._delMultipleList.push(repeatItem.item)
                        this.onDelMultipleListChange([...this._delMultipleList])
                      }
                    }
                  })
              )
            })
            .key((item: VideoMetadata, _index: number) => item.date.toString() + item.last_play + item.title +
              item.size.toString() +
              this.videoListController.folder.name + item.time)
            .virtualScroll()
        }
        .clip(false)
        .padding({ left: 10, right: 10 })
        .contentStartOffset(SafeHeight.topSafeHeight +
          (Setting.showToast && this.file_folder_list.length > 1 ? 90 : 65))
        .contentEndOffset(SafeHeight.bottomSafeHeight)
        .lanes(this.videoListController.listLine)
        .animation({ duration: 300, curve: Curve.Smooth })
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true }) // 滚动边缘效果
        .chainAnimation(true)
        .syncLoad(false)
        .width('100%')
        .height('100%')
        .fadingEdge(true)
        .onAppear(() => {
          this.videoListController.listScroller.scrollEdge(Edge.Top)
        })
        .onScrollIndex((start: number) => {
          if (this.currentSortField === SortField.NAME) {
            this.updateIndexerOnScroll(start)
          }
        })

        if (this.currentSortField === 'name' && this.activeAlphabet.length > 0) {
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

        if (this.currentSortField !== SortField.NAME) {
          ScrollBarBuilder({
            videoListController: this.videoListController.listScroller,
            fileFolderLength: this.file_folder_list.length
          })
        }
      }
      .width('100%')
      .height('100%')
      .animation({ duration: 300, curve: Curve.Ease })
    } else {
      Stack({
        alignContent: IntellectualGripPostureUtil.isLeftHoldHand(this.holdingHand) ? Alignment.TopStart :
          Alignment.TopEnd
      }) {
        Scroll() {
          Column() {
            Blank().height(SafeHeight.topSafeHeight + (Setting.showToast && this.file_folder_list.length > 1 ? 90 : 65))
            WaterFlow({
              scroller: this.videoListController.listScroller,
              layoutMode: WaterFlowLayoutMode.SLIDING_WINDOW
            }) {
              Repeat<VideoMetadata>(this.videoListController.videoDataSource.data)
                .each((repeatItem: RepeatItem<VideoMetadata>) => {
                  FlowItem() {
                    VideoCardItem({
                      item: repeatItem.item,
                      delMultipleList: this._delMultipleList
                    }).width('100%')
                  }
                  .backgroundColor(
                    Setting.backgroundImageSrc.length > 0 ? $r('app.color.start_window_background_blur') :
                      $r('app.color.start_window_background'))
                  .borderRadius(16)
                  .width('100%')
                  .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
                  .bindContextMenu(this.MenuBuilder(repeatItem.item), ResponseType.LongPress,
                    {
                      backgroundBlurStyle: BlurStyle.COMPONENT_ULTRA_THIN,
                      preview: VideoItemPreviewBuilder(repeatItem.item),
                      previewAnimationOptions: { scale: [1.0, 0.95], hoverScale: [1.0, 1.2] },
                      layoutRegionMargin: {
                        left: 16,
                        right: 16,
                        top: 16,
                        bottom: 4
                      },
                      hapticFeedbackMode: HapticFeedbackMode.ENABLED,
                      mask: true
                    })
                  .bindContextMenu(this.MenuBuilder(repeatItem.item), ResponseType.RightClick,
                    {
                      backgroundBlurStyle: BlurStyle.COMPONENT_ULTRA_THIN,
                      preview: VideoItemPreviewBuilder(repeatItem.item),
                      previewAnimationOptions: { scale: [1.0, 0.95], hoverScale: [1.0, 1.2] },
                      layoutRegionMargin: {
                        left: 16,
                        right: 16,
                        top: 16,
                        bottom: 4
                      },
                    })
                  .gesture(
                    TapGesture({ count: 1, fingers: 1 })
                      .onAction(async () => {
                        if (this.videoListController.multipleChooseState !== Visibility.Visible) {
                          await this.clickItem(repeatItem.item,
                            VideoOperateUtil.getPlayerNavigationAddress(Setting.defaultPlayerEngine))
                          return
                        } else {
                          if (this._delMultipleList.some(video => video.date === repeatItem.item.date)) {
                            this._delMultipleList =
                              this._delMultipleList.filter(video => video.date !== repeatItem.item.date)
                            this.onDelMultipleListChange([...this._delMultipleList])
                          } else {
                            this._delMultipleList.push(repeatItem.item)
                            this.onDelMultipleListChange([...this._delMultipleList])
                          }
                        }
                      })
                  )
                })
                .key((item: VideoMetadata, _index: number) => item.date + item.last_play + item.title +
                  item.size.toString() +
                  this.videoListController.folder.name + item.time)
                .virtualScroll()
            }
            .clip(false)
            .columnsTemplate('1fr '.repeat(this.videoListController.listLine).trim())
            .columnsGap(16) // 列间距
            .rowsGap(16) // 行间距
            .scrollBar(BarState.Off)
            .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
            .width('100%')
            .height('100%')
            .padding({ left: 10, right: 10 })
            .onAppear(() => {
              this.videoListController.listScroller.scrollEdge(Edge.Top)
            })
            .nestedScroll({
              scrollForward: NestedScrollMode.PARENT_FIRST,
              scrollBackward: NestedScrollMode.SELF_FIRST
            })
            .onScrollIndex((first: number) => {
              if (this.currentSortField === SortField.NAME) {
                this.updateIndexerOnScroll(first)
              }
            })
          }
          .clip(false)
        }
        .clip(false)
        .scrollBar(BarState.Off)
        .width('100%')
        .height('100%')

        if (this.currentSortField === 'name' && this.activeAlphabet.length > 0) {
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

        if (this.currentSortField !== SortField.NAME) {
          ScrollBarBuilder({
            videoListController: this.videoListController.listScroller,
            fileFolderLength: this.file_folder_list.length
          })
        }
      }
      .width('100%')
      .height('100%')
      .animation({ duration: 300, curve: Curve.Ease })
    }
  }

  async clickItem(item: VideoMetadata | undefined, choosePlayer: string) {
    if (!item || !this.videoListController.videoDataSource.getAllData().some(i => i.date == item?.date!)) {
      ToolsUtil.showToast('数据正在加载中，请重试')
      this.videoListController.videoDataSource.refreshData(this.videoListController.folder)
      return
    }
    try {
      this.videoListController.listScroller.closeAllSwipeActions()
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
    if (await SelectFileUtil.isFileExist(item.uri, true)) {
      ToolsUtil.routerWhere(this.pathStack, choosePlayer, item,
        this.videoListController.videoDataSource.getAllData())
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
        content: this.videoListController.multipleChooseState === Visibility.Visible ? '取消多选' :
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
            await this.clickItem(videoItem,
              VideoOperateUtil.getPlayerNavigationAddress(Setting.defaultPlayerEngine, true))
          }, DELAY_JUMP_TO_PLAYER)
        })
      MenuItem({ symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.info_circle')), content: '详情' })
        .onClick(() => {
          setTimeout(() => {
            DataSyncUtil.editingVideo = item
            this.VideoDetailDialog.open()
          }, DELAY_JUMP_TO_PLAYER)
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.textformat_size_square')), content: '导入或删除字幕'
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
        content: '打开文件所在位置'
      })
        .onClick(async () => {
          await WantProcess.linkToVideoSource(item!.uri)
        })
    }.attributeModifier(new MenuFancyModifier())
  }

  @Builder
  FileFolderMenuBuilder(video_item: VideoMetadata | undefined) {
    FileFolderMenu({ video_item: video_item })
  }

  private updateActiveAlphabet(): void {
    const list = this.videoListController.videoDataSource.getAllData()
    const letterSet = new Set<string>()
    for (const item of list) {
      letterSet.add(ToolsUtil.getFirstLetter(item.title || ''))
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
      if (ToolsUtil.getFirstLetter(list[i].title || '') === letter) {
        this.videoListController.listScroller.scrollToIndex(i)
        return
      }
    }
  }

  private updateIndexerOnScroll(index: number): void {
    const list = this.videoListController.videoDataSource.getAllData()
    if (index < 0 || index >= list.length) {
      return
    }
    const letter = ToolsUtil.getFirstLetter(list[index].title || '')
    const targetIndex = this.activeAlphabet.indexOf(letter)
    if (targetIndex !== -1 && targetIndex !== this.indexerSelected) {
      this.indexerSelected = targetIndex
    }
  }
}
