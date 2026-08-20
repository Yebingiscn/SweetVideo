import { FileFolderDataSource } from '../utils/DataUtil'
import { FileFolder } from '../interfaces/FileFolderInterface'
import { DefaultDialogShadow } from '../common/AttributeModifierConfig'
import { VideoListController } from '../component/VideoItemComponent/VideoItemComponent'
import { SideBarController } from '../component/SideBarComponent/SideBar'
import { DeletedVideosDialog } from '../component/Dialog/DeletedVideosDialog'
import { motion } from '@kit.MultimodalAwarenessKit'
import { salmonLogger } from 'salmonlogger'
import { ListDisplayMode } from '../common/enum/DisplayMode'
import { SortField } from '../common/enum/SortField'
import { VideoSource } from '../common/enum/VideoSource'
import NavigationAddress, { IPTVChannelParams } from '../common/NavigationCommon'
import { SideBarContentComponent } from '../component/SideBarComponent/SideBarContentComponent'
import { ImportProgressBuilder } from '../component/VideoItemComponent/ImportProgressBuilder'
import { VideoView } from '../component/VideoItemComponent/VideoViewComponent'
import Preferences from '../database/Preferences'
import { VideoMetaDataOperator } from '../database/VideoMetaData'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import AccountUtil from '../utils/AccountUtil'
import { XAnimation } from '../utils/AnimationUtil'
import BiometricAccessUtil from '../utils/BiometricAccessUtil'
import DataSyncUtil from '../utils/DataSyncUtil'
import FileFolderUtil from '../utils/FileFolderUtil'
import { importAndProcessFiles, ProgressInfo } from '../utils/FileProcessorUtil'
import IntellectualGripPostureUtil from '../utils/IntellectualGripPostureUtil'
import { Setting } from '../utils/ObservedUtil'
import { PathUtils } from '../utils/PathUtils'
import PermissionUtil from '../utils/PermissionUtil'
import RecentPlayUtil from '../utils/RecentPlayUtil'
import SelectFileUtil from '../utils/SelectFileUtil'
import SubtitleUtil from '../utils/SubtitleUtil'
import { checkUriProcess } from '../utils/TaskpoolUtil'
import ToolsUtil from '../utils/ToolsUtil'
import VideoOperateUtil from '../utils/VideoOperateUtil'
import VideoUtils from '../utils/VideoUtil'
import WantProcessUtil from '../utils/WantProcessUtil'
import { WindowUtil } from '../utils/WindowUtil'
import { PrivacySpace } from './PrivacySpace/PrivacySpace'
import { PrivacySpaceErrorList } from './PrivacySpace/PrivacySpaceErrorList'
import { RecentPlay } from './RecentPlay'
import { AboutApp } from './SettingPage/AboutApp'
import { CrashPage } from './SettingPage/CrashPage'
import { GetVipPage } from './SettingPage/GetVipPage'
import { MoreSettingPage } from './SettingPage/MoreSettingPage'
import { PersonalizePage } from './SettingPage/PersonalizePage'
import { PlayerSettingPage } from './SettingPage/PlayerSettingPage'
import { SubtitleSettingPage } from './SettingPage/SubtitleSettingPage'
import { SettingsPage } from './SettingPage/Setting'
import { VideoPlayer } from './VideoPlayer/VideoPlayer'
import { ShortVideoPage } from './ShortVideo/ShortVideoPage'
import { StreamPage } from './StreamPage/StreamPage'
import { IPTVSourcePage } from './IPTV/IPTVSourcePage'
import { IPTVChannelPage } from './IPTV/IPTVChannelPage'
import { unifiedDataChannel, uniformTypeDescriptor } from '@kit.ArkData'
import { LengthMetrics } from '@kit.ArkUI'
import { HdsNavigation, HideMode, ScrollEffectType } from '@kit.UIDesignKit'

const TAG = 'Index'

@Entry
@ComponentV2
struct Index {
  @Local list_empty_item: string[] = ['']
  @Local loading: boolean = false
  @Local processedItems: number = 0
  @Local totalItems: number = 0
  @Local currentFileName: string = '' // 当前处理的文件名
  @Local failedCount: number = 0 // 失败文件数
  @Local currentStage: 'extracting' | 'cover' | 'saving' = 'extracting'
  @Local isSizeInitialized: boolean = false
  @Provider() file_folder_list: FileFolder[] = []
  @Local searchValue: string = ''
  @Local contentWidth: number = 0
  @Local holdingHand: motion.HoldingHandStatus | null = null
  @Provider() videoListController: VideoListController = new VideoListController()
  @Provider() fileFolderSource: FileFolderDataSource = new FileFolderDataSource([])
  @Provider() sideBarController: SideBarController = new SideBarController()
  @Provider('pathStack') pathStack: NavPathStack = new NavPathStack()
  @Local scrollToFolderDate: string = ''
  deletedVideosDialogController: CustomDialogController = new CustomDialogController({
    builder: DeletedVideosDialog(), cornerRadius: 20, shadow: DefaultDialogShadow
  })
  sideBarScroller: Scroller = new Scroller()
  private passwd: string = 'passwd'
  private videoValidityCheckRunning: boolean = false

  async onPageShow(): Promise<void> {
    await WantProcessUtil.checkWant(this.pathStack)
    const currentFolder = this.videoListController.folder
    if (currentFolder) {
      const updatedFolders = Preferences.getFileFolder(PathUtils.appContext!)
      const updatedFolder = updatedFolders.find(f => f.date === currentFolder.date)
      if (updatedFolder) {
        this.videoListController.videoDataSource.updateData(updatedFolder.video_list)
        this.videoListController.updateData(this.videoListController.videoDataSource, updatedFolder)
      }
    }
  }

  async aboutToAppear(): Promise<void> {
    await WindowUtil.init(PathUtils.appContext!)
    VideoOperateUtil.initSetting(PathUtils.appContext!)
    this.file_folder_list = Preferences.getFileFolder(PathUtils.appContext!)
    if (this.file_folder_list.length === 0) {
      this.file_folder_list = await FileFolderUtil.createNewFolder(PathUtils.appContext!, '首页')
    }
    const defaultStartupFolderDate = Preferences.getDefaultStartupFolder(PathUtils.appContext!)
    const isStreamStartup = defaultStartupFolderDate === '__stream__'
    const isIptvStartup = defaultStartupFolderDate === '__iptv__'
    const isIptvSourceStartup = defaultStartupFolderDate.startsWith('__iptv_src__')
    const defaultFolder = (defaultStartupFolderDate && !isStreamStartup && !isIptvStartup && !isIptvSourceStartup)
      ? this.file_folder_list.find(f => f.date === defaultStartupFolderDate) ?? this.file_folder_list[0]
      : this.file_folder_list[0]
    this.videoListController?.updateData(undefined, defaultFolder)
    if (isStreamStartup) {
      setTimeout(() => {
        this.pathStack.pushPathByName(NavigationAddress.STREAM_PAGE, null)
      }, 0)
    }
    if (isIptvStartup) {
      setTimeout(() => {
        this.pathStack.pushPathByName(NavigationAddress.IPTV_SOURCE_PAGE, null)
      }, 0)
    }
    if (isIptvSourceStartup) {
      const iptvSourceId = defaultStartupFolderDate.substring('__iptv_src__'.length)
      setTimeout(() => {
        this.pathStack.pushPathByName(NavigationAddress.IPTV_CHANNEL_PAGE,
          new IPTVChannelParams(iptvSourceId), true)
      }, 0)
    }
    void this.applySavedFolderSort()
    setTimeout(() => {
      SelectFileUtil.getDownloadUri()
      VideoMetaDataOperator.migrationRootVideoMetaToRootFolder()
      FileFolderUtil.fileFolderExistCheck()
      AccountUtil.initAccount()
      IntellectualGripPostureUtil.createHoldingHandStatus((data: motion.HoldingHandStatus) => {
        this.holdingHand = data
      })
      IntellectualGripPostureUtil.createOperatingHandStatus()
    }, 0)
    void this.checkInvalidVideos(this.file_folder_list)
  }

  async toMetaData(fileList: string[], fileFolder?: FileFolder) {
    await importAndProcessFiles(
      fileList,
      this.videoListController.videoDataSource?.getAllData() ?? [],
      (info: ProgressInfo) => {
        this.processedItems = info.current
        this.currentFileName = info.fileName
        this.currentStage = info.stage
        this.failedCount = info.failedCount
      },
      (loading: boolean) => {
        this.loading = loading
      },
      (totalItems: number) => {
        this.totalItems = totalItems
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
        this.file_folder_list = updatedFolders
      }
    )
  }

  build() {
    HdsNavigation(this.pathStack) {
      SideBarContainer(this.sideBarController.mode) {
        SideBarContentComponent({
          sideBarController: this.sideBarController,
          pathStack: this.pathStack,
          videoListController: this.videoListController,
          fileFolderSource: this.fileFolderSource,
          file_folder_list: this.file_folder_list,
          scrollToFolderDate: this.scrollToFolderDate,
          sideBarScroller: this.sideBarScroller,
          fileFolderListChange: (folders: FileFolder[]) => {
            this.file_folder_list = folders
          },
          scrollToFolderDateChange: (date: string) => {
            this.scrollToFolderDate = date
          },
          searchValueClear: (): boolean => this.clearSearchValue(),
          onImportProgress: (info: ProgressInfo) => {
            this.processedItems = info.current
            this.currentFileName = info.fileName
            this.currentStage = info.stage
            this.failedCount = info.failedCount
          },
          onImportLoading: (loading: boolean) => {
            this.loading = loading
          },
          onImportTotal: (totalItems: number) => {
            this.totalItems = totalItems
          }
        })

        Stack() {
          VideoView({
            loading: this.loading,
            searchValue: this.searchValue,
            holdingHand: this.holdingHand,
            onSearchValueChange: (v: string) => {
              this.searchValue = v
            },
            videoListController: this.videoListController,
            scrollToFolderDate: this.scrollToFolderDate,
            onScrollToFolderDateChange: (v: string) => {
              this.scrollToFolderDate = v
            }
          }).scale({
            x: this.sideBarController.isShow === true ? 0.95 : 1,
            y: this.sideBarController.isShow ? 0.95 : 1
          }).animation({ duration: 300, curve: Curve.Ease })
          if (this.loading) {
            ImportProgressBuilder({
              processedItems: this.processedItems,
              totalItems: this.totalItems,
              currentFileName: this.currentFileName,
              currentStage: this.currentStage,
              failedCount: this.failedCount
            })
          }
        }
        .backgroundColor(Setting.backgroundImageSrc.length > 0 ? '' : $r('app.color.start_window_background'))
        .onAreaChange(async (_oldValue: Area, newValue: Area) => {
          const width = Number(newValue.width)
          this.contentWidth = width
          this.videoListController.refresh(width, Setting.listDisplayMode)
        })
        .priorityGesture(SwipeGesture({ direction: SwipeDirection.Horizontal }).onAction((event: GestureEvent) => {
          this.handleFolderSwipe(event)
        }))
        .gesture(
          // 绑定二指触发的捏合手势
          PinchGesture({ fingers: 2 })
            .onActionEnd((event: PinchGestureEvent) => {
              const scaleValue = event.scale
              if (!Setting.allowGestureEntry) {
                return
              }
              this.passwd = Preferences.getPassword(PathUtils.appContext!)
              if (!this.passwd || this.passwd.length === 0) {
                return
              }
              if (scaleValue > 1.5) {
                if (BiometricAccessUtil.checkUserAuthSupport()) { // 支持生物认证时进行认证
                  BiometricAccessUtil.startUserAuth().then(isSuccess => {
                    if (isSuccess) { // 认证成功进入隐私空间
                      this.pathStack.replacePathByName(NavigationAddress.PRIVACY_SPACE, null)
                    } else {
                      ToolsUtil.showToast(
                        ToolsUtil.getStringResource($r('app.string.privacy_auth_failed').id)) // 认证失败显示提示
                    }
                  })
                  return
                }
                ToolsUtil.showToast(
                  ToolsUtil.getStringResource($r('app.string.privacy_enter_via_password').id)) // 设备不支持生物认证的提示
              }
            })
        )
      }
      .minSideBarWidth(DataSyncUtil.minSideBarWidth) // 设置侧边栏最小宽度
      .minContentWidth(DataSyncUtil.minContentWidth) // 设置内容区最小宽度
      .allowDrop([uniformTypeDescriptor.UniformDataType.PLAIN_TEXT, uniformTypeDescriptor.UniformDataType.VIDEO])
      .onSizeChange((_oldValue: SizeResult, newValue: SizeResult) => {
        if (newValue.width >= DataSyncUtil.minSideBarWidth + DataSyncUtil.minContentWidth) {
          if (!this.isSizeInitialized || this.sideBarController.mode !== SideBarContainerType.Embed) {
            this.sideBarController.mode = SideBarContainerType.Embed
            const visible = Preferences.getEmbedSidebarVisible(PathUtils.appContext!)
            this.sideBarController.visibility = visible ? Visibility.Visible : Visibility.Hidden
            this.sideBarController.isShow = visible
          }
        } else {
          if (!this.isSizeInitialized || this.sideBarController.mode !== SideBarContainerType.Overlay) {
            this.sideBarController.mode = SideBarContainerType.Overlay
            this.sideBarController.visibility = Visibility.Hidden
            this.sideBarController.isShow = false
          }
        }
        this.isSizeInitialized = true
      })
      .onChange((value: boolean) => {
        this.sideBarController.isShow = value
      })
      .showSideBar(this.sideBarController.isShow)
      .showControlButton(false)
      .divider({ strokeWidth: 0 })
      .gesture(SwipeGesture({ direction: SwipeDirection.Horizontal }).onAction((event: GestureEvent) => {
        if (event) {
          const rotateAngle = event.angle
          if (rotateAngle < -135 || rotateAngle > 135) {
            this.sideBarController.close(true)
          }
        }
      }))
    }
    .backgroundImage(
      Setting.backgroundDropBlur > 0 && Setting.backgroundBlurImageSrc.length > 0 ? Setting.backgroundBlurImageSrc :
        Setting.backgroundImageSrc, ImageRepeat.NoRepeat)
    .backgroundImageSize(ImageSize.Cover)
    .backgroundImagePosition(Alignment.Center)
    .hideTitleBar(true)
    .mode(NavigationMode.Stack)
    .navDestination(this.Pages)
    .bindToScrollable(
      [this.videoListController.listScroller, this.videoListController.waterFlowScroller]) // 绑定导航组件和可滚动容器组件
    .dynamicHideTitleBar({
      hideTitleArea: true,
      hideBottomBuilder: true,
      hideStatusBar: false,
      mode: HideMode.SCROLL_UP_TO
    })
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
    })
    .onDrop((dragEvent: DragEvent) => {
      let records: Array<unifiedDataChannel.UnifiedRecord> = []
      try {
        records = dragEvent.getData().getRecords()
      } catch (error) {
        ToolsUtil.showToast('获取数据时异常：' + error)
      }
      let video: unifiedDataChannel.Video = records[0] as unifiedDataChannel.Video
      WantProcessUtil.wantUri = video?.uri
      WantProcessUtil.hasWant(this.pathStack)
    })
    .onNavBarStateChange((isVisible: boolean) => {
      if (isVisible) {
        if (this.videoListController.folder?.video_list) {
          if (this.contentWidth > 0) {
            const currentScreenWidth = AppStorage.get('screen_width') as number ?? 0
            const currentScreenHeight = AppStorage.get('screen_height') as number ?? 0
            const currentIsLandscape = currentScreenWidth > currentScreenHeight
            const currentListDisplayMode = Setting.listDisplayMode
            const savedIsLandscape = AppStorage.get('saved_is_landscape') as boolean | undefined
            const savedListDisplayMode = AppStorage.get('saved_list_display_mode') as ListDisplayMode | undefined
            const savedListLine = AppStorage.get('saved_list_line') as number | undefined
            const savedMaxListLine = AppStorage.get('saved_max_list_line') as number | undefined
            const needRefresh = savedIsLandscape == undefined ||
              savedListDisplayMode == undefined ||
              savedListLine == undefined ||
              savedMaxListLine == undefined ||
              currentIsLandscape != savedIsLandscape ||
              currentListDisplayMode != savedListDisplayMode ||
              this.videoListController.listLine != savedListLine ||
              Setting.maxListLine != savedMaxListLine
            if (needRefresh) {
              this.videoListController.refresh(this.contentWidth, Setting.listDisplayMode)
            }
          }
          const targetFolder = this.videoListController.folder ?? this.file_folder_list[0]
          const updatedFolders = VideoUtils.refresh(this.videoListController, this.fileFolderSource, targetFolder)
          this.file_folder_list = updatedFolders
        }
        if (DataSyncUtil.lastPlayVideoIndex >= 0) {
          this.videoListController.getActiveScroller().scrollToIndex(DataSyncUtil.lastPlayVideoIndex)
          DataSyncUtil.lastPlayVideoIndex = -1
        }
        const value: string | undefined = AppStorage.get('searchValue')
        if (value) {
          this.searchValue = value
          AppStorage.set('searchValue', '')
        }
      } else {
        // 保存当前状态到 AppStorage
        const currentScreenWidth = AppStorage.get('screen_width') as number ?? 0
        const currentScreenHeight = AppStorage.get('screen_height') as number ?? 0
        const currentIsLandscape = currentScreenWidth > currentScreenHeight

        AppStorage.setOrCreate('saved_is_landscape', currentIsLandscape)
        AppStorage.setOrCreate('saved_list_display_mode', Setting.listDisplayMode)
        AppStorage.setOrCreate('saved_list_line', this.videoListController.listLine)
        AppStorage.setOrCreate('saved_max_list_line', Setting.maxListLine)
      }
    })
  }

  @Builder
  Pages(name: string) {
    if (name == NavigationAddress.SETTING_PAGE) {
      SettingsPage()
    } else if (name == NavigationAddress.ABOUT_PAGE) {
      AboutApp()
    } else if (name == NavigationAddress.RECENT_PLAY) {
      RecentPlay()
    } else if (name == NavigationAddress.PRIVACY_SPACE) {
      PrivacySpace()
    } else if (name == NavigationAddress.CRASH_PAGE) {
      CrashPage()
    } else if (name == NavigationAddress.PLAYER_SETTING_PAGE) {
      PlayerSettingPage()
    } else if (name == NavigationAddress.SUBTITLE_SETTING_PAGE) {
      SubtitleSettingPage()
    } else if (name == NavigationAddress.PERSONALIZE_PAGE) {
      PersonalizePage()
    } else if (name == NavigationAddress.PRIVACY_ERROR_LIST) {
      PrivacySpaceErrorList()
    } else if (name == NavigationAddress.MORE_SETTING_PAGE) {
      MoreSettingPage()
    } else if (name == NavigationAddress.VIDEO_PLAYER) {
      VideoPlayer()
    } else if (name == NavigationAddress.SHORT_VIDEO) {
      ShortVideoPage()
    } else if (name == NavigationAddress.VIP_PAGE) {
      GetVipPage()
    } else if (name == NavigationAddress.STREAM_PAGE) {
      StreamPage()
    } else if (name == NavigationAddress.IPTV_SOURCE_PAGE) {
      IPTVSourcePage()
    } else if (name == NavigationAddress.IPTV_CHANNEL_PAGE) {
      IPTVChannelPage()
    }
  }

  clearSearchValue() {
    if (this.searchValue.length > 0) {
      this.searchValue = ''
      return true
    } else {
      return false
    }
  }

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

  private async checkInvalidVideos(folders: FileFolder[]): Promise<void> {
    if (this.videoValidityCheckRunning) {
      return
    }
    this.videoValidityCheckRunning = true
    try {
      await this.doCheckInvalidVideos(folders)
    } catch (error) {
      salmonLogger.addLog(TAG, '检查视频有效性失败: ' + error, true)
    } finally {
      this.videoValidityCheckRunning = false
    }
  }

  private async doCheckInvalidVideos(folders: FileFolder[]): Promise<void> {
    const videosToCheck: VideoMetadata[] = []
    folders.forEach(folder => {
      folder.video_list.forEach(video => {
        const isExternalDevice = SelectFileUtil.isPathFromSource(video.uri, VideoSource.EXTERNAL_DEVICE)
        const normalizedUri = video.uri.toLowerCase()
        const isNetworkVideo = ToolsUtil.isNetworkUrl(normalizedUri) ||
          /\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/.test(normalizedUri)
        if (!isExternalDevice && !isNetworkVideo) {
          videosToCheck.push(video)
        }
      })
    })

    // 文档与媒体 URI 的持久化权限需要在 UI 线程激活；真正的文件探测仍放在 TaskPool 中。
    const batchSize = 8
    for (let start = 0; start < videosToCheck.length; start += batchSize) {
      const batch = videosToCheck.slice(start, start + batchSize)
      await Promise.all(batch.map(async (video: VideoMetadata) => {
        const needsPermissionActivation =
          SelectFileUtil.isPathFromSource(video.uri, VideoSource.DOCUMENT_SELECT_OPTION) ||
            SelectFileUtil.isPathFromSource(video.uri, VideoSource.PHOTO_SELECT_OPTION)
        if (needsPermissionActivation) {
          await PermissionUtil.activatePermission(video.uri)
        }
      }))
    }

    const invalidVideos = await checkUriProcess(videosToCheck)
    const invalidDates = new Set<string>()
    const result: VideoMetadata[] = []
    invalidVideos.forEach(video => {
      if (!invalidDates.has(video.date)) {
        invalidDates.add(video.date)
        result.push(video)
      }
    })
    if (result.length === 0) {
      return
    }

    const updatedFolders = Preferences.getFileFolder(PathUtils.appContext!)
    updatedFolders.forEach(folder => {
      folder.video_list = folder.video_list.filter(item => !invalidDates.has(item.date))
    })
    Preferences.saveFileFolder(PathUtils.appContext!, updatedFolders)

    await Promise.all(result.map(async (item: VideoMetadata) => {
      try {
        await Promise.all([
          SubtitleUtil.deleteSubtitle(PathUtils.subtitlePath, item.date),
          SelectFileUtil.deleteCover(item.date)
        ])
        RecentPlayUtil.delData(PathUtils.appContext!, item.uri)
      } catch (error) {
        salmonLogger.addLog(TAG, `清理视频资源失败: ${item.uri} ` + error, true)
      }
    }))

    const targetFolder = updatedFolders.find(folder => folder.date === this.videoListController.folder?.date) ??
      updatedFolders[0]
    this.file_folder_list = VideoUtils.refresh(this.videoListController, this.fileFolderSource, targetFolder)
    DataSyncUtil.deletedVideos = result
    setTimeout(() => {
      this.deletedVideosDialogController.open()
    }, 100)
  }

  private async applySavedFolderSort(): Promise<void> {
    const field = Preferences.getFolderSortField(PathUtils.appContext!) as SortField
    if (field !== SortField.FOLDER_NAME) {
      return
    }
    const source = this.file_folder_list
    const homeFolder = source.find(f => f.name === '首页' && f.parent_date === null)
    const others = source.filter(f => f.date !== homeFolder?.date)
    const sorted = await ToolsUtil.sortFoldersByNameInTaskPool(
      others, Preferences.getFolderSortAsc(PathUtils.appContext!), Preferences.getPinyinSort(PathUtils.appContext!)
    )
    if (source === this.file_folder_list) {
      this.file_folder_list = homeFolder ? [homeFolder, ...sorted] : sorted
    }
  }

  /**
   * 获取当前文件夹在列表中的索引
   */
  private getCurrentFolderIndex(): number {
    return FileFolderUtil.flattenTree(this.file_folder_list).findIndex(
      folder => folder.date === this.videoListController?.folder?.date
    )
  }

  /**
   * 切换到指定索引的文件夹
   */
  private switchToFolder(index: number): void {
    const treeFolders = FileFolderUtil.flattenTree(this.file_folder_list)
    const result = VideoUtils.switchFolder(
      index, treeFolders, this.videoListController, this.fileFolderSource, this.searchValue
    )
    if (!result) {
      return
    }
    this.file_folder_list = result.refreshedFolders
    this.scrollToFolderDate = result.currentFolder!.date
    const estimatedOffset = index > 0 ? 260 + (index - 1) * 70 : 0
    XAnimation.runWithAnimation(() => {
      this.sideBarScroller.scrollTo({
        xOffset: 0,
        yOffset: estimatedOffset,
        animation: { duration: 300, curve: Curve.Ease }
      })
    })
  }

  /**
   * 处理文件夹切换滑动手势
   */
  private handleFolderSwipe(event: GestureEvent): void {
    // 批量选择模式下禁止切换
    if (this.videoListController.multipleChooseState === Visibility.Visible) {
      return
    }
    // 侧边栏展开时（Overlay 模式）：左滑关闭侧边栏
    // Embed 模式下侧边栏始终展开，但仍允许文件夹切换
    if (this.sideBarController.visibility === Visibility.Visible &&
      this.sideBarController.mode === SideBarContainerType.Overlay) {
      const rotateAngle = event.angle ?? 0
      // 从右向左滑（手指从右往左移动，角度接近180/-180）-> 关闭侧边栏
      if (rotateAngle < -135 || rotateAngle > 135) {
        this.sideBarController.close(true)
      }
      return
    }
    const rotateAngle = event.angle ?? 0
    // 手势方向：手指移动方向
    // 从左往右滑（右滑）：角度接近0度
    // 从右往左滑（左滑）：角度接近180/-180度
    const isSwipeRight = rotateAngle > -45 && rotateAngle < 45
    const isSwipeLeft = rotateAngle < -135 || rotateAngle > 135
    // 面包屑未开启时：只允许右滑打开侧边栏（仅 Overlay 模式）
    if (!Setting.showToast) {
      if (isSwipeRight && this.sideBarController.mode === SideBarContainerType.Overlay) {
        this.sideBarController.open()
      }
      return
    }
    // 文件夹列表为空或只有一个时：右滑打开侧边栏（仅 Overlay 模式），左滑不响应
    const treeFolderCount = FileFolderUtil.flattenTree(this.file_folder_list).length
    if (treeFolderCount <= 1) {
      if (isSwipeRight && this.sideBarController.mode === SideBarContainerType.Overlay) {
        this.sideBarController.open()
      }
      return
    }
    const currentIndex = this.getCurrentFolderIndex()
    // 检查当前文件夹索引是否有效
    if (currentIndex === -1) {
      salmonLogger.addLog(TAG, `[Index] handleFolderSwipe: current folder not found in list`, true)
      return
    }
    const isFirstFolder = currentIndex === 0
    const isLastFolder = currentIndex === treeFolderCount - 1
    if (isSwipeRight) {
      if (isFirstFolder) {
        if (this.sideBarController.mode === SideBarContainerType.Overlay) {
          this.sideBarController.open()
        } else {
          this.switchToFolder(treeFolderCount - 1)
        }
      } else {
        this.switchToFolder(currentIndex - 1)
      }
    } else if (isSwipeLeft) {
      if (isLastFolder) {
        this.switchToFolder(0)
      } else {
        this.switchToFolder(currentIndex + 1)
      }
    }
  }
}
