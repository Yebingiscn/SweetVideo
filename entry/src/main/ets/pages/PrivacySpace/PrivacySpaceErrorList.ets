import MediaLibraryService from '../../utils/MediaLibraryService'
import { salmonLogger } from 'salmonlogger'
import { ImageFancyModifier, MenuFancyModifier } from '../../common/AttributeModifierConfig'
import Preferences from '../../database/Preferences'
import { PrivacySpaceErrorListDataSource } from '../../utils/DataUtil'
import { Privacy, Setting } from '../../utils/ObservedUtil'
import { PathUtils } from '../../utils/PathUtils'
import SelectFileUtil from '../../utils/SelectFileUtil'
import { hdsMaterial, HdsNavDestination, HideMode, ScrollEffectType } from '@kit.UIDesignKit'
import { LengthMetrics, SymbolGlyphModifier } from '@kit.ArkUI'
import { fileIo } from '@kit.CoreFileKit'
import { CoverLayoutMode } from '../../common/enum/DisplayMode'
import ShareUtil from '../../utils/ShareUtil'
import { SuppressWarnings, SuppressWarningsType } from '@kit.BasicServicesKit'
import PrivacyRecoveryUtil from '../../utils/PrivacyRecoveryUtil'
import ToolsUtil from '../../utils/ToolsUtil'
import { ImportProgressBuilder } from '../../component/VideoItemComponent/ImportProgressBuilder'

const TAG = 'PrivacySpaceErrorList'

@ComponentV2
export struct PrivacySpaceErrorList {
  @Local errorListDataSource: PrivacySpaceErrorListDataSource = new PrivacySpaceErrorListDataSource([])
  @Local videoList: string[] = []
  @Consumer('pathStack') pathStack: NavPathStack = new NavPathStack()
  private listScroller: Scroller = new Scroller()
  @Local isScanning: boolean = false
  @Local deletionInProgress: boolean = false
  @Local isCancelling: boolean = false
  @Local processedItems: number = 0
  @Local totalItems: number = 0
  @Local currentFileName: string = ''
  @Local failedCount: number = 0
  private pageActive: boolean = false
  private scanBusy: boolean = false
  private deleteBusy: boolean = false
  private scanGeneration: number = 0
  private refreshGeneration: number = 0

  async aboutToAppear(): Promise<void> {
    this.pageActive = true
    await this.refreshErrorList()
  }

  aboutToDisappear(): void {
    this.pageActive = false
    this.scanGeneration++
    this.refreshGeneration++
  }

  private async refreshErrorList(): Promise<boolean> {
    const generation = ++this.refreshGeneration
    let files: string[]
    try {
      files = await fileIo.listFile(PathUtils.videoPath)
      if (!this.pageActive || generation !== this.refreshGeneration) return false
      // 数据库读取失败不能当成空列表，否则会把所有正常文件误判成异常。
      const records = Preferences.getVideoMetaDataEncryption(PathUtils.appContext!, true)
      const existingDatesSet: Set<string> = new Set(records.map(item => item.date))
      this.videoList = files.filter((item: string) => !existingDatesSet.has(item))
      this.errorListDataSource = new PrivacySpaceErrorListDataSource(this.videoList)
    } catch (_) {
      salmonLogger.addLog(TAG, '读取异常媒体列表失败', true)
      if (this.pageActive && generation === this.refreshGeneration) {
        ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.privacy_recovery_failed').id))
      }
      return false
    }
    return true
  }

  private async scanToPrivacySpace(): Promise<void> {
    if (this.scanBusy || this.deleteBusy || !this.pageActive) return
    this.scanBusy = true
    this.isScanning = true
    this.isCancelling = false
    this.processedItems = 0
    this.totalItems = 0
    this.failedCount = 0
    this.currentFileName = ''
    const generation = ++this.scanGeneration
    const isCancelled = (): boolean => !this.pageActive || generation !== this.scanGeneration
    let recoveredCount = 0
    let completed = false
    try {
      if (!await this.refreshErrorList() || isCancelled()) return
      const candidates = this.videoList.slice()
      this.totalItems = candidates.length
      for (const date of candidates) {
        if (isCancelled()) break
        this.currentFileName = date
        const result = await PrivacyRecoveryUtil.recover(date, isCancelled)
        if (result === 'recovered') recoveredCount++
        if (result === 'cancelled' || !this.pageActive) break
        this.processedItems++
        if (result === 'failed') this.failedCount++
        if (result === 'recovered' || result === 'skipped') {
          this.videoList = this.videoList.filter(item => item !== date)
          this.errorListDataSource = new PrivacySpaceErrorListDataSource(this.videoList)
        }
      }
      completed = true
    } catch (_) {
      salmonLogger.addLog(TAG, '扫描恢复异常，保留原文件', true)
      if (this.pageActive) {
        ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.privacy_recovery_failed').id))
      }
    } finally {
      if (this.pageActive) {
        await this.refreshErrorList()
        if (completed && this.pageActive) {
          ToolsUtil.showToast(ToolsUtil.getStringResourceArgs2(
            (isCancelled() ? $r('app.string.privacy_recovery_cancelled') :
              $r('app.string.privacy_recovery_result')).id, recoveredCount, this.failedCount))
        }
      }
      this.scanBusy = false
      if (this.pageActive) {
        this.isScanning = false
        this.isCancelling = false
      }
    }
  }

  async delItem(date: string) {
    if (this.scanBusy || this.deleteBusy) return
    this.deleteBusy = true
    this.deletionInProgress = true
    try {
      await MediaLibraryService.deletePrivacyVideo(date, date,
        Preferences.getVideoMetaDataEncryption(PathUtils.appContext!, true))
      await this.refreshErrorList()
    } catch (_) {
      salmonLogger.addLog(TAG, '异常媒体删除失败', true)
      if (this.pageActive) {
        ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.delete_failed').id))
      }
    } finally {
      this.deleteBusy = false
      if (this.pageActive) this.deletionInProgress = false
    }
  }

  @Builder
  MenuBuilder(item: string) {
    Menu() {
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.trash_fill')), content: $r('app.string.delete')
      })
        .enabled(!this.isScanning && !this.deletionInProgress)
        .onClick(async () => {
          await this.delItem(item)
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.arrow_right_folder_circle')),
        content: $r('app.string.export')
      })
        .onClick(async () => {
          await SelectFileUtil.exportFile(PathUtils.videoUri(item), item, '',
            PathUtils.appContext!)
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.share')),
        content: $r('app.string.share')
      })
        .onClick(async () => {
          await ShareUtil.shareVideo(PathUtils.videoUri(item), item)
        })
    }
    .attributeModifier(new MenuFancyModifier())
  }

  @Builder
  RecoveryBuilder() {
    Column({ space: 12 }) {
      Text($r('app.string.privacy_recovery_hint'))
        .fontSize(12)
        .fontColor($r('app.color.text_color'))
        .width('100%')
      if (this.isScanning) {
        ImportProgressBuilder({
          processedItems: this.processedItems,
          totalItems: this.totalItems,
          currentFileName: this.currentFileName,
          currentStage: 'extracting',
          failedCount: this.failedCount
        })
        Button($r('app.string.cancel'))
          .enabled(!this.isCancelling)
          .onClick(() => {
            this.isCancelling = true
            this.scanGeneration++
          })
      } else {
        Button($r('app.string.privacy_recovery_scan'))
          .enabled(this.videoList.length > 0 && !this.deletionInProgress)
          .backgroundColor($r('app.color.main_color'))
          .onClick(async () => {
            await this.scanToPrivacySpace()
          })
      }
    }
    .padding(16)
    .width('100%')
  }

  @Builder
  VideoItemBuilder(errorVideo: string) {
    Row() {
      Image(PathUtils.coverUri(errorVideo))
        .attributeModifier(new ImageFancyModifier(12, Setting.coverLayout === CoverLayoutMode.VERTICAL_PLATE ? 85 : 110,
          Setting.coverLayout === CoverLayoutMode.VERTICAL_PLATE ? 110 : 85))
      Column() {
        Text(errorVideo)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .maxLines(4)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .margin({ left: 5 })
          .wordBreak(WordBreak.BREAK_ALL)
      }.alignItems(HorizontalAlign.Start)
      .padding({ left: 16, right: 16 })
      .layoutWeight(1)
    }
    .backgroundColor($r('app.color.start_window_background'))
    .justifyContent(FlexAlign.Center)
    .width('100%')
  }

  @SuppressWarnings({ rules: [SuppressWarningsType.SYSCAP] })
  build() {
    HdsNavDestination() {
      Column() {
        this.RecoveryBuilder()
        if (this.videoList.length === 0) {
          Text($r('app.string.no_error_data')).textAlign(TextAlign.Center)
            .align(Alignment.Center)
            .width('90%').layoutWeight(1)
        } else {
          List({ scroller: this.listScroller, space: 10 }) {
            Repeat<string>(this.errorListDataSource.data)
              .each((repeatItem: RepeatItem<string>) => {
                ListItem() {
                  this.VideoItemBuilder(repeatItem.item)
                }
                .width('100%')
                .height('auto')
                .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
                .transition(TransitionEffect.OPACITY.animation({ duration: 150, curve: Curve.Sharp }))
                .bindContextMenu(this.MenuBuilder(repeatItem.item), ResponseType.LongPress, {
                  backgroundBlurStyle: BlurStyle.BACKGROUND_ULTRA_THICK,
                  preview: this.VideoItemBuilder(repeatItem.item),
                  previewAnimationOptions: { scale: [1.0, 0.95], hoverScale: [1.0, 1.2] },
                  layoutRegionMargin: {
                    left: 16,
                    right: 16,
                    top: 16,
                    bottom: 4
                  },
                  mask: true,
                  hapticFeedbackMode: HapticFeedbackMode.ENABLED
                })
                .bindContextMenu(this.MenuBuilder(repeatItem.item), ResponseType.RightClick, {
                  backgroundBlurStyle: BlurStyle.BACKGROUND_ULTRA_THICK,
                  preview: this.VideoItemBuilder(repeatItem.item),
                  previewAnimationOptions: { hoverScale: [1.0, 1.2] },
                  layoutRegionMargin: {
                    left: 16,
                    right: 16,
                    top: 16,
                    bottom: 4
                  },
                  mask: true
                })
              })
              .key((item: string, _index: number) => item)
              .virtualScroll()
          }
          .clip(false)
          .layoutWeight(1)
          .padding({ left: 16, right: 16 })
          .width('100%')
          .height('auto')
          .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true }) // 滚动边缘效果
          .chainAnimation(true)
          .scrollBar(BarState.Off)
        }
      }.width('100%')
      .height('100%')
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
      content: {
        title: {
          mainTitle: $r('app.string.privacy_space_error_data'),
        }
      },
    })
    .backgroundColor($r('app.color.start_window_background'))
    .backgroundImage(
      Setting.backgroundDropBlur > 0 && Setting.backgroundBlurImageSrc.length > 0 ? Setting.backgroundBlurImageSrc :
        Setting.backgroundImageSrc, ImageRepeat.NoRepeat)
    .backgroundImageSize(ImageSize.Cover)
    .backgroundImagePosition(Alignment.Center)
    .blur(Privacy.isPrivacyBackground ? 1000 : 0)
    .dynamicHideTitleBar({
      hideTitleArea: true,
      hideBottomBuilder: true,
      hideStatusBar: false,
      mode: HideMode.SCROLL_UP_TO
    })
    .bindToScrollable([this.listScroller]) // 绑定导航组件和可滚动容器组件
    .hideBackButton(false)
    .onHidden(() => {
      this.pageActive = false
      this.scanGeneration++
      this.refreshGeneration++
    })
    .onShown(async () => {
      this.pageActive = true
      this.isScanning = this.scanBusy
      this.isCancelling = this.scanBusy
      this.deletionInProgress = this.deleteBusy
      await this.refreshErrorList()
    })
  }
}
