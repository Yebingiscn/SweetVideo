import { SettingsMenuItem } from '../../component/SettingComponent/SettingsMenuItem'
import { SettingsSegmentButtonItem } from '../../component/SettingComponent/SettingsSegmentButtonItem'
import { SettingsSliderItem } from '../../component/SettingComponent/SettingsSliderItem'
import { SettingsToggleItem } from '../../component/SettingComponent/SettingsToggleItem'

import ToolsUtil from '../../utils/ToolsUtil'
import Preferences from '../../database/Preferences'
import { FastForwardSecondInterface } from '../../interfaces/FastForwardSecondInterface'
import AVSessionUtil from '../../utils/AVSessionUtil'
import { SafeHeight, Setting } from '../../utils/ObservedUtil'
import { PathUtils } from '../../utils/PathUtils'
import { userData } from '../../component/common/UserLoginComponent'
import VideoInfoUtil from '../../utils/VideoInfoUtil'
import VideoOperateUtil from '../../utils/VideoOperateUtil'

import PermissionUtil from '../../utils/PermissionUtil'
import { LengthMetrics } from '@kit.ArkUI'
import { hdsMaterial, HdsNavDestination, ScrollEffectType } from '@kit.UIDesignKit'
import { SuppressWarnings, SuppressWarningsType } from '@kit.BasicServicesKit'

@ComponentV2
export struct PlayerSettingPage {
  private fastForwardSecond: FastForwardSecondInterface[] = [
    { label: ToolsUtil.getStringResourceArgs($r('app.string.seconds_n').id, 5), value: '5' },
    { label: ToolsUtil.getStringResourceArgs($r('app.string.seconds_n').id, 10), value: '10' },
    { label: ToolsUtil.getStringResourceArgs($r('app.string.seconds_n').id, 15), value: '15' },
    { label: ToolsUtil.getStringResourceArgs($r('app.string.seconds_n').id, 30), value: '30' },
    { label: ToolsUtil.getStringResourceArgs($r('app.string.seconds_n').id, 60), value: '60' },
    { label: ToolsUtil.getStringResourceArgs($r('app.string.seconds_n').id, 120), value: '120' }
  ]
  private listScroller: Scroller = new Scroller()

  @SuppressWarnings({ rules: [SuppressWarningsType.SYSCAP] })
  build() {
    HdsNavDestination() {
      List({ scroller: this.listScroller }) {
        ListItem() {
          SettingsToggleItem({
            symbol: $r('sys.symbol.play'),
            message: ToolsUtil.getStringResource($r('app.string.background_playback').id),
            enable: Setting.allowBackgroundPlay,
            onChange: (checked: boolean) => {
              Setting.allowBackgroundPlay = checked
              Preferences.saveAllowBackgroundPlayState(PathUtils.appContext!, Setting.allowBackgroundPlay)
              PermissionUtil.handleBackgroundPlaySettingChanged(checked)
            }
          })
        }

        ListItem() {
          SettingsToggleItem({
            symbol: $r('sys.symbol.play_gobackward'),
            message: ToolsUtil.getStringResource($r('app.string.play_with_others').id),
            tag: 'VIP',
            enable: Setting.allowConcurrentPlay,
            itemEnabled: userData.isVip,
            onChange: (checked: boolean) => {
              Setting.allowConcurrentPlay = checked
              Preferences.saveAllowConcurrentPlayState(PathUtils.appContext!, Setting.allowConcurrentPlay)
              AVSessionUtil.applyAudioConcurrencyMode()
            }
          })
        }

        ListItem() {
          SettingsToggleItem({
            symbol: $r('sys.symbol.rectangle_portrait_filled_on_rectangle_portrait'),
            message: ToolsUtil.getStringResource($r('app.string.auto_pip_on_background').id),
            enable: Setting.autoActivePip,
            onChange: (checked: boolean) => {
              Setting.autoActivePip = checked
              Preferences.saveAutoActivePip(PathUtils.appContext!, Setting.autoActivePip)
            }
          })
        }

        ListItem() {
          SettingsToggleItem({
            symbol: $r('sys.symbol.play_circle'),
            message: ToolsUtil.getStringResource($r('app.string.resume_on_foreground').id),
            enable: Setting.autoResumeOnReturn,
            onChange: (checked: boolean) => {
              Setting.autoResumeOnReturn = checked
              Preferences.saveAutoResumeOnReturn(PathUtils.appContext!, Setting.autoResumeOnReturn)
            }
          })
        }

        ListItem() {
          SettingsToggleItem({
            symbol: $r('sys.symbol.arrow_left'),
            message: ToolsUtil.getStringResource($r('app.string.hide_status_bar_on_back').id),
            enable: !Setting.allowPlayBackExist,
            onChange: (checked: boolean) => {
              Setting.allowPlayBackExist = !checked
              Preferences.saveAllowPlayBackExistState(PathUtils.appContext!, Setting.allowPlayBackExist)
            }
          })
        }

        ListItem() {

          SettingsToggleItem({
            symbol: $r('sys.symbol.music_note_phone'),
            message: ToolsUtil.getStringResource($r('app.string.short_video_mode').id),
            enable: Setting.shortVideoMode,
            onChange: (checked: boolean) => {
              Setting.shortVideoMode = checked
              Preferences.saveShortVideoMode(PathUtils.appContext!, checked)
            }
          })
        }


        ListItem() {
          SettingsToggleItem({
            symbol: $r('sys.symbol.screen_rotation'),
            message: ToolsUtil.getStringResource($r('app.string.smart_landscape').id),
            enable: Setting.smartRotation,
            onChange: (checked: boolean) => {
              Setting.smartRotation = checked
              Preferences.saveSmartRotation(PathUtils.appContext!, Setting.smartRotation)
            }
          })
        }

        ListItem() {
          SettingsToggleItem({
            symbol: $r('sys.symbol.resolution_video'),
            message: ToolsUtil.getStringResource($r('app.string.show_progress_preview').id),
            enable: Setting.showFrameImgStatus,
            onChange: (checked: boolean) => {
              Setting.showFrameImgStatus = checked
              Preferences.saveShowFrameTime(PathUtils.appContext!, Setting.showFrameImgStatus)
            }
          })
        }

        ListItem() {
          SettingsToggleItem({

            symbol: $r('sys.symbol.pin'),
            message: ToolsUtil.getStringResource($r('app.string.remember_playback_position').id),
            enable: Setting.jumpToHistoryTimeStatus,
            onChange: (checked: boolean) => {
              Setting.jumpToHistoryTimeStatus = checked
              Preferences.saveJumpToHistoryTime(PathUtils.appContext!, Setting.jumpToHistoryTimeStatus)
            }
          })
        }

        ListItem() {
          Column() {
            SettingsToggleItem({
              symbol: $r('sys.symbol.hand_draw'),
              message: ToolsUtil.getStringResource($r('app.string.enable_double_tap_seek').id),
              enable: Setting.allowDoubleFastForward,
              onChange: (checked: boolean) => {
                Setting.allowDoubleFastForward = checked
                Preferences.saveAllowDoubleFastForwardState(PathUtils.appContext!, Setting.allowDoubleFastForward)
              }
            })
          }
        }

        if (Setting.allowDoubleFastForward) {
          ListItem() {
            SettingsMenuItem({
              symbol: $r('sys.symbol.hand_point_up_tap'),
              message: ToolsUtil.getStringResource($r('app.string.seek_duration').id),
              list: this.fastForwardSecond.map(opt => opt.label),
              selected: this.fastForwardSecond.findIndex(opt => opt.value === Setting.fastForwardSeconds),
              onChange: (index: number) => {
                Setting.fastForwardSeconds = this.fastForwardSecond[index].value
                Preferences.saveFastForwardSeconds(PathUtils.appContext!, Setting.fastForwardSeconds)
              }
            })
          }
        }

        ListItem() {
          SettingsMenuItem({
            symbol: $r('sys.symbol.fast_forward'),
            message: ToolsUtil.getStringResource($r('app.string.long_press_speed').id),
            list: VideoInfoUtil.getVideoSpeedTextList(),
            selected: VideoInfoUtil.videoSpeedListAll.findIndex(opt => opt === Setting.longPressSpeed),
            onChange: (index: number) => {
              Setting.longPressSpeed = VideoInfoUtil.videoSpeedListAll[index]
              Preferences.saveLongPressSpeed(PathUtils.appContext!, Setting.longPressSpeed)
            }
          })
        }

        ListItem() {
          SettingsSegmentButtonItem({
            symbol: $r('sys.symbol.hand_draw'),
            message: ToolsUtil.getStringResource($r('app.string.horizontal_seek_sensitivity').id),
            tips: [$r('app.string.sensitivity_normal'), $r('app.string.sensitivity_medium'), $r('app.string.sensitivity_low')],
            tabSelectedIndex: Setting.seekSensitivity,
            onButtonClick: (tabSelectedIndex: number) => {
              Setting.seekSensitivity = tabSelectedIndex
              Preferences.saveSeekSensitivity(PathUtils.appContext!, tabSelectedIndex)
            }
          })
        }

        ListItem() {
          SettingsSliderItem({
            symbol: $r('sys.symbol.forward_end_fill'),
            message: ToolsUtil.getStringResource($r('app.string.skip_intro').id),
            selected: Number(Setting.skipIntroTime),
            textSliderMode: true,
            onChangeComplete: (value: number) => {
              Setting.skipIntroTime = value.toString()
              Preferences.saveSkipIntroTime(PathUtils.appContext!, Setting.skipIntroTime)
            }
          })
        }

        ListItem() {
          SettingsSliderItem({
            symbol: $r('sys.symbol.backward_end_fill'),
            message: ToolsUtil.getStringResource($r('app.string.skip_outro').id),
            selected: Number(Setting.skipOutroTime),
            textSliderMode: true,
            onChangeComplete: (value: number) => {
              Setting.skipOutroTime = value.toString()
              Preferences.saveSkipOutroTime(PathUtils.appContext!, Setting.skipOutroTime)
            }
          })
        }

        ListItem() {
          SettingsSliderItem({
            symbol: $r('sys.symbol.sun_max'),
            message: ToolsUtil.getStringResource($r('app.string.default_brightness').id),
            selected: Setting.defaultBrightness,
            min: 0,
            max: 100,
            zeroText: ToolsUtil.getStringResource($r('app.string.display_mode_auto').id),
            valueSuffix: '%',
            onChange: (value: number) => {
              if (value > 0) {
                VideoOperateUtil.setBrightness(value / 100)
              }
            },
            onChangeComplete: (value: number) => {
              Setting.defaultBrightness = value
              Preferences.saveDefaultBrightness(PathUtils.appContext!, value)
              VideoOperateUtil.setBrightness(-1)
            }
          })
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
          mainTitle: $r('app.string.settings_playback'),
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
}
