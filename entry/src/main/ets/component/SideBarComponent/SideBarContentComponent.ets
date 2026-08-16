import { FileFolderDataSource } from '../../utils/DataUtil'
import { AddFileFolderNameDialog } from '../Dialog/AddFileFolderNameDialog'
import { RenameDialog } from '../Dialog/RenameDialog'
import { MoveFileFolderDialog } from '../Dialog/MoveFileFolderDialog'
import { AddNetworkStreamDialog } from '../Dialog/AddNetworkStreamDialog'
import { FolderOpeningEndingDialog } from '../Dialog/FolderOpeningEndingDialog'

import { FileFolder } from '../../interfaces/FileFolderInterface'
import {
  ButtonFancyModifier,
  DefaultDialogShadow,
  ImageFancyModifier,
  SymbolGlyphFancyModifier
} from '../../common/AttributeModifierConfig'
import { PathUtils } from '../../utils/PathUtils'
import { VideoListController } from '../VideoItemComponent/VideoItemComponent'
import { SideBarController } from './SideBar'
import Preferences from '../../database/Preferences'
import { DeleteType } from '../../common/enum/DeleteType'
import { SortField } from '../../common/enum/SortField'
import NavigationAddress from '../../common/NavigationCommon'
import { userData, userLoginBuilder } from '../common/UserLoginComponent'
import { FileFolderListBuilder } from '../FileFolderComponent/FileFolderListComponent'
import { FolderSelectMenuBuilder } from '../FileFolderComponent/FileFolderSelectBuilder'
import { SortMenuComponent } from '../common/SortMenuComponent'
import { FolderOperator, VideoMetaDataOperator } from '../../database/VideoMetaData'
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import DataSyncUtil from '../../utils/DataSyncUtil'
import FileFolderUtil from '../../utils/FileFolderUtil'
import { importAndProcessFiles, ProgressInfo } from '../../utils/FileProcessorUtil'
import { XAnimation } from '../../utils/AnimationUtil'
import SelectFileUtil from '../../utils/SelectFileUtil'
import TimeUtil from '../../utils/TimeUtil'
import ToolsUtil from '../../utils/ToolsUtil'
import VideoUtils from '../../utils/VideoUtil'
import { SafeHeight, Setting } from '../../utils/ObservedUtil'
import { CapsuleSegmentButtonV2, ColorMetrics, SegmentButtonV2ItemOptions, SegmentButtonV2Items } from '@kit.ArkUI'

@ComponentV2
export struct SideBarContentComponent {
  @Param sideBarController: SideBarController = new SideBarController()
  @Param pathStack: NavPathStack = new NavPathStack()
  @Param videoListController: VideoListController = new VideoListController()
  @Param fileFolderSource: FileFolderDataSource = new FileFolderDataSource([])
  @Param file_folder_list: FileFolder[] = []
  @Param scrollToFolderDate: string = ''
  @Local isLogin: boolean = false
  @Local expandedFolderDates: Set<string> = new Set()
  @Local collapsedFolderDates: Set<string> = new Set()
  @Local folderSortField: SortField | '' = ''
  @Local folderSortAsc: boolean = true
  @Local folderPinyinSort: boolean = true
  @Param sideBarScroller: Scroller = new Scroller()
  @Local currentSourceTab: number = 0
  @Local segmentItems: SegmentButtonV2Items = new SegmentButtonV2Items([
    { text: '本地' } as SegmentButtonV2ItemOptions,
    { text: '网络' } as SegmentButtonV2ItemOptions
  ])
  @Local itemSelectedBackgroundColor: ColorMetrics | undefined = undefined
  @Local itemSelectedFontColor: ColorMetrics | undefined = undefined
  addNetworkStreamDialogController: CustomDialogController = new CustomDialogController({
    builder: AddNetworkStreamDialog({
      onStreamAdded: () => {
      }
    }), cornerRadius: 20, shadow: DefaultDialogShadow
  })
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
      title: '修改新文件夹名',
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

  @Event scrollToFolderDateChange: (date: string) => void = () => {
  }
  @Event searchValueClear: () => boolean = () => false
  @Event onImportProgress: (info: ProgressInfo) => void = () => {
  }
  @Event onImportLoading: (loading: boolean) => void = () => {
  }
  @Event onImportTotal: (total: number) => void = () => {
  }

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
    try {
      this.itemSelectedBackgroundColor = ColorMetrics.resourceColor($r('app.color.main_color'))
      this.itemSelectedFontColor = ColorMetrics.resourceColor($r('sys.color.white'))
    } catch (_error) {
    }
  }

  @Monitor('file_folder_list')
  onFileFolderListChanged() {
    this.fileFolderSource.updateData(this.file_folder_list)
    const allFolderDates = new Set(this.file_folder_list.map(f => f.date))
    this.collapsedFolderDates = new Set(Array.from(this.collapsedFolderDates).filter(d => allFolderDates.has(d)))
    this.recomputeExpandedFolderDates()
  }

  @Builder
  FileFolderSelectMenu(folder: FileFolder) {
    if (folder.name !== '首页') {
      FolderSelectMenuBuilder([
        {
          icon: $r('sys.symbol.time_lapse'),
          content: '设置片头片尾',
          onAction: () => {
            this.openFolderOpeningEndingDialog(folder)
          },
        },
        {
          icon: $r("sys.symbol.trash_fill"),
          content: $r('app.string.delete'),
          onAction: async () => {
            const allFolders = Preferences.getFileFolder(PathUtils.appContext!)
            const collectAllVideos = (rootDate: string): VideoMetadata[] => {
              const videos: VideoMetadata[] = []
              const visited = new Set<string>()
              const stack: string[] = [rootDate]
              while (stack.length > 0) {
                const current = stack.pop()!
                if (visited.has(current)) {
                  continue
                }
                visited.add(current)
                const targetFolder = allFolders.find(f => f.date === current) ?? folder
                videos.push(...(targetFolder.video_list ?? []))
                const childFolders = allFolders.filter(f => f.parent_date === current)
                for (const child of childFolders) {
                  stack.push(child.date)
                }
              }
              return videos
            }
            DataSyncUtil.delMultipleList = collectAllVideos(folder.date)
            await Promise.all(
              DataSyncUtil.delMultipleList.map(async item => {
                await VideoMetaDataOperator.deleteItem(this.videoListController, this.fileFolderSource, DeleteType.SOFT,
                  item)
              })
            )
            this.videoListController.closeMultipleChoose()
            const newFolders = FileFolderUtil.deleteFileFolderRecursive(PathUtils.appContext!, folder)
            this.fileFolderListChange(newFolders)
            let newFolder: FileFolder | undefined
            if (this.videoListController.folder?.date === folder.date) {
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
          icon: $r('sys.symbol.time_lapse'),
          content: '设置片头片尾',
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

  @Builder
  SelectFileMenuBuilder() {
    FolderSelectMenuBuilder([
      {
        icon: $r("sys.symbol.resolution_video"),
        content: $r('app.string.import_from_videos'),
        onAction: async () => {
          this.sideBarController.closeIfOverlay(false)
          await this.toMetaData(await SelectFileUtil.selectFromFileManager(undefined, "video"),
            this.videoListController.folder)
        },
      },
      {
        icon: $r('sys.symbol.folder_badge_eye'),
        content: `从下载文件夹导入（路径：Download/${ToolsUtil.getStringResource($r('app.string.EntryAbility_label')
          .id)}）`,
        onAction: async () => {
          this.sideBarController.closeIfOverlay(false)
          await this.toMetaData(await SelectFileUtil.getDownloadFilesUri(), undefined)
        },
      },
      {
        icon: $r('sys.symbol.picture_2'),
        content: $r('app.string.import_from_album'),
        onAction: async () => {
          this.sideBarController.closeIfOverlay(false)
          await this.toMetaData(await SelectFileUtil.selectFromFileManager(undefined, "album"),
            this.videoListController.folder)
        },
      },
      {
        icon: $r('sys.symbol.music'),
        content: $r('app.string.import_from_music'),
        onAction: async () => {
          this.sideBarController.closeIfOverlay(false)
          await this.toMetaData(await SelectFileUtil.selectFromFileManager(undefined, "audio"),
            this.videoListController.folder)
        },
      },
    ])
  }

  async toMetaData(fileList: string[], fileFolder?: FileFolder) {
    await importAndProcessFiles(
      fileList,
      this.videoListController.videoDataSource?.getAllData() ?? [],
      (info: ProgressInfo) => {
        this.onImportProgress(info)
      },
      (loading: boolean) => {
        this.onImportLoading(loading)
      },
      (totalItems: number) => {
        this.onImportTotal(totalItems)
      },
      fileFolder,
      () => {
        const currentFolderDate = this.videoListController.folder?.date
        const latestFolders = Preferences.getFileFolder(PathUtils.appContext!)
        const targetFolder = currentFolderDate
          ? latestFolders.find(f => f.date === currentFolderDate) ?? latestFolders[0]
          : latestFolders[0]
        const sortField = Preferences.getSortField(PathUtils.appContext!) as SortField
        if (sortField) {
          const sortAsc = Preferences.getSortAsc(PathUtils.appContext!)
          targetFolder.video_list =
            ToolsUtil.sortBy(PathUtils.appContext!, targetFolder.video_list, targetFolder, sortField, sortAsc)
        }
        const updatedFolders = VideoUtils.refresh(this.videoListController, this.fileFolderSource, targetFolder)
        this.fileFolderListChange(updatedFolders)
      }
    )
  }

  build() {
    Column() {
      // 头部固定区域：标题 + 用户卡片 + 快捷入口 + 分段按钮
      Column() {
        Row() {
          Text($r('app.string.EntryAbility_label'))
            .fontSize(20)
            .fontColor($r('app.color.text_color'))
            .fontWeight(FontWeight.Bold)
            .textOverflow({ overflow: TextOverflow.MARQUEE })
          Text(TimeUtil.getTextByTime())
            .fontSize(15)
            .fontColor($r('app.color.text_color'))
            .textOverflow({ overflow: TextOverflow.MARQUEE })
            .margin({ left: 5, right: 12 })
        }
        .alignItems(VerticalAlign.Bottom)
        .width('100%')
        .justifyContent(FlexAlign.Start)
        .margin({ top: SafeHeight.topSafeHeight })
        .clickEffect({ level: ClickEffectLevel.HEAVY, scale: 0.9 })
        .onClick(() => {
          ToolsUtil.startVibration()
          ToolsUtil.showToast('不管多么难熬，人生都要眉开眼笑 ( •̀ ω •́ )✧')
        })

        Row() {
          Image(userData?.userAvatar || $r("app.media.Foreground"))
            .attributeModifier(new ImageFancyModifier(20, 45, 45))
            .margin({ left: 10 })
          Column({ space: 2 }) {
            Text(userData.isLogin ? (userData.nickName || '已登录') : '点击登录')
              .fontColor($r('app.color.text_color'))
              .fontSize(15)
              .textOverflow({ overflow: TextOverflow.MARQUEE })
            if (userData.isLogin) {
              Text(userData.isVip ? 'VIP' : '非VIP')
                .fontSize(10)
                .fontColor(userData.isVip ? $r('sys.color.white') : $r('sys.color.black'))
                .backgroundColor(userData.isVip ? $r('app.color.main_color') : '#c1b2a3')
                .fontWeight(userData.isVip ? FontWeight.Bold : FontWeight.Normal)
                .borderRadius(6)
                .padding({
                  left: 5,
                  right: 5,
                  top: 2,
                  bottom: 2
                })
            }
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          .margin({ left: 10, right: 12 })
        }
        .height(65)
        .onClick(() => {
          this.isLogin = true
        })
        .clickEffect({ level: ClickEffectLevel.HEAVY, scale: 0.9 })
        .margin({ top: 10 })
        .justifyContent(FlexAlign.Start)
        .backgroundColor($r('app.color.list_item_background'))
        .borderRadius(16)
        .shadow({
          radius: 4,
          color: $r('app.color.shadow_color'),
          offsetX: 0,
          offsetY: 1
        })
        .bindSheet(this.isLogin, userLoginBuilder(() => {
          this.isLogin = false
          this.pathStack.pushPathByName(NavigationAddress.VIP_PAGE, true)
        }), {
          detents: [SheetSize.FIT_CONTENT],
          height: SheetSize.MEDIUM,
          preferType: SheetType.CENTER,
          enableOutsideInteractive: false,
          dragBar: true,
          showClose: true,
          title: { title: '账号信息' },
          onWillDismiss: () => {
            this.isLogin = false
          }
        })

        // 快捷入口：设置 + 最近播放（从底部移到顶部）
        Row() {
          Column() {
            SymbolGlyph($r('sys.symbol.gearshape'))
              .attributeModifier(new SymbolGlyphFancyModifier(22, '', ''))
            Text($r('app.string.setting'))
              .fontSize(11)
              .fontColor($r('app.color.text_color'))
              .margin({ top: 4 })
          }
          .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
          .layoutWeight(1)
          .padding({ top: 12, bottom: 12 })
          .alignItems(HorizontalAlign.Center)
          .onClick(() => {
            this.sideBarController.closeIfOverlay(false)
            this.pathStack.pushPathByName(NavigationAddress.SETTING_PAGE, null)
          })

          Column() {
            SymbolGlyph($r('sys.symbol.clock'))
              .attributeModifier(new SymbolGlyphFancyModifier(22, '', ''))
            Text($r('app.string.recent_play'))
              .fontSize(11)
              .fontColor($r('app.color.text_color'))
              .margin({ top: 4 })
          }
          .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
          .layoutWeight(1)
          .padding({ top: 12, bottom: 12 })
          .alignItems(HorizontalAlign.Center)
          .onClick(() => {
            this.sideBarController.closeIfOverlay(false)
            this.pathStack.pushPathByName(NavigationAddress.RECENT_PLAY, true)
          })
        }
        .width('100%')
        .margin({ top: 10 })
        .backgroundColor($r('app.color.list_item_background'))
        .borderRadius(16)
        .shadow({
          radius: 4,
          color: $r('app.color.shadow_color'),
          offsetX: 0,
          offsetY: 1
        })

        // 本地/网络切换 - CapsuleSegmentButtonV2
        CapsuleSegmentButtonV2({
          items: this.segmentItems,
          selectedIndex: this.currentSourceTab,
          buttonBackgroundBlurStyle: BlurStyle.BACKGROUND_THICK,
          itemSelectedFontColor: this.itemSelectedFontColor,
          itemSelectedBackgroundColor: this.itemSelectedBackgroundColor,
          onItemClicked: (index: number) => {
            this.currentSourceTab = index
          }
        })
          .margin({ top: 10, bottom: 6 })
      }
      .width('100%')
      .padding({ left: 16, right: 16 })

      // 内容区域：Swiper 切换本地/网络
      Swiper() {
        // Tab 0: 本地
        Scroll(this.sideBarScroller) {
          Column() {
            // 导入操作区
            Column() {
              Button({ type: ButtonType.Normal, stateEffect: true }) {
                Row() {
                  SymbolGlyph($r('sys.symbol.plus_square'))
                    .attributeModifier(new SymbolGlyphFancyModifier(25, '', ''))
                  Text($r('app.string.import_from_videos'))
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
              .bindMenu(this.SelectFileMenuBuilder)
              .width('100%')

              Button({ type: ButtonType.Normal, stateEffect: true }) {
                Row() {
                  SymbolGlyph($r('sys.symbol.folder_badge_plus'))
                    .attributeModifier(new SymbolGlyphFancyModifier(25, '', ''))
                  Text('添加文件夹')
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
              Text('文件夹')
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
                      depth: FileFolderUtil.getFolderDepth(PathUtils.appContext!, repeatItem.item.date),
                      hasChildren: FileFolderUtil.getChildFolders(PathUtils.appContext!, repeatItem.item.date)
                        .length > 0,
                      isExpanded: this.expandedFolderDates.has(repeatItem.item.date),
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
                    this.searchValueClear()
                    if (this.videoListController.folder?.date === repeatItem.item.date) {
                      return
                    }
                    const currentFolders = Preferences.getFileFolder(PathUtils.appContext!)
                    this.fileFolderListChange(currentFolders)
                    const currentFolder = currentFolders.find(f => f.date === repeatItem.item.date)
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
                    this.videoListController.updateData(this.videoListController.videoDataSource, currentFolder!)
                    this.scrollToFolderDateChange(repeatItem.item.date)
                    this.sideBarController.closeIfOverlay(true)
                  })
                  .bindContextMenu(this.FileFolderSelectMenu(repeatItem.item), ResponseType.LongPress)
                  .bindContextMenu(this.FileFolderSelectMenu(repeatItem.item), ResponseType.RightClick)
                })
                .key((item: FileFolder, _index: number) => item.name + item.date + item.video_list.length)
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
        .padding({ left: 16, right: 16 })
        .align(Alignment.Top)
        .edgeEffect(EdgeEffect.Spring)
        .scrollBar(BarState.Off)
        .width('100%')
        .height('100%')

        // Tab 1: 网络
        Scroll() {
          Column({ space: 8 }) {
            Button({ type: ButtonType.Normal, stateEffect: true }) {
              Row() {
                SymbolGlyph($r('sys.symbol.wifi'))
                  .attributeModifier(new SymbolGlyphFancyModifier(25, '', ''))
                Text('串流')
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
              this.sideBarController.closeIfOverlay(false)
              this.pathStack.pushPathByName(NavigationAddress.STREAM_PAGE, null)
            })

            Button({ type: ButtonType.Normal, stateEffect: true }) {
              Row() {
                SymbolGlyph($r('sys.symbol.dot_radiowaves_left_and_right'))
                  .attributeModifier(new SymbolGlyphFancyModifier(25, '', ''))
                Text('IPTV')
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
              this.sideBarController.closeIfOverlay(false)
              this.pathStack.pushPathByName(NavigationAddress.IPTV_SOURCE_PAGE, null)
            })

          }
          .backgroundColor($r('app.color.list_item_background'))
          .width('100%')
          .borderRadius(16)
          .padding({ top: 4, bottom: 4 })
          .shadow({
            radius: 4,
            color: $r('app.color.shadow_color'),
            offsetX: 0,
            offsetY: 1
          })
        }
        .padding({ left: 16, right: 16 })
        .align(Alignment.Top)
        .edgeEffect(EdgeEffect.Spring)
        .scrollBar(BarState.Off)
        .width('100%')
        .height('100%')
      }
      .index(this.currentSourceTab)
      .indicator(false)
      .layoutWeight(1)
      .width('100%')
      .onChange((index: number) => {
        this.currentSourceTab = index
      })
    }
    .width('100%')
    .justifyContent(FlexAlign.Start)
    .backgroundColor(Setting.backgroundImageSrc.length > 0 ? '' : $r('app.color.sidebar_background_color'))
    .transition(TransitionEffect.translate({ x: -300 })
      .combine(TransitionEffect.OPACITY)
      .animation(XAnimation.getAnimationCurve()))
    .visibility(this.sideBarController.visibility)
    .borderRadius(this.sideBarController.mode === SideBarContainerType.Overlay ? 16 : 0)
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
    const folders = this.fileFolderSource.data
    const result: FileFolder[] = []
    const visited = new Set<string>()

    const dfs = (parentDate: string | null) => {
      const children = folders.filter(f => f.parent_date === parentDate)
      for (const child of children) {
        if (visited.has(child.date)) {
          continue
        }
        visited.add(child.date)
        result.push(child)
        if (this.expandedFolderDates.has(child.date)) {
          dfs(child.date)
        }
      }
    }

    dfs(null)
    return result
  }

  private openFolderOpeningEndingDialog(folder: FileFolder): void {
    if (folder.video_list.length === 0) {
      ToolsUtil.showToast('该文件夹内没有视频')
      return
    }
    DataSyncUtil.editingFolder = folder
    this.folderOpeningEndingDialogController.open()
  }

  private updateFolderOpeningEndingTimes(folderDate: string, startTime: number, endTime: number): void {
    const updatedFolders = FolderOperator.updateFolderOpeningEndingTimes(folderDate, startTime, endTime)
    const updatedFolder = updatedFolders.find(folder => folder.date === folderDate)
    if (!updatedFolder) {
      ToolsUtil.showToast('文件夹不存在，设置失败')
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
