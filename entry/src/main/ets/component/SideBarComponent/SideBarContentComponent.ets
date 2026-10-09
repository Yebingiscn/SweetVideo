import { FileFolderDataSource } from '../../utils/DataUtil'
import { AddNetworkStreamDialog } from '../Dialog/AddNetworkStreamDialog'
import { FileFolder } from '../../interfaces/FileFolderInterface'
import { ButtonFancyModifier, DefaultDialogShadow, ImageFancyModifier, SymbolGlyphFancyModifier } from '../../common/AttributeModifierConfig'
import { PathUtils } from '../../utils/PathUtils'
import { VideoListController } from '../../controller/VideoListController'
import { SideBarController } from './SideBar'
import Preferences from '../../database/Preferences'
import { SortField } from '../../common/enum/SortField'
import NavigationAddress from '../../common/NavigationCommon'
import { userData, userLoginBuilder } from '../common/UserLoginComponent'
import { FolderSelectMenuBuilder } from '../FileFolderComponent/FileFolderSelectBuilder'
import { importAndProcessFiles, ProgressInfo } from '../../utils/FileProcessorUtil'
import { XAnimation } from '../../utils/AnimationUtil'
import SelectFileUtil from '../../utils/SelectFileUtil'
import TimeUtil from '../../utils/TimeUtil'
import ToolsUtil from '../../utils/ToolsUtil'
import VideoUtils from '../../utils/VideoUtil'
import { SafeHeight, Setting } from '../../utils/ObservedUtil'
import { CapsuleSegmentButtonV2, ColorMetrics, SegmentButtonV2ItemOptions, SegmentButtonV2Items } from '@kit.ArkUI'
import { IMenuItem } from '../../interfaces/IMenuItemInterface'
import { deviceInfo } from '@kit.BasicServicesKit'
import { SideBarFolderComponent } from './SideBarFolderComponent'

@ComponentV2
export struct SideBarContentComponent {
  @Param sideBarController: SideBarController = new SideBarController()
  @Param pathStack: NavPathStack = new NavPathStack()
  @Param videoListController: VideoListController = new VideoListController()
  @Param fileFolderSource: FileFolderDataSource = new FileFolderDataSource([])
  @Param file_folder_list: FileFolder[] = []
  @Param scrollToFolderDate: string = ''
  @Local isLogin: boolean = false
  @Local folderDeleting: boolean = false
  @Param sideBarScroller: Scroller = new Scroller()
  @Local currentSourceTab: number = 0
  @Local segmentItems: SegmentButtonV2Items = new SegmentButtonV2Items([
    { text: ToolsUtil.getStringResource($r('app.string.segment_local').id) } as SegmentButtonV2ItemOptions,
    { text: ToolsUtil.getStringResource($r('app.string.segment_network').id) } as SegmentButtonV2ItemOptions
  ])
  @Local itemSelectedBackgroundColor: ColorMetrics | undefined = undefined
  @Local itemSelectedFontColor: ColorMetrics | undefined = undefined
  addNetworkStreamDialogController: CustomDialogController = new CustomDialogController({
    builder: AddNetworkStreamDialog({
      onStreamAdded: () => {
      }
    }), cornerRadius: 20, shadow: DefaultDialogShadow
  })
  @Event fileFolderListChange: (folders: FileFolder[]) => void = () => {}
  @Event scrollToFolderDateChange: (date: string) => void = () => {
  }
  @Event searchValueClear: () => boolean = () => false
  @Event onImportProgress: (info: ProgressInfo) => void = () => {
  }
  @Event onImportLoading: (loading: boolean) => void = () => {
  }
  @Event onImportTotal: (total: number) => void = () => {
  }

  aboutToAppear(): void {
    try {
      this.itemSelectedBackgroundColor = ColorMetrics.resourceColor($r('app.color.main_color'))
      this.itemSelectedFontColor = ColorMetrics.resourceColor($r('sys.color.white'))
    } catch (_error) {
    }
  }

  @Builder
  SelectFileMenuBuilder() {
    FolderSelectMenuBuilder(this.getSelectFileMenus())
  }

  async toMetaData(fileList: string[], fileFolder?: FileFolder,
    importRootUri?: string, importRootFolderName?: string) {
    await importAndProcessFiles(
      fileList,
      this.videoListController.videoDataSource?.getAllData() ?? [],
      (info: ProgressInfo) => {
        this.onImportProgress(info)
      },
      (loading: boolean) => {
        this.onImportLoading(loading)
      },
      (totalItems: number) => {
        this.onImportTotal(totalItems)
      },
      fileFolder,
      () => {
        const currentFolderDate = this.videoListController.folder?.date
        const latestFolders = Preferences.getFileFolder(PathUtils.appContext!)
        const targetFolder = currentFolderDate
          ? latestFolders.find(f => f.date === currentFolderDate) ?? latestFolders[0]
          : latestFolders[0]
        const sortField = Preferences.getSortField(PathUtils.appContext!) as SortField
        if (sortField) {
          const sortAsc = Preferences.getSortAsc(PathUtils.appContext!)
          targetFolder.video_list =
            ToolsUtil.sortBy(PathUtils.appContext!, targetFolder.video_list, targetFolder, sortField, sortAsc)
        }
        const updatedFolders = VideoUtils.refresh(this.videoListController, this.fileFolderSource, targetFolder)
        this.fileFolderListChange(updatedFolders)
      },
      importRootUri,
      importRootFolderName
    )
  }

  @Builder
  ImportActions() {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row() {
        SymbolGlyph($r('sys.symbol.plus_square'))
          .attributeModifier(new SymbolGlyphFancyModifier(25, '', ''))
        Text($r('app.string.import_from_videos'))
          .fontSize(15)
          .margin({ left: 10, right: 12 })
          .textOverflow({ overflow: TextOverflow.MARQUEE })
      }
    }
    .align(Alignment.Start)
    .padding({ left: 16, right: 16 })
    .attributeModifier(new ButtonFancyModifier('100%', 60))
    .backgroundColor(Color.Transparent)
    .animation({ duration: 300, curve: Curve.Ease })
    .bindMenu(this.SelectFileMenuBuilder)
    .width('100%')

    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row() {
        SymbolGlyph($r('sys.symbol.magnifyingglass'))
          .attributeModifier(new SymbolGlyphFancyModifier(25, '', ''))
        Text($r('app.string.global_search'))
          .fontSize(15)
          .margin({ left: 10, right: 12 })
      }
    }
    .align(Alignment.Start)
    .padding({ left: 16, right: 16 })
    .attributeModifier(new ButtonFancyModifier('100%', 60))
    .backgroundColor(Color.Transparent)
    .onClick(() => {
      this.pathStack.pushPathByName(NavigationAddress.GLOBAL_SEARCH, null)
    })
  }

  build() {
    Column() {
      // 头部固定区域：标题 + 用户卡片 + 快捷入口 + 分段按钮
      Column() {
        Row() {
          Text($r('app.string.EntryAbility_label'))
            .fontSize(20)
            .fontColor($r('app.color.text_color'))
            .fontWeight(FontWeight.Bold)
            .textOverflow({ overflow: TextOverflow.MARQUEE })
          Text(TimeUtil.getTextByTime())
            .fontSize(15)
            .fontColor($r('app.color.text_color'))
            .textOverflow({ overflow: TextOverflow.MARQUEE })
            .margin({ left: 5, right: 12 })
        }
        .alignItems(VerticalAlign.Bottom)
        .width('100%')
        .justifyContent(FlexAlign.Start)
        .margin({ top: SafeHeight.topSafeHeight })
        .clickEffect({ level: ClickEffectLevel.HEAVY, scale: 0.9 })
        .onClick(() => {
          ToolsUtil.startVibration()
          ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.toast_easter_egg').id))
        })

        Row() {
          Image(userData?.userAvatar || $r("app.media.Foreground"))
            .attributeModifier(new ImageFancyModifier(20, 45, 45))
            .margin({ left: 10 })
          Column({ space: 2 }) {
            Text(userData.isLogin ? (userData.nickName || ToolsUtil.getStringResource($r('app.string.logged_in').id)) : ToolsUtil.getStringResource($r('app.string.tap_to_login').id))
              .fontColor($r('app.color.text_color'))
              .fontSize(15)
              .textOverflow({ overflow: TextOverflow.MARQUEE })
            if (userData.isLogin) {
              Text(userData.isVip ? $r('app.string.vip_label') : $r('app.string.non_vip'))
                .fontSize(10)
                .fontColor(userData.isVip ? $r('sys.color.white') : $r('sys.color.black'))
                .backgroundColor(userData.isVip ? $r('app.color.main_color') : '#c1b2a3')
                .fontWeight(userData.isVip ? FontWeight.Bold : FontWeight.Normal)
                .borderRadius(6)
                .padding({
                  left: 5,
                  right: 5,
                  top: 2,
                  bottom: 2
                })
            }
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          .margin({ left: 10, right: 12 })
        }
        .height(65)
        .onClick(() => {
          this.isLogin = true
        })
        .clickEffect({ level: ClickEffectLevel.HEAVY, scale: 0.9 })
        .margin({ top: 10 })
        .justifyContent(FlexAlign.Start)
        .backgroundColor($r('app.color.list_item_background'))
        .borderRadius(16)
        .shadow({
          radius: 4,
          color: $r('app.color.shadow_color'),
          offsetX: 0,
          offsetY: 1
        })
        .bindSheet(this.isLogin, userLoginBuilder(() => {
          this.isLogin = false
          this.pathStack.pushPathByName(NavigationAddress.VIP_PAGE, true)
        }), {
          detents: [SheetSize.FIT_CONTENT],
          height: SheetSize.MEDIUM,
          preferType: SheetType.CENTER,
          enableOutsideInteractive: false,
          dragBar: true,
          showClose: true,
          title: { title: $r('app.string.account_info') },
          onWillDismiss: () => {
            this.isLogin = false
          }
        })

        // 快捷入口：设置 + 最近播放（从底部移到顶部）
        Row() {
          Column() {
            SymbolGlyph($r('sys.symbol.gearshape'))
              .attributeModifier(new SymbolGlyphFancyModifier(22, '', ''))
            Text($r('app.string.setting'))
              .fontSize(11)
              .fontColor($r('app.color.text_color'))
              .margin({ top: 4 })
          }
          .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
          .layoutWeight(1)
          .padding({ top: 12, bottom: 12 })
          .alignItems(HorizontalAlign.Center)
          .onClick(() => {
            this.sideBarController.closeIfOverlay(false)
            this.pathStack.pushPathByName(NavigationAddress.SETTING_PAGE, null)
          })

          Column() {
            SymbolGlyph($r('sys.symbol.clock'))
              .attributeModifier(new SymbolGlyphFancyModifier(22, '', ''))
            Text($r('app.string.recent_play'))
              .fontSize(11)
              .fontColor($r('app.color.text_color'))
              .margin({ top: 4 })
          }
          .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
          .layoutWeight(1)
          .padding({ top: 12, bottom: 12 })
          .alignItems(HorizontalAlign.Center)
          .onClick(() => {
            this.sideBarController.closeIfOverlay(false)
            this.pathStack.pushPathByName(NavigationAddress.RECENT_PLAY, true)
          })
        }
        .width('100%')
        .margin({ top: 10 })
        .backgroundColor($r('app.color.list_item_background'))
        .borderRadius(16)
        .shadow({
          radius: 4,
          color: $r('app.color.shadow_color'),
          offsetX: 0,
          offsetY: 1
        })

        // 本地/网络切换 - CapsuleSegmentButtonV2
        CapsuleSegmentButtonV2({
          items: this.segmentItems,
          selectedIndex: this.currentSourceTab,
          buttonBackgroundBlurStyle: BlurStyle.BACKGROUND_THICK,
          itemSelectedFontColor: this.itemSelectedFontColor,
          itemSelectedBackgroundColor: this.itemSelectedBackgroundColor,
          onItemClicked: (index: number) => {
            this.currentSourceTab = index
          }
        })
          .margin({ top: 10, bottom: 6 })
      }
      .width('100%')
      .padding({ left: 16, right: 16 })

      // 内容区域：Swiper 切换本地/网络
      Swiper() {
        SideBarFolderComponent({
          sideBarController: this.sideBarController,
          videoListController: this.videoListController,
          fileFolderSource: this.fileFolderSource,
          file_folder_list: this.file_folder_list,
          sideBarScroller: this.sideBarScroller,
          currentSourceTab: this.currentSourceTab,
          // 闭包保留父组件上下文，避免 BuilderParam 将 this 切换到文件夹子组件。
          importActions: () => { this.ImportActions() },
          fileFolderListChange: this.fileFolderListChange,
          scrollToFolderDateChange: this.scrollToFolderDateChange,
          searchValueClear: this.searchValueClear,
          onDeletingChange: (deleting: boolean) => { this.folderDeleting = deleting }
        })

        // Tab 1: 网络
        Scroll() {
          Column({ space: 8 }) {
            Button({ type: ButtonType.Normal, stateEffect: true }) {
              Row() {
                SymbolGlyph($r('sys.symbol.switch_TV'))
                  .attributeModifier(new SymbolGlyphFancyModifier(25, '', ''))
                Text($r('app.string.stream'))
                  .fontSize(15)
                  .margin({ left: 10, right: 12 })
                  .textOverflow({ overflow: TextOverflow.MARQUEE })
              }
            }
            .align(Alignment.Start)
            .padding({ left: 16, right: 16 })
            .attributeModifier(new ButtonFancyModifier('100%', 60))
            .backgroundColor(Color.Transparent)
            .animation({ duration: 300, curve: Curve.Ease })
            .onClick(() => {
              this.sideBarController.closeIfOverlay(false)
              this.pathStack.pushPathByName(NavigationAddress.STREAM_PAGE, null)
            })

            Button({ type: ButtonType.Normal, stateEffect: true }) {
              Row() {
                SymbolGlyph($r('sys.symbol.TV_tv'))
                  .attributeModifier(new SymbolGlyphFancyModifier(25, '', ''))
                Text('IPTV')
                  .fontSize(15)
                  .margin({ left: 10, right: 12 })
                  .textOverflow({ overflow: TextOverflow.MARQUEE })
              }
            }
            .align(Alignment.Start)
            .padding({ left: 16, right: 16 })
            .attributeModifier(new ButtonFancyModifier('100%', 60))
            .backgroundColor(Color.Transparent)
            .animation({ duration: 300, curve: Curve.Ease })
            .onClick(() => {
              this.sideBarController.closeIfOverlay(false)
              this.pathStack.pushPathByName(NavigationAddress.IPTV_SOURCE_PAGE, null)
            })

            Button({ type: ButtonType.Normal, stateEffect: true }) {
              Row() {
                SymbolGlyph($r('sys.symbol.folder_badge_ellipsis'))
                  .attributeModifier(new SymbolGlyphFancyModifier(25, '', ''))
                Text('SMB')
                  .fontSize(15)
                  .margin({ left: 10, right: 12 })
                  .textOverflow({ overflow: TextOverflow.MARQUEE })
              }
            }
            .align(Alignment.Start)
            .padding({ left: 16, right: 16 })
            .attributeModifier(new ButtonFancyModifier('100%', 60))
            .backgroundColor(Color.Transparent)
            .animation({ duration: 300, curve: Curve.Ease })
            .onClick(() => {
              this.sideBarController.closeIfOverlay(false)
              this.pathStack.pushPathByName(NavigationAddress.SMB_PAGE, null)
            })

            Button({ type: ButtonType.Normal, stateEffect: true }) {
              Row() {
                SymbolGlyph($r('sys.symbol.folder_badge_ellipsis'))
                  .attributeModifier(new SymbolGlyphFancyModifier(25, '', ''))
                Text('WebDAV')
                  .fontSize(15)
                  .margin({ left: 10, right: 12 })
                  .textOverflow({ overflow: TextOverflow.MARQUEE })
              }
            }
            .align(Alignment.Start)
            .padding({ left: 16, right: 16 })
            .attributeModifier(new ButtonFancyModifier('100%', 60))
            .backgroundColor(Color.Transparent)
            .animation({ duration: 300, curve: Curve.Ease })
            .onClick(() => {
              this.sideBarController.closeIfOverlay(false)
              this.pathStack.pushPathByName(NavigationAddress.WEBDAV_PAGE, null)
            })

            Button({ type: ButtonType.Normal, stateEffect: true }) {
              Row() {
                SymbolGlyph($r('sys.symbol.folder_badge_ellipsis'))
                  .attributeModifier(new SymbolGlyphFancyModifier(25, '', ''))
                Text('FTP')
                  .fontSize(15)
                  .margin({ left: 10, right: 12 })
                  .textOverflow({ overflow: TextOverflow.MARQUEE })
              }
            }
            .align(Alignment.Start)
            .padding({ left: 16, right: 16 })
            .attributeModifier(new ButtonFancyModifier('100%', 60))
            .backgroundColor(Color.Transparent)
            .animation({ duration: 300, curve: Curve.Ease })
            .onClick(() => {
              this.sideBarController.closeIfOverlay(false)
              this.pathStack.pushPathByName(NavigationAddress.FTP_PAGE, null)
            })

            Button({ type: ButtonType.Normal, stateEffect: true }) {
              Row() {
                SymbolGlyph($r('sys.symbol.cloud'))
                  .attributeModifier(new SymbolGlyphFancyModifier(25, '', ''))
                Text($r('app.string.huawei_drive'))
                  .fontSize(15)
                  .margin({ left: 10, right: 12 })
                  .textOverflow({ overflow: TextOverflow.MARQUEE })
              }
            }
            .align(Alignment.Start)
            .padding({ left: 16, right: 16 })
            .attributeModifier(new ButtonFancyModifier('100%', 60))
            .backgroundColor(Color.Transparent)
            .animation({ duration: 300, curve: Curve.Ease })
            .onClick(() => {
              this.sideBarController.closeIfOverlay(false)
              this.pathStack.pushPathByName(NavigationAddress.HUAWEI_DRIVE_PAGE, null)
            })

          }
          .backgroundColor($r('app.color.list_item_background'))
          .width('100%')
          .borderRadius(16)
          .padding({ top: 4, bottom: 4 })
          .shadow({
            radius: 4,
            color: $r('app.color.shadow_color'),
            offsetX: 0,
            offsetY: 1
          })
        }
        .padding({ left: 16, right: 16 })
        .align(Alignment.Top)
        .edgeEffect(EdgeEffect.Spring)
        .scrollBar(BarState.Off)
        .width('100%')
        .height('100%')
      }
      .index(this.currentSourceTab)
      .indicator(false)
      .layoutWeight(1)
      .width('100%')
      .onChange((index: number) => {
        this.currentSourceTab = index
      })
    }
    .width('100%')
    .justifyContent(FlexAlign.Start)
    .enabled(!this.folderDeleting)
    .backgroundColor(Setting.backgroundImageSrc.length > 0 ? '' : $r('app.color.sidebar_background_color'))
    .transition(TransitionEffect.translate({ x: -300 })
      .combine(TransitionEffect.OPACITY)
      .animation(XAnimation.getAnimationCurve()))
    .visibility(this.sideBarController.visibility)
    .borderRadius(this.sideBarController.mode === SideBarContainerType.Overlay ? 16 : 0)
  }

  private getSelectFileMenus(): IMenuItem[] {
    const menus: IMenuItem[] = [
      {
        icon: $r("sys.symbol.resolution_video"),
        content: $r('app.string.import_from_videos'),
        onAction: async () => {
          this.sideBarController.closeIfOverlay(false)
          await this.toMetaData(await SelectFileUtil.selectFromFileManager(undefined, "video"),
            this.videoListController.folder)
        },
      },
      {
        icon: $r('sys.symbol.folder_badge_eye'),
        content: `从下载文件夹导入（路径：Download/${ToolsUtil.getStringResource($r('app.string.EntryAbility_label')
          .id)}）`,
        onAction: async () => {
          this.sideBarController.closeIfOverlay(false)
          await this.toMetaData(await SelectFileUtil.getDownloadFilesUri(), undefined)
        },
      },
      {
        icon: $r('sys.symbol.picture_2'),
        content: $r('app.string.import_from_album'),
        onAction: async () => {
          this.sideBarController.closeIfOverlay(false)
          await this.toMetaData(await SelectFileUtil.selectFromFileManager(undefined, "album"),
            this.videoListController.folder)
        },
      },
      {
        icon: $r('sys.symbol.music'),
        content: $r('app.string.import_from_music'),
        onAction: async () => {
          this.sideBarController.closeIfOverlay(false)
          await this.toMetaData(await SelectFileUtil.selectFromFileManager(undefined, "audio"),
            this.videoListController.folder)
        },
      },
    ]
    if (deviceInfo.apiAvailable('26.0.0')) {
      menus.push({
        icon: $r('sys.symbol.folder'),
        content: $r('app.string.import_from_folder'),
        onAction: async () => {
          this.sideBarController.closeIfOverlay(false)
          await this.importMediaFolders()
        },
      })
    }
    return menus
  }

  private async importMediaFolders(): Promise<void> {
    if (deviceInfo.apiAvailable('26.0.0')) {
      const imports = await SelectFileUtil.selectMediaFolders()
      if (imports.length === 0) {
        return
      }
      let emptyFolderCount = 0
      for (const folderImport of imports) {
        if (folderImport.files.length === 0) {
          emptyFolderCount++
          continue
        }
        const folderName = folderImport.name === '首页' ? ToolsUtil.getStringResource($r('app.string.home_folder_import').id) : folderImport.name
        await this.toMetaData(folderImport.files, undefined, folderImport.uri, folderName)
      }
      const currentFolderDate = this.videoListController.folder?.date
      const latestFolders = Preferences.getFileFolder(PathUtils.appContext!)
      const currentFolder =
        latestFolders.find((folder: FileFolder) => folder.date === currentFolderDate) ?? latestFolders[0]
      const updatedFolders = VideoUtils.refresh(this.videoListController, this.fileFolderSource, currentFolder)
      this.fileFolderListChange(updatedFolders)
      if (emptyFolderCount === imports.length) {
        ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.folder_no_importable_media').id))
      }
    }
  }

}
