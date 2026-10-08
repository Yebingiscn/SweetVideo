import { SettingsClickItem } from '../../component/SettingComponent/SettingsClickItem'
import { SettingsSliderItem } from '../../component/SettingComponent/SettingsSliderItem'
import { SettingsToggleItem } from '../../component/SettingComponent/SettingsToggleItem'
import { SettingsMenuItem } from '../../component/SettingComponent/SettingsMenuItem'
import Preferences from '../../database/Preferences'
import { SafeHeight, Setting } from '../../utils/ObservedUtil'
import { PathUtils } from '../../utils/PathUtils'
import SubtitleStyleUtil from '../../utils/SubtitleStyleUtil'
import ToolsUtil from '../../utils/ToolsUtil'
import { LengthMetrics } from '@kit.ArkUI'
import { hdsMaterial, HdsNavDestination, ScrollEffectType } from '@kit.UIDesignKit'
import { SubtitlePreferredLanguage } from '../../common/enum/SubtitleLanguage'
import { SuppressWarnings, SuppressWarningsType } from '@kit.BasicServicesKit'

const SUBTITLE_PREVIEW_HEIGHT: number = 220

interface SubtitleColorOption {
  name: string
  value: string
}

@ComponentV2
export struct SubtitleSettingPage {
  private listScroller: Scroller = new Scroller()
  private subtitleLanguages: ResourceStr[] = [$r('app.string.lang_simplified_chinese'), $r('app.string.lang_traditional_chinese'), $r('app.string.lang_english')]
  private textColors: SubtitleColorOption[] = [
    { name: ToolsUtil.getStringResource($r('app.string.color_warm_white').id), value: '#F0F0F0' },
    { name: ToolsUtil.getStringResource($r('app.string.color_pure_white').id), value: '#FFFFFF' },
    { name: ToolsUtil.getStringResource($r('app.string.color_warm_yellow').id), value: '#FFD966' },
    { name: ToolsUtil.getStringResource($r('app.string.color_cyan').id), value: '#66E0FF' },
    { name: ToolsUtil.getStringResource($r('app.string.color_light_green').id), value: '#8FE388' },
    { name: ToolsUtil.getStringResource($r('app.string.color_pink').id), value: '#FF9EC4' }
  ]
  private effectColors: SubtitleColorOption[] = [
    { name: ToolsUtil.getStringResource($r('app.string.color_black').id), value: '#000000' },
    { name: ToolsUtil.getStringResource($r('app.string.color_dark_gray').id), value: '#303030' },
    { name: ToolsUtil.getStringResource($r('app.string.color_white').id), value: '#FFFFFF' },
    { name: ToolsUtil.getStringResource($r('app.string.color_dark_blue').id), value: '#10243D' },
    { name: ToolsUtil.getStringResource($r('app.string.color_dark_red').id), value: '#44151B' }
  ]

  @SuppressWarnings({ rules: [SuppressWarningsType.SYSCAP] })
  build() {
    HdsNavDestination() {
      List({ scroller: this.listScroller, space: 6 }) {
        ListItem() {
          this.PreviewCard()
        }

        ListItem() {
          SettingsMenuItem({
            symbol: $r('sys.symbol.textformat_size_square'),
            message: ToolsUtil.getStringResource($r('app.string.auto_select_subtitle_language').id),
            list: this.subtitleLanguages,
            selected: Setting.subtitlePreferredLanguage,
            onChange: (index: number) => {
              Setting.subtitlePreferredLanguage = index as SubtitlePreferredLanguage
              Preferences.saveSubtitlePreferredLanguage(PathUtils.appContext!, Setting.subtitlePreferredLanguage)
            }
          })
        }

        ListItem() {
          SettingsSliderItem({
            symbol: $r('sys.symbol.title_size'),
            message: ToolsUtil.getStringResource($r('app.string.font_size').id),
            selected: Number(Setting.subtitleSize),
            min: 14,
            max: 48,
            valueSuffix: ToolsUtil.getStringResource($r('app.string.unit_point').id),
            onChange: (value: number) => {
              Setting.subtitleSize = Math.round(value).toString()
            },
            onChangeComplete: (value: number) => {
              Setting.subtitleSize = Math.round(value).toString()
              Preferences.saveSubtitleSize(PathUtils.appContext!, Setting.subtitleSize)
              SubtitleStyleUtil.applyToActiveMpv()
            }
          })
        }

        ListItem() {
          SettingsSliderItem({
            symbol: $r('sys.symbol.celiakeyboard_menu_icon_size'),
            message: ToolsUtil.getStringResource($r('app.string.vertical_position').id),
            selected: Setting.subtitlePosition,
            min: 5,
            max: 100,
            valueSuffix: '%',
            onChange: (value: number) => {
              Setting.subtitlePosition = Math.round(value)
            },
            onChangeComplete: (value: number) => {
              Setting.subtitlePosition = Math.round(value)
              Preferences.saveSubtitlePosition(PathUtils.appContext!, Setting.subtitlePosition)
              SubtitleStyleUtil.applyToActiveMpv()
            }
          })
        }

        ListItem() {
          SettingsToggleItem({
            symbol: $r('sys.symbol.bold'),
            message: ToolsUtil.getStringResource($r('app.string.bold').id),
            enable: Setting.subtitleBold,
            onChange: (checked: boolean) => {
              Setting.subtitleBold = checked
              Preferences.saveSubtitleBold(PathUtils.appContext!, checked)
              SubtitleStyleUtil.applyToActiveMpv()
            }
          })
        }

        ListItem() {
          SettingsToggleItem({
            symbol: $r('sys.symbol.italic'),
            message: ToolsUtil.getStringResource($r('app.string.italic').id),
            enable: Setting.subtitleItalic,
            onChange: (checked: boolean) => {
              Setting.subtitleItalic = checked
              Preferences.saveSubtitleItalic(PathUtils.appContext!, checked)
              SubtitleStyleUtil.applyToActiveMpv()
            }
          })
        }

        ListItem() {
          this.ColorPalette(this.textColors, 0)
        }

        ListItem() {
          SettingsSliderItem({
            symbol: $r('sys.symbol.rectangle_portrait_filled_on_rectangle_portrait'),
            message: ToolsUtil.getStringResource($r('app.string.outline_width').id),
            selected: Setting.subtitleBorderSize,
            min: 0,
            max: 6,
            valueSuffix: ' px',
            onChange: (value: number) => {
              Setting.subtitleBorderSize = Math.round(value)
            },
            onChangeComplete: (value: number) => {
              Setting.subtitleBorderSize = Math.round(value)
              Preferences.saveSubtitleBorderSize(PathUtils.appContext!, Setting.subtitleBorderSize)
              SubtitleStyleUtil.applyToActiveMpv()
            }
          })
        }

        ListItem() {
          this.ColorPalette(this.effectColors, 1)
        }

        ListItem() {
          SettingsToggleItem({
            symbol: $r('sys.symbol.wand_and_stars'),
            message: ToolsUtil.getStringResource($r('app.string.subtitle_shadow').id),
            enable: Setting.subtitleShadowEnabled,
            onChange: (checked: boolean) => {
              Setting.subtitleShadowEnabled = checked
              Preferences.saveSubtitleShadowEnabled(PathUtils.appContext!, checked)
              SubtitleStyleUtil.applyToActiveMpv()
            }
          })
        }

        if (Setting.subtitleShadowEnabled) {
          ListItem() {
            SettingsSliderItem({
              symbol: $r('sys.symbol.shadow'),
              message: ToolsUtil.getStringResource($r('app.string.shadow_strength').id),
              selected: Setting.subtitleShadowSize,
              min: 1,
              max: 12,
              valueSuffix: ' px',
              onChange: (value: number) => {
                Setting.subtitleShadowSize = Math.round(value)
              },
              onChangeComplete: (value: number) => {
                Setting.subtitleShadowSize = Math.round(value)
                Preferences.saveSubtitleShadowSize(PathUtils.appContext!, Setting.subtitleShadowSize)
                SubtitleStyleUtil.applyToActiveMpv()
              }
            })
          }

          ListItem() {
            this.ColorPalette(this.effectColors, 2)
          }
        }

        ListItem() {
          SettingsSliderItem({
            symbol: $r('sys.symbol.rectangle_lefthalf_inset_filled'),
            message: ToolsUtil.getStringResource($r('app.string.background_opacity').id),
            selected: Setting.subtitleBackgroundOpacity,
            min: 0,
            max: 80,
            valueSuffix: '%',
            zeroText: ToolsUtil.getStringResource($r('app.string.off').id),
            onChange: (value: number) => {
              Setting.subtitleBackgroundOpacity = Math.round(value)
            },
            onChangeComplete: (value: number) => {
              Setting.subtitleBackgroundOpacity = Math.round(value)
              Preferences.saveSubtitleBackgroundOpacity(PathUtils.appContext!, Setting.subtitleBackgroundOpacity)
              SubtitleStyleUtil.applyToActiveMpv()
            }
          })
        }

        ListItem() {
          SettingsClickItem({
            symbol: $r('sys.symbol.arrow_counterclockwise'),
            message: ToolsUtil.getStringResource($r('app.string.reset_subtitle_style').id),
            showArrow: false,
            onPress: () => {
              SubtitleStyleUtil.reset()
              ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.subtitle_style_reset').id))
            }
          })
        }
      }
      .clip(false)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true }) // 滚动边缘效果
      .chainAnimation(true)
      .borderRadius(16)
      .align(Alignment.Top)
      .margin({ left: 16, right: 16 })
      .scrollBar(BarState.Off)
      .height('100%')
      .width('95%')
      .layoutWeight(1)
      .contentEndOffset(SafeHeight.bottomSafeHeight + 16)
    }
    .hideToolBar(true)
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
            backgroundColor: $r('sys.color.ohos_id_color_background')
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
            backgroundColor: $r('sys.color.ohos_id_color_background_transparent')
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
          mainTitle: $r('app.string.settings_subtitle_style'),
        }
      }
    })
    .backgroundColor($r('app.color.start_window_background'))
    .backgroundImage(
      Setting.backgroundDropBlur > 0 && Setting.backgroundBlurImageSrc.length > 0 ? Setting.backgroundBlurImageSrc :
        Setting.backgroundImageSrc, ImageRepeat.NoRepeat)
    .backgroundImageSize(ImageSize.Cover)
    .backgroundImagePosition(Alignment.Center)
    .hideBackButton(false)
    .bindToScrollable([this.listScroller])
  }

  @Builder
  private PreviewCard() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column({ space: 6 }) {
        SymbolGlyph($r('sys.symbol.play_fill'))
          .fontSize(42)
          .fontColor(['#55FFFFFF'])
        Text($r('app.string.subtitle_preview'))
          .fontSize(13)
          .fontColor($r('sys.color.node_graph_toolbar_background_color'))
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .margin({ top: 45 })

      Stack({ alignContent: Alignment.Bottom }) {
        Text($r('app.string.subtitle_slogan'))
          .fontSize(Number(Setting.subtitleSize))
          .fontColor(Setting.subtitleColor)
          .fontWeight(Setting.subtitleBold ? FontWeight.Bold : FontWeight.Normal)
          .fontStyle(Setting.subtitleItalic ? FontStyle.Italic : FontStyle.Normal)
          .textAlign(TextAlign.Center)
          .textShadow(this.getPreviewShadow())
          .backgroundColor(SubtitleStyleUtil.getAppBackgroundColor())
          .borderRadius(4)
          .padding({
            left: 8,
            right: 8,
            top: 2,
            bottom: 2
          })
          .width('90%')
          .margin({
            bottom: SubtitleStyleUtil.getSubtitleBottomMargin(SUBTITLE_PREVIEW_HEIGHT,
              Setting.subtitlePosition)
          })
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height(SUBTITLE_PREVIEW_HEIGHT)
    .borderRadius(20)
    .clip(true)
    .backgroundColor('#202530')
    .margin({ top: 8, bottom: 10 })
  }

  @Builder
  private ColorPalette(colors: SubtitleColorOption[], target: number) {
    Column({ space: 10 }) {
      Row() {
        Text(target === 0 ? $r('app.string.pick_text_color') : (target === 1 ? $r('app.string.pick_outline_color') : $r('app.string.pick_shadow_color')))
          .fontSize(15)
          .fontColor($r('sys.color.font_primary'))
          .layoutWeight(1)
        Text(this.getColorName(colors, this.getSelectedColor(target)))
          .fontSize(13)
          .fontColor($r('sys.color.font_secondary'))
      }
      .width('100%')

      Row({ space: 14 }) {
        ForEach(colors, (item: SubtitleColorOption) => {
          Stack() {
            Circle()
              .width(42)
              .height(42)
              .fill(item.value)
              .stroke($r('sys.color.comp_divider'))
              .strokeWidth(1)
            if (this.getSelectedColor(target) === item.value) {
              Circle()
                .width(48)
                .height(48)
                .fill(Color.Transparent)
                .stroke($r('app.color.main_color'))
                .strokeWidth(3)

            }
          }
          .width(48)
          .height(48)
          .onClick(() => {
            this.selectColor(target, item.value)
          })
        }, (item: SubtitleColorOption) => item.value)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
    }
    .width('100%')
    .padding(16)
    .borderRadius(16)
    .backgroundColor($r('app.color.start_window_background_blur'))
  }

  private getColorName(colors: SubtitleColorOption[], selected: string): string {
    return colors.find((item: SubtitleColorOption) => item.value === selected)?.name ?? selected
  }

  private getPreviewShadow(): ShadowOptions[] {
    const shadows: ShadowOptions[] = []
    if (Setting.subtitleBorderSize > 0) {
      shadows.push({
        color: Setting.subtitleBorderColor,
        type: ShadowType.BLUR,
        radius: Setting.subtitleBorderSize
      })
    }
    if (Setting.subtitleShadowEnabled && Setting.subtitleShadowSize > 0) {
      shadows.push({
        color: Setting.subtitleShadowColor,
        type: ShadowType.BLUR,
        radius: Setting.subtitleShadowSize,
        offsetX: 2,
        offsetY: 2
      })
    }
    return shadows
  }

  private getSelectedColor(target: number): string {
    if (target === 0) {
      return Setting.subtitleColor
    } else if (target === 1) {
      return Setting.subtitleBorderColor
    } else {
      return Setting.subtitleShadowColor
    }
  }

  private selectColor(target: number, value: string): void {
    if (target === 0) {
      Setting.subtitleColor = value
      Preferences.saveSubtitleColor(PathUtils.appContext!, value)
    } else if (target === 1) {
      Setting.subtitleBorderColor = value
      Preferences.saveSubtitleBorderColor(PathUtils.appContext!, value)
    } else {
      Setting.subtitleShadowColor = value
      Preferences.saveSubtitleShadowColor(PathUtils.appContext!, value)
    }
    SubtitleStyleUtil.applyToActiveMpv()
  }
}
