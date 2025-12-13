import { SettingsClickItem } from '../../component/SettingComponent/SettingsClickItem';
import SelectFileUtil from '../../utils/SelectFileUtil';
import ToolsUtil from '../../utils/ToolsUtil';
import { PathUtils } from '../../utils/PathUtils';
import { SettingSliderItem } from '../../component/SettingComponent/SettingSliderItem';
import Preferences from '../../database/Preferences';
import { SettingsCheckboxItem } from '../../component/SettingComponent/SettingsCheckboxItem';
import { SafeHeight, Setting } from '../../utils/ObservedUtil';

@Component
export struct PersonalizePage {
  private backgroundColorDisplayMode: ResourceStr[] = ['自动', '浅色', '深色']

  build() {
    NavDestination() {
      List() {
        ListItem() {
          SettingsCheckboxItem({
            symbol: $r('sys.symbol.sun'),
            message: '显示模式',
            tips: this.backgroundColorDisplayMode,
            tabSelectedIndexes: [Setting.backgroundColorMode],
            onButtonClick: (tabSelectedIndexes: number) => {
              Setting.backgroundColorMode = tabSelectedIndexes
              Preferences.saveBackgroundColorMode(PathUtils.appContext!, tabSelectedIndexes)
              ToolsUtil.setColorMode(PathUtils.appContext!, tabSelectedIndexes)
            }
          })
        }

        ListItem() {
          SettingsClickItem({
            symbol: $r('sys.symbol.picture'),
            message: '自定义背景',
            onPress: async () => {
              const imageUris = await SelectFileUtil.selectPhoto()
              if (imageUris.length === 0) {
                ToolsUtil.showToast('没有照片被选择')
                return
              }
              Setting.backgroundImageSrc = ''
              SelectFileUtil.saveImageToPrivacySpace(imageUris[0])
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
              symbol: $r('sys.symbol.picture_damage'),
              message: '删除自定义背景',
              onPress: async () => {
                await SelectFileUtil.deletePhoto()
                Setting.backgroundImageSrc = ''
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