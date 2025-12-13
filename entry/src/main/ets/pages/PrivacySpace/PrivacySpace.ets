import { VideoMetadata } from '../../interfaces/VideoMetadataInterface';
import SelectFileUtil from '../../utils/SelectFileUtil';
import { VideoDataSource } from '../../utils/DataUtil';
import ToolsUtil from '../../utils/ToolsUtil';
import DataSyncUtil from '../../utils/DataSyncUtil';
import { SymbolGlyphModifier } from '@kit.ArkUI';
import { VideoDetailDialog } from '../../component/Dialog/VideoDetailDialog';
import Preferences from '../../database/Preferences';
import PrivacySpaceUtil from '../../utils/PrivacySpaceUtil';
import { FileFolder } from '../../interfaces/FileFolderInterface';
import {
  ButtonFancyModifier,
  DefaultDialogShadow,
  MenuFancyModifier,
  SymbolGlyphFancyModifier
} from '../../common/AttributeModifierConfig';
import { FileProcessorUtil } from '../../utils/FileProcessorUtil';
import { PathUtils } from '../../utils/PathUtils';
import { EditPasswordDialog } from '../../component/Dialog/EditPasswordDialog';
import { SearchComponent } from '../../component/VideoItemComponent/SearchComponent';
import NavigationAddress, { PrivacySpaceParams } from '../../common/NavigationCommon';
import { EditMetadataDialog } from '../../component/Dialog/EditMetadataDialog';
import FileFolderUtil from '../../utils/FileFolderUtil';
import { ImportProgressBuilder } from '../../component/VideoItemComponent/ImportProgressBuilder';
import VideoListItem from '../../component/VideoItemComponent/VideoListItemComponent';
import VideoCardItem from '../../component/VideoItemComponent/VideoCardItemComponent';
import VideoOperateUtil from '../../utils/VideoOperateUtil';
import { SettingsToggleItem } from '../../component/SettingComponent/SettingsToggleItem';
import { SettingsClickItem } from '../../component/SettingComponent/SettingsClickItem';
import { ListDisplayMode } from '../../common/enum/ListDisplayMode';
import SubtitleUtil from '../../utils/SubtitleUtil';
import { Privacy, SafeHeight, Setting } from '../../utils/ObservedUtil';

@Component
export struct PrivacySpace { // 隐私空间页
  @State videoDataSource: VideoDataSource = new VideoDataSource([])
  @State video_meta_data_encryption: VideoMetadata[] = []
  editMetadataDialogController: CustomDialogController = new CustomDialogController({
    builder: EditMetadataDialog({
      confirm: (title: string | undefined) => {
        if (!title?.trim()) {
          return;
        }
        const editingVideo = DataSyncUtil.editingVideo!
        const targetIndex = SelectFileUtil.getItemIndex(this.video_meta_data_encryption, editingVideo);
        if (targetIndex === -1) {
          return;
        }
        if (this.video_meta_data_encryption.some((v, index) => index !== targetIndex && v.title === title.trim())) {
          return; // 这里直接用 some 来代替，隐私空间视频不多，没必要每次都 new 一个Set
        }
        this.video_meta_data_encryption[targetIndex].title = title.trim();
        this.videoDataSource.updateData(this.video_meta_data_encryption)
        Preferences.saveVideoMetaDataEncryption(PathUtils.appContext!, this.video_meta_data_encryption)
      },
    }), cornerRadius: 20, shadow: DefaultDialogShadow
  })
  @State list_line: number = 1
  @Consume('pathStack') pathStack: NavPathStack
  @State totalItems: number = 0
  @State processedItems: number = 0
  @State loading: boolean = false
  @State searchValue: string = ''
  @State is_edit: boolean = false
  @State passwd: string = 'passwd'
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
  @State longPressPreview: boolean = false
  @State delMultipleList: VideoMetadata[] = []
  @State isPresent: boolean = false;
  searchController: SearchController = new SearchController()
  VideoDetailDialog: CustomDialogController = new CustomDialogController({
    builder: VideoDetailDialog(), cornerRadius: 20,
    shadow: DefaultDialogShadow
  })
  private listScroller: Scroller = new Scroller();

  @Builder
  PrivacySpaceSettingBuilder() {
    Column() {
      SettingsClickItem({
        symbol: $r('sys.symbol.lock'),
        message: '重设密码',
        onPress: () => {
          this.isPresent = false
          this.passwd = Preferences.getPassword(PathUtils.appContext!)
          this.editPasswdDialogController.open()
        }
      })

      SettingsToggleItem({
        symbol: $r('sys.symbol.checkmark_shield'),
        message: '设置中显示隐私空间入口',
        enable: Setting.showSettingPageEntry,
        onChange: (checked: boolean) => {
          Setting.showSettingPageEntry = checked
          Preferences.saveShowSettingPageEntry(PathUtils.appContext!, Setting.showSettingPageEntry)
        }
      })

      SettingsToggleItem({
        symbol: $r('sys.symbol.arrow_up_left_and_arrow_down_right'),
        message: '首页双指捏合往外划开进入隐私空间',
        enable: Setting.allowGestureEntry,
        onChange: (checked: boolean) => {
          Setting.allowGestureEntry = checked
          Preferences.saveAllowGestureEntry(PathUtils.appContext!, Setting.allowGestureEntry)
        }
      })

      SettingsClickItem({
        symbol: $r('sys.symbol.staroflife_rectangle'),
        message: '异常数据列表',
        onPress: () => {
          this.isPresent = false
          this.pathStack.pushPathByName(NavigationAddress.PRIVACY_ERROR_LIST, true)
        }
      })

      Column({ space: 8 }) {
        Text('清理提示')
          .fontSize(20).fontWeight(FontWeight.Medium)
        Text('删除隐私空间的视频后，系统存储的占用情况可能不会立即刷新。建议重启手机，以查看准确的空间释放情况。')
          .fontSize(15)
      }
      .padding(15)
      .alignItems(HorizontalAlign.Start)
      .borderRadius(16)
      .width('100%')
      .backgroundColor($r('app.color.start_window_background_blur'))
      .margin({ top: 10 })
    }.width('100%').height('100%').padding({ left: 16, right: 16 })
  }

  @Builder
  NavigationMenus() {
    Row() {
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.gearshape'))
          .attributeModifier(new SymbolGlyphFancyModifier(25, '', ''))
      }
      .backdropBlur(150)
      .attributeModifier(new ButtonFancyModifier(35, 35))
      .animation({ duration: 300, curve: Curve.Ease })
      .bindSheet($$this.isPresent, this.PrivacySpaceSettingBuilder, {
        detents: [SheetSize.FIT_CONTENT],
        height: SheetSize.MEDIUM,
        preferType: SheetType.CENTER,
        enableOutsideInteractive: false,
        dragBar: true,
        showClose: true,
        title: { title: '隐私空间设置' },
      })
      .onClick(() => {
        this.isPresent = !this.isPresent;
      })
      .margin({ right: 10 })

      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.plus'))
          .attributeModifier(new SymbolGlyphFancyModifier(25, '', ''))
      }
      .backdropBlur(150)
      .attributeModifier(new ButtonFancyModifier(35, 35))
      .animation({ duration: 300, curve: Curve.Ease })
      .bindMenu(this.SelectFileMenuBuilder)
      .margin({ right: 10 })

      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.text_and_arrow_down'))
          .attributeModifier(new SymbolGlyphFancyModifier(25, '', ''))
      }
      .backdropBlur(150)
      .attributeModifier(new ButtonFancyModifier(35, 35))
      .animation({ duration: 300, curve: Curve.Ease })
      .bindMenu(this.SortMenuBuilder)
    }.margin({ right: 10, top: 10 })
  }

  @Builder
  SelectFileMenuBuilder() {
    Menu() {
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.folder')),
        content: $r('app.string.import_from_files')
      })
        .onClick(async () => {
          this.isPresent = false
          await this.toMetaData(await SelectFileUtil.selectFromFileManager());
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.picture')),
        content: $r('app.string.import_from_album')
      })
        .onClick(async () => {
          this.isPresent = false
          await this.toMetaData(await SelectFileUtil.selectVideos());
        })
    }.attributeModifier(new MenuFancyModifier())
  }

  @Builder
  SortMenuBuilder() {
    Menu() {
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.textformat')),
        content: $r('app.string.sort_by_name')
      })
        .onClick(async () => {
          await ToolsUtil.sortBy(PathUtils.appContext!, this.video_meta_data_encryption, undefined, "name")
          this.video_meta_data_encryption = Preferences.getVideoMetaDataEncryption(PathUtils.appContext!)
          this.videoDataSource.updateData(this.video_meta_data_encryption)
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.clock')),
        content: $r('app.string.sort_by_time')
      })
        .onClick(async () => {
          await ToolsUtil.sortBy(PathUtils.appContext!, this.video_meta_data_encryption, undefined, "time")
          this.video_meta_data_encryption = Preferences.getVideoMetaDataEncryption(PathUtils.appContext!)
          this.videoDataSource.updateData(this.video_meta_data_encryption)
        })
    }.attributeModifier(new MenuFancyModifier())
  }

  @Builder
  MenuBuilder(item: VideoMetadata | undefined) {
    Menu() {
      MenuItem({ startIcon: $r("app.media.ffmpeg"), content: $r('app.string.FFMpeg_Player') }).onClick(async () => {
        setTimeout(async () => { //延迟跳转，确保弹窗关闭，防止系统误识别为子窗口导致播放器异常
          this.clickItem(item, NavigationAddress.FFMPEG_PLAYER)
        }, VideoOperateUtil.delayJumpToPlayer)
      })
      MenuItem({ startIcon: $r("app.media.RedPlayer"), content: '红薯播放器' }).onClick(() => {
        setTimeout(async () => { //延迟跳转，确保弹窗关闭，防止系统误识别为子窗口导致播放器异常
          this.clickItem(item, NavigationAddress.RED_PLAYER)
        }, VideoOperateUtil.delayJumpToPlayer)
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
          const targetIndex = SelectFileUtil.getItemIndex(this.video_meta_data_encryption, item!);
          if (targetIndex !== -1) {
            this.video_meta_data_encryption[targetIndex] = item!;
            this.videoDataSource.updateData(this.video_meta_data_encryption)
            Preferences.saveVideoMetaDataEncryption(PathUtils.appContext!, this.video_meta_data_encryption)
          }
        })
    }.attributeModifier(new MenuFancyModifier())
  }

  async toMetaData(fileList: string[], fileFolder?: FileFolder) {
    if (fileList.length === 0) {
      ToolsUtil.showToast('没有任何文件被导入哦~');
      return;
    }
    this.loading = true;
    this.totalItems = fileList.length;
    this.processedItems = 0;
    try {
      await FileProcessorUtil.processFilesConcurrently(
        fileList, PathUtils.appContext!, PathUtils.videoPath, PathUtils.coverPath, this.video_meta_data_encryption,
        (increment: number) => {
          this.processedItems += increment;
        },
        fileFolder
      );
      this.video_meta_data_encryption = Preferences.getVideoMetaDataEncryption(PathUtils.appContext!);
      this.videoDataSource.updateData(this.video_meta_data_encryption)
      ToolsUtil.showToast(
        `${ToolsUtil.getStringResource($r('app.string.add_time_info').id)}${this.totalItems -
        FileFolderUtil.duplicateVideo}${FileFolderUtil.duplicateVideo > 0 ?
          '重复视频已经智能跳过，跳过视频数：' + FileFolderUtil.duplicateVideo : ''}`
      );
    } catch (error) {
      ToolsUtil.showToast('处理过程中发生意外错误:' + error);
    } finally {
      this.loading = false;
    }
  }

  closePrivacyMode() {
    PrivacySpaceUtil.setPrivacyMode(false)
  }

  async aboutToAppear(): Promise<void> {
    this.video_meta_data_encryption = Preferences.getVideoMetaDataEncryption(PathUtils.appContext!)
    this.videoDataSource = new VideoDataSource(this.video_meta_data_encryption)
    PrivacySpaceUtil.setPrivacyMode(true)
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
    this.video_meta_data_encryption = Preferences.getVideoMetaDataEncryption(PathUtils.appContext!)
    this.videoDataSource.deleteData(this.video_meta_data_encryption.findIndex(i => i.date === date))
    this.video_meta_data_encryption = this.video_meta_data_encryption.filter(i => i.date !== date)
    await SelectFileUtil.deletePrivacyVideo(date, title, this.video_meta_data_encryption)
  }

  @Builder
  VideoItemBuilder(item: VideoMetadata) {
    VideoListItem({
      item: item,
      delMultipleList: this.delMultipleList
    }).backgroundColor(this.longPressPreview ? $r('app.color.start_window_background_blur') :
      $r('app.color.start_window_background')).reuseId(`VideoListItem#${item.uri}`).borderRadius(16)
  }

  build() {
    NavDestination() {
      Column() {
        if (this.video_meta_data_encryption.length == 0 && !this.loading) {
          Row() { //顶栏
            Column() {
              Text($r('app.string.nothing')).fontSize(25).fontWeight(FontWeight.Bold)
              Text($r('app.string.privacy_space_info'))
                .fontSize(15)
                .textAlign(TextAlign.Center)
                .fontWeight(FontWeight.Lighter)
                .margin({ top: 20 })
            }
          }.height('100%')
          .animation({ duration: 150, curve: Curve.Ease })
        }

        SearchComponent({
          controller: this.searchController,
          searchValue: this.searchValue,
          onChange: () => {
            const newVideoList = SelectFileUtil.getItemFromSearch(
              this.video_meta_data_encryption,
              this.searchValue,
            );
            if (this.video_meta_data_encryption) {
              this.searchValue === '' ?
                this.video_meta_data_encryption = Preferences.getVideoMetaDataEncryption(PathUtils.appContext!)
                : this.video_meta_data_encryption = newVideoList
              this.videoDataSource.updateData(this.video_meta_data_encryption)
            }
          },
          onEditChange: (isEditing: boolean) => {
            animateToImmediately({ duration: 300, curve: Curve.Ease }, () => {
              this.is_edit = isEditing
            })
          }
        }).padding({ left: 10, right: 10 })
        if (this.loading) {
          ImportProgressBuilder({ processedItems: this.processedItems, totalItems: this.totalItems })
        }
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
                  .reuseId(`VideoCardItem#${item.uri}`)
                  .backgroundColor(this.longPressPreview || Setting.backgroundImageSrc.length > 0 ?
                    $r('app.color.start_window_background_blur') :
                    $r('app.color.start_window_background'))
                  .borderRadius(16)
                  .height('auto')
              }
            }
            .width('100%')
            .height('auto')
            .onClick(async () => {
              this.clickItem(item, NavigationAddress.AV_PLAYER)
            })
            .bindContextMenu(this.MenuBuilder(item), ResponseType.LongPress,
              {
                backgroundBlurStyle: BlurStyle.COMPONENT_ULTRA_THIN,
                preview: this.VideoItemBuilder(item),
                previewAnimationOptions: { hoverScale: [1.0, 1.2] },
                onAppear: () => {
                  this.longPressPreview = true
                  ToolsUtil.startVibration()
                },
                aboutToDisappear: () => {
                  this.longPressPreview = false
                }
              })
            .bindContextMenu(this.MenuBuilder(item), ResponseType.RightClick,
              {
                backgroundBlurStyle: BlurStyle.COMPONENT_ULTRA_THIN,
                preview: this.VideoItemBuilder(item),
                previewAnimationOptions: { hoverScale: [1.0, 1.2] },
                onAppear: () => {
                  this.longPressPreview = true
                },
                aboutToDisappear: () => {
                  this.longPressPreview = false
                }
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
        .height('auto')
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true }) // 滚动边缘效果
        .chainAnimation(true)
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')
      .onAreaChange(async (_oldValue: Area, newValue: Area) => {
        const width = Number(newValue.width);
        const base = Math.floor(width / 500);
        this.list_line = Setting.listDisplayMode === ListDisplayMode.LIST_DISPLAY
          ? base + 1
          : base + 2;
      })
    }
    .onWillDisappear(() => {
      this.closePrivacyMode()
    })
    .onShown(() => {
      this.video_meta_data_encryption = Preferences.getVideoMetaDataEncryption(PathUtils.appContext!)
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
    .title($r('app.string.privacy_space'))
    .menus(this.NavigationMenus)
    .padding({ top: SafeHeight.topSafeHeight })
    .backgroundColor($r('app.color.start_window_background'))
    .backgroundImage(Setting.backgroundImageSrc, ImageRepeat.NoRepeat)
    .backgroundImageSize(ImageSize.Cover)
    .backgroundImagePosition(Alignment.Center)
    .backdropBlur(Setting.backgroundDropBlur)
    .onBackPressed(() => {
      if (this.searchValue.length > 0) {
        this.searchValue = ''
        return true
      } else {
        return false
      }
    })
    .blur(Privacy.isPrivacyBackground ? 1000 : 0)
    .onReady(() => {
      const privacySpaceParams = this.pathStack.getParamByName(NavigationAddress.PRIVACY_SPACE)[0] as PrivacySpaceParams
      if (privacySpaceParams?.needGotoSetting) {
        this.isPresent = true
      }
    })
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
}