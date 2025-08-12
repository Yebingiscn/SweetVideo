import { VideoMetadata } from '../interfaces/VideoMetadataInterface';
import SelectFileUtil from '../utils/SelectFileUtil';
import { VideoDataSource } from '../utils/DataUtil';
import { fileUri, fileIo as fs } from '@kit.CoreFileKit';
import ToolsUtil from '../utils/ToolsUtil';
import DataSyncUtil from '../utils/DataSyncUtil';
import { MenuModifier, SymbolGlyphModifier } from '@kit.ArkUI';
import { VideoDetailDialog } from '../component/Dialog/VideoDetailDialog';
import { DefaultDialogShadow } from '../common/DefaultDialogShadow';
import { BusinessError } from '@kit.BasicServicesKit';
import Preferences from '../database/Preferences';
import PrivacySpaceUtil from '../utils/PrivacySpaceUtil';
import { FileFolder } from '../interfaces/FileFolderInterface';
import {
  ButtonFancyModifier,
  ImageFancyModifier,
  SymbolGlyphFancyModifier
} from '../utils/AttributeModifierUtil';
import { FileProcessorUtil } from '../utils/FileProcessorUtil';
import VideoInfoUtil from '../utils/VideoInfoUtil';
import SubtitleUtil from '../utils/SubtitleUtil';
import { PathUtils } from '../utils/PathUtils';
import { editPasswordDialog } from '../component/Dialog/EditPasswordDialog';
import { SearchComponent } from '../component/VideoItemComponent/SearchComponent';
import { VideoInfoComponent } from '../component/VideoItemComponent/VideoInfoComponent';
import { ImportProgressComponent } from '../component/VideoItemComponent/ImportProgressComponent';

@Component
export struct PrivacySpace { // 隐私空间页
  @State videoDataSource: VideoDataSource = new VideoDataSource([])
  @State video_meta_data_encryption: VideoMetadata[] = []
  @State list_line: number = 1
  @Consume('pathStack') pathStack: NavPathStack
  @StorageProp('topSafeHeight') topSafeHeight: number = 0;
  @StorageProp('bottomSafeHeight') bottomSafeHeight: number = 0;
  @State MenuBuilderState: boolean = false
  @State import_sum: number = 0
  @State current_import: number = 0
  @State loading: boolean = false
  @State searchValue: string = ''
  @State is_edit: boolean = false
  @State passwd: string = 'passwd'
  @State longPressPreview: boolean = false
  @StorageLink('isListDisplay') isListDisplay: boolean = false
  searchController: SearchController = new SearchController()
  VideoDetailDialog: CustomDialogController = new CustomDialogController({
    builder: VideoDetailDialog(), cornerRadius: 20,
    shadow: DefaultDialogShadow
  })
  editPasswdDialogController: CustomDialogController = new CustomDialogController({
    builder: editPasswordDialog({
      confirm: (passwd: string | undefined) => {
        if (!passwd || passwd.trim() == '') {
          return
        }
        this.passwd = passwd
        ToolsUtil.savePwd(PathUtils.appContext!, passwd)
        ToolsUtil.showToast(PathUtils.appContext!.resourceManager.getStringSync($r('app.string.set_passwd_tip')))
      },
    }), cornerRadius: 20, shadow: DefaultDialogShadow
  })
  private listScroller: Scroller = new Scroller();

  @Builder
  NavigationMenus() {
    Row() {
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.lock'))
          .attributeModifier(new SymbolGlyphFancyModifier(25, '', ''))
      }
      .backdropBlur(150)
      .attributeModifier(new ButtonFancyModifier(40, 40))
      .animation({ duration: 300, curve: Curve.Ease })
      .onClick(() => {
        this.passwd = Preferences.getPassword(PathUtils.appContext!)
        this.editPasswdDialogController.open()
      })
      .margin({ right: 5 })

      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.plus'))
          .attributeModifier(new SymbolGlyphFancyModifier(25, '', ''))
      }
      .backdropBlur(150)
      .attributeModifier(new ButtonFancyModifier(40, 40))
      .animation({ duration: 300, curve: Curve.Ease })
      .bindMenu(this.SelectFileMenuBuilder)
      .margin({ right: 5 })

      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.text_and_arrow_down'))
          .attributeModifier(new SymbolGlyphFancyModifier(25, '', ''))
      }
      .backdropBlur(150)
      .attributeModifier(new ButtonFancyModifier(40, 40))
      .animation({ duration: 300, curve: Curve.Ease })
      .bindMenu(this.SortMenuBuilder)
    }.margin({ right: 24, top: 10 })
  }

  @Builder
  SelectFileMenuBuilder() {
    Menu() {
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.folder')),
        content: $r('app.string.import_from_files')
      })
        .onClick(async () => {
          await this.toMetaData(await SelectFileUtil.selectFiles());
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.picture')),
        content: $r('app.string.import_from_album')
      })
        .onClick(async () => {
          await this.toMetaData(await SelectFileUtil.selectVideo());
        })
    }.attributeModifier(new MenuModifier())
  }

  @Builder
  SortMenuBuilder() {
    Menu() {
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.textformat')),
        content: $r('app.string.sort_by_name')
      })
        .onClick(async () => {
          await ToolsUtil.sortByName(PathUtils.appContext!, this.video_meta_data_encryption,
            undefined)
          this.video_meta_data_encryption = Preferences.getVideoMetaDataEncryption(PathUtils.appContext!)
          this.videoDataSource.updateData(this.video_meta_data_encryption)
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.clock')),
        content: $r('app.string.sort_by_time')
      })
        .onClick(async () => {
          await ToolsUtil.sortByTime(PathUtils.appContext!, this.video_meta_data_encryption, undefined)
          this.video_meta_data_encryption = Preferences.getVideoMetaDataEncryption(PathUtils.appContext!)
          this.videoDataSource.updateData(this.video_meta_data_encryption)
        })
    }.attributeModifier(new MenuModifier())
  }

  @Builder
  MenuBuilder(item: VideoMetadata | undefined) {
    Menu() {
      MenuItem({ startIcon: $r("app.media.ffmpeg"), content: $r('app.string.FFMpeg_Player') }).onClick(async () => {
        this.MenuBuilderState = false
        setTimeout(async () => { //延迟跳转，确保弹窗关闭，防止系统误识别为子窗口导致播放器异常
          await ToolsUtil.isFileExist(item) ?
          ToolsUtil.routerWhere(this.pathStack, 'Player', item!, this.video_meta_data_encryption) :
            await this.delItem(PathUtils.appContext!, item!)
        }, 200)
      })
      MenuItem({ symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.info_circle')), content: '详情' })
        .onClick(() => {
          DataSyncUtil.editingVideo = JSON.stringify(item!)
          this.VideoDetailDialog.open()
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.trash_fill')), content: $r('app.string.delete')
      })
        .onClick(async () => {
          await this.delItem(PathUtils.appContext!, item!)
        })
    }.attributeModifier(new MenuModifier()).onAppear(() => {
      ToolsUtil.startVibration()
      this.MenuBuilderState = true
    })
  }

  async toMetaData(fileList: string[], fileFolder?: FileFolder) {
    if (fileList.length === 0) {
      ToolsUtil.showToast('没有任何文件被导入哦~');
      return;
    }
    this.loading = true;
    this.import_sum = fileList.length;
    this.current_import = 0;
    try {
      await FileProcessorUtil.processFilesConcurrently(
        fileList, PathUtils.appContext!, PathUtils.videoPath, PathUtils.coverPath, this.video_meta_data_encryption,
        (increment: number) => {
          this.current_import += increment;
        },
        fileFolder
      );
      this.video_meta_data_encryption = Preferences.getVideoMetaDataEncryption(PathUtils.appContext!);
      this.videoDataSource.updateData(this.video_meta_data_encryption)
      ToolsUtil.showToast(
        `${PathUtils.appContext!.resourceManager.getStringSync($r('app.string.add_time_info'))}${this.import_sum}`
      );
    } catch (error) {
      ToolsUtil.showToast('处理过程中发生意外错误:' + error);
    } finally {
      this.loading = false;
    }
  }

  async aboutToAppear(): Promise<void> {
    this.video_meta_data_encryption = Preferences.getVideoMetaDataEncryption(PathUtils.appContext!)
    this.videoDataSource = new VideoDataSource(this.video_meta_data_encryption)
    PrivacySpaceUtil.setPrivacyMode(true)
  }

  async delItem(context: Context, item: VideoMetadata) {
    await SubtitleUtil.deleteSubtitle(PathUtils.subtitlePath, item.date!)
    this.videoDataSource.deleteData(this.video_meta_data_encryption.findIndex(i => i.date == item.date))
    this.video_meta_data_encryption = this.video_meta_data_encryption.filter(i => i.date != item.date);
    fs.access(PathUtils.videoPath + item.date).then((res: boolean) => {
      if (res) {
        fs.unlink(PathUtils.videoPath + item.date, async (unlinkErr) => {
          if (unlinkErr) {
            ToolsUtil.showToast('删除视频失败：' + item.title + '原因是：' + unlinkErr.message)
          }
          Preferences.saveVideoMetaDataEncryption(context, this.video_meta_data_encryption)
        });
      }
    }).catch((err: BusinessError) => {
      console.error("access failed with error message: " + err.message + ", error code: " + err.code);
    });
  }

  build() {
    NavDestination() {
      Column() {
        SearchComponent({
          controller: this.searchController,
          placeholder: $r('app.string.search_placeholder'),
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
        }).width('90%')
        List({ scroller: this.listScroller, space: 10 }) {
          LazyForEach(this.videoDataSource, (item: VideoMetadata) => {
            ListItem() {
              if (this.isListDisplay) {
                Column() {
                  Row() {
                    Image(fileUri.getUriFromPath(PathUtils.coverPath + item.date))
                      .attributeModifier(new ImageFancyModifier(10, 60, 90))
                    Column() {
                      Row() {
                        Text(VideoInfoUtil.getVideoTitle(this.video_meta_data_encryption, item))
                          .fontSize(15)
                          .fontWeight(FontWeight.Medium)
                          .maxLines(4)
                          .textOverflow({ overflow: TextOverflow.Ellipsis })
                          .width('80%')
                          .margin({ left: 5 })
                          .wordBreak(WordBreak.BREAK_ALL)
                      }.width('100%')

                      VideoInfoComponent({ item })
                    }.margin({ left: 10 }).alignItems(HorizontalAlign.Start)
                  }
                  .width('100%')
                  .height(100)
                }
                .justifyContent(FlexAlign.SpaceEvenly)
                .backgroundColor(this.longPressPreview ? $r('app.color.start_window_background_blur') :
                $r('app.color.start_window_background'))
                .borderRadius(8)
              } else {
                Column() {
                  Image(fileUri.getUriFromPath(PathUtils.coverPath + item.date))
                    .attributeModifier(new ImageFancyModifier({
                      topLeft: 10,
                      topRight: 10,
                      bottomLeft: 0,
                      bottomRight: 0
                    }, 60, 200))
                    .draggable(false)
                    .width('100%')
                    .objectFit(ImageFit.Cover)
                  Column() {
                    Row() {
                      Text(VideoInfoUtil.getVideoTitle(this.video_meta_data_encryption, item))
                        .fontSize(15)
                        .fontWeight(FontWeight.Medium)
                        .maxLines(2)// 减少行数以适应卡片布局
                        .textAlign(TextAlign.Start)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .layoutWeight(1)// 占据剩余空间
                        .wordBreak(WordBreak.BREAK_ALL)
                    }
                    .width('100%')
                    .padding({ top: 5 })

                    VideoInfoComponent({ item })
                  }.padding({ left: 5, right: 5, bottom: 5 })
                  .width('100%')
                }
                .backgroundColor(this.longPressPreview ? $r('app.color.start_window_background_blur') :
                $r('app.color.start_window_background'))
                .borderRadius(8)
                .width('95%')
                .height('auto')
                .backgroundColor($r('app.color.start_window_background_blur'))
                .borderRadius(10)
              }
            }
            .onClick(async () => {
              await ToolsUtil.isFileExist(item) ?
              ToolsUtil.routerWhere(this.pathStack, 'Player', item, this.video_meta_data_encryption) :
                await this.delItem(PathUtils.appContext!, item)
            })
            .bindContextMenu(this.MenuBuilder(item), ResponseType.LongPress,
              {
                preview: MenuPreviewMode.IMAGE,
                previewAnimationOptions: { scale: [0.8, 1.0] },
                onAppear: () => {
                  this.longPressPreview = true
                },
                aboutToDisappear: () => {
                  this.longPressPreview = false
                }
              })
            .bindContextMenu(this.MenuBuilder(item), ResponseType.RightClick,
              {
                preview: MenuPreviewMode.IMAGE,
                previewAnimationOptions: { scale: [0.8, 1.0] },
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
          }, (item: VideoMetadata) => item.date + item.title + item.last_play + item.size.toString())
        }
        .cachedCount(3)
        .lanes(this.list_line)
        .layoutWeight(1)
        .padding({ left: 20, right: 20 })
        .width('100%')
        .height('auto')
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true }) // 滚动边缘效果
        .chainAnimation(true)
        .scrollBar(BarState.Off)

        if (this.video_meta_data_encryption.length == 0) {
          Row() { //顶栏
            if (!this.loading) {
              Column() {
                Text($r('app.string.nothing')).fontSize(25).fontWeight(FontWeight.Bold)
                Text($r('app.string.privacy_space_info'))
                  .fontSize(15)
                  .textAlign(TextAlign.Center)
                  .fontWeight(FontWeight.Lighter)
                  .margin({ top: 20 })
              }
            }
          }.height('100%')
          .animation({ duration: 150, curve: Curve.Ease })
        }
        if (this.loading) {
          Stack() {
            ImportProgressComponent({
              processedItems: this.current_import,
              totalItems: this.import_sum
            })
          }.width('100%')
          .height('100%')
        }
      }.width('100%').height('100%')
      .onAreaChange(async (_oldValue: Area, newValue: Area) => {
        const width = Number(newValue.width);
        const base = Math.floor(width / 500);
        this.list_line = this.isListDisplay
          ? base + 1
          : base + 2;
      })
      .backgroundColor($r('app.color.start_window_background'))
    }
    .onWillDisappear(() => {
      PrivacySpaceUtil.setPrivacyMode(false)
    })
    .onShown(() => {
      this.video_meta_data_encryption = Preferences.getVideoMetaDataEncryption(PathUtils.appContext!)
      this.videoDataSource.updateData(this.video_meta_data_encryption)
    })
    .title($r('app.string.privacy_space'))
    .menus(this.NavigationMenus)
    .padding({ top: this.topSafeHeight })
    .backgroundColor($r('app.color.start_window_background'))
    .onBackPressed(() => {
      if (this.searchValue.length > 0) {
        this.searchValue = ''
        return true
      } else {
        return false
      }
    })
  }

  @Builder
  itemEnd(item: VideoMetadata) {
    Row({ space: 10 }) {
      Stack().width(10)
      SymbolGlyph($r('sys.symbol.arrow_right_folder_circle'))
        .attributeModifier(new SymbolGlyphFancyModifier(28, 40, 40))
        .onClick(() => {
          SelectFileUtil.exportFile(item, PathUtils.appContext!)
        })
    }.padding({ left: 15, right: 15 }).justifyContent(FlexAlign.SpaceEvenly)
  }
}