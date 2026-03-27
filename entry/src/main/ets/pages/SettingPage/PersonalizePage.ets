import { SettingsCheckboxItem } from '../../component/SettingComponent/SettingsCheckboxItem'
import { SettingsClickItem } from '../../component/SettingComponent/SettingsClickItem'
import { SettingSliderItem } from '../../component/SettingComponent/SettingSliderItem'
import Preferences from '../../database/Preferences'
import { SafeHeight, Setting } from '../../utils/ObservedUtil'
import { PathUtils } from '../../utils/PathUtils'
import SelectFileUtil from '../../utils/SelectFileUtil'
import ToolsUtil from '../../utils/ToolsUtil'
import { ConfigurationConstant } from '@kit.AbilityKit'

@Component
export struct PersonalizePage {
  build() {
    NavDestination() {
      List() {
        ListItem() {
          SettingsCheckboxItem({
            symbol: $r('sys.symbol.sun'),
            message: '显示模式',
            tips: ['自动', '浅色', '深色'],
            tabSelectedIndexes: [Setting.backgroundColorMode],
            onButtonClick: (tabSelectedIndexes: number) => {
              Setting.backgroundColorMode = tabSelectedIndexes
              Preferences.saveBackgroundColorMode(PathUtils.appContext!, tabSelectedIndexes)
              ToolsUtil.setColorMode(PathUtils.appContext!, tabSelectedIndexes)
              Setting.backgroundImageSrc = ''
              setTimeout(() => {
                Setting.backgroundImageSrc = SelectFileUtil.getImageUri()
                ToolsUtil.showToast('设置成功')
              }, 100)
            }
          })
        }

        ListItem() {
          SettingsClickItem({
            symbol: $r('sys.symbol.picture'),
            message: '自定义（浅色）背景',
            onPress: async () => {
              const imageUris = await SelectFileUtil.selectPhoto()
              if (imageUris.length === 0) {
                ToolsUtil.showToast('没有照片被选择')
                return
              }
              Setting.backgroundImageSrc = ''
              SelectFileUtil.saveImageToPrivacySpace(imageUris[0], false)
              setTimeout(() => {
                Setting.backgroundImageSrc = SelectFileUtil.getImageUri()
                ToolsUtil.showToast('设置成功')
              }, 100)
            }
          })
        }

        if (Setting.backgroundImageSrc.length > 0) {
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
                Setting.backgroundImageSrc = ''
                SelectFileUtil.saveImageToPrivacySpace(imageUris[0], true)
                setTimeout(() => {
                  Setting.backgroundImageSrc = SelectFileUtil.getImageUri()
                  ToolsUtil.showToast('设置成功')
                }, 100)
              }
            })
          }


          ListItem() {
            SettingsClickItem({
              symbol: $r('sys.symbol.picture_damage'),
              message: '删除（浅色）自定义背景',
              onPress: async () => {
                await SelectFileUtil.deletePhoto('BackgroundImage')
                await SelectFileUtil.deletePhoto('BackgroundDarkImage')
                Setting.backgroundImageSrc = ''
                ToolsUtil.showToast('删除成功')
                Preferences.saveBackgroundDropBlur(PathUtils.appContext!, 0)
              }
            })
          }

          ListItem() {
            SettingsClickItem({
              symbol: $r('sys.symbol.picture_damage'),
              message: '删除（深色）自定义背景',
              onPress: async () => {
                await SelectFileUtil.deletePhoto('BackgroundDarkImage')
                const currentColorMode = AppStorage.get('currentColorMode') as number
                if (currentColorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK) {
                  Setting.backgroundImageSrc = ''
                } else {
                  Setting.backgroundImageSrc = ''
                  setTimeout(() => {
                    Setting.backgroundImageSrc = SelectFileUtil.getImageUri()
                  }, 100)
                }
                ToolsUtil.showToast('删除成功')
                Preferences.saveBackgroundDropBlur(PathUtils.appContext!, 0)
              }
            })
          }

          ListItem() {
            SettingSliderItem({
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