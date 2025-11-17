import { SettingsClickItem } from '../../component/SettingComponent/SettingsClickItem';
import SelectFileUtil from '../../utils/SelectFileUtil';
import ToolsUtil from '../../utils/ToolsUtil';
import { Want } from '@kit.AbilityKit';
import { InfoConfirmDialog } from '../../component/Dialog/InfoConfirmDialog';
import { DefaultDialogShadow } from '../../common/DefaultDialogShadow';
import { PathUtils } from '../../utils/PathUtils';
import { SettingSliderItem } from '../../component/SettingComponent/SettingSliderItem';
import Preferences from '../../database/Preferences';
import { SettingsCheckboxItem } from '../../component/SettingComponent/SettingsCheckboxItem';
import { BackgroundColorMode } from '../../common/enum/BackgroundColorMode';

@Component
export struct PersonalizePage {
  @StorageProp('topSafeHeight') topSafeHeight: number = 0;
  @StorageProp('bottomSafeHeight') bottomSafeHeight: number = 0;
  @StorageLink('backgroundImageSrc') backgroundImageSrc: string = ''
  @StorageLink('backgroundDropBlur') backgroundDropBlur: number = 0
  @StorageLink('backgroundColorMode') backgroundColorMode: BackgroundColorMode = BackgroundColorMode.AUTO
  restartConfirmDialog: CustomDialogController = new CustomDialogController({
    builder: InfoConfirmDialog({
      confirm: async () => {
        if (canIUse('SystemCapability.BundleManager.BundleFramework.Core')) {
          let applicationContext = PathUtils.appContext!.getApplicationContext();
          let want: Want = {
            bundleName: PathUtils.appContext!.abilityInfo.bundleName,
            abilityName: PathUtils.appContext!.abilityInfo.name
          };
          try {
            applicationContext.restartApp(want);
          } catch (error) {
            console.error(`restartApp fail, error: ${JSON.stringify(error)}`);
          }
        }
      },
      textInfo: '部分效果需要重启 APP 才能显示，是否重启？'
    }), cornerRadius: 20, shadow: DefaultDialogShadow
  })
  private backgroundColorDisplayMode: ResourceStr[] = ['自动', '浅色', '深色']

  build() {
    NavDestination() {
      List() {
        ListItem() {
          SettingsCheckboxItem({
            symbol: $r('sys.symbol.sun'),
            message: '显示模式',
            tips: this.backgroundColorDisplayMode,
            tabSelectedIndexes: [this.backgroundColorMode],
            onButtonClick: (tabSelectedIndexes: number) => {
              this.backgroundColorMode = tabSelectedIndexes
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
              SelectFileUtil.saveImageToPrivacySpace(imageUris[0])
              this.backgroundImageSrc = SelectFileUtil.getImageUri()
              ToolsUtil.showToast('设置成功')
              this.restartConfirmDialog.open()
            }
          })
        }

        if (this.backgroundImageSrc.length > 0) {
          ListItem() {
            SettingsClickItem({
              symbol: $r('sys.symbol.picture_damage'),
              message: '删除自定义背景',
              onPress: async () => {
                await SelectFileUtil.deletePhoto()
                this.backgroundImageSrc = SelectFileUtil.getImageUri()
                ToolsUtil.showToast('删除成功')
                Preferences.saveBackgroundDropBlur(PathUtils.appContext!, 0)
                this.restartConfirmDialog.open()
              }
            })
          }

          ListItem() {
            SettingSliderItem({
              symbol: $r('sys.symbol.livephoto'),
              message: '背景模糊',
              textSliderMode: false,
              selected: this.backgroundDropBlur,
              onChangeComplete: (value: number) => {
                this.backgroundDropBlur = value
                Preferences.saveBackgroundDropBlur(PathUtils.appContext!, this.backgroundDropBlur)
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
      .contentEndOffset(this.bottomSafeHeight)
    }
    .hideToolBar(true)
    .title('个性化')
    .backgroundColor($r('app.color.start_window_background'))
    .padding({ top: this.topSafeHeight })
    .backgroundImage(this.backgroundImageSrc, ImageRepeat.NoRepeat)
    .backgroundImageSize(ImageSize.Cover)
    .backgroundImagePosition(Alignment.Center)
    .backdropBlur(this.backgroundDropBlur)
  }
}