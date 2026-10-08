import { SettingsClickItem } from '../../component/SettingComponent/SettingsClickItem'
import { SettingsMenuItem } from '../../component/SettingComponent/SettingsMenuItem'
import { SettingsSegmentButtonItem } from '../../component/SettingComponent/SettingsSegmentButtonItem'
import { SettingsToggleItem } from '../../component/SettingComponent/SettingsToggleItem'
import { DefaultStartupFolderDialog } from '../../component/Dialog/DefaultStartupFolderDialog'
import { DefaultDialogShadow } from '../../common/AttributeModifierConfig'
import { CoverLayoutMode, ListDisplayMode } from '../../common/enum/DisplayMode'
import Preferences from '../../database/Preferences'
import { SafeHeight, Setting } from '../../utils/ObservedUtil'
import ToolsUtil from '../../utils/ToolsUtil'
import { PathUtils } from '../../utils/PathUtils'
import { userData } from '../../component/common/UserLoginComponent'
import { hdsMaterial, HdsNavDestination, ScrollEffectType } from '@kit.UIDesignKit'
import { LengthMetrics } from '@kit.ArkUI'
import { SuppressWarnings, SuppressWarningsType } from '@kit.BasicServicesKit'
import { VideoListController } from '../../component/VideoItemComponent/VideoItemComponent'
import StartupPageUtil from '../../utils/StartupPageUtil'

@ComponentV2
export struct PersonalizePage {
  @Consumer() videoListController: VideoListController = new VideoListController()
  @Local defaultStartupFolderName: string = ''
  defaultStartupFolderDialogController: CustomDialogController = new CustomDialogController({
    builder: DefaultStartupFolderDialog({
      onFolderSelected: (folderDate: string) => {
        this.updateDefaultStartupFolderName(folderDate)
      }
    }), cornerRadius: 20, shadow: DefaultDialogShadow
  })
  private listScroller: Scroller = new Scroller()

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
            symbol: $r('sys.symbol.doc_plaintext_and_folder'),
            message: $r('app.string.home_style'),
            tips: [$r('app.string.home_style_list'), $r('app.string.home_style_directory')],
            tabSelectedIndex: this.videoListController.directoryMode ? 1 : 0,
            onButtonClick: (tabSelectedIndex: number) => {
              this.videoListController.setDirectoryView(tabSelectedIndex === 1)
            }
          })
        }

        ListItem() {
          SettingsSegmentButtonItem({
            symbol: Setting.listDisplayMode === ListDisplayMode.LIST_DISPLAY ? $r('sys.symbol.list_bullet_square') :
              $r('sys.symbol.grid'),
            message: $r('app.string.list_layout'),
            tips: [$r('app.string.list_layout_card'), $r('app.string.list_layout_list'), $r('app.string.list_layout_grid')],
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
            message: $r('app.string.cover_layout'),
            tips: [$r('app.string.cover_layout_vertical'), $r('app.string.cover_layout_horizontal')],
            tabSelectedIndex: Setting.coverLayout,
            onButtonClick: (tabSelectedIndex: number) => {
              Setting.coverLayout = tabSelectedIndex
              Preferences.saveCoverLayoutMode(PathUtils.appContext!, tabSelectedIndex)
            }
          })
        }

        ListItem() {
          Column({ space: 4 }) {
            SettingsToggleItem({
              symbol: $r('sys.symbol.rectangle_uphalf_inset_filled'),
              message: $r('app.string.random_cover'),
              enable: Setting.randomCover,
              onChange: (checked: boolean) => {
                Setting.randomCover = checked
                Preferences.saveRandomCover(PathUtils.appContext!, checked)
              }
            })

            Text($r('app.string.random_cover_tip'))
              .fontSize(12)
              .fontColor($r('sys.color.font_secondary'))
              .width('100%')
              .padding({ left: 16, right: 16, bottom: 12 })
          }
        }

        ListItem() {
          SettingsMenuItem({
            symbol: $r('sys.symbol.list_number'),
            message: $r('app.string.max_list_count'),
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
            message: $r('app.string.enable_recent_play'),
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
            message: $r('app.string.home_show_folder_tabs'),
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
            message: $r('app.string.default_startup_page', this.defaultStartupFolderName),
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
          mainTitle: $r('app.string.appearance_title'),
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
      this.defaultStartupFolderName = ToolsUtil.getStringResource($r('app.string.default_start_page_default').id)
      return
    }
    const startupPage = StartupPageUtil.getPage(folderDate)
    if (startupPage) {
      this.defaultStartupFolderName = typeof startupPage.label === 'string' ? startupPage.label :
        ToolsUtil.getStringResource(startupPage.label.id)
      return
    }
    if (folderDate.startsWith(StartupPageUtil.IPTV_SOURCE_PREFIX)) {
      const sourceId = folderDate.substring(StartupPageUtil.IPTV_SOURCE_PREFIX.length)
      const sources = Preferences.getIPTVSources(PathUtils.appContext!)
      const source = sources.find(s => s.id === sourceId)
      this.defaultStartupFolderName = source ? `IPTV - ${source.name}` : ToolsUtil.getStringResource($r('app.string.default_start_page_iptv').id)
      return
    }
    const folders = Preferences.getFileFolder(PathUtils.appContext!)
    const folder = folders.find(f => f.date === folderDate)
    this.defaultStartupFolderName = folder?.name ?? ToolsUtil.getStringResource($r('app.string.default_start_page_default').id)
  }
}
