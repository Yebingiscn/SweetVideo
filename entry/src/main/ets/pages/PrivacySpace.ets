import { VideoMetadata } from '../interfaces/VideoMetadataInterface';
import SelectFileUtil from '../utils/SelectFileUtil';
import { common } from '@kit.AbilityKit';
import { PrivacySpaceDataSource } from '../utils/DataUtil';
import { fileUri, fileIo as fs } from '@kit.CoreFileKit';
import { media } from '@kit.MediaKit';
import VideoInfoUtil from '../utils/VideoInfoUtil';
import TimeUtil from '../utils/TimeUtil';
import ToolsUtil from '../utils/ToolsUtil';
import DataSyncUtil from '../utils/DataSyncUtil';
import { SymbolGlyphModifier } from '@kit.ArkUI';
import { VideoDetailDialog } from '../component/VideoDetailDialog';
import { DefaultDialogShadow } from '../common/DefaultDialogShadow';
import { BusinessError } from '@kit.BasicServicesKit';
import Preferences from '../database/Preferences';
import PrivacySpaceUtil from '../utils/PrivacySpaceUtil';
import { FileFolder } from '../interfaces/FileFolderInterface';
import { ButtonFancyModifier, ImageFancyModifier, SymbolGlyphFancyModifier } from '../utils/AttributeModifierUtil';

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
  @State current_iport: number = 0
  @State loading: boolean = false
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
            // await this.toMetaData(await SelectFileUtil.selectFiles());
          })
        MenuItem({
          symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.picture')),
          content: $r('app.string.import_from_album')
        })
          .onClick(async () => {
            // await this.toMetaData(await SelectFileUtil.selectVideo());
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

          })
        MenuItem({
          symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.clock')),
          content: $r('app.string.sort_by_time')
        })
          .onClick(async () => {

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
            ToolsUtil.routerWhere(this.pathStack, 'Player', item?.date!, this.video_meta_data_encryption) :
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

  async toMetaData(list: string[], file_folder: FileFolder | undefined) {
    if (list.length === 0) {
      ToolsUtil.showToast('没有任何文件被导入哦~');
      return;
    }
    this.loading = true;
    this.import_sum = list.length
    try {
      const processFile = async (uri: string, video_meta_data: VideoMetadata[]) => {
        await SelectFileUtil.addFile(context, sandbox_video, sandbox_path, uri, video_meta_data, file_folder)
      };
      const chunkSize = Math.ceil(list.length / VideoInfoUtil.MAX_CONCURRENT);
      const workers: Promise<void>[] = [];
      for (let i = 0; i < VideoInfoUtil.MAX_CONCURRENT; i++) {
        const start = i * chunkSize;
        const end = Math.min(start + chunkSize, list.length);
        const chunk = list.slice(start, end);
        workers.push((async () => {
          for (const uri of chunk) {
            await processFile(uri, this.video_meta_data_encryption);
            this.current_iport++; // 安全地更新进度
          }
        })());
      }
      await Promise.all(workers);
      this.video_meta_data_encryption = Preferences.getVideoMetaDataEncryption(context)
      this.videoDataSource = new PrivacySpaceDataSource(this.video_meta_data_encryption)
      ToolsUtil.showToast(`${getContext().resourceManager
        .getStringSync($r('app.string.add_time_info'))}${this.import_sum}`);
    } catch (error) {
      ToolsUtil.showToast('处理过程中发生意外错误:' + error);
    } finally {
      this.loading = false;
      this.current_iport = 0
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
    this.video_meta_data_encryption = this.video_meta_data_encryption.filter(i => i.date != item.date);
    fs.access(sandbox_video + item.date).then((res: boolean) => {
      if (res) {
        fs.unlink(sandbox_video + item.date, async (unlinkErr) => {
          if (unlinkErr) {
            ToolsUtil.showToast('删除视频失败：' + item.title + '原因是：' + unlinkErr.message)
          }
          Preferences.saveVideoMetaDataEncryption(context, this.video_meta_data_encryption)
          this.videoDataSource.deleteData(this.videoDataSource.getAllData().indexOf(item))
        });
      }
    }).catch((err: BusinessError) => {
      console.error("access failed with error message: " + err.message + ", error code: " + err.code);
    });
  }

  build() {
    NavDestination() {
      Column() {
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
              Column() {
                Row() {
                  Image(fileUri.getUriFromPath(sandbox_path + item.date))
                    .width(60)
                    .height(90)
                    .alt($r("app.media.sweet_video_alt"))
                    .backgroundImageSize(ImageSize.Cover)
                    .borderRadius(10)
                    .margin({ left: 5 })
                    .autoResize(true)
                    .interpolation(ImageInterpolation.Low)
                  Column() {
                    Row() {
                      Text((String(SelectFileUtil.getItem(this.video_meta_data_encryption, item?.date)?.title)).slice(0,
                        String(SelectFileUtil.getItem(this.video_meta_data_encryption, item?.date)?.title)
                          .lastIndexOf('.')))
                        .fontSize(15)
                        .fontWeight(FontWeight.Medium)
                        .maxLines(4)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .width('85%')
                        .margin({ left: 5 })
                        .wordBreak(WordBreak.BREAK_ALL)
                    }.width('100%')

                    Row() {
                      if (item.hdr_type === media.HdrType.AV_HDR_TYPE_VIVID) {
                        Image($r("app.media.hdr_vivid_icon"))
                          .attributeModifier(new ImageFancyModifier(10, 65, 25))
                      } else if (VideoInfoUtil.videoWidthAndHeightFormat(item.size.toString()).includes('HD')) {
                        Text(VideoInfoUtil.videoWidthAndHeightFormat(item.size.toString()))
                          .fontWeight(FontWeight.Bold)
                          .fontSize(10)
                          .opacity(0.8)
                          .backgroundColor('rgba(255, 189, 0, 0.4)')
                          .padding(5)
                          .borderRadius(10)
                      } else if (VideoInfoUtil.videoWidthAndHeightFormat(item.size.toString()) === '0 x 0') {
                        Text($r('app.string.unknown_resolution'))
                          .fontSize(10)
                          .opacity(0.8)
                          .backgroundColor('#808080')
                          .padding(5)
                          .borderRadius(10)
                      } else {
                        Text(VideoInfoUtil.videoWidthAndHeightFormat(item.size.toString()))
                          .fontSize(15)
                          .opacity(0.8)
                      }
                      Text("  " + TimeUtil.convertMsToMMSS(item.time))
                        .fontSize(15)
                        .fontWeight(FontWeight.Normal)
                        .opacity(0.8)
                    }.padding({ top: 10 }).width('100%')
                  }.margin({ left: 10 })
                }
                .onClick(async () => {
                  await ToolsUtil.isFileExist(item) ?
                  ToolsUtil.routerWhere(this.pathStack, 'Player', item.date, this.video_meta_data_encryption) :
                    await this.delData(context, item)
                })
                .width('100%')
                .height(100)
                .clickEffect({ level: ClickEffectLevel.HEAVY, scale: 0.9 })
              }
            }.bindContextMenu(this.MenuBuilder(item), ResponseType.LongPress)
          }, (item: VideoMetadata) => JSON.stringify(item))
        }
        .lanes(this.list_line)
        .layoutWeight(1)
        .padding({ left: 20, right: 20 })
        .width('100%')
        .height('100%')
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
            Column() {
              Progress({ value: this.current_iport, total: this.import_sum, type: ProgressType.Ring })
                .width(100)
                .height(100)
                .color($r('app.color.main_color'))
                .style({ strokeWidth: 15 })
                .margin({ bottom: 8 }) // 添加底部间距分隔文字
              Text(this.current_iport + '/' + this.import_sum)
                .fontSize(16)
                .fontColor($r('app.color.main_color'))
            }
          }.width('100%')
          .height('100%')
          .animation({ duration: 150, curve: Curve.Sharp })
        }
      }.width('100%').height('100%')
      .onAreaChange(async (_oldValue: Area, newValue: Area) => {
        this.list_line = Math.floor(new Number(newValue.width).valueOf() / 500 + 1)
      })
      .backgroundColor($r('app.color.start_window_background'))
    }.onDisAppear(() => {
      PrivacySpaceUtil.setPrivacyMode(false)
    })
    .title($r('app.string.privacy_space'))
    .padding({ top: this.topSafeHeight, bottom: this.bottomSafeHeight })
    .backgroundColor($r('app.color.start_window_background'))
  }
}