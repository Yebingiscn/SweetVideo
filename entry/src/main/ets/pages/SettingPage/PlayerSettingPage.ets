import { SettingsMenuItem } from '../../component/SettingComponent/SettingsMenuItem'
import { SettingsSegmentButtonItem } from '../../component/SettingComponent/SettingsSegmentButtonItem'
import { SettingsSliderItem } from '../../component/SettingComponent/SettingsSliderItem'
import { SettingsToggleItem } from '../../component/SettingComponent/SettingsToggleItem'
import { SettingsSectionHeaderBuilder } from '../../component/SettingComponent/SettingsSectionHeader'
import { MpvController } from '../../controller/MpvController/MpvController'
import { MpvDecodingMethod, MpvGpuApi } from '../../controller/MpvController/MpvTypes'
import Preferences from '../../database/Preferences'
import { FastForwardSecondInterface } from '../../interfaces/FastForwardSecondInterface'
import AVSessionUtil from '../../utils/AVSessionUtil'
import { SafeHeight, Setting } from '../../utils/ObservedUtil'
import { PathUtils } from '../../utils/PathUtils'
import VideoInfoUtil from '../../utils/VideoInfoUtil'
import VideoOperateUtil from '../../utils/VideoOperateUtil'
import { LengthMetrics } from '@kit.ArkUI'
import { hdsMaterial, HdsNavDestination, ScrollEffectType } from '@kit.UIDesignKit'

@ComponentV2
export struct PlayerSettingPage {
  private fastForwardSecond: FastForwardSecondInterface[] = [
    { label: '5秒', value: '5' },
    { label: '10秒', value: '10' },
    { label: '15秒', value: '15' },
    { label: '30秒', value: '30' },
    { label: '60秒', value: '60' },
    { label: '120秒', value: '120' }
  ]
  private listScroller: Scroller = new Scroller()

  build() {
    HdsNavDestination() {
      List({ scroller: this.listScroller }) {
        ListItem() {
          SettingsSectionHeaderBuilder('基础播放', '后台、小窗与返回行为')
        }

        ListItem() {
          SettingsToggleItem({
            symbol: $r('sys.symbol.play'),
            message: '后台播放',
            enable: Setting.allowBackgroundPlay,
            onChange: (checked: boolean) => {
              Setting.allowBackgroundPlay = checked
              Preferences.saveAllowBackgroundPlayState(PathUtils.appContext!, Setting.allowBackgroundPlay)
            }
          })
        }

        ListItem() {
          SettingsToggleItem({
            symbol: $r('sys.symbol.play_gobackward'),
            message: '与其他应用同时播放',
            tag: '试用',
            enable: Setting.allowConcurrentPlay,
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
            message: '回到后台自动启用小窗',
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
            message: '从后台返回自动播放',
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
            message: '播放时返回隐藏状态栏',
            enable: !Setting.allowPlayBackExist,
            onChange: (checked: boolean) => {
              Setting.allowPlayBackExist = !checked
              Preferences.saveAllowPlayBackExistState(PathUtils.appContext!, Setting.allowPlayBackExist)
            }
          })
        }

        ListItem() {
          SettingsSectionHeaderBuilder('解码与画质', '播放引擎、MPV 解码与画质增强')
        }

        ListItem() {
          SettingsMenuItem({
            symbol: $r('sys.symbol.play_round_rectangle'),
            message: '默认播放引擎',
            list: VideoInfoUtil.playerEngineList,
            selected: Math.max(VideoInfoUtil.playerEngineList.findIndex(i => i == Setting.defaultPlayerEngine), 0),
            onChange: (index: number) => {
              Setting.defaultPlayerEngine = VideoInfoUtil.playerEngineList[index]
              Preferences.saveDefaultPlayerEngine(PathUtils.appContext!, Setting.defaultPlayerEngine)
            }
          })
        }

        ListItem() {
          SettingsSegmentButtonItem({
            symbol: $r('sys.symbol.hardware'),
            message: 'MPV 解码：' + this.getMPVDecodeInfo(Setting.mpvDecodingMethod),
            tips: ['硬解（Surface）', '软解', '硬解（Buffer）'],
            tabSelectedIndex: Setting.mpvDecodingMethod,
            onButtonClick: (tabSelectedIndex: number) => {
              Setting.mpvDecodingMethod = tabSelectedIndex
              Preferences.saveMpvDecodingMethod(PathUtils.appContext!, tabSelectedIndex)
            }
          })
        }

        ListItem() {
          SettingsSegmentButtonItem({
            symbol: $r('sys.symbol.rays'),
            message: 'MPV GPU 后端（Buffer 模式）',
            tips: ['OpenGL', 'Vulkan'],
            tabSelectedIndex: Setting.mpvGpuApi,
            onButtonClick: (tabSelectedIndex: number) => {
              Setting.mpvGpuApi = tabSelectedIndex as MpvGpuApi
              Preferences.saveMpvGpuApi(PathUtils.appContext!, Setting.mpvGpuApi)
            }
          })
        }

        ListItem() {
          SettingsSegmentButtonItem({
            symbol: $r('sys.symbol.wand_and_stars'),
            message: 'MPV 画质增强（Surface 模式下不可用）',
            tips: MpvController.getShaderModeNames(),
            tabSelectedIndex: Setting.mpvShaderMode,
            onButtonClick: (tabSelectedIndex: number) => {
              Setting.mpvShaderMode = tabSelectedIndex
              Preferences.saveMpvShaderMode(PathUtils.appContext!, tabSelectedIndex)
            }
          })
        }

        ListItem() {
          SettingsSectionHeaderBuilder('播放体验', '显示方式、横屏与进度记录')
        }

        ListItem() {
          SettingsToggleItem({
            symbol: $r('sys.symbol.music_note_phone'),
            message: '短视频模式',
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
            message: '智能横屏',
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
            message: '展示进度条预览图',
            enable: Setting.showFrameImgStatus,
            onChange: (checked: boolean) => {
              Setting.showFrameImgStatus = checked
              Preferences.saveShowFrameTime(PathUtils.appContext!, Setting.showFrameImgStatus)
            }
          })
        }

        ListItem() {
          SettingsToggleItem({
            symbol: $r('sys.symbol.camera_master_ai'),
            message: '视频超分辨率',
            enable: Setting.superResolutionState,
            onChange: (checked: boolean) => {
              Setting.superResolutionState = checked
              Preferences.saveSuperResolutionState(PathUtils.appContext!, Setting.superResolutionState)
            }
          })
        }

        ListItem() {
          SettingsToggleItem({
            symbol: $r('sys.symbol.pin'),
            message: '记住播放进度',
            enable: Setting.jumpToHistoryTimeStatus,
            onChange: (checked: boolean) => {
              Setting.jumpToHistoryTimeStatus = checked
              Preferences.saveJumpToHistoryTime(PathUtils.appContext!, Setting.jumpToHistoryTimeStatus)
            }
          })
        }

        ListItem() {
          SettingsSectionHeaderBuilder('手势与默认值', '快进、片头片尾与默认亮度')
        }

        ListItem() {
          Column() {
            SettingsToggleItem({
              symbol: $r('sys.symbol.hand_draw'),
              message: '启用双击屏幕两边快进快退',
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
              message: '快进快退时长',
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
            message: '长按快进倍速',
            list: VideoInfoUtil.getVideoSpeedTextList(),
            selected: VideoInfoUtil.videoSpeedListAll.findIndex(opt => opt === Setting.longPressSpeed),
            onChange: (index: number) => {
              Setting.longPressSpeed = VideoInfoUtil.videoSpeedListAll[index]
              Preferences.saveLongPressSpeed(PathUtils.appContext!, Setting.longPressSpeed)
            }
          })
        }

        ListItem() {
          SettingsSliderItem({
            symbol: $r('sys.symbol.forward_end_fill'),
            message: '跳过片头',
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
            message: '跳过片尾',
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
            message: '默认亮度',
            selected: Setting.defaultBrightness,
            min: 0,
            max: 100,
            zeroText: '自动',
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
          mainTitle: '播放设置',
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
    .bindToScrollable([this.listScroller]) // 绑定导航组件和可滚动容器组件
  }

  private getMPVDecodeInfo(decodingMethod: MpvDecodingMethod) {
    switch (decodingMethod) {
      case MpvDecodingMethod.HARDWARE_BUFFER:
        return '支持杜比P5，性能稍差'
      case MpvDecodingMethod.SOFTWARE:
        return '画面兼容最佳，功耗高'
      case MpvDecodingMethod.HARDWARE_SURFACE:
        return '性能最佳，不支持杜比P5'
      default:
        return 'Unknown'
    }
  }
}
