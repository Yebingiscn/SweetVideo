import DataSyncUtil from '../utils/DataSyncUtil'
import { FileFolderDataSource } from '../utils/DataUtil'
import { AddFileFolderNameDialog } from '../component/Dialog/AddFileFolderNameDialog'
import FileFolderUtil from '../utils/FileFolderUtil'
import { EditFileFolderNameDialog } from '../component/Dialog/EditFileFolderNameDialog'
import { FileFolder } from '../interfaces/FileFolderInterface'
import { ButtonFancyModifier, DefaultDialogShadow, SymbolGlyphFancyModifier } from '../common/AttributeModifierConfig'
import { PathUtils } from '../utils/PathUtils'
import { VideoListController } from '../component/VideoItemComponent/VideoItemComponent'
import { SideBarController } from '../component/SideBarComponent/SideBar'
import { DeletedVideosDialog } from '../component/Dialog/DeletedVideosDialog'
import { motion } from '@kit.MultimodalAwarenessKit'
import Preferences from '../database/Preferences'
import { salmonLogger } from 'salmonlogger'
import { DeleteType } from '../common/enum/DeleteType'
import { ListDisplayMode } from '../common/enum/DisplayMode'
import { SortField } from '../common/enum/SortField'
import NavigationAddress from '../common/NavigationCommon'
import { userData, userLoginBuilder } from '../component/common/UserLoginComponent'
import { FileFolderListBuilder } from '../component/FileFolderComponent/FileFolderListComponent'
import { FolderSelectMenuBuilder } from '../component/FileFolderComponent/FileFolderSelectBuilder'
import { ImportProgressBuilder } from '../component/VideoItemComponent/ImportProgressBuilder'
import { VideoView } from '../component/VideoItemComponent/VideoViewComponent'
import { VideoMetaDataOperator } from '../database/VideoMetaData'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import AccountUtil from '../utils/AccountUtil'
import { XAnimation } from '../utils/AnimationUtil'
import BiometricAccessUtil from '../utils/BiometricAccessUtil'
import { importAndProcessFiles, ProgressInfo } from '../utils/FileProcessorUtil'
import IntellectualGripPostureUtil from '../utils/IntellectualGripPostureUtil'
import { SafeHeight, Setting } from '../utils/ObservedUtil'
import RecentPlayUtil from '../utils/RecentPlayUtil'
import SelectFileUtil from '../utils/SelectFileUtil'
import SubtitleUtil from '../utils/SubtitleUtil'
import { checkUriProcess } from '../utils/TaskpoolUtil'
import TimeUtil from '../utils/TimeUtil'
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
import { HdsNavigation, HideMode, ScrollEffectType } from '@kit.UIDesignKit'
import { unifiedDataChannel, uniformTypeDescriptor } from '@kit.ArkData'
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
  @Local isLogin: boolean = false
  @Provider() file_folder_list: FileFolder[] = []
  addFileFolderNameDialogController: CustomDialogController = new CustomDialogController({
    builder: AddFileFolderNameDialog({
      onFolderAdded: (folders: FileFolder[]) => {
        this.file_folder_list = folders
      }
    }), cornerRadius: 20, shadow: DefaultDialogShadow
  })
  @Local searchValue: string = ''
  @Local contentWidth: number = 0
  @Local holdingHand: motion.HoldingHandStatus | null = null
  @Provider() videoListController: VideoListController = new VideoListController()
  @Provider() fileFolderSource: FileFolderDataSource = new FileFolderDataSource([])
  editFileFolderNameDialogController: CustomDialogController = new CustomDialogController({
    builder: EditFileFolderNameDialog({
      confirm: async (newFolderName: string | undefined) => {
        if (!newFolderName || newFolderName.trim() == '') {
          return
        }
        await FileFolderUtil.changeFileFolderName(PathUtils.appContext!,
          DataSyncUtil.editingFolder!, newFolderName, this.fileFolderSource)
        const updatedFolders = Preferences.getFileFolder(PathUtils.appContext!) as FileFolder[]
        this.file_folder_list = updatedFolders
        this.fileFolderSource.updateData(updatedFolders)
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

  @Monitor('file_folder_list')
  onFileFolderListChanged() {
    this.fileFolderSource.updateData(this.file_folder_list)
  }

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
            if (newFolder) {
              this.scrollToFolderDate = newFolder.date
            }
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
        icon: $r('sys.symbol.folder_badge_eye'),
        content: `从下载文件夹导入（路径：Download/${ToolsUtil.getStringResource($r('app.string.EntryAbility_label')
          .id)}）`,
        onAction: async () => {
          this.sideBarController.close(false)
          await this.toMetaData(await SelectFileUtil.getDownloadFilesUri(), undefined)
        },
      },
      {
        icon: $r('sys.symbol.picture_2'),
        content: $r('app.string.import_from_album'),
        onAction: async () => {
          this.sideBarController.close(false)
          await this.toMetaData(await SelectFileUtil.selectFromFileManager(undefined, "album"),
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
    ])
  }

  async onPageShow(): Promise<void> {
    await WantProcessUtil.checkWant(PathUtils.appContext!, this.pathStack)
    const currentFolder = this.videoListController.folder
    if (currentFolder) {
      const updatedFolders = Preferences.getFileFolder(PathUtils.appContext!)
      const updatedFolder = updatedFolders.find(f => f.name === currentFolder.name)
      if (updatedFolder) {
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
    AccountUtil.initAccount()
    this.file_folder_list = Preferences.getFileFolder(PathUtils.appContext!)
    // 首次安装时如果没有文件夹，创建默认"首页"文件夹
    if (this.file_folder_list.length === 0) {
      this.file_folder_list = await FileFolderUtil.createNewFolder(PathUtils.appContext!, '首页')
    }
    this.videoListController?.updateData(undefined, this.file_folder_list[0])
    IntellectualGripPostureUtil.createHoldingHandStatus((data: motion.HoldingHandStatus) => {
      this.holdingHand = data
    })
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
    await importAndProcessFiles(
      fileList,
      this.videoListController.videoDataSource?.getAllData() ?? [],
      (info: ProgressInfo) => {
        this.processedItems = info.current
        this.currentFileName = info.fileName
        this.currentStage = info.stage
        this.importSpeed = info.speed
        this.elapsedTime = info.elapsedTime
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
        const targetFolder = this.videoListController.folder ?? this.file_folder_list[0]
        const sortField = Preferences.getSortField(PathUtils.appContext!) as SortField
        if (sortField) {
          const sortAsc = Preferences.getSortAsc(PathUtils.appContext!)
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
        Column() {
          Scroll(this.sideBarScroller) {
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
                ToolsUtil.showToast('不管多么难熬，人生都要眉开眼笑 ( •̀ ω •́ )✧')
              })

              Row() {
                Image(userData?.userAvatar || $r("app.media.Foreground"))
                  .width(50)
                  .height(50)
                  .borderRadius(25)
                  .interpolation(ImageInterpolation.Medium)// 用于重采样后的抗锯齿
                  .draggable(false)// 禁止长按手势拖动
                  .autoResize(true) // 重采样，可减少内存占用
                  .margin({ left: 10 })
                Text(userData.isLogin ? (userData.nickName || '已登录') : '点击登录')
                  .width('100%')
                  .fontSize(15)
                  .margin({ left: 10, right: 12 })
                  .textOverflow({ overflow: TextOverflow.MARQUEE })
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
              .bindSheet(this.isLogin, userLoginBuilder, {
                detents: [SheetSize.FIT_CONTENT],
                height: SheetSize.MEDIUM,
                preferType: SheetType.CENTER,
                enableOutsideInteractive: false,
                dragBar: true,
                showClose: true,
                title: { title: '账号信息' },
                onWillDismiss: () => {
                  this.isLogin = false
                }
              })

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
                .backgroundColor(Color.Transparent)
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
                .backgroundColor(Color.Transparent)
                .animation({ duration: 300, curve: Curve.Ease })
                .onClick(() => {
                  this.addFileFolderNameDialogController.open()
                })
              }
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

              //文件夹列表
              List() {
                Repeat<FileFolder>(this.fileFolderSource.data)
                  .each((repeatItem: RepeatItem<FileFolder>) => {
                    ListItem() {
                      FileFolderListBuilder({
                        folder: repeatItem.item,
                        videoListController: this.videoListController
                      })
                    }
                    .onClick(() => {
                      this.clearSearchValue()
                      if (this.videoListController.folder?.date === repeatItem.item.date) {
                        return
                      }
                      this.file_folder_list = Preferences.getFileFolder(PathUtils.appContext!)
                      const currentFolder = this.fileFolderSource.getFileFolder(repeatItem.item.name)
                      let folderVideos: VideoMetadata[] = currentFolder.video_list
                      const sortField = Preferences.getSortField(PathUtils.appContext!) as SortField
                      if (sortField) {
                        const sortAsc = Preferences.getSortAsc(PathUtils.appContext!)
                        ToolsUtil.sortBy(PathUtils.appContext!, folderVideos, currentFolder, sortField, sortAsc)
                      }
                      this.videoListController.videoDataSource.updateData(folderVideos)
                      this.videoListController.updateData(this.videoListController.videoDataSource, currentFolder!)
                      // 同步面包屑选中状态
                      this.scrollToFolderDate = repeatItem.item.date
                      this.sideBarController.close(true)
                    })
                    .bindContextMenu(this.FileFolderSelectMenu(repeatItem.item), ResponseType.LongPress)
                    .bindContextMenu(this.FileFolderSelectMenu(repeatItem.item), ResponseType.RightClick)
                    .height(60)
                  })
                  .key((item: FileFolder, _index: number) => item.name + item.date + item.video_list.toString())
                  .virtualScroll()
              }
              .borderRadius(16)
              .width('100%')
              .height('auto')
              .align(Alignment.Start)
              .margin({ top: 10, bottom: 10 })
              .backgroundColor($r('app.color.list_item_background'))
              .shadow({
                radius: 4,
                color: $r('app.color.shadow_color'),
                offsetX: 0,
                offsetY: 1
              })
            }.width('100%')
          }
          .fadingEdge(true)
          .margin({ top: 10 })
          .padding({ left: 20, right: 20 })
          .layoutWeight(1)
          .align(Alignment.Top)
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
            .backgroundColor(Color.Transparent)
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
            .backgroundColor(Color.Transparent)
            .animation({ duration: 300, curve: Curve.Ease })
            .onClick(() => {
              this.sideBarController.close(false)
              this.pathStack.pushPathByName(NavigationAddress.SETTING_PAGE, null)
            })
          }
          .margin({ bottom: SafeHeight.bottomSafeHeight === 0 ? 15 : SafeHeight.bottomSafeHeight, left: 20, right: 20 })
          .justifyContent(FlexAlign.Start)
          .backgroundColor($r('app.color.list_item_background'))
          .borderRadius(16)
          .shadow({
            radius: 4,
            color: $r('app.color.shadow_color'),
            offsetX: 0,
            offsetY: 1
          })
        }
        .width('100%')
        .justifyContent(FlexAlign.Start)
        .backgroundColor(Setting.backgroundImageSrc.length > 0 ? '' : $r('app.color.sidebar_background_color'))
        .transition(TransitionEffect.translate({ x: -300 })
          .combine(TransitionEffect.OPACITY)
          .animation(XAnimation.getAnimationCurve()))
        .visibility(this.sideBarController.visibility)
        .borderRadius(this.sideBarController.mode === SideBarContainerType.Overlay ? 16 : 0)

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
              speed: this.importSpeed,
              elapsedTime: this.elapsedTime,
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
    .backgroundImage(
      Setting.backgroundDropBlur > 0 && Setting.backgroundBlurImageSrc.length > 0 ? Setting.backgroundBlurImageSrc :
        Setting.backgroundImageSrc, ImageRepeat.NoRepeat)
    .backgroundImageSize(ImageSize.Cover)
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
    .onNavBarStateChange((isVisible: boolean) => {
      if (isVisible) {
        // 从其他页面返回时，用内容区实际宽度重新计算列数
        // 覆盖场景：设置页修改了 listDisplayMode、屏幕方向变化后返回
        if (this.contentWidth > 0) {
          // 获取当前状态
          const currentScreenWidth = AppStorage.get('screen_width') as number ?? 0
          const currentScreenHeight = AppStorage.get('screen_height') as number ?? 0
          const currentIsLandscape = currentScreenWidth > currentScreenHeight
          const currentListDisplayMode = Setting.listDisplayMode

          // 获取保存的状态
          const savedIsLandscape = AppStorage.get('saved_is_landscape') as boolean | undefined
          const savedListDisplayMode = AppStorage.get('saved_list_display_mode') as ListDisplayMode | undefined
          const savedListLine = AppStorage.get('saved_list_line') as number | undefined

          salmonLogger.addLog(TAG,
            `保存的状态：[${this.passwd}] saved_is_landscape: ${savedIsLandscape}, saved_list_display_mode: ${savedListDisplayMode}, saved_list_line: ${savedListLine}`)
          salmonLogger.addLog(TAG,
            `当前的状态[${this.passwd}] current_is_landscape: ${currentIsLandscape}, current_list_display_mode: ${currentListDisplayMode}, current_list_line: ${this.videoListController.listLine}`)
          // 判断是否需要重新计算：三者都一致则不计算
          const needRefresh = savedIsLandscape === undefined ||
            savedListDisplayMode === undefined ||
            savedListLine === undefined ||
            currentIsLandscape !== savedIsLandscape ||
            currentListDisplayMode !== savedListDisplayMode ||
            this.videoListController.listLine !== savedListLine

          if (needRefresh) {
            // 有不一致项，重新计算
            this.videoListController.refresh(this.contentWidth, Setting.listDisplayMode)
          }
        }

        if (this.videoListController.folder?.video_list) {
          const currentScreenWidth = AppStorage.get('screen_width') as number ?? 0
          const actualContentWidth = this.sideBarController.mode === SideBarContainerType.Embed
            ? currentScreenWidth - DataSyncUtil.minContentWidth
            : currentScreenWidth
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
      } else {
        // 保存当前状态到 AppStorage
        const currentScreenWidth = AppStorage.get('screen_width') as number ?? 0
        const currentScreenHeight = AppStorage.get('screen_height') as number ?? 0
        const currentIsLandscape = currentScreenWidth > currentScreenHeight

        AppStorage.setOrCreate('saved_is_landscape', currentIsLandscape)
        AppStorage.setOrCreate('saved_list_display_mode', Setting.listDisplayMode)
        AppStorage.setOrCreate('saved_list_line', this.videoListController.listLine)
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
    const result = VideoUtils.switchFolder(
      index, this.file_folder_list, this.videoListController, this.fileFolderSource, this.searchValue
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
      if (isFirstFolder) {
        if (this.sideBarController.mode === SideBarContainerType.Overlay) {
          this.sideBarController.open()
        } else {
          this.switchToFolder(this.file_folder_list.length - 1)
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