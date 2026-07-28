import { SettingsClickItem } from '../../component/SettingComponent/SettingsClickItem'
import { SettingsSegmentButtonItem } from '../../component/SettingComponent/SettingsSegmentButtonItem'
import { SettingsSliderItem } from '../../component/SettingComponent/SettingsSliderItem'
import { SettingsToggleItem } from '../../component/SettingComponent/SettingsToggleItem'
import Preferences from '../../database/Preferences'
import { SafeHeight, Setting } from '../../utils/ObservedUtil'
import { PathUtils } from '../../utils/PathUtils'
import SelectFileUtil from '../../utils/SelectFileUtil'
import ToolsUtil from '../../utils/ToolsUtil'
import { HdsNavDestination, ScrollEffectType } from '@kit.UIDesignKit'
import { LengthMetrics } from '@kit.ArkUI'
import { ConfigurationConstant } from '@kit.AbilityKit'
import { appInfoManager } from '@kit.AppGalleryKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { salmonLogger } from 'salmonlogger'

const TAG = 'PersonalizePage'

@ComponentV2
export struct PersonalizePage {
  @Local dynamicIconList: appInfoManager.DynamicIconInfo[] = []
  @Local currentEnabledIconId: string = ''
  @Local dynamicIconSupported: boolean = false
  @Local dynamicIconDialogOpen: boolean = false
  private listScroller: Scroller = new Scroller()

  aboutToAppear(): void {
    this.queryDynamicIcons()
  }

  build() {
    HdsNavDestination() {
      List({ scroller: this.listScroller }) {
        ListItem() {
          SettingsSegmentButtonItem({
            symbol: $r('sys.symbol.sun'),
            message: '显示模式',
            tips: ['自动', '浅色', '深色'],
            tabSelectedIndex: Setting.backgroundColorMode,
            onButtonClick: (tabSelectedIndex: number) => {
              Setting.backgroundColorMode = tabSelectedIndex
              Preferences.saveBackgroundColorMode(PathUtils.appContext!, tabSelectedIndex)
              ToolsUtil.setColorMode(PathUtils.appContext!, tabSelectedIndex)
              Setting.backgroundImageSrc = ''
              setTimeout(async () => {
                Setting.backgroundImageSrc = SelectFileUtil.getImageUri()
                if (Setting.backgroundDropBlur > 0 && Setting.backgroundImageSrc.length > 0) {
                  await SelectFileUtil.updateBlurBackground(Setting.backgroundDropBlur)
                }
              }, 100)
            }
          })
        }

        if (this.dynamicIconSupported) {
          ListItem() {
            SettingsClickItem({
              symbol: $r('sys.symbol.icloud'),
              message: '切换应用图标',
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
            message: '深浅色图片切换',
            enable: Setting.enableBackgroundDarkImage,
            tag: '试用',
            onChange: async (checked: boolean) => {
              Setting.enableBackgroundDarkImage = checked
              if (!checked) {
                await SelectFileUtil.deletePhoto('BackgroundDarkImage')
                const currentColorMode = AppStorage.get('currentColorMode') as number
                if (currentColorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK) {
                  Setting.backgroundImageSrc = ''
                }
              }
              Preferences.saveEnableBackgroundDarkImage(PathUtils.appContext!, Setting.enableBackgroundDarkImage)
            }
          })
        }

        if (Setting.backgroundImageSrc.length > 0) {
          ListItem() {
            SettingsToggleItem({
              symbol: $r('sys.symbol.blur_bar'),
              message: '列表项背景模糊',
              tag: '试用',
              enable: Setting.listItemBackgroundBlur,
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
            message: Setting.enableBackgroundDarkImage ? '自定义浅色背景' : '自定义背景',
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
              message: '自定义深色背景',
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
              message: Setting.enableBackgroundDarkImage ? '删除浅色自定义背景' : '删除自定义背景',
              onPress: async () => {
                await SelectFileUtil.deletePhoto('BackgroundImage')
                Setting.backgroundImageSrc = ''
                Setting.backgroundBlurImageSrc = ''
                Setting.backgroundDropBlur = 0
                Setting.listItemBackgroundBlur = false
                ToolsUtil.showToast('删除成功')
                Preferences.saveBackgroundDropBlur(PathUtils.appContext!, 0)
                Preferences.saveListItemBackgroundBlur(PathUtils.appContext!, false)
              }
            })
          }

          if (Setting.enableBackgroundDarkImage) {
            ListItem() {
              SettingsClickItem({
                symbol: $r('sys.symbol.picture_damage'),
                message: '删除深色自定义背景',
                onPress: async () => {
                  await SelectFileUtil.deletePhoto('BackgroundDarkImage')
                  const currentColorMode = AppStorage.get('currentColorMode') as number
                  if (currentColorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK) {
                    Setting.backgroundImageSrc = ''
                    Setting.backgroundBlurImageSrc = ''
                    Setting.backgroundDropBlur = 0
                    Setting.listItemBackgroundBlur = false
                    Preferences.saveListItemBackgroundBlur(PathUtils.appContext!, false)
                  }
                  ToolsUtil.showToast('删除成功')
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
              message: '背景模糊',
              textSliderMode: false,
              selected: Setting.backgroundDropBlur,
              onChange: (value: number) => {
                Setting.backgroundDropBlur = value
              },
              onChangeComplete: async (value: number) => {
                Setting.backgroundDropBlur = value
                Preferences.saveBackgroundDropBlur(PathUtils.appContext!, Setting.backgroundDropBlur)
                await SelectFileUtil.updateBlurBackground(value, true)
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
          mainTitle: '个性化',
        }
      },
    })
    .backgroundColor($r('app.color.start_window_background'))
    .padding({ top: SafeHeight.topSafeHeight })
    .backgroundImage(
      Setting.backgroundDropBlur > 0 && Setting.backgroundBlurImageSrc.length > 0 ? Setting.backgroundBlurImageSrc :
        Setting.backgroundImageSrc, ImageRepeat.NoRepeat)
    .backgroundImageSize(ImageSize.Cover)
    .backdropBlur(
      Setting.backgroundDropBlur > 0 && Setting.backgroundBlurImageSrc.length === 0 ? Setting.backgroundDropBlur : 0)
    .backgroundImagePosition(Alignment.Center)
    .hideBackButton(false)
    .bindToScrollable([this.listScroller]) // 绑定导航组件和可滚动容器组件
    .bindSheet(this.dynamicIconDialogOpen, this.dynamicIconCoverBuilder(), {
      detents: [SheetSize.LARGE, SheetSize.MEDIUM],
      showClose: true,
      dragBar: true,
      backgroundColor: $r('app.color.start_window_background'),
      title: { title: '应用图标' },
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
                  color: ri.item.iconId === this.currentEnabledIconId ? $r('app.color.main_color') : Color.Transparent
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

  private queryDynamicIcons() {
    try {
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
    } catch (error) {
      this.dynamicIconSupported = false
      salmonLogger.addLog(TAG, `查询动态图标异常, code: ${error.code}, message: ${error.message}`, true)
    }
  }

  private selectDynamicIcon(iconId: string) {
    try {
      appInfoManager.selectDynamicIcon(iconId).then(() => {
        this.currentEnabledIconId = iconId
        ToolsUtil.showToast('图标切换成功')
        salmonLogger.addLog(TAG, `切换动态图标成功, iconId: ${iconId}`, false)
      }).catch((error: BusinessError) => {
        ToolsUtil.showToast('图标切换失败')
        salmonLogger.addLog(TAG, `切换动态图标失败, code: ${error.code}, message: ${error.message}`, true)
      })
    } catch (error) {
      ToolsUtil.showToast('图标切换失败')
      salmonLogger.addLog(TAG, `切换动态图标异常, code: ${error.code}, message: ${error.message}`, true)
    }
  }

  private disableDynamicIcon() {
    try {
      appInfoManager.disableDynamicIcon().then(() => {
        this.currentEnabledIconId = ''
        ToolsUtil.showToast('已恢复默认图标')
        salmonLogger.addLog(TAG, '禁用动态图标成功', false)
      }).catch((error: BusinessError) => {
        ToolsUtil.showToast('恢复默认图标失败')
        salmonLogger.addLog(TAG, `禁用动态图标失败, code: ${error.code}, message: ${error.message}`, true)
      })
    } catch (error) {
      ToolsUtil.showToast('恢复默认图标失败')
      salmonLogger.addLog(TAG, `禁用动态图标异常, code: ${error.code}, message: ${error.message}`, true)
    }
  }

  private async selectAndSetBackgroundImage(imageName: string, shouldApply: () => boolean) {
    const imageUris = await SelectFileUtil.selectPhoto()
    if (imageUris.length === 0) {
      ToolsUtil.showToast('没有照片被选择')
      return
    }
    Setting.backgroundImageSrc = ''
    SelectFileUtil.saveImageToSandBox(imageUris[0], imageName)
    setTimeout(async () => {
      if (shouldApply()) {
        Setting.backgroundImageSrc = SelectFileUtil.getImageUri()
        if (Setting.backgroundDropBlur > 0) {
          await SelectFileUtil.updateBlurBackground(Setting.backgroundDropBlur, true)
        }
        ToolsUtil.showToast('设置成功')
      }
    }, 100)
  }
}