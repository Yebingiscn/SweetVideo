import { VideoDataSource } from '../utils/DataUtil';
import RecentPlayUtil from '../utils/RecentPlayUtil';
import ToolsUtil from '../utils/ToolsUtil';
import { VideoMetadata } from '../interfaces/VideoMetadataInterface';
import { PathUtils } from '../utils/PathUtils';
import { ListView } from '../component/PlayerComponent/PlayerSideBarComponent';
import { SymbolGlyphModifier } from '@kit.ArkUI';
import { ButtonFancyModifier, SymbolGlyphFancyModifier } from '../utils/AttributeModifierUtil';
import NavigationAddress from '../common/NavigationAddress';

@Component
export struct RecentPlay { // 最近播放页
  @State videoDataSource: VideoDataSource = new VideoDataSource([])
  @State recent_video_meta_data: VideoMetadata[] = []
  @State MenuBuilderState: boolean = false
  @State longPressPreview: boolean = false
  @Consume('pathStack') pathStack: NavPathStack
  @StorageProp('topSafeHeight') topSafeHeight: number = 0;
  @StorageProp('bottomSafeHeight') bottomSafeHeight: number = 0;
  @StorageLink('recentPlay') recentPlay: boolean = true
  private listScroller: Scroller = new Scroller();

  async aboutToAppear(): Promise<void> {
    if (this.recentPlay) {
      this.recent_video_meta_data = RecentPlayUtil.getRecentPlaybacks()
      this.videoDataSource = new VideoDataSource(this.recent_video_meta_data);
    }
  }

  @Builder
  NavigationMenus() {
    Row() {
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.ohos_trash'))
          .attributeModifier(new SymbolGlyphFancyModifier(25, '', ''))
      }
      .backdropBlur(150)
      .attributeModifier(new ButtonFancyModifier(40, 40))
      .animation({ duration: 300, curve: Curve.Ease })
      .onClick(() => {
        for (const element of this.recent_video_meta_data ?? []) {
          this.delData(PathUtils.appContext!, element);
        }
      })
      .margin({ right: 10 })
    }
  }

  @Builder
  MenuBuilder(item: VideoMetadata | undefined) {
    Menu() {
      MenuItem({ startIcon: $r("app.media.ffmpeg"), content: $r('app.string.FFMpeg_Player') }).onClick(async () => {
        this.MenuBuilderState = false
        setTimeout(async () => { //延迟跳转，确保弹窗关闭，防止系统误识别为子窗口导致播放器异常
          this.clickItem(item, NavigationAddress.FFMPEG_PLAYER)
        }, 350)
      })

      MenuItem({ startIcon: $r("app.media.RedPlayer"), content: '红薯播放器' }).onClick(() => {
        this.MenuBuilderState = false
        setTimeout(async () => { //延迟跳转，确保弹窗关闭，防止系统误识别为子窗口导致播放器异常
          this.clickItem(item, NavigationAddress.RED_PLAYER)
        }, 350)
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

  async clickItem(item: VideoMetadata | undefined, choosePlayer: string) {
    if (item) {
      await ToolsUtil.isFileExist(item?.uri) ?
        ToolsUtil.routerWhere(this.pathStack, choosePlayer, item, this.recent_video_meta_data) :
        this.delData(PathUtils.appContext!, item)
    }
  }

  delData(context: Context, item: VideoMetadata) {
    this.recent_video_meta_data = this.recent_video_meta_data.filter(i => i.date !== item.date)
    RecentPlayUtil.delData(context, item.uri)
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
                  this.clickItem(item, NavigationAddress.AV_PLAYER)
                })
                .width('100%')
                .height(100)
                .clickEffect({ level: ClickEffectLevel.HEAVY, scale: 0.9 })
            }.backgroundColor(this.longPressPreview ? $r('app.color.start_window_background_blur') :
              $r('app.color.start_window_background'))
            .borderRadius(8)
            .bindContextMenu(this.MenuBuilder(item), ResponseType.LongPress,
              {
                preview: MenuPreviewMode.IMAGE,
                previewAnimationOptions: { scale: [0.8, 1.0] },
              })
            .bindContextMenu(this.MenuBuilder(item), ResponseType.RightClick,
              {
                preview: MenuPreviewMode.IMAGE,
                previewAnimationOptions: { scale: [0.8, 1.0] },
              })
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
    }
    .onShown(async () => {
      if (this.recentPlay) {
        this.recent_video_meta_data = RecentPlayUtil.getRecentPlaybacks()
        this.videoDataSource.updateData(this.recent_video_meta_data)
      }
    })
    .menus(this.NavigationMenus())
    .title('最近播放')
    .padding({ top: this.topSafeHeight })
    .backgroundColor($r('app.color.start_window_background'))
  }
}