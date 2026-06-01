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
import SelectFileUtil from '../../utils/SelectFileUtil'
import ToolsUtil from '../../utils/ToolsUtil'
import { SymbolGlyphModifier } from '@kit.ArkUI'
import DataSyncUtil from '../../utils/DataSyncUtil'
import { FileFolderDataSource } from '../../utils/DataUtil'
import { FileFolderMenu } from '../FileFolderComponent/FileFolderMenu'
import { MaskComponent } from '../SideBarComponent/MaskComponent'
import { SearchComponent } from './SearchComponent'
import { FolderOperator } from '../../database/VideoMetaData'
import VideoUtils from '../../utils/VideoUtil'
import FileFolderUtil from '../../utils/FileFolderUtil'
import NavigationAddress from '../../common/NavigationCommon'
import Preferences from '../../database/Preferences'
import { XAnimation } from '../../utils/AnimationUtil'
import { FileFolder } from '../../interfaces/FileFolderInterface'
import { SafeHeight, Setting } from '../../utils/ObservedUtil'
import { SortComponent } from './SortComponent'
import { DebounceUtil } from '../../utils/DebounceUtil'
import { BatchVideoDeleteDialog } from '../Dialog/BatchVideoDeleteDialog'
import { DeleteType } from '../../common/enum/DeleteType'

@ComponentV2
export struct VideoView {
  searchController: SearchController = new SearchController()
  @Param loading: boolean = false
  @Param holdingHand: motion.HoldingHandStatus | null = null
  @Local is_edit: boolean = false
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
  @Local currentSortField: 'name' | 'datetime' | 'time' | '' = ''
  @Local currentSortAsc: boolean = true
  @Param scrollToFolderDate: string = ''
  private passwd: string = 'passwd'
  private breadcrumbScroller: Scroller = new Scroller()
  // 文件夹按钮尺寸配置
  private readonly FOLDER_TAB_MIN_WIDTH: number = 64
  private readonly FOLDER_TAB_HEIGHT: number = 28
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
    const newIndex = this.file_folder_list.findIndex(f => f.date === this.scrollToFolderDate)
    if (newIndex !== -1) {
      this.scrollToCurrentFolder(newIndex)
    }
  }

  aboutToAppear(): void {
    this._searchValue = this.searchValue
    const savedField = Preferences.getSortField(PathUtils.appContext!)
    if (savedField === 'name' || savedField === 'datetime' || savedField === 'time') {
      this.currentSortField = savedField
    }
    this.currentSortAsc = Preferences.getSortAsc(PathUtils.appContext!)
  }

  @Monitor('searchValue')
  onSearchValueMonitor() {
    this._searchValue = this.searchValue
  }

  build() {
    Stack({ alignContent: Alignment.Top }) { // 内容区
      if (this.sideBarController.overlay &&
        this.sideBarController.visibility !== Visibility.Hidden &&
        this.sideBarController.mode === SideBarContainerType.Overlay) {
        MaskComponent({ sideBarController: this.sideBarController })
      }
      VideoList({
        videoListController: this.videoListController,
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
        currentSortAsc: this.currentSortAsc
      })

      if (!this.loading && this.videoListController.openSideBarTip(this._searchValue)) {
        Row() { //顶栏
          Column() {
            Text($r('app.string.nothing')).fontSize(25).fontWeight(FontWeight.Bold)
            Text($r('app.string.open_side_bar_tip'))
              .fontSize(15)
              .textAlign(TextAlign.Center)
              .fontWeight(FontWeight.Lighter)
              .margin({ top: 20 })
          }
        }
        .height('100%')
        .animation({ duration: 150, curve: Curve.Ease })
      }

      // 搜索无结果提示
      if (!this.loading && this.videoListController.isSearchEmpty(this._searchValue)) {
        Row() {
          Column() {
            Text('没有匹配结果').fontSize(25).fontWeight(FontWeight.Bold)
            Text('当前文件夹没有匹配"' + this._searchValue + '"的视频')
              .fontSize(15)
              .textAlign(TextAlign.Center)
              .fontWeight(FontWeight.Lighter)
              .margin({ top: 20 })
          }
        }
        .height('100%')
        .animation({ duration: 150, curve: Curve.Ease })
      }
      Column() {
        Row({ space: 15 }) {
          if (!this.is_edit && this.sideBarController.mode == SideBarContainerType.Overlay) {
            Button({ type: ButtonType.Circle, stateEffect: true }) {
              SymbolGlyph($r('sys.symbol.close_sidebar'))
                .attributeModifier(new SymbolGlyphFancyModifier(25, '', ''))
            }
            .attributeModifier(new ButtonFancyModifier(40, 40))
            .animation({ duration: 300, curve: Curve.Ease })
            .onClick(() => {
              this.sideBarController.open()
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
                    FolderOperator.getFolderByName(this.videoListController.folder.name).video_list
                  this.videoListController.videoDataSource.updateData(videoMetaDataList)
                  this.videoListController.updateData(this.videoListController.videoDataSource,
                    this.videoListController.folder)
                } else {
                  const videoMetaDataList: VideoMetadata[] =
                    SelectFileUtil.getItemFromSearch(
                      FolderOperator.getFolderByName(this.videoListController.folder.name)
                        .video_list, this._searchValue)
                  this.videoListController.videoDataSource.updateData(videoMetaDataList)
                  this.videoListController.updateData(this.videoListController.videoDataSource,
                    this.videoListController.folder)
                }
              }, 300)
            },
            onSubmit: (value: string) => {
              if (value == '') {
                if (this.videoListController.videoMetaDataList.length == 0) {
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
              if (this.videoListController.videoMetaDataList.length == 0) {
                ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.add_video_first').id))
              }
            },
            onEditChange: (isEditing: boolean) => {
              XAnimation.runWithAnimation(() => {
                this.is_edit = isEditing
              })
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

        if (Setting.showToast && this.file_folder_list.length > 1) {
          this.FolderTabsBuilder()
        }
      }
      .width('100%')
      .padding({ top: SafeHeight.topSafeHeight, left: 10, right: 10 })
    }.width('100%')
  }

  @Builder
  SortMenuBuilder() {
    SortComponent({
      currentSortField: this.currentSortField,
      currentSortAsc: this.currentSortAsc,
      onSortByName: (): void => this.handleSort('name', true),
      onSortByTime: (): void => this.handleSort('time', false),
      onSortByDatetime: (): void => this.handleSort('datetime', false)
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
          this.videoListController.videoMetaDataList.length > 0 ? '取消全选' : $r('app.string.select_all')
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
        builder: () => {
          FileFolderMenu({ video_item: undefined })
        }
      })
    }.attributeModifier(new MenuFancyModifier())
  }

  @Builder
  FolderTabsBuilder() {
    Scroll(this.breadcrumbScroller) {
      Row({ space: 8 }) {
        Repeat<FileFolder>(this.fileFolderSource.data)
          .each((repeatItem: RepeatItem<FileFolder>) => {
            Row() {
              Text(repeatItem.item.name)
                .fontSize(13)
                .fontWeight(this.videoListController?.folder?.date === repeatItem.item.date ? FontWeight.Bold :
                  FontWeight.Medium)
                .fontColor(this.videoListController?.folder?.date === repeatItem.item.date ?
                  $r('sys.color.white') : $r('app.color.text_color'))
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .maxLines(1)
                .padding({ left: 12, right: 12 })
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
                this.switchToFolderByIndex(repeatItem.index)
              }
            })
          })
          .key((item: FileFolder) => item.date.toString() + item.name)
      }
      .padding({ left: 6, right: 10 })
      .height(36)
      .margin({ top: -8 })
    }
    .width('100%')
    .height(36)
    .scrollBar(BarState.Off)
    .scrollable(ScrollDirection.Horizontal)
    .edgeEffect(EdgeEffect.Spring)
  }


  private handleSort(field: 'name' | 'time' | 'datetime', defaultAsc: boolean) {
    if (this.currentSortField === field) {
      this.currentSortAsc = !this.currentSortAsc
    } else {
      this.currentSortField = field
      this.currentSortAsc = defaultAsc
    }
    Preferences.saveSortField(PathUtils.appContext!, this.currentSortField)
    Preferences.saveSortAsc(PathUtils.appContext!, this.currentSortAsc)
    ToolsUtil.sortBy(PathUtils.appContext!, this.videoListController.videoMetaDataList,
      this.videoListController.folder, field, this.currentSortAsc)
    VideoUtils.refresh(this.videoListController, this.fileFolderSource, this.videoListController.folder)
  }

  /**
   * 通过索引切换文件夹
   */
  private switchToFolderByIndex(index: number): void {
    const result = VideoUtils.switchFolder(
      index, this.file_folder_list, this.videoListController, this.fileFolderSource, this._searchValue
    )
    if (!result) {
      return
    }
    this.file_folder_list = result.refreshedFolders
    this.scrollToCurrentFolder(index)
    this.sideBarController.close(true)
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
}
