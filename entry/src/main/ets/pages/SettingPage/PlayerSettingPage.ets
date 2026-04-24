import { SettingsSegmentButtonItem } from '../../component/SettingComponent/SettingsSegmentButtonItem'
import { SettingsSliderItem } from '../../component/SettingComponent/SettingsSliderItem'
import { SettingsMenuItem } from '../../component/SettingComponent/SettingsMenuItem'
import { SettingsToggleItem } from '../../component/SettingComponent/SettingsToggleItem'
import { MpvDecodingMethod } from '../../controller/MpvController/MpvTypes'
import Preferences from '../../database/Preferences'
import { FastForwardSecondInterface } from '../../interfaces/FastForwardSecondInterface'
import { SafeHeight, Setting } from '../../utils/ObservedUtil'
import { PathUtils } from '../../utils/PathUtils'
import VideoInfoUtil from '../../utils/VideoInfoUtil'

@ComponentV2
export struct PlayerSettingPage {
  private subtitleSizeList = ['19', '20', '21', '22', '23', '24', '25', '26']
  private fastForwardSecond: FastForwardSecondInterface[] = [
    { label: '5秒', value: '5' },
    { label: '10秒', value: '10' },
    { label: '15秒', value: '15' },
    { label: '30秒', value: '30' },
    { label: '60秒', value: '60' },
    { label: '120秒', value: '120' }
  ]

  build() {
    NavDestination() {
      List() {
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
            message: '自动跳转到上次播放时间',
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
          SettingsMenuItem({
            symbol: $r('sys.symbol.textformat_size_square'),
            message: '字幕字体大小',
            list: this.subtitleSizeList,
            selected: this.subtitleSizeList.findIndex(i => i == Setting.subtitleSize),
            onChange: (index: number) => {
              Setting.subtitleSize = this.subtitleSizeList[index]
              Preferences.saveSubtitleSize(PathUtils.appContext!, Setting.subtitleSize)
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
    .title('播放设置')
    .backgroundColor($r('app.color.start_window_background'))
    .padding({ top: SafeHeight.topSafeHeight })
    .backgroundImage(Setting.backgroundImageSrc, ImageRepeat.NoRepeat)
    .backgroundImageSize(ImageSize.Cover)
    .backdropBlur(Setting.backgroundDropBlur)
    .backgroundImagePosition(Alignment.Center)
  }

  private getMPVDecodeInfo(decodingMethod: MpvDecodingMethod) {
    switch (decodingMethod) {
      case MpvDecodingMethod.HARDWARE_BUFFER:
        return '功耗低但少部分视频异常'
      case MpvDecodingMethod.SOFTWARE:
        return '功耗高，画面一般正常'
      case MpvDecodingMethod.HARDWARE_SURFACE:
        return '性能最佳，不支持杜比P5'
      default:
        return 'Unknown'
    }
  }
}