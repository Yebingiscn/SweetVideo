import { FileFolder } from '../../interfaces/FileFolderInterface'
import { VideoListController } from '../VideoItemComponent/VideoItemComponent'
import { FileFolderDataSource } from '../../utils/DataUtil'
import { SideBarController, AppInfoBuilder } from '../SideBarComponent/SideBar'
import { FileFolderListBuilder } from '../FileFolderComponent/FileFolderListComponent'
import { FolderSelectMenuBuilder } from '../FileFolderComponent/FileFolderSelectBuilder'
import { ButtonFancyModifier, SymbolGlyphFancyModifier, DefaultDialogShadow } from '../../common/AttributeModifierConfig'
import ToolsUtil from '../../utils/ToolsUtil'
import { SafeHeight, Setting } from '../../utils/ObservedUtil'
import DataSyncUtil from '../../utils/DataSyncUtil'
import { XAnimation } from '../../utils/AnimationUtil'
import NavigationAddress from '../../common/NavigationCommon'
import { AddFileFolderNameDialog } from '../Dialog/AddFileFolderNameDialog'
import { EditFileFolderNameDialog } from '../Dialog/EditFileFolderNameDialog'
import FileFolderUtil from '../../utils/FileFolderUtil'
import { PathUtils } from '../../utils/PathUtils'
import SelectFileUtil from '../../utils/SelectFileUtil'

/**
 * 菜单项配置
 */
interface MenuItemConfig {
  icon: Resource
  content: string | Resource
  onAction: () => void
}

/**
 * 侧边栏内容组件
 * 封装侧边栏的完整 UI 和交互逻辑
 */
@Component
export struct SideBarContentComponent {
  // === 输入属性 ===
  @Link file_folder_list: FileFolder[]
  @ObjectLink videoListController: VideoListController
  @ObjectLink sideBarController: SideBarController
  @ObjectLink fileFolderSource: FileFolderDataSource

  // === 回调 ===
  onFolderSelect: (folder: FileFolder) => Promise<void> = async () => {}
  onImportFromFileManager: () => Promise<void> = async () => {}
  onImportFromAlbum: () => Promise<void> = async () => {}
  onImportFromDownload: () => Promise<void> = async () => {}
  onAddFolder: () => void = () => {}
  onNavigateToRecent: () => void = () => {}
  onNavigateToSettings: () => void = () => {}
  onDeleteFolder: (folder: FileFolder) => Promise<void> = async () => {}
  onRenameFolder: (folder: FileFolder) => void = () => {}

  // === 内部状态 ===
  private sideBarScroller: Scroller = new Scroller()
  private addFolderDialogController: CustomDialogController = new CustomDialogController({
    builder: AddFileFolderNameDialog({ onFolderAdded: () => {} }),
    cornerRadius: 20,
    shadow: DefaultDialogShadow
  })
  private editFolderDialogController: CustomDialogController = new CustomDialogController({
    builder: EditFileFolderNameDialog({ confirm: async () => {} }),
    cornerRadius: 20,
    shadow: DefaultDialogShadow
  })

  aboutToAppear(): void {
    // 初始化对话框控制器，绑定回调
    this.addFolderDialogController = new CustomDialogController({
      builder: AddFileFolderNameDialog({
        onFolderAdded: (folders: FileFolder[]) => {
          this.file_folder_list = folders
        }
      }),
      cornerRadius: 20,
      shadow: DefaultDialogShadow
    })

    this.editFolderDialogController = new CustomDialogController({
      builder: EditFileFolderNameDialog({
        confirm: async (newFolderName: string | undefined) => {
          if (!newFolderName || newFolderName.trim() == '') {
            return
          }
          await FileFolderUtil.changeFileFolderName(
            PathUtils.appContext!,
            DataSyncUtil.editingFolder!,
            newFolderName,
            this.fileFolderSource
          )
        }
      }),
      cornerRadius: 20,
      shadow: DefaultDialogShadow
    })
  }

  build() {
    Column() {
      Scroll(this.sideBarScroller) {
        Column() {
          // 应用信息头
          AppInfoBuilder({ topSafeHeight: SafeHeight.topSafeHeight })

          // 操作按钮区域
          this.ActionButtonsBuilder()

          // 文件夹列表
          this.FolderListBuilder()
        }
        .width('100%')
      }
      .margin({ top: 10 })
      .padding({ left: 20, right: 20 })
      .layoutWeight(1)
      .align(Alignment.Top)
      .scrollable(ScrollDirection.Vertical)
      .edgeEffect(EdgeEffect.Spring)
      .scrollBar(BarState.Off)
      .width('100%')
      .height('100%')
      .fadingEdge(true)

      // 底部导航按钮
      this.BottomNavBuilder()
    }
    .width('100%')
    .justifyContent(FlexAlign.Start)
    .backgroundColor(Setting.backgroundImageSrc.length > 0 ? '' : $r('app.color.start_window_background'))
    .transition(TransitionEffect.translate({ x: -300 }).animation(XAnimation.getAnimationCurve()))
    .visibility(this.sideBarController.visibility)
    .borderRadius(this.sideBarController.mode === SideBarContainerType.Overlay ? 16 : 0)
  }

  /**
   * 操作按钮区域（导入视频 + 添加文件夹）
   */
  @Builder
  ActionButtonsBuilder() {
    Column() {
      // 导入视频按钮
      Button({ type: ButtonType.Normal, stateEffect: true }) {
        Row() {
          SymbolGlyph($r('sys.symbol.plus_square'))
            .attributeModifier(new SymbolGlyphFancyModifier(25, '', ''))
          Text('导入视频')
            .fontSize(15)
            .margin({ left: 10, right: 12 })
            .textOverflow({ overflow: TextOverflow.MARQUEE })
        }
      }
      .align(Alignment.Start)
      .padding({ left: 15, right: 15 })
      .attributeModifier(new ButtonFancyModifier('100%', 60))
      .animation({ duration: 300, curve: Curve.Ease })
      .bindMenu(this.ImportMenuBuilder)
      .width('100%')

      // 添加文件夹按钮
      Button({ type: ButtonType.Normal, stateEffect: true }) {
        Row() {
          SymbolGlyph($r('sys.symbol.folder_badge_plus'))
            .attributeModifier(new SymbolGlyphFancyModifier(25, '', ''))
          Text('添加文件夹')
            .fontSize(15)
            .margin({ left: 10, right: 12 })
            .textOverflow({ overflow: TextOverflow.MARQUEE })
        }
      }
      .align(Alignment.Start)
      .padding({ left: 15, right: 15 })
      .attributeModifier(new ButtonFancyModifier('100%', 60))
      .animation({ duration: 300, curve: Curve.Ease })
      .onClick(() => {
        this.onAddFolder()
        this.addFolderDialogController.open()
      })
    }
    .margin({ top: 10 })
    .justifyContent(FlexAlign.Start)
    .backgroundColor($r('app.color.start_window_background_blur'))
    .borderRadius(16)
  }

  /**
   * 导入菜单构建器
   */
  @Builder
  ImportMenuBuilder() {
    FolderSelectMenuBuilder([
      {
        icon: $r("sys.symbol.folder"),
        content: $r('app.string.import_from_files'),
        onAction: async () => {
          this.sideBarController.close(false)
          await this.onImportFromFileManager()
        },
      },
      {
        icon: $r('sys.symbol.picture_2'),
        content: $r('app.string.import_from_album'),
        onAction: async () => {
          this.sideBarController.close(false)
          await this.onImportFromAlbum()
        },
      },
      {
        icon: $r('sys.symbol.folder_badge_eye'),
        content: `从下载文件夹导入（路径：Download/${ToolsUtil.getStringResource($r('app.string.EntryAbility_label').id)}）`,
        onAction: async () => {
          this.sideBarController.close(false)
          await this.onImportFromDownload()
        },
      },
    ])
  }

  /**
   * 文件夹列表构建器
   */
  @Builder
  FolderListBuilder() {
    List() {
      LazyForEach(this.fileFolderSource, (folder: FileFolder) => {
        ListItem() {
          FileFolderListBuilder({
            folder: folder,
            videoListController: this.videoListController
          })
        }
        .onClick(async () => {
          if (this.videoListController.folder?.date === folder.date) {
            return
          }
          await this.onFolderSelect(folder)
          this.sideBarController.close(true)
        })
        .bindContextMenu(this.FolderContextMenuBuilder(folder), ResponseType.LongPress)
        .bindContextMenu(this.FolderContextMenuBuilder(folder), ResponseType.RightClick)
        .height(60)
      }, (folder: FileFolder) => folder.name + folder.date + folder.video_list.toString())
    }
    .cachedCount(1)
    .borderRadius(16)
    .width('100%')
    .height('auto')
    .align(Alignment.Start)
    .margin({ top: 10, bottom: 10 })
    .backgroundColor($r('app.color.start_window_background_blur'))
  }

  /**
   * 文件夹右键/长按菜单
   */
  @Builder
  FolderContextMenuBuilder(folder: FileFolder) {
    if (folder.name !== '首页') {
      FolderSelectMenuBuilder([
        {
          icon: $r("sys.symbol.trash_fill"),
          content: $r('app.string.delete'),
          onAction: async () => {
            await this.onDeleteFolder(folder)
          },
        },
        {
          icon: $r('sys.symbol.rename'),
          content: $r('app.string.edit'),
          onAction: () => {
            DataSyncUtil.editingFolder = folder
            this.onRenameFolder(folder)
            this.editFolderDialogController.open()
          },
        },
      ])
    }
  }

  /**
   * 底部导航按钮（最近播放 + 设置）
   */
  @Builder
  BottomNavBuilder() {
    Column() {
      // 最近播放按钮：仅在用户开启 Setting.recentPlay 时显示，避免关闭最近播放功能后仍占用侧边栏空间
      if (Setting.recentPlay) {
        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Row() {
            SymbolGlyph($r('sys.symbol.clock')).attributeModifier(new SymbolGlyphFancyModifier(25, '', ''))
            Text('最近播放')
              .fontSize(15)
              .fontColor($r('app.color.text_color'))
              .margin({ left: 10, right: 12 })
              .textOverflow({ overflow: TextOverflow.MARQUEE })
          }
        }
        .align(Alignment.Start)
        .padding({ left: 15, right: 15 })
        .attributeModifier(new ButtonFancyModifier('100%', 60))
        .animation({ duration: 300, curve: Curve.Ease })
        .onClick(async () => {
          this.sideBarController.close(false)
          this.onNavigateToRecent()
        })
      }

      Button({ type: ButtonType.Normal, stateEffect: true }) {
        Row() {
          SymbolGlyph($r('sys.symbol.gearshape'))
            .attributeModifier(new SymbolGlyphFancyModifier(25, '', ''))
          Text($r('app.string.setting'))
            .fontSize(15)
            .margin({ left: 10, right: 12 })
            .textOverflow({ overflow: TextOverflow.MARQUEE })
        }
      }
      .align(Alignment.Start)
      .padding({ left: 15, right: 15 })
      .attributeModifier(new ButtonFancyModifier('100%', 60))
      .animation({ duration: 300, curve: Curve.Ease })
      .onClick(() => {
        this.sideBarController.close(false)
        this.onNavigateToSettings()
      })
    }
    .margin({
      bottom: SafeHeight.bottomSafeHeight === 0 ? 15 : SafeHeight.bottomSafeHeight,
      left: 20,
      right: 20
    })
    .justifyContent(FlexAlign.Start)
    .backgroundColor($r('app.color.start_window_background_blur'))
    .borderRadius(16)
  }

  /**
   * 滚动到指定文件夹位置
   */
  scrollToFolder(index: number): void {
    const estimatedOffset = index > 0 ? 260 + (index - 1) * 70 : 0
    animateToImmediately({
      duration: 200,
      curve: Curve.Ease
    }, () => {
      this.sideBarScroller.scrollTo({
        xOffset: 0,
        yOffset: estimatedOffset,
        animation: { duration: 200, curve: Curve.Ease }
      })
    })
  }
}
