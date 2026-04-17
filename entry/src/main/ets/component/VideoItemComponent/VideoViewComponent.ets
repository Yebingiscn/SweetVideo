import { VideoList, VideoListController } from './VideoItemComponent'
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import { SideBarController } from '../SideBarComponent/SideBar'
import {
  ButtonFancyModifier,
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
import PrivacySpaceUtil from '../../utils/PrivacySpaceUtil'
import { XAnimation } from '../../utils/AnimationUtil'
import { FileFolder } from '../../interfaces/FileFolderInterface'
import { SafeHeight, Setting } from '../../utils/ObservedUtil'
import { SortComponent } from './SortComponent'

@Component
export struct VideoView {
  searchController: SearchController = new SearchController()
  @Link loading: boolean
  @State is_edit: boolean = false
  @Link searchValue: string
  @Link videoListController: VideoListController
  @Consume @Watch('onFolderListChanged') file_folder_list: FileFolder[]
  @Consume sideBarController: SideBarController
  @Consume('pathStack') pathStack: NavPathStack
  @Consume fileFolderSource: FileFolderDataSource
  @Watch('SyncDelMultipleList') @State delMultipleList: VideoMetadata[] = DataSyncUtil.delMultipleList
  // 当前选中文件夹索引
  @State currentFolderIndex: number = 0
  // 监听文件夹切换，同步面包屑选中状态
  @Watch('onFolderChanged') @StorageLink('scrollToFolderDate') scrollToFolderDate: number = 0
  // 排序方向状态，用于触发排序按钮 UI 刷新
  // 说明：ORM 改造后排序偏好保存在 Preferences 中，但每次排序后需要同步刷新按钮图标，
  //       因此增加 @State sortOrder 响应式状态，在排序回调中重新读取偏好值。
  @State sortOrder: 'asc' | 'desc' = 'desc'
  private passwd: string = 'passwd'
  // 面包屑滚动控制器
  private breadcrumbScroller: Scroller = new Scroller()
  // 文件夹按钮尺寸配置
  private readonly FOLDER_TAB_MIN_WIDTH: number = 64
  private readonly FOLDER_TAB_HEIGHT: number = 28

  /**
   * 文件夹切换时同步面包屑选中状态
   */
  onFolderChanged(): void {
    const newIndex = this.getCurrentFolderIndex()
    if (newIndex !== -1 && newIndex !== this.currentFolderIndex) {
      this.currentFolderIndex = newIndex
      // 滚动到当前文件夹
      this.scrollToCurrentFolder(newIndex)
    }
  }

  SyncDelMultipleList() {
    DataSyncUtil.delMultipleList = this.delMultipleList
  }

  /**
   * 文件夹列表变化时处理（如添加新文件夹）
   */
  onFolderListChanged(): void {
    // 文件夹列表变化时，确保选中状态正确
    const newIndex = this.getCurrentFolderIndex()
    if (newIndex !== -1 && newIndex !== this.currentFolderIndex) {
      this.currentFolderIndex = newIndex
    }
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
        delMultipleList: this.delMultipleList,
        searchValue: this.searchValue
      })

      if (!this.loading && this.videoListController.openSideBarTip(this.searchValue)) {
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
      if (!this.loading && this.videoListController.isSearchEmpty(this.searchValue)) {
        Row() {
          Column() {
            Text('没有匹配结果').fontSize(25).fontWeight(FontWeight.Bold)
            Text('当前文件夹没有匹配"' + this.searchValue + '"的视频')
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
            searchValue: this.searchValue,
            onChange: async () => {
              // ORM 改造：FolderOperator.getFolderByName 已从同步改为异步，搜索清空或过滤时都需要 await
              if (this.searchValue === '') {
                const folder = await FolderOperator.getFolderByName(this.videoListController.folder.name)
                const videoMetaDataList: VideoMetadata[] = folder?.video_list || []
                this.videoListController.videoDataSource.updateData(videoMetaDataList)
                this.videoListController.updateData(this.videoListController.videoDataSource,
                  this.videoListController.folder)
              } else {
                const folder = await FolderOperator.getFolderByName(this.videoListController.folder.name)
                const videoMetaDataList: VideoMetadata[] =
                  SelectFileUtil.getItemFromSearch(folder?.video_list || [], this.searchValue)
                this.videoListController.videoDataSource.updateData(videoMetaDataList)
                this.videoListController.updateData(this.videoListController.videoDataSource,
                  this.videoListController.folder)
              }
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
                ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.add_video_first').id))
                this.pathStack.pushPathByName(NavigationAddress.PRIVACY_SPACE, null)
                this.searchValue = ''
                return
              }
              if (this.videoListController.videoMetaDataList.length == 0) {
                ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.add_video_first').id))
              }
            },
            onEditChange: (isEditing: boolean) => {
              animateToImmediately({ duration: 300, curve: Curve.Ease }, () => {
                this.is_edit = isEditing
              })
            },
            onSearchFocus: () => {
              this.passwd = Preferences.getPassword(PathUtils.appContext!)
            }
          })

          if (!this.is_edit) {
            this.SortButtonBuilder()

            if (this.videoListController.multipleChooseState === Visibility.Visible) {
              Button({ type: ButtonType.Circle, stateEffect: true }) {
                SymbolGlyph($r('sys.symbol.checkmark_square_on_square'))
                  .attributeModifier(new SymbolGlyphFancyModifier(25, '', ''))
              }
              .attributeModifier(new ButtonFancyModifier(40, 40))
              .bindMenu(this.SelectItemMenuBuilder,
                { backgroundBlurStyle: BlurStyle.COMPONENT_ULTRA_THIN })
              .attributeModifier(new SearchShadowModifier())
              .transition(XAnimation.getAnimation('right', 0, false))
            }
          }
        }
        .width('100%')

        // 自定义面包屑导航
        if (Setting.showToast && this.file_folder_list.length > 1) {
          this.FolderTabsBuilder()
        }
      }.width('100%').padding({ top: SafeHeight.topSafeHeight, left: 10, right: 10 })
    }.width('100%')
  }

  // 获取当前排序按钮的图标资源
  private getSortIconResource(): Resource {
    // 使用通用排序图标，不根据排序类型变化
    return $r('sys.symbol.text_and_arrow_down')
  }

  /**
   * 获取当前排序方向
   * @returns 'asc' 升序（从小到大）或 'desc' 降序（从大到小）
   */
  private getSortOrder(): 'asc' | 'desc' {
    const isPrivacy = PrivacySpaceUtil.getPrivacyMode()
    return Preferences.getVideoSortOrder(PathUtils.appContext!, isPrivacy)
  }

  /**
   * 排序按钮 Builder
   * 显示通用排序图标 + 升序指示器
   * 点击后弹出排序菜单，可切换排序类型和方向
   */
  @Builder
  SortButtonBuilder() {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      // 根据排序方向切换图标：降序向下箭头，升序向上箭头
      SymbolGlyph(this.sortOrder === 'asc' ? $r('sys.symbol.text_and_arrow_up') : $r('sys.symbol.text_and_arrow_down'))
        .attributeModifier(new SymbolGlyphFancyModifier(25, '', ''))
    }
    .attributeModifier(new ButtonFancyModifier(40, 40))
    .bindMenu(this.SortMenuBuilder, { backgroundBlurStyle: BlurStyle.COMPONENT_ULTRA_THIN })
    .attributeModifier(new SearchShadowModifier())
    .transition(XAnimation.getAnimation('right', 0, false))
  }

  @Builder
  SortMenuBuilder() {
    SortComponent({
      onSortByName: async () => {
        ToolsUtil.sortBy(PathUtils.appContext!, this.videoListController.videoMetaDataList,
          this.videoListController.folder, "name")
        // ORM 改造：VideoUtils.refresh 已改为异步，必须 await 确保数据库查询完成后再更新 UI
        await VideoUtils.refresh(this.videoListController, this.fileFolderSource, this.videoListController.folder)
        this.sortOrder = this.getSortOrder()
      },
      onSortByTime: async () => {
        ToolsUtil.sortBy(PathUtils.appContext!, this.videoListController.videoMetaDataList,
          this.videoListController.folder, "time")
        await VideoUtils.refresh(this.videoListController, this.fileFolderSource, this.videoListController.folder)
        this.sortOrder = this.getSortOrder()
      },
      onSortByDatetime: async () => {
        ToolsUtil.sortBy(PathUtils.appContext!, this.videoListController.videoMetaDataList,
          this.videoListController.folder, "datetime")
        await VideoUtils.refresh(this.videoListController, this.fileFolderSource, this.videoListController.folder)
        this.sortOrder = this.getSortOrder()
      }
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
        content: $r('app.string.select_all')
      })
        .onClick(() => {
          this.delMultipleList = [...this.videoListController.videoMetaDataList]
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.trash_fill')),
        content: $r('app.string.delete_selected')
      })
        .onClick(async () => {
          try {
            if (this.delMultipleList.length > 0) {
              await FileFolderUtil.delVideosFileFolder(PathUtils.appContext!, this.videoListController,
                this.fileFolderSource)
            }
          } finally {
            await VideoUtils.refresh(this.videoListController, this.fileFolderSource, this.videoListController.folder)
        this.sortOrder = this.getSortOrder()
            this.videoListController.closeMultipleChoose()
          }
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.arrow_right_folder_circle')),
        content: $r('app.string.move_to_folder'),
        builder: (): void => this.FileFolderMenuBuilder(undefined)
      })
    }.attributeModifier(new MenuFancyModifier())
  }

  @Builder
  FolderTabsBuilder() {
    Scroll(this.breadcrumbScroller) {
      Row({ space: 8 }) {
        LazyForEach(this.fileFolderSource, (folder: FileFolder, index: number) => {
          this.FolderTabItemBuilder(folder, index)
        }, (folder: FileFolder, index: number) => folder.date.toString() + '_' + index + '_' +
          (this.currentFolderIndex === index))
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

  @Builder
  FolderTabItemBuilder(folder: FileFolder, index: number) {
    Row() {
      Text(folder.name)
        .fontSize(13)
        .fontWeight(this.currentFolderIndex === index ? FontWeight.Bold : FontWeight.Medium)
        .fontColor(this.currentFolderIndex === index ?
          $r('sys.color.white') : $r('app.color.text_color'))
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .maxLines(1)
        .padding({ left: 12, right: 12 })
    }
    .backgroundColor(this.currentFolderIndex === index ?
      $r('app.color.main_color') : $r('app.color.start_window_background'))
    .height(this.FOLDER_TAB_HEIGHT)
    .constraintSize({ minWidth: this.FOLDER_TAB_MIN_WIDTH })
    .borderRadius(16)
    .justifyContent(FlexAlign.Center)
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
    .onClick(async () => {
      if (this.currentFolderIndex !== index) {
        this.currentFolderIndex = index
        await this.switchToFolderByIndex(index)
      }
    })
  }

  @Builder
  FileFolderMenuBuilder(video_item: VideoMetadata | undefined) {
    FileFolderMenu({ video_item: video_item })
  }

  /**
   * 获取当前文件夹在列表中的索引
   */
  private getCurrentFolderIndex(): number {
    return this.file_folder_list.findIndex(f => f.date === this.videoListController?.folder?.date)
  }

  /**
   * 通过索引切换文件夹
   * ORM 改造：切换前重新从数据库拉取最新的 folder 与 video 数据，确保手势滑动或点击面包屑后 UI 显示的是最新状态。
   */
  private async switchToFolderByIndex(index: number): Promise<void> {
    // 边界检查
    if (index < 0 || index >= this.file_folder_list.length) {
      console.error(`[VideoView] switchToFolderByIndex: index ${index} out of bounds, length: ${this.file_folder_list.length}`)
      return
    }
    const folder = this.file_folder_list[index]
    if (!folder) {
      console.error(`[VideoView] switchToFolderByIndex: folder at index ${index} is undefined`)
      return
    }
    if (this.videoListController?.folder?.date === folder.date) {
      return
    }
    // 保留搜索状态，在新文件夹中应用搜索过滤
    // 从 ORM 重新加载最新数据（包含可能的新导入视频或排序变化）
    this.file_folder_list = await FileFolderUtil.getAllFolderAsync(PathUtils.appContext!)
    this.fileFolderSource.updateData(this.file_folder_list)
    const currentFolder = this.fileFolderSource.getFileFolder(folder.name)
    if (currentFolder) {
      // 如果有搜索值，在新文件夹中过滤视频
      let filteredVideos = currentFolder.video_list
      if (this.searchValue.length > 0) {
        filteredVideos = SelectFileUtil.getItemFromSearch(currentFolder.video_list, this.searchValue)
      }
      animateToImmediately({
        duration: 200,
        curve: Curve.EaseInOut
      }, () => {
        this.videoListController.videoDataSource.updateData(filteredVideos)
        this.videoListController.updateData(
          this.videoListController.videoDataSource,
          currentFolder
        )
      })
    }
    // 滚动面包屑使当前文件夹可见
    this.scrollToCurrentFolder(index)
    this.sideBarController.close(true)
    // 同步 scrollToFolderDate，触发 onFolderChanged 确保状态一致
    AppStorage.setOrCreate('scrollToFolderDate', folder.date)
  }

  /**
   * 滚动面包屑使当前文件夹可见
   */
  private scrollToCurrentFolder(index: number): void {
    // 计算目标位置，使当前文件夹居中显示
    const estimatedItemWidth = 80
    const spacing = 8
    const targetOffset = Math.max(0, index * (estimatedItemWidth + spacing) - 100)
    animateToImmediately({
      duration: 200,
      curve: Curve.Ease
    }, () => {
      this.breadcrumbScroller.scrollTo({
        xOffset: targetOffset,
        yOffset: 0,
        animation: { duration: 200, curve: Curve.Ease }
      })
    })
  }
}
