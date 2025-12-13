import { VideoDataSource } from '../utils/DataUtil';
import RecentPlayUtil from '../utils/RecentPlayUtil';
import ToolsUtil from '../utils/ToolsUtil';
import { VideoMetadata } from '../interfaces/VideoMetadataInterface';
import { PathUtils } from '../utils/PathUtils';
import { VideoItemBuilder } from '../component/PlayerComponent/PlayerSideBarComponent';
import { SymbolGlyphModifier } from '@kit.ArkUI';
import { ButtonFancyModifier, DefaultDialogShadow, SymbolGlyphFancyModifier } from '../common/AttributeModifierConfig';
import NavigationAddress from '../common/NavigationCommon';
import VideoOperateUtil from '../utils/VideoOperateUtil';
import { VideoDetailDialog } from '../component/Dialog/VideoDetailDialog';
import DataSyncUtil from '../utils/DataSyncUtil';
import SelectFileUtil from '../utils/SelectFileUtil';
import { Context } from '@kit.AbilityKit';
import BackgroundUtil from '../utils/BackgroundUtil';

@Component
export struct RecentPlay { // 最近播放页
  @State videoDataSource: VideoDataSource = new VideoDataSource([])
  @State recent_video_meta_data: VideoMetadata[] = []
  @State longPressPreview: boolean = false
  @Consume('pathStack') pathStack: NavPathStack
  @StorageProp('topSafeHeight') topSafeHeight: number = 0;
  @StorageProp('bottomSafeHeight') bottomSafeHeight: number = 0;
  @StorageLink('recentPlay') recentPlay: boolean = true
  VideoDetailDialog: CustomDialogController = new CustomDialogController({
    builder: VideoDetailDialog(), cornerRadius: 20,
    shadow: DefaultDialogShadow
  })
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
      .attributeModifier(new ButtonFancyModifier(35, 35))
      .animation({ duration: 300, curve: Curve.Ease })
      .onClick(() => {
        for (const element of this.recent_video_meta_data ?? []) {
          this.delData(PathUtils.appContext!, element);
        }
      })
    }.margin({ right: 10, top: 10 })
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
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.trash_fill')),
        content: $r('app.string.delete')
      }).onClick(() => {
        this.delData(PathUtils.appContext!, item!)
      })
      MenuItem({ symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.info_circle')), content: '详情' })
        .onClick(() => {
          setTimeout(() => {
            DataSyncUtil.editingVideo = item
            this.VideoDetailDialog.open()
          }, 300)
        })
    }
  }

  async clickItem(item: VideoMetadata | undefined, choosePlayer: string) {
    if (!item) {
      return
    }
    const isFileExist = await SelectFileUtil.isFileExist(item.uri, true)
    if (isFileExist) {
      const originalList = SelectFileUtil.getVideoListByVideoDate(item.date)
      if (originalList[1].length > 0 && originalList[0]) {
        await ToolsUtil.routerWhere(this.pathStack, choosePlayer, originalList[0], originalList[1])
      } else {
        ToolsUtil.showToast('数据异常，已移除该数据')
        this.delData(PathUtils.appContext!, item)
      }
    } else {
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
              VideoItemBuilder({ item: item })
            }
            .onClick(async () => {
              this.clickItem(item, NavigationAddress.AV_PLAYER)
            })
            .backgroundColor(this.longPressPreview ? $r('app.color.start_window_background_blur') :
              $r('app.color.start_window_background'))
            .width('100%')
            .height('auto')
            .clickEffect({ level: ClickEffectLevel.HEAVY, scale: 0.9 })
            .borderRadius(16)
            .bindContextMenu(this.MenuBuilder(item), ResponseType.LongPress,
              {
                preview: VideoItemBuilder({ item: item, longPressPreview: this.longPressPreview }),
                previewAnimationOptions: { hoverScale: [1.0, 1.2] },
                backgroundBlurStyle: BlurStyle.COMPONENT_ULTRA_THIN,
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
                preview: VideoItemBuilder({ item: item, longPressPreview: this.longPressPreview }),
                previewAnimationOptions: { hoverScale: [1.0, 1.2] },
                backgroundBlurStyle: BlurStyle.COMPONENT_ULTRA_THIN,
                onAppear: () => {
                  this.longPressPreview = true
                },
                aboutToDisappear: () => {
                  this.longPressPreview = false
                }
              })
          }, (item: VideoMetadata) => item.date + item.title + item.last_play + item.size.toString() + item.time)
        }
        .clip(false)
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
    .onShown(() => {
      if (this.recentPlay) {
        this.recent_video_meta_data = RecentPlayUtil.getRecentPlaybacks()
        this.videoDataSource.updateData(this.recent_video_meta_data)
      }
    })
    .menus(this.NavigationMenus)
    .title('最近播放')
    .padding({ top: this.topSafeHeight })
    .backgroundColor($r('app.color.start_window_background'))
    .backgroundImage(BackgroundUtil.backgroundImageSrc, ImageRepeat.NoRepeat)
    .backgroundImageSize(ImageSize.Cover)
    .backdropBlur(BackgroundUtil.backgroundDropBlur)
    .backgroundImagePosition(Alignment.Center)
  }
}