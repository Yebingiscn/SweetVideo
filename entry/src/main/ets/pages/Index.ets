import DataSyncUtil from '../utils/DataSyncUtil'
import { FileFolderDataSource } from '../utils/DataUtil'
import { AddFileFolderNameDialog } from '../component/Dialog/AddFileFolderNameDialog'
import FileFolderUtil from '../utils/FileFolderUtil'
import { EditFileFolderNameDialog } from '../component/Dialog/EditFileFolderNameDialog'
import { FileFolder } from '../interfaces/FileFolderInterface'
import { ButtonFancyModifier, DefaultDialogShadow, SymbolGlyphFancyModifier } from '../common/AttributeModifierConfig'
import { PathUtils } from '../utils/PathUtils'
import { VideoListController } from '../component/VideoItemComponent/VideoItemComponent'
import { AppInfoBuilder, SideBarController } from '../component/SideBarComponent/SideBar'
import { DeletedVideosDialog } from '../component/Dialog/DeletedVideosDialog'
import { DeleteType } from '../common/enum/DeleteType'
import NavigationAddress from '../common/NavigationCommon'
import { FileFolderListBuilder } from '../component/FileFolderComponent/FileFolderListComponent'
import { FolderSelectMenuBuilder } from '../component/FileFolderComponent/FileFolderSelectBuilder'
import { ImportProgressBuilder } from '../component/VideoItemComponent/ImportProgressBuilder'
import { VideoView } from '../component/VideoItemComponent/VideoViewComponent'
import Preferences from '../database/Preferences'
import { VideoMetaDataOperator } from '../database/VideoMetaData'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import { XAnimation } from '../utils/AnimationUtil'
import BiometricAccessUtil from '../utils/BiometricAccessUtil'
import { FileProcessorUtil, ProgressInfo } from '../utils/FileProcessorUtil'
import { SafeHeight, Setting } from '../utils/ObservedUtil'
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
import { MoreSettingPage } from './SettingPage/MoreSettingPage'
import { PersonalizePage } from './SettingPage/PersonalizePage'
import { PlayerSettingPage } from './SettingPage/PlayerSettingPage'
import { SettingsPage } from './SettingPage/Setting'
import { MpvPlayer } from './VideoPlayer/MpvPlayer'
import { Player } from './VideoPlayer/Player'
import { unifiedDataChannel, uniformTypeDescriptor } from '@kit.ArkData'
import { salmonLogger } from 'salmonlogger'
import IntellectualGripPostureUtil from '../utils/IntellectualGripPostureUtil'
import { HdsNavigation, HideMode, ScrollEffectType } from '@hms.hds.hdsBaseComponent'
import { LengthMetrics } from '@kit.ArkUI'

const TAG = 'Index'

@Entry
@ComponentV2
struct Index {
  @Local list_empty_item: string[] = ['']
  @Local loading: boolean = false
  @Local processedItems: number = 0
  @Local totalItems: number = 0
  @Local currentFileName: string = '' // 当前处理的文件名
  @Local importSpeed: number = 0 // 处理速度
  @Local elapsedTime: number = 0 // 已耗时
  @Local failedCount: number = 0 // 失败文件数
  @Local currentStage: 'extracting' | 'cover' | 'saving' = 'extracting' // 当前处理阶段
  @Provider() file_folder_list: FileFolder[] = []
  @Local searchValue: string = ''
  @Local screen_width: number = AppStorage.get('screen_width') as number ?? 0
  @Provider() videoListController: VideoListController = new VideoListController()
  @Provider() fileFolderSource: FileFolderDataSource = new FileFolderDataSource([])
  addFileFolderNameDialogController: CustomDialogController = new CustomDialogController({
    builder: AddFileFolderNameDialog({
      fileFolderSource: this.fileFolderSource,
      onFolderAdded: (folders: FileFolder[]) => {
        this.file_folder_list = folders
      }
    }), cornerRadius: 20, shadow: DefaultDialogShadow
  })
  editFileFolderNameDialogController: CustomDialogController = new CustomDialogController({
    builder: EditFileFolderNameDialog({
      confirm: async (newFolderName: string | undefined) => {
        if (!newFolderName || newFolderName.trim() == '') {
          return
        }
        await FileFolderUtil.changeFileFolderName(PathUtils.appContext!,
          DataSyncUtil.editingFolder!, newFolderName, this.fileFolderSource)
      }
    }), cornerRadius: 20, shadow: DefaultDialogShadow
  })
  @Provider() sideBarController: SideBarController = new SideBarController()
  @Provider('pathStack') pathStack: NavPathStack = new NavPathStack()
  @Local scrollToFolderDate: string = ''
  deletedVideosDialogController: CustomDialogController = new CustomDialogController({
    builder: DeletedVideosDialog(), cornerRadius: 20, shadow: DefaultDialogShadow
  })
  // 侧边栏滚动控制器
  private sideBarScroller: Scroller = new Scroller()
  private passwd: string = 'passwd'

  @Builder
  FileFolderSelectMenu(folder: FileFolder) {
    if (folder.name !== '首页') {
      FolderSelectMenuBuilder([
        {
          icon: $r("sys.symbol.trash_fill"),
          content: $r('app.string.delete'),
          onAction: async () => {
            DataSyncUtil.delMultipleList = Array.from(folder.video_list)
            await Promise.all(
              DataSyncUtil.delMultipleList.map(async item => {
                await VideoMetaDataOperator.deleteItem(this.videoListController, this.fileFolderSource, DeleteType.SOFT,
                  item)
              })
            )
            this.videoListController.closeMultipleChoose()
            this.file_folder_list = FileFolderUtil.deleteFileFolder(PathUtils.appContext!, folder)
            let newFolder: FileFolder | undefined
            if (this.videoListController.folder?.date === folder.date) {
              newFolder = this.file_folder_list[0]
            } else {
              newFolder = this.videoListController.folder
            }
            this.videoListController.folder = newFolder
            VideoUtils.refresh(this.videoListController, this.fileFolderSource, newFolder)
          },
        },
        {
          icon: $r('sys.symbol.rename'),
          content: $r('app.string.edit'),
          onAction: () => {
            DataSyncUtil.editingFolder = folder
            this.editFileFolderNameDialogController.open()
          },
        },
      ])
    }
  }

  @Builder
  SelectFileMenuBuilder() {
    FolderSelectMenuBuilder([
      {
        icon: $r("sys.symbol.resolution_video"),
        content: $r('app.string.import_from_videos'),
        onAction: async () => {
          this.sideBarController.close(false)
          await this.toMetaData(await SelectFileUtil.selectFromFileManager(undefined, "video"),
            this.videoListController.folder)
        },
      },
      {
        icon: $r('sys.symbol.music'),
        content: $r('app.string.import_from_music'),
        onAction: async () => {
          this.sideBarController.close(false)
          await this.toMetaData(await SelectFileUtil.selectFromFileManager(undefined, "audio"),
            this.videoListController.folder)
        },
      },
      {
        icon: $r('sys.symbol.folder_badge_eye'),
        content: `从下载文件夹导入（路径：Download/${ToolsUtil.getStringResource($r('app.string.EntryAbility_label')
          .id)}）`,
        onAction: async () => {
          this.sideBarController.close(false)
          await this.toMetaData(await SelectFileUtil.getDownloadFilesUri(), undefined)
        },
      },
    ])
  }

  async onPageShow(): Promise<void> {
    await WantProcessUtil.checkWant(PathUtils.appContext!, this.pathStack)
    // 从播放器返回时刷新数据源，确保播放进度更新
    const currentFolder = this.videoListController.folder
    if (currentFolder) {
      const updatedFolders = Preferences.getFileFolder(PathUtils.appContext!)
      const updatedFolder = updatedFolders.find(f => f.name === currentFolder.name)
      if (updatedFolder) {
        // 使用增量更新而不是全量重载
        this.videoListController.videoDataSource.updateData(updatedFolder.video_list)
        this.videoListController.updateData(this.videoListController.videoDataSource, updatedFolder)
      }
    }
  }

  async aboutToAppear(): Promise<void> {
    await WindowUtil.init(PathUtils.appContext!)
    SelectFileUtil.getDownloadUri()
    VideoOperateUtil.initSetting(PathUtils.appContext!)
    VideoMetaDataOperator.migrationRootVideoMetaToRootFolder()
    FileFolderUtil.fileFolderExistCheck()
    this.file_folder_list = Preferences.getFileFolder(PathUtils.appContext!)
    // 首次安装时如果没有文件夹，创建默认"首页"文件夹
    if (this.file_folder_list.length === 0) {
      this.file_folder_list = await FileFolderUtil.createNewFolder(PathUtils.appContext!, '首页')
    }
    this.fileFolderSource?.updateData(this.file_folder_list)
    this.videoListController?.updateData(undefined, this.file_folder_list[0])
    IntellectualGripPostureUtil.createHoldingHandStatus()
    IntellectualGripPostureUtil.createOperatingHandStatus()
    checkUriProcess(Preferences.getFileFolder(PathUtils.appContext!), (re: Object) => {
      const result = re as Array<VideoMetadata>
      if (result.length > 0) {
        // 在主线程中清理资源（字幕、历史记录、封面）
        result.forEach(async (item: VideoMetadata) => {
          try {
            await Promise.all([
              SubtitleUtil.deleteSubtitle(PathUtils.subtitlePath, item.date!),
              RecentPlayUtil.delData(PathUtils.appContext!, item.uri),
              SelectFileUtil.deleteCover(item.date!)
            ])
          } catch (error) {
            salmonLogger.addLog(TAG, `清理视频资源失败: ${item.uri} ` + error)
          }
        })

        // 删除视频并刷新列表
        setTimeout(() => {
          result.forEach(async item => {
            await this.videoListController.videoDataSource?.deleteUnExistFile(item, this.videoListController,
              this.fileFolderSource)
          })
          const targetFolder = this.videoListController.folder ?? this.file_folder_list[0]
          const updatedFolders = VideoUtils.refresh(this.videoListController, this.fileFolderSource, targetFolder)
          // 更新文件夹列表状态，确保面包屑等UI正确刷新
          this.file_folder_list = updatedFolders

          // 显示删除视频弹框
          DataSyncUtil.deletedVideos = result
          this.deletedVideosDialogController.open()
        }, 100)
      }
    })
  }

  async toMetaData(fileList: string[], fileFolder?: FileFolder) {
    if (fileList.length === 0) {
      ToolsUtil.showToast('没有任何文件被导入哦~')
      return
    }
    this.loading = true
    this.totalItems = fileList.length
    this.processedItems = 0
    this.currentFileName = ''
    this.importSpeed = 0
    this.elapsedTime = 0
    this.failedCount = 0
    try {
      await FileProcessorUtil.processFilesConcurrently(
        fileList, PathUtils.appContext!, PathUtils.videoPath, PathUtils.coverPath,
        this.videoListController.videoDataSource?.getAllData() ?? [],
        (info: ProgressInfo) => {
          this.processedItems = info.current
          this.currentFileName = info.fileName
          this.currentStage = info.stage
          this.importSpeed = info.speed
          this.elapsedTime = info.elapsedTime
          this.failedCount = info.failedCount
        },
        fileFolder
      )
      ToolsUtil.showToast(
        `${ToolsUtil.getStringResource($r('app.string.add_time_info').id)}${this.totalItems -
          FileFolderUtil.duplicateVideo - FileProcessorUtil.failedFiles.length}${
        FileFolderUtil.duplicateVideo > 0 ? '，跳过重复视频：' + FileFolderUtil.duplicateVideo : ''}${
        FileProcessorUtil.failedFiles.length > 0 ? '，失败：' + FileProcessorUtil.failedFiles.length : ''}`
      )
    } catch (error) {
      ToolsUtil.showToast('处理过程中发生意外错误:' + error)
    } finally {
      this.loading = false
      const targetFolder = this.videoListController.folder ?? this.file_folder_list[0]
      const updatedFolders = VideoUtils.refresh(this.videoListController, this.fileFolderSource, targetFolder)
      // 更新文件夹列表状态，确保面包屑等UI正确刷新
      this.file_folder_list = updatedFolders
    }
  }

  build() {
    HdsNavigation(this.pathStack) {
      SideBarContainer(this.sideBarController.mode) {
        Column() {
          Scroll(this.sideBarScroller) {
            Column() {
              AppInfoBuilder({ topSafeHeight: SafeHeight.topSafeHeight })
              Column() {
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
                .bindMenu(this.SelectFileMenuBuilder)
                .width('100%')

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
                  this.addFileFolderNameDialogController.open()
                })
              }.margin({ top: 10 })
              .justifyContent(FlexAlign.Start)
              .backgroundColor($r('app.color.start_window_background_blur'))
              .borderRadius(16)

              //文件夹列表
              List() {
                LazyForEach(this.fileFolderSource, (folder: FileFolder) => {
                  ListItem() {
                    FileFolderListBuilder({
                      folder: folder,
                      videoListController: this.videoListController
                    })
                  }
                  .onClick(() => {
                    this.clearSearchValue()
                    if (this.videoListController.folder?.date === folder.date) {
                      return
                    }
                    this.file_folder_list = Preferences.getFileFolder(PathUtils.appContext!)
                    this.fileFolderSource.updateData(this.file_folder_list)
                    const currentFolder = this.fileFolderSource.getFileFolder(folder.name)
                    this.videoListController.videoDataSource.updateData(currentFolder.video_list)
                    this.videoListController.updateData(this.videoListController.videoDataSource, currentFolder!)
                    // 同步面包屑选中状态
                    this.scrollToFolderDate = folder.date
                    this.sideBarController.close(true)
                  })
                  .bindContextMenu(this.FileFolderSelectMenu(folder), ResponseType.LongPress)
                  .bindContextMenu(this.FileFolderSelectMenu(folder), ResponseType.RightClick)
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
            }.width('100%')
          }
          .margin({ top: 10 })
          .padding({ left: 20, right: 20 })
          .layoutWeight(1)
          .align(Alignment.Top)
          .scrollable(ScrollDirection.Vertical) // 启用垂直滚动
          .edgeEffect(EdgeEffect.Spring) // 滚动边缘效果
          .scrollBar(BarState.Off)
          .width('100%')
          .height('100%')

          Column() {
            Button({ type: ButtonType.Normal, stateEffect: true }) {
              Row() {
                SymbolGlyph($r('sys.symbol.clock')).attributeModifier(new SymbolGlyphFancyModifier(25, '', ''))
                Text($r('app.string.recent_play'))
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
              this.pathStack.pushPathByName(NavigationAddress.RECENT_PLAY, true)
            })

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
              this.pathStack.pushPathByName(NavigationAddress.SETTING_PAGE, null)
            })
          }
          .margin({ bottom: SafeHeight.bottomSafeHeight === 0 ? 15 : SafeHeight.bottomSafeHeight, left: 20, right: 20 })
          .justifyContent(FlexAlign.Start)
          .backgroundColor($r('app.color.start_window_background_blur'))
          .borderRadius(16)
        }
        .width('100%')
        .justifyContent(FlexAlign.Start)
        .backgroundColor(Setting.backgroundImageSrc.length > 0 ? '' : $r('app.color.start_window_background'))
        .transition(TransitionEffect.translate({ x: -300 }).animation(XAnimation.getAnimationCurve()))
        .visibility(this.sideBarController.visibility)
        .borderRadius(this.sideBarController.mode === SideBarContainerType.Overlay ? 16 : 0)

        Stack() {
          VideoView({
            loading: this.loading,
            searchValue: this.searchValue,
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
              speed: this.importSpeed,
              elapsedTime: this.elapsedTime,
              failedCount: this.failedCount
            })
          }
        }
        .backgroundColor(Setting.backgroundImageSrc.length > 0 ? '' : $r('app.color.start_window_background'))
        .onAreaChange(async (_oldValue: Area, newValue: Area) => {
          const width = Number(newValue.width)
          // 增加判断，旋转时保持滚动位置不变
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
                      ToolsUtil.showToast('验证失败，请从首页搜索框输入密码进入隐私空间') // 认证失败显示提示
                    }
                  })
                  return
                }
                ToolsUtil.showToast('请从首页搜索框输入密码进入隐私空间') // 设备不支持生物认证的提示
              }
            })
        )
      }
      .minSideBarWidth(DataSyncUtil.minSideBarWidth) // 设置侧边栏最小宽度
      .minContentWidth(DataSyncUtil.minContentWidth) // 设置内容区最小宽度
      .allowDrop([uniformTypeDescriptor.UniformDataType.PLAIN_TEXT, uniformTypeDescriptor.UniformDataType.VIDEO])
      .onSizeChange((_oldValue: SizeResult, newValue: SizeResult) => {
        if (newValue.width >= DataSyncUtil.minSideBarWidth + DataSyncUtil.minContentWidth) {
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
      .gesture(SwipeGesture({ direction: SwipeDirection.Horizontal }).onAction((event: GestureEvent) => {
        if (event) {
          const rotateAngle = event.angle
          if (rotateAngle < -135 || rotateAngle > 135) {
            this.sideBarController.close(true)
          }
        }
      }))
    }
    .backgroundImage(Setting.backgroundImageSrc, ImageRepeat.NoRepeat)
    .backgroundImageSize(ImageSize.Cover)
    .backdropBlur(Setting.backgroundDropBlur)
    .backgroundImagePosition(Alignment.Center)
    .hideTitleBar(true)
    .mode(NavigationMode.Stack)
    .navDestination(this.Pages)
    .bindToScrollable([this.videoListController.listScroller]) // 绑定导航组件和可滚动容器组件
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
      WantProcessUtil.hasWant(PathUtils.appContext!, this.pathStack)
    })
    .onNavBarStateChange(async (isVisible: boolean) => {
      if (isVisible) {
        // 增加判断，旋转时保持滚动位置不变
        if (this.videoListController.folder?.video_list) {
          const actualContentWidth = this.screen_width - DataSyncUtil.minContentWidth
          this.videoListController.refresh(actualContentWidth, Setting.listDisplayMode)
          const targetFolder = this.videoListController.folder ?? this.file_folder_list[0]
          const updatedFolders = VideoUtils.refresh(this.videoListController, this.fileFolderSource, targetFolder)
          // 更新文件夹列表状态，确保面包屑等UI正确刷新
          this.file_folder_list = updatedFolders
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

  @Builder
  Pages(name: string) {
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

  /**
   * 获取当前文件夹在列表中的索引
   */
  private getCurrentFolderIndex(): number {
    return this.file_folder_list.findIndex(
      folder => folder.date === this.videoListController?.folder?.date
    )
  }

  /**
   * 切换到指定索引的文件夹
   */
  private switchToFolder(index: number): void {
    if (index < 0 || index >= this.file_folder_list.length) {
      return
    }

    const targetFolder = this.file_folder_list[index]
    if (this.videoListController.folder?.date === targetFolder.date) {
      return
    }

    // 保留搜索状态，在新文件夹中应用搜索过滤

    // 刷新文件夹列表（确保数据最新）
    this.file_folder_list = Preferences.getFileFolder(PathUtils.appContext!)
    this.fileFolderSource.updateData(this.file_folder_list)

    // 获取目标文件夹的最新数据
    const currentFolder = this.fileFolderSource.getFileFolder(targetFolder.name)
    if (currentFolder) {
      // 如果有搜索值，在新文件夹中过滤视频
      let filteredVideos = currentFolder.video_list
      if (this.searchValue.length > 0) {
        filteredVideos = SelectFileUtil.getItemFromSearch(currentFolder.video_list, this.searchValue)
      }
      // 添加过渡动画
      animateToImmediately({
        duration: 200,
        curve: Curve.EaseInOut
      }, () => {
        this.videoListController.videoDataSource.updateData(filteredVideos)
        this.videoListController.updateData(
          this.videoListController.videoDataSource,
          currentFolder
        )
      })
    }

    // 触发面包屑滚动（为 Task 2 预留）
    this.scrollToFolderDate = targetFolder.date

    // 滚动侧边栏使当前文件夹可见
    // 估算位置：AppInfoBuilder(100) + 导入按钮(60) + 添加文件夹按钮(60) + 间距(40) = 260
    // 文件夹列表从约 260vp 开始，每个文件夹 70vp
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
    if (this.file_folder_list.length <= 1) {
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
    const isLastFolder = currentIndex === this.file_folder_list.length - 1

    if (isSwipeRight) {
      // 从左向右滑
      if (isFirstFolder) {
        // 第一个文件夹右滑 -> 打开侧边栏（仅 Overlay 模式）
        if (this.sideBarController.mode === SideBarContainerType.Overlay) {
          this.sideBarController.open()
        }
        // Embed 模式下侧边栏已固定，无需操作
      } else {
        // 切换到上一个文件夹
        this.switchToFolder(currentIndex - 1)
      }
    } else if (isSwipeLeft) {
      // 从右向左滑
      if (!isLastFolder) {
        this.switchToFolder(currentIndex + 1)
      }
    }
  }
}