import { RecentVideoDataSource } from '../utils/DataUtil';
import SelectFileUtil from '../utils/SelectFileUtil';
import { fileUri } from '@kit.CoreFileKit';
import RecentPlayUtil from '../utils/RecentPlayUtil';
import ToolsUtil from '../utils/ToolsUtil';
import { VideoMetadata } from '../interfaces/VideoMetadataInterface';
import { ImageFancyModifier } from '../utils/AttributeModifierUtil';
import { PathUtils } from '../utils/PathUtils';

@Component
export struct RecentPlay { // 最近播放页
  @State videoDataSource: RecentVideoDataSource = new RecentVideoDataSource([])
  @State recent_video_meta_data: VideoMetadata[] = []
  @State MenuBuilderState: boolean = false
  @Consume('pathStack') pathStack: NavPathStack
  @StorageProp('topSafeHeight') topSafeHeight: number = 0;
  @StorageProp('bottomSafeHeight') bottomSafeHeight: number = 0;
  @StorageLink('recentPlay') recentPlay: boolean = true
  private listScroller: Scroller = new Scroller();

  async aboutToAppear(): Promise<void> {
    if (this.recentPlay) {
      this.recent_video_meta_data = await RecentPlayUtil.getRecentPlaybacks()
      this.videoDataSource = new RecentVideoDataSource(this.recent_video_meta_data);
    }
  }

  @Builder
  MenuBuilder(item: VideoMetadata | undefined) {
    Flex({ direction: FlexDirection.Column, justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center }) {
      Menu() {
        MenuItem({ startIcon: $r("app.media.ffmpeg"), content: $r('app.string.FFMpeg_Player') }).onClick(async () => {
          this.MenuBuilderState = false
          setTimeout(async () => { //延迟跳转，确保弹窗关闭，防止系统误识别为子窗口导致播放器异常
            await ToolsUtil.isFileExist(item) ?
            ToolsUtil.routerWhere(this.pathStack, 'FFMpegPlayer', item!, this.recent_video_meta_data) :
            this.delData(PathUtils.appContext!, item!)
          }, 200)
        })
      }.font({ size: 15, weight: FontWeight.Normal })

      MenuItem({ startIcon: $r("app.media.RedPlayer"), content: '红薯播放器' }).onClick(() => {
        this.MenuBuilderState = false
        setTimeout(async () => { //延迟跳转，确保弹窗关闭，防止系统误识别为子窗口导致播放器异常
          await ToolsUtil.isFileExist(item) ?
          ToolsUtil.routerWhere(this.pathStack, 'RedPlayer', item!, this.recent_video_meta_data) :
          this.delData(PathUtils.appContext!, item!)
        }, 200)
      })
      MenuItem({ startIcon: $r('sys.symbol.trash_fill'), content: $r('app.string.delete') }).onClick(() => {
        this.MenuBuilderState = false
        this.delData(PathUtils.appContext!, item!)
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
                  Image(fileUri.getUriFromPath(PathUtils.coverPath + item.date))
                    .attributeModifier(new ImageFancyModifier(10, 60, 90))
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
                  ToolsUtil.routerWhere(this.pathStack, 'Player', item, this.recent_video_meta_data) :
                  this.delData(PathUtils.appContext!, item)
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
    }.onShown(async () => {
      if (this.recentPlay) {
        this.recent_video_meta_data = await RecentPlayUtil.getRecentPlaybacks()
        this.videoDataSource.updateData(this.recent_video_meta_data)
      }
    })
    .title('最近播放')
    .padding({ top: this.topSafeHeight })
    .backgroundColor($r('app.color.start_window_background'))
  }
}