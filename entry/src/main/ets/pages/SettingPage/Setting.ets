import { DefaultDialogShadow } from '../../common/DefaultDialogShadow';
import NavigationAddress from '../../common/NavigationCommon';
import { EditPasswordDialog } from '../../component/Dialog/EditPasswordDialog';
import { SettingsClickItem } from '../../component/SettingComponent/SettingsClickItem';
import { SettingsToggleItem } from '../../component/SettingComponent/SettingsToggleItem';
import Preferences from '../../database/Preferences';
import BiometricAccessUtil from '../../utils/BiometricAccessUtil';
import { PathUtils } from '../../utils/PathUtils';
import ToolsUtil from '../../utils/ToolsUtil';
import { SettingsCheckboxItem } from '../../component/SettingComponent/SettingsCheckboxItem';
import { ListDisplayMode } from '../../common/enum/ListDisplayMode';

@Component
export struct SettingsPage { //设置页
  @StorageProp('topSafeHeight') topSafeHeight: number = 0;
  @StorageProp('bottomSafeHeight') bottomSafeHeight: number = 0;
  @StorageLink('recentPlay') recentPlay: boolean = true
  @StorageLink('listDisplayMode') listDisplayMode: ListDisplayMode = ListDisplayMode.LIST_DISPLAY
  @StorageLink('backgroundImageSrc') backgroundImageSrc: string = ''
  @StorageLink('backgroundDropBlur') backgroundDropBlur: number = 0
  @StorageLink('showSettingPageEntry') showSettingPageEntry: boolean = true
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
        this.pathStack.replacePathByName(NavigationAddress.PRIVACY_SPACE, { "needGotoSetting": true })
      },
    }), cornerRadius: 20, shadow: DefaultDialogShadow
  })
  private listDisplayModeList: ResourceStr[] = ['卡片', '列表', '网格']

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

        if (this.showSettingPageEntry) {
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
            symbol: $r('sys.symbol.more'),
            message: '更多设置',
            onPress: () => {
              this.pathStack.pushPathByName(NavigationAddress.MORE_SETTING_PAGE, true)
            }
          })
        }

        ListItem() {
          SettingsCheckboxItem({
            symbol: $r('sys.symbol.square_fill_grid_2x2'),
            message: '列表布局',
            tips: this.listDisplayModeList,
            tabSelectedIndexes: [this.listDisplayMode],
            onButtonClick: (tabSelectedIndexes: number) => {
              this.listDisplayMode = tabSelectedIndexes
              Preferences.saveListDisplayMode(PathUtils.appContext!, tabSelectedIndexes);
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
          Column() {
            Text('手势操作说明')
              .fontSize(20).fontWeight(FontWeight.Medium)
            Text('1. 左侧 1/5 处 快退 中间暂停 右侧 1/5 处快进')
              .fontSize(15)
            Text('2. 横向滑动调整进度')
              .fontSize(15)
            Text('3. 竖向滑动左侧调节亮度，右侧调节音量')
              .fontSize(15)
            Text('4. 长按倍速，长按并横向滑动调节倍速值')
              .fontSize(15)
            Text('4. 双指缩放调节视频显示大小')
              .fontSize(15)
          }.alignItems(HorizontalAlign.Start).width('100%')
        }
        .margin({ top: 5 })
        .padding(15)
        .borderRadius(16)
        .width('100%')
        .backgroundColor($r('app.color.start_window_background_blur'))

        ListItem() {
          Column() {
            Text('快捷键操作说明')
              .fontSize(20).fontWeight(FontWeight.Medium)
            Text('1. ESC 退出视频')
              .fontSize(15)
            Text('2. 空格暂停视频')
              .fontSize(15)
            Text('3. 方向左键回退')
              .fontSize(15)
            Text('4. 方向右键快进')
              .fontSize(15)
          }.alignItems(HorizontalAlign.Start).width('100%')
        }
        .margin({ top: 10 })
        .padding(15)
        .borderRadius(16)
        .width('100%')
        .backgroundColor($r('app.color.start_window_background_blur'))

        ListItem() {
          Column() {
            Text('如何进入隐私空间')
              .fontSize(20).fontWeight(FontWeight.Medium)
            Text('1. 通过设置页隐私空间进入')
              .fontSize(15)
            Text('2. 通过搜索框输入密码进入')
              .fontSize(15)
            Text('3. 通过首页双指捏合往外划开进入')
              .fontSize(15)
          }.alignItems(HorizontalAlign.Start).width('100%')
        }
        .margin({ top: 10 })
        .padding(15)
        .borderRadius(16)
        .width('100%')
        .backgroundColor($r('app.color.start_window_background_blur'))
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
    .backgroundImagePosition(Alignment.Center)
  }
}