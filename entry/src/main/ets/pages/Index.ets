import { fileIo as fs } from '@kit.CoreFileKit';
import { SymbolGlyphModifier } from '@kit.ArkUI';
import DataSyncUtil, { OOBEVersion } from '../utils/DataSyncUtil';
import { FileFolderDataSource, VideoDataSource } from '../utils/DataUtil';
import ToolsUtil from '../utils/ToolsUtil';
import SelectFileUtil from '../utils/SelectFileUtil';
import { JSON } from '@kit.ArkTS';
import WantProcessUtil from '../utils/WantProcessUtil';
import { unifiedDataChannel, uniformTypeDescriptor } from '@kit.ArkData';
import RecentPlayUtil from '../utils/RecentPlayUtil';
import { addFileFolderNameDialog } from '../component/Dialog/AddFileFolderNameDialog';
import FileFolderUtil from '../utils/FileFolderUtil';
import { editFileFolderNameDialog } from '../component/Dialog/EditFileFolderNameDialog';
import { VideoMetadata } from '../interfaces/VideoMetadataInterface';
import { FileFolder } from '../interfaces/FileFolderInterface';
import { DefaultDialogShadow } from '../common/DefaultDialogShadow';
import ScreenUtil from '../utils/ScreenUtil';
import { SettingsPage } from './Setting';
import { AboutApp } from './AboutApp';
// import { FileFolderContent } from './FileFolderContent';
import { FFMpegPlayer } from './FFMpegPlayer';
import { Player } from './Player';
import { RecentPlay } from './RecentPlay';
import { PrivacyPolicyDialog } from './PrivacyInfo';
import VideoOperateUtil from '../utils/VideoOperateUtil';
import { PrivacySpace } from './PrivacySpace';
import Preferences from '../database/Preferences';
import { RedPlayer } from './RedPlayer';
import {
  ButtonFancyModifier,
  MenuModifier,
  ShadowModifier,
  SymbolGlyphFancyModifier
} from '../utils/AttributeModifierUtil';
import { ImportProgressComponent } from '../component/ImportProgressComponent';
import { FileProcessorUtil } from '../utils/FileProcessorUtil';
import { PathUtils } from '../utils/PathUtils';
import { MaskComponent } from '../component/MaskComponent';
import { SearchComponent } from '../component/SearchComponent';
import { VideoList, VideoListController } from '../component/VideoItemComponent';
import SubtitleUtil from '../utils/SubtitleUtil';
import { AppInfo, SideBarController } from '../component/SideBarComponent/SideBar';
import { VideoView } from '../component/VideoItemComponent/VideoViewComponent';


@Builder
export function IndexBuilder() {
  Index()
}

@Entry
@Component
struct Index {
  @StorageProp('topSafeHeight') topSafeHeight: number = 0;
  @StorageProp('bottomSafeHeight') bottomSafeHeight: number = 0;
  @State video_meta_data: VideoMetadata[] = []
  @State videoDataSource: VideoDataSource = new VideoDataSource([])
  @Provide fileFolderSource: FileFolderDataSource = new FileFolderDataSource([])
  @State passwd: string = 'passwd'
  @State list_empty_item: string[] = ['']
  @State loading: boolean = false
  @State current_import: number = 0
  @State import_sum: number = 0
  @State file_folder_list: FileFolder[] = []
  @StorageLink('is_list_display') is_list_display: boolean = false
  @StorageProp('screen_width') screen_width: number = 0
  @StorageProp('screen_height') screen_height: number = 0
  @State searchValue: string = ''
  @Provide('pathStack') pathStack: NavPathStack = new NavPathStack()
  @State videoListController: VideoListController = new VideoListController([])
  @State @Watch('SyncSideBarAndMaskState') sideBarController: SideBarController = new SideBarController()

  SyncSideBarAndMaskState(): void {
    if (this.sideBarController.sideBarStatusTmp == Visibility.Hidden) {
      this.sideBarController.mask_state = false
    }
  }

  addFileFolderNameDialogController: CustomDialogController = new CustomDialogController({
    builder: addFileFolderNameDialog({
      confirm: async (file_folder_name: string | undefined) => {
        if (!file_folder_name || file_folder_name.trim() == '') {
          return
        }
        this.file_folder_list = await FileFolderUtil.createNewFolder(PathUtils.appContext!, file_folder_name)
        this.fileFolderSource.updateData(this.file_folder_list)
      },
    }), cornerRadius: 20, shadow: DefaultDialogShadow
  })
  editFileFolderNameDialogController: CustomDialogController = new CustomDialogController({
    builder: editFileFolderNameDialog({
      confirm: async (file_folder: string | undefined) => {
        if (!file_folder || file_folder.trim() == '') {
          return
        }
        this.file_folder_list =
          await FileFolderUtil.changeFileFolderName(PathUtils.appContext!,
            JSON.parse(DataSyncUtil.editing_video) as FileFolder,
            file_folder, this.file_folder_list)
        this.fileFolderSource.updateData(this.file_folder_list)
      }
    }), cornerRadius: 20, shadow: DefaultDialogShadow
  })

  @Builder
  FileFolderSelectMenu(file_folder: FileFolder) {
    Menu() {
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r("sys.symbol.trash_fill")),
        content: $r('app.string.delete')
      })
        .onClick(async () => {
          DataSyncUtil.delMultipleList = Array.from(file_folder.video_list);
          this.videoDataSource.refreshData()
          const deletePromises = DataSyncUtil.delMultipleList.map(item => {
            return new Promise<void>((resolve, reject) => {
              DataSyncUtil.editing_video = JSON.stringify(item);
              this.deleteItem(resolve, reject);
              this.videoListController.closeMultipleChoose()
            });
          });
          await Promise.all(deletePromises)
          this.fileFolderSource.deleteData(this.file_folder_list.findIndex(i => i.date === file_folder.date))
          this.file_folder_list =
            await FileFolderUtil.deleteFileFolder(PathUtils.appContext!, file_folder, this.file_folder_list)
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.rename')),
        content: $r('app.string.edit')
      }).onClick(() => {
        DataSyncUtil.editing_video = JSON.stringify(file_folder);
        this.editFileFolderNameDialogController.open()
      })
    }.attributeModifier(new MenuModifier()).onAppear(() => {
      ToolsUtil.startVibration()
    })
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
          await this.toMetaData(await SelectFileUtil.selectFiles(), undefined);
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.picture')),
        content: $r('app.string.import_from_album')
      })
        .onClick(async () => {
          this.sideBarController.closeSideBar(false)
          await this.toMetaData(await SelectFileUtil.selectVideo(), undefined);
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

  async deleteItem(resolve: () => void, reject: (reason?: Error) => void) {
    let tmp = JSON.parse(DataSyncUtil.editing_video) as VideoMetadata;
    SubtitleUtil.deleteSubtitle(PathUtils.subtitlePath, tmp.date!)
    this.videoDataSource.deleteData(this.video_meta_data.findIndex(i => i.date === tmp.date))
    this.video_meta_data = this.video_meta_data.filter(i => i.date != tmp.date);
    RecentPlayUtil.delData(PathUtils.appContext!, tmp) // 删除最近播放的记录
    fs.access(PathUtils.coverPath + tmp.date, (err) => {
      if (!err) { // 文件存在
        fs.unlink(PathUtils.coverPath + tmp.date, (unlinkErr) => {
          if (unlinkErr) {
            reject(new Error(`Error deleting file from sandbox_path: ${unlinkErr.message}`));
            return;
          }
          Preferences.saveVideoMetaData(PathUtils.appContext!, this.video_meta_data)
          resolve(); // 在所有操作完成后调用 resolve
        });
      } else {
        resolve(); // 文件不存在时直接调用 resolve
      }
    });
  }

  onPageShow(): void {
    setTimeout(() => { // 临时解决 system share 获取 want 没有 onPageShow 跑的快的问题
      if (WantProcessUtil.has_new_want) {
        WantProcessUtil.checkWant(PathUtils.appContext!, this.pathStack)
      }
    }, 0.1)
  }

  async aboutToAppear(): Promise<void> {
    SelectFileUtil.getDownloadUri()
    ScreenUtil.init(PathUtils.appContext!)
    await VideoOperateUtil.initSetting(PathUtils.appContext!)
    this.passwd = Preferences.getPassword(PathUtils.appContext!)
    ToolsUtil.isSubtitleFileFolderExist(PathUtils.videoPath, PathUtils.subtitlePath)
    this.video_meta_data = Preferences.getVideoMetaData(PathUtils.appContext!)
    this.videoDataSource = new VideoDataSource(this.video_meta_data)
    this.videoListController = new VideoListController(this.video_meta_data)
    this.file_folder_list = Preferences.getFileFolder(PathUtils.appContext!)
    this.fileFolderSource.updateData(this.file_folder_list)
    if (Preferences.getOOBEVersion(PathUtils.appContext!) < OOBEVersion) {
      let controller = new CustomDialogController({
        builder: PrivacyPolicyDialog({
          cancel: () => {
            PathUtils.appContext!.terminateSelf()
          },
          confirm: async () => {
            Preferences.saveOOBEVersion(PathUtils.appContext!, OOBEVersion)
            controller.close()
          }
        }),
        autoCancel: false,
        onWillDismiss: async () => {
          if (Preferences.getOOBEVersion(PathUtils.appContext!) < OOBEVersion) {
            PathUtils.appContext!.terminateSelf()
          }
        }
      })
      setTimeout(() => {
        controller.open()
      }, 1000)
    }
  }

  async toMetaData(fileList: string[], fileFolder?: FileFolder) {
    if (fileList.length === 0) {
      ToolsUtil.showToast('没有任何文件被导入哦~');
      return;
    }
    this.loading = true;
    this.import_sum = fileList.length;
    this.current_import = 0;
    try {
      await FileProcessorUtil.processFilesConcurrently(
        fileList, PathUtils.appContext!, PathUtils.videoPath, PathUtils.coverPath, this.video_meta_data,
        (increment: number) => {
          this.current_import += increment;
        },
        fileFolder
      );
      this.videoDataSource.refreshData()
      ToolsUtil.showToast(
        `${PathUtils.appContext!.resourceManager.getStringSync($r('app.string.add_time_info'))}${this.import_sum}`
      );
    } catch (error) {
      ToolsUtil.showToast('处理过程中发生意外错误:' + error);
    } finally {
      this.loading = false;
    }
  }

  deleteUnExistFile(item: VideoMetadata | undefined) {
    DataSyncUtil.editing_video = JSON.stringify(item)
    new Promise<void>((resolve, reject) => {
      this.deleteItem(resolve, reject);
    });
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

              List() {
                LazyForEach(this.fileFolderSource, (item: FileFolder) => {
                  ListItem() {
                    Button({ type: ButtonType.Normal, stateEffect: true }) {
                      Row() {
                        SymbolGlyph($r('sys.symbol.folder'))
                          .attributeModifier(new SymbolGlyphFancyModifier(25, '', ''))
                        Text(item.name)
                          .fontSize(15)
                          .margin({ left: 10, right: 12 })
                      }
                    }
                    .align(Alignment.Start)
                    .padding({ left: 15, right: 15 })
                    .attributeModifier(new ButtonFancyModifier('100%', 60))
                    .animation({ duration: 300, curve: Curve.Ease })
                  }
                  .onClick(() => {
                    ToolsUtil.routerToFileFolder(this.pathStack, item)
                  })
                  .bindContextMenu(this.FileFolderSelectMenu(item), ResponseType.LongPress)
                  .height(60)
                }, (item: FileFolder) => item.date)
              }
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
              this.pathStack.pushPathByName('RecentPlay', true)
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
              this.pathStack.pushPathByName('SettingsPage', null)
            })
          }
          .alignSelf(ItemAlign.End)
          .padding({ bottom: 15 })
        }
        .width('100%')
        .justifyContent(FlexAlign.Start)
        .backgroundColor($r('app.color.start_window_background'))
        .transition(TransitionEffect.translate({ x: -300 }).animation({ duration: 500, curve: Curve.Friction }))
        .visibility(this.sideBarController.sideBarStatusTmp)
        .borderRadius(this.sideBarController.side_bar_mode === SideBarContainerType.Overlay ? 16 : 0)

        Stack() {
          if (this.loading) {
            Stack() {
              ImportProgressComponent({
                current_import: this.current_import,
                import_sum: this.import_sum
              })
            }.width('100%')
            .height('100%')
          }
          VideoView({
            videoListController: this.videoListController,
            sideBarController: this.sideBarController,
            loading: this.loading,
            passwd: this.passwd
          })
        }.backgroundColor($r('app.color.start_window_background'))
        .onAreaChange(async (_oldValue: Area, newValue: Area) => {
          const width = Number(newValue.width);
          // 增加判断，旋转时保持滚动位置不变
          this.videoListController.refresh(width, this.is_list_display)
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
        let records: Array<unifiedDataChannel.UnifiedRecord> = dragEvent.getData().getRecords();
        let video: unifiedDataChannel.Video = records[0] as unifiedDataChannel.Video;
        WantProcessUtil.want_uri = video.uri
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
    .hideTitleBar(true).mode(NavigationMode.Stack).navDestination(this.Pages)
    .onNavBarStateChange((isVisible: boolean) => {
      if (isVisible) {
        this.videoDataSource.refreshData()
        this.passwd = Preferences.getPassword(PathUtils.appContext!)
        // 增加判断，旋转时保持滚动位置不变
        this.videoListController.refresh(this.screen_width, this.is_list_display)
      }
    })
  }

  @Builder
  Pages(name: string) {
    if (name == 'SettingsPage') {
      SettingsPage()
    } else if (name == 'AboutPage') {
      AboutApp()
    // } else if (name == 'FileFolderContent') {
    //   FileFolderContent()
    } else if (name == 'Player') {
      Player()
    } else if (name == 'FFMpegPlayer') {
      FFMpegPlayer()
    } else if (name == 'RecentPlay') {
      RecentPlay()
    } else if (name == 'PrivacySpace') {
      PrivacySpace()
    } else if (name == 'RedPlayer') {
      RedPlayer()
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
    if (this.searchValue.length > 0) {
      this.searchValue = ''
      return true
    }
    return false
  }
}