import { VideoDataSource } from '../utils/DataUtil'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import { PathUtils } from '../utils/PathUtils'
import { VideoDetailSheetBuilder } from '../component/Dialog/VideoDetailDialog'
import { InfoConfirmDialog } from '../component/Dialog/InfoConfirmDialog'
import { Context } from '@kit.AbilityKit'
import { DELAY_JUMP_TO_PLAYER } from '../common/Constants'
import { VideoItemBuilder } from '../component/PlayerComponent/PlayerSideBarComponent'
import { VideoItemPreviewBuilder } from '../component/VideoItemComponent/VideoItemPreviewBuilder'

import { SafeHeight, Setting } from '../utils/ObservedUtil'
import RecentPlayUtil from '../utils/RecentPlayUtil'
import { RecentPlaybackSnapshot } from '../utils/RecentPlaybackSnapshot'
import SelectFileUtil from '../utils/SelectFileUtil'
import Preferences from '../database/Preferences'
import ToolsUtil from '../utils/ToolsUtil'
import VideoOperateUtil from '../utils/VideoOperateUtil'
import { hdsMaterial, HdsNavDestination, HideMode, ScrollEffectType } from '@kit.UIDesignKit'
import { LengthMetrics, uiMaterial } from '@kit.ArkUI'
import { SuppressWarnings, SuppressWarningsType } from '@kit.BasicServicesKit'
import { MaterialCapability } from '../common/MaterialCapability'

@ComponentV2
export struct RecentPlay { // 最近播放页
  @Local videoDataSource: VideoDataSource = new VideoDataSource([])
  @Local recent_video_meta_data: VideoMetadata[] = []
  deleteAllConfirmDialog: CustomDialogController = new CustomDialogController({
    builder: InfoConfirmDialog({
      textInfo: $r('app.string.clear_play_history_confirm'),
      confirm: () => {
        if (!RecentPlayUtil.clearData(PathUtils.appContext!)) {
          ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.delete_failed_retry').id))
          return
        }
        this.publishRecentPlay([])
      }
    }),
    cornerRadius: 20,
    systemMaterial: MaterialCapability.hdsSupported ? new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.ULTRA_THICK
    }) : undefined
  })
  @Consumer('pathStack') pathStack: NavPathStack = new NavPathStack()
  @Local showDetailSheet: boolean = false
  @Local detailMetadata: VideoMetadata | undefined = undefined
  private pendingDeleteItem: VideoMetadata | null = null
  deleteConfirmDialog: CustomDialogController = new CustomDialogController({
    builder: InfoConfirmDialog({
      textInfo: $r('app.string.delete_play_record_confirm'),
      confirm: () => {
        if (this.pendingDeleteItem) {
          this.delData(PathUtils.appContext!, this.pendingDeleteItem)
        }
      }
    }), cornerRadius: 20, systemMaterial: MaterialCapability.hdsSupported ? new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.ULTRA_THICK
    }) : undefined
  })
  private listScroller: Scroller = new Scroller()
  private historySnapshot: RecentPlaybackSnapshot = new RecentPlaybackSnapshot()
  private historySubscription: (() => void) | undefined = undefined

  aboutToDisappear(): void {
    this.stopObservingRecentPlay()
  }

  @Builder
  MenuBuilder(item: VideoMetadata | undefined) {
    Menu() {
      MenuItem({
        content: VideoOperateUtil.getPlayerName(Setting.defaultPlayerEngine, true)
      })
        .onClick(() => {
          setTimeout(async () => { //延迟跳转，确保弹窗关闭，防止系统误识别为子窗口导致播放器异常
            await this.clickItem(item, true)
          }, DELAY_JUMP_TO_PLAYER)
        })
      MenuItem({
        content: $r('app.string.short_video_mode')
      })
        .onClick(() => {
          setTimeout(async () => {
            if (item) {
              await ToolsUtil.routerToShortVideo(this.pathStack, item, this.recent_video_meta_data)
            }
          }, DELAY_JUMP_TO_PLAYER)
        })
      MenuItem({
        content: $r('app.string.delete')
      }).onClick(() => {
        this.pendingDeleteItem = item!
        this.deleteConfirmDialog.open()
      })
      MenuItem({ content: $r('app.string.menu_detail') })
        .onClick(() => {
          setTimeout(() => {
            this.detailMetadata = item
            this.showDetailSheet = true
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
        let originalList: [VideoMetadata | undefined, VideoMetadata[], string | undefined]
        try {
          originalList = Preferences.findVideoByDate(PathUtils.appContext!, item.date, true)
        } catch (_error) {
          // 媒体库读取失败不代表历史记录已经失效。
          ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.open_video_failed').id))
          return
        }
        if (originalList[1].length > 0 && originalList[0]) {
          await ToolsUtil.routerWhere(this.pathStack, originalList[0], originalList[1], reverse)
        } else if (this.delData(PathUtils.appContext!, item)) {
          ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.data_invalid_removed').id))
        }
      }
    } else {
      this.delData(PathUtils.appContext!, item)
    }
  }

  delData(context: Context, item: VideoMetadata): boolean {
    if (!RecentPlayUtil.delData(context, item.uri)) {
      ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.delete_failed_retry').id))
      return false
    }
    // Read the successful persisted result, not a possibly stale visible subset.
    this.refreshRecentPlay()
    return true
  }

  @SuppressWarnings({ rules: [SuppressWarningsType.SYSCAP] })
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
                  hapticFeedbackMode: HapticFeedbackMode.ENABLED,
                  mask: true,
                  systemMaterial: MaterialCapability.hdsSupported ? new uiMaterial.ImmersiveMaterial({
                    style: uiMaterial.ImmersiveStyle.ULTRA_THICK,
                  }) : undefined
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
                  mask: true,
                  systemMaterial: MaterialCapability.hdsSupported ? new uiMaterial.ImmersiveMaterial({
                    style: uiMaterial.ImmersiveStyle.ULTRA_THICK,
                  }) : undefined
                })
            })
            .key((item: VideoMetadata): string => RecentPlaybackSnapshot.key(item))
            .virtualScroll()
        }
        .clip(false)
        .layoutWeight(1)
        .padding({ left: 16, right: 16 })
        .contentEndOffset(SafeHeight.bottomSafeHeight)
        .width('100%')
        .height('100%')
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true }) // 滚动边缘效果
        .chainAnimation(true)
        .scrollBar(BarState.Off)
      }
    }
    .onShown(() => {
      // 返回时可能早于播放器完成进度保存，继续监听成功写入以更新本次进度。
      this.observeRecentPlay()
    })
    .onHidden(() => {
      this.stopObservingRecentPlay()
    })
    .titleBar({
      enableComponentSafeArea: true, // 将标题栏设置为组件级安全区，内容区可避让标题栏
      avoidLayoutSafeArea: true,
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
          scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR,
          blurEffectiveStartOffset: LengthMetrics.vp(0),
          blurEffectiveEndOffset: LengthMetrics.vp(20)
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
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
      mode: HideMode.SCROLL_UP_TO
    })
    .bindSheet(this.showDetailSheet, this.DetailSheetBuilder, {
      detents: [SheetSize.LARGE],
      showClose: true,
      onWillDismiss: () => {
        this.showDetailSheet = false
      },
      systemMaterial: MaterialCapability.hdsSupported ? new uiMaterial.ImmersiveMaterial({
        style: uiMaterial.ImmersiveStyle.ULTRA_THICK,
      }) : undefined
    })
  }

  @Builder
  DetailSheetBuilder() {
    VideoDetailSheetBuilder(this.detailMetadata)
  }

  private observeRecentPlay(): void {
    if (!this.historySubscription) {
      this.historySubscription = Preferences.subscribeRecentPlayChanges(() => {
        this.refreshRecentPlay()
      })
    }
    this.refreshRecentPlay()
  }

  private stopObservingRecentPlay(): void {
    this.historySubscription?.()
    this.historySubscription = undefined
  }

  private publishRecentPlay(items: VideoMetadata[]): void {
    if (!this.historySnapshot.update(items)) {
      return
    }
    this.recent_video_meta_data = this.historySnapshot.items
    this.videoDataSource.updateData(this.recent_video_meta_data)
  }

  private refreshRecentPlay(): void {
    this.publishRecentPlay(Setting.recentPlay ? RecentPlayUtil.getRecentPlaybacks() : [])
  }
}
