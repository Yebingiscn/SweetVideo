import NavigationAddress from '../../common/NavigationCommon'
import { EditPasswordDialog } from '../../component/Dialog/EditPasswordDialog'
import { PathUtils } from '../../utils/PathUtils'
import ToolsUtil from '../../utils/ToolsUtil'
import { DefaultDialogShadow } from '../../common/AttributeModifierConfig'
import { Markdown, MarkdownController } from '@luvi/lv-markdown-in'
import { salmonLogger } from 'salmonlogger'
import { CoverLayoutMode, ListDisplayMode } from '../../common/enum/DisplayMode'
import { SettingsClickItem } from '../../component/SettingComponent/SettingsClickItem'
import { SettingsSegmentButtonItem } from '../../component/SettingComponent/SettingsSegmentButtonItem'
import { SettingsToggleItem } from '../../component/SettingComponent/SettingsToggleItem'
import Preferences from '../../database/Preferences'
import BiometricAccessUtil from '../../utils/BiometricAccessUtil'
import { SafeHeight, Setting } from '../../utils/ObservedUtil'
import { HdsNavDestination, ScrollEffectType } from '@kit.UIDesignKit'
import { LengthMetrics } from '@kit.ArkUI'

const TAG = 'SettingsPage'

@ComponentV2
export struct SettingsPage { //设置页
  @Local passwd: string = 'passwd'
  @Consumer('pathStack') pathStack: NavPathStack = new NavPathStack()
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
  controller: MarkdownController = new MarkdownController()
  private listScroller: Scroller = new Scroller()

  aboutToAppear(): void {
    this.controller
      .setTitleColor($r("app.color.text_color"))
      .setTextColor($r("app.color.text_color"))
      .setTableTitleBackgroundColor($r('app.color.start_window_background_blur'))
      .setQuoteBackgroundColor($r('app.color.start_window_background_blur'))
      .setTableBackgroundColor($r('app.color.start_window_background_blur'))
  }

  build() {
    HdsNavDestination() {
      List({ scroller: this.listScroller }) {
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
                  this.editPasswdDialogController.open()
                  return
                }
                if (BiometricAccessUtil.checkUserAuthSupport()) { // 支持生物认证时进行认证
                  const isSuccess = await BiometricAccessUtil.startUserAuth()
                  if (isSuccess) { // 认证成功进入隐私空间
                    this.pathStack.replacePathByName(NavigationAddress.PRIVACY_SPACE, null)
                    return
                  }
                  ToolsUtil.showToast('验证失败，请从首页搜索框输入密码进入隐私空间') // 认证失败显示提示
                  return
                }
                ToolsUtil.showToast('请从首页搜索框输入密码进入隐私空间') // 设备不支持生物认证的提示
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
          SettingsSegmentButtonItem({
            symbol: Setting.listDisplayMode === ListDisplayMode.LIST_DISPLAY ? $r('sys.symbol.list_bullet_square') :
              $r('sys.symbol.grid'),
            message: '列表布局',
            tips: ['卡片', '列表', '网格'],
            tabSelectedIndex: Setting.listDisplayMode,
            onButtonClick: (tabSelectedIndex: number) => {
              Setting.listDisplayMode = tabSelectedIndex
              Preferences.saveListDisplayMode(PathUtils.appContext!, tabSelectedIndex)
            }
          })
        }

        ListItem() {
          SettingsSegmentButtonItem({
            symbol: Setting.coverLayout === CoverLayoutMode.VERTICAL_PLATE ?
              $r('sys.symbol.rectangle_uphalf_inset_filled') : $r('sys.symbol.rectangle_lefthalf_inset_filled'),
            message: '封面版式',
            tips: ['竖版', '横版'],
            tabSelectedIndex: Setting.coverLayout,
            onButtonClick: (tabSelectedIndex: number) => {
              Setting.coverLayout = tabSelectedIndex
              Preferences.saveCoverLayoutMode(PathUtils.appContext!, tabSelectedIndex)
            }
          })
        }

        ListItem() {
          SettingsToggleItem({
            symbol: $r('sys.symbol.doc_text_badge_clock'),
            message: '开启历史记录',
            enable: Setting.recentPlay,
            onChange: (checked: boolean) => {
              Setting.recentPlay = checked
              if (!Setting.recentPlay) {
                Preferences.saveRecentPlay(PathUtils.appContext!, [])
              }
              Preferences.saveRecentPlayState(PathUtils.appContext!, Setting.recentPlay)
            }
          })
        }

        ListItem() {
          SettingsToggleItem({
            symbol: $r('sys.symbol.folder'),
            message: '开启面包屑',
            enable: Setting.showToast,
            onChange: (checked: boolean) => {
              Setting.showToast = checked
              Preferences.saveShowToast(PathUtils.appContext!, Setting.showToast)
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
                  salmonLogger.addLog(TAG, "Markdown component load success.", false)
                },
                fail: (code: number, message: string) => {
                  salmonLogger.addLog(TAG, "Markdown component load error. code: " + code + ", message: " + message,
                    true)
                }
              }
            })
          }
          .margin({ top: 10 })
          .padding(15)
          .alignItems(HorizontalAlign.Start)
          .borderRadius(16)
          .width('100%')
          .backgroundColor($r('app.color.start_window_background_blur'))
        }
      }
      .clip(false)
      .align(Alignment.Top)
      .borderRadius(16)
      .margin({ left: 16, right: 16 })
      .scrollBar(BarState.Off)
      .height('100%')
      .width('95%')
      .layoutWeight(1)
      .contentEndOffset(SafeHeight.bottomSafeHeight)
    }
    .titleBar({
      enableComponentSafeArea: true, // 将标题栏设置为组件级安全区，内容区可避让标题栏
      padding: {
        start: LengthMetrics.vp(5),
        end: LengthMetrics.vp(5)
      },
      style: {
        // 设置导航组件标题栏样式，推荐使用默认样式
        // 标题栏动态模糊样式，包括是否使能滚动动态模糊，动态模糊类型，动态模糊生效的滚动距离等
        scrollEffectOpts: {
          enableScrollEffect: true,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
          blurEffectiveStartOffset: LengthMetrics.vp(0),
          blurEffectiveEndOffset: LengthMetrics.vp(20)
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
    .padding({ top: SafeHeight.topSafeHeight })
    .backgroundImage(Setting.backgroundImageSrc, ImageRepeat.NoRepeat)
    .backgroundImageSize(ImageSize.Cover)
    .backdropBlur(Setting.backgroundDropBlur)
    .backgroundImagePosition(Alignment.Center)
    .hideBackButton(false)
    .bindToScrollable([this.listScroller]) // 绑定导航组件和可滚动容器组件
  }
}