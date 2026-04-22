import { SettingsCheckboxItem } from '../../component/SettingComponent/SettingsCheckboxItem'
import { SettingsClickItem } from '../../component/SettingComponent/SettingsClickItem'
import { SettingsSliderItem } from '../../component/SettingComponent/SettingsSliderItem'
import Preferences from '../../database/Preferences'
import { SafeHeight, Setting } from '../../utils/ObservedUtil'
import { PathUtils } from '../../utils/PathUtils'
import SelectFileUtil from '../../utils/SelectFileUtil'
import ToolsUtil from '../../utils/ToolsUtil'
import { ConfigurationConstant } from '@kit.AbilityKit'
import { SettingsToggleItem } from '../../component/SettingComponent/SettingsToggleItem'

@ComponentV2
export struct PersonalizePage {
  build() {
    NavDestination() {
      List() {
        ListItem() {
          SettingsCheckboxItem({
            symbol: $r('sys.symbol.sun'),
            message: '显示模式',
            tips: ['自动', '浅色', '深色'],
            tabSelectedIndex: Setting.backgroundColorMode,
            onButtonClick: (tabSelectedIndex: number) => {
              Setting.backgroundColorMode = tabSelectedIndex
              Preferences.saveBackgroundColorMode(PathUtils.appContext!, tabSelectedIndex)
              ToolsUtil.setColorMode(PathUtils.appContext!, tabSelectedIndex)
              Setting.backgroundImageSrc = ''
              setTimeout(() => {
                Setting.backgroundImageSrc = SelectFileUtil.getImageUri()
              }, 100)
            }
          })
        }

        ListItem() {
          SettingsToggleItem({
            symbol: $r('sys.symbol.doc_text_badge_clock'),
            message: '深浅色图片切换',
            enable: Setting.enableBackgroundDarkImage,
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

        ListItem() {
          SettingsClickItem({
            symbol: $r('sys.symbol.picture'),
            message: Setting.enableBackgroundDarkImage ? '自定义浅色背景' : '自定义背景',
            onPress: async () => {
              const imageUris = await SelectFileUtil.selectPhoto()
              if (imageUris.length === 0) {
                ToolsUtil.showToast('没有照片被选择')
                return
              }
              const currentColorMode = AppStorage.get('currentColorMode') as number
              Setting.backgroundImageSrc = ''
              SelectFileUtil.saveImageToPrivacySpace(imageUris[0], false)
              setTimeout(() => {
                if (!Setting.enableBackgroundDarkImage ||
                  currentColorMode === ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT) {
                  Setting.backgroundImageSrc = SelectFileUtil.getImageUri()
                  ToolsUtil.showToast('设置成功')
                }
              }, 100)
            }
          })
        }


        if (Setting.enableBackgroundDarkImage) {
          ListItem() {
            SettingsClickItem({
              symbol: $r('sys.symbol.picture'),
              message: '自定义深色背景',
              onPress: async () => {
                const imageUris = await SelectFileUtil.selectPhoto()
                if (imageUris.length === 0) {
                  ToolsUtil.showToast('没有照片被选择')
                  return
                }
                const currentColorMode = AppStorage.get('currentColorMode') as number
                Setting.backgroundImageSrc = ''
                SelectFileUtil.saveImageToPrivacySpace(imageUris[0], true)
                setTimeout(() => {
                  if (currentColorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK) {
                    Setting.backgroundImageSrc = SelectFileUtil.getImageUri()
                    ToolsUtil.showToast('设置成功')
                  }
                }, 100)
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
                ToolsUtil.showToast('删除成功')
                Preferences.saveBackgroundDropBlur(PathUtils.appContext!, 0)
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
              onChangeComplete: (value: number) => {
                Setting.backgroundDropBlur = value
                Preferences.saveBackgroundDropBlur(PathUtils.appContext!, Setting.backgroundDropBlur)
              }
            })
          }
        }

      }
      .align(Alignment.Top)
      .borderRadius(16)
      .margin({ left: 16, right: 16 })
      .clip(true)
      .scrollBar(BarState.Off)
      .height('100%')
      .width('95%')
      .layoutWeight(1)
      .contentEndOffset(SafeHeight.bottomSafeHeight)
    }
    .hideToolBar(true)
    .title('个性化')
    .backgroundColor($r('app.color.start_window_background'))
    .padding({ top: SafeHeight.topSafeHeight })
    .backgroundImage(Setting.backgroundImageSrc, ImageRepeat.NoRepeat)
    .backgroundImageSize(ImageSize.Cover)
    .backgroundImagePosition(Alignment.Center)
    .backdropBlur(Setting.backgroundDropBlur)
  }
}