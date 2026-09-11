import { SettingsClickItem } from '../../component/SettingComponent/SettingsClickItem'
import { SettingsMenuItem } from '../../component/SettingComponent/SettingsMenuItem'
import { SettingsSegmentButtonItem } from '../../component/SettingComponent/SettingsSegmentButtonItem'
import { SettingsToggleItem } from '../../component/SettingComponent/SettingsToggleItem'
import { DefaultStartupFolderDialog } from '../../component/Dialog/DefaultStartupFolderDialog'
import { DefaultDialogShadow } from '../../common/AttributeModifierConfig'
import { CoverLayoutMode, ListDisplayMode } from '../../common/enum/DisplayMode'
import Preferences from '../../database/Preferences'
import { SafeHeight, Setting } from '../../utils/ObservedUtil'
import { PathUtils } from '../../utils/PathUtils'
import ToolsUtil from '../../utils/ToolsUtil'
import { userData } from '../../component/common/UserLoginComponent'
import { hdsMaterial, HdsNavDestination, ScrollEffectType } from '@kit.UIDesignKit'
import { LengthMetrics } from '@kit.ArkUI'
import { SuppressWarnings, SuppressWarningsType } from '@kit.BasicServicesKit'

const TAG = 'PersonalizePage'

@ComponentV2
export struct PersonalizePage {
  @Local defaultStartupFolderName: string = ''
  private listScroller: Scroller = new Scroller()
  defaultStartupFolderDialogController: CustomDialogController = new CustomDialogController({
    builder: DefaultStartupFolderDialog({
      onFolderSelected: (folderDate: string) => {
        this.updateDefaultStartupFolderName(folderDate)
      }
    }), cornerRadius: 20, shadow: DefaultDialogShadow
  })

  aboutToAppear(): void {
    const savedFolderDate = Preferences.getDefaultStartupFolder(PathUtils.appContext!)
    this.updateDefaultStartupFolderName(savedFolderDate)
  }

  @SuppressWarnings({ rules: [SuppressWarningsType.SYSCAP] })
  build() {
    HdsNavDestination() {
      List({ scroller: this.listScroller }) {
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
          SettingsMenuItem({
            symbol: $r('sys.symbol.list_number'),
            message: '最大列表数',
            tag: 'VIP',
            selected: Setting.maxListLine - 1,
            list: ['1', '2', '3', '4', '5', '6', '7', '8'],
            itemEnabled: userData.isVip,
            onChange: (index: number) => {
              Setting.maxListLine = index + 1
              Preferences.saveMaxListLine(PathUtils.appContext!, Setting.maxListLine)
            }
          })
        }

        ListItem() {
          SettingsToggleItem({
            symbol: $r('sys.symbol.doc_text_badge_clock'),
            message: '开启最近播放',
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
            message: '首页显示顶部文件夹列表',
            enable: Setting.showToast,
            onChange: (checked: boolean) => {
              Setting.showToast = checked
              Preferences.saveShowToast(PathUtils.appContext!, Setting.showToast)
            }
          })
        }

        ListItem() {
          SettingsClickItem({
            symbol: $r('sys.symbol.folder_badge_plus'),
            message: '默认启动页面：' + this.defaultStartupFolderName,
            showArrow: true,
            onPress: () => {
              this.defaultStartupFolderDialogController.open()
            }
          })
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
          mainTitle: '界面',
        }
      },
    })
    .backgroundColor($r('app.color.start_window_background'))
    .backgroundImage(
      Setting.backgroundDropBlur > 0 && Setting.backgroundBlurImageSrc.length > 0 ? Setting.backgroundBlurImageSrc :
        Setting.backgroundImageSrc, ImageRepeat.NoRepeat)
    .backgroundImageSize(ImageSize.Cover)
    .backdropBlur(
      Setting.backgroundDropBlur > 0 && Setting.backgroundBlurImageSrc.length === 0 ? Setting.backgroundDropBlur : 0)
    .backgroundImagePosition(Alignment.Center)
    .hideBackButton(false)
    .bindToScrollable([this.listScroller])
  }

  private updateDefaultStartupFolderName(folderDate: string) {
    if (folderDate === '') {
      this.defaultStartupFolderName = '默认（首页）'
      return
    }
    if (folderDate === '__stream__') {
      this.defaultStartupFolderName = '串流页'
      return
    }
    if (folderDate === '__iptv__') {
      this.defaultStartupFolderName = 'IPTV源列表'
      return
    }
    if (folderDate.startsWith('__iptv_src__')) {
      const sourceId = folderDate.substring('__iptv_src__'.length)
      const sources = Preferences.getIPTVSources(PathUtils.appContext!)
      const source = sources.find(s => s.id === sourceId)
      this.defaultStartupFolderName = source ? `IPTV - ${source.name}` : 'IPTV源列表'
      return
    }
    const folders = Preferences.getFileFolder(PathUtils.appContext!)
    const folder = folders.find(f => f.date === folderDate)
    this.defaultStartupFolderName = folder?.name ?? '默认（首页）'
  }
}
