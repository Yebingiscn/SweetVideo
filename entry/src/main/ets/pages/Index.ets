import { SymbolGlyphModifier } from '@kit.ArkUI';
import DataSyncUtil, { OOBEVersion } from '../utils/DataSyncUtil';
import { FileFolderDataSource } from '../utils/DataUtil';
import ToolsUtil from '../utils/ToolsUtil';
import SelectFileUtil from '../utils/SelectFileUtil';
import { JSON } from '@kit.ArkTS';
import WantProcessUtil from '../utils/WantProcessUtil';
import { unifiedDataChannel, uniformTypeDescriptor } from '@kit.ArkData';
import { AddFileFolderNameDialog } from '../component/Dialog/AddFileFolderNameDialog';
import FileFolderUtil from '../utils/FileFolderUtil';
import { EditFileFolderNameDialog } from '../component/Dialog/EditFileFolderNameDialog';
import { FileFolder } from '../interfaces/FileFolderInterface';
import { DefaultDialogShadow } from '../common/DefaultDialogShadow';
import ScreenUtil from '../utils/ScreenUtil';
import { SettingsPage } from './Setting';
import { AboutApp } from './AboutApp';
import { FFMpegPlayer } from './FFMpegPlayer';
import { Player } from './Player';
import { RecentPlay } from './RecentPlay';
import { PrivacyPolicyDialog } from './PrivacyInfo';
import VideoOperateUtil from '../utils/VideoOperateUtil';
import { PrivacySpace } from './PrivacySpace';
import Preferences from '../database/Preferences';
import { RedPlayer } from './RedPlayer';
import { ButtonFancyModifier, MenuModifier, SymbolGlyphFancyModifier } from '../utils/AttributeModifierUtil';
import { FileProcessorUtil } from '../utils/FileProcessorUtil';
import { PathUtils } from '../utils/PathUtils';
import { VideoListController } from '../component/VideoItemComponent/VideoItemComponent';
import { AppInfo, SideBarController } from '../component/SideBarComponent/SideBar';
import { VideoView } from '../component/VideoItemComponent/VideoViewComponent';
import { ImportProgressComponent } from '../component/VideoItemComponent/ImportProgressComponent';
import { VideoMetaDataOperator } from '../database/VideoMetaData';
import { FileFolderListComponent } from '../component/FileFolderComponent/FileFolderListComponent';
import VideoUtils from '../utils/VideoUtil';
import NavigationAddress from '../common/NavigationAddress';
import { taskpoolExecTool } from '../utils/TaskpoolUtil';
import { VideoMetadata } from '../interfaces/VideoMetadataInterface';
import { DeletedVideosDialog } from '../component/Dialog/DeletedVideosDialog';

@Builder
export function IndexBuilder() {
  Index()
}

@Entry
@Component
struct Index {
  @State passwd: string = 'passwd'
  @State list_empty_item: string[] = ['']
  @State loading: boolean = false
  @State processedItems: number = 0
  @State totalItems: number = 0
  @State file_folder_list: FileFolder[] = []
  @State searchValue: string = ''
  @StorageLink('isListDisplay') isListDisplay: boolean = false
  @StorageProp('screen_width') screen_width: number = 0
  @StorageProp('screen_height') screen_height: number = 0
  @StorageProp('topSafeHeight') topSafeHeight: number = 0;
  @StorageProp('bottomSafeHeight') bottomSafeHeight: number = 0;
  @Provide videoListController: VideoListController = new VideoListController()
  @Provide fileFolderSource: FileFolderDataSource = new FileFolderDataSource([])
  @Provide sideBarController: SideBarController = new SideBarController()
  @Provide('pathStack') pathStack: NavPathStack = new NavPathStack()
  addFileFolderNameDialogController: CustomDialogController = new CustomDialogController({
    builder: AddFileFolderNameDialog(), cornerRadius: 20, shadow: DefaultDialogShadow
  })
  deletedVideosDialogController: CustomDialogController = new CustomDialogController({
    builder: DeletedVideosDialog(), cornerRadius: 20, shadow: DefaultDialogShadow
  })
  editFileFolderNameDialogController: CustomDialogController = new CustomDialogController({
    builder: EditFileFolderNameDialog({
      confirm: async (newFolderName: string | undefined) => {
        if (!newFolderName || newFolderName.trim() == '') {
          return
        }
        await FileFolderUtil.changeFileFolderName(PathUtils.appContext!,
          JSON.parse(DataSyncUtil.editingVideo) as FileFolder, newFolderName, this.fileFolderSource)
      }
    }), cornerRadius: 20, shadow: DefaultDialogShadow
  })

  @Builder
  FileFolderSelectMenu(folder: FileFolder) {
    if (folder.name !== '首页') {
      Menu() {
        MenuItem({
          symbolStartIcon: new SymbolGlyphModifier($r("sys.symbol.trash_fill")),
          content: $r('app.string.delete')
        })
          .onClick(async () => {
            DataSyncUtil.delMultipleList = Array.from(folder.video_list);
            await Promise.all(
              DataSyncUtil.delMultipleList.map(item => {
                DataSyncUtil.editingVideo = JSON.stringify(item);
                VideoMetaDataOperator.deleteItem(this.videoListController, this.fileFolderSource);
                return Promise.resolve();
              })
            );
            this.videoListController.closeMultipleChoose()
            this.file_folder_list = FileFolderUtil.deleteFileFolder(PathUtils.appContext!, folder)
            let newFolder: FileFolder | undefined
            if (this.videoListController.folder.date === folder.date) {
              newFolder = this.file_folder_list[0]
            } else {
              newFolder = this.videoListController.folder
            }
            this.videoListController.folder = newFolder
            VideoUtils.refresh(this.videoListController, this.fileFolderSource, newFolder)
          })
        MenuItem({
          symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.rename')),
          content: $r('app.string.edit')
        })
          .onClick(() => {
            DataSyncUtil.editingVideo = JSON.stringify(folder);
            this.editFileFolderNameDialogController.open()
          })
      }.attributeModifier(new MenuModifier()).onAppear(() => {
        ToolsUtil.startVibration()
      })
    }
  }

  @Builder
  SelectFileMenuBuilder() {
    Menu() {
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.folder')),
        content: $r('app.string.import_from_files')
      })
        .onClick(async () => {
          this.sideBarController.closeSideBar(false)
          await this.toMetaData(await SelectFileUtil.selectFiles(), this.videoListController.folder);
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.picture')),
        content: $r('app.string.import_from_album')
      })
        .onClick(async () => {
          this.sideBarController.closeSideBar(false)
          await this.toMetaData(await SelectFileUtil.selectVideo(), this.videoListController.folder);
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.folder_badge_eye')),
        content: '从下载文件夹导入（路径：Download/' +
        PathUtils.appContext!.resourceManager.getStringSync($r('app.string.EntryAbility_label').id) + '）'
      })
        .onClick(async () => {
          this.sideBarController.closeSideBar(false)
          await this.toMetaData(await SelectFileUtil.getDownloadFilesUri(), undefined);
        })
    }.attributeModifier(new MenuModifier())
  }

  async onPageShow(): Promise<void> {
    await WantProcessUtil.checkWant(PathUtils.appContext!, this.pathStack)
  }

  async aboutToAppear(): Promise<void> {
    await ScreenUtil.init(PathUtils.appContext!)
    SelectFileUtil.getDownloadUri()
    VideoOperateUtil.initSetting(PathUtils.appContext!)
    VideoMetaDataOperator.migrationRootVideoMetaToRootFolder()
    ToolsUtil.isSubtitleFileFolderExist(PathUtils.videoPath, PathUtils.subtitlePath)
    this.passwd = Preferences.getPassword(PathUtils.appContext!)
    this.file_folder_list = Preferences.getFileFolder(PathUtils.appContext!)
    this.fileFolderSource?.updateData(this.file_folder_list)
    this.videoListController?.updateData(undefined, this.file_folder_list[0])
    if (Preferences.getOOBEVersion(PathUtils.appContext!) < OOBEVersion) {
      let controller = new CustomDialogController({
        builder: PrivacyPolicyDialog({
          cancel: () => {
            PathUtils.appContext!.terminateSelf().catch((error: Error) => {
              ToolsUtil.showToast('关闭弹窗失败' + error)
            })
          },
          confirm: async () => {
            Preferences.saveOOBEVersion(PathUtils.appContext!, OOBEVersion)
            controller.close()
          }
        }),
        autoCancel: false,
        onWillDismiss: async () => {
          if (Preferences.getOOBEVersion(PathUtils.appContext!) < OOBEVersion) {
            PathUtils.appContext!.terminateSelf().catch((error: Error) => {
              ToolsUtil.showToast('退出应用失败' + error)
            })
          }
        }
      })
      setTimeout(() => {
        controller.open()
      }, 1000)
    }
    taskpoolExecTool(Preferences.getFileFolder(PathUtils.appContext!), (re: Object) => {
      setTimeout(() => {
        const result = re as Array<VideoMetadata>
        if (result.length > 0) {
          const idsToDelete = result
          idsToDelete.forEach(async item => {
            await this.videoListController.videoDataSource.deleteUnExistFile(item, this.videoListController,
              this.fileFolderSource)
          });
          VideoUtils.refresh(this.videoListController, this.fileFolderSource, this.videoListController.folder)
          DataSyncUtil.deletedVideos = result
          this.deletedVideosDialogController.open()
        }
      }, 50)
    })
  }

  async toMetaData(fileList: string[], fileFolder?: FileFolder) {
    if (fileList.length === 0) {
      ToolsUtil.showToast('没有任何文件被导入哦~');
      return;
    }
    this.loading = true;
    this.totalItems = fileList.length;
    this.processedItems = 0;
    try {
      await FileProcessorUtil.processFilesConcurrently(
        fileList, PathUtils.appContext!, PathUtils.videoPath, PathUtils.coverPath,
        this.videoListController.videoDataSource.getAllData(),
        (increment: number) => {
          this.processedItems += increment;
        },
        fileFolder
      );
      ToolsUtil.showToast(
        `${PathUtils.appContext!.resourceManager.getStringSync($r('app.string.add_time_info'))}${this.totalItems -
        FileFolderUtil.duplicateVideo}${FileFolderUtil.duplicateVideo > 0 ?
          '重复视频已经智能跳过，跳过视频数：' + FileFolderUtil.duplicateVideo : ''}`
      );
    } catch (error) {
      ToolsUtil.showToast('处理过程中发生意外错误:' + error);
    } finally {
      this.loading = false;
      VideoUtils.refresh(this.videoListController, this.fileFolderSource, this.videoListController.folder)
    }
  }

  build() {
    Navigation(this.pathStack) {
      SideBarContainer(this.sideBarController.side_bar_mode) {
        Column() {
          Scroll() {
            Column() {
              AppInfo()
              Column() {
                Row() {
                  Button({ type: ButtonType.Normal, stateEffect: true }) {
                    Row() {
                      SymbolGlyph($r('sys.symbol.plus_square'))
                        .attributeModifier(new SymbolGlyphFancyModifier(25, '', ''))
                      Text('导入视频')
                        .fontSize(15)
                        .margin({ left: 10, right: 12 })
                    }
                  }
                  .align(Alignment.Start)
                  .padding({ left: 15, right: 15 })
                  .attributeModifier(new ButtonFancyModifier('100%', 60))
                  .animation({ duration: 300, curve: Curve.Ease })
                  .bindMenu(this.SelectFileMenuBuilder)
                }
                .width('100%')
                .justifyContent(FlexAlign.Start)

                Row() {
                  Button({ type: ButtonType.Normal, stateEffect: true }) {
                    Row() {
                      SymbolGlyph($r('sys.symbol.folder_badge_plus'))
                        .attributeModifier(new SymbolGlyphFancyModifier(25, '', ''))
                      Text('添加文件夹')
                        .fontSize(15)
                        .margin({ left: 10, right: 12 })
                    }
                  }
                  .align(Alignment.Start)
                  .padding({ left: 15, right: 15 })
                  .attributeModifier(new ButtonFancyModifier('100%', 60))
                  .animation({ duration: 300, curve: Curve.Ease })
                  .onClick(() => {
                    this.addFileFolderNameDialogController.open()
                  })
                }.width('100%')
                .justifyContent(FlexAlign.Start)
              }.margin({ top: 10 })
              .justifyContent(FlexAlign.Start)
              .backgroundColor($r('app.color.start_window_background_blur'))
              .borderRadius(16)

              //文件夹列表
              List() {
                LazyForEach(this.fileFolderSource, (folder: FileFolder) => {
                  ListItem() {
                    FileFolderListComponent({
                      folder: folder,
                      videoListController: this.videoListController
                    })
                      .reuseId(this.videoListController.folder.name === folder.name ? 'selected_folder' :
                        'unselect_folder')
                  }
                  .onClick(() => {
                    this.clearSearchValue()
                    if (this.videoListController.folder.date === folder.date) {
                      return
                    }
                    this.file_folder_list = Preferences.getFileFolder(PathUtils.appContext!)
                    this.fileFolderSource.updateData(this.file_folder_list)
                    const currentFolder = this.fileFolderSource.getFileFolder(folder.name)
                    this.videoListController.videoDataSource.updateData(currentFolder.video_list)
                    this.videoListController.updateData(this.videoListController.videoDataSource, currentFolder!)
                    this.sideBarController.closeSideBar(true)
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
              .margin({ top: 10 })
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

          Row() {
            Button({ type: ButtonType.Normal, stateEffect: true }) {
              Row() {
                SymbolGlyph($r('sys.symbol.clock')).attributeModifier(new SymbolGlyphFancyModifier(25, '', ''))
                Text('最近播放')
                  .fontSize(15)
                  .fontColor($r('app.color.text_color'))
                  .margin({ left: 10, right: 12 })
              }
            }
            .align(Alignment.Start)
            .padding({ left: 15, right: 15 })
            .attributeModifier(new ButtonFancyModifier('100%', 60))
            .backgroundColor($r('app.color.start_window_background'))
            .animation({ duration: 300, curve: Curve.Ease })
            .onClick(async () => {
              this.sideBarController.closeSideBar(false)
              this.pathStack.pushPathByName(NavigationAddress.RECENT_PLAY, true)
            })
          }
          .alignSelf(ItemAlign.End)

          Row() {
            Button({ type: ButtonType.Normal, stateEffect: true }) {
              Row() {
                SymbolGlyph($r('sys.symbol.gearshape'))
                  .attributeModifier(new SymbolGlyphFancyModifier(25, '', ''))
                Text($r('app.string.setting'))
                  .fontSize(15)
                  .margin({ left: 10, right: 12 })
              }
            }
            .align(Alignment.Start)
            .padding({ left: 15, right: 15 })
            .attributeModifier(new ButtonFancyModifier('100%', 60))
            .backgroundColor($r('app.color.start_window_background'))
            .animation({ duration: 300, curve: Curve.Ease })
            .onClick(() => {
              this.sideBarController.closeSideBar(false)
              this.pathStack.pushPathByName(NavigationAddress.SETTING_PAGE, null)
            })
          }
          .alignSelf(ItemAlign.End)
          .padding({ bottom: this.bottomSafeHeight })
        }
        .width('100%')
        .justifyContent(FlexAlign.Start)
        .backgroundColor($r('app.color.start_window_background'))
        .transition(TransitionEffect.translate({ x: -300 }).animation({ duration: 500, curve: Curve.Friction }))
        .visibility(this.sideBarController.sideBarStatusTmp)
        .borderRadius(this.sideBarController.side_bar_mode === SideBarContainerType.Overlay ? 16 : 0)

        Stack() {
          VideoView({
            loading: this.loading,
            passwd: this.passwd,
            searchValue: this.searchValue,
            videoListController: this.videoListController
          })
          if (this.loading) {
            ImportProgressComponent({
              processedItems: this.processedItems,
              totalItems: this.totalItems
            })
          }
        }
        .backgroundColor($r('app.color.start_window_background'))
        .onAreaChange(async (_oldValue: Area, newValue: Area) => {
          const width = Number(newValue.width);
          // 增加判断，旋转时保持滚动位置不变
          this.videoListController.refresh(width, this.isListDisplay)
        })
        .gesture(SwipeGesture({ direction: SwipeDirection.Horizontal }).onAction((event: GestureEvent) => {
          if (event) {
            this.sideBarController.sideBarStatusTmp === Visibility.Visible ?
              this.sideBarController.closeSideBar(true) : this.sideBarController.openSideBar()
          }
        }))
      }
      .minSideBarWidth(DataSyncUtil.minSideBarWidth) // 设置侧边栏最小宽度
      .minContentWidth(DataSyncUtil.minContentWidth) // 设置内容区最小宽度
      .allowDrop([uniformTypeDescriptor.UniformDataType.PLAIN_TEXT, uniformTypeDescriptor.UniformDataType.VIDEO])
      .onSizeChange((_oldValue: SizeResult, newValue: SizeResult) => {
        if (newValue.width >= DataSyncUtil.minSideBarWidth + DataSyncUtil.minContentWidth) {
          this.sideBarController.side_bar_mode = SideBarContainerType.Embed
          this.sideBarController.sideBarStatusTmp = Visibility.Visible
          this.sideBarController.sideBarStatus = true
        } else {
          this.sideBarController.side_bar_mode = SideBarContainerType.Overlay
          this.sideBarController.sideBarStatusTmp = Visibility.Hidden
          this.sideBarController.sideBarStatus = false
        }
      })
      .onDrop((dragEvent: DragEvent) => {
        let records: Array<unifiedDataChannel.UnifiedRecord> = []
        try {
          records = dragEvent.getData().getRecords();
        } catch (error) {
          ToolsUtil.showToast('获取数据时异常：' + error)
        }
        let video: unifiedDataChannel.Video = records[0] as unifiedDataChannel.Video;
        WantProcessUtil.wantUri = video.uri
        WantProcessUtil.hasWant(PathUtils.appContext!, this.pathStack)
      })
      .onChange((value: boolean) => {
        this.sideBarController.sideBarStatus = value;
      })
      .showSideBar(this.sideBarController.sideBarStatus)
      .showControlButton(false)
      .divider({ strokeWidth: 0 })
      .gesture(SwipeGesture({ direction: SwipeDirection.Horizontal }).onAction((event: GestureEvent) => {
        if (event) {
          this.sideBarController.closeSideBar(true)
        }
      }))
    }
    .backgroundImage('')
    .hideTitleBar(true)
    .mode(NavigationMode.Stack)
    .navDestination(this.Pages)
    .onNavBarStateChange((isVisible: boolean) => {
      if (isVisible) {
        this.passwd = Preferences.getPassword(PathUtils.appContext!)
        // 增加判断，旋转时保持滚动位置不变
        if (this.videoListController.folder?.video_list) {
          this.videoListController.refresh(this.screen_width, this.isListDisplay)
          VideoUtils.refresh(this.videoListController, this.fileFolderSource, this.videoListController.folder)
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
    } else if (name == NavigationAddress.FFMPEG_PLAYER) {
      FFMpegPlayer()
    } else if (name == NavigationAddress.RECENT_PLAY) {
      RecentPlay()
    } else if (name == NavigationAddress.PRIVACY_SPACE) {
      PrivacySpace()
    } else if (name == NavigationAddress.RED_PLAYER) {
      RedPlayer()
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
    if (this.sideBarController.sideBarStatusTmp === Visibility.Visible &&
      this.sideBarController.side_bar_mode === SideBarContainerType.Overlay) {
      this.sideBarController.closeSideBar(true)
      return true
    }
    if (this.clearSearchValue()) {
      return true
    }
    return false
  }
}