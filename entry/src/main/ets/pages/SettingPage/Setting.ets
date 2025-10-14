import { DefaultDialogShadow } from '../../common/DefaultDialogShadow';
import NavigationAddress from '../../common/NavigationAddress';
import { EditPasswordDialog } from '../../component/Dialog/EditPasswordDialog';
import { SettingsClickItem } from '../../component/SettingComponent/SettingsClickItem';
import { SettingsMenuItem } from '../../component/SettingComponent/SettingsMenuItem';
import { SettingsToggleItem } from '../../component/SettingComponent/SettingsToggleItem';
import Preferences from '../../database/Preferences';
import BiometricAccessUtil from '../../utils/BiometricAccessUtil';
import { PathUtils } from '../../utils/PathUtils';
import ToolsUtil from '../../utils/ToolsUtil';

@Component
export struct SettingsPage { //设置页
  @StorageProp('topSafeHeight') topSafeHeight: number = 0;
  @StorageProp('bottomSafeHeight') bottomSafeHeight: number = 0;
  @StorageLink('recentPlay') recentPlay: boolean = true
  @StorageLink('isListDisplay') isListDisplay: boolean = true
  @StorageLink('backgroundImageSrc') backgroundImageSrc: string = ''
  @StorageLink('backgroundDropBlur') backgroundDropBlur: number = 0
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
        ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.set_passwd_tip').id))
        this.pathStack.replacePathByName(NavigationAddress.PRIVACY_SPACE, null)
      },
    }), cornerRadius: 20, shadow: DefaultDialogShadow
  })
  private listDisplayMode = ['列表布局', '卡片布局']

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
          SettingsClickItem({
            symbol: $r('sys.symbol.doc_plaintext'),
            message: '崩溃日志',
            onPress: () => {
              this.pathStack.pushPathByName(NavigationAddress.CRASH_PAGE, true)
            }
          })
        }

        ListItem() {
          SettingsClickItem({
            symbol: $r('sys.symbol.paintpalette'),
            message: '个性化',
            onPress: () => {
              this.pathStack.pushPathByName(NavigationAddress.PERSONALIZE_PAGE, true)
            }
          })
        }

        ListItem() {
          SettingsClickItem({
            symbol: $r('sys.symbol.play_round_rectangle'),
            message: '播放设置',
            onPress: () => {
              this.pathStack.pushPathByName(NavigationAddress.PLAYER_SETTING_PAGE, true)
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
    .title('设置')
    .backgroundColor($r('app.color.start_window_background'))
    .padding({ top: this.topSafeHeight })
    .backgroundImage(this.backgroundImageSrc, ImageRepeat.NoRepeat)
    .backgroundImageSize(ImageSize.Cover)
    .backdropBlur(this.backgroundDropBlur)
  }
}