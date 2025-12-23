import NavigationAddress from '../../common/NavigationCommon';
import { EditPasswordDialog } from '../../component/Dialog/EditPasswordDialog';
import { SettingsClickItem } from '../../component/SettingComponent/SettingsClickItem';
import { SettingsToggleItem } from '../../component/SettingComponent/SettingsToggleItem';
import Preferences from '../../database/Preferences';
import BiometricAccessUtil from '../../utils/BiometricAccessUtil';
import { PathUtils } from '../../utils/PathUtils';
import ToolsUtil from '../../utils/ToolsUtil';
import { SettingsCheckboxItem } from '../../component/SettingComponent/SettingsCheckboxItem';
import { DefaultDialogShadow } from '../../common/AttributeModifierConfig';
import { SafeHeight, Setting } from '../../utils/ObservedUtil';
import { Markdown, MarkdownController } from '@luvi/lv-markdown-in';
import { salmonLogger } from 'salmonlogger';

@Component
export struct SettingsPage { //设置页
  @State passwd: string = 'passwd'
  @Consume('pathStack') pathStack: NavPathStack
  controller: MarkdownController = new MarkdownController()
  editPasswdDialogController: CustomDialogController = new CustomDialogController({
    builder: EditPasswordDialog({
      confirm: (passwd: string | undefined) => {
        if (!passwd || passwd.trim() == '') {
          return
        }
        this.passwd = passwd
        ToolsUtil.savePwd(PathUtils.appContext!, passwd)
        ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.set_passwd_tip').id))
        this.pathStack.replacePathByName(NavigationAddress.PRIVACY_SPACE, { "needGotoSetting": true })
      },
    }), cornerRadius: 20, shadow: DefaultDialogShadow
  })
  private listDisplayModeList: ResourceStr[] = ['卡片', '列表', '网格']

  aboutToAppear(): void {
    this.controller
      .setTitleColor($r("app.color.text_color"))
      .setTextColor($r("app.color.text_color"))
      .setTableTitleBackgroundColor($r('app.color.start_window_background_blur'))
      .setQuoteBackgroundColor($r('app.color.start_window_background_blur'))
      .setTableBackgroundColor($r('app.color.start_window_background_blur'))
  }

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

        if (Setting.showSettingPageEntry) {
          ListItem() {
            SettingsClickItem({
              symbol: $r('sys.symbol.lock'),
              message: $r('app.string.privacy_space'),
              onPress: async () => {
                this.passwd = Preferences.getPassword(PathUtils.appContext!)
                if (this.passwd.length === 0) { // 未设置密码时直接打开设置弹窗
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
          SettingsClickItem({
            symbol: $r('sys.symbol.square_grid_2x2'),
            message: '更多设置',
            onPress: () => {
              this.pathStack.pushPathByName(NavigationAddress.MORE_SETTING_PAGE, true)
            }
          })
        }

        ListItem() {
          SettingsCheckboxItem({
            symbol: $r('sys.symbol.grid'),
            message: '列表布局',
            tips: this.listDisplayModeList,
            tabSelectedIndexes: [Setting.listDisplayMode],
            onButtonClick: (tabSelectedIndexes: number) => {
              Setting.listDisplayMode = tabSelectedIndexes
              Preferences.saveListDisplayMode(PathUtils.appContext!, tabSelectedIndexes);
            }
          })
        }

        ListItem() {
          SettingsToggleItem({
            symbol: $r('sys.symbol.doc_text_badge_clock'),
            message: '开启历史记录',
            enable: Setting.recentPlay,
            onChange: async (checked: boolean) => {
              Setting.recentPlay = checked
              if (!Setting.recentPlay) {
                Preferences.saveRecentPlay(PathUtils.appContext!, [])
              }
              Preferences.saveRecentPlayState(PathUtils.appContext!, Setting.recentPlay)
            }
          })
        }

        ListItem() {
          Column() {
            Markdown({
              controller: this.controller,
              mode: "rawfile",
              context: PathUtils.appContext!, // 资源文件模式必填参数
              rawfilePath: "Tips.md", // 资源文件地址
              callback: {
                complete: () => {
                  console.log("Markdown component load success.")
                  salmonLogger.addLog(this.pathStack.getAllPathName()[0],
                    "Markdown component load success.", false)
                },
                fail: (code: number, message: string) => {
                  console.error("Markdown component load error. code: " + code + ", message: " + message)
                  salmonLogger.addLog(this.pathStack.getAllPathName()[0],
                    "Markdown component load error. code: " + code + ", message: " + message, true)
                }
              }
            })
          }
          .padding(15)
          .alignItems(HorizontalAlign.Start)
          .borderRadius(16)
          .width('100%')
          .backgroundColor($r('app.color.start_window_background_blur'))
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
    .title('设置')
    .backgroundColor($r('app.color.start_window_background'))
    .padding({ top: SafeHeight.topSafeHeight })
    .backgroundImage(Setting.backgroundImageSrc, ImageRepeat.NoRepeat)
    .backgroundImageSize(ImageSize.Cover)
    .backdropBlur(Setting.backgroundDropBlur)
    .backgroundImagePosition(Alignment.Center)
  }
}