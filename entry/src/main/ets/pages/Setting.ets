import { DefaultDialogShadow } from '../common/DefaultDialogShadow';
import { editPasswordDialog } from '../component/Dialog/EditPasswordDialog';
import { SettingsMenuItem } from '../component/SettingComponent/SettingsMenuItem';
import { SettingsToggleItem } from '../component/SettingComponent/SettingsToggleItem';
import { SettingTimeItem } from '../component/SettingComponent/SettingTimeItem';
import Preferences from '../database/Preferences';
import { SymbolGlyphFancyModifier } from '../utils/AttributeModifierUtil';
import BiometricAccessUtil from '../utils/BiometricAccessUtil';
import { PathUtils } from '../utils/PathUtils';
import ToolsUtil from '../utils/ToolsUtil';

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
  @StorageLink('is_list_display') is_list_display: boolean = true
  @State passwd: string = 'passwd'
  fastForwardSecondsList = ['15', '30', '60', '120']
  subtitleSizeList = ['19', '20', '21', '22', '23', '24', '25', '26']
  @Consume('pathStack') pathStack: NavPathStack
  editPasswdDialogController: CustomDialogController = new CustomDialogController({
    builder: editPasswordDialog({
      confirm: (passwd: string | undefined) => {
        if (!passwd || passwd.trim() == '') {
          return
        }
        this.passwd = passwd
        ToolsUtil.savePwd(PathUtils.appContext!, passwd)
        ToolsUtil.showToast(PathUtils.appContext!.resourceManager.getStringSync($r('app.string.set_passwd_tip')))
        this.pathStack.replacePathByName('PrivacySpace', null)
      },
    }), cornerRadius: 20, shadow: DefaultDialogShadow
  })

  build() {
    NavDestination() {
      List() {
        ListItem() {
          SettingsClickItem({
            symbol: $r('sys.symbol.info_circle'),
            message: '关于此应用',
            onPress: () => {
              this.pathStack.pushPathByName('AboutPage', true)
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
                  this.pathStack.replacePathByName('PrivacySpace', null);
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
            symbol: $r('sys.symbol.list_square'),
            message: '列表样式（关闭为卡片样式）',
            enable: this.is_list_display,
            onChange: (checked: boolean) => {
              this.is_list_display = checked
              Preferences.saveListDisplayMode(PathUtils.appContext!, this.is_list_display)
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
            message: '播放器使用返回手势时直接退出',
            enable: this.allowPlayBackExist,
            onChange: (checked: boolean) => {
              this.allowPlayBackExist = checked
              Preferences.saveAllowPlayBackExistState(PathUtils.appContext!, this.allowPlayBackExist)
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
            symbol: $r('sys.symbol.fast_forward'),
            message: '快进快退时长',
            list: ['15秒', '30秒', '60秒', '120秒'],
            selected: ['15', '30', '60', '120'].findIndex(i => i == this.fastForwardSeconds),
            onChange: (index: number) => {
              this.fastForwardSeconds = ['15', '30', '60', '120'][index]
              Preferences.saveFastForwardSeconds(PathUtils.appContext!, this.fastForwardSeconds)
            }
          })
        }

        ListItem() {
          SettingTimeItem({
            symbol: $r('sys.symbol.forward_end_fill'),
            message: '跳过片头',
            selected: Number(this.skipIntroTime),
            onChange: (value: number) => {
              ToolsUtil.startVibration()
              this.skipIntroTime = value.toString()
              Preferences.saveSkipIntroTime(PathUtils.appContext!, this.skipIntroTime)
            }
          })
        }

        ListItem() {
          SettingsMenuItem({
            symbol: $r('sys.symbol.play_round_rectangle'),
            message: '外链默认播放器',
            list: ['系统播放器', 'FFMpeg播放器', '红薯播放器'],
            selected: ['系统播放器', 'FFMpeg播放器', '红薯播放器'].findIndex(i => i == this.defaultPlayer),
            onChange: (index: number) => {
              this.defaultPlayer = ['系统播放器', 'FFMpeg播放器', '红薯播放器'][index]
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

@Component
export struct SettingsClickItem {
  @State symbol: Resource | undefined = undefined
  @State message: ResourceStr = ''
  @StorageProp('disable_blur') disable_blur: boolean = false
  @Prop showArrow: boolean = true
  @StorageProp('vipState') vipState: boolean = false
  onPress = () => {
  }
  onLongPress = () => {
  }

  build() {
    Button({ type: ButtonType.Normal, stateEffect: true }) {

      Flex({ justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Center }) {
        Row({ space: 10 }) {
          if (this.symbol) {
            SymbolGlyph(this.symbol)
              .attributeModifier(new SymbolGlyphFancyModifier(22, '', ''))
              .visibility(this.symbol ? Visibility.Visible : Visibility.None)
          } else {
            Stack()
          }
          Text(this.message)
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.MARQUEE })
            .layoutWeight(1)
        }.layoutWeight(1)

        if (this.showArrow) {
          SymbolGlyph($r('sys.symbol.chevron_right'))
            .attributeModifier(new SymbolGlyphFancyModifier(22, '', ''))
            .margin(5)
        }

      }.align(Alignment.Center)

    }
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
    .onClick(() => {
      this.onPress()
    })
    .gesture(LongPressGesture().onAction(() => {
      this.onLongPress()
    }))
    .backgroundColor($r('app.color.start_window_background_blur'))
    .height(55)
    .borderRadius(16)
    .padding({
      right: 15,
      left: 15,
      top: 10,
      bottom: 10
    })
    .margin({ top: 5, bottom: 5 })
  }
}