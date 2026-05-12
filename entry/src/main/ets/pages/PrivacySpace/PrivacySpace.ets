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
import {
  DELAY_JUMP_TO_PLAYER,
  FULL_ALPHABET,
  NO_BLUR_AMOUNT,
  PRIVACY_BACKGROUND_BLUR_AMOUNT
} from '../../common/Constants'
import VideoOperateUtil from '../../utils/VideoOperateUtil'
import { VideoItemPreviewBuilder } from '../../component/VideoItemComponent/VideoItemPreviewBuilder'
import { PrivacySpaceSettingComponent } from '../../component/PrivacySpaceComponent/PrivacySpaceSettingComponent'
import DlpAntiPeepUtil from '../../utils/DlpAntiPeepUtil'
import { HdsNavDestination, HideMode, ScrollEffectType } from '@kit.UIDesignKit'
import { motion } from '@kit.MultimodalAwarenessKit'
import IntellectualGripPostureUtil from '../../utils/IntellectualGripPostureUtil'
import { pinyin4js } from '@ohos/pinyin4js'
import { ScrollBarBuilder } from '../../component/VideoItemComponent/ScrollBarBuilder'

@ComponentV2
export struct PrivacySpace { // 隐私空间页
  @Local videoDataSource: VideoDataSource = new VideoDataSource([])
  @Local video_meta_data_encryption: VideoMetadata[] = []
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
  @Local is_edit: boolean = false
  @Local currentSortField: 'name' | 'datetime' | 'time' | '' = ''
  @Local currentSortAsc: boolean = true
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
  @Local isPresent: boolean = false
  searchController: SearchController = new SearchController()
  VideoDetailDialog: CustomDialogController = new CustomDialogController({
    builder: VideoDetailDialog(), cornerRadius: 20,
    shadow: DefaultDialogShadow
  })
  @Local HoldingHand: motion.HoldingHandStatus | null = null
  private listScroller: Scroller = new Scroller()

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
    }.justifyContent(FlexAlign.End).width('100%').height('auto')
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
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.picture_2')),
        content: $r('app.string.import_from_album')
      })
        .onClick(async () => {
          this.isPresent = false
          await this.toMetaData(await SelectFileUtil.selectFromFileManager(undefined, "album"))
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
    .reverse(IntellectualGripPostureUtil.isLeftHoldHand(this.HoldingHand))
    .animation({ duration: 300, curve: Curve.Ease })
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
    const savedField = Preferences.getSortField(PathUtils.appContext!)
    if (savedField === 'name' || savedField === 'datetime' || savedField === 'time') {
      this.currentSortField = savedField
    }
    this.currentSortAsc = Preferences.getSortAsc(PathUtils.appContext!)
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
          Stack({
            alignContent: IntellectualGripPostureUtil.isLeftHoldHand(this.HoldingHand) ? Alignment.TopStart :
              Alignment.TopEnd
          }) {
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
            .clip(false)
            .cachedCount(3)
            .lanes(this.list_line)
            .layoutWeight(1)
            .padding({ left: 10, right: 10 })
            .width('100%')
            .height('100%')
            .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true }) // 滚动边缘效果
            .chainAnimation(true)
            .scrollBar(BarState.Off)
            .onScrollIndex((start: number, _end: number, _center: number) => {
              if (this.currentSortField === 'name') {
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
                .margin(IntellectualGripPostureUtil.isLeftHoldHand(this.HoldingHand) ? { left: 2 } : { right: 2 })
            }

            if (this.currentSortField !== 'name') {
              ScrollBarBuilder({
                videoListController: this.listScroller,
                fileFolderLength: 0
              })
            }
          }
          .animation({ duration: 300, curve: Curve.Ease })
          .layoutWeight(1)
          .width('100%')
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
      IntellectualGripPostureUtil.destroyHoldingHandStatus()
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
      enableComponentSafeArea: true, // 将标题栏设置为组件级安全区，内容区可避让标题栏
      padding: {
        start: LengthMetrics.vp(5),
        end: LengthMetrics.vp(5)
      },
      style: {
        // 设置导航组件标题栏样式，推荐使用默认样式
        // 标题栏动态模糊样式，包括是否使能滚动动态模糊，动态模糊类型，动态模糊生效的滚动距离等
        scrollEffectOpts: {
          enableScrollEffect: true,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
          blurEffectiveStartOffset: LengthMetrics.vp(0),
          blurEffectiveEndOffset: LengthMetrics.vp(20)
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
    .bindToScrollable([this.listScroller]) // 绑定导航组件和可滚动容器组件
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

  @Monitor('video_meta_data_encryption', 'currentSortField', 'currentSortAsc')
  onVideoListChanged() {
    if (this.currentSortField === 'name') {
      this.updateActiveAlphabet()
    } else {
      this.activeAlphabet = []
    }
  }

  private getFirstLetter(title: string): string {
    if (!title || title.length === 0) {
      return '#'
    }
    const pinyin = pinyin4js.getShortPinyin(title) as string
    if (pinyin.length === 0) {
      return '#'
    }
    const first = pinyin[0].toUpperCase()
    if (first >= 'A' && first <= 'Z') {
      return first
    }
    return '#'
  }

  private updateActiveAlphabet(): void {
    const list = this.videoDataSource.getAllData()
    const letterSet = new Set<string>()
    for (const item of list) {
      letterSet.add(this.getFirstLetter(item.title || ''))
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
      if (this.getFirstLetter(list[i].title || '') === letter) {
        this.listScroller.scrollToIndex(i)
        return
      }
    }
  }

  private updateIndexerOnScroll(index: number): void {
    const list = this.videoDataSource.getAllData()
    if (index < 0 || index >= list.length) {
      return
    }
    const letter = this.getFirstLetter(list[index].title || '')
    const targetIndex = this.activeAlphabet.indexOf(letter)
    if (targetIndex !== -1 && targetIndex !== this.indexerSelected) {
      this.indexerSelected = targetIndex
    }
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
    ToolsUtil.sortBy(PathUtils.appContext!, this.allVideos, undefined, field, this.currentSortAsc)
    this.allVideos = Preferences.getVideoMetaDataEncryption(PathUtils.appContext!)
    this.applySearch()
  }

  private applySearch() {
    this.video_meta_data_encryption = this.searchValue.trim()
      ? SelectFileUtil.getItemFromSearch(this.allVideos, this.searchValue)
      : this.allVideos
    this.videoDataSource.updateData(this.video_meta_data_encryption)
  }
}