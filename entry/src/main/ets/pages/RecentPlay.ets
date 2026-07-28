import { VideoDataSource } from '../utils/DataUtil'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import { PathUtils } from '../utils/PathUtils'
import { DefaultDialogShadow } from '../common/AttributeModifierConfig'
import { VideoDetailDialog } from '../component/Dialog/VideoDetailDialog'
import { InfoConfirmDialog } from '../component/Dialog/InfoConfirmDialog'
import { Context } from '@kit.AbilityKit'
import { DELAY_JUMP_TO_PLAYER } from '../common/Constants'
import { VideoItemBuilder } from '../component/PlayerComponent/PlayerSideBarComponent'
import { VideoItemPreviewBuilder } from '../component/VideoItemComponent/VideoItemPreviewBuilder'
import DataSyncUtil from '../utils/DataSyncUtil'
import { Setting, SafeHeight } from '../utils/ObservedUtil'
import RecentPlayUtil from '../utils/RecentPlayUtil'
import SelectFileUtil from '../utils/SelectFileUtil'
import Preferences from '../database/Preferences'
import ToolsUtil from '../utils/ToolsUtil'
import VideoOperateUtil from '../utils/VideoOperateUtil'
import { HdsNavDestination, HideMode, ScrollEffectType } from '@kit.UIDesignKit'
import { LengthMetrics, SymbolGlyphModifier } from '@kit.ArkUI'

@ComponentV2
export struct RecentPlay { // 最近播放页
  @Local videoDataSource: VideoDataSource = new VideoDataSource([])
  @Local recent_video_meta_data: VideoMetadata[] = []
  deleteAllConfirmDialog: CustomDialogController = new CustomDialogController({
    builder: InfoConfirmDialog({
      textInfo: '确定清空所有播放记录吗？',
      confirm: () => {
        for (const element of this.recent_video_meta_data ?? []) {
          this.delData(PathUtils.appContext!, element)
        }
      }
    }), cornerRadius: 20, shadow: DefaultDialogShadow
  })
  @Consumer('pathStack') pathStack: NavPathStack = new NavPathStack()
  VideoDetailDialog: CustomDialogController = new CustomDialogController({
    builder: VideoDetailDialog(), cornerRadius: 20,
    shadow: DefaultDialogShadow
  })
  private pendingDeleteItem: VideoMetadata | null = null
  deleteConfirmDialog: CustomDialogController = new CustomDialogController({
    builder: InfoConfirmDialog({
      textInfo: '确定删除该播放记录吗？',
      confirm: () => {
        if (this.pendingDeleteItem) {
          this.delData(PathUtils.appContext!, this.pendingDeleteItem)
        }
      }
    }), cornerRadius: 20, shadow: DefaultDialogShadow
  })
  private listScroller: Scroller = new Scroller()

  async aboutToAppear(): Promise<void> {
    if (Setting.recentPlay) {
      this.recent_video_meta_data = RecentPlayUtil.getRecentPlaybacks()
      this.videoDataSource = new VideoDataSource(this.recent_video_meta_data)
    }
  }

  @Builder
  MenuBuilder(item: VideoMetadata | undefined) {
    Menu() {
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.play_round_triangle')),
        content: VideoOperateUtil.getPlayerName(Setting.defaultPlayerEngine, true)
      })
        .onClick(() => {
          setTimeout(async () => { //延迟跳转，确保弹窗关闭，防止系统误识别为子窗口导致播放器异常
            await this.clickItem(item, true)
          }, DELAY_JUMP_TO_PLAYER)
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.trash_fill')),
        content: $r('app.string.delete')
      }).onClick(() => {
        this.pendingDeleteItem = item!
        this.deleteConfirmDialog.open()
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

  async clickItem(item: VideoMetadata | undefined, reverse: boolean = false) {
    if (!item) {
      return
    }
    const isNetwork = ToolsUtil.isNetworkUrl(item.uri)
    if (isNetwork || await SelectFileUtil.isFileExist(item.uri, true)) {
      if (isNetwork) {
        const streams = Preferences.getNetworkStreams(PathUtils.appContext!)
        await ToolsUtil.routerWhere(this.pathStack, item, streams, reverse, true)
      } else {
        const originalList = SelectFileUtil.getVideoListByVideoDate(item.date)
        if (originalList[1].length > 0 && originalList[0]) {
          await ToolsUtil.routerWhere(this.pathStack, originalList[0], originalList[1], reverse)
        } else {
          ToolsUtil.showToast('数据异常，已移除该数据')
          this.delData(PathUtils.appContext!, item)
        }
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
    HdsNavDestination() {
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

        List({ scroller: this.listScroller, space: 6 }) {
          Repeat<VideoMetadata>(this.videoDataSource.data)
            .each((repeatItem: RepeatItem<VideoMetadata>) => {
              ListItem() {
                VideoItemBuilder({ item: repeatItem.item })
              }
              .onClick(async () => {
                await this.clickItem(repeatItem.item)
              })
              .backgroundColor(Setting.listItemBackgroundBlur ? undefined :
                $r('app.color.list_item_background'))

              .width('100%')
              .height('auto')
              .clickEffect({ level: ClickEffectLevel.HEAVY, scale: 0.9 })
              .borderRadius(16)
              .shadow({
                radius: 4,
                color: $r('app.color.shadow_color'),
                offsetX: 0,
                offsetY: 1
              })
              .bindContextMenu(this.MenuBuilder(repeatItem.item), ResponseType.LongPress,
                {
                  preview: VideoItemPreviewBuilder(repeatItem.item),
                  previewAnimationOptions: { scale: [1.0, 0.95], hoverScale: [1.0, 1.2] },
                  layoutRegionMargin: {
                    left: 16,
                    right: 16,
                    top: 16,
                    bottom: 4
                  },
                  backgroundBlurStyle: BlurStyle.COMPONENT_ULTRA_THIN,
                  hapticFeedbackMode: HapticFeedbackMode.ENABLED,
                  mask: true
                })
              .bindContextMenu(this.MenuBuilder(repeatItem.item), ResponseType.RightClick,
                {
                  preview: VideoItemPreviewBuilder(repeatItem.item),
                  previewAnimationOptions: { scale: [1.0, 0.95], hoverScale: [1.0, 1.2] },
                  layoutRegionMargin: {
                    left: 16,
                    right: 16,
                    top: 16,
                    bottom: 4
                  },
                  backgroundBlurStyle: BlurStyle.COMPONENT_ULTRA_THIN,
                  mask: true
                })
            })
            .key(
              (item: VideoMetadata, _index: number) => item.date + item.title + item.last_play + item.size.toString() +
                item.time)
            .virtualScroll()
        }
        .clip(false)
        .layoutWeight(1)
        .padding({ left: 16, right: 16 })
        .width('100%')
        .height('100%')
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true }) // 滚动边缘效果
        .chainAnimation(true)
        .scrollBar(BarState.Off)
      }
    }
    .onShown(() => {
      if (Setting.recentPlay) {
        this.recent_video_meta_data = RecentPlayUtil.getRecentPlaybacks()
        this.videoDataSource.updateData(this.recent_video_meta_data)
      }
    })
    .titleBar({
      enableComponentSafeArea: true, // 将标题栏设置为组件级安全区，内容区可避让标题栏
      padding: {
        start: LengthMetrics.vp(5),
        end: LengthMetrics.vp(5)
      },
      content: {
        title: {
          mainTitle: $r('app.string.recent_play'),
        },
        menu: {
          value: [{
            content: {
              label: '',
              icon: $r('sys.symbol.ohos_trash'),
              isEnabled: true,
              action: () => {
                this.deleteAllConfirmDialog.open()
              }
            }
          }]
        }
      },
      style: {
        // 设置导航组件标题栏样式，推荐使用默认样式
        // 标题栏动态模糊样式，包括是否使能滚动动态模糊，动态模糊类型，动态模糊生效的滚动距离等
        scrollEffectOpts: {
          enableScrollEffect: true,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
          blurEffectiveStartOffset: LengthMetrics.vp(0),
          blurEffectiveEndOffset: LengthMetrics.vp(20)
        },
        originalStyle: {
          // 内容区滚动前初始样式设置
          backgroundStyle: {
            // 标题栏背板样式设置
            backgroundColor: $r('sys.color.ohos_id_color_background'),
          },
          contentStyle: {
            // 标题栏内容区样式设置，包括标题区域，菜单区域，返回按钮区域
            titleStyle: {
              mainTitleColor: $r('sys.color.font_primary'),
              subTitleColor: $r('sys.color.font_secondary')
            },
            menuStyle: {
              backgroundColor: $r('sys.color.comp_background_tertiary'),
              iconColor: $r('sys.color.icon_primary')
            },
            backIconStyle: {
              backgroundColor: $r('sys.color.comp_background_tertiary'),
              iconColor: $r('sys.color.icon_primary')
            }
          }
        },
        scrollEffectStyle: {
          // 内容区滚动超过blurEffectiveEndOffset后样式设置
          backgroundStyle: {
            backgroundColor: $r('sys.color.ohos_id_color_background_transparent'),
          },
          contentStyle: {
            titleStyle: {
              mainTitleColor: $r('sys.color.font_primary'),
              subTitleColor: $r('sys.color.font_secondary')
            },
            menuStyle: {
              backgroundColor: $r('sys.color.comp_background_tertiary'),
              iconColor: $r('sys.color.icon_primary')
            },
            backIconStyle: {
              backgroundColor: $r('sys.color.comp_background_tertiary'),
              iconColor: $r('sys.color.icon_primary')
            }
          }
        }
      },
    })
    .padding({ top: SafeHeight.topSafeHeight })
    .backgroundColor($r('app.color.start_window_background'))
    .backgroundImage(
      Setting.backgroundDropBlur > 0 && Setting.backgroundBlurImageSrc.length > 0 ? Setting.backgroundBlurImageSrc :
        Setting.backgroundImageSrc, ImageRepeat.NoRepeat)
    .backgroundImageSize(ImageSize.Cover)
    .backgroundImagePosition(Alignment.Center)
    .bindToScrollable([this.listScroller]) // 绑定导航组件和可滚动容器组件
    .dynamicHideTitleBar({
      hideTitleArea: true,
      hideBottomBuilder: true,
      hideStatusBar: false,
      mode: HideMode.SCROLL_UP
    })
  }
}