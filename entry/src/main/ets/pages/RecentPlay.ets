import { RecentVideoDataSource } from '../utils/DataUtil';
import SelectFileUtil from '../utils/SelectFileUtil';
import { fileUri } from '@kit.CoreFileKit';
import RecentPlayUtil from '../utils/RecentPlayUtil';
import ToolsUtil from '../utils/ToolsUtil';
import { common } from '@kit.AbilityKit';
import { VideoMetadata } from '../interfaces/VideoMetadataInterface';

const sandbox_path = getContext().filesDir + '/'
const context = getContext() as common.UIAbilityContext;

@Extend(SymbolGlyph)
function symbolGlyphFancy(fontSize: number, width: number | string, height: number | string) {
  .fontSize(fontSize)
  .fontColor([$r('app.color.text_color')])
  .width(width)
  .height(height)
}


@Component
export struct RecentPlay { // 最近播放页
  @State videoDataSource: RecentVideoDataSource = new RecentVideoDataSource([])
  @State recent_video_meta_data: VideoMetadata[] = []
  @State MenuBuilderState: boolean = false
  @Consume('pathStack') pathStack: NavPathStack
  @StorageProp('topSafeHeight') topSafeHeight: number = 0;
  @StorageProp('bottomSafeHeight') bottomSafeHeight: number = 0;
  private listScroller: Scroller = new Scroller();

  async aboutToAppear(): Promise<void> {
    this.recent_video_meta_data = await RecentPlayUtil.getRecentPlaybacks()
    this.videoDataSource = new RecentVideoDataSource(this.recent_video_meta_data);
  }

  @Builder
  MenuBuilder(item: VideoMetadata | undefined) {
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
        ToolsUtil.routerWhere(this.pathStack, context, 'FFMpegPlayer', item?.date!, this.recent_video_meta_data,
          false) :
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

  delData(context: Context, item: VideoMetadata) {
    RecentPlayUtil.delData(context, item)
    this.videoDataSource.deleteData(this.videoDataSource.getAllData().indexOf(item))
  }

  build() {
    NavDestination() {
      Column() {

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
                  ToolsUtil.routerWhere(this.pathStack, context, 'Player', item.date, this.recent_video_meta_data,
                    false) :
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
      }
    }
    .title('最近播放')
    .padding({ top: this.topSafeHeight, bottom: this.bottomSafeHeight })
    .backgroundColor($r('app.color.start_window_background'))
  }
}