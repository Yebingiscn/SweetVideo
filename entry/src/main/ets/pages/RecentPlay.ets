import { VideoDataSource } from '../utils/DataUtil';
import RecentPlayUtil from '../utils/RecentPlayUtil';
import ToolsUtil from '../utils/ToolsUtil';
import { VideoMetadata } from '../interfaces/VideoMetadataInterface';
import { PathUtils } from '../utils/PathUtils';
import { ListView } from '../component/PlayerComponent/PlayerSideBarComponent';
import { SymbolGlyphModifier } from '@kit.ArkUI';

@Component
export struct RecentPlay { // 最近播放页
  @State videoDataSource: VideoDataSource = new VideoDataSource([])
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
      this.videoDataSource = new VideoDataSource(this.recent_video_meta_data);
    }
  }

  @Builder
  MenuBuilder(item: VideoMetadata | undefined) {
    Menu() {
      MenuItem({ startIcon: $r("app.media.ffmpeg"), content: $r('app.string.FFMpeg_Player') }).onClick(async () => {
        this.MenuBuilderState = false
        setTimeout(async () => { //延迟跳转，确保弹窗关闭，防止系统误识别为子窗口导致播放器异常
          await ToolsUtil.isFileExist(item) ?
          ToolsUtil.routerWhere(this.pathStack, 'FFMpegPlayer', item!, this.recent_video_meta_data) :
          this.delData(PathUtils.appContext!, item!)
        }, 200)
      })

      MenuItem({ startIcon: $r("app.media.RedPlayer"), content: '红薯播放器' }).onClick(() => {
        this.MenuBuilderState = false
        setTimeout(async () => { //延迟跳转，确保弹窗关闭，防止系统误识别为子窗口导致播放器异常
          await ToolsUtil.isFileExist(item) ?
          ToolsUtil.routerWhere(this.pathStack, 'RedPlayer', item!, this.recent_video_meta_data) :
          this.delData(PathUtils.appContext!, item!)
        }, 200)
      })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.trash_fill')),
        content: $r('app.string.delete')
      }).onClick(() => {
        this.MenuBuilderState = false
        this.delData(PathUtils.appContext!, item!)
      })
    }.onAppear(() => {
      ToolsUtil.startVibration()
      this.MenuBuilderState = true
    })
  }

  delData(context: Context, item: VideoMetadata) {
    this.recent_video_meta_data = this.recent_video_meta_data.filter(i => i.date !== item.date)
    RecentPlayUtil.delData(context, item)
    this.videoDataSource.deleteData(this.videoDataSource.getAllData().indexOf(item))
  }

  build() {
    NavDestination() {
      Column() {
        if (this.recent_video_meta_data.length === 0) {
          Text($r('app.string.nothing'))
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
              ListView({
                item: item,
                now_playing: undefined
              })
                .onClick(async () => {
                  await ToolsUtil.isFileExist(item) ?
                  ToolsUtil.routerWhere(this.pathStack, 'Player', item, this.recent_video_meta_data) :
                  this.delData(PathUtils.appContext!, item)
                })
                .width('100%')
                .height(100)
                .clickEffect({ level: ClickEffectLevel.HEAVY, scale: 0.9 })
            }.bindContextMenu(this.MenuBuilder(item), ResponseType.LongPress)
            .bindContextMenu(this.MenuBuilder(item), ResponseType.RightClick)
          }, (item: VideoMetadata) => item.date + item.title + item.last_play + item.size.toString())
        }
        .layoutWeight(1)
        .padding({ left: 20, right: 20 })
        .width('100%')
        .height('100%')
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true }) // 滚动边缘效果
        .chainAnimation(true)
        .scrollBar(BarState.Off)
        .cachedCount(3)
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