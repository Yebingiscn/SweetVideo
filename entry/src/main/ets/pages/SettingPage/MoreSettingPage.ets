import { salmonLogger } from 'salmonlogger'
import { Markdown, MarkdownController } from '@luvi/lv-markdown-in'
import NavigationAddress from '../../common/NavigationCommon'
import { SettingsClickItem } from '../../component/SettingComponent/SettingsClickItem'
import { SettingsSectionHeaderBuilder } from '../../component/SettingComponent/SettingsSectionHeader'
import { SettingsToggleItem } from '../../component/SettingComponent/SettingsToggleItem'
import Preferences from '../../database/Preferences'
import PreferencesUtil from '../../database/PreferencesUtil'
import FileFolderUtil from '../../utils/FileFolderUtil'
import { SafeHeight, Setting } from '../../utils/ObservedUtil'
import { PathUtils } from '../../utils/PathUtils'
import ToolsUtil from '../../utils/ToolsUtil'
import WantProcess from '../../utils/WantProcessUtil'
import { LengthMetrics } from '@kit.ArkUI'
import { hdsMaterial, HdsNavDestination, ScrollEffectType } from '@kit.UIDesignKit'
import { commentManager } from '@kit.AppGalleryKit'

const TAG = 'MoreSettingPage'

@ComponentV2
export struct MoreSettingPage {
  @Consumer('pathStack') pathStack: NavPathStack = new NavPathStack()
  private listScroller: Scroller = new Scroller()
  controller: MarkdownController = new MarkdownController()

  aboutToAppear(): void {
    this.controller.setTitleColor($r('app.color.text_color'))
    this.controller.setTextColor($r('app.color.text_color'))
    this.controller.setQuoteBackgroundColor($r('app.color.start_window_background_blur'))
    this.controller.setLazyRender(true)
  }

  build() {
    HdsNavDestination() {
      List({ scroller: this.listScroller }) {
        ListItem() {
          SettingsSectionHeaderBuilder('应用信息', '关于、版本更新与应用评价')
        }

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
            symbol: $r('sys.symbol.arrow_up_circle'),
            message: '检查更新',
            onPress: () => {
              ToolsUtil.checkUpdate()
            }
          })
        }

        if (canIUse('SystemCapability.AppGalleryService.Distribution.Comment')) {
          ListItem() {
            SettingsClickItem({
              symbol: $r('sys.symbol.hand_thumbsup'),
              message: '从夯到拉锐评下流心',
              onPress: async () => {
                try {
                  commentManager.showCommentDialog(PathUtils.appContext!).then(() => {
                    salmonLogger.addLog(TAG, '成功展示评论弹窗', false)
                  })?.catch((error: BusinessError<Object>) => {
                    salmonLogger.addLog(TAG,
                      `展示评论弹窗错误, Code: ${error.code}, message: ${error.message}`, true)
                    WantProcess.linkToAppGallery(PathUtils.appContext!.abilityInfo.bundleName)
                  })
                } catch (error) {
                  salmonLogger.addLog(TAG, `展示评论弹窗错误, Code: ${error.code}, message: ${error.message}`, true)
                }
              }
            })
          }
        }

        ListItem() {
          SettingsSectionHeaderBuilder('维护与诊断', '运行日志、文件清理与界面兼容')
        }

        ListItem() {
          SettingsClickItem({
            symbol: $r('sys.symbol.doc_plaintext'),
            message: '流心运行日志',
            onPress: () => {
              this.pathStack.pushPathByName(NavigationAddress.CRASH_PAGE, true)
            }
          })
        }

        ListItem() {
          SettingsClickItem({
            symbol: $r('sys.symbol.fast'),
            message: '清理失效文件',
            onPress: async () => {
              PreferencesUtil.delPreferencesValue(PathUtils.appContext!, 'sweet_video', 'circle_play')
              PreferencesUtil.delPreferencesValue(PathUtils.appContext!, 'sweet_video', 'is_list_display')
              PreferencesUtil.delPreferencesValue(PathUtils.appContext!, 'sweet_video', 'defaultPlayer')
              const missingFileSum = await FileFolderUtil.cleanInvalidFiles(PathUtils.appContext!)
              ToolsUtil.showToast(missingFileSum > 0 ? '删除了 ' + missingFileSum + ' 项文件' : '没有找到失效文件')
            }
          })
        }

        if (canIUse('SystemCapability.Window.SessionManager')) {
          ListItem() {
            SettingsToggleItem({
              symbol: $r('sys.symbol.display'),
              message: '固定缩放（关闭可能导致UI异常）',
              tag: '试用',
              enable: Setting.defaultDensityEnabled,
              onChange: (checked: boolean) => {
                if (!checked) {
                  ToolsUtil.showToast('重启生效，关闭可能导致UI异常')
                }
                Setting.defaultDensityEnabled = checked
                Preferences.saveDefaultDensityEnabled(PathUtils.appContext!, Setting.defaultDensityEnabled)
              }
            })
          }
        }

        ListItem() {
          SettingsSectionHeaderBuilder('使用技巧', '快速了解手势与常用功能')
        }

        ListItem() {
          Column() {
            Markdown({
              controller: this.controller,
              mode: 'rawfile',
              context: PathUtils.appContext!,
              rawfilePath: 'Tips.md',
              callback: {
                complete: () => {
                  salmonLogger.addLog(TAG, 'Markdown component load success.', false)
                },
                fail: (code: number, message: string) => {
                  salmonLogger.addLog(TAG,
                    'Markdown component load error. code: ' + code + ', message: ' + message, true)
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
          mainTitle: '应用与支持',
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
