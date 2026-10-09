import FolderHierarchy from '../../utils/FolderHierarchy'
import { FileFolderDataSource } from '../../utils/DataUtil'
import { AddFileFolderNameDialog } from '../Dialog/AddFileFolderNameDialog'
import { RenameDialog } from '../Dialog/RenameDialog'
import { MoveFileFolderDialog } from '../Dialog/MoveFileFolderDialog'
import { FolderOpeningEndingDialog } from '../Dialog/FolderOpeningEndingDialog'
import { FileFolder } from '../../interfaces/FileFolderInterface'
import { ButtonFancyModifier, DefaultDialogShadow, SymbolGlyphFancyModifier } from '../../common/AttributeModifierConfig'
import { PathUtils } from '../../utils/PathUtils'
import { VideoListController } from '../../controller/VideoListController'
import { SideBarController } from './SideBar'
import Preferences from '../../database/Preferences'
import { SortField } from '../../common/enum/SortField'
import { FileFolderListBuilder } from '../FileFolderComponent/FileFolderListComponent'
import { FolderSelectMenuBuilder } from '../FileFolderComponent/FileFolderSelectBuilder'
import { SortMenuComponent } from '../common/SortMenuComponent'
import { FolderOperator } from '../../database/VideoMetaData'
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import DataSyncUtil from '../../utils/DataSyncUtil'
import FileFolderUtil from '../../utils/FileFolderUtil'
import ToolsUtil from '../../utils/ToolsUtil'
import VideoUtils from '../../utils/VideoUtil'
import { SafeHeight } from '../../utils/ObservedUtil'
import FolderSelection from '../../utils/FolderSelection'
import { InfoConfirmDialog } from '../Dialog/InfoConfirmDialog'
import { salmonLogger } from 'salmonlogger'

@ComponentV2
export struct SideBarFolderComponent {
  @Param sideBarController: SideBarController = new SideBarController()
  @Param videoListController: VideoListController = new VideoListController()
  @Param fileFolderSource: FileFolderDataSource = new FileFolderDataSource([])
  @Param file_folder_list: FileFolder[] = []
  @Param sideBarScroller: Scroller = new Scroller()
  @Param currentSourceTab: number = 0
  @BuilderParam importActions: () => void
  @Event scrollToFolderDateChange: (date: string) => void = () => {}
  @Event searchValueClear: () => boolean = () => false
  @Event onDeletingChange: (deleting: boolean) => void = () => {}
  @Local expandedFolderDates: Set<string> = new Set()
  @Local collapsedFolderDates: Set<string> = new Set()
  @Local folderSelectionMode: boolean = false
  @Local selectedFolderDates: Set<string> = new Set()
  @Local folderDeleting: boolean = false
  private folderDeleteDialogController: CustomDialogController | undefined = undefined
  @Local folderSortField: SortField | '' = ''
  @Local folderSortAsc: boolean = true
  @Local folderPinyinSort: boolean = true

  folderOpeningEndingDialogController: CustomDialogController = new CustomDialogController({
    builder: FolderOpeningEndingDialog({
      onConfirm: (folderDate: string, startTime: number, endTime: number) => {
        this.updateFolderOpeningEndingTimes(folderDate, startTime, endTime)
      }
    }), cornerRadius: 20, shadow: DefaultDialogShadow
  })
  private folderSortRequestId: number = 0
  @Event fileFolderListChange: (folders: FileFolder[]) => void = () => {
  }
  addFileFolderNameDialogController: CustomDialogController = new CustomDialogController({
    builder: AddFileFolderNameDialog({
      onFolderAdded: (folders: FileFolder[]) => {
        this.fileFolderListChange(folders)
      }
    }), cornerRadius: 20, shadow: DefaultDialogShadow
  })
  editFileFolderNameDialogController: CustomDialogController = new CustomDialogController({
    builder: RenameDialog({
      title: $r('app.string.rename_new_folder'),
      renameTarget: 'folder',
      onConfirm: async (newFolderName: string) => {
        await FileFolderUtil.changeFileFolderName(PathUtils.appContext!,
          DataSyncUtil.editingFolder!, newFolderName, this.fileFolderSource)
        const updatedFolders = Preferences.getFileFolder(PathUtils.appContext!) as FileFolder[]
        this.fileFolderListChange(updatedFolders)
        this.fileFolderSource.updateData(updatedFolders)
      }
    }), cornerRadius: 20, shadow: DefaultDialogShadow
  })
  moveFileFolderDialogController: CustomDialogController = new CustomDialogController({
    builder: MoveFileFolderDialog({
      onFolderMoved: (folders: FileFolder[]) => {
        this.fileFolderListChange(folders)
        this.fileFolderSource.updateData(folders)
      }
    }), cornerRadius: 20, shadow: DefaultDialogShadow
  })

  aboutToAppear(): void {
    const savedFolderField = Preferences.getFolderSortField(PathUtils.appContext!)
    if (savedFolderField === SortField.FOLDER_NAME || savedFolderField === SortField.FOLDER_DATETIME ||
      savedFolderField === SortField.FOLDER_COUNT) {
      this.folderSortField = savedFolderField as SortField
    }
    this.folderSortAsc = Preferences.getFolderSortAsc(PathUtils.appContext!)
    this.folderPinyinSort = Preferences.getPinyinSort(PathUtils.appContext!)
    this.collapsedFolderDates = new Set(Preferences.getCollapsedFolderDates(PathUtils.appContext!))

    this.recomputeExpandedFolderDates()
  }

  aboutToDisappear(): void {
    this.folderSortRequestId++
    this.folderDeleteDialogController?.close()
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

  @Monitor('sideBarController.isShow', 'currentSourceTab')
  onFolderSelectionContextChanged(): void {
    if (!this.sideBarController.isShow || this.currentSourceTab !== 0) { this.closeFolderSelection() }
  }

  private closeFolderSelection(): void {
    this.folderSelectionMode = false
    this.selectedFolderDates = new Set()
  }

  private startFolderSelection(folder: FileFolder): void {
    if (this.folderDeleting || this.videoListController.directoryTransitioning) { return }
    this.videoListController.closeMultipleChoose()
    this.folderSelectionMode = true
    this.selectedFolderDates = new Set(folder.name === '首页' ? [] : [folder.date])
  }

  private toggleFolderSelection(folder: FileFolder): void {
    if (this.folderDeleting || folder.name === '首页') { return }
    const selected = new Set(this.selectedFolderDates)
    if (selected.has(folder.date)) { selected.delete(folder.date) }
    else { selected.add(folder.date) }
    this.selectedFolderDates = selected
  }

  private allFoldersSelected(): boolean {
    const folders = FolderSelection.selectable(this.file_folder_list)
    return folders.length > 0 && folders.every(folder => this.selectedFolderDates.has(folder.date))
  }

  private toggleAllFolderSelection(): void {
    if (this.folderDeleting) { return }
    this.selectedFolderDates = this.allFoldersSelected() ? new Set() :
      new Set(FolderSelection.selectable(this.file_folder_list).map(folder => folder.date))
  }

  private confirmFolderSelectionDelete(): void {
    if (this.folderDeleting || this.selectedFolderDates.size === 0) { return }
    const selected = Array.from(this.selectedFolderDates)
    const plan = FolderSelection.deletionPlan(Preferences.getFileFolder(PathUtils.appContext!), selected)
    if (plan.dates.size === 0) { return }
    this.folderDeleteDialogController = new CustomDialogController({
      builder: InfoConfirmDialog({
        textInfo: $r('app.string.folder_batch_delete_confirm', plan.dates.size, plan.videoCount),
        confirm: () => { void this.deleteSelectedFolders(selected) }
      }), cornerRadius: 20, shadow: DefaultDialogShadow
    })
    this.folderDeleteDialogController.open()
  }

  private async deleteSelectedFolders(selected: string[]): Promise<void> {
    if (this.folderDeleting) { return }
    this.folderDeleting = true
    this.onDeletingChange(true)
    try {
      const folders = await FileFolderUtil.deleteFileFoldersRecursive(PathUtils.appContext!, selected,
        this.fileFolderSource)
      const current = folders.find(folder => folder.date === this.videoListController.folder?.date) ??
        folders.find(folder => folder.name === '首页') ?? folders[0]
      this.searchValueClear()
      this.fileFolderListChange(folders)
      if (current) {
        const refreshed = VideoUtils.refresh(this.videoListController, this.fileFolderSource, current)
        this.fileFolderListChange(refreshed)
        this.scrollToFolderDateChange(current.date)
      }
      this.closeFolderSelection()
    } catch (error) {
      salmonLogger.addLog('FolderBatchDelete', 'delete folders failed: ' + (error as Error).message, true)
      ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.folder_batch_delete_failed').id))
    } finally {
      this.folderDeleting = false
      this.onDeletingChange(false)
    }
  }

  @Builder
  FolderSelectionToolbarBuilder() {
    Column({ space: 6 }) {
      Row() {
        Text($r('app.string.folder_selection_count', this.selectedFolderDates.size))
          .fontSize(13).fontColor($r('app.color.text_color')).layoutWeight(1)
        Button($r('app.string.cancel'), { type: ButtonType.Normal })
          .fontSize(13).height(28).backgroundColor(Color.Transparent)
          .fontColor($r('app.color.main_color'))
          .onClick(() => { this.closeFolderSelection() })
      }.width('100%')
      Row({ space: 8 }) {
        Button(this.allFoldersSelected() ? $r('app.string.deselect_all') : $r('app.string.select_all'),
          { type: ButtonType.Normal })
          .fontSize(13).height(32).layoutWeight(1).borderRadius(10)
          .fontColor($r('app.color.text_color')).backgroundColor($r('app.color.list_item_background'))
          .onClick(() => { this.toggleAllFolderSelection() })
        Button($r('app.string.delete_selected'), { type: ButtonType.Normal })
          .fontSize(13).height(32).layoutWeight(1).borderRadius(10)
          .fontColor($r('sys.color.white')).backgroundColor($r('app.color.main_color'))
          .enabled(this.selectedFolderDates.size > 0)
          .onClick(() => { this.confirmFolderSelectionDelete() })
      }.width('100%')
    }.width('100%').padding({ left: 16, right: 16, bottom: 8 })
  }

  @Builder
  FileFolderSelectMenu(folder: FileFolder) {
    if (this.folderSelectionMode) {
      FolderSelectMenuBuilder([{
        icon: $r('sys.symbol.xmark'), content: $r('app.string.cancel'),
        onAction: () => { if (!this.folderDeleting) { this.closeFolderSelection() } }
      }])
    } else if (folder.name !== '首页') {
      FolderSelectMenuBuilder([
        {
          icon: $r('sys.symbol.checkmark_square'), content: $r('app.string.multiple_choice'),
          onAction: () => { this.startFolderSelection(folder) }
        },
        {
          icon: $r('sys.symbol.time_lapse'),
          content: $r('app.string.menu_intro_outro'),
          onAction: () => {
            this.openFolderOpeningEndingDialog(folder)
          },
        },
        {
          icon: $r("sys.symbol.trash_fill"),
          content: $r('app.string.delete'),
          onAction: async () => {
            const newFolders = await FileFolderUtil.deleteFileFolderRecursive(PathUtils.appContext!, folder)
            this.videoListController.closeMultipleChoose()
            this.fileFolderListChange(newFolders)
            let newFolder: FileFolder | undefined
            if (!newFolders.some(item => item.date === this.videoListController.folder?.date)) {
              newFolder = newFolders[0]
            } else {
              newFolder = this.videoListController.folder
            }
            this.videoListController.folder = newFolder
            if (newFolder) {
              this.scrollToFolderDateChange(newFolder.date)
            }
            VideoUtils.refresh(this.videoListController, this.fileFolderSource, newFolder)
          },
        },
        {
          icon: $r('sys.symbol.rename'),
          content: $r('app.string.edit'),
          onAction: () => {
            DataSyncUtil.editingFolder = folder
            this.editFileFolderNameDialogController.open()
          },
        },
        {
          icon: $r('sys.symbol.arrow_right_folder_circle'),
          content: $r('app.string.move_folder'),
          onAction: () => {
            DataSyncUtil.movingFolderDate = folder.date
            this.moveFileFolderDialogController.open()
          },
        },
      ])
    } else {
      FolderSelectMenuBuilder([
        {
          icon: $r('sys.symbol.checkmark_square'), content: $r('app.string.multiple_choice'),
          onAction: () => { this.startFolderSelection(folder) }
        },
        {
          icon: $r('sys.symbol.time_lapse'),
          content: $r('app.string.menu_intro_outro'),
          onAction: () => {
            this.openFolderOpeningEndingDialog(folder)
          },
        },
      ])
    }
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
    Column() {
      if (this.folderSelectionMode && this.currentSourceTab === 0) {
        this.FolderSelectionToolbarBuilder()
      }
      Scroll(this.sideBarScroller) {
        Column() {
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
          .shadow({
            radius: 4,
            color: $r('app.color.shadow_color'),
            offsetX: 0,
            offsetY: 1
          })

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
            }
            .width(28)
            .height(28)
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

          // 文件夹列表
          List({ space: 2 }) {
            Repeat<FileFolder>(this.getFlattenedTreeFolders())
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
                  if (this.folderDeleting) { return }
                  if (this.folderSelectionMode) {
                    this.toggleFolderSelection(repeatItem.item)
                    return
                  }
                  if (this.videoListController.directoryTransitioning) { return }
                  this.searchValueClear()
                  if (this.videoListController.folder?.date === repeatItem.item.date &&
                    !this.videoListController.directoryOverview) {
                    return
                  }
                  const latestFolders = Preferences.getFileFolder(PathUtils.appContext!)
                  const currentFolder = latestFolders.find(f => f.date === repeatItem.item.date)
                  if (!currentFolder) {
                    return
                  }
                  let folderVideos: VideoMetadata[] = currentFolder.video_list
                  const sortField = Preferences.getSortField(PathUtils.appContext!) as SortField
                  if (sortField) {
                    const sortAsc = Preferences.getSortAsc(PathUtils.appContext!)
                    folderVideos =
                      ToolsUtil.sortBy(PathUtils.appContext!, folderVideos, currentFolder, sortField, sortAsc)
                  }
                  this.videoListController.videoDataSource.updateData(folderVideos)
                  this.videoListController.directoryOverview = false
                  this.videoListController.updateData(this.videoListController.videoDataSource, currentFolder!)
                  this.scrollToFolderDateChange(repeatItem.item.date)
                  this.sideBarController.closeIfOverlay(true)
                })
                .bindContextMenu(this.FileFolderSelectMenu(repeatItem.item), ResponseType.LongPress)
                .bindContextMenu(this.FileFolderSelectMenu(repeatItem.item), ResponseType.RightClick)
              })
              .key((item: FileFolder) => item.date)
              .virtualScroll()
          }
          .shadow({
            radius: 4,
            color: $r('app.color.shadow_color'),
            offsetX: 0,
            offsetY: 1
          })
          .scrollBar(BarState.Off)
          .borderRadius(12)
          .width('100%')
          .height('auto')
          .align(Alignment.Start)
          .padding({
            left: 8,
            right: 8,
            top: 4,
            bottom: 4
          })
          .backgroundColor($r('app.color.list_item_background'))
          .nestedScroll({
            scrollForward: NestedScrollMode.PARENT_FIRST,
            scrollBackward: NestedScrollMode.SELF_FIRST
          })
          .edgeEffect(EdgeEffect.None)
        }
        .width('100%')
      }
      .fadingEdge(true)
      .padding({ left: 16, right: 16, bottom: SafeHeight.bottomSafeHeight })
      .align(Alignment.Top)
      .edgeEffect(EdgeEffect.Spring)
      .scrollBar(BarState.Off)
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
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

  private getFlattenedTreeFolders(): FileFolder[] {
    return FolderHierarchy.flatten(this.fileFolderSource.data, this.expandedFolderDates)
  }

  private openFolderOpeningEndingDialog(folder: FileFolder): void {
    if (folder.video_list.length === 0) {
      ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.folder_no_video').id))
      return
    }
    DataSyncUtil.editingFolder = folder
    this.folderOpeningEndingDialogController.open()
  }

  private updateFolderOpeningEndingTimes(folderDate: string, startTime: number, endTime: number): void {
    const updatedFolders = FolderOperator.updateFolderOpeningEndingTimes(folderDate, startTime, endTime)
    const updatedFolder = updatedFolders.find(folder => folder.date === folderDate)
    if (!updatedFolder) {
      ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.folder_not_exist_set_failed').id))
      return
    }
    this.fileFolderSource.updateData(updatedFolders)
    this.fileFolderListChange(updatedFolders)
    if (this.videoListController.folder?.date === folderDate) {
      const visibleVideoDates = new Set(this.videoListController.videoDataSource.getAllData().map(video => video.date))
      const visibleVideos = updatedFolder.video_list.filter(video => visibleVideoDates.has(video.date))
      this.videoListController.videoDataSource.updateData(visibleVideos)
      this.videoListController.updateData(this.videoListController.videoDataSource, updatedFolder)
    }
    ToolsUtil.showToast(`已更新 ${updatedFolder.video_list.length} 个视频的片头片尾时间`)
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
