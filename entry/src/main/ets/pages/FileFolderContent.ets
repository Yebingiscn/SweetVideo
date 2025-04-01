import { common } from '@kit.AbilityKit';
import ToolsUtil from '../utils/ToolsUtil';
import VideoInfoUtil, { DEFAULT_DIALOG_SHADOW, VideoMetadata } from '../utils/VideoInfoUtil';
import { router, SymbolGlyphModifier } from '@kit.ArkUI';
import DataSyncUtil from '../utils/DataSyncUtil';
import SelectFileUtil from '../utils/SelectFileUtil';
import { JSON } from '@kit.ArkTS';
import { fileUri, fileIo as fs } from '@kit.CoreFileKit';
import { FileFolderContentDataSource } from '../utils/DataUtil';
import { media } from '@kit.MediaKit';
import TimeUtil from '../utils/TimeUtil';
import { VideoDetailDialog } from '../component/VideoDetailDialog';
import { FileFolder } from '../utils/FileFolderUtil';

const sandbox_subtitle = getContext().filesDir + '/subtitle/'
const sandbox_path = getContext().filesDir + '/'
const context = getContext() as common.UIAbilityContext;

@Extend(SymbolGlyph)
function symbolGlyphFancy(fontSize: number, width: number | string, height: number | string) {
  .fontSize(fontSize)
  .fontColor([$r('app.color.text_color')])
  .width(width)
  .height(height)
}

@Extend(Image)
function imageFancy(borderRadius: number, width: number | string, height: number | string) {
  .alt($r("app.media.sweet_video_alt"))
  .backgroundImageSize(ImageSize.Cover)
  .borderRadius(borderRadius)
  .width(width)
  .height(height)
  .autoResize(true)
  .interpolation(ImageInterpolation.Low)
}

@Entry
@Component
struct FileFolderContent {
  @State videoDataSource: FileFolderContentDataSource = new FileFolderContentDataSource([])
  @State MenuBuilderState: boolean = false
  @State file_folder: FileFolder | undefined = undefined
  VideoDetailDialog: CustomDialogController = new CustomDialogController({
    builder: VideoDetailDialog(), cornerRadius: 20,
    shadow: DEFAULT_DIALOG_SHADOW
  })
  private listScroller: Scroller = new Scroller();

  async aboutToAppear(): Promise<void> {
    let record = router.getParams() as Record<string, string>
    if (record) {
      this.file_folder = JSON.parse(record['file_folder']) as FileFolder
    }
    this.videoDataSource = new FileFolderContentDataSource(this.file_folder?.video_list!);
  }

  @Builder
  MenuBuilder(item: VideoMetadata | undefined) {
    Flex({ direction: FlexDirection.Column, justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center }) {
      Menu() {
        MenuItem({ startIcon: $r("app.media.ffmpeg"), content: $r('app.string.FFMpeg_Player') }).onClick(() => {
          this.MenuBuilderState = false
          ToolsUtil.isFileExist(item) ?
          ToolsUtil.routerToVideoFromFileFolder(context, 'pages/FFMpegPlayer', item!, this.file_folder?.video_list!) :
          this.delData(context, item!)
        })
        MenuItem({ symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.info_circle')), content: '详情' })
          .onClick(() => {
            DataSyncUtil.editing_video = JSON.stringify(item)
            this.VideoDetailDialog.open()
          })
        MenuItem({
          symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.trash_fill')), content: $r('app.string.delete')
        })
          .onClick(() => {
            this.delData(context, item!)
          })
      }.font({ size: 15, weight: FontWeight.Normal })
    }.width(180).onAppear(() => {
      ToolsUtil.startVibration()
      this.MenuBuilderState = true
    })
  }

  async delData(context: Context, item: VideoMetadata) {
    this.file_folder!.video_list = this.file_folder!.video_list.filter(i => i.date !== item.date);
    let file_folder_list = await SelectFileUtil.getFileFolder(context)
    file_folder_list = file_folder_list.filter(i => i.date !== this.file_folder?.date)
    file_folder_list.push(this.file_folder!)
    await SelectFileUtil.saveFileFolder(context, file_folder_list)
    this.videoDataSource.deleteData(this.videoDataSource.getAllData().indexOf(item))
    if (await SelectFileUtil.isSubtitleExist(sandbox_subtitle, item.date!)) {
      SelectFileUtil.deleteSubtitle(sandbox_subtitle, item.date!)
    }
    fs.access(sandbox_path + item.date, (err) => {
      if (!err) { // 文件存在
        fs.unlink(sandbox_path + item.date, (unlinkErr) => {
          if (unlinkErr) {
            return;
          }
        });
      }
    })
  }

  build() {
    Column() {
      Row({ space: 12 }) {
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.arrow_left'))
            .fontSize(20)
            .fontColor([$r('app.color.text_color')])
        }
        .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
        .height(40)
        .width(80)
        .backgroundColor($r('app.color.start_window_background_blur'))
        .onClick(() => {
          router.back()
        })

        Text(this.file_folder?.name)
          .fontSize(24)
          .fontWeight(FontWeight.Medium)
      }.margin({ top: DataSyncUtil.getActuallyTopSafeHeight() })
      .width('100%')
      .padding({
        left: 16,
        right: 16,
        top: 12,
        bottom: 12
      })
      .justifyContent(FlexAlign.Start)

      if (this.file_folder?.video_list.length === 0) {
        Text('还没有任何视频哦~')
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
                    Text((String(SelectFileUtil.getItem(this.file_folder?.video_list!, item?.date)?.title)).slice(0,
                      String(SelectFileUtil.getItem(this.file_folder?.video_list!, item?.date)?.title)
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
                        .imageFancy(10, 65, 25)
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
                ToolsUtil.isFileExist(item) ?
                ToolsUtil.routerToVideoFromFileFolder(context, 'pages/Player', item, this.file_folder?.video_list!) :
                this.delData(context, item)
              })
              .width('100%')
              .height(100)
              .clickEffect({ level: ClickEffectLevel.HEAVY, scale: 0.9 })
            }
          }.bindContextMenu(this.MenuBuilder(item), ResponseType.LongPress)
        }, (item: VideoMetadata) => item.date)
      }
      .layoutWeight(1)
      .padding({ left: 20, right: 20 })
      .width('100%')
      .height('100%')
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true }) // 滚动边缘效果
      .chainAnimation(true)
      .scrollBar(BarState.Off)
    }.width('100%').height('100%')
    .backgroundColor($r('app.color.start_window_background'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}