import NavigationAddress from '../../common/NavigationCommon'
import { SettingSliderItem } from '../../component/SettingComponent/SettingSliderItem'
import { SettingsMenuItem } from '../../component/SettingComponent/SettingsMenuItem'
import { SettingsToggleItem } from '../../component/SettingComponent/SettingsToggleItem'
import Preferences from '../../database/Preferences'
import { FastForwardSecondInterface } from '../../interfaces/FastForwardSecondInterface'
import { SafeHeight, Setting } from '../../utils/ObservedUtil'
import { PathUtils } from '../../utils/PathUtils'
import VideoInfoUtil from '../../utils/VideoInfoUtil'

@Component
export struct PlayerSettingPage {
  private subtitleSizeList = ['19', '20', '21', '22', '23', '24', '25', '26']
  private playerList = ['系统播放器', 'FFMpeg播放器', '红薯播放器', 'MPV播放器']
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
            symbol: $r('sys.symbol.hand_draw'),
            message: '启用双击屏幕两边快进快退',
            enable: Setting.allowDoubleFastForward,
            onChange: (checked: boolean) => {
              Setting.allowDoubleFastForward = checked
              Preferences.saveAllowDoubleFastForwardState(PathUtils.appContext!, Setting.allowDoubleFastForward)
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

        ListItem() {
          SettingsMenuItem({
            symbol: $r('sys.symbol.fast_forward'),
            message: '长按快进倍速',
            list: VideoInfoUtil.getVideoSpeedTextList(),
            selected: VideoInfoUtil.getVideoSpeedList(NavigationAddress.AV_PLAYER)
              .findIndex(opt => opt === Setting.longPressSpeed),
            onChange: (index: number) => {
              Setting.longPressSpeed = VideoInfoUtil.getVideoSpeedList(NavigationAddress.AV_PLAYER)[index]
              Preferences.saveLongPressSpeed(PathUtils.appContext!, Setting.longPressSpeed)
            }
          })
        }

        ListItem() {
          SettingsMenuItem({
            symbol: $r('sys.symbol.play_round_rectangle'),
            message: '外链默认播放器',
            list: this.playerList,
            selected: this.playerList.findIndex(i => i == Setting.defaultPlayer),
            onChange: (index: number) => {
              Setting.defaultPlayer = this.playerList[index]
              Preferences.saveDefaultPlayer(PathUtils.appContext!, Setting.defaultPlayer)
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
          SettingSliderItem({
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
}