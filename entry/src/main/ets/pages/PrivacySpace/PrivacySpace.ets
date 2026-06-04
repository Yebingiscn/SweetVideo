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
import { PathUtils } from '../../utils/PathUtils'
import { EditPasswordDialog } from '../../component/Dialog/EditPasswordDialog'
import NavigationAddress, { PrivacySpaceParams } from '../../common/NavigationCommon'
import { EditMetadataDialog } from '../../component/Dialog/EditMetadataDialog'
import { InfoConfirmDialog } from '../../component/Dialog/InfoConfirmDialog'
import { ImportProgressBuilder } from '../../component/VideoItemComponent/ImportProgressBuilder'
import VideoCardItem from '../../component/VideoItemComponent/VideoCardItemComponent'
import { ListDisplayMode } from '../../common/enum/DisplayMode'
import { DeleteType } from '../../common/enum/DeleteType'
import { SortField } from '../../common/enum/SortField'
import { Privacy, SafeHeight, Setting } from '../../utils/ObservedUtil'
import {
  DELAY_JUMP_TO_PLAYER,
  FULL_ALPHABET,
  NO_BLUR_AMOUNT,
  PRIVACY_BACKGROUND_BLUR_AMOUNT
} from '../../common/Constants'
import VideoOperateUtil from '../../utils/VideoOperateUtil'
import { VideoItemPreviewBuilder } from '../../component/VideoItemComponent/VideoItemPreviewBuilder'
import { HdsNavDestination, HideMode, ScrollEffectType } from '@kit.UIDesignKit'
import { motion } from '@kit.MultimodalAwarenessKit'
import IntellectualGripPostureUtil from '../../utils/IntellectualGripPostureUtil'
import { ScrollBarBuilder } from '../../component/VideoItemComponent/ScrollBarBuilder'
import { pinyin4js } from '@ohos/pinyin4js'
import { PrivacySpaceSettingComponent } from '../../component/PrivacySpaceComponent/PrivacySpaceSettingComponent'
import { SearchComponent } from '../../component/VideoItemComponent/SearchComponent'
import { SortComponent } from '../../component/VideoItemComponent/SortComponent'
import VideoListItem from '../../component/VideoItemComponent/VideoListItemComponent'
import { XAnimation } from '../../utils/AnimationUtil'
import { VideoListController } from '../../component/VideoItemComponent/VideoItemComponent'
import DlpAntiPeepUtil from '../../utils/DlpAntiPeepUtil'
import { importAndProcessFiles, ProgressInfo } from '../../utils/FileProcessorUtil'
import SubtitleUtil from '../../utils/SubtitleUtil'

@ComponentV2
export struct PrivacySpace { // 隐私空间页
  @Local videoDataSource: VideoDataSource = new VideoDataSource([])
  @Local video_meta_data_encryption: VideoMetadata[] = []
  @Local allVideos: VideoMetadata[] = [] // 保存完整数据用于搜索
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
          return
        }
        this.video_meta_data_encryption = Preferences.getVideoMetaDataEncryption(PathUtils.appContext!)
        const original = this.video_meta_data_encryption[targetIndex]
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
        this.video_meta_data_encryption[targetIndex] = updatedVideo
        DataSyncUtil.editingVideo = updatedVideo
        this.allVideos = [...this.video_meta_data_encryption]
        this.videoDataSource.updateData(this.video_meta_data_encryption)
        Preferences.saveVideoMetaDataEncryption(PathUtils.appContext!, this.video_meta_data_encryption)
        this.searchValue = ''
      },
    }), cornerRadius: 20, shadow: DefaultDialogShadow
  })
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
  @Local currentSortField: SortField | '' = ''
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
  @Local multipleChooseState: Visibility = Visibility.None
  @Provider('videoListController') privacyVideoListController: VideoListController =
    new VideoListController()
  @Local isPresent: boolean = false
  searchController: SearchController = new SearchController()
  VideoDetailDialog: CustomDialogController = new CustomDialogController({
    builder: VideoDetailDialog(), cornerRadius: 20,
    shadow: DefaultDialogShadow
  })
  @Local HoldingHand: motion.HoldingHandStatus | null = null
  batchDeleteConfirmDialog: CustomDialogController = new CustomDialogController({
    builder: InfoConfirmDialog({
      textInfo: '确定永久删除选中的视频吗？此操作不可恢复',
      confirm: async () => {
        await this.batchDeleteItems()
        this.closeMultipleChoose()
      }
    }), cornerRadius: 20, shadow: DefaultDialogShadow
  })
  private pendingDeleteItem: VideoMetadata | null = null
  deleteConfirmDialog: CustomDialogController = new CustomDialogController({
    builder: InfoConfirmDialog({
      textInfo: '确定删除该视频吗？',
      confirm: () => {
        if (this.pendingDeleteItem) {
          this.deleteItem(this.pendingDeleteItem.date, this.pendingDeleteItem.title)
        }
      }
    }), cornerRadius: 20, shadow: DefaultDialogShadow
  })
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
        .backdropBlur(150)
        .attributeModifier(new ButtonFancyModifier(35, 35))
        .transition(XAnimation.getAnimation('right', 0, false))
        .bindMenu(this.SortMenuBuilder, { showInSubWindow: false })

        if (this.multipleChooseState === Visibility.Visible) {
          Button({ type: ButtonType.Circle, stateEffect: true }) {
            SymbolGlyph($r('sys.symbol.checkmark_square_on_square'))
              .attributeModifier(new SymbolGlyphFancyModifier(25, '', ''))
          }
          .backdropBlur(150)
          .attributeModifier(new ButtonFancyModifier(35, 35))
          .transition(XAnimation.getAnimation('right', 0, false))
          .bindMenu(this.SelectItemMenuBuilder, { showInSubWindow: false })
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
    SortComponent({
      currentSortField: this.currentSortField,
      currentSortAsc: this.currentSortAsc,
      onSortByName: (): void => this.handleSort(SortField.NAME, true),
      onSortByTime: (): void => this.handleSort(SortField.TIME, false),
      onSortByDatetime: (): void => this.handleSort(SortField.DATETIME, false)
    })
  }

  @Builder
  SelectItemMenuBuilder() {
    Menu() {
      MenuItem({ content: $r('app.string.cancel') })
        .onClick(() => {
          this.closeMultipleChoose()
        })
      MenuItem({
        content: this.delMultipleList.length === this.video_meta_data_encryption.length &&
          this.video_meta_data_encryption.length > 0 ? '取消全选' : $r('app.string.select_all')
      })
        .onClick(() => {
          if (this.delMultipleList.length === this.video_meta_data_encryption.length &&
            this.video_meta_data_encryption.length > 0) {
            this.delMultipleList = []
          } else {
            this.delMultipleList = [...this.video_meta_data_encryption]
          }
        })
      MenuItem({ content: $r('app.string.delete_selected') })
        .onClick(() => {
          this.batchDeleteConfirmDialog.open()
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
        .onClick(() => {
          if (this.multipleChooseState === Visibility.Visible) {
            const isSelected = this.delMultipleList.some(v => v.uri === item?.uri)
            if (!isSelected) {
              this.delMultipleList = [...this.delMultipleList, item!]
            }
            this.batchDeleteConfirmDialog.open()
          } else {
            this.pendingDeleteItem = item!
            this.deleteConfirmDialog.open()
          }
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.checkmark_square_on_square')),
        content: this.multipleChooseState === Visibility.Visible ? '取消多选' :
          $r('app.string.multiple_choice')
      })
        .onClick(() => {
          XAnimation.runWithAnimation(() => {
            this.multipleChooseState =
              this.multipleChooseState === Visibility.None ? Visibility.Visible : Visibility.None
          })
          this.delMultipleList = item ? [item] : []
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
    await importAndProcessFiles(
      fileList,
      this.video_meta_data_encryption,
      (info: ProgressInfo) => {
        this.processedItems = info.current
        this.currentFileName = info.fileName
        this.currentStage = info.stage
        this.importSpeed = info.speed
        this.elapsedTime = info.elapsedTime
        this.failedCount = info.failedCount
      },
      (loading: boolean) => {
        this.loading = loading
      },
      (totalItems: number) => {
        this.totalItems = totalItems
      },
      fileFolder,
      () => {
        this.allVideos = Preferences.getVideoMetaDataEncryption(PathUtils.appContext!)
        this.video_meta_data_encryption = this.searchValue.trim()
          ? SelectFileUtil.getItemFromSearch(this.allVideos, this.searchValue)
          : this.allVideos
        const sortField = Preferences.getSortField(PathUtils.appContext!) as SortField
        if (sortField) {
          const sortAsc = Preferences.getSortAsc(PathUtils.appContext!)
          ToolsUtil.sortBy(PathUtils.appContext!, this.video_meta_data_encryption, undefined, sortField, sortAsc)
        }
        this.videoDataSource.updateData(this.video_meta_data_encryption)
      }
    )
  }

  @Monitor('multipleChooseState')
  onMultipleChooseStateChanged() {
    this.privacyVideoListController.multipleChooseState = this.multipleChooseState
  }

  async aboutToAppear(): Promise<void> {
    this.allVideos = Preferences.getVideoMetaDataEncryption(PathUtils.appContext!)
    this.video_meta_data_encryption = this.allVideos
    this.videoDataSource = new VideoDataSource(this.video_meta_data_encryption)
    PrivacySpaceUtil.setPrivacyMode(true)
    // 只有当 AI隐私防窥 开关开启时才检查并引导用户设置
    if (Setting.enableAiPrivacyAntiPeep) {
      DlpAntiPeepUtil.checkDlpAntiPeepStatus()
    }
    const savedField = Preferences.getSortField(PathUtils.appContext!)
    if (savedField === SortField.NAME || savedField === SortField.DATETIME || savedField === SortField.TIME) {
      this.currentSortField = savedField as SortField
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
              Repeat<VideoMetadata>(this.videoDataSource.data)
                .each((repeatItem: RepeatItem<VideoMetadata>) => {
                  ListItem() {
                    if (Setting.listDisplayMode === ListDisplayMode.LIST_DISPLAY) {
                      this.VideoItemBuilder(repeatItem.item)
                    } else {
                      VideoCardItem({
                        item: repeatItem.item,
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
                    if (this.multipleChooseState === Visibility.Visible) {
                      if (this.delMultipleList.some(v => v.date === repeatItem.item.date)) {
                        this.delMultipleList = this.delMultipleList.filter(v => v.date !== repeatItem.item.date)
                      } else {
                        this.delMultipleList = [...this.delMultipleList, repeatItem.item]
                      }
                    } else {
                      await this.clickItem(repeatItem.item,
                        VideoOperateUtil.getPlayerNavigationAddress(Setting.defaultPlayerEngine))
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
            .padding({ left: 10, right: 10 })
            .width('100%')
            .height('100%')
            .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true }) // 滚动边缘效果
            .chainAnimation(true)
            .scrollBar(BarState.Off)
            .onScrollIndex((start: number, _end: number, _center: number) => {
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
                .margin(IntellectualGripPostureUtil.isLeftHoldHand(this.HoldingHand) ? { left: 2 } : { right: 2 })
            }

            if (this.currentSortField !== SortField.NAME) {
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
    .backgroundImage(
      Setting.backgroundDropBlur > 0 && Setting.backgroundBlurImageSrc.length > 0 ? Setting.backgroundBlurImageSrc :
        Setting.backgroundImageSrc, ImageRepeat.NoRepeat)
    .backgroundImageSize(ImageSize.Cover)
    .backgroundImagePosition(Alignment.Center)
    .onBackPressed(() => {
      if (this.multipleChooseState === Visibility.Visible) {
        this.closeMultipleChoose()
        return true
      }
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
    if (this.currentSortField === SortField.NAME) {
      this.updateActiveAlphabet()
    } else {
      this.activeAlphabet = []
    }
  }

  private closeMultipleChoose() {
    XAnimation.runWithAnimation(() => {
      this.multipleChooseState = Visibility.None
    })
    this.delMultipleList = []
  }

  private async batchDeleteItems() {
    if (this.delMultipleList.length === 0) {
      return
    }
    await VideoOperateUtil.deleteVideoFiles(this.delMultipleList, DeleteType.HARD)
    const deleteDates = new Set(this.delMultipleList.map(v => v.date))
    this.allVideos = Preferences.getVideoMetaDataEncryption(PathUtils.appContext!)
      .filter(v => !deleteDates.has(v.date))
    Preferences.saveVideoMetaDataEncryption(PathUtils.appContext!, this.allVideos)
    this.video_meta_data_encryption = this.searchValue.trim()
      ? SelectFileUtil.getItemFromSearch(this.allVideos, this.searchValue)
      : this.allVideos
    this.videoDataSource.updateData(this.video_meta_data_encryption)
    ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.delete_success').id))
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

  private handleSort(field: SortField, defaultAsc: boolean) {
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