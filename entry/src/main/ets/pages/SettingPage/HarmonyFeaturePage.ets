import { SettingsToggleItem } from '../../component/SettingComponent/SettingsToggleItem'
import { SettingsClickItem } from '../../component/SettingComponent/SettingsClickItem'
import { formProvider } from '@kit.FormKit'
import { deviceInfo, SuppressWarnings, SuppressWarningsType } from '@kit.BasicServicesKit'
import { VIDEO_FORM_ABILITY, VIDEO_FORM_NAME, VideoFormData } from '../../forms/VideoFormData'
import ToolsUtil from '../../utils/ToolsUtil'
import { userData } from '../../component/common/UserLoginComponent'
import Preferences from '../../database/Preferences'
import { MediaSmartGestureSession } from '../../utils/MediaSmartGestureUtil'
import KnockShareUtil from '../../utils/KnockShareUtil'
import { SafeHeight, Setting } from '../../utils/ObservedUtil'
import { PathUtils } from '../../utils/PathUtils'
import { LengthMetrics } from '@kit.ArkUI'
import { hdsMaterial, HdsNavDestination, ScrollEffectType } from '@kit.UIDesignKit'

@ComponentV2
export struct HarmonyFeaturePage {
  @Consumer('pathStack') pathStack: NavPathStack = new NavPathStack()
  private listScroller: Scroller = new Scroller()

  @SuppressWarnings({ rules: [SuppressWarningsType.SYSCAP] })
  build() {
    HdsNavDestination() {
      List({ scroller: this.listScroller }) {

        if (canIUse('SystemCapability.Ability.Form') &&
          ['phone', 'tablet', '2in1'].includes(deviceInfo.deviceType)) {
          ListItem() {
            SettingsClickItem({
              message: $r('app.string.video_form_setting'),
              onPress: () => this.openDesktopCards()
            })
          }
        }

        if (KnockShareUtil.isSupported()) {
          ListItem() {
            Column() {
              SettingsToggleItem({
                symbol: $r('sys.symbol.cheers'),
                message: '碰一碰',
                enable: Setting.knockShareEnabled,
                onChange: (checked: boolean) => {
                  Setting.knockShareEnabled = checked
                  Preferences.saveKnockShareEnabled(PathUtils.appContext!, checked)
                }
              })
              Text('两台设备碰一碰即可快速分享或接收视频文件。需设备支持碰一碰分享功能。')
                .fontSize(12)
                .fontColor($r('sys.color.font_secondary'))
                .width('100%')
                .padding({ left: 16, right: 16, bottom: 12 })
            }
          }
        }

        if (canIUse('SystemCapability.MultimodalAwareness.Motion')) {
          ListItem() {
            Column() {
              SettingsToggleItem({
                symbol: $r('sys.symbol.hand_draw'),
                message: '智感握姿',
                enable: Setting.gripPostureEnabled,
                onChange: (checked: boolean) => {
                  Setting.gripPostureEnabled = checked
                  Preferences.saveGripPostureEnabled(PathUtils.appContext!, checked)
                }
              })
              Text('识别左右手握持状态，自动调整界面布局以适配单手操作。需设备支持智感握姿功能。')
                .fontSize(12)
                .fontColor($r('sys.color.font_secondary'))
                .width('100%')
                .padding({ left: 16, right: 16, bottom: 12 })
            }
          }
        }

        if (MediaSmartGestureSession.isSupported()) {
          ListItem() {
            Column() {
              SettingsToggleItem({
                symbol: $r('sys.symbol.hand_point_up_tap'),
                message: '智慧手势',
                tag: 'VIP',
                enable: Setting.smartGestureEnabled,
                itemEnabled: userData.isVip,
                onChange: (checked: boolean) => {
                  Setting.smartGestureEnabled = checked
                  Preferences.saveSmartGestureEnabled(PathUtils.appContext!, checked)
                }
              })
              Text(
                '敲一敲播放/暂停；划一划在普通播放中快进，在短视频中切换下一条；翻腕返回退出播放。需设备支持并开启系统智慧手势。')
                .fontSize(12)
                .fontColor($r('sys.color.font_secondary'))
                .width('100%')
                .padding({ left: 16, right: 16, bottom: 12 })
            }
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
          mainTitle: '鸿蒙特性',
        }
      },
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

  private openDesktopCards(): void {
    const context = PathUtils.appContext
    if (!context) {
      return
    }
    try {
      VideoFormData.save(context, Preferences.getRecentPlay(context), true)
      formProvider.openFormManager({
        bundleName: context.applicationInfo.name,
        abilityName: VIDEO_FORM_ABILITY,
        parameters: {
          'ohos.extra.param.key.form_dimension': 2,
          'ohos.extra.param.key.form_name': VIDEO_FORM_NAME,
          'ohos.extra.param.key.module_name': 'entry'
        }
      })
    } catch (_) {
      ToolsUtil.showToast('暂时无法打开桌面卡片，请稍后重试')
    }
  }
}
