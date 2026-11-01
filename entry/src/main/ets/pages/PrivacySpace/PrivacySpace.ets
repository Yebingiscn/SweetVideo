import MediaLibraryService from '../../utils/MediaLibraryService'
import MediaSortUtil from '../../utils/MediaSortUtil'
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import SelectFileUtil from '../../utils/SelectFileUtil'
import { VideoDataSource } from '../../utils/DataUtil'
import ToolsUtil from '../../utils/ToolsUtil'
import DataSyncUtil from '../../utils/DataSyncUtil'
import { LengthMetrics, SymbolGlyphModifier, UIUtils } from '@kit.ArkUI'
import { VideoDetailSheetBuilder } from '../../component/Dialog/VideoDetailDialog'
import Preferences from '../../database/Preferences'
import PrivacySpaceUtil from '../../utils/PrivacySpaceUtil'
import { FileFolder } from '../../interfaces/FileFolderInterface'
import {
  ButtonFancyModifier,
  DefaultDialogShadow,
  LightMaterialModifier,
  MenuFancyModifier,
  SymbolGlyphFancyModifier
} from '../../common/AttributeModifierConfig'
import { PathUtils } from '../../utils/PathUtils'
import { EditPasswordDialog } from '../../component/Dialog/EditPasswordDialog'
import NavigationAddress, { PrivacySpaceParams } from '../../common/NavigationCommon'
import { RenameDialog } from '../../component/Dialog/RenameDialog'
import { InfoConfirmDialog } from '../../component/Dialog/InfoConfirmDialog'
import { ImportSelectDialog } from '../../component/Dialog/ImportSelectDialog'
import { ImportProgressBuilder } from '../../component/VideoItemComponent/ImportProgressBuilder'
import VideoCardItem from '../../component/VideoItemComponent/VideoCardItemComponent'
import { ListDisplayMode } from '../../common/enum/DisplayMode'
import { SortField } from '../../common/enum/SortField'
import ShareUtil from '../../utils/ShareUtil'
import { Privacy, PrivacySecureUtil, Setting } from '../../utils/ObservedUtil'
import {
  DELAY_JUMP_TO_PLAYER,
  FULL_ALPHABET,
  NO_BLUR_AMOUNT,
  PRIVACY_BACKGROUND_BLUR_AMOUNT
} from '../../common/Constants'
import VideoOperateUtil from '../../utils/VideoOperateUtil'
import { VideoItemPreviewBuilder } from '../../component/VideoItemComponent/VideoItemPreviewBuilder'
import { hdsMaterial, HdsNavDestination, HideMode, ScrollEffectType } from '@kit.UIDesignKit'
import { motion } from '@kit.MultimodalAwarenessKit'
import IntellectualGripPostureUtil from '../../utils/IntellectualGripPostureUtil'
import { ScrollBarBuilder } from '../../component/VideoItemComponent/ScrollBarBuilder'
import VideoListItem from '../../component/VideoItemComponent/VideoListItemComponent'
import { VideoListController } from '../../controller/VideoListController'
import { SortMenuComponent } from '../../component/common/SortMenuComponent'

import { PrivacySpaceSettingComponent } from '../../component/PrivacySpaceComponent/PrivacySpaceSettingComponent'
import { SearchComponent } from '../../component/VideoItemComponent/SearchComponent'
import { XAnimation } from '../../utils/AnimationUtil'
import DlpAntiPeepUtil from '../../utils/DlpAntiPeepUtil'
import { ConcurrencyManagerUtil, importAndProcessFiles, ProgressInfo } from '../../utils/FileProcessorUtil'
import SubtitleUtil from '../../utils/SubtitleUtil'
import { SuppressWarnings, SuppressWarningsType } from '@kit.BasicServicesKit'
import { salmonLogger } from 'salmonlogger'
import PrivacyBatchDeleteUtil from '../../utils/PrivacyBatchDeleteUtil'
import { MediaBatchProgress, MediaBatchResult } from '../../interfaces/MediaBatchInterface'
import PrivacyFolderUtil, { PrivacyFolderState } from '../../utils/PrivacyFolderUtil'
import FolderHierarchy from '../../utils/FolderHierarchy'
import FolderDirectory from '../../utils/FolderDirectory'
import { AddFileFolderNameDialog } from '../../component/Dialog/AddFileFolderNameDialog'
import { FolderPickerDialog } from '../../component/Dialog/FolderPickerDialog'

interface PrivacyFolderNavigationLabel {
  date: string
  name: ResourceStr
  videoCount: number
}

const TAG = 'PrivacySpace'

@ComponentV2
export struct PrivacySpace { // 隐私空间页
  @Local privacyState: PrivacySecureUtil = Privacy
  @Local videoDataSource: VideoDataSource = new VideoDataSource([])
  @Local video_meta_data_encryption: VideoMetadata[] = []
  @Local allVideos: VideoMetadata[] = [] // 保存完整数据用于搜索
  private folderState: PrivacyFolderState = PrivacyFolderUtil.empty()
  @Local privateFolders: FileFolder[] = []
  @Local childFolders: FileFolder[] = []
  @Local folderPath: FileFolder[] = []
  @Local currentFolderDate: string = PrivacyFolderUtil.ALL
  @Local currentFolderVideoCount: number = 0
  @Local folderWorking: boolean = false
  @Local folderDataReady: boolean = true
  private folderDialog: CustomDialogController | undefined = undefined
  @Local list_line: number = 1
  @Consumer('pathStack') pathStack: NavPathStack = new NavPathStack()
  @Local totalItems: number = 0
  @Local processedItems: number = 0
  @Local loading: boolean = false
  @Local currentFileName: string = '' // 当前处理的文件名
  @Local failedCount: number = 0 // 失败文件数
  @Local currentStage: 'extracting' | 'cover' | 'saving' = 'extracting' // 当前处理阶段
  @Local searchValue: string = ''
  editMetadataDialogController: CustomDialogController = new CustomDialogController({
    builder: RenameDialog({
      title: $r('app.string.rename'),
      renameTarget: 'video',
      preserveExtension: true,
      onConfirm: (title: string) => {
        const editingVideo = DataSyncUtil.editingVideo
        if (!editingVideo) {
          return
        }
        const latestVideos = Preferences.getVideoMetaDataEncryption(PathUtils.appContext!)
        // 搜索结果下标不等于完整记录下标，使用稳定 ID 在最新完整列表中定位。
        const targetIndex = MediaLibraryService.getItemIndex(latestVideos, editingVideo)
        if (targetIndex === -1) {
          return
        }
        if (latestVideos.some((v, index) => index !== targetIndex && v.title === title)) {
          return
        }
        // 只修改名称，保留播放记忆、字幕、外挂音频等全部已有字段。
        const updatedVideo = latestVideos[targetIndex]
        updatedVideo.title = title
        DataSyncUtil.editingVideo = updatedVideo
        Preferences.saveVideoMetaDataEncryption(PathUtils.appContext!, latestVideos)
        this.allVideos = [...latestVideos]
        this.searchValue = ''
        this.applySearch()
      },
    }), cornerRadius: 20, shadow: DefaultDialogShadow
  })
  @Local is_edit: boolean = false
  @Local currentSortField: SortField | '' = ''
  @Local currentSortAsc: boolean = true
  @Local pinyinSort: boolean = true
  @Local activeAlphabet: string[] = []
  @Local indexerSelected: number = 0
  @Local passwd: string = 'passwd'
  editPasswdDialogController: CustomDialogController = new CustomDialogController({
    builder: EditPasswordDialog({
      confirm: (passwd: string | undefined) => {
        if (!passwd || passwd.trim() == '') {
          return
        }
        this.passwd = passwd
        ToolsUtil.savePwd(PathUtils.appContext!, passwd)
        ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.set_passwd_tip').id))
      },
    }), cornerRadius: 20, shadow: DefaultDialogShadow
  })
  @Local delMultipleList: VideoMetadata[] = []
  @Local multipleChooseState: Visibility = Visibility.None
  @Local batchWorking: boolean = false
  @Local batchStopping: boolean = false
  @Provider('videoListController') privacyVideoListController: VideoListController =
    new VideoListController()
  @Local isPresent: boolean = false
  importSelectDialog: CustomDialogController = new CustomDialogController({
    builder: ImportSelectDialog({
      onImportVideo: async () => {
        this.isPresent = false
        const target = this.privateFolders.find(folder => folder.date === this.currentFolderDate) ?? null
        await this.toMetaData(await SelectFileUtil.selectFromFileManager(undefined, "video"), target)
      },
      onImportAlbum: async () => {
        this.isPresent = false
        const target = this.privateFolders.find(folder => folder.date === this.currentFolderDate) ?? null
        await this.toMetaData(await SelectFileUtil.selectFromFileManager(undefined, "album"), target)
      },
      onImportMusic: async () => {
        this.isPresent = false
        const target = this.privateFolders.find(folder => folder.date === this.currentFolderDate) ?? null
        await this.toMetaData(await SelectFileUtil.selectFromFileManager(undefined, "audio"), target)
      }
    }), cornerRadius: 20, shadow: DefaultDialogShadow
  })
  searchController: SearchController = new SearchController()
  @Local showDetailSheet: boolean = false
  @Local detailMetadata: VideoMetadata | undefined = undefined
  @Local HoldingHand: motion.HoldingHandStatus | null = null
  batchDeleteConfirmDialog: CustomDialogController = new CustomDialogController({
    builder: InfoConfirmDialog({
      textInfo: $r('app.string.delete_selected_videos_permanent'),
      confirm: async () => {
        await this.batchDeleteItems()
      }
    }), cornerRadius: 20, shadow: DefaultDialogShadow
  })
  private batchCancelled: boolean = false
  private pageActive: boolean = false
  private pendingBatchDeleteDates: string[] = []
  private knockFilesMonitorRegistered: boolean = false
  private pendingDeleteItem: VideoMetadata | null = null
  deleteConfirmDialog: CustomDialogController = new CustomDialogController({
    builder: InfoConfirmDialog({
      textInfo: $r('app.string.delete_video_confirm'),
      confirm: () => {
        if (this.pendingDeleteItem) {
          this.deleteItem(this.pendingDeleteItem.date, this.pendingDeleteItem.title)
        }
      }
    }), cornerRadius: 20, shadow: DefaultDialogShadow
  })
  private listScroller: ListScroller = new ListScroller()
  private waterFlowScroller: ListScroller = new ListScroller()

  private refreshLibrary(): void {
    try {
      this.allVideos = Preferences.getVideoMetaDataEncryption(PathUtils.appContext!, true)
      try {
        this.folderState = Preferences.getPrivacyFolders(PathUtils.appContext!)
        this.folderDataReady = true
      } catch (_) {
        // 文件夹数据读取失败时仍能访问全部视频，但禁止用空索引覆盖原有归属。
        this.folderDataReady = false
        this.currentFolderDate = PrivacyFolderUtil.ALL
        ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.privacy_folder_load_failed').id))
      }
      this.applySearch()
    } catch (_) {
      salmonLogger.addLog(TAG, '隐私空间数据读取失败，保留现有视图', true)
    }
  }

  private async updateFolders(update: (state: PrivacyFolderState, videos: VideoMetadata[]) => PrivacyFolderState):
    Promise<boolean> {
    if (!this.pageActive || this.batchWorking || this.loading || this.folderWorking || !this.folderDataReady) return false
    this.folderWorking = true
    const lock = ConcurrencyManagerUtil.getLock('global_data')
    let acquired = false
    try {
      await lock.acquire()
      acquired = true
      if (!this.pageActive) return false
      const videos = Preferences.getVideoMetaDataEncryption(PathUtils.appContext!, true)
      const next = update(Preferences.getPrivacyFolders(PathUtils.appContext!), videos)
      Preferences.savePrivacyFolders(PathUtils.appContext!, next)
      this.folderState = next
      this.allVideos = videos
      this.applySearch()
      return true
    } catch (error) {
      const reason = (error as Error).message
      let message: Resource = $r('app.string.privacy_folder_operation_failed')
      if (reason === 'privacy_folder_invalid_name') message = $r('app.string.privacy_folder_invalid_name')
      if (reason === 'same_folder_name_exists') message = $r('app.string.same_folder_name_exists')
      if (reason === 'target_folder_not_found') message = $r('app.string.target_folder_missing')
      if (reason === 'privacy_folder_cycle') message = $r('app.string.cannot_move_into_self')
      salmonLogger.addLog(TAG, '隐私文件夹操作失败，保留视频和已有归属', true)
      if (this.pageActive) ToolsUtil.showToast(ToolsUtil.getStringResource(message.id))
      return false
    } finally {
      if (acquired) lock.release()
      this.folderWorking = false
    }
  }

  private openFolder(date: string): void {
    if (this.batchWorking || this.loading || this.folderWorking || !this.folderDataReady) return
    this.closeMultipleChoose()
    this.currentFolderDate = date
    this.searchValue = ''
    this.applySearch()
    try {
      if (Setting.listDisplayMode === ListDisplayMode.LIST_DISPLAY) this.listScroller.scrollEdge(Edge.Top)
      else this.waterFlowScroller.scrollTo({ xOffset: 0, yOffset: 0, animation: false })
    } catch (_) {
      // 从空目录切回时滚动容器尚未挂载，新容器默认从顶部开始。
    }
  }

  private createFolder(): void {
    if (this.batchWorking || this.loading || this.folderWorking || !this.folderDataReady) return
    this.folderDialog = new CustomDialogController({
      builder: AddFileFolderNameDialog({
        foldersOverride: this.privateFolders,
        initialParentDate: this.currentFolderDate === PrivacyFolderUtil.ALL ? null : this.currentFolderDate || null,
        onCreateFolder: (name: string, parentDate: string | null): void => {
          void this.updateFolders((state: PrivacyFolderState): PrivacyFolderState =>
            PrivacyFolderUtil.create(state, name, parentDate))
        }
      }), cornerRadius: 20, shadow: DefaultDialogShadow
    })
    this.folderDialog.open()
  }

  private renameFolder(folder: FileFolder): void {
    DataSyncUtil.editingFolder = folder
    this.folderDialog = new CustomDialogController({
      builder: RenameDialog({
        title: $r('app.string.rename_new_folder'), renameTarget: 'folder',
        onConfirm: (name: string): void => {
          void this.updateFolders((state: PrivacyFolderState): PrivacyFolderState =>
            PrivacyFolderUtil.rename(state, folder.date, name))
        }
      }), cornerRadius: 20, shadow: DefaultDialogShadow
    })
    this.folderDialog.open()
  }

  private moveFolder(folder: FileFolder): void {
    this.folderDialog = new CustomDialogController({
      builder: FolderPickerDialog({
        title: $r('app.string.move_folder'), folders: this.privateFolders,
        initialDate: folder.parent_date ?? '',
        excludedDates: Array.from(FolderHierarchy.descendants(this.privateFolders, folder.date)),
        onConfirm: (date: string): void => {
          void this.updateFolders((state: PrivacyFolderState): PrivacyFolderState =>
            PrivacyFolderUtil.moveFolder(state, folder.date, date || null))
        }
      }), cornerRadius: 20, shadow: DefaultDialogShadow
    })
    this.folderDialog.open()
  }

  private removeFolder(folder: FileFolder): void {
    this.folderDialog = new CustomDialogController({
      builder: InfoConfirmDialog({
        textInfo: $r('app.string.privacy_folder_delete_confirm'),
        confirm: (): void => {
          void this.runBatchOperation('delete', [], folder.date)
        }
      }), cornerRadius: 20, shadow: DefaultDialogShadow
    })
    this.folderDialog.open()
  }

  private chooseMoveTarget(dates: string[]): void {
    if (dates.length === 0 || this.batchWorking || this.loading || this.folderWorking || !this.folderDataReady) return
    const selected = new Set(dates)
    this.folderDialog = new CustomDialogController({
      builder: FolderPickerDialog({
        folders: this.privateFolders,
        initialDate: this.currentFolderDate === PrivacyFolderUtil.ALL ? '' : this.currentFolderDate,
        onConfirm: async (date: string): Promise<void> => {
          const saved = await this.updateFolders((state: PrivacyFolderState, videos: VideoMetadata[]): PrivacyFolderState =>
            PrivacyFolderUtil.moveVideos(state, videos.filter(video => selected.has(video.date)).map(video => video.date), date))
          if (saved && this.pageActive) this.closeMultipleChoose()
        }
      }), cornerRadius: 20, shadow: DefaultDialogShadow
    })
    this.folderDialog.open()
  }

  @Builder
  FolderMenuBuilder(folder: FileFolder) {
    Menu() {
      MenuItem({ content: $r('app.string.rename') }).onClick(() => this.renameFolder(folder))
      MenuItem({ content: $r('app.string.move_folder') }).onClick(() => this.moveFolder(folder))
      MenuItem({ content: $r('app.string.delete') }).onClick(() => this.removeFolder(folder))
    }
    .attributeModifier(new MenuFancyModifier())
    .enabled(!this.batchWorking && !this.loading && !this.folderWorking && this.folderDataReady)
  }

  @Builder
  FolderLabelBuilder(label: PrivacyFolderNavigationLabel) {
    Text() {
      Span(label.name)
      if (this.currentFolderDate === label.date) {
        Span(` (${label.videoCount})`)
      }
    }
    .fontSize(13)
    .maxLines(1)
    .fontColor(this.currentFolderDate === label.date ?
      (label.date === PrivacyFolderUtil.ALL ? $r('sys.color.white') : $r('app.color.main_color')) :
      $r('app.color.text_color'))
  }

  @Builder
  FolderNavigationBuilder() {
    Column({ space: 6 }) {
      Row({ space: 8 }) {
        Button() {
          this.FolderLabelBuilder({ date: PrivacyFolderUtil.ALL, name: $r('app.string.privacy_all_videos'),
            videoCount: this.allVideos.length })
        }
          .height(36)
          .padding({ left: 16, right: 16 })
          .flexShrink(0)
          .backgroundColor(this.currentFolderDate === PrivacyFolderUtil.ALL ? $r('app.color.main_color') : Color.Transparent)
          .onClick(() => this.openFolder(PrivacyFolderUtil.ALL))
        Scroll() {
          Row({ space: 4 }) {
            Button() {
              this.FolderLabelBuilder({ date: '', name: $r('app.string.root_folder'),
                videoCount: this.currentFolderVideoCount })
            }
              .height(36)
              .backgroundColor(Color.Transparent)
              .onClick(() => this.openFolder(''))
            Repeat<FileFolder>(this.folderPath)
              .each((entry: RepeatItem<FileFolder>) => {
                Row({ space: 4 }) {
                  SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(10)
                    .fontColor([$r('app.color.text_color')])
                  Button() {
                    this.FolderLabelBuilder({ date: entry.item.date, name: entry.item.name,
                      videoCount: entry.item.video_list.length })
                  }
                    .height(36)
                    .backgroundColor(Color.Transparent)
                    .onClick(() => this.openFolder(entry.item.date))
                    .bindContextMenu(this.FolderMenuBuilder(entry.item), ResponseType.LongPress)
                    .bindContextMenu(this.FolderMenuBuilder(entry.item), ResponseType.RightClick)
                }
              })
              .key((folder: FileFolder) => folder.date)
          }
        }
        .scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).height(36).layoutWeight(1)
      }.padding({ left: 16, right: 16 }).width('100%')
      if (this.childFolders.length > 0 && this.folderDataReady) {
        List({ space: 8 }) {
          Repeat<FileFolder>(this.childFolders)
            .each((entry: RepeatItem<FileFolder>) => {
              ListItem() {
                Button({ type: ButtonType.Normal }) {
                  this.FolderLabelBuilder({ date: entry.item.date, name: entry.item.name,
                    videoCount: entry.item.video_list.length })
                }
                .attributeModifier(new ButtonFancyModifier('', 38))
                .attributeModifier(new LightMaterialModifier())
                .padding({ left: 12, right: 12 })
                .onClick(() => this.openFolder(entry.item.date))
                .bindContextMenu(this.FolderMenuBuilder(entry.item), ResponseType.LongPress)
                .bindContextMenu(this.FolderMenuBuilder(entry.item), ResponseType.RightClick)
              }
            })
            .key((folder: FileFolder) => folder.date)
            .virtualScroll()
        }
        .listDirection(Axis.Horizontal).height(40).width('100%')
        .padding({ left: 16, right: 16 }).scrollBar(BarState.Off)
      }
    }
    .enabled(!this.batchWorking && !this.loading && !this.folderWorking && this.folderDataReady)
    .padding({ top: 6, bottom: 8 }).width('100%')
  }

  @Builder
  PrivacySpaceSettingBuilder() {
    PrivacySpaceSettingComponent({
      isPresent: this.isPresent,
      passwd: this.passwd,
      onEditPasswdDialogOpen: () => {
        this.editPasswdDialogController.open()
      },
      onIsPresentChange: (isPresent: boolean) => {
        this.isPresent = isPresent
      }
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
          this.applySearch()
        },
        onEditChange: (isEditing: boolean) => {
          XAnimation.runWithAnimation(() => {
            this.is_edit = isEditing
          })
        }
      })

      if (!this.is_edit) {
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.text_and_arrow_down'))
            .attributeModifier(new SymbolGlyphFancyModifier(25, '', ''))
        }
        .attributeModifier(new ButtonFancyModifier(40, 40))
        .enabled(!this.batchWorking && !this.loading)
        .transition(XAnimation.getAnimation('right', 0, false))
        .bindMenu(this.SortMenuBuilder, { showInSubWindow: false })
        .attributeModifier(new LightMaterialModifier())

        if (this.multipleChooseState === Visibility.Visible) {
          Button({ type: ButtonType.Circle, stateEffect: true }) {
            SymbolGlyph($r('sys.symbol.checkmark_square_on_square'))
              .attributeModifier(new SymbolGlyphFancyModifier(25, '', ''))
          }
          .attributeModifier(new ButtonFancyModifier(40, 40))
          .transition(XAnimation.getAnimation('right', 0, false))
          .bindMenu(this.SelectItemMenuBuilder, { showInSubWindow: false })
          .attributeModifier(new LightMaterialModifier())
        }
      }
    }
    .width('95%')
    .justifyContent(FlexAlign.Start)
    .reverse(IntellectualGripPostureUtil.isLeftHoldHand(this.HoldingHand))
    .animation({ duration: 300, curve: Curve.Ease })
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
          icon: $r('sys.symbol.play_round_triangle_fill'),
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
      MenuItem({ content: $r('app.string.privacy_selected_count', this.delMultipleList.length) })
        .enabled(false)
      MenuItem({ content: $r('app.string.cancel') })
        .enabled(!this.batchWorking)
        .onClick(() => {
          this.closeMultipleChoose()
        })
      MenuItem({
        content: this.areAllVisibleSelected() ? $r('app.string.deselect_all') : $r('app.string.select_all')
      })
        .enabled(!this.batchWorking && !this.loading)
        .onClick(() => {
          this.toggleSelectAll()
        })
      MenuItem({ content: $r('app.string.delete_selected') })
        .enabled(this.delMultipleList.length > 0 && !this.batchWorking && !this.loading)
        .onClick(() => {
          this.confirmBatchDelete()
        })
      MenuItem({ content: $r('app.string.move_to_folder'),
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.folder')) })
        .enabled(this.delMultipleList.length > 0 && !this.batchWorking && !this.loading &&
          !this.folderWorking && this.folderDataReady)
        .onClick(() => this.chooseMoveTarget(this.delMultipleList.map(item => item.date)))
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.arrow_right_folder_circle')),
        content: $r('app.string.privacy_export_selected')
      })
        .enabled(this.delMultipleList.length > 0 && !this.batchWorking && !this.loading)
        .onClick(async () => {
          await this.batchExportItems()
        })
    }.attributeModifier(new MenuFancyModifier())
  }

  @Builder
  MenuBuilder(item: VideoMetadata | undefined) {
    Menu() {
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.play_round_triangle')),
        content: VideoOperateUtil.getPlayerName(Setting.defaultPlayerEngine, true)
      })
        .onClick(() => {
          setTimeout(async () => { //延迟跳转，确保弹窗关闭，防止系统误识别为子窗口导致播放器异常
            await this.clickItem(item, true)
          }, DELAY_JUMP_TO_PLAYER)
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.play_round_rectangle')),
        content: $r('app.string.short_video_mode')
      })
        .onClick(() => {
          setTimeout(async () => {
            if (item) {
              await ToolsUtil.routerToShortVideo(this.pathStack, item, this.video_meta_data_encryption)
            }
          }, DELAY_JUMP_TO_PLAYER)
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.info_circle')),
        content: $r('app.string.menu_detail')
      })
        .onClick(() => {
          this.detailMetadata = item
          this.showDetailSheet = true
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.trash_fill')), content: $r('app.string.delete')
      })
        .onClick(() => {
          if (this.multipleChooseState === Visibility.Visible) {
            const isSelected = this.delMultipleList.some(v => v.date === item?.date)
            if (!isSelected) {
              this.delMultipleList = [...this.delMultipleList, item!]
            }
            this.confirmBatchDelete()
          } else {
            this.pendingDeleteItem = item!
            this.deleteConfirmDialog.open()
          }
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.checkmark_square_on_square')),
        content: this.multipleChooseState === Visibility.Visible ? $r('app.string.multi_select_off') :
          $r('app.string.multiple_choice')
      })
        .onClick(() => {
          XAnimation.runWithAnimation(() => {
            this.multipleChooseState =
              this.multipleChooseState === Visibility.None ? Visibility.Visible : Visibility.None
          })
          this.delMultipleList = this.multipleChooseState === Visibility.Visible && item ? [item] : []
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.rename')),
        content: $r('app.string.rename')
      })
        .onClick(() => {
          DataSyncUtil.editingVideo = item
          this.editMetadataDialogController.open()
        })
      MenuItem({ content: $r('app.string.move_to_folder'),
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.folder')) })
        .enabled(this.folderDataReady)
        .onClick(() => {
          if (item) this.chooseMoveTarget(this.multipleChooseState === Visibility.Visible ?
            Array.from(new Set([...this.delMultipleList.map(video => video.date), item.date])) : [item.date])
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.arrow_right_folder_circle')),
        content: $r('app.string.export')
      })
        .onClick(async () => {
          await SelectFileUtil.exportFile(item!.uri, item!.title, item!.format, PathUtils.appContext!)
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.textformat_size_square')),
        content: $r('app.string.import_or_delete_subtitle')
      })
        .onClick(async () => {
          await SubtitleUtil.importOrDeleteSubtitleProcess(item!)
          const targetIndex = MediaLibraryService.getItemIndex(this.allVideos, item!)
          if (targetIndex !== -1) {
            this.allVideos[targetIndex] = item!
            const displayIndex = MediaLibraryService.getItemIndex(this.video_meta_data_encryption, item!)
            if (displayIndex !== -1) {
              this.video_meta_data_encryption[displayIndex] = item!
              this.videoDataSource.updateItem(displayIndex, item!)
            }
            Preferences.saveVideoMetaDataEncryption(PathUtils.appContext!, this.allVideos)
          }
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.share')),
        content: $r('app.string.share')
      })
        .onClick(async () => {
          await ShareUtil.shareVideo(item!.uri, item!.title)
        })
    }.attributeModifier(new MenuFancyModifier())
    .enabled(!this.batchWorking && !this.loading && !this.folderWorking)
  }

  async toMetaData(fileList: string[], fileFolder?: FileFolder | null) {
    if (this.batchWorking || this.loading || this.folderWorking || !this.pageActive) {
      return
    }
    // 导入始终使用完整记录，不能把搜索视图作为可持久化的数据源。
    const importVideos = Preferences.getVideoMetaDataEncryption(PathUtils.appContext!)
    await importAndProcessFiles(
      fileList,
      importVideos,
      (info: ProgressInfo) => {
        this.processedItems = info.current
        this.currentFileName = info.fileName
        this.currentStage = info.stage
        this.failedCount = info.failedCount
      },
      (loading: boolean) => {
        this.loading = loading
      },
      (totalItems: number) => {
        this.totalItems = totalItems
      },
      fileFolder === undefined ? this.privateFolders.find(folder => folder.date === this.currentFolderDate) :
        fileFolder ?? undefined,
      () => {
        if (this.pageActive) this.refreshLibrary()
      }
    )
  }

  @Monitor('multipleChooseState')
  onMultipleChooseStateChanged() {
    this.privacyVideoListController.multipleChooseState = this.multipleChooseState
  }

  onKnockFilesReceived(_mon: IMonitor): void {
    if (this.pageActive) this.refreshLibrary()
  }

  async aboutToAppear(): Promise<void> {
    this.pageActive = true
    this.registerKnockFilesMonitor()
    PrivacySpaceUtil.setPrivacyMode(true)
    // 只有当 AI隐私防窥 开关开启时才检查并引导用户设置
    if (Setting.enableAiPrivacyAntiPeep) {
      DlpAntiPeepUtil.checkDlpAntiPeepStatus()
    }
    const savedField = Preferences.getSortField(PathUtils.appContext!)
    if (savedField === SortField.NAME || savedField === SortField.DATETIME || savedField === SortField.TIME ||
      savedField === SortField.RECENT_PLAY) {
      this.currentSortField = savedField as SortField
    }
    this.currentSortAsc = Preferences.getSortAsc(PathUtils.appContext!)
    this.pinyinSort = Preferences.getPinyinSort(PathUtils.appContext!)
    this.refreshLibrary()
  }

  aboutToDisappear(): void {
    this.pageActive = false
    this.searchSortVersion++
    this.batchCancelled = true
    this.unregisterKnockFilesMonitor()
    this.folderDialog?.close()
    this.folderDialog = undefined
  }

  async clickItem(item: VideoMetadata | undefined, reverse: boolean = false) {
    if (this.batchWorking || this.loading || this.folderWorking) {
      return
    }
    if (this.searchValue) {
      setTimeout(() => {
        AppStorage.setOrCreate('searchValue', this.searchValue)
        this.searchValue = ''
      }, 500)
    }
    await SelectFileUtil.isFileExist(item?.uri!, true) ?
      ToolsUtil.routerWhere(this.pathStack, item!,
        this.video_meta_data_encryption, reverse) :
      await this.deleteItem(item!.date, item!.title)
  }

  async deleteItem(date: string, _title: string) {
    // 与批量删除共用稳定 ID、最新全量数据及并发锁，不使用当前文件夹的显示下标。
    await this.runBatchOperation('delete', [date])
  }

  @SuppressWarnings({ rules: [SuppressWarningsType.SYSCAP] })
  build() {
    HdsNavDestination() {
      Column() {
        this.FolderNavigationBuilder()
        if (this.batchWorking) {
          ImportProgressBuilder({
            processedItems: this.processedItems,
            totalItems: this.totalItems,
            currentFileName: this.currentFileName,
            currentStage: 'saving',
            failedCount: this.failedCount
          })
          Button($r('app.string.cancel'))
            .enabled(!this.batchStopping)
            .margin({ top: 8, bottom: 12 })
            .onClick(() => {
              this.batchStopping = true
              this.batchCancelled = true
            })
        }
        if (this.loading) {

          ImportProgressBuilder({
            processedItems: this.processedItems,
            totalItems: this.totalItems,
            currentFileName: this.currentFileName,
            currentStage: this.currentStage,
            failedCount: this.failedCount
          })
        }
        if (this.video_meta_data_encryption.length == 0 && !this.loading) {
          Column() {
            if (this.searchValue.trim() !== '') {
              Text($r('app.string.no_matching_video')).fontSize(25).fontWeight(FontWeight.Bold)
            } else {
              Text($r('app.string.nothing')).fontSize(25).fontWeight(FontWeight.Bold)
              Text($r('app.string.privacy_space_info'))
                .fontSize(15)
                .textAlign(TextAlign.Center)
                .fontWeight(FontWeight.Lighter)
                .margin({ top: 20 })
            }
          }
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .animation({ duration: 150, curve: Curve.Ease })
        } else {
          if (Setting.listDisplayMode === ListDisplayMode.LIST_DISPLAY) {
            Stack({
              alignContent: IntellectualGripPostureUtil.isLeftHoldHand(this.HoldingHand) ? Alignment.TopStart :
                Alignment.TopEnd
            }) {
              List({ scroller: this.listScroller, space: 10 }) {
                Repeat<VideoMetadata>(this.videoDataSource.data)
                  .each((repeatItem: RepeatItem<VideoMetadata>) => {
                    ListItem() {
                      VideoListItem({
                        item: repeatItem.item,
                        delMultipleList: this.delMultipleList
                      })
                    }
                    .backgroundColor(Setting.listItemBackgroundBlur ? undefined :
                      $r('app.color.start_window_background'))
                    .borderRadius(12)
                    .width('100%')
                    .height('auto')
                    .onClick(async () => {
                      if (this.batchWorking) {
                        return
                      }
                      if (this.multipleChooseState === Visibility.Visible) {
                        if (this.delMultipleList.some(v => v.date === repeatItem.item.date)) {
                          this.delMultipleList = this.delMultipleList.filter(v => v.date !== repeatItem.item.date)
                        } else {
                          this.delMultipleList = [...this.delMultipleList, repeatItem.item]
                        }
                      } else {
                        await this.clickItem(repeatItem.item)
                      }
                    })
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
                        mask: true
                      })
                    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
                    .transition(TransitionEffect.OPACITY.animation({ duration: 150, curve: Curve.Sharp }))
                    .swipeAction({
                      end: this.itemEnd(repeatItem.item),
                      edgeEffect: SwipeEdgeEffect.Spring
                    })
                  })
                  .key((item: VideoMetadata, _index: number) => item.date + item.title + item.last_play +
                    item.size.toString() + item.time)
                  .virtualScroll()
              }
              .clip(false)
              .lanes(this.list_line)
              .layoutWeight(1)
              .padding({ left: 16, right: 16 })
              .width('100%')
              .height('100%')
              .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
              .chainAnimation(true)
              .scrollBar(BarState.Off)
              .onScrollIndex((start: number, _end: number, _center: number) => {
                if (this.currentSortField === SortField.NAME && this.pinyinSort) {
                  this.updateIndexerOnScroll(start)
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
                  .margin(IntellectualGripPostureUtil.isLeftHoldHand(this.HoldingHand) ? { left: 2 } : { right: 2 })
              }

              if (this.currentSortField !== SortField.NAME || !this.pinyinSort) {
                ScrollBarBuilder({
                  videoListController: this.listScroller,
                  fileFolderLength: 0
                })
              }
            }
            .animation({ duration: 300, curve: Curve.Ease })
            .layoutWeight(1)
            .width('100%')
          } else {
            Stack({
              alignContent: IntellectualGripPostureUtil.isLeftHoldHand(this.HoldingHand) ? Alignment.TopStart :
                Alignment.TopEnd
            }) {
              WaterFlow({ scroller: this.waterFlowScroller, layoutMode: WaterFlowLayoutMode.SLIDING_WINDOW }) {
                Repeat<VideoMetadata>(this.videoDataSource.data)
                  .each((repeatItem: RepeatItem<VideoMetadata>) => {
                    FlowItem() {
                      VideoCardItem({
                        item: repeatItem.item,
                        delMultipleList: this.delMultipleList
                      }).width('100%')
                    }
                    .backgroundColor(Setting.listItemBackgroundBlur ? undefined :
                      (Setting.backgroundImageSrc.length > 0 ?
                        $r('app.color.start_window_background_blur') :
                        $r('app.color.start_window_background')))
                    .borderRadius(12)
                    .width('100%')
                    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
                    .onClick(async () => {
                      if (this.batchWorking) {
                        return
                      }
                      if (this.multipleChooseState === Visibility.Visible) {
                        if (this.delMultipleList.some(v => v.date === repeatItem.item.date)) {
                          this.delMultipleList = this.delMultipleList.filter(v => v.date !== repeatItem.item.date)
                        } else {
                          this.delMultipleList = [...this.delMultipleList, repeatItem.item]
                        }
                      } else {
                        await this.clickItem(repeatItem.item)
                      }
                    })
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
                        mask: true
                      })
                  })
                  .key((item: VideoMetadata, _index: number) => item.date + item.title + item.last_play +
                    item.size.toString() + item.time)
                  .virtualScroll()
              }
              .columnsTemplate('1fr '.repeat(this.list_line).trim())
              .columnsGap(16)
              .rowsGap(16)
              .padding({ left: 16, right: 16 })
              .onScrollIndex((first: number) => {
                if (this.currentSortField === SortField.NAME && this.pinyinSort) {
                  this.updateIndexerOnScroll(first)
                }
              })
              .clip(false)
              .scrollBar(BarState.Off)
              .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
              .width('100%')
              .height('100%')
              .layoutWeight(1)

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
                  .margin(IntellectualGripPostureUtil.isLeftHoldHand(this.HoldingHand) ? { left: 2 } : { right: 2 })
              }

              if (this.currentSortField !== SortField.NAME || !this.pinyinSort) {
                ScrollBarBuilder({
                  videoListController: this.waterFlowScroller,
                  fileFolderLength: 0
                })
              }
            }
            .animation({ duration: 300, curve: Curve.Ease })
            .layoutWeight(1)
            .width('100%')
          }
        }
      }
      .width('100%')
      .height('100%')
      .enabled(!this.folderWorking)
      .onAreaChange(async (_oldValue: Area, newValue: Area) => {
        const width = Number(newValue.width)
        const base = Math.floor(width / 500)
        this.list_line = Setting.listDisplayMode === ListDisplayMode.LIST_DISPLAY
          ? base + 1
          : base + 2
      })
      .bindSheet(this.isPresent, this.PrivacySpaceSettingBuilder, {
        detents: [SheetSize.FIT_CONTENT],
        preferType: SheetType.CENTER,
        enableOutsideInteractive: false,
        dragBar: true,
        showClose: true,
        title: { title: $r('app.string.privacy_space_settings') },
        onWillDismiss: () => {
          this.isPresent = false
        }
      })
    }
    .onWillDisappear(() => {
      this.pageActive = false
      this.searchSortVersion++
      IntellectualGripPostureUtil.destroyHoldingHandStatus()
      PrivacySpaceUtil.closePrivacyMode()
    })
    .onShown(() => {
      this.pageActive = true
      PrivacySpaceUtil.setPrivacyMode(true)
      this.refreshLibrary()
      if (DataSyncUtil.lastPlayVideoIndex >= 0) {
        const activeScroller = Setting.listDisplayMode === ListDisplayMode.LIST_DISPLAY
          ? this.listScroller : this.waterFlowScroller
        activeScroller.scrollToIndex(DataSyncUtil.lastPlayVideoIndex)
        DataSyncUtil.lastPlayVideoIndex = -1
      }
      const value: string | undefined = AppStorage.get('searchValue')
      if (value) {
        this.searchValue = value
        AppStorage.set('searchValue', '')
        this.applySearch()
      }
    })
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
        title: {
          mainTitle: $r('app.string.privacy_space'),
        },
        menu: {
          value: [{
            content: {
              label: '',
              icon: $r('sys.symbol.plus'),
              isEnabled: !this.batchWorking && !this.loading && !this.folderWorking,
              action: () => {
                this.importSelectDialog.open()
              }
            }
          }, {
            content: {
              label: $r('app.string.new_folder'),
              icon: $r('sys.symbol.folder_badge_plus'),
              isEnabled: !this.batchWorking && !this.loading && !this.folderWorking && this.folderDataReady,
              action: () => {
                this.createFolder()
              }
            }
          }, {
            content: {
              label: '',
              icon: $r('sys.symbol.gearshape'),
              isEnabled: true,
              action: () => {
                this.isPresent = true
              }
            }
          }]
        },
        bottomBuilder: { builder: (): void => this.SearchBuilder() },
      },
    })
    .backgroundColor($r('app.color.start_window_background'))
    .backgroundImage(
      Setting.backgroundDropBlur > 0 && Setting.backgroundBlurImageSrc.length > 0 ? Setting.backgroundBlurImageSrc :
        Setting.backgroundImageSrc, ImageRepeat.NoRepeat)
    .backgroundImageSize(ImageSize.Cover)
    .backgroundImagePosition(Alignment.Center)
    .onBackPressed(() => {
      if (this.folderWorking) return true
      if (this.batchWorking) {
        this.batchStopping = true
        this.batchCancelled = true
        return true
      }
      if (this.multipleChooseState === Visibility.Visible) {
        this.closeMultipleChoose()
        return true
      }
      if (this.searchValue.length > 0) {
        this.searchValue = ''
        this.applySearch()
        return true
      }
      if (this.currentFolderDate !== PrivacyFolderUtil.ALL && this.currentFolderDate !== '') {
        this.openFolder(this.privateFolders.find(folder => folder.date === this.currentFolderDate)?.parent_date ?? '')
        return true
      }
      return false
    })
    .bindToScrollable([this.listScroller, this.waterFlowScroller])
    .blur(Privacy.isPrivacyBackground ? PRIVACY_BACKGROUND_BLUR_AMOUNT : NO_BLUR_AMOUNT)
    .onReady(() => {
      const privacySpaceParams =
        this.pathStack.getParamByName(NavigationAddress.PRIVACY_SPACE)[0] as PrivacySpaceParams
      if (privacySpaceParams?.needGotoSetting) {
        this.isPresent = true
      }
      IntellectualGripPostureUtil.createHoldingHandStatus((data: motion.HoldingHandStatus) => {
        this.HoldingHand = data
      })
    })
    .dynamicHideTitleBar({
      hideTitleArea: true,
      hideBottomBuilder: true,
      hideStatusBar: false,
      mode: HideMode.SCROLL_UP
    })
    .hideBackButton(false)

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
  DetailSheetBuilder() {
    VideoDetailSheetBuilder(this.detailMetadata)
  }

  @Builder
  itemEnd(item: VideoMetadata) {
    Row({ space: 10 }) {
      Stack().width(10)
      SymbolGlyph($r('sys.symbol.arrow_right_folder_circle'))
        .attributeModifier(new SymbolGlyphFancyModifier(28, 40, 40))
        .onClick(async () => {
          if (this.batchWorking || this.loading) {
            return
          }
          await SelectFileUtil.exportFile(item!.uri, item!.title, item!.format, PathUtils.appContext!)
        })
    }.padding({ left: 16, right: 16 }).justifyContent(FlexAlign.SpaceEvenly)
  }

  @Monitor('video_meta_data_encryption', 'currentSortField', 'currentSortAsc', 'pinyinSort')
  onVideoListChanged() {
    if (this.currentSortField === SortField.NAME && this.pinyinSort) {
      this.updateActiveAlphabet()
    } else {
      this.activeAlphabet = []
    }
  }

  private registerKnockFilesMonitor(): void {
    if (this.knockFilesMonitorRegistered) {
      return
    }
    try {
      UIUtils.addMonitor(this.privacyState, 'receivedFilesVersion', (mon: IMonitor): void => {
        this.onKnockFilesReceived(mon)
      })
      this.knockFilesMonitorRegistered = true
    } catch (error) {
      salmonLogger.addLog(TAG, `注册碰一碰文件监听失败: ${error}`, true)
    }
  }

  private unregisterKnockFilesMonitor(): void {
    if (!this.knockFilesMonitorRegistered) {
      return
    }
    this.knockFilesMonitorRegistered = false
    try {
      UIUtils.clearMonitor(this.privacyState, 'receivedFilesVersion')
    } catch (error) {
      salmonLogger.addLog(TAG, `注销碰一碰文件监听失败: ${error}`, true)
    }
  }

  private closeMultipleChoose() {
    if (this.batchWorking) {
      return
    }
    XAnimation.runWithAnimation(() => {
      this.multipleChooseState = Visibility.None
    })
    this.delMultipleList = []
  }

  private areAllVisibleSelected(): boolean {
    const selected = new Set(this.delMultipleList.map(item => item.date))
    return this.video_meta_data_encryption.length > 0 &&
      this.video_meta_data_encryption.every(item => selected.has(item.date))
  }

  private toggleSelectAll(): void {
    if (this.batchWorking || this.loading) {
      return
    }
    const visible = new Set(this.video_meta_data_encryption.map(item => item.date))
    const hiddenSelection = this.delMultipleList.filter(item => !visible.has(item.date))
    this.delMultipleList = this.areAllVisibleSelected() ? hiddenSelection :
      [...hiddenSelection, ...this.video_meta_data_encryption]
  }

  private syncSelectedItems(): void {
    const selected = new Set((this.delMultipleList ?? []).map(item => item.date))
    this.delMultipleList = this.allVideos.filter(item => selected.has(item.date))
  }

  private confirmBatchDelete(): void {
    if (this.batchWorking || this.loading || this.delMultipleList.length === 0) {
      return
    }
    this.pendingBatchDeleteDates = this.delMultipleList.map(item => item.date)
    this.batchDeleteConfirmDialog.open()
  }

  private async batchDeleteItems(): Promise<void> {
    const dates = this.pendingBatchDeleteDates.slice()
    this.pendingBatchDeleteDates = []
    await this.runBatchOperation('delete', dates)
  }

  private async batchExportItems(): Promise<void> {
    await this.runBatchOperation('export', this.delMultipleList.map(item => item.date))
  }

  private async runBatchOperation(operation: 'delete' | 'export', dates: string[], folderDate?: string): Promise<void> {
    if (this.batchWorking || this.loading || this.folderWorking || !this.pageActive ||
      (dates.length === 0 && folderDate === undefined) || (folderDate !== undefined && !this.folderDataReady)) {
      return
    }
    this.batchWorking = true
    this.batchStopping = false
    this.batchCancelled = false
    this.processedItems = 0
    this.failedCount = 0
    this.currentFileName = ''
    this.totalItems = dates.length
    const isCancelled = (): boolean => this.batchCancelled || !this.pageActive
    const onProgress = (info: MediaBatchProgress): void => {
      if (!this.pageActive) {
        return
      }
      this.processedItems = info.processedItems
      this.totalItems = info.totalItems
      this.currentFileName = info.currentFileName
      this.failedCount = info.failedCount
    }
    try {
      let result: MediaBatchResult
      if (folderDate !== undefined && operation === 'delete') {
        // 文件夹删除按完整归属递归执行，不能使用当前目录或搜索结果作为删除范围。
        result = await PrivacyBatchDeleteUtil.deleteFolder(folderDate, isCancelled, onProgress)
      } else {
        // 固定用户确认的 ID，以最新完整记录定位，不使用搜索下标或过期的导入 URI。
        const selected = new Set(dates)
        const selectedItems = Preferences.getVideoMetaDataEncryption(PathUtils.appContext!, true)
          .filter(item => selected.has(item.date))
        if (selectedItems.some(item => !item.date || item.date === '.' || item.date === '..' ||
          /[\\/\u0000]/.test(item.date))) {
          throw new Error('Invalid private media ID')
        }
        const items = selectedItems.map((item): VideoMetadata => {
          const privateItem = JSON.parse(JSON.stringify(item)) as VideoMetadata
          privateItem.uri = PathUtils.videoPath + item.date
          return privateItem
        })
        this.totalItems = items.length
        result = operation === 'delete' ?
          await PrivacyBatchDeleteUtil.deleteItems(items, isCancelled, onProgress) :
          await SelectFileUtil.exportFiles(items, PathUtils.appContext!, isCancelled, onProgress)
      }
      if (this.pageActive) {
        this.refreshLibrary()
        ToolsUtil.showToast(ToolsUtil.getStringResourceArgs2(
          (result.cancelled ? $r('app.string.privacy_batch_cancelled') : folderDate !== undefined && result.failedCount > 0 ?
            $r('app.string.privacy_folder_delete_incomplete') : operation === 'delete' ?
            $r('app.string.privacy_batch_delete_result') : $r('app.string.privacy_batch_export_result')).id,
          result.successDates.length, result.failedCount))
      }
    } catch (_) {
      salmonLogger.addLog(TAG, '隐私空间批量操作失败', true)
      if (this.pageActive) {
        this.refreshLibrary()
        ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.privacy_batch_failed').id))
      }
    } finally {
      this.batchWorking = false
      if (this.pageActive) {
        this.batchStopping = false
        if (operation === 'delete' && this.delMultipleList.length === 0) {
          this.closeMultipleChoose()
        }
      }
    }
  }

  private updateActiveAlphabet(): void {
    const list = this.videoDataSource.getAllData()
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
    const list = this.videoDataSource.getAllData()
    for (let i = 0; i < list.length; i++) {
      if (MediaSortUtil.getFirstLetter(list[i].title || '') === letter) {
        const activeScroller = Setting.listDisplayMode === ListDisplayMode.LIST_DISPLAY
          ? this.listScroller : this.waterFlowScroller
        activeScroller.scrollToIndex(i)
        return
      }
    }
  }

  private updateIndexerOnScroll(index: number): void {
    const list = this.videoDataSource.getAllData()
    if (index < 0 || index >= list.length) {
      return
    }
    const letter = MediaSortUtil.getFirstLetter(list[index].title || '')
    const targetIndex = this.activeAlphabet.indexOf(letter)
    if (targetIndex !== -1 && targetIndex !== this.indexerSelected) {
      this.indexerSelected = targetIndex
    }
  }

  private handleSort(field: SortField, defaultAsc: boolean) {
    if (this.batchWorking || this.loading) {
      return
    }
    if (this.currentSortField === field) {
      this.currentSortAsc = !this.currentSortAsc
    } else {
      this.currentSortField = field
      this.currentSortAsc = defaultAsc
    }
    Preferences.saveSortField(PathUtils.appContext!, this.currentSortField)
    Preferences.saveSortAsc(PathUtils.appContext!, this.currentSortAsc)
    this.applySearch()
  }

  private handlePinyinSortChange(value: boolean) {
    if (this.batchWorking || this.loading) {
      return
    }
    this.pinyinSort = value
    Preferences.savePinyinSort(PathUtils.appContext!, this.pinyinSort)
    if (this.currentSortField === SortField.NAME) {
      this.applySearch()
    }
  }

  private searchSortVersion: number = 0

  private async applySearch(): Promise<void> {
    const version = ++this.searchSortVersion
    this.privateFolders = PrivacyFolderUtil.project(this.folderState, this.allVideos)
    const validDates = new Set(this.privateFolders.map(folder => folder.date))
    if (this.currentFolderDate !== PrivacyFolderUtil.ALL && this.currentFolderDate !== '' &&
      !validDates.has(this.currentFolderDate)) {
      this.currentFolderDate = this.folderPath.slice().reverse().find(folder => validDates.has(folder.date))?.date ?? ''
    }
    const directory = FolderDirectory.forLibrary(this.privateFolders)
    this.folderPath = directory.path(this.currentFolderDate)
    const parent = this.currentFolderDate === PrivacyFolderUtil.ALL ? null : this.currentFolderDate || null
    const query = this.searchValue.trim().toLocaleLowerCase()
    const childFolders = await MediaSortUtil.sortFolderByNameProcess(directory.childFolders(parent)
      .filter(folder => !query || folder.name.toLocaleLowerCase().includes(query)), true, this.pinyinSort)
    if (!this.pageActive || version !== this.searchSortVersion) return
    this.childFolders = childFolders
    const scoped = PrivacyFolderUtil.videosIn(this.folderState, this.allVideos, this.currentFolderDate)
    this.currentFolderVideoCount = scoped.length
    this.video_meta_data_encryption = this.searchValue.trim()
      ? MediaLibraryService.getItemFromSearch(scoped, this.searchValue) : scoped
    if (this.currentSortField === SortField.NAME) {
      const source = this.video_meta_data_encryption
      const sorted = await MediaSortUtil.sortByNameProcess(source, this.currentSortAsc, this.pinyinSort)
      if (!this.pageActive || version !== this.searchSortVersion) return
      this.video_meta_data_encryption = sorted
    } else if (this.currentSortField === SortField.DATETIME) {
      this.video_meta_data_encryption = MediaSortUtil.sortByDatetimeProcess(this.video_meta_data_encryption, this.currentSortAsc)
    } else if (this.currentSortField === SortField.TIME) {
      this.video_meta_data_encryption = MediaSortUtil.sortByTimeProcess(this.video_meta_data_encryption, this.currentSortAsc)
    } else if (this.currentSortField === SortField.RECENT_PLAY) {
      this.video_meta_data_encryption = MediaSortUtil.sortByRecentPlayProcess(this.video_meta_data_encryption, this.currentSortAsc)
    }
    this.videoDataSource.updateData(this.video_meta_data_encryption)
    this.syncSelectedItems()
  }
}
