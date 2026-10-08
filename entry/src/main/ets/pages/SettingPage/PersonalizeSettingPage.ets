import ImageFileUtil from '../../utils/ImageFileUtil'
import { SettingsClickItem } from '../../component/SettingComponent/SettingsClickItem'
import { SettingsSegmentButtonItem } from '../../component/SettingComponent/SettingsSegmentButtonItem'
import { SettingsSliderItem } from '../../component/SettingComponent/SettingsSliderItem'
import { SettingsToggleItem } from '../../component/SettingComponent/SettingsToggleItem'
import Preferences from '../../database/Preferences'
import { SafeHeight, Setting } from '../../utils/ObservedUtil'
import { PathUtils } from '../../utils/PathUtils'
import SelectFileUtil from '../../utils/SelectFileUtil'
import ToolsUtil from '../../utils/ToolsUtil'
import { userData } from '../../component/common/UserLoginComponent'
import { hdsMaterial, HdsNavDestination, ScrollEffectType } from '@kit.UIDesignKit'
import { LengthMetrics } from '@kit.ArkUI'
import { ConfigurationConstant } from '@kit.AbilityKit'
import { appInfoManager } from '@kit.AppGalleryKit'
import { BusinessError, SuppressWarnings, SuppressWarningsType } from '@kit.BasicServicesKit'
import { salmonLogger } from 'salmonlogger'
import { BackgroundColorMode } from '../../common/enum/BackgroundColorMode'

const TAG = 'PersonalizeSettingPage'

@ComponentV2
export struct PersonalizeSettingPage {
  @Local dynamicIconList: appInfoManager.DynamicIconInfo[] = []
  @Local currentEnabledIconId: string = ''
  @Local dynamicIconSupported: boolean = false
  @Local dynamicIconDialogOpen: boolean = false
  private listScroller: Scroller = new Scroller()

  aboutToAppear(): void {
    this.queryDynamicIcons()
  }

  @SuppressWarnings({ rules: [SuppressWarningsType.SYSCAP] })
  build() {
    HdsNavDestination() {
      List({ scroller: this.listScroller }) {
        ListItem() {
          SettingsSegmentButtonItem({
            symbol: $r('sys.symbol.sun'),
            message: $r('app.string.display_mode'),
            tips: [$r('app.string.display_mode_auto'), $r('app.string.display_mode_light'), $r('app.string.display_mode_dark')],
            tabSelectedIndex: Setting.backgroundColorMode,
            onButtonClick: (tabSelectedIndex: number) => {
              Setting.backgroundColorMode = tabSelectedIndex
              Preferences.saveBackgroundColorMode(PathUtils.appContext!, tabSelectedIndex)
              ToolsUtil.setColorMode(PathUtils.appContext!, tabSelectedIndex)
              if (tabSelectedIndex === BackgroundColorMode.LIGHT) {
                AppStorage.setOrCreate('currentColorMode', ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT)
              } else if (tabSelectedIndex === BackgroundColorMode.DARK) {
                AppStorage.setOrCreate('currentColorMode', ConfigurationConstant.ColorMode.COLOR_MODE_DARK)
              }
              Setting.backgroundImageSrc = ''
              setTimeout(async () => {
                Setting.backgroundImageSrc = ImageFileUtil.getImageUri()
                if (Setting.backgroundDropBlur > 0 && Setting.backgroundImageSrc.length > 0) {
                  await ImageFileUtil.updateBlurBackground(Setting.backgroundDropBlur)
                }
              }, 100)
            }
          })
        }

        if (this.dynamicIconSupported) {
          ListItem() {
            SettingsClickItem({
              symbol: $r('sys.symbol.brush'),
              message: $r('app.string.switch_app_icon'),
              onPress: () => {
                this.dynamicIconDialogOpen = false
                setTimeout(() => {
                  this.dynamicIconDialogOpen = true
                }, 50)
              }
            })
          }
        }

        ListItem() {
          SettingsToggleItem({
            symbol: $r('sys.symbol.doc_text_badge_clock'),
            message: $r('app.string.wallpaper_switch'),
            enable: Setting.enableBackgroundDarkImage,
            tag: 'VIP',
            itemEnabled: userData.isVip,
            onChange: async (checked: boolean) => {
              Setting.enableBackgroundDarkImage = checked
              Setting.backgroundImageSrc = ''
              setTimeout(async () => {
                Setting.backgroundImageSrc = ImageFileUtil.getImageUri()
                if (Setting.backgroundDropBlur > 0 && Setting.backgroundImageSrc.length > 0) {
                  await ImageFileUtil.updateBlurBackground(Setting.backgroundDropBlur, true)
                }
              }, 100)
              Preferences.saveEnableBackgroundDarkImage(PathUtils.appContext!, Setting.enableBackgroundDarkImage)
            }
          })
        }

        if (Setting.backgroundImageSrc.length > 0) {
          ListItem() {
            SettingsToggleItem({
              symbol: $r('sys.symbol.blur_bar'),
              message: $r('app.string.list_item_bg_blur'),
              tag: 'VIP',
              enable: Setting.listItemBackgroundBlur,
              itemEnabled: userData.isVip,
              onChange: (checked: boolean) => {
                Setting.listItemBackgroundBlur = checked
                Preferences.saveListItemBackgroundBlur(PathUtils.appContext!, Setting.listItemBackgroundBlur)
              }
            })
          }
        }

        ListItem() {
          SettingsClickItem({
            symbol: $r('sys.symbol.picture'),
            message: Setting.enableBackgroundDarkImage ? $r('app.string.custom_wallpaper_light') : $r('app.string.custom_wallpaper'),
            onPress: async () => {
              const currentColorMode = AppStorage.get('currentColorMode') as number
              await this.selectAndSetBackgroundImage('BackgroundImage',
                () => !Setting.enableBackgroundDarkImage ||
                  currentColorMode === ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT)
            }
          })
        }

        if (Setting.enableBackgroundDarkImage) {
          ListItem() {
            SettingsClickItem({
              symbol: $r('sys.symbol.picture'),
              message: $r('app.string.custom_wallpaper_dark'),
              onPress: async () => {
                const currentColorMode = AppStorage.get('currentColorMode') as number
                await this.selectAndSetBackgroundImage('BackgroundDarkImage',
                  () => currentColorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK)
              }
            })
          }
        }

        if (Setting.backgroundImageSrc.length > 0) {
          ListItem() {
            SettingsClickItem({
              symbol: $r('sys.symbol.picture_damage'),
              message: Setting.enableBackgroundDarkImage ? $r('app.string.delete_wallpaper_light') : $r('app.string.delete_wallpaper'),
              onPress: async () => {
                await ImageFileUtil.deletePhoto('BackgroundImage')
                Setting.backgroundImageSrc = ''
                Setting.backgroundBlurImageSrc = ''
                Setting.backgroundDropBlur = 0
                Setting.listItemBackgroundBlur = false
                ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.delete_success').id))
                Preferences.saveBackgroundDropBlur(PathUtils.appContext!, 0)
                Preferences.saveListItemBackgroundBlur(PathUtils.appContext!, false)
              }
            })
          }

          if (Setting.enableBackgroundDarkImage) {
            ListItem() {
              SettingsClickItem({
                symbol: $r('sys.symbol.picture_damage'),
                message: $r('app.string.delete_wallpaper_dark'),
                onPress: async () => {
                  await ImageFileUtil.deletePhoto('BackgroundDarkImage')
                  const currentColorMode = AppStorage.get('currentColorMode') as number
                  if (currentColorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK) {
                    Setting.backgroundImageSrc = ''
                    Setting.backgroundBlurImageSrc = ''
                    Setting.backgroundDropBlur = 0
                    Setting.listItemBackgroundBlur = false
                    Preferences.saveListItemBackgroundBlur(PathUtils.appContext!, false)
                  }
                  ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.delete_success').id))
                  Preferences.saveBackgroundDropBlur(PathUtils.appContext!, 0)
                }
              })
            }
          }
        }

        if (Setting.backgroundImageSrc.length > 0) {
          ListItem() {
            SettingsSliderItem({
              symbol: $r('sys.symbol.livephoto'),
              message: $r('app.string.wallpaper_blur'),
              textSliderMode: false,
              selected: Setting.backgroundDropBlur,
              onChange: (value: number) => {
                Setting.backgroundDropBlur = value
              },
              onChangeComplete: async (value: number) => {
                Setting.backgroundDropBlur = value
                Preferences.saveBackgroundDropBlur(PathUtils.appContext!, Setting.backgroundDropBlur)
                await ImageFileUtil.updateBlurBackground(value, true)
              }
            })
          }
        }

      }
      .align(Alignment.Top)
      .borderRadius(16)
      .margin({ left: 16, right: 16 })
      .clip(false)
      .scrollBar(BarState.Off)
      .height('100%')
      .width('95%')
      .layoutWeight(1)
      .contentEndOffset(SafeHeight.bottomSafeHeight)
    }
    .hideToolBar(true)
    .titleBar({
      avoidLayoutSafeArea: true,
      enableComponentSafeArea: true,
      padding: { start: LengthMetrics.vp(5), end: LengthMetrics.vp(5) },
      style: {
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
      content: {
        title: {
          mainTitle: $r('app.string.personalize_title'),
        }
      },
    })
    .backgroundColor($r('app.color.start_window_background'))
    .backgroundImage(
      Setting.backgroundDropBlur > 0 && Setting.backgroundBlurImageSrc.length > 0 ? Setting.backgroundBlurImageSrc :
        Setting.backgroundImageSrc, ImageRepeat.NoRepeat)
    .backgroundImageSize(ImageSize.Cover)
    .backdropBlur(
      Setting.backgroundDropBlur > 0 && Setting.backgroundBlurImageSrc.length === 0 ? Setting.backgroundDropBlur : 0)
    .backgroundImagePosition(Alignment.Center)
    .hideBackButton(false)
    .bindToScrollable([this.listScroller])
    .bindSheet(this.dynamicIconDialogOpen, this.dynamicIconCoverBuilder(), {
      detents: [SheetSize.LARGE, SheetSize.MEDIUM],
      showClose: true,
      dragBar: true,
      backgroundColor: $r('app.color.start_window_background'),
      title: { title: $r('app.string.app_icon') },
    })
  }

  @Builder
  dynamicIconCoverBuilder() {
    Grid() {
      GridItem() {
        Column() {
          Image($r('app.media.sweet_video'))
            .width(96)
            .height(96)
            .borderRadius(24)
            .shadow(this.currentEnabledIconId.length === 0 ?
              {
                radius: 8,
                color: $r('app.color.main_color'),
                offsetX: 0,
                offsetY: 0
              } :
              {
                radius: 0,
                color: Color.Transparent,
                offsetX: 0,
                offsetY: 0
              })
            .border({
              width: 3,
              color: this.currentEnabledIconId.length === 0 ? $r('app.color.main_color') : Color.Transparent
            })
        }
        .justifyContent(FlexAlign.Center)
        .padding(8)
        .borderRadius(16)
        .onClick(() => {
          if (this.currentEnabledIconId.length > 0) {
            this.disableDynamicIcon()
            this.dynamicIconDialogOpen = false
          }
        })
      }

      if (canIUse("SystemCapability.AppGalleryService.AppInfoManager")) {
        Repeat(this.dynamicIconList)
          .each((ri: RepeatItem<appInfoManager.DynamicIconInfo>) => {
            GridItem() {
              Column() {
                Image(ri.item.iconUrl)
                  .width(96)
                  .height(96)
                  .borderRadius(24)
                  .shadow(ri.item.iconId === this.currentEnabledIconId ?
                    {
                      radius: 8,
                      color: $r('app.color.main_color'),
                      offsetX: 0,
                      offsetY: 0
                    } :
                    {
                      radius: 0,
                      color: Color.Transparent,
                      offsetX: 0,
                      offsetY: 0
                    })
                  .border({
                    width: 3,
                    color: ri.item.iconId === this.currentEnabledIconId ? $r('app.color.main_color') :
                      Color.Transparent
                  })
              }
              .justifyContent(FlexAlign.Center)
              .padding(8)
              .borderRadius(16)
              .onClick(() => {
                if (ri.item.iconId !== this.currentEnabledIconId) {
                  this.selectDynamicIcon(ri.item.iconId)
                }
                this.dynamicIconDialogOpen = false
              })
            }
          })
          .key((item: appInfoManager.DynamicIconInfo) => item.iconId)
      }
    }
    .columnsTemplate('1fr 1fr')
    .rowsGap(12)
    .columnsGap(12)
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .padding({
      left: 20,
      right: 20,
      top: 12,
      bottom: 20
    })
  }

  @SuppressWarnings({ rules: [SuppressWarningsType.SYSCAP] })
  private queryDynamicIcons() {
    try {
      if (canIUse("SystemCapability.AppGalleryService.AppInfoManager")) {
        appInfoManager.queryDynamicIcons().then((queryResult: appInfoManager.DynamicIconInfo[]) => {
          this.dynamicIconList = queryResult
          this.dynamicIconSupported = queryResult.length > 0
          for (const icon of queryResult) {
            if (icon.enabled) {
              this.currentEnabledIconId = icon.iconId
              break
            }
          }
          salmonLogger.addLog(TAG, `查询动态图标成功, 数量: ${queryResult.length}`, false)
        }).catch((error: BusinessError) => {
          this.dynamicIconSupported = false
          salmonLogger.addLog(TAG, `查询动态图标失败, code: ${error.code}, message: ${error.message}`, true)
        })
      } else {
        ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.device_not_supported').id))
      }
    } catch (error) {
      this.dynamicIconSupported = false
      salmonLogger.addLog(TAG, `查询动态图标异常, code: ${error.code}, message: ${error.message}`, true)
    }
  }

  @SuppressWarnings({ rules: [SuppressWarningsType.SYSCAP] })
  private selectDynamicIcon(iconId: string) {
    try {
      if (canIUse("SystemCapability.AppGalleryService.AppInfoManager")) {
        appInfoManager.selectDynamicIcon(iconId).then(() => {
          this.currentEnabledIconId = iconId
          ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.icon_switched').id))
          salmonLogger.addLog(TAG, `切换动态图标成功, iconId: ${iconId}`, false)
        }).catch((error: BusinessError) => {
          ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.icon_switch_failed').id))
          salmonLogger.addLog(TAG, `切换动态图标失败, code: ${error.code}, message: ${error.message}`, true)
        })
      } else {
        ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.device_not_supported').id))
      }
    } catch (error) {
      ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.icon_switch_failed').id))
      salmonLogger.addLog(TAG, `切换动态图标异常, code: ${error.code}, message: ${error.message}`, true)
    }
  }

  @SuppressWarnings({ rules: [SuppressWarningsType.SYSCAP] })
  private disableDynamicIcon() {
    try {
      if (canIUse("SystemCapability.AppGalleryService.AppInfoManager")) {
        appInfoManager.disableDynamicIcon().then(() => {
          this.currentEnabledIconId = ''
          ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.icon_restored').id))
          salmonLogger.addLog(TAG, '禁用动态图标成功', false)
        }).catch((error: BusinessError) => {
          ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.icon_restore_failed').id))
          salmonLogger.addLog(TAG, `禁用动态图标失败, code: ${error.code}, message: ${error.message}`, true)
        })
      } else {
        ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.device_not_supported').id))
      }
    } catch (error) {
      ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.icon_restore_failed').id))
      salmonLogger.addLog(TAG, `禁用动态图标异常, code: ${error.code}, message: ${error.message}`, true)
    }
  }

  private async selectAndSetBackgroundImage(imageName: string, shouldApply: () => boolean) {
    const imageUris = await SelectFileUtil.selectPhoto()
    if (imageUris.length === 0) {
      ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.no_photo_selected').id))
      return
    }
    Setting.backgroundImageSrc = ''
    ImageFileUtil.saveImageToSandBox(imageUris[0], imageName)
    setTimeout(async () => {
      if (shouldApply()) {
        Setting.backgroundImageSrc = ImageFileUtil.getImageUri()
        if (Setting.backgroundDropBlur > 0) {
          await ImageFileUtil.updateBlurBackground(Setting.backgroundDropBlur, true)
        }
        ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.set_success').id))
      }
    }, 100)
  }
}