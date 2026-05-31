import { salmonLogger } from 'salmonlogger'
import { ImageFancyModifier, MenuFancyModifier } from '../../common/AttributeModifierConfig'
import Preferences from '../../database/Preferences'
import { PrivacySpaceErrorListDataSource } from '../../utils/DataUtil'
import { Privacy, SafeHeight, Setting } from '../../utils/ObservedUtil'
import { PathUtils } from '../../utils/PathUtils'
import SelectFileUtil from '../../utils/SelectFileUtil'
import { HdsNavDestination, HideMode, ScrollEffectType } from '@kit.UIDesignKit'
import { LengthMetrics, SymbolGlyphModifier } from '@kit.ArkUI'
import { fileIo, fileUri } from '@kit.CoreFileKit'

const TAG = 'PrivacySpaceErrorList'

@ComponentV2
export struct PrivacySpaceErrorList {
  @Local errorListDataSource: PrivacySpaceErrorListDataSource = new PrivacySpaceErrorListDataSource([])
  @Local videoList: string[] = []
  @Consumer('pathStack') pathStack: NavPathStack = new NavPathStack()
  private listScroller: Scroller = new Scroller()

  async aboutToAppear(): Promise<void> {
    const videoMetaDataEncryption = Preferences.getVideoMetaDataEncryption(PathUtils.appContext!)
    const videoFromSandbox = await fileIo.listFile(PathUtils.videoPath)?.catch(() => {
      salmonLogger.addLog(TAG, 'get video fail', true)
    })
    // 确保 videoFromSandbox 是一个数组（如果出错则设为空数组）
    const videoFromSandboxArray = Array.isArray(videoFromSandbox) ? videoFromSandbox : []
    // 从 videoMetaDataEncryption 中提取所有 date 字段的值
    const existingDatesSet: Set<string> = new Set(videoMetaDataEncryption.map(item => item.date))
    // 找出在 videoFromSandboxArray 中存在，但在 existingDates 中不存在的元素
    this.videoList = videoFromSandboxArray.filter((item: string) =>
    !existingDatesSet.has(item)
    )
    this.errorListDataSource = new PrivacySpaceErrorListDataSource(this.videoList)
  }

  async delItem(date: string) {
    this.errorListDataSource.deleteData(this.videoList.findIndex(i => i === date))
    await SelectFileUtil.deletePrivacyVideo(date, date, Preferences.getVideoMetaDataEncryption(PathUtils.appContext!))
  }

  @Builder
  MenuBuilder(item: string) {
    Menu() {
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.trash_fill')), content: $r('app.string.delete')
      })
        .onClick(async () => {
          await this.delItem(item)
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.arrow_right_folder_circle')),
        content: '导出'
      })
        .onClick(async () => {
          await SelectFileUtil.exportFile(fileUri.getUriFromPath(PathUtils.videoPath + item), item, '',
            PathUtils.appContext!)
        })
    }
    .attributeModifier(new MenuFancyModifier())
  }

  @Builder
  VideoItemBuilder(errorVideo: string) {
    Row() {
      Image(fileUri.getUriFromPath(PathUtils.coverPath + errorVideo))
        .attributeModifier(new ImageFancyModifier(16, 80, 120))
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
      .padding({ left: 15, right: 15 })
      .layoutWeight(1)
    }
    .backgroundColor($r('app.color.start_window_background'))
    .justifyContent(FlexAlign.Center)
    .width('100%')
  }

  build() {
    HdsNavDestination() {
      Column() {
        if (this.videoList.length === 0) {
          Text('没有异常，看起来一点 bug 也没有捏 (^人^)').textAlign(TextAlign.Center)
            .align(Alignment.Center)
            .width('90%').height('100%')
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
          .padding({ left: 20, right: 20 })
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
      enableComponentSafeArea: true, // 将标题栏设置为组件级安全区，内容区可避让标题栏
      padding: {
        start: LengthMetrics.vp(5),
        end: LengthMetrics.vp(5)
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
      content: {
        title: {
          mainTitle: '隐私空间异常数据',
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
    .blur(Privacy.isPrivacyBackground ? 1000 : 0)
    .dynamicHideTitleBar({
      hideTitleArea: true,
      hideBottomBuilder: true,
      hideStatusBar: false,
      mode: HideMode.SCROLL_UP_TO
    })
    .bindToScrollable([this.listScroller]) // 绑定导航组件和可滚动容器组件
    .hideBackButton(false)
  }
}