import DataSyncUtil from '../utils/DataSyncUtil';
import { RecentVideoDataSource } from '../utils/DataUtil';
import SelectFileUtil from '../utils/SelectFileUtil';
import { fileUri } from '@kit.CoreFileKit';
import RecentPlayUtil from '../utils/RecentPlayUtil';
import ToolsUtil from '../utils/ToolsUtil';
import { common } from '@kit.AbilityKit';
import { VideoMetadataInterface } from '../interfaces/VideoMetadataInterface';

const sandbox_path = getContext().filesDir + '/'
const context = getContext() as common.UIAbilityContext;

@Extend(SymbolGlyph)
function symbolGlyphFancy(fontSize: number, width: number | string, height: number | string) {
  .fontSize(fontSize)
  .fontColor([$r('app.color.text_color')])
  .width(width)
  .height(height)
}

@Builder
export function RecentPlayBuilder() {
  RecentPlay()
}

@Entry
@Component
struct RecentPlay { // 最近播放页
  @State videoDataSource: RecentVideoDataSource = new RecentVideoDataSource([])
  @State recent_video_meta_data: VideoMetadataInterface[] = []
  @State MenuBuilderState: boolean = false
  pathStack: NavPathStack = new NavPathStack()
  private listScroller: Scroller = new Scroller();

  async aboutToAppear(): Promise<void> {
    this.recent_video_meta_data = await RecentPlayUtil.getRecentPlaybacks()
    this.videoDataSource = new RecentVideoDataSource(this.recent_video_meta_data);
  }

  @Builder
  MenuBuilder(item: VideoMetadataInterface | undefined) {
    Flex({ direction: FlexDirection.Column, justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center }) {
      Row() {
        Image($r("app.media.ffmpeg"))
          .width(25)
          .height(25)
          .borderRadius(10)
          .backgroundImageSize(ImageSize.Cover)
          .autoResize(true)
          .interpolation(ImageInterpolation.Low)
        Text($r('app.string.FFMpeg_Player'))
          .fontSize(15)
          .width(180)
          .height(30)
      }.padding(10).onClick(async () => {
        this.MenuBuilderState = false
        await ToolsUtil.isFileExist(item) ?
        ToolsUtil.routerWhere(this.pathStack, context, 'FFMpegPlayer', item?.date!, false) :
        this.delData(context, item!)
      })

      Divider().height(2)
      Row() {
        SymbolGlyph($r('sys.symbol.trash_fill'))
          .symbolGlyphFancy(20, 25, 40)
        Text($r('app.string.delete'))
          .fontSize(15)
          .width(180)
          .height(30)
      }.padding(10).onClick(() => {
        this.delData(context, item!)
      })
    }.width(150).onAppear(() => {
      ToolsUtil.startVibration()
      this.MenuBuilderState = true
    })
  }

  delData(context: Context, item: VideoMetadataInterface) {
    RecentPlayUtil.delData(context, item)
    this.videoDataSource.deleteData(this.videoDataSource.getAllData().indexOf(item))
  }

  build() {
    NavDestination() {
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
            this.pathStack.clear()
          })

          Text('最近播放')
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

        if (this.recent_video_meta_data.length === 0) {
          Text('此时无声胜有声 <(￣ c￣)y▂ξ')
            .fontSize(24)
            .fontWeight(FontWeight.Medium)
            .textAlign(TextAlign.Center)
            .align(Alignment.Center)
            .height('100%')
            .width('100%')
        }

        List({ scroller: this.listScroller, space: 10 }) {
          LazyForEach(this.videoDataSource, (item: VideoMetadataInterface) => {
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
                  Text((String(SelectFileUtil.getItem(this.recent_video_meta_data, item?.date)?.title)).slice(0,
                    String(SelectFileUtil.getItem(this.recent_video_meta_data, item?.date)?.title).lastIndexOf('.')))
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .maxLines(4)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .width('65%')
                    .margin({ left: 5 })
                    .wordBreak(WordBreak.BREAK_ALL)
                }
                .onClick(async () => {
                  await ToolsUtil.isFileExist(item) ?
                  ToolsUtil.routerWhere(this.pathStack, context, 'Player', item.date, false) :
                  this.delData(context, item)
                })
                .width('100%')
                .height(100)
                .clickEffect({ level: ClickEffectLevel.HEAVY, scale: 0.9 })
              }
            }.bindContextMenu(this.MenuBuilder(item), ResponseType.LongPress)
          }, (item: VideoMetadataInterface) => item.date)
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
    }.onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack
    }).hideToolBar(true).hideTitleBar(true)
  }
}