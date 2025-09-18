import { DefaultDialogShadow } from '../common/DefaultDialogShadow';
import NavigationAddress from '../common/NavigationAddress';
import { EditPasswordDialog } from '../component/Dialog/EditPasswordDialog';
import { SettingsClickItem } from '../component/SettingComponent/SettingsClickItem';
import { SettingSliderItem } from '../component/SettingComponent/SettingSliderItem';
import { SettingsMenuItem } from '../component/SettingComponent/SettingsMenuItem';
import { SettingsToggleItem } from '../component/SettingComponent/SettingsToggleItem';
import Preferences from '../database/Preferences';
import { FastForwardSecondInterface } from '../interfaces/FastForwardSecondInterface';
import BiometricAccessUtil from '../utils/BiometricAccessUtil';
import { PathUtils } from '../utils/PathUtils';
import ToolsUtil from '../utils/ToolsUtil';
import VideoInfoUtil from '../utils/VideoInfoUtil';

@Component
export struct SettingsPage { //设置页
  @StorageProp('topSafeHeight') topSafeHeight: number = 0;
  @StorageProp('bottomSafeHeight') bottomSafeHeight: number = 0;
  @StorageLink('allowBackgroundPlay') allowBackgroundPlay: boolean = true
  @StorageLink('allowPlayBackExist') allowPlayBackExist: boolean = false
  @StorageLink('allowDoubleFastForward') allowDoubleFastForward: boolean = true
  @StorageLink('fastForwardSeconds') fastForwardSeconds: string = '15'
  @StorageLink('skipIntroTime') skipIntroTime: string = '0'
  @StorageLink('recentPlay') recentPlay: boolean = true
  @StorageLink('defaultPlayer') defaultPlayer: string = 'FFMpeg播放器'
  @StorageLink('subtitleSize') subtitleSize: string = '22'
  @StorageLink('isListDisplay') isListDisplay: boolean = true
  @StorageLink('smartRotation') smartRotation: boolean = true
  @StorageLink('longPressSpeed') longPressSpeed: number = 3
  @State passwd: string = 'passwd'
  @Consume('pathStack') pathStack: NavPathStack
  editPasswdDialogController: CustomDialogController = new CustomDialogController({
    builder: EditPasswordDialog({
      confirm: (passwd: string | undefined) => {
        if (!passwd || passwd.trim() == '') {
          return
        }
        this.passwd = passwd
        ToolsUtil.savePwd(PathUtils.appContext!, passwd)
        ToolsUtil.showToast(PathUtils.appContext!.resourceManager.getStringSync($r('app.string.set_passwd_tip')))
        this.pathStack.replacePathByName(NavigationAddress.PRIVACY_SPACE, null)
      },
    }), cornerRadius: 20, shadow: DefaultDialogShadow
  })
  private listDisplayMode = ['列表布局', '卡片布局']
  private subtitleSizeList = ['19', '20', '21', '22', '23', '24', '25', '26']
  private fastForwardSecond: FastForwardSecondInterface[] = [
    { label: '5秒', value: '5' },
    { label: '10秒', value: '10' },
    { label: '15秒', value: '15' },
    { label: '30秒', value: '30' },
    { label: '60秒', value: '60' },
    { label: '120秒', value: '120' }
  ];
  private playerList = ['系统播放器', 'FFMpeg播放器', '红薯播放器']

  build() {
    NavDestination() {
      List() {
        ListItem() {
          SettingsClickItem({
            symbol: $r('sys.symbol.info_circle'),
            message: '关于此应用',
            onPress: () => {
              this.pathStack.pushPathByName(NavigationAddress.ABOUT_PAGE, true)
            }
          })
        }

        ListItem() {
          SettingsClickItem({
            symbol: $r('sys.symbol.lock'),
            message: $r('app.string.privacy_space'),
            onPress: async () => {
              this.passwd = Preferences.getPassword(PathUtils.appContext!)
              if (this.passwd === '') { // 未设置密码时直接打开设置弹窗
                this.editPasswdDialogController.open();
                return;
              }
              if (BiometricAccessUtil.checkUserAuthSupport()) { // 支持生物认证时进行认证
                const isSuccess = await BiometricAccessUtil.startUserAuth();
                if (isSuccess) { // 认证成功进入隐私空间
                  this.pathStack.replacePathByName(NavigationAddress.PRIVACY_SPACE, null);
                  return;
                }
                ToolsUtil.showToast('验证失败，请从首页搜索框输入密码进入隐私空间'); // 认证失败显示提示
                return;
              }
              ToolsUtil.showToast('请从首页搜索框输入密码进入隐私空间'); // 设备不支持生物认证的提示
            }
          })
        }

        ListItem() {
          SettingsToggleItem({
            symbol: $r('sys.symbol.play'),
            message: '后台播放',
            enable: this.allowBackgroundPlay,
            onChange: (checked: boolean) => {
              this.allowBackgroundPlay = checked
              Preferences.saveAllowBackgroundPlayState(PathUtils.appContext!, this.allowBackgroundPlay)
            }
          })
        }

        ListItem() {
          SettingsToggleItem({
            symbol: $r('sys.symbol.arrow_left'),
            message: '播放时返回隐藏状态栏',
            enable: !this.allowPlayBackExist,
            onChange: (checked: boolean) => {
              this.allowPlayBackExist = !checked
              Preferences.saveAllowPlayBackExistState(PathUtils.appContext!, this.allowPlayBackExist)
            }
          })
        }

        ListItem() {
          SettingsToggleItem({
            symbol: $r('sys.symbol.screen_rotation'),
            message: '智能横屏',
            enable: this.smartRotation,
            onChange: (checked: boolean) => {
              this.smartRotation = checked
              Preferences.saveSmartRotation(PathUtils.appContext!, this.smartRotation)
            }
          })
        }

        ListItem() {
          SettingsToggleItem({
            symbol: $r('sys.symbol.doc_text_badge_clock'),
            message: '开启历史记录',
            enable: this.recentPlay,
            onChange: async (checked: boolean) => {
              this.recentPlay = checked
              if (!this.recentPlay) {
                Preferences.saveRecentPlay(PathUtils.appContext!, [])
              }
              Preferences.saveRecentPlayState(PathUtils.appContext!, this.recentPlay)
            }
          })
        }

        ListItem() {
          SettingsToggleItem({
            symbol: $r('sys.symbol.hand_draw'),
            message: '启用双击屏幕两边快进（后退）',
            enable: this.allowDoubleFastForward,
            onChange: (checked: boolean) => {
              this.allowDoubleFastForward = checked
              Preferences.saveAllowDoubleFastForwardState(PathUtils.appContext!, this.allowDoubleFastForward)
            }
          })
        }

        ListItem() {
          SettingsMenuItem({
            symbol: $r('sys.symbol.hand_point_up_tap'),
            message: '快进快退时长',
            list: this.fastForwardSecond.map(opt => opt.label),
            selected: this.fastForwardSecond.findIndex(opt => opt.value === this.fastForwardSeconds),
            onChange: (index: number) => {
              this.fastForwardSeconds = this.fastForwardSecond[index].value;
              Preferences.saveFastForwardSeconds(PathUtils.appContext!, this.fastForwardSeconds)
            }
          })
        }

        ListItem() {
          SettingsMenuItem({
            symbol: $r('sys.symbol.square_fill_grid_2x2'),
            message: '列表布局',
            list: this.listDisplayMode,
            selected: this.isListDisplay ? 0 : 1,
            onChange: (index: number) => {
              this.isListDisplay = (index === 0);
              Preferences.saveListDisplayMode(PathUtils.appContext!, this.isListDisplay);
            }
          })
        }

        ListItem() {
          SettingsMenuItem({
            symbol: $r('sys.symbol.fast_forward'),
            message: '长按快进倍速',
            list: VideoInfoUtil.getVideoSpeedTextList(),
            selected: VideoInfoUtil.getVideoSpeedList(NavigationAddress.AV_PLAYER)
              .findIndex(opt => opt === this.longPressSpeed),
            onChange: (index: number) => {
              this.longPressSpeed = VideoInfoUtil.getVideoSpeedList(NavigationAddress.AV_PLAYER)[index]
              Preferences.saveLongPressSpeed(PathUtils.appContext!, this.longPressSpeed)
            }
          })
        }

        ListItem() {
          SettingsMenuItem({
            symbol: $r('sys.symbol.play_round_rectangle'),
            message: '外链默认播放器',
            list: this.playerList,
            selected: this.playerList.findIndex(i => i == this.defaultPlayer),
            onChange: (index: number) => {
              this.defaultPlayer = this.playerList[index]
              Preferences.saveDefaultPlayer(PathUtils.appContext!, this.defaultPlayer)
            }
          })
        }

        ListItem() {
          SettingsMenuItem({
            symbol: $r('sys.symbol.textformat_size_square'),
            message: '字幕字体大小',
            list: this.subtitleSizeList,
            selected: this.subtitleSizeList.findIndex(i => i == this.subtitleSize),
            onChange: (index: number) => {
              this.subtitleSize = this.subtitleSizeList[index]
              Preferences.saveSubtitleSize(PathUtils.appContext!, this.subtitleSize)
            }
          })
        }

        ListItem() {
          SettingSliderItem({
            symbol: $r('sys.symbol.forward_end_fill'),
            message: '跳过片头',
            selected: Number(this.skipIntroTime),
            onChangeComplete: (value: number) => {
              this.skipIntroTime = value.toString()
              Preferences.saveSkipIntroTime(PathUtils.appContext!, this.skipIntroTime)
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
      .contentEndOffset(this.bottomSafeHeight)
    }.hideToolBar(true).title('设置')
    .backgroundColor($r('app.color.start_window_background'))
    .padding({ top: this.topSafeHeight })
  }
}