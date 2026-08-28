import NavigationAddress, { IPTVChannelParams } from '../../common/NavigationCommon'
import {
  ButtonFancyModifier,
  DefaultDialogShadow,
  ImageFancyModifier,
  MenuFancyModifier,
  SymbolGlyphFancyModifier
} from '../../common/AttributeModifierConfig'
import { IPTVSource } from '../../interfaces/IPTVInterface'
import { IPTVSourceDialog } from '../../component/Dialog/IPTVSourceDialog'
import { InfoConfirmDialog } from '../../component/Dialog/InfoConfirmDialog'
import Preferences from '../../database/Preferences'
import IPTVUtil from '../../utils/IPTVUtil'
import { PathUtils } from '../../utils/PathUtils'
import TimeUtil from '../../utils/TimeUtil'
import ToolsUtil from '../../utils/ToolsUtil'
import { SafeHeight, Setting } from '../../utils/ObservedUtil'
import { LengthMetrics, SymbolGlyphModifier } from '@kit.ArkUI'
import { hdsMaterial, HdsNavDestination, HideMode, ScrollEffectType } from '@kit.UIDesignKit'

@ComponentV2
export struct IPTVSourcePage {
  @Consumer('pathStack') pathStack: NavPathStack = new NavPathStack()
  @Local sources: IPTVSource[] = []
  @Local refreshingIds: Set<string> = new Set()
  addDialogController: CustomDialogController = new CustomDialogController({
    builder: IPTVSourceDialog({
      onSaved: (source: IPTVSource) => this.upsertSource(source)
    }),
    cornerRadius: 20,
    shadow: DefaultDialogShadow,
    cancel: () => IPTVUtil.editingSource = undefined
  })
  private pendingDelete: IPTVSource | undefined = undefined
  deleteDialogController: CustomDialogController = new CustomDialogController({
    builder: InfoConfirmDialog({
      textInfo: '确定删除该 IPTV 节目源及频道缓存吗？',
      confirm: () => {
        if (this.pendingDelete) {
          this.sources = this.sources.filter(item => item.id !== this.pendingDelete!.id)
          Preferences.saveIPTVSources(PathUtils.appContext!, this.sources)
          this.pendingDelete = undefined
        }
      }
    }),
    cornerRadius: 20,
    shadow: DefaultDialogShadow
  })
  private listScroller: Scroller = new Scroller()

  aboutToAppear(): void {
    this.reload()
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
      .onClick(() => {
        IPTVUtil.editingSource = undefined
        this.addDialogController.open()
      })
      .margin({ right: 10 })
    }.justifyContent(FlexAlign.End).width('100%')
  }

  @Builder
  SourceMenu(source: IPTVSource) {
    Menu() {
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.rename')),
        content: '编辑'
      }).onClick(() => {
        IPTVUtil.editingSource = source
        this.addDialogController.open()
      })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.arrow_clockwise')),
        content: '刷新'
      }).onClick(async () => await this.refresh(source))
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.trash_fill')),
        content: '删除'
      }).onClick(() => {
        this.pendingDelete = source
        this.deleteDialogController.open()
      })
    }.attributeModifier(new MenuFancyModifier())
  }

  build() {
    HdsNavDestination() {
      if (this.sources.length === 0) {
        Column({ space: 10 }) {
          Text('暂无 IPTV 节目源')
            .fontSize(18)
            .fontColor($r('app.color.text_color'))
            .opacity(0.65)
          Text('点击右上角 + 添加 M3U/M3U8 或 TXT 节目源')
            .fontSize(14)
            .fontColor($r('app.color.text_color'))
            .opacity(0.45)
            .textAlign(TextAlign.Center)
        }
        .padding(24)
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        List({ scroller: this.listScroller, space: 12 }) {
          Repeat<IPTVSource>(this.sources)
            .each((item: RepeatItem<IPTVSource>) => {
              ListItem() {
                Row({ space: 14 }) {
                  Image($r('app.media.sweet_video_alt')).attributeModifier(new ImageFancyModifier(12, 46, 46))

                  Column({ space: 5 }) {
                    Row() {
                      Text(item.item.name)
                        .fontSize(17)
                        .fontWeight(FontWeight.Medium)
                        .fontColor($r('app.color.text_color'))
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .layoutWeight(1)
                      Text(item.item.sourceType === 'url' ? 'URL' : '本地')
                        .fontSize(11)
                        .fontColor($r('app.color.text_color'))
                        .padding({
                          left: 7,
                          right: 7,
                          top: 3,
                          bottom: 3
                        })
                        .backgroundColor($r('sys.color.button_background_color_transparent'))
                        .borderRadius(8)
                    }.width('100%')

                    Text(`${item.item.channelCount} 个频道  ·  ${item.item.groupCount} 个分组`)
                      .fontSize(13)
                      .fontColor($r('app.color.text_color'))
                      .opacity(0.65)
                    Row() {
                      Text(this.statusText(item.item))
                        .fontSize(12)
                        .fontColor(item.item.lastRefreshStatus === 'failed' ? '#C62828' :
                          $r('app.color.text_color'))
                        .opacity(item.item.lastRefreshStatus === 'failed' ? 1 : 0.45)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .layoutWeight(1)
                      if (this.refreshingIds.has(item.item.id)) {
                        LoadingProgress().width(18).height(18).color($r('app.color.main_color'))
                      } else {
                        SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(17).opacity(0.45)
                      }
                    }.width('100%')
                  }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                }
                .padding(16)
                .width('100%')
                .backgroundColor($r('app.color.list_item_background'))
                .borderRadius(16)
              }
              .onClick(() => {
                if (!this.refreshingIds.has(item.item.id)) {
                  this.pathStack.pushPathByName(NavigationAddress.IPTV_CHANNEL_PAGE,
                    new IPTVChannelParams(item.item.id), true)
                }
              })
              .clickEffect({ level: ClickEffectLevel.HEAVY, scale: 0.9 })
              .bindContextMenu(this.SourceMenu(item.item), ResponseType.LongPress,
                {
                  backgroundBlurStyle: BlurStyle.COMPONENT_ULTRA_THIN,
                  hapticFeedbackMode: HapticFeedbackMode.ENABLED
                })
              .bindContextMenu(this.SourceMenu(item.item), ResponseType.RightClick,
                { backgroundBlurStyle: BlurStyle.COMPONENT_ULTRA_THIN })
            })
            .key((item: IPTVSource) => `${item.id}_${item.updatedTime}_${item.lastRefreshStatus}`)
        }
        .padding({ left: 16, right: 16 })
        .contentEndOffset(SafeHeight.bottomSafeHeight)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .width('100%')
        .height('100%')
        .clip(false)
      }
    }
    .titleBar({
      avoidLayoutSafeArea: true,
      enableComponentSafeArea: true,
      padding: { start: LengthMetrics.vp(5), end: LengthMetrics.vp(5) },
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
      content: { title: { mainTitle: 'IPTV' }, stackBuilder: (): void => this.NavigationMenus() }
    })
    .backgroundColor($r('app.color.start_window_background'))
    .backgroundImage(Setting.backgroundDropBlur > 0 && Setting.backgroundBlurImageSrc.length > 0 ?
      Setting.backgroundBlurImageSrc : Setting.backgroundImageSrc, ImageRepeat.NoRepeat)
    .backgroundImageSize(ImageSize.Cover)
    .backgroundImagePosition(Alignment.Center)
    .bindToScrollable([this.listScroller])
    .dynamicHideTitleBar({
      hideTitleArea: true,
      hideBottomBuilder: true,
      hideStatusBar: false,
      mode: HideMode.SCROLL_UP
    })
    .onShown(() => this.reload())
  }

  private reload(): void {
    this.sources = Preferences.getIPTVSources(PathUtils.appContext!)
  }

  private upsertSource(source: IPTVSource): void {
    const sources = Preferences.getIPTVSources(PathUtils.appContext!)
    const index = sources.findIndex(item => item.id === source.id)
    if (index >= 0) {
      sources[index] = source
    } else {
      sources.push(source)
    }
    Preferences.saveIPTVSources(PathUtils.appContext!, sources)
    this.sources = [...sources]
  }

  private async refresh(source: IPTVSource): Promise<void> {
    if (this.refreshingIds.has(source.id)) {
      return
    }
    const ids = new Set(this.refreshingIds)
    ids.add(source.id)
    this.refreshingIds = ids
    try {
      const refreshed = await IPTVUtil.refreshSource(source)
      this.upsertSource(refreshed)
      ToolsUtil.showToast(`刷新成功：${refreshed.channelCount} 个频道`)
    } catch (error) {
      const sources = Preferences.getIPTVSources(PathUtils.appContext!)
      const target = sources.find(item => item.id === source.id)
      if (target) {
        target.lastRefreshStatus = 'failed'
        target.lastRefreshTime = Date.now()
        target.lastError = error instanceof Error ? error.message : String(error)
        Preferences.saveIPTVSources(PathUtils.appContext!, sources)
        this.sources = [...sources]
      }
      ToolsUtil.showToast(`刷新失败：${error instanceof Error ? error.message : String(error)}`)
    } finally {
      const latestIds = new Set(this.refreshingIds)
      latestIds.delete(source.id)
      this.refreshingIds = latestIds
    }
  }

  private statusText(source: IPTVSource): string {
    if (source.lastRefreshStatus === 'failed') {
      return source.lastError || '上次刷新失败'
    }
    if (!source.lastRefreshTime) {
      return '尚未刷新'
    }
    return `更新于 ${TimeUtil.formatDateTime(source.lastRefreshTime)}`
  }
}
