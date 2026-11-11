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
import lazy { HdsColorPicker } from '@kit.UIDesignKit'
import { hdsMaterial, HdsNavDestination, ScrollEffectType } from '@kit.UIDesignKit'
import { SubtitlePreferredLanguage } from '../../common/enum/SubtitleLanguage'
import { deviceInfo, SuppressWarnings, SuppressWarningsType } from '@kit.BasicServicesKit'
import AICaptionSettings, { AICaptionSettingsValue } from '../../utils/AICaptionSettings'
import { SettingsTitleModifier } from '../../common/AttributeModifierConfig'

const SUBTITLE_PREVIEW_HEIGHT: number = 220

@ComponentV2
export struct SubtitleSettingPage {
  @Local favoriteColors: string[] = ['#FFF0F0F0', '#FFFFFFFF', '#FFFFD966', '#FF66E0FF',
    '#FF8FE388', '#FFFF9EC4', '#FF000000', '#FF303030']
  private listScroller: Scroller = new Scroller()
  private subtitleLanguages: ResourceStr[] =
    [$r('app.string.lang_simplified_chinese'), $r('app.string.lang_traditional_chinese'), $r('app.string.lang_english')]
  private aiSourceLanguages: ResourceStr[] =
    [$r('app.string.ai_subtitle_language_chinese'), $r('app.string.lang_english')]
  private aiTargetLanguages: ResourceStr[] =
    [$r('app.string.ai_subtitle_language_chinese'), $r('app.string.lang_english'),
      $r('app.string.ai_subtitle_language_bilingual')]
  private aiFontSizes: ResourceStr[] =
    [$r('app.string.ai_subtitle_font_small'), $r('app.string.ai_subtitle_font_normal'),
      $r('app.string.ai_subtitle_font_big'), $r('app.string.ai_subtitle_font_large')]
  private aiPanelOpacities: ResourceStr[] = [$r('app.string.ai_subtitle_opacity_transparent'),
    $r('app.string.ai_subtitle_opacity_half'), $r('app.string.ai_subtitle_opacity_opaque')]

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

        this.ColorPalette(0)

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

        this.ColorPalette(1)

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

          this.ColorPalette(2)
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

        if (canIUse('SystemCapability.AI.AICaption')) {
          this.AISubtitleSettings()
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
  private AISubtitleSettings() {
    ListItem() {
      Column({ space: 8 }) {
        Text($r('app.string.ai_subtitle'))
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .width('100%')
        Text($r('app.string.ai_subtitle_settings_hint'))
          .fontSize(12)
          .fontColor($r('sys.color.font_secondary'))
          .width('100%')
      }
      .padding({
        left: 16,
        right: 16,
        top: 20,
        bottom: 8
      })
    }

    ListItem() {
      SettingsMenuItem({
        symbol: $r('sys.symbol.textformat_size_square'),
        message: $r('app.string.ai_subtitle_source_language'),
        list: this.aiSourceLanguages,
        selected: Setting.aiSubtitleSourceLanguage === 'en' ? 1 : 0,
        onChange: (index: number) => {
          Setting.aiSubtitleSourceLanguage = index === 1 ? 'en' : 'zh'
          this.saveAISettings()
        }
      })
    }

    // Select 的选项在组件首次创建时生成，切换源语言时用不同分支重建，避免保留非法选项。
    if (Setting.aiSubtitleSourceLanguage === 'en') {
      this.AITargetLanguageMenu(true)
    } else {
      this.AITargetLanguageMenu(false)
    }

    ListItem() {
      SettingsMenuItem({
        symbol: $r('sys.symbol.title_size'),
        message: $r('app.string.font_size'),
        list: this.aiFontSizes,
        selected: Setting.aiSubtitleFontSize - 1,
        onChange: (index: number) => {
          Setting.aiSubtitleFontSize = index + 1
          this.saveAISettings()
        }
      })
    }

    this.ColorPalette(3)

    ListItem() {
      SettingsMenuItem({
        symbol: $r('sys.symbol.rectangle_lefthalf_inset_filled'),
        message: $r('app.string.ai_subtitle_panel_opacity'),
        list: this.aiPanelOpacities,
        selected: Math.round(AICaptionSettings.getInitialOpacity(Setting.aiSubtitleBackgroundOpacity, '2in1') * 2),
        onChange: (index: number) => {
          Setting.aiSubtitleBackgroundOpacity = index * 50
          this.saveAISettings()
        }
      })
    }

    ListItem() {
      SettingsClickItem({
        symbol: $r('sys.symbol.arrow_counterclockwise'),
        message: $r('app.string.reset_ai_subtitle_settings'),
        showArrow: false,
        onPress: () => {
          this.saveAISettings(AICaptionSettings.defaults())
          ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.ai_subtitle_settings_reset').id))
        }
      })
    }
  }

  @Builder
  private AITargetLanguageMenu(englishSource: boolean) {
    ListItem() {
      SettingsMenuItem({
        symbol: $r('sys.symbol.textformat_size_square'),
        message: $r('app.string.ai_subtitle_target_language'),
        list: englishSource ? this.aiTargetLanguages : [this.aiTargetLanguages[0]],
        selected: englishSource ? Math.max(0, ['zh', 'en', 'zh-en'].indexOf(Setting.aiSubtitleTargetLanguage)) : 0,
        onChange: (index: number) => {
          Setting.aiSubtitleTargetLanguage = englishSource ? (['zh', 'en', 'zh-en'][index] ?? 'zh') : 'zh'
          this.saveAISettings()
        }
      })
    }
  }

  private saveAISettings(value?: AICaptionSettingsValue): void {
    const settings = AICaptionSettings.normalize(value ?? {
      sourceLanguage: Setting.aiSubtitleSourceLanguage,
      targetLanguage: Setting.aiSubtitleTargetLanguage,
      fontSize: Setting.aiSubtitleFontSize,
      fontColor: Setting.aiSubtitleFontColor,
      backgroundOpacity: Setting.aiSubtitleBackgroundOpacity
    })
    Setting.aiSubtitleSourceLanguage = settings.sourceLanguage
    Setting.aiSubtitleTargetLanguage = settings.targetLanguage
    Setting.aiSubtitleFontSize = settings.fontSize
    Setting.aiSubtitleFontColor = settings.fontColor
    Setting.aiSubtitleBackgroundOpacity = settings.backgroundOpacity
    Preferences.saveAISubtitleSettings(PathUtils.appContext!, settings)
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

  private isColorPickerDeviceSupported(): boolean {
    return (deviceInfo.deviceType === 'phone' || deviceInfo.deviceType === 'tablet') &&
      canIUse('SystemCapability.UIDesign.HDSPattern.Standard')
  }

  @Builder
  private ColorPalette(target: number) {
    // 仅在支持取色器的设备上创建条目并触发延迟导入。
    if (this.isColorPickerDeviceSupported()) {
      ListItem() {
        Row({ space: 12 }) {
          Text(this.getColorTitle(target))
            .attributeModifier(new SettingsTitleModifier())
            .layoutWeight(1)
          Text(this.getSelectedColor(target))
            .fontSize(15)
            .fontColor($r('sys.color.font_primary'))
          HdsColorPicker({
            initialColor: this.getSelectedColor(target),
            initialFavoriteColors: this.favoriteColors,
            onColorSelected: (color: string) => {
              this.selectColor(target, color)
            },
            onFavoriteColorsUpdate: (colors: string[]) => {
              this.favoriteColors = colors
            }
          })
        }
        .width('100%')
        .padding(16)
        .borderRadius(16)
        .backgroundColor($r('app.color.start_window_background_blur'))
        .opacity(0.8)
      }
    }
  }

  private getColorTitle(target: number): Resource {
    if (target === 3) {
      return $r('app.string.ai_subtitle_font_color')
    }
    return target === 0 ? $r('app.string.pick_text_color') :
      (target === 1 ? $r('app.string.pick_outline_color') : $r('app.string.pick_shadow_color'))
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
    if (target === 3) {
      return Setting.aiSubtitleFontColor
    } else if (target === 0) {
      return Setting.subtitleColor
    } else if (target === 1) {
      return Setting.subtitleBorderColor
    } else {
      return Setting.subtitleShadowColor
    }
  }

  private selectColor(target: number, value: string): void {
    if (target === 3) {
      Setting.aiSubtitleFontColor = value
      this.saveAISettings()
      return
    } else if (target === 0) {
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
