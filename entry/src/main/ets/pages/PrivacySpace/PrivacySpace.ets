import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import SelectFileUtil from '../../utils/SelectFileUtil'
import { VideoDataSource } from '../../utils/DataUtil'
import ToolsUtil from '../../utils/ToolsUtil'
import DataSyncUtil from '../../utils/DataSyncUtil'
import { LengthMetrics, SymbolGlyphModifier } from '@kit.ArkUI'
import { VideoDetailDialog } from '../../component/Dialog/VideoDetailDialog'
import Preferences from '../../database/Preferences'
import PrivacySpaceUtil from '../../utils/PrivacySpaceUtil'
import { FileFolder } from '../../interfaces/FileFolderInterface'
import {
  ButtonFancyModifier,
  DefaultDialogShadow,
  MenuFancyModifier,
  SymbolGlyphFancyModifier
} from '../../common/AttributeModifierConfig'
import { FileProcessorUtil, ProgressInfo } from '../../utils/FileProcessorUtil'
import { PathUtils } from '../../utils/PathUtils'
import { EditPasswordDialog } from '../../component/Dialog/EditPasswordDialog'
import { SearchComponent } from '../../component/VideoItemComponent/SearchComponent'
import NavigationAddress, { PrivacySpaceParams } from '../../common/NavigationCommon'
import { EditMetadataDialog } from '../../component/Dialog/EditMetadataDialog'
import FileFolderUtil from '../../utils/FileFolderUtil'
import { ImportProgressBuilder } from '../../component/VideoItemComponent/ImportProgressBuilder'
import VideoListItem from '../../component/VideoItemComponent/VideoListItemComponent'
import VideoCardItem from '../../component/VideoItemComponent/VideoCardItemComponent'
import { ListDisplayMode } from '../../common/enum/DisplayMode'
import SubtitleUtil from '../../utils/SubtitleUtil'
import { Privacy, SafeHeight, Setting } from '../../utils/ObservedUtil'
import { SortComponent } from '../../component/VideoItemComponent/SortComponent'
import { DELAY_JUMP_TO_PLAYER, NO_BLUR_AMOUNT, PRIVACY_BACKGROUND_BLUR_AMOUNT } from '../../common/Constants'
import VideoOperateUtil from '../../utils/VideoOperateUtil'
import { VideoItemPreviewBuilder } from '../../component/VideoItemComponent/VideoItemPreviewBuilder'
import { PrivacySpaceSettingComponent } from '../../component/PrivacySpaceComponent/PrivacySpaceSettingComponent'
import DlpAntiPeepUtil from '../../utils/DlpAntiPeepUtil'
import { HdsNavDestination, ScrollEffectType } from '@kit.UIDesignKit'

@ComponentV2
export struct PrivacySpace { // 隐私空间页
  @Local videoDataSource: VideoDataSource = new VideoDataSource([])
  @Local video_meta_data_encryption: VideoMetadata[] = []
  @Local allVideos: VideoMetadata[] = [] // 保存完整数据用于搜索
  @Local list_line: number = 1
  @Consumer('pathStack') pathStack: NavPathStack = new NavPathStack()
  @Local totalItems: number = 0
  @Local processedItems: number = 0
  @Local loading: boolean = false
  @Local currentFileName: string = '' // 当前处理的文件名
  @Local importSpeed: number = 0 // 处理速度
  @Local elapsedTime: number = 0 // 已耗时
  @Local failedCount: number = 0 // 失败文件数
  @Local currentStage: 'extracting' | 'cover' | 'saving' = 'extracting' // 当前处理阶段
  @Local searchValue: string = ''
  editMetadataDialogController: CustomDialogController = new CustomDialogController({
    builder: EditMetadataDialog({
      confirm: (title: string | undefined) => {
        if (!title?.trim()) {
          return
        }
        const editingVideo = DataSyncUtil.editingVideo!
        const targetIndex = SelectFileUtil.getItemIndex(this.video_meta_data_encryption, editingVideo)
        if (targetIndex === -1) {
          return
        }
        if (this.video_meta_data_encryption.some((v, index) => index !== targetIndex && v.title === title.trim())) {
          return // 这里直接用 some 来代替，隐私空间视频不多，没必要每次都 new 一个Set
        }
        this.video_meta_data_encryption = Preferences.getVideoMetaDataEncryption(PathUtils.appContext!)
        this.video_meta_data_encryption[targetIndex].title = title.trim()
        this.allVideos = [...this.video_meta_data_encryption]
        this.videoDataSource.updateData(this.video_meta_data_encryption)
        Preferences.saveVideoMetaDataEncryption(PathUtils.appContext!, this.video_meta_data_encryption)
        this.searchValue = ''
      },
    }), cornerRadius: 20, shadow: DefaultDialogShadow
  })
  @Local is_edit: boolean = false
  @Local currentSortField: 'name' | 'datetime' | 'time' | '' = ''
  @Local currentSortAsc: boolean = true
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
  @Local isPresent: boolean = false
  searchController: SearchController = new SearchController()
  VideoDetailDialog: CustomDialogController = new CustomDialogController({
    builder: VideoDetailDialog(), cornerRadius: 20,
    shadow: DefaultDialogShadow
  })
  private listScroller: Scroller = new Scroller()

  @Builder
  PrivacySpaceSettingBuilder() {
    PrivacySpaceSettingComponent({
      isPresent: this.isPresent,
      passwd: this.passwd,
      onEditPasswdDialogOpen: () => {
        this.editPasswdDialogController.open()
      }
    })
  }

  @Builder
  NavigationMenus() {
    Row() {
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.plus'))
          .attributeModifier(new SymbolGlyphFancyModifier(25, '', ''))
      }
      .backdropBlur(150)
      .attributeModifier(new ButtonFancyModifier(35, 35))
      .animation({ duration: 300, curve: Curve.Ease })
      .bindMenu(this.SelectFileMenuBuilder, { showInSubWindow: false })
      .margin({ right: 10 })

      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.gearshape'))
          .attributeModifier(new SymbolGlyphFancyModifier(25, '', ''))
      }
      .backdropBlur(150)
      .attributeModifier(new ButtonFancyModifier(35, 35))
      .animation({ duration: 300, curve: Curve.Ease })
      .bindSheet(this.isPresent, this.PrivacySpaceSettingBuilder, {
        detents: [SheetSize.FIT_CONTENT],
        height: SheetSize.MEDIUM,
        preferType: SheetType.CENTER,
        enableOutsideInteractive: false,
        dragBar: true,
        showClose: true,
        title: { title: '隐私空间设置' },
        onWillDismiss: () => {
          this.isPresent = false
        }
      })
      .onClick(() => {
        this.isPresent = !this.isPresent
      })
      .margin({ right: 10 })
    }.justifyContent(FlexAlign.End).width('100%')
  }

  @Builder
  SelectFileMenuBuilder() {
    Menu() {
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.resolution_video')),
        content: $r('app.string.import_from_videos')
      })
        .onClick(async () => {
          this.isPresent = false
          await this.toMetaData(await SelectFileUtil.selectFromFileManager(undefined, "video"))
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.music')),
        content: $r('app.string.import_from_music')
      })
        .onClick(async () => {
          this.isPresent = false
          await this.toMetaData(await SelectFileUtil.selectFromFileManager(undefined, "audio"))
        })
    }.attributeModifier(new MenuFancyModifier())
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
          if (this.searchValue.trim() === '') {
            this.video_meta_data_encryption = this.allVideos
          } else {
            this.video_meta_data_encryption = SelectFileUtil.getItemFromSearch(this.allVideos, this.searchValue)
          }
          this.videoDataSource.updateData(this.video_meta_data_encryption)
        },
        onEditChange: (isEditing: boolean) => {
          animateToImmediately({ duration: 300, curve: Curve.Ease }, () => {
            this.is_edit = isEditing
          })
        }
      })
      if (!this.is_edit) {
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.text_and_arrow_down'))
            .attributeModifier(new SymbolGlyphFancyModifier(25, '', ''))
        }
        .backdropBlur(150)
        .attributeModifier(new ButtonFancyModifier(35, 35))
        .animation({ duration: 300, curve: Curve.Ease })
        .bindMenu(this.SortMenuBuilder, { showInSubWindow: false })
      }
    }
    .width('95%')
    .justifyContent(FlexAlign.Start)
  }

  @Builder
  SortMenuBuilder() {
    SortComponent({
      onSortByName: () => {
        const defaultAsc = true
        if (this.currentSortField === 'name') {
          this.currentSortAsc = !this.currentSortAsc
        } else {
          this.currentSortField = 'name'
          this.currentSortAsc = defaultAsc
        }
        ToolsUtil.sortBy(PathUtils.appContext!, this.allVideos, undefined, "name", this.currentSortAsc)
        this.allVideos = Preferences.getVideoMetaDataEncryption(PathUtils.appContext!)
        this.applySearch()
      },
      onSortByTime: () => {
        const defaultAsc = false
        if (this.currentSortField === 'time') {
          this.currentSortAsc = !this.currentSortAsc
        } else {
          this.currentSortField = 'time'
          this.currentSortAsc = defaultAsc
        }
        ToolsUtil.sortBy(PathUtils.appContext!, this.allVideos, undefined, "time", this.currentSortAsc)
        this.allVideos = Preferences.getVideoMetaDataEncryption(PathUtils.appContext!)
        this.applySearch()
      },
      onSortByDatetime: () => {
        const defaultAsc = false
        if (this.currentSortField === 'datetime') {
          this.currentSortAsc = !this.currentSortAsc
        } else {
          this.currentSortField = 'datetime'
          this.currentSortAsc = defaultAsc
        }
        ToolsUtil.sortBy(PathUtils.appContext!, this.allVideos, undefined, "datetime", this.currentSortAsc)
        this.allVideos = Preferences.getVideoMetaDataEncryption(PathUtils.appContext!)
        this.applySearch()
      }
    })
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
            await this.clickItem(item, VideoOperateUtil.getPlayerNavigationAddress(Setting.defaultPlayerEngine, true))
          }, DELAY_JUMP_TO_PLAYER)
        })
      MenuItem({ symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.info_circle')), content: '详情' })
        .onClick(() => {
          DataSyncUtil.editingVideo = item
          this.VideoDetailDialog.open()
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.trash_fill')), content: $r('app.string.delete')
      })
        .onClick(async () => {
          await this.deleteItem(item!.date, item!.title)
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.rename')),
        content: $r('app.string.rename')
      })
        .onClick(() => {
          DataSyncUtil.editingVideo = item
          this.editMetadataDialogController.open()
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.arrow_right_folder_circle')),
        content: '导出'
      })
        .onClick(async () => {
          await SelectFileUtil.exportFile(item!.uri, item!.title, item!.format, PathUtils.appContext!)
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.textformat_size_square')), content: '导入或删除字幕'
      })
        .onClick(async () => {
          await SubtitleUtil.importOrDeleteSubtitleProcess(item!)
          const targetIndex = SelectFileUtil.getItemIndex(this.allVideos, item!)
          if (targetIndex !== -1) {
            this.allVideos[targetIndex] = item!
            // 使用增量更新而不是全量重载，提升性能
            const displayIndex = SelectFileUtil.getItemIndex(this.video_meta_data_encryption, item!)
            if (displayIndex !== -1) {
              this.video_meta_data_encryption[displayIndex] = item!
              this.videoDataSource.updateItem(displayIndex, item!)
            }
            Preferences.saveVideoMetaDataEncryption(PathUtils.appContext!, this.allVideos)
          }
        })
    }.attributeModifier(new MenuFancyModifier())
  }

  async toMetaData(fileList: string[], fileFolder?: FileFolder) {
    if (fileList.length === 0) {
      ToolsUtil.showToast('没有任何文件被导入哦~')
      return
    }
    this.loading = true
    this.totalItems = fileList.length
    this.processedItems = 0
    this.currentFileName = ''
    this.importSpeed = 0
    this.elapsedTime = 0
    this.failedCount = 0
    try {
      await FileProcessorUtil.processFilesConcurrently(
        fileList, PathUtils.appContext!, PathUtils.videoPath, PathUtils.coverPath, this.video_meta_data_encryption,
        (info: ProgressInfo) => {
          this.processedItems = info.current
          this.currentFileName = info.fileName
          this.currentStage = info.stage
          this.importSpeed = info.speed
          this.elapsedTime = info.elapsedTime
          this.failedCount = info.failedCount
        },
        fileFolder
      )
      this.allVideos = Preferences.getVideoMetaDataEncryption(PathUtils.appContext!)
      this.video_meta_data_encryption = this.searchValue.trim()
        ? SelectFileUtil.getItemFromSearch(this.allVideos, this.searchValue)
        : this.allVideos
      this.videoDataSource.updateData(this.video_meta_data_encryption)
      ToolsUtil.showToast(
        `${ToolsUtil.getStringResource($r('app.string.add_time_info').id)}${this.totalItems -
          FileFolderUtil.duplicateVideo - FileProcessorUtil.failedFiles.length}${
        FileFolderUtil.duplicateVideo > 0 ? '，跳过重复视频：' + FileFolderUtil.duplicateVideo : ''}${
        FileProcessorUtil.failedFiles.length > 0 ? '，失败：' + FileProcessorUtil.failedFiles.length : ''}`
      )
    } catch (error) {
      ToolsUtil.showToast('处理过程中发生意外错误:' + error)
    } finally {
      this.loading = false
    }
  }

  async aboutToAppear(): Promise<void> {
    this.allVideos = Preferences.getVideoMetaDataEncryption(PathUtils.appContext!)
    this.video_meta_data_encryption = this.allVideos
    this.videoDataSource = new VideoDataSource(this.video_meta_data_encryption)
    PrivacySpaceUtil.setPrivacyMode(true)
    DlpAntiPeepUtil.checkDlpAntiPeepStatus()
  }

  async clickItem(item: VideoMetadata | undefined, choosePlayer: string) {
    if (this.searchValue) {
      setTimeout(() => {
        AppStorage.setOrCreate('searchValue', this.searchValue)
        this.searchValue = ''
      }, 500)
    }
    await SelectFileUtil.isFileExist(item?.uri!, true) ?
      ToolsUtil.routerWhere(this.pathStack, choosePlayer, item!,
        this.video_meta_data_encryption) :
      await this.deleteItem(item!.date, item!.title)
  }

  async deleteItem(date: string, title: string) {
    this.allVideos = Preferences.getVideoMetaDataEncryption(PathUtils.appContext!)
    this.videoDataSource.deleteData(this.allVideos.findIndex(i => i.date === date))
    this.allVideos = this.allVideos.filter(i => i.date !== date)
    this.video_meta_data_encryption = this.searchValue.trim()
      ? SelectFileUtil.getItemFromSearch(this.allVideos, this.searchValue)
      : this.allVideos
    this.videoDataSource.updateData(this.video_meta_data_encryption)
    await SelectFileUtil.deletePrivacyVideo(date, title, this.allVideos)
  }

  @Builder
  VideoItemBuilder(item: VideoMetadata) {
    VideoListItem({
      item: item,
      delMultipleList: this.delMultipleList
    }).backgroundColor($r('app.color.start_window_background')).borderRadius(16)
  }

  build() {
    HdsNavDestination() {
      Column() {
        if (this.loading) {
          ImportProgressBuilder({
            processedItems: this.processedItems,
            totalItems: this.totalItems,
            currentFileName: this.currentFileName,
            currentStage: this.currentStage,
            speed: this.importSpeed,
            elapsedTime: this.elapsedTime,
            failedCount: this.failedCount
          })
        }
        if (this.video_meta_data_encryption.length == 0 && !this.loading) {
          Row() {
            Column() {
              if (this.searchValue.trim() !== '') {
                Text('未找到相关视频').fontSize(25).fontWeight(FontWeight.Bold)
              } else {
                Text($r('app.string.nothing')).fontSize(25).fontWeight(FontWeight.Bold)
                Text($r('app.string.privacy_space_info'))
                  .fontSize(15)
                  .textAlign(TextAlign.Center)
                  .fontWeight(FontWeight.Lighter)
                  .margin({ top: 20 })
              }
            }
          }.layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .animation({ duration: 150, curve: Curve.Ease })
        } else {
          Blank().height(SafeHeight.topSafeHeight + 80).width('100%')
          List({ scroller: this.listScroller, space: 10 }) {
            LazyForEach(this.videoDataSource, (item: VideoMetadata) => {
              ListItem() {
                if (Setting.listDisplayMode === ListDisplayMode.LIST_DISPLAY) {
                  this.VideoItemBuilder(item)
                } else {
                  VideoCardItem({
                    item: item,
                    delMultipleList: this.delMultipleList
                  })
                    .width('95%')
                    .backgroundColor(Setting.backgroundImageSrc.length > 0 ?
                      $r('app.color.start_window_background_blur') :
                      $r('app.color.start_window_background'))
                    .borderRadius(16)
                    .height('auto')
                }
              }
              .width('100%')
              .height('auto')
              .onClick(async () => {
                await this.clickItem(item, VideoOperateUtil.getPlayerNavigationAddress(Setting.defaultPlayerEngine))
              })
              .bindContextMenu(this.MenuBuilder(item), ResponseType.LongPress,
                {
                  backgroundBlurStyle: BlurStyle.COMPONENT_ULTRA_THIN,
                  preview: VideoItemPreviewBuilder(item),
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
              .bindContextMenu(this.MenuBuilder(item), ResponseType.RightClick,
                {
                  backgroundBlurStyle: BlurStyle.COMPONENT_ULTRA_THIN,
                  preview: VideoItemPreviewBuilder(item),
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
                end: this.itemEnd(item),
                edgeEffect: SwipeEdgeEffect.Spring
              })
            }, (item: VideoMetadata) => item.date + item.title + item.last_play + item.size.toString() + item.time)
          }
          .fadingEdge(true)
          .clip(false)
          .cachedCount(3)
          .lanes(this.list_line)
          .layoutWeight(1)
          .padding({ left: 10, right: 10 })
          .width('100%')
          .height('auto')
          .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true }) // 滚动边缘效果
          .chainAnimation(true)
          .scrollBar(BarState.Off)
        }
      }
      .width('100%')
      .height('100%')
      .onAreaChange(async (_oldValue: Area, newValue: Area) => {
        const width = Number(newValue.width)
        const base = Math.floor(width / 500)
        this.list_line = Setting.listDisplayMode === ListDisplayMode.LIST_DISPLAY
          ? base + 1
          : base + 2
      })
    }
    .onWillDisappear(() => {
      PrivacySpaceUtil.closePrivacyMode()
    })
    .onShown(() => {
      this.allVideos = Preferences.getVideoMetaDataEncryption(PathUtils.appContext!)
      this.video_meta_data_encryption = this.searchValue.trim()
        ? SelectFileUtil.getItemFromSearch(this.allVideos, this.searchValue)
        : this.allVideos
      this.videoDataSource.updateData(this.video_meta_data_encryption)
      if (DataSyncUtil.lastPlayVideoIndex >= 0) {
        this.listScroller.scrollToIndex(DataSyncUtil.lastPlayVideoIndex)
        DataSyncUtil.lastPlayVideoIndex = -1
      }
      const value: string | undefined = AppStorage.get('searchValue')
      if (value) {
        this.searchValue = value
        AppStorage.set('searchValue', '')
      }
    })
    .titleBar({
      padding: {
        start: LengthMetrics.vp(2),
        end: LengthMetrics.vp(2)
      },
      style: {
        scrollEffectOpts: {
          enableScrollEffect: true,
          scrollEffectType: ScrollEffectType.GRADUAL_BLUR,
          blurEffectiveStartOffset: LengthMetrics.vp(0),
          blurEffectiveEndOffset: LengthMetrics.vp(20)
        },
        originalStyle: {
          backgroundStyle: {
            backgroundColor: $r('app.color.start_window_background'),
          },
          contentStyle: {
            titleStyle: { mainTitleColor: $r('sys.color.font_primary') },
            menuStyle: {
              backgroundColor: $r('app.color.start_window_background'),
              iconColor: $r('sys.color.icon_primary')
            },
            backIconStyle: {
              backgroundColor: $r('app.color.start_window_background'),
              iconColor: $r('sys.color.icon_primary')
            }
          }
        },
      },
      content: {
        title: {
          mainTitle: $r('app.string.privacy_space'),
        },
        stackBuilder: (): void => this.NavigationMenus(),
        bottomBuilder: { builder: (): void => this.SearchBuilder() },
      },
    })
    .padding({ top: SafeHeight.topSafeHeight })
    .backgroundColor($r('app.color.start_window_background'))
    .backgroundImage(Setting.backgroundImageSrc, ImageRepeat.NoRepeat)
    .backgroundImageSize(ImageSize.Cover)
    .backgroundImagePosition(Alignment.Center)
    .backdropBlur(Setting.backgroundDropBlur)
    .onBackPressed(() => {
      if (this.searchValue.length > 0) {
        this.searchValue = ''
        this.video_meta_data_encryption = this.allVideos
        this.videoDataSource.updateData(this.video_meta_data_encryption)
        return true
      } else {
        return false
      }
    })
    .blur(Privacy.isPrivacyBackground ? PRIVACY_BACKGROUND_BLUR_AMOUNT : NO_BLUR_AMOUNT)
    .onReady(() => {
      const privacySpaceParams =
        this.pathStack.getParamByName(NavigationAddress.PRIVACY_SPACE)[0] as PrivacySpaceParams
      if (privacySpaceParams?.needGotoSetting) {
        this.isPresent = true
      }
    })
    .hideBackButton(false)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
  }

  @Builder
  itemEnd(item: VideoMetadata) {
    Row({ space: 10 }) {
      Stack().width(10)
      SymbolGlyph($r('sys.symbol.arrow_right_folder_circle'))
        .attributeModifier(new SymbolGlyphFancyModifier(28, 40, 40))
        .onClick(async () => {
          await SelectFileUtil.exportFile(item!.uri, item!.title, item!.format, PathUtils.appContext!)
        })
    }.padding({ left: 15, right: 15 }).justifyContent(FlexAlign.SpaceEvenly)
  }

  private applySearch() {
    this.video_meta_data_encryption = this.searchValue.trim()
      ? SelectFileUtil.getItemFromSearch(this.allVideos, this.searchValue)
      : this.allVideos
    this.videoDataSource.updateData(this.video_meta_data_encryption)
  }
}