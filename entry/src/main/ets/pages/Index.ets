import { FileFolderDataSource } from '../utils/DataUtil'
import { VideoListController } from '../component/VideoItemComponent/VideoItemComponent'
import { SideBarController } from '../component/SideBarComponent/SideBar'
import { VideoView } from '../component/VideoItemComponent/VideoViewComponent'
import { ImportProgressBuilder } from '../component/VideoItemComponent/ImportProgressBuilder'
import { DeletedVideosDialog } from '../component/Dialog/DeletedVideosDialog'
import { SideBarContentComponent } from '../component/IndexComponent/SideBarContentComponent'
import { IndexViewModel, ImportResult } from '../viewmodel/IndexViewModel'
// 页面导入
import { SettingsPage } from './SettingPage/Setting'
import { AboutApp } from './SettingPage/AboutApp'
import { Player } from './VideoPlayer/Player'
import { RecentPlay } from './RecentPlay'
import { PrivacySpace } from './PrivacySpace/PrivacySpace'
import { CrashPage } from './SettingPage/CrashPage'
import { PlayerSettingPage } from './SettingPage/PlayerSettingPage'
import { PersonalizePage } from './SettingPage/PersonalizePage'
import { PrivacySpaceErrorList } from './PrivacySpace/PrivacySpaceErrorList'
import { MoreSettingPage } from './SettingPage/MoreSettingPage'
import { MpvPlayer } from './VideoPlayer/MpvPlayer'
import { FolderGestureHandler } from '../utils/FolderGestureHandler'
import { FileFolder } from '../interfaces/FileFolderInterface'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import WantProcessUtil from '../utils/WantProcessUtil'
import SelectFileUtil from '../utils/SelectFileUtil'
import { PathUtils } from '../utils/PathUtils'
import VideoOperateUtil from '../utils/VideoOperateUtil'
import { WindowUtil } from '../utils/WindowUtil'
import { checkUriProcess } from '../utils/TaskpoolUtil'
import DataSyncUtil from '../utils/DataSyncUtil'
import { VideoMetaDataOperator } from '../database/VideoMetaData'
import ToolsUtil from '../utils/ToolsUtil'
import { SafeHeight, Setting } from '../utils/ObservedUtil'
import NavigationAddress from '../common/NavigationCommon'
import { DefaultDialogShadow } from '../common/AttributeModifierConfig'
import BiometricAccessUtil from '../utils/BiometricAccessUtil'
import Preferences from '../database/Preferences'
import { unifiedDataChannel, uniformTypeDescriptor } from '@kit.ArkData'

@Entry
@Component
struct Index {
  // === 状态定义 ===
  @State loading: boolean = false
  @State processedItems: number = 0
  @State totalItems: number = 0
  @Provide file_folder_list: FileFolder[] = []
  @State searchValue: string = ''
  @StorageLink('screen_width') screen_width: number = 0
  @StorageLink('migrationNeedsRefresh') @Watch('onMigrationNeedsRefreshChange') migrationNeedsRefresh: boolean = false

  // === 控制器 ===
  @Provide videoListController: VideoListController = new VideoListController()
  @Provide fileFolderSource: FileFolderDataSource = new FileFolderDataSource([])
  @Provide sideBarController: SideBarController = new SideBarController()
  @Provide('pathStack') pathStack: NavPathStack = new NavPathStack()

  // === ViewModel & Handler ===
  // 架构重构：将首页业务逻辑从 Index.ets 中抽离到 IndexViewModel，职责分离如下：
  // - Index.ets         负责 UI 构建、手势响应、导航跳转
  // - IndexViewModel    负责文件夹初始化、导入流程、刷新逻辑、已删除视频处理
  // - FolderGestureHandler 负责侧边栏手势与文件夹切换动画
  private viewModel: IndexViewModel | null = null
  private gestureHandler: FolderGestureHandler | null = null
  private passwd: string = ''

  // === Dialog 控制器 ===
  private deletedVideosDialogController: CustomDialogController = new CustomDialogController({
    builder: DeletedVideosDialog(),
    cornerRadius: 20,
    shadow: DefaultDialogShadow
  })

  // === 生命周期 ===
  async onPageShow(): Promise<void> {
    await WantProcessUtil.checkWant(PathUtils.appContext!, this.pathStack)
  }

  async aboutToAppear(): Promise<void> {
    await WindowUtil.init(PathUtils.appContext!)
    SelectFileUtil.getDownloadUri()
    VideoOperateUtil.initSetting(PathUtils.appContext!)

    // ORM 改造 + 架构重构：通过 ViewModel 初始化文件夹数据
    // 旧逻辑直接读取 Preferences.getFileFolder 并创建默认首页；
    // 新逻辑由 IndexViewModel.initializeFolders 封装，内部通过 FolderRepository 查询/创建。
    this.viewModel = new IndexViewModel(
      PathUtils.appContext!,
      (processed, total) => {
        this.processedItems = processed
        this.totalItems = total
      },
      (folders) => {
        this.file_folder_list = folders
      }
    )

    // 初始化文件夹
    this.loading = true
    const folders = await this.viewModel?.initializeFolders() ?? []
    this.loading = false
    this.file_folder_list = folders
    this.fileFolderSource.updateData(folders)
    this.videoListController.updateData(undefined, folders[0])

    // 初始化手势处理器
    this.gestureHandler = new FolderGestureHandler(
      this.file_folder_list,
      this.videoListController,
      this.sideBarController,
      this.fileFolderSource,
      (folder, index) => {
        AppStorage.setOrCreate('scrollToFolderDate', folder.date)
      },
      (offset) => {
        // 侧边栏滚动由 SideBarContentComponent 内部处理
      }
    )

    // 检查已删除视频（外部文件被用户手动删除后，需要清理数据库中对应的无效记录）
    // ORM 改造：由 ViewModel.handleDeletedVideosCheck 统一处理数据库删除与 UI 刷新
    checkUriProcess(this.file_folder_list, async (result: Object) => {
      setTimeout(async () => {
        const deletedVideos = result as Array<VideoMetadata>
        if (deletedVideos.length > 0) {
          const updatedFolders = await this.viewModel?.handleDeletedVideosCheck(
            deletedVideos,
            this.videoListController,
            this.fileFolderSource
          ) ?? this.file_folder_list
          this.file_folder_list = updatedFolders
          this.gestureHandler?.updateFolderList(this.file_folder_list)
          this.deletedVideosDialogController.open()
        }
      }, 50)
    })
  }

  // === 数据迁移后刷新 ===
  private onMigrationNeedsRefreshChange(): void {
    if (this.migrationNeedsRefresh && this.viewModel) {
      this.viewModel.refreshFolders().then(refreshedFolders => {
        this.file_folder_list = refreshedFolders
        this.fileFolderSource.updateData(refreshedFolders)
        const currentFolder = this.videoListController.folder ?? refreshedFolders[0]
        if (currentFolder) {
          const targetFolder = refreshedFolders.find(f => f.date === currentFolder.date) ?? refreshedFolders[0]
          this.videoListController.updateData(undefined, targetFolder)
        }
        this.gestureHandler = new FolderGestureHandler(
          this.file_folder_list,
          this.videoListController,
          this.sideBarController,
          this.fileFolderSource,
          (folder, index) => {
            AppStorage.setOrCreate('scrollToFolderDate', folder.date)
          },
          (offset) => {
            // 侧边栏滚动由 SideBarContentComponent 内部处理
          }
        )
        AppStorage.setOrCreate('migrationNeedsRefresh', false)
      })
    }
  }

  // === 导入处理 ===
  // 架构重构：导入逻辑下沉到 IndexViewModel，页面层仅负责触发和根据结果刷新 UI
  private async handleImport(fileList: string[], folder?: FileFolder): Promise<void> {
    if (fileList.length === 0) {
      ToolsUtil.showToast('没有任何文件被导入哦~')
      return
    }

    this.loading = true
    const result = await this.viewModel?.importVideos(
      fileList,
      folder,
      this.videoListController.videoDataSource?.getAllData() ?? [],
      this.videoListController
    )

    if (result?.success) {
      this.file_folder_list = await this.viewModel?.refreshFolders() ?? this.file_folder_list
      this.fileFolderSource.updateData(this.file_folder_list)
      this.gestureHandler?.updateFolderList(this.file_folder_list)
    }
    this.loading = false
  }

  // === 文件夹操作 ===
  private async handleFolderSelect(folder: FileFolder): Promise<void> {
    this.clearSearchValue()
    const updatedFolders = await this.viewModel?.switchToFolder(
      folder,
      this.videoListController,
      this.fileFolderSource,
      this.searchValue
    ) ?? this.file_folder_list
    this.file_folder_list = updatedFolders
    this.gestureHandler?.updateFolderList(this.file_folder_list)
  }

  private async handleDeleteFolder(folder: FileFolder): Promise<void> {
    const updatedFolders = await this.viewModel?.deleteFolder(folder, this.videoListController) ?? this.file_folder_list
    this.file_folder_list = updatedFolders
    this.fileFolderSource.updateData(updatedFolders)
    this.gestureHandler?.updateFolderList(this.file_folder_list)
  }

  // === 搜索处理 ===
  private clearSearchValue(): boolean {
    if (this.searchValue.length > 0) {
      this.searchValue = ''
      return true
    }
    return false
  }

  // === 导航处理 ===
  private navigateToRecent(): void {
    this.pathStack.pushPathByName(NavigationAddress.RECENT_PLAY, true)
  }

  private navigateToSettings(): void {
    this.pathStack.pushPathByName(NavigationAddress.SETTING_PAGE, null)
  }

  // === 隐私空间手势 ===
  private handlePinchGesture(scale: number): void {
    if (!Setting.allowGestureEntry) {
      return
    }
    this.passwd = Preferences.getPassword(PathUtils.appContext!)
    if (!this.passwd || this.passwd.length === 0) {
      return
    }
    if (scale > 1.5) {
      if (BiometricAccessUtil.checkUserAuthSupport()) {
        BiometricAccessUtil.startUserAuth().then(isSuccess => {
          if (isSuccess) {
            this.pathStack.replacePathByName(NavigationAddress.PRIVACY_SPACE, null)
          } else {
            ToolsUtil.showToast('验证失败，请从首页搜索框输入密码进入隐私空间')
          }
        })
        return
      }
      ToolsUtil.showToast('请从首页搜索框输入密码进入隐私空间')
    }
  }

  // === 构建 ===
  build() {
    Navigation(this.pathStack) {
      SideBarContainer(this.sideBarController.mode) {
        // 侧边栏内容
        SideBarContentComponent({
          file_folder_list: this.file_folder_list,
          videoListController: this.videoListController,
          sideBarController: this.sideBarController,
          fileFolderSource: this.fileFolderSource,
          onFolderSelect: (folder) => this.handleFolderSelect(folder),
          onImportFromFileManager: async () => {
            await this.handleImport(await SelectFileUtil.selectFromFileManager())
          },
          onImportFromAlbum: async () => {
            await this.handleImport(await SelectFileUtil.selectVideos())
          },
          onImportFromDownload: async () => {
            await this.handleImport(await SelectFileUtil.getDownloadFilesUri())
          },
          onAddFolder: () => {},
          onNavigateToRecent: () => this.navigateToRecent(),
          onNavigateToSettings: () => this.navigateToSettings(),
          onDeleteFolder: (folder) => this.handleDeleteFolder(folder),
          onRenameFolder: (folder) => {
            DataSyncUtil.editingFolder = folder
          }
        })

        // 主内容区
        Stack() {
          VideoView({
            loading: this.loading,
            searchValue: this.searchValue,
            videoListController: this.videoListController
          })
          .scale({
            x: this.sideBarController.isShow === true ? 0.95 : 1,
            y: this.sideBarController.isShow ? 0.95 : 1
          })
          .animation({ duration: 300, curve: Curve.Ease })

          if (this.loading) {
            ImportProgressBuilder({
              processedItems: this.processedItems,
              totalItems: this.totalItems
            })
          }
        }
        .backgroundColor(Setting.backgroundImageSrc.length > 0 ? '' : $r('app.color.start_window_background'))
        .onAreaChange(async (_oldValue, newValue) => {
          const width = Number(newValue.width)
          this.videoListController.refresh(width, Setting.listDisplayMode)
        })
        .priorityGesture(
          SwipeGesture({ direction: SwipeDirection.Horizontal })
            .onAction((event: GestureEvent) => {
              this.gestureHandler?.handleSwipe(event)
            })
        )
        .gesture(
          PinchGesture({ fingers: 2 })
            .onActionEnd((event: GestureEvent) => {
              this.handlePinchGesture(event.scale)
            })
        )
      }
      .minSideBarWidth(DataSyncUtil.minSideBarWidth)
      .minContentWidth(DataSyncUtil.minContentWidth)
      .allowDrop([uniformTypeDescriptor.UniformDataType.PLAIN_TEXT, uniformTypeDescriptor.UniformDataType.VIDEO])
      .onSizeChange((_oldValue, newValue) => {
        if (newValue.width && newValue.width >= DataSyncUtil.minSideBarWidth + DataSyncUtil.minContentWidth) {
          this.sideBarController.mode = SideBarContainerType.Embed
          this.sideBarController.visibility = Visibility.Visible
          this.sideBarController.isShow = true
        } else {
          this.sideBarController.mode = SideBarContainerType.Overlay
          this.sideBarController.visibility = Visibility.Hidden
          this.sideBarController.isShow = false
        }
      })
      .onChange((value: boolean) => {
        this.sideBarController.isShow = value
      })
      .showSideBar(this.sideBarController.isShow)
      .showControlButton(false)
      .divider({ strokeWidth: 0 })
      .gesture(
        SwipeGesture({ direction: SwipeDirection.Horizontal })
          .onAction((event: GestureEvent) => {
            if (event) {
              const rotateAngle = event.angle
              if (rotateAngle < -135 || rotateAngle > 135) {
                this.sideBarController.close(true)
              }
            }
          })
      )
    }
    .backgroundImage(Setting.backgroundImageSrc, ImageRepeat.NoRepeat)
    .backgroundImageSize(ImageSize.Cover)
    .backdropBlur(Setting.backgroundDropBlur)
    .backgroundImagePosition(Alignment.Center)
    .hideTitleBar(true)
    .mode(NavigationMode.Stack)
    .navDestination(IndexPages)
    .onDrop((dragEvent: DragEvent) => {
      let records: Array<unifiedDataChannel.UnifiedRecord> = []
      try {
        records = dragEvent.getData().getRecords()
      } catch (error) {
        ToolsUtil.showToast('获取数据时异常：' + error)
      }
      const video = records[0] as unifiedDataChannel.Video
      WantProcessUtil.wantUri = video?.uri
      WantProcessUtil.hasWant(PathUtils.appContext!, this.pathStack)
    })
    .onNavBarStateChange(async (isVisible: boolean) => {
      if (isVisible) {
        // 数据迁移后从子页面返回首页，需要强制刷新
        const migrationNeedsRefresh = AppStorage.get<boolean>('migrationNeedsRefresh')
        if (migrationNeedsRefresh && this.viewModel) {
          const refreshedFolders = await this.viewModel.refreshFolders()
          this.file_folder_list = refreshedFolders
          this.fileFolderSource.updateData(refreshedFolders)
          const currentFolder = this.videoListController.folder ?? refreshedFolders[0]
          if (currentFolder) {
            const targetFolder = refreshedFolders.find(f => f.date === currentFolder.date) ?? refreshedFolders[0]
            this.videoListController.updateData(undefined, targetFolder)
          }
          this.gestureHandler = new FolderGestureHandler(
            this.file_folder_list,
            this.videoListController,
            this.sideBarController,
            this.fileFolderSource,
            (folder, index) => {
              AppStorage.setOrCreate('scrollToFolderDate', folder.date)
            },
            (offset) => {
              // 侧边栏滚动由 SideBarContentComponent 内部处理
            }
          )
          AppStorage.setOrCreate('migrationNeedsRefresh', false)
        }

        if (this.videoListController.folder?.video_list) {
          const actualContentWidth = this.screen_width - DataSyncUtil.minContentWidth
          this.videoListController.refresh(actualContentWidth, Setting.listDisplayMode)
          const targetFolder = this.videoListController.folder ?? this.file_folder_list[0]
          const updatedFolders = await this.viewModel?.refreshFolders() ?? this.file_folder_list
          this.file_folder_list = updatedFolders
          this.gestureHandler?.updateFolderList(this.file_folder_list)
        }
        if (DataSyncUtil.lastPlayVideoIndex >= 0) {
          this.videoListController.listScroller.scrollToIndex(DataSyncUtil.lastPlayVideoIndex)
          DataSyncUtil.lastPlayVideoIndex = -1
        }
        const value: string | undefined = AppStorage.get('searchValue')
        if (value) {
          this.searchValue = value
          AppStorage.set('searchValue', '')
        }
      }
    })
  }

  // === 返回键处理 ===
  onBackPress(): boolean | void {
    if (this.videoListController.multipleChooseState === Visibility.Visible) {
      this.videoListController.closeMultipleChoose()
      return true
    }
    if (this.sideBarController.visibility === Visibility.Visible &&
      this.sideBarController.mode === SideBarContainerType.Overlay) {
      this.sideBarController.close(true)
      return true
    }
    if (this.clearSearchValue()) {
      return true
    }
    return false
  }
}

// 全局页面路由 Builder（navDestination 需要使用全局 Builder）
@Builder
function IndexPages(name: string) {
  if (name == NavigationAddress.SETTING_PAGE) {
    SettingsPage()
  } else if (name == NavigationAddress.ABOUT_PAGE) {
    AboutApp()
  } else if (name == NavigationAddress.AV_PLAYER) {
    Player()
  } else if (name == NavigationAddress.RECENT_PLAY) {
    RecentPlay()
  } else if (name == NavigationAddress.PRIVACY_SPACE) {
    PrivacySpace()
  } else if (name == NavigationAddress.CRASH_PAGE) {
    CrashPage()
  } else if (name == NavigationAddress.PLAYER_SETTING_PAGE) {
    PlayerSettingPage()
  } else if (name == NavigationAddress.PERSONALIZE_PAGE) {
    PersonalizePage()
  } else if (name == NavigationAddress.PRIVACY_ERROR_LIST) {
    PrivacySpaceErrorList()
  } else if (name == NavigationAddress.MORE_SETTING_PAGE) {
    MoreSettingPage()
  } else if (name == NavigationAddress.MPV_PLAYER) {
    MpvPlayer()
  }
}
