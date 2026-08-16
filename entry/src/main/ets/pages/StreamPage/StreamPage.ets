import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import Preferences from '../../database/Preferences'
import { PathUtils } from '../../utils/PathUtils'
import DataSyncUtil from '../../utils/DataSyncUtil'
import ToolsUtil from '../../utils/ToolsUtil'
import SelectFileUtil from '../../utils/SelectFileUtil'
import { LengthMetrics, SymbolGlyphModifier } from '@kit.ArkUI'
import {
  ButtonFancyModifier,
  DefaultDialogShadow,
  MenuFancyModifier,
  SymbolGlyphFancyModifier
} from '../../common/AttributeModifierConfig'
import { SortField } from '../../common/enum/SortField'
import { SafeHeight, Setting } from '../../utils/ObservedUtil'
import { HdsNavDestination, HideMode, ScrollEffectType } from '@kit.UIDesignKit'
import { SortMenuComponent } from '../../component/common/SortMenuComponent'

import { SearchComponent } from '../../component/VideoItemComponent/SearchComponent'
import { EditStreamDialog } from '../../component/Dialog/EditStreamDialog'
import { AddNetworkStreamDialog } from '../../component/Dialog/AddNetworkStreamDialog'
import { InfoConfirmDialog } from '../../component/Dialog/InfoConfirmDialog'
import { VideoItemPreviewBuilder } from '../../component/VideoItemComponent/VideoItemPreviewBuilder'
import { XAnimation } from '../../utils/AnimationUtil'
import VideoOperateUtil from '../../utils/VideoOperateUtil'
import { DELAY_JUMP_TO_PLAYER } from '../../common/Constants'
import ShareUtil from '../../utils/ShareUtil'
import VideoCardItem from '../../component/VideoItemComponent/VideoCardItemComponent'
import VideoListItem from '../../component/VideoItemComponent/VideoListItemComponent'
import { VideoListController } from '../../component/VideoItemComponent/VideoItemComponent'
import { ListDisplayMode } from '../../common/enum/DisplayMode'
import RecentPlayUtil from '../../utils/RecentPlayUtil'

@ComponentV2
export struct StreamPage {
  @Local networkStreams: VideoMetadata[] = []
  @Local allStreams: VideoMetadata[] = []
  editStreamDialogController: CustomDialogController = new CustomDialogController({
    builder: EditStreamDialog({
      onConfirm: (newName: string, newUrl: string) => {
        const stream = DataSyncUtil.editingVideo
        if (!stream) {
          return
        }
        const streams = Preferences.getNetworkStreams(PathUtils.appContext!)
        const target = streams.find(s => s.date === stream.date)
        if (target) {
          target.title = newName
          target.uri = newUrl
          Preferences.saveNetworkStreams(PathUtils.appContext!, streams)
          this.allStreams = [...streams]
          this.applySearch()
        }
      }
    }), cornerRadius: 20, shadow: DefaultDialogShadow
  })
  addNetworkStreamDialogController: CustomDialogController = new CustomDialogController({
    builder: AddNetworkStreamDialog({
      onStreamAdded: () => {
        this.allStreams = Preferences.getNetworkStreams(PathUtils.appContext!)
        this.applySearch()
      }
    }), cornerRadius: 20, shadow: DefaultDialogShadow
  })
  @Local searchValue: string = ''
  @Local is_edit: boolean = false
  @Local currentSortField: SortField | '' = ''
  @Local currentSortAsc: boolean = true
  @Local pinyinSort: boolean = true
  @Consumer('pathStack') pathStack: NavPathStack = new NavPathStack()
  searchController: SearchController = new SearchController()
  @Local list_line: number = 1
  @Provider('videoListController') streamVideoListController: VideoListController = new VideoListController()
  @Local delMultipleList: VideoMetadata[] = []
  @Local multipleChooseState: Visibility = Visibility.None
  private pendingDeleteStream: VideoMetadata | null = null
  deleteConfirmDialog: CustomDialogController = new CustomDialogController({
    builder: InfoConfirmDialog({
      textInfo: '确定删除该串流吗？',
      confirm: async () => {
        if (this.pendingDeleteStream) {
          await this.deleteStream(this.pendingDeleteStream)
          this.pendingDeleteStream = null
        }
      }
    }), cornerRadius: 20, shadow: DefaultDialogShadow
  })
  private listScroller: ListScroller = new ListScroller()

  @Monitor('multipleChooseState')
  onMultipleChooseStateChanged() {
    this.streamVideoListController.multipleChooseState = this.multipleChooseState
  }

  aboutToAppear(): void {
    this.allStreams = Preferences.getNetworkStreams(PathUtils.appContext!)
    this.networkStreams = this.allStreams
    const savedField = Preferences.getSortField(PathUtils.appContext!)
    if (savedField === SortField.NAME || savedField === SortField.DATETIME || savedField === SortField.TIME) {
      this.currentSortField = savedField as SortField
    }
    this.currentSortAsc = Preferences.getSortAsc(PathUtils.appContext!)
    this.pinyinSort = Preferences.getPinyinSort(PathUtils.appContext!)
  }

  @Builder
  NavigationMenus() {
    Row() {
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.plus'))
          .attributeModifier(new SymbolGlyphFancyModifier(25, '', ''))
      }
      .backdropBlur(150)
      .attributeModifier(new ButtonFancyModifier(35, 35))
      .animation({ duration: 300, curve: Curve.Ease })
      .onClick(() => {
        this.addNetworkStreamDialogController.open()
      })
      .margin({ right: 10 })
    }.justifyContent(FlexAlign.End).width('100%').height('auto')
  }

  @Builder
  SearchBuilder() {
    Row({ space: 10 }) {
      SearchComponent({
        controller: this.searchController,
        searchValue: this.searchValue,
        onSearchValueChange: (v: string) => {
          this.searchValue = v
        },
        onChange: () => {
          if (this.searchValue.trim() === '') {
            this.networkStreams = this.allStreams
          } else {
            this.networkStreams = SelectFileUtil.getItemFromSearch(this.allStreams, this.searchValue)
          }
        },
        onEditChange: (isEditing: boolean) => {
          XAnimation.runWithAnimation(() => {
            this.is_edit = isEditing
          })
        }
      })

      if (!this.is_edit) {
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.text_and_arrow_down'))
            .attributeModifier(new SymbolGlyphFancyModifier(25, '', ''))
        }
        .backdropBlur(150)
        .attributeModifier(new ButtonFancyModifier(35, 35))
        .transition(XAnimation.getAnimation('right', 0, false))
        .bindMenu(this.SortMenuBuilder, { showInSubWindow: false })
      }
    }
    .width('95%')
    .justifyContent(FlexAlign.Start)
    .animation({ duration: 300, curve: Curve.Ease })
  }

  @Builder
  SortMenuBuilder() {
    SortMenuComponent({
      currentSortField: this.currentSortField,
      currentSortAsc: this.currentSortAsc,
      pinyinSort: this.pinyinSort,
      pinyinSortField: SortField.NAME,
      items: [
        {
          field: SortField.DATETIME,
          icon: $r('sys.symbol.calendar'),
          textResource: $r('app.string.sort_by_datetime'),
          onAction: (): void => this.handleSort(SortField.DATETIME, false)
        },
        {
          field: SortField.TIME,
          icon: $r('sys.symbol.clock'),
          textResource: $r('app.string.sort_by_time'),
          onAction: (): void => this.handleSort(SortField.TIME, false)
        },
        {
          field: SortField.NAME,
          icon: $r('sys.symbol.textformat'),
          textResource: $r('app.string.sort_by_name'),
          onAction: (): void => this.handleSort(SortField.NAME, true)
        }
      ],
      onPinyinSortChange: (value: boolean): void => this.handlePinyinSortChange(value)
    })
  }

  @Builder
  StreamMenuBuilder(item: VideoMetadata | undefined) {
    Menu() {
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.play_round_triangle')),
        content: VideoOperateUtil.getPlayerName(Setting.defaultPlayerEngine, true)
      })
        .onClick(() => {
          setTimeout(() => {
            this.playStream(item!, true)
          }, DELAY_JUMP_TO_PLAYER)
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.rename')),
        content: '编辑'
      })
        .onClick(() => {
          DataSyncUtil.editingVideo = item
          this.editStreamDialogController.open()
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.trash_fill')),
        content: '删除'
      })
        .onClick(() => {
          this.pendingDeleteStream = item!
          this.deleteConfirmDialog.open()
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.share')),
        content: $r('app.string.share')
      })
        .onClick(async () => {
          await ShareUtil.shareVideo(item!.uri, item!.title)
        })
    }
    .attributeModifier(new MenuFancyModifier())
  }

  build() {
    HdsNavDestination() {
      Column() {
        if (this.networkStreams.length === 0) {
          Column() {
            if (this.searchValue.trim() !== '') {
              Text('未找到相关串流')
                .fontSize(18)
                .fontColor($r('app.color.text_color'))
                .opacity(0.6)
            } else {
              Text('暂无串流')
                .fontSize(18)
                .fontColor($r('app.color.text_color'))
                .opacity(0.6)
              Text('点击右上角 + 添加串流')
                .fontSize(14)
                .fontColor($r('app.color.text_color'))
                .opacity(0.4)
                .margin({ top: 8 })
            }
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          if (Setting.listDisplayMode === ListDisplayMode.LIST_DISPLAY) {
            List({ scroller: this.listScroller, space: 10 }) {
              Repeat<VideoMetadata>(this.networkStreams)
                .each((repeatItem: RepeatItem<VideoMetadata>) => {
                  ListItem() {
                    VideoListItem({
                      item: repeatItem.item,
                      delMultipleList: this.delMultipleList
                    })
                  }
                  .backgroundColor(Setting.listItemBackgroundBlur ? undefined :
                    $r('app.color.start_window_background'))
                  .borderRadius(12)
                  .width('100%')
                  .height('auto')
                  .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
                  .onClick(() => this.playStream(repeatItem.item))
                  .bindContextMenu(this.StreamMenuBuilder(repeatItem.item), ResponseType.LongPress,
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
                  .bindContextMenu(this.StreamMenuBuilder(repeatItem.item), ResponseType.RightClick,
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
                .key((item: VideoMetadata) => item.date)
                .virtualScroll()
            }
            .clip(false)
            .lanes(this.list_line)
            .layoutWeight(1)
            .padding({ left: 16, right: 16 })
            .width('100%')
            .height('100%')
            .scrollBar(BarState.Off)
            .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
            .chainAnimation(true)
          } else {
            WaterFlow({
              scroller: this.listScroller,
              layoutMode: WaterFlowLayoutMode.SLIDING_WINDOW
            }) {
              Repeat<VideoMetadata>(this.networkStreams)
                .each((repeatItem: RepeatItem<VideoMetadata>) => {
                  FlowItem() {
                    VideoCardItem({
                      item: repeatItem.item,
                      delMultipleList: this.delMultipleList
                    }).width('100%')
                  }
                  .backgroundColor(Setting.listItemBackgroundBlur ? undefined :
                    (Setting.backgroundImageSrc.length > 0 ?
                      $r('app.color.start_window_background_blur') :
                      $r('app.color.start_window_background')))
                  .borderRadius(12)
                  .width('100%')
                  .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
                  .onClick(() => this.playStream(repeatItem.item))
                  .bindContextMenu(this.StreamMenuBuilder(repeatItem.item), ResponseType.LongPress,
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
                  .bindContextMenu(this.StreamMenuBuilder(repeatItem.item), ResponseType.RightClick,
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
                .key((item: VideoMetadata) => item.date)
                .virtualScroll()
            }
            .clip(false)
            .columnsTemplate('1fr '.repeat(this.list_line).trim())
            .columnsGap(16)
            .rowsGap(16)
            .layoutWeight(1)
            .padding({ left: 16, right: 16 })
            .scrollBar(BarState.Off)
            .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
            .width('100%')
            .height('100%')
          }
        }
      }.padding({ bottom: SafeHeight.bottomSafeHeight })
      .width('100%')

      .onAreaChange(async (_oldValue: Area, newValue: Area) => {
        const width = Number(newValue.width)
        const base = Math.floor(width / 500)
        this.list_line = Setting.listDisplayMode === ListDisplayMode.LIST_DISPLAY
          ? base + 1
          : base + 2
      })
    }
    .titleBar({
      enableComponentSafeArea: true,
      padding: {
        start: LengthMetrics.vp(5),
        end: LengthMetrics.vp(5)
      },
      style: {
        scrollEffectOpts: {
          enableScrollEffect: true,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
          blurEffectiveStartOffset: LengthMetrics.vp(0),
          blurEffectiveEndOffset: LengthMetrics.vp(20)
        },
        originalStyle: {
          backgroundStyle: {
            backgroundColor: $r('sys.color.ohos_id_color_background'),
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
        },
        scrollEffectStyle: {
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
      content: {
        title: {
          mainTitle: '网络串流',
        },
        stackBuilder: (): void => this.NavigationMenus(),
        bottomBuilder: { builder: (): void => this.SearchBuilder() },
      },
    })
    .backgroundImage(
      Setting.backgroundDropBlur > 0 && Setting.backgroundBlurImageSrc.length > 0 ? Setting.backgroundBlurImageSrc :
        Setting.backgroundImageSrc, ImageRepeat.NoRepeat)
    .backgroundImageSize(ImageSize.Cover)
    .backgroundImagePosition(Alignment.Center)
    .padding({ top: SafeHeight.topSafeHeight })
    .backgroundColor($r('app.color.start_window_background'))
    .bindToScrollable([this.listScroller]) // 绑定导航组件和可滚动容器组件
    .onBackPressed(() => {
      if (this.searchValue.length > 0) {
        this.searchValue = ''
        this.networkStreams = this.allStreams
        return true
      }
      return false
    })
    .dynamicHideTitleBar({
      hideTitleArea: true,
      hideBottomBuilder: true,
      hideStatusBar: false,
      mode: HideMode.SCROLL_UP
    })
    .hideBackButton(false)
    .onShown(() => {
      this.allStreams = Preferences.getNetworkStreams(PathUtils.appContext!)
      this.applySearch()
      if (DataSyncUtil.lastPlayVideoIndex >= 0) {
        this.listScroller.scrollToIndex(DataSyncUtil.lastPlayVideoIndex)
        DataSyncUtil.lastPlayVideoIndex = -1
      }
    })
  }

  private playStream(stream: VideoMetadata, reverse: boolean = false) {
    if (Setting.recentPlay) {
      RecentPlayUtil.addPlayback(PathUtils.appContext!, stream)
    }
    ToolsUtil.routerWhere(this.pathStack, stream, this.networkStreams, reverse, true)
  }

  private async deleteStream(stream: VideoMetadata) {
    const streams = Preferences.getNetworkStreams(PathUtils.appContext!)
    const idx = streams.findIndex(s => s.date === stream.date)
    if (idx !== -1) {
      streams.splice(idx, 1)
      Preferences.saveNetworkStreams(PathUtils.appContext!, streams)
      this.allStreams = [...streams]
      this.applySearch()
      RecentPlayUtil.delData(PathUtils.appContext!, stream.uri)
      await SelectFileUtil.deleteCover(stream.date as string).catch(() => {
      })
    }
  }

  private applySearch() {
    this.networkStreams = this.searchValue.trim()
      ? SelectFileUtil.getItemFromSearch(this.allStreams, this.searchValue)
      : this.allStreams
  }

  private handleSort(field: SortField, defaultAsc: boolean) {
    if (this.currentSortField === field) {
      this.currentSortAsc = !this.currentSortAsc
    } else {
      this.currentSortField = field
      this.currentSortAsc = defaultAsc
    }
    Preferences.saveSortField(PathUtils.appContext!, this.currentSortField)
    Preferences.saveSortAsc(PathUtils.appContext!, this.currentSortAsc)
    this.allStreams.sort((a, b) => {
      let cmp = 0
      switch (field) {
        case SortField.NAME:
          cmp = (a.title ?? '').localeCompare(b.title ?? '')
          break
        case SortField.DATETIME:
          cmp = Number(a.date) - Number(b.date)
          break
        case SortField.TIME:
          cmp = (a.time ?? 0) - (b.time ?? 0)
          break
      }
      return this.currentSortAsc ? cmp : -cmp
    })
    this.applySearch()
  }

  private handlePinyinSortChange(value: boolean) {
    this.pinyinSort = value
    Preferences.savePinyinSort(PathUtils.appContext!, this.pinyinSort)
    if (this.currentSortField === SortField.NAME) {
      this.allStreams = ToolsUtil.sortBy(PathUtils.appContext!, this.allStreams, undefined,
        SortField.NAME, this.currentSortAsc, this.pinyinSort)
      this.applySearch()
    }
  }
}
