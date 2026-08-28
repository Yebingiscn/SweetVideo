import NavigationAddress from '../../common/NavigationCommon'
import { EditPasswordDialog } from '../../component/Dialog/EditPasswordDialog'
import { PathUtils } from '../../utils/PathUtils'
import ToolsUtil from '../../utils/ToolsUtil'
import { DefaultDialogShadow, ImageFancyModifier } from '../../common/AttributeModifierConfig'
import { SettingsClickItem } from '../../component/SettingComponent/SettingsClickItem'
import { SettingsSectionHeaderBuilder } from '../../component/SettingComponent/SettingsSectionHeader'
import Preferences from '../../database/Preferences'
import BiometricAccessUtil from '../../utils/BiometricAccessUtil'
import { Setting } from '../../utils/ObservedUtil'
import { LengthMetrics } from '@kit.ArkUI'
import { hdsMaterial, HdsNavDestination, ScrollEffectType } from '@kit.UIDesignKit'
import { IapVerifyUtil } from '../../utils/IapVerifyUtil'
import { userData } from '../../component/common/UserLoginComponent'

@ComponentV2
export struct SettingsPage { //设置页
  @Local passwd: string = 'passwd'
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
  @Local showVipPage: boolean = true
  @Consumer('pathStack') pathStack: NavPathStack = new NavPathStack()
  private listScroller: Scroller = new Scroller()

  async aboutToAppear(): Promise<void> {
    this.showVipPage = await IapVerifyUtil.queryEnvironmentStatus()
  }

  build() {
    HdsNavDestination() {
      List({ scroller: this.listScroller }) {
        if (this.showVipPage) {
          ListItem() {
            Button({ type: ButtonType.Normal, stateEffect: true }) {
              Row({ space: 12 }) {
                Image(userData.userAvatar || $r('app.media.Foreground'))
                  .attributeModifier(new ImageFancyModifier(22, 42, 42))
                Text(userData.isLogin ? (userData.nickName || '已登录') : '未登录')
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Color.White)
                  .textOverflow({ overflow: TextOverflow.MARQUEE })
                  .maxLines(1)
                  .layoutWeight(1)
                  .constraintSize({ maxWidth: '80%' })

                Row({ space: 4 }) {
                  SymbolGlyph($r('sys.symbol.diamond'))
                    .fontSize(18)
                    .fontColor(['#ffd87c'])
                  Text('VIP')
                    .fontSize(20)
                    .fontColor('#ffd87c')
                    .fontWeight(FontWeight.Bold)
                }
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)
            }
            .height(78)
            .borderRadius(16)
            .padding({ left: 14, right: 14 })
            .linearGradient({
              direction: GradientDirection.Right,
              colors: userData.isVip ?
                [['#FFD87C', 0], [$r('app.color.main_color'), 1]] :
                [[$r('app.color.main_color'), 0], ['#4A2C7D', 1]]
            })
            .shadow({
              radius: 6,
              color: userData.isVip ? '#33ffd87c' : $r('app.color.shadow_color'),
              offsetX: 0,
              offsetY: 2
            })
            .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
            .onClick(() => {
              this.pathStack.pushPathByName(NavigationAddress.VIP_PAGE, true)
            })
          }
        }

        ListItem() {
          SettingsSectionHeaderBuilder('常用设置', '按功能进入对应设置')
        }

        ListItem() {
          SettingsClickItem({
            symbol: $r('sys.symbol.paintpalette'),
            message: '外观与首页',
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
            symbol: $r('sys.symbol.textformat_size_square'),
            message: '字幕样式',
            onPress: () => {
              this.pathStack.pushPathByName(NavigationAddress.SUBTITLE_SETTING_PAGE, true)
            }
          })
        }

        ListItem() {
          SettingsClickItem({
            symbol: $r('sys.symbol.square_grid_2x2'),
            message: '应用与支持',
            onPress: () => {
              this.pathStack.pushPathByName(NavigationAddress.MORE_SETTING_PAGE, true)
            }
          })
        }

        if (Setting.showSettingPageEntry) {
          ListItem() {
            SettingsSectionHeaderBuilder('隐私与安全', '保护私密内容与访问权限')
          }

          ListItem() {
            SettingsClickItem({
              symbol: $r('sys.symbol.lock'),
              message: $r('app.string.privacy_space'),
              onPress: async () => {
                this.passwd = Preferences.getPassword(PathUtils.appContext!)
                if (this.passwd.length === 0) { // 未设置密码时直接打开设置弹窗
                  this.editPasswdDialogController.open()
                  return
                }
                if (BiometricAccessUtil.checkUserAuthSupport()) { // 支持生物认证时进行认证
                  const isSuccess = await BiometricAccessUtil.startUserAuth()
                  if (isSuccess) { // 认证成功进入隐私空间
                    this.pathStack.replacePathByName(NavigationAddress.PRIVACY_SPACE, null)
                    return
                  }
                  ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.privacy_auth_failed').id)) // 认证失败显示提示
                  return
                }
                ToolsUtil.showToast(
                  ToolsUtil.getStringResource($r('app.string.privacy_enter_via_password').id)) // 设备不支持生物认证的提示
              }
            })
          }
        }

      }
      .clip(false)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true }) // 滚动边缘效果
      .chainAnimation(true)
      .borderRadius(16)
      .margin({ left: 16, right: 16 })
      .scrollBar(BarState.Off)
      .height('100%')
      .width('95%')
      .layoutWeight(1)
    }
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
          mainTitle: '设置',
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

}
