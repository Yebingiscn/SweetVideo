import { VideoMetadata } from '../interfaces/VideoMetadataInterface';
import SelectFileUtil from '../utils/SelectFileUtil';
import { common } from '@kit.AbilityKit';
import { PrivacySpaceDataSource } from '../utils/DataUtil';
import { fileUri, fileIo as fs } from '@kit.CoreFileKit';
import ToolsUtil from '../utils/ToolsUtil';
import DataSyncUtil from '../utils/DataSyncUtil';
import { SymbolGlyphModifier } from '@kit.ArkUI';
import { VideoDetailDialog } from '../component/Dialog/VideoDetailDialog';
import { DefaultDialogShadow } from '../common/DefaultDialogShadow';
import { BusinessError } from '@kit.BasicServicesKit';
import Preferences from '../database/Preferences';
import PrivacySpaceUtil from '../utils/PrivacySpaceUtil';
import { FileFolder } from '../interfaces/FileFolderInterface';
import {
  ButtonFancyModifier,
  ImageFancyModifier,
  ShadowModifier,
  SymbolGlyphFancyModifier
} from '../utils/AttributeModifierUtil';
import { ImportProgress } from '../component/ImportProgress';
import { FileProcessorUtil } from '../utils/FileProcessorUtil';
import { VideoInfoView } from '../component/VideoInfoView';
import VideoInfoUtil from '../utils/VideoInfoUtil';

const sandbox_subtitle = getContext().filesDir + '/subtitle/'
const sandbox_path = getContext().filesDir + '/'
const sandbox_video = getContext().filesDir + '/video/'
const context = getContext() as common.UIAbilityContext;

@Component
export struct PrivacySpace { // 隐私空间页，施工未完成
  @State videoDataSource: PrivacySpaceDataSource = new PrivacySpaceDataSource([])
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
  @StorageLink('is_list_display') is_list_display: boolean = false
  searchController: SearchController = new SearchController()
  VideoDetailDialog: CustomDialogController = new CustomDialogController({
    builder: VideoDetailDialog(), cornerRadius: 20,
    shadow: DefaultDialogShadow
  })
  private listScroller: Scroller = new Scroller();

  @Builder
  NavigationMenus() {
    Row() {
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.plus'))
          .attributeModifier(new SymbolGlyphFancyModifier(25, '', ''))
      }
      .backdropBlur(150)
      .attributeModifier(new ButtonFancyModifier(40, 40))
      .animation({ duration: 300, curve: Curve.Ease })
      .bindMenu(this.SelectFileMenuBuilder)
      .backgroundColor('rgba(0, 0, 0, 0.05)')
      .margin({ right: 5 })

      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.text_and_arrow_down'))
          .attributeModifier(new SymbolGlyphFancyModifier(25, '', ''))
      }
      .backdropBlur(150)
      .attributeModifier(new ButtonFancyModifier(40, 40))
      .animation({ duration: 300, curve: Curve.Ease })
      .bindMenu(this.SortMenuBuilder)
      .backgroundColor('rgba(0, 0, 0, 0.05)')
    }.margin({ right: 24, top: 10 })
  }

  @Builder
  SelectFileMenuBuilder() {
    Flex({ direction: FlexDirection.Column, justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center }) {
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
      }.font({ size: 15, weight: FontWeight.Normal })
    }.width(150)
  }

  @Builder
  SortMenuBuilder() {
    Flex({ direction: FlexDirection.Column, justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center }) {
      Menu() {
        MenuItem({
          symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.textformat')),
          content: $r('app.string.sort_by_name')
        })
          .onClick(async () => {
            this.video_meta_data_encryption =
              await ToolsUtil.sortByName(context, this.video_meta_data_encryption, undefined) as VideoMetadata[]
            this.videoDataSource.updateData(this.video_meta_data_encryption)
          })
        MenuItem({
          symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.clock')),
          content: $r('app.string.sort_by_time')
        })
          .onClick(async () => {
            this.video_meta_data_encryption =
              await ToolsUtil.sortByTime(context, this.video_meta_data_encryption, undefined) as VideoMetadata[]
            this.videoDataSource.updateData(this.video_meta_data_encryption)
          })
      }.font({ size: 15, weight: FontWeight.Normal })
    }.width(150)
  }

  @Builder
  MenuBuilder(item: VideoMetadata | undefined) {
    Flex({ direction: FlexDirection.Column, justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center }) {
      Menu() {
        MenuItem({ startIcon: $r("app.media.ffmpeg"), content: $r('app.string.FFMpeg_Player') }).onClick(async () => {
          this.MenuBuilderState = false
          setTimeout(async () => { //延迟跳转，确保弹窗关闭，防止系统误识别为子窗口导致播放器异常
            await ToolsUtil.isFileExist(item) ?
            ToolsUtil.routerWhere(this.pathStack, 'Player', item!, this.video_meta_data_encryption) :
              await this.delData(context, item!)
          }, 200)
        })
        MenuItem({ symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.info_circle')), content: '详情' })
          .onClick(() => {
            DataSyncUtil.editing_video = JSON.stringify(item!)
            this.VideoDetailDialog.open()
          })
        MenuItem({
          symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.trash_fill')), content: $r('app.string.delete')
        })
          .onClick(async () => {
            await this.delData(context, item!)
          })
      }.font({ size: 15, weight: FontWeight.Normal })
    }.width(180).onAppear(() => {
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
        fileList, context, sandbox_video, sandbox_path, this.video_meta_data_encryption,
        (increment: number) => {
          this.current_import += increment;
        },
        fileFolder
      );
      this.video_meta_data_encryption = Preferences.getVideoMetaDataEncryption(context);
      this.videoDataSource.updateData(this.video_meta_data_encryption)
      ToolsUtil.showToast(
        `${context.resourceManager.getStringSync($r('app.string.add_time_info'))}${this.import_sum}`
      );
    } catch (error) {
      ToolsUtil.showToast('处理过程中发生意外错误:' + error);
    } finally {
      this.loading = false;
    }
  }

  async aboutToAppear(): Promise<void> {
    this.video_meta_data_encryption = Preferences.getVideoMetaDataEncryption(context)
    this.videoDataSource = new PrivacySpaceDataSource(this.video_meta_data_encryption)
    PrivacySpaceUtil.setPrivacyMode(true)
  }

  async delData(context: Context, item: VideoMetadata) {
    if (await SelectFileUtil.isSubtitleExist(sandbox_subtitle, item.date!)) {
      SelectFileUtil.deleteSubtitle(sandbox_subtitle, item.date!)
    }
    this.videoDataSource.deleteData(this.video_meta_data_encryption.findIndex(i => i.date == item.date))
    this.video_meta_data_encryption = this.video_meta_data_encryption.filter(i => i.date != item.date);
    fs.access(sandbox_video + item.date).then((res: boolean) => {
      if (res) {
        fs.unlink(sandbox_video + item.date, async (unlinkErr) => {
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
        Search({
          controller: this.searchController,
          placeholder: $r('app.string.search_placeholder'),
          value: $$this.searchValue, // $$使得 searchValue 可以动态变化，清空搜索框依赖这个
        })
          .height(40)
          .width('90%')
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
          .backgroundColor($r('app.color.start_window_background_blur'))
          .backdropBlur(150)
          .attributeModifier(new ShadowModifier())
          .animation({ duration: 300, curve: Curve.Ease })
          .onChange(() => {
            const newVideoList = SelectFileUtil.getItemFromSearch(
              this.video_meta_data_encryption,
              this.searchValue,
            );
            if (this.video_meta_data_encryption) {
              this.searchValue === '' ?
                this.video_meta_data_encryption = Preferences.getVideoMetaDataEncryption(context)
                : this.video_meta_data_encryption = newVideoList
              this.videoDataSource.updateData(this.video_meta_data_encryption)
            }
          })
          .onEditChange((isEditing: boolean) => {
            animateToImmediately({ duration: 300, curve: Curve.Ease }, () => {
              this.is_edit = isEditing
            })
          })
        if (this.video_meta_data_encryption?.length === 0) {
          Text($r('app.string.privacy_space_info'))
            .fontSize(24)
            .fontWeight(FontWeight.Medium)
            .textAlign(TextAlign.Center)
            .align(Alignment.Center)
            .height('100%')
            .width('100%')
        }
        List({ scroller: this.listScroller, space: 10 }) {
          LazyForEach(this.videoDataSource, (item: VideoMetadata) => {
            ListItem() {
              if (this.is_list_display) {
                Column() {
                  Row() {
                    Image(fileUri.getUriFromPath(sandbox_path + item.date))
                      .attributeModifier(new ImageFancyModifier(10, 60, 90))
                    Column() {
                      Row() {
                        Text(VideoInfoUtil.getVideoTitle(this.video_meta_data_encryption, item))
                          .fontSize(15)
                          .fontWeight(FontWeight.Medium)
                          .maxLines(4)
                          .textOverflow({ overflow: TextOverflow.Ellipsis })
                          .width('85%')
                          .margin({ left: 5 })
                          .wordBreak(WordBreak.BREAK_ALL)
                      }.width('100%')

                      VideoInfoView({ item })
                    }.margin({ left: 10 })
                  }
                  .onClick(async () => {
                    await ToolsUtil.isFileExist(item) ?
                    ToolsUtil.routerWhere(this.pathStack, 'Player', item, this.video_meta_data_encryption) :
                      await this.delData(context, item)
                  })
                  .width('100%')
                  .height(100)
                  .clickEffect({ level: ClickEffectLevel.HEAVY, scale: 0.9 })
                }
              } else {
                Column() {
                  Image(fileUri.getUriFromPath(sandbox_path + item.date))
                    .attributeModifier(new ImageFancyModifier({
                      topLeft: 10,
                      topRight: 10,
                      bottomLeft: 0,
                      bottomRight: 0
                    }, 60, 200))
                    .width('100%')
                    .objectFit(ImageFit.Cover)
                  Column() {
                    Row() {
                      Text((String(SelectFileUtil.getItem(this.video_meta_data_encryption, item?.date)?.title)).slice(0,
                        String(SelectFileUtil.getItem(this.video_meta_data_encryption, item?.date)?.title)
                          .lastIndexOf('.')))
                        .fontSize(15)
                        .fontWeight(FontWeight.Medium)
                        .maxLines(2)// 减少行数以适应卡片布局
                        .textAlign(TextAlign.Center)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .layoutWeight(1)// 占据剩余空间
                        .wordBreak(WordBreak.BREAK_ALL)
                    }
                    .width('100%')
                    .padding({ top: 5 })

                    VideoInfoView({ item })
                  }.padding({ left: 5, right: 5, bottom: 5 })
                  .width('100%')
                }
                .width('95%')
                .height('auto')
                .backgroundColor($r('app.color.start_window_background_blur'))
                .borderRadius(10)
              }
            }.bindContextMenu(this.MenuBuilder(item), ResponseType.LongPress)
            .swipeAction({
              end: this.itemEnd(item),
              edgeEffect: SwipeEdgeEffect.Spring
            })
          }, (item: VideoMetadata) => JSON.stringify(item))
        }
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
            ImportProgress({
              current_import: this.current_import,
              import_sum: this.import_sum
            })
          }.width('100%')
          .height('100%')
          .animation({ duration: 150, curve: Curve.Sharp })
        }
      }.width('100%').height('100%')
      .onAreaChange(async (_oldValue: Area, newValue: Area) => {
        const width = Number(newValue.width);
        const base = Math.floor(width / 500);
        this.list_line = this.is_list_display
          ? base + 1
          : base + 2;
      })
      .backgroundColor($r('app.color.start_window_background'))
    }
    .onWillDisappear(() => {
      PrivacySpaceUtil.setPrivacyMode(false)
    })
    .onShown(() => {
      this.video_meta_data_encryption = Preferences.getVideoMetaDataEncryption(context)
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
          SelectFileUtil.exportFile(item, context)
        })
    }.padding({ left: 15, right: 15 }).justifyContent(FlexAlign.SpaceEvenly)
  }
}