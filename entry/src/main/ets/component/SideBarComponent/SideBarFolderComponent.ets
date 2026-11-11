import FolderHierarchy from '../../utils/FolderHierarchy'
import { FileFolderDataSource } from '../../utils/DataUtil'
import { AddFileFolderNameDialog } from '../Dialog/AddFileFolderNameDialog'
import { FileFolder } from '../../interfaces/FileFolderInterface'
import {
  ButtonFancyModifier,
  DefaultDialogShadow,
  SymbolGlyphFancyModifier
} from '../../common/AttributeModifierConfig'
import { PathUtils } from '../../utils/PathUtils'
import { VideoListController } from '../../controller/VideoListController'
import { SideBarController } from './SideBar'
import Preferences from '../../database/Preferences'
import { SortField } from '../../common/enum/SortField'
import { FileFolderListBuilder } from '../FileFolderComponent/FileFolderListComponent'
import { FolderContextMenu, FolderMenuAction, FolderMenuActions } from '../FileFolderComponent/FileFolderSelectBuilder'
import { SortMenuComponent } from '../common/SortMenuComponent'
import FileFolderUtil from '../../utils/FileFolderUtil'
import ToolsUtil from '../../utils/ToolsUtil'
import VideoUtils from '../../utils/VideoUtil'
import FolderSelection from '../../utils/FolderSelection'
import { KeyboardShortcuts, LibraryItemFocus, LibraryKeyboard, ShortcutAction } from '../../utils/KeyboardShortcuts'

@ComponentV2
export struct SideBarFolderComponent {
  @Consumer() folderMenuActions: FolderMenuActions = new FolderMenuActions()
  @Consumer() libraryKeyboard: LibraryKeyboard = new LibraryKeyboard()
  @Param sideBarController: SideBarController = new SideBarController()
  @Param videoListController: VideoListController = new VideoListController()
  @Param fileFolderSource: FileFolderDataSource = new FileFolderDataSource([])
  @Param file_folder_list: FileFolder[] = []
  @Param sideBarScroller: Scroller = new Scroller()
  @Param currentSourceTab: number = 0
  @BuilderParam importActions: () => void
  @Local expandedFolderDates: Set<string> = new Set()
  @Local collapsedFolderDates: Set<string> = new Set()
  @Local folderSelectionMode: boolean = false
  @Local selectedFolderDates: Set<string> = new Set()
  @Local folderSortField: SortField | '' = ''
  @Local folderSortAsc: boolean = true
  @Local folderPinyinSort: boolean = true
  @Local importActionsHeight: number = 180
  @Local folderToolbarHeight: number = 74
  private folderSortRequestId: number = 0

  @Computed
  get sidebarContentHeight(): number {
    const count = this.visibleTreeFolders.length
    // 原文件树固定行高44，组内上下各4，行间距2；仅统计，不展开虚拟节点测量。
    const treeHeight = count * 44 + (count > 0 ? 8 + (count - 1) * 2 : 0)
    const toolbarHeight = this.folderSelectionMode && this.currentSourceTab === 0 ? this.folderToolbarHeight : 0
    return this.importActionsHeight + 32 + treeHeight + 12 + toolbarHeight
  }

  @Computed
  get visibleTreeFolders(): FileFolder[] {
    return FolderHierarchy.flatten(this.fileFolderSource.data, this.expandedFolderDates)
  }

  @Event onFolderTreeIndicesChange: (indices: Map<string, number>) => void = () => {
  }
  @Event onContentHeightChange: (height: number) => void = () => {
  }
  @Event scrollToFolderDateChange: (date: string) => void = () => {
  }
  @Event searchValueClear: () => boolean = () => false
  @Event onDeletingChange: (deleting: boolean) => void = () => {
  }
  @Event fileFolderListChange: (folders: FileFolder[]) => void = () => {
  }
  addFileFolderNameDialogController: CustomDialogController = new CustomDialogController({
    builder: AddFileFolderNameDialog({
      onFolderAdded: (folders: FileFolder[]) => {
        this.fileFolderListChange(folders)
      }
    }),
    cornerRadius: 20,
    shadow: DefaultDialogShadow,
    onDidDisappear: () => this.libraryKeyboard.reset()
  })
  aboutToAppear(): void {
    this.libraryKeyboard.onFolderAction = (action: ShortcutAction, date: string): void => {
      if (this.folderMenuActions.deleting || this.videoListController.directoryTransitioning) {
        return
      }
      const folder = this.file_folder_list.find(item => item.date === date)
      if (action === ShortcutAction.NEW_FOLDER) {
        this.addFileFolderNameDialogController.open()
      } else if (action === ShortcutAction.SELECT_ALL) {
        this.videoListController.closeMultipleChoose()
        this.videoListController.directoryFolderSelection = undefined
        this.folderSelectionMode = true
        this.selectedFolderDates = new Set(FolderSelection.selectable(this.file_folder_list).map(item => item.date))
      } else if (action === ShortcutAction.ESCAPE) {
        this.closeFolderSelection()
      } else if (action === ShortcutAction.RENAME) {
        if (this.folderSelectionMode && this.selectedFolderDates.size !== 1) {
          return
        }
        const target =
          this.folderSelectionMode ? this.file_folder_list.find(item => this.selectedFolderDates.has(item.date)) :
            folder
        if (!target || target.name === '首页') {
          return
        }
        this.folderMenuActions.run(FolderMenuAction.EDIT, target)
      } else if (action === ShortcutAction.DELETE) {
        if (this.folderSelectionMode) {
          this.confirmFolderSelectionDelete()
        } else if (folder && folder.name !== '首页') {
          this.folderMenuActions.confirmDelete([folder.date], () => this.closeFolderSelection())
        }
      }
    }
    const savedFolderField = Preferences.getFolderSortField(PathUtils.appContext!)
    if (savedFolderField === SortField.FOLDER_NAME || savedFolderField === SortField.FOLDER_DATETIME ||
      savedFolderField === SortField.FOLDER_COUNT) {
      this.folderSortField = savedFolderField as SortField
    }
    this.folderSortAsc = Preferences.getFolderSortAsc(PathUtils.appContext!)
    this.folderPinyinSort = Preferences.getPinyinSort(PathUtils.appContext!)
    this.collapsedFolderDates = new Set(Preferences.getCollapsedFolderDates(PathUtils.appContext!))

    this.recomputeExpandedFolderDates()
    this.publishFolderTreeIndices()
    this.onContentHeightChange(this.sidebarContentHeight)
  }

  aboutToDisappear(): void {
    this.folderSortRequestId++
  }

  @Monitor('file_folder_list')
  onFileFolderListChanged() {
    this.fileFolderSource.updateData(this.file_folder_list)
    const allFolderDates = new Set(this.file_folder_list.map(f => f.date))
    this.collapsedFolderDates = new Set(Array.from(this.collapsedFolderDates).filter(d => allFolderDates.has(d)))
    const selectable = new Set(FolderSelection.selectable(this.file_folder_list).map(folder => folder.date))
    this.selectedFolderDates = new Set(Array.from(this.selectedFolderDates).filter(date => selectable.has(date)))
    this.recomputeExpandedFolderDates()
  }

  @Monitor('videoListController.directoryFolderSelection')
  onDirectoryFolderSelectionChanged(): void {
    if (this.videoListController.directoryFolderSelection && this.folderSelectionMode) {
      this.closeFolderSelection()
    }
  }

  @Monitor('sideBarController.isShow', 'currentSourceTab')
  onFolderSelectionContextChanged(): void {
    if (!this.sideBarController.isShow || this.currentSourceTab !== 0) {
      this.closeFolderSelection()
    }
  }

  @Monitor('visibleTreeFolders', 'folderSelectionMode', 'currentSourceTab')
  onFolderTreeIndicesChanged(): void {
    this.publishFolderTreeIndices()
  }

  @Monitor('sidebarContentHeight')
  onSidebarContentHeightChanged(): void {
    this.onContentHeightChange(this.sidebarContentHeight)
  }

  @Builder
  FolderSelectionToolbarBuilder() {
    Column({ space: 6 }) {
      Row() {
        Text($r('app.string.folder_selection_count', this.selectedFolderDates.size))
          .fontSize(13).fontColor($r('app.color.text_color')).layoutWeight(1)
        Button($r('app.string.cancel'), { type: ButtonType.Normal })
          .fontSize(13)
          .height(28)
          .backgroundColor(Color.Transparent)
          .fontColor($r('app.color.main_color'))
          .onClick(() => {
            this.closeFolderSelection()
          })
      }.width('100%')

      Row({ space: 8 }) {
        Button(this.allFoldersSelected() ? $r('app.string.deselect_all') : $r('app.string.select_all'),
          { type: ButtonType.Normal })
          .fontSize(13)
          .height(32)
          .layoutWeight(1)
          .borderRadius(10)
          .fontColor($r('app.color.text_color'))
          .backgroundColor($r('app.color.list_item_background'))
          .onClick(() => {
            this.toggleAllFolderSelection()
          })
        Button($r('app.string.delete_selected'), { type: ButtonType.Normal })
          .fontSize(13)
          .height(32)
          .layoutWeight(1)
          .borderRadius(10)
          .fontColor($r('sys.color.white'))
          .backgroundColor($r('app.color.main_color'))
          .enabled(this.selectedFolderDates.size > 0)
          .onClick(() => {
            this.confirmFolderSelectionDelete()
          })
      }.width('100%')
    }.width('100%').padding({ left: 16, right: 16, bottom: 8 })
  }

  @Builder
  FileFolderSelectMenu(folder: FileFolder) {
    FolderContextMenu(folder, this.folderMenuActions, this.folderSelectionMode,
      () => this.startFolderSelection(folder), () => {
        if (!this.folderMenuActions.deleting) {
          this.closeFolderSelection()
        }
      }, this.folderMenuActions.playDisc)
  }

  @Builder
  FolderSortMenuBuilder() {
    SortMenuComponent({
      currentSortField: this.folderSortField,
      currentSortAsc: this.folderSortAsc,
      pinyinSort: this.folderPinyinSort,
      pinyinSortField: SortField.FOLDER_NAME,
      items: [
        {
          field: SortField.FOLDER_NAME,
          icon: $r('sys.symbol.textformat'),
          textResource: $r('app.string.sort_folder_by_name'),
          onAction: (): void => this.handleFolderSort(SortField.FOLDER_NAME, true)
        },
        {
          field: SortField.FOLDER_DATETIME,
          icon: $r('sys.symbol.calendar'),
          textResource: $r('app.string.sort_folder_by_datetime'),
          onAction: (): void => this.handleFolderSort(SortField.FOLDER_DATETIME, false)
        },
        {
          field: SortField.FOLDER_COUNT,
          icon: $r('sys.symbol.sort'),
          textResource: $r('app.string.sort_folder_by_count'),
          onAction: (): void => this.handleFolderSort(SortField.FOLDER_COUNT, false)
        }
      ],
      onPinyinSortChange: (value: boolean): void => {
        this.folderPinyinSort = value
        Preferences.savePinyinSort(PathUtils.appContext!, this.folderPinyinSort)
        if (this.folderSortField === SortField.FOLDER_NAME) {
          void this.sortFoldersByName()
        }
      }
    })
  }

  build() {
    List({ space: 0, scroller: this.sideBarScroller }) {
      if (this.folderSelectionMode && this.currentSourceTab === 0) {
        ListItem() {
          this.FolderSelectionToolbarBuilder()
        }
        .onSizeChange((_oldValue: SizeResult, newValue: SizeResult) => {
          const height = Number(newValue.height)
          if (Number.isFinite(height) && height > 0 && Math.abs(height - this.folderToolbarHeight) > 0.5) {
            this.folderToolbarHeight = height
          }
        })
      }
      ListItem() {
        Column() {
          this.importActions()
          Button({ type: ButtonType.Normal, stateEffect: true }) {
            Row() {
              SymbolGlyph($r('sys.symbol.folder_badge_plus'))
                .attributeModifier(new SymbolGlyphFancyModifier(25, '', ''))
              Text($r('app.string.add_folder'))
                .fontSize(15)
                .margin({ left: 10, right: 12 })
                .textOverflow({ overflow: TextOverflow.MARQUEE })
            }
          }
          .align(Alignment.Start)
          .padding({ left: 16, right: 16 })
          .attributeModifier(new ButtonFancyModifier('100%', 60))
          .backgroundColor(Color.Transparent)
          .animation({ duration: 300, curve: Curve.Ease })
          .onClick(() => {
            this.addFileFolderNameDialogController.open()
          })
        }
        .justifyContent(FlexAlign.Start)
        .backgroundColor($r('app.color.list_item_background'))
        .borderRadius(16)
        .width('100%')
      }
      .onSizeChange((_oldValue: SizeResult, newValue: SizeResult) => {
        const height = Number(newValue.height)
        if (Number.isFinite(height) && height > 0 && Math.abs(height - this.importActionsHeight) > 0.5) {
          this.importActionsHeight = height
        }
      })

      ListItem() {
        // 文件夹标题行 + 排序
        Row() {
          Text($r('app.string.folder'))
            .fontSize(14)
            .fontColor($r('sys.color.font_tertiary'))
            .fontWeight(FontWeight.Medium)
            .margin({ left: 4 })
            .textOverflow({ overflow: TextOverflow.MARQUEE })
          Blank()
          Button({ type: ButtonType.Circle, stateEffect: true }) {
            SymbolGlyph($r('sys.symbol.text_and_arrow_down'))
              .fontSize(16)
              .fontColor([$r('sys.color.font_tertiary')])
          }.attributeModifier(new ButtonFancyModifier(28, 28))
          .backgroundColor(Color.Transparent)
          .bindMenu(this.FolderSortMenuBuilder,
            {
              backgroundBlurStyle: BlurStyle.Regular,
              hapticFeedbackMode: HapticFeedbackMode.ENABLED
            })
          .margin({ right: 4 })
        }
        .width('100%')
        .height(32)
        .alignItems(VerticalAlign.Center)
        .padding({ left: 16, right: 16 })
      }

      Repeat<FileFolder>(this.visibleTreeFolders)
        .each((repeatItem: RepeatItem<FileFolder>) => {
          ListItem() {
            FileFolderListBuilder({
              folder: repeatItem.item,
              videoListController: this.videoListController,
              fileFolderSource: this.fileFolderSource,
              expandedFolderDates: this.expandedFolderDates,
              depth: FileFolderUtil.getFolderDepth(PathUtils.appContext!, repeatItem.item.date,
                this.fileFolderSource.data),
              hasChildren: this.fileFolderSource.data.some(
                folder => folder.parent_date === repeatItem.item.date),
              isExpanded: this.expandedFolderDates.has(repeatItem.item.date),
              selectionMode: this.folderSelectionMode,
              selected: this.selectedFolderDates.has(repeatItem.item.date),
              selectable: repeatItem.item.name !== '首页',
              onToggleExpand: (folderDate: string) => {
                const newExpandedSet = new Set(this.expandedFolderDates)
                const newCollapsedSet = new Set(this.collapsedFolderDates)
                if (newExpandedSet.has(folderDate)) {
                  newExpandedSet.delete(folderDate)
                  newCollapsedSet.add(folderDate)
                } else {
                  newExpandedSet.add(folderDate)
                  newCollapsedSet.delete(folderDate)
                }
                this.expandedFolderDates = newExpandedSet
                this.collapsedFolderDates = newCollapsedSet
                Preferences.saveCollapsedFolderDates(PathUtils.appContext!,
                  Array.from(this.collapsedFolderDates))
              }
            })
          }
          .onClick(() => {
            this.activateFolder(repeatItem.item)
          })
          .attributeModifier(new LibraryItemFocus(this.libraryKeyboard, 'sidebar-folder', repeatItem.item.date,
            () => this.activateFolder(repeatItem.item)))
          .bindContextMenu(this.FileFolderSelectMenu(repeatItem.item), ResponseType.LongPress)
          .bindContextMenu(this.FileFolderSelectMenu(repeatItem.item), ResponseType.RightClick)
          .width('100%')
          .padding({
            left: 8,
            right: 8,
            top: repeatItem.index === 0 ? 4 : 0,
            bottom: repeatItem.index === this.visibleTreeFolders.length - 1 ? 4 : 2
          })
          .backgroundColor($r('app.color.list_item_background'))
          .borderRadius({
            topLeft: repeatItem.index === 0 ? 12 : 0,
            topRight: repeatItem.index === 0 ? 12 : 0,
            bottomLeft: repeatItem.index === this.visibleTreeFolders.length - 1 ? 12 : 0,
            bottomRight: repeatItem.index === this.visibleTreeFolders.length - 1 ? 12 : 0
          })
        })
        .key((item: FileFolder) => item.date)
        .virtualScroll()
    }
    .width('100%')
    .height('100%')
    .padding({ left: 8, right: 8 })
    .contentEndOffset(12)
    .fadingEdge(true)
    .nestedScroll({
      scrollForward: NestedScrollMode.PARENT_FIRST,
      scrollBackward: NestedScrollMode.SELF_FIRST
    })
    .edgeEffect(EdgeEffect.None)
    .scrollBar(BarState.Off)
    .onKeyEvent((event: KeyEvent): boolean => {
      if (!this.sideBarController.isShow || this.currentSourceTab !== 0 || this.folderMenuActions.deleting) {
        return false
      }
      const action = KeyboardShortcuts.home(event)
      if (action === ShortcutAction.SELECT_ALL) {
        if (this.libraryKeyboard.accept(action)) {
          this.libraryKeyboard.onFolderAction?.(action,
            this.libraryKeyboard.focusDate)
        }
        return true
      }
      if (this.folderSelectionMode && action === ShortcutAction.DELETE) {
        if (this.libraryKeyboard.accept(action)) {
          this.confirmFolderSelectionDelete()
        }
        return true
      }
      if (this.folderSelectionMode && action === ShortcutAction.ESCAPE) {
        if (this.libraryKeyboard.accept(action)) {
          this.closeFolderSelection()
        }
        return true
      }
      return false
    })
  }

  private publishFolderTreeIndices(): void {
    const indices = new Map<string, number>()
    if (this.currentSourceTab !== 0) {
      this.onFolderTreeIndicesChange(indices)
      return
    }
    // 导入操作和文件夹标题各占一项，多选工具栏出现时再增加一项。
    const firstFolderIndex = 2 + (this.folderSelectionMode && this.currentSourceTab === 0 ? 1 : 0)
    this.visibleTreeFolders.forEach((folder: FileFolder, index: number) => {
      indices.set(folder.date, firstFolderIndex + index)
    })
    this.onFolderTreeIndicesChange(indices)
  }

  private closeFolderSelection(): void {
    this.folderSelectionMode = false
    this.selectedFolderDates = new Set()
  }

  private activateFolder(folder: FileFolder): void {
    if (this.folderMenuActions.deleting || this.videoListController.directoryTransitioning) {
      return
    }
    if (this.folderSelectionMode) {
      this.toggleFolderSelection(folder)
      return
    }
    this.searchValueClear()
    if (this.videoListController.folder?.date === folder.date && !this.videoListController.directoryOverview) {
      return
    }
    const currentFolder = Preferences.getFileFolder(PathUtils.appContext!).find(item => item.date === folder.date)
    if (!currentFolder) {
      return
    }
    let videos = currentFolder.video_list
    this.videoListController.directoryFolderSelection = undefined
    this.videoListController.videoDataSource.updateData(videos)
    this.videoListController.directoryOverview = false
    this.videoListController.updateData(this.videoListController.videoDataSource, currentFolder)
    VideoUtils.refresh(this.videoListController, this.fileFolderSource, currentFolder)
    this.scrollToFolderDateChange(folder.date)
    this.sideBarController.closeIfOverlay(true)
  }

  private startFolderSelection(folder: FileFolder): void {
    if (this.folderMenuActions.deleting || this.videoListController.directoryTransitioning) {
      return
    }
    this.videoListController.closeMultipleChoose()
    this.videoListController.directoryFolderSelection = undefined
    this.folderSelectionMode = true
    this.selectedFolderDates = new Set(folder.name === '首页' ? [] : [folder.date])
  }

  private toggleFolderSelection(folder: FileFolder): void {
    if (this.folderMenuActions.deleting || folder.name === '首页') {
      return
    }
    const selected = new Set(this.selectedFolderDates)
    if (selected.has(folder.date)) {
      selected.delete(folder.date)
    } else {
      selected.add(folder.date)
    }
    this.selectedFolderDates = selected
  }

  private allFoldersSelected(): boolean {
    const folders = FolderSelection.selectable(this.file_folder_list)
    return folders.length > 0 && folders.every(folder => this.selectedFolderDates.has(folder.date))
  }

  private toggleAllFolderSelection(): void {
    if (this.folderMenuActions.deleting) {
      return
    }
    this.selectedFolderDates = this.allFoldersSelected() ? new Set() :
      new Set(FolderSelection.selectable(this.file_folder_list).map(folder => folder.date))
  }

  private confirmFolderSelectionDelete(): void {
    this.folderMenuActions.confirmDelete(Array.from(this.selectedFolderDates), () => this.closeFolderSelection())
  }

  @Monitor('folderMenuActions.deleting')
  onFolderDeletingChanged(): void {
    this.onDeletingChange(this.folderMenuActions.deleting)
  }

  private recomputeExpandedFolderDates() {
    const newSet = new Set<string>()
    for (const folder of this.file_folder_list) {
      if (FileFolderUtil.getChildFolders(PathUtils.appContext!, folder.date).length > 0 &&
        !this.collapsedFolderDates.has(folder.date)) {
        newSet.add(folder.date)
      }
    }
    this.expandedFolderDates = newSet
  }

  private handleFolderSort(field: SortField, defaultAsc: boolean) {
    // 使先前仍在运行的名称排序结果失效。
    this.folderSortRequestId++
    if (this.folderSortField === field) {
      this.folderSortAsc = !this.folderSortAsc
    } else {
      this.folderSortField = field
      this.folderSortAsc = defaultAsc
    }
    Preferences.saveFolderSortField(PathUtils.appContext!, this.folderSortField)
    Preferences.saveFolderSortAsc(PathUtils.appContext!, this.folderSortAsc)
    if (field === SortField.FOLDER_NAME) {
      void this.sortFoldersByName()
      return
    }
    const homeFolder = this.file_folder_list.find(f => f.name === '首页' && f.parent_date === null)
    let otherFolders = this.file_folder_list.filter(f => f.date !== homeFolder?.date)
    switch (field) {
      case SortField.FOLDER_DATETIME:
        otherFolders.sort((a, b) => {
          const cmp = Number(a.date) - Number(b.date)
          return this.folderSortAsc ? cmp : -cmp
        })
        break
      case SortField.FOLDER_COUNT:
        otherFolders.sort((a, b) => {
          const cmp = a.video_list.length - b.video_list.length
          return this.folderSortAsc ? cmp : -cmp
        })
        break
    }
    this.fileFolderListChange(homeFolder ? [homeFolder, ...otherFolders] : otherFolders)
  }

  private async sortFoldersByName(): Promise<void> {
    const requestId = ++this.folderSortRequestId
    const source = this.file_folder_list
    const homeFolder = source.find(f => f.name === '首页' && f.parent_date === null)
    const otherFolders = source.filter(f => f.date !== homeFolder?.date)
    const sorted = await ToolsUtil.sortFoldersByNameInTaskPool(otherFolders, this.folderSortAsc, this.folderPinyinSort)
    // 用户在任务运行期间切换了文件夹或排序规则时，丢弃过期结果。
    if (requestId !== this.folderSortRequestId || source !== this.file_folder_list ||
      this.folderSortField !== SortField.FOLDER_NAME) {
      return
    }
    this.fileFolderListChange(homeFolder ? [homeFolder, ...sorted] : sorted)
  }
}
