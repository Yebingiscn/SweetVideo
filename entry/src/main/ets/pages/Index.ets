import { fileUri, fileIo as fs } from '@kit.CoreFileKit';
import { SymbolGlyphModifier } from '@kit.ArkUI';
import DataSyncUtil, { OOBEVersion } from '../utils/DataSyncUtil';
import { FileFolderDataSource, VideoDataSource } from '../utils/DataUtil';
import ToolsUtil from '../utils/ToolsUtil';
import { delConfirmDialog } from '../component/Dialog/DelConfirmDialog';
import { editMetadataDialog } from '../component/Dialog//EditMetadataDialog';
import SelectFileUtil from '../utils/SelectFileUtil';
import { JSON } from '@kit.ArkTS';
import { VideoDetailDialog } from '../component/Dialog//VideoDetailDialog';
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
import { FileFolderContent } from './FileFolderContent';
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
  ImageFancyModifier,
  MenuModifier,
  ShadowModifier,
  SymbolGlyphFancyModifier
} from '../utils/AttributeModifierUtil';
import { ImportProgressComponent } from '../component/ImportProgressComponent';
import { FileProcessorUtil } from '../utils/FileProcessorUtil';
import { VideoInfoComponent } from '../component/VideoInfoComponent';
import VideoInfoUtil from '../utils/VideoInfoUtil';
import SubtitleUtil from '../utils/SubtitleUtil';
import { PathUtils } from '../utils/PathUtils';
import { MaskComponent } from '../component/MaskComponent';
import { SearchComponent } from '../component/SearchComponent';

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
  @State fileFolderSource: FileFolderDataSource = new FileFolderDataSource([])
  @State passwd: string = 'passwd'
  @State list_line: number = 1
  @State list_empty_item: string[] = ['']
  @State loading: boolean = false
  @State sideBarStatus: boolean = false
  @State current_import: number = 0
  @State is_edit: boolean = false
  @State mask_state: boolean = false
  @State import_sum: number = 0
  @State @Watch('SyncSideBarAndMaskState') sideBarStatusTmp: Visibility = Visibility.Hidden
  @State itemMultipleChoose: boolean = false
  @State multipleChooseState: Visibility = Visibility.None
  @State MenuBuilderState: boolean = false
  @State file_folder_list: FileFolder[] = []
  @State side_bar_mode: SideBarContainerType = SideBarContainerType.AUTO
  @StorageLink('is_list_display') is_list_display: boolean = false
  @StorageProp('screen_width') screen_width: number = 0
  @StorageProp('screen_height') screen_height: number = 0
  @State searchValue: string = ''
  @Provide('pathStack') pathStack: NavPathStack = new NavPathStack()
  editMetadataDialogController: CustomDialogController = new CustomDialogController({
    builder: editMetadataDialog({
      confirm: async (title: string | undefined) => {
        if (!title?.trim()) {
          return;
        } // 更严格的空值判断
        const editingVideo = JSON.parse(DataSyncUtil.editing_video) as VideoMetadata;
        const targetIndex = SelectFileUtil.getItemIndex(this.video_meta_data, editingVideo);
        if (targetIndex === -1) {
          return;
        }
        const titleSet = new Set(this.video_meta_data.map(v => v.title));
        if (titleSet.has(title)) {
          return;
        }
        this.video_meta_data[targetIndex].title = title.trim();
        this.videoDataSource.updateData(this.video_meta_data)
        Preferences.saveVideoMetaData(PathUtils.appContext!, this.video_meta_data)
      },
    }), cornerRadius: 20, shadow: DefaultDialogShadow
  })
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
  VideoDetailDialog: CustomDialogController = new CustomDialogController({
    builder: VideoDetailDialog(), cornerRadius: 20,
    shadow: DefaultDialogShadow
  })
  listScroller: ListScroller = new ListScroller()
  searchController: SearchController = new SearchController()
  delConfirmDialog: CustomDialogController = new CustomDialogController({
    builder: delConfirmDialog({
      confirm: async (confirm_del: boolean | undefined) => {
        if (!confirm_del) {
          return
        }
        await new Promise<void>((resolve, reject) => {
          this.deleteItem(resolve, reject);
        });
        if (DataSyncUtil.delMultipleList.length > 0) {
          this.videoDataSource.refreshData()
          const deletePromises = DataSyncUtil.delMultipleList.map(item => {
            return new Promise<void>((resolve, reject) => {
              DataSyncUtil.editing_video = JSON.stringify(item);
              this.deleteItem(resolve, reject);
              this.closeMultipleChoose()
            });
          });
          await Promise.all(deletePromises);
        } else {
          this.closeMultipleChoose()
        }
      }
    }), cornerRadius: 20, shadow: DefaultDialogShadow
  })

  SyncSideBarAndMaskState(): void {
    if (this.sideBarStatusTmp == Visibility.Hidden) {
      this.mask_state = false
    }
  }

  @Builder
  FileFolderMenu(video_item: VideoMetadata | undefined) {
    Menu() {
      LazyForEach(this.fileFolderSource, (item: FileFolder) => {
        MenuItem({ symbolStartIcon: new SymbolGlyphModifier($r("sys.symbol.folder")), content: item.name })
          .onClick(async () => {
            if (DataSyncUtil.delMultipleList.length > 0) {
              for (let i = 0; i < DataSyncUtil.delMultipleList.length; i++) {
                await this.addVideoToFileFolder(DataSyncUtil.delMultipleList[i], item)
              }
              DataSyncUtil.delMultipleList = []
              this.closeMultipleChoose()
            } else if (this.multipleChooseState === Visibility.None) {
              await this.addVideoToFileFolder(video_item!, item)
            }
          })
      }, (item: FileFolder) => item.date)
    }.attributeModifier(new MenuModifier())
  }

  async addVideoToFileFolder(video_item: VideoMetadata, item: FileFolder) {
    if (!item.video_list.some(v => v.title === video_item.title)) {
      this.file_folder_list = await FileFolderUtil.addVideoInFileFolder(PathUtils.appContext!, video_item!, item.date)
      this.videoDataSource.deleteData(this.video_meta_data.findIndex(i => i.date === video_item.date))
      this.video_meta_data = this.video_meta_data.filter(i => i.date !== video_item?.date)
      Preferences.saveVideoMetaData(PathUtils.appContext!, this.video_meta_data)
    }
  }

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
              this.closeMultipleChoose()
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
  MenuBuilder(item: VideoMetadata | undefined) {
    Menu() {
      MenuItem({ startIcon: $r("app.media.ffmpeg"), content: $r('app.string.FFMpeg_Player') }).onClick(() => {
        this.MenuBuilderState = false
        setTimeout(async () => { //延迟跳转，确保弹窗关闭，防止系统误识别为子窗口导致播放器异常
          let target_item = SelectFileUtil.getItem(this.video_meta_data, item?.date!)
          if (!this.video_meta_data.find(i => i.date == item?.date!)) {
            ToolsUtil.showToast('数据正在加载中，请重试')
            this.videoDataSource.refreshData()
            return
          }
          await ToolsUtil.isFileExist(target_item) ?
          ToolsUtil.routerWhere(this.pathStack, 'FFMpegPlayer', item!, this.video_meta_data) :
          this.deleteUnExistFile(target_item)
        }, 200)
      })
      MenuItem({ startIcon: $r("app.media.RedPlayer"), content: '红薯播放器' }).onClick(() => {
        this.MenuBuilderState = false
        setTimeout(async () => { //延迟跳转，确保弹窗关闭，防止系统误识别为子窗口导致播放器异常
          let target_item = SelectFileUtil.getItem(this.video_meta_data, item?.date!)
          if (!this.video_meta_data.find(i => i.date == item?.date!)) {
            ToolsUtil.showToast('数据正在加载中，请重试')
            this.videoDataSource.refreshData()
            return
          }
          await ToolsUtil.isFileExist(target_item) ?
          ToolsUtil.routerWhere(this.pathStack, 'RedPlayer', item!, this.video_meta_data) :
          this.deleteUnExistFile(target_item)
        }, 200)
      })
      MenuItem({ symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.info_circle')), content: '详情' })
        .onClick(() => {
          DataSyncUtil.editing_video = JSON.stringify(item)
          this.VideoDetailDialog.open()
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.arrow_right_folder_circle')),
        content: "添加到文件夹",
        builder: (): void => this.FileFolderMenu(item)
      })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.trash_fill')), content: $r('app.string.delete')
      })
        .onClick(() => {
          DataSyncUtil.editing_video = JSON.stringify(item)
          this.delConfirmDialog.open()
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.checkmark_square_on_square')),
        content: $r('app.string.multiple_choice')
      })
        .onClick(() => {
          this.multipleChooseState =
            this.multipleChooseState == Visibility.None ? Visibility.Visible : Visibility.None
          DataSyncUtil.delMultipleList.length = 0
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.line_3_horizontal')),
        content: '更多',
        builder: (): void => this.MenuBuilderExtend(item)
      })
    }.attributeModifier(new MenuModifier()).onAppear(() => {
      ToolsUtil.startVibration()
      this.MenuBuilderState = true
    })
  }

  @Builder
  MenuBuilderExtend(item: VideoMetadata | undefined) {
    Menu() {
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.rename')), content: $r('app.string.edit')
      })
        .onClick(() => {
          DataSyncUtil.editing_video = JSON.stringify(item)
          this.editMetadataDialogController.open()
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.textformat_size_square')), content: '导入或删除字幕'
      })
        .onClick(async () => {
          await SubtitleUtil.isSubtitleExist(PathUtils.subtitlePath, item?.date!) ?
          SubtitleUtil.deleteSubtitle(PathUtils.subtitlePath, item?.date!) :
          SubtitleUtil.selectExternalSubtitles(PathUtils.subtitlePath, item?.date!)
        })
    }
  }

  @Builder
  SortMenuBuilder() {
    Menu() {
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.textformat')),
        content: $r('app.string.sort_by_name')
      })
        .onClick(async () => {
          this.video_meta_data =
            await ToolsUtil.sortByName(PathUtils.appContext!, this.video_meta_data, undefined) as VideoMetadata[]
          this.videoDataSource.updateData(this.video_meta_data)
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.clock')),
        content: $r('app.string.sort_by_time')
      })
        .onClick(async () => {
          this.video_meta_data =
            await ToolsUtil.sortByTime(PathUtils.appContext!, this.video_meta_data, undefined) as VideoMetadata[]
          this.videoDataSource.updateData(this.video_meta_data)
        })
    }.attributeModifier(new MenuModifier())
  }

  @Builder
  SelectFileMenuBuilder() {
    Menu() {
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.folder')),
        content: $r('app.string.import_from_files')
      })
        .onClick(async () => {
          this.closeSideBar(false)
          await this.toMetaData(await SelectFileUtil.selectFiles(), undefined);
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.picture')),
        content: $r('app.string.import_from_album')
      })
        .onClick(async () => {
          this.closeSideBar(false)
          await this.toMetaData(await SelectFileUtil.selectVideo(), undefined);
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.folder_badge_eye')),
        content: '从下载文件夹导入（路径：Download/' +
        PathUtils.appContext!.resourceManager.getStringSync($r('app.string.EntryAbility_label').id) + '）'
      })
        .onClick(async () => {
          this.closeSideBar(false)
          await this.toMetaData(await SelectFileUtil.getDownloadFilesUri(), undefined);
        })
    }.attributeModifier(new MenuModifier())
  }

  @Builder
  SelectItemMenuBuilder() {
    Menu() {
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.xmark')),
        content: $r('app.string.cancel')
      })
        .onClick(() => {
          this.closeMultipleChoose()
          DataSyncUtil.delMultipleList.length = 0
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.checkmark_square_on_square')),
        content: $r('app.string.select_all')
      })
        .onClick(() => {
          this.itemMultipleChoose = !this.itemMultipleChoose
          DataSyncUtil.delMultipleList.length = 0
          DataSyncUtil.delMultipleList = [...this.video_meta_data]
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.trash_fill')),
        content: $r('app.string.delete_selected')
      })
        .onClick(async () => {
          this.closeMultipleChoose()
          this.multipleChooseState = Visibility.None;
          if (DataSyncUtil.delMultipleList.length > 0) {
            this.videoDataSource.refreshData()
            const deletePromises = DataSyncUtil.delMultipleList.map(item => {
              return new Promise<void>((resolve, reject) => {
                DataSyncUtil.editing_video = JSON.stringify(item);
                this.deleteItem(resolve, reject);
              });
            });
            await Promise.all(deletePromises);
          }
        })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.arrow_right_folder_circle')),
        content: "添加到文件夹",
        builder: (): void => this.FileFolderMenu(undefined)
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
    this.file_folder_list = Preferences.getFileFolder(PathUtils.appContext!)
    this.fileFolderSource = new FileFolderDataSource(this.file_folder_list)
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

  closeSideBar(isPlayAnimation: boolean) {
    if (this.side_bar_mode === SideBarContainerType.Overlay) {
      this.sideBarStatusTmp = Visibility.Hidden
      this.mask_state = false
      isPlayAnimation ? setTimeout(() => {
        this.sideBarStatus = false
      }, 400) : this.sideBarStatus = false
    }
  }

  openSideBar() {
    if (this.side_bar_mode === SideBarContainerType.Overlay) {
      this.sideBarStatusTmp = Visibility.Visible
      this.mask_state = true
      this.sideBarStatus = true
    }
  }

  closeMultipleChoose() {
    this.itemMultipleChoose = false;
    this.multipleChooseState = Visibility.None;
  }

  deleteUnExistFile(item: VideoMetadata | undefined) {
    DataSyncUtil.editing_video = JSON.stringify(item)
    new Promise<void>((resolve, reject) => {
      this.deleteItem(resolve, reject);
    });
  }

  build() {
    Navigation(this.pathStack) {
      SideBarContainer(this.side_bar_mode) {
        Column() {
          Scroll() {
            Column() {
              Stack() {
                Image($r("app.media.Background"))
                  .attributeModifier(new ImageFancyModifier(16, '100%', 120))
                  .zIndex(1)
                Row() {
                  Image($r("app.media.Foreground"))
                    .attributeModifier(new ImageFancyModifier(0, 50, 50))
                  Text($r('app.string.EntryAbility_label'))
                    .fontSize(20)
                    .fontColor('#ffff')
                    .margin({ left: 5, right: 12 })
                }.width('100%')
                .justifyContent(FlexAlign.Center)
                .zIndex(2)
              }.margin({ top: this.topSafeHeight })

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
              this.closeSideBar(false)
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
              this.closeSideBar(false)
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
        .visibility(this.sideBarStatusTmp)
        .borderRadius(this.side_bar_mode === SideBarContainerType.Overlay ? 16 : 0)

        Stack({ alignContent: Alignment.Top }) { // 内容区
          if (this.mask_state && this.side_bar_mode === SideBarContainerType.Overlay) {
            MaskComponent({ onClose: (): void => this.closeSideBar(true) })
          }
          Column() {
            List({ scroller: this.listScroller }) {
              LazyForEach(this.videoDataSource, (item: VideoMetadata, index: number) => { // 加载视频列表
                ListItem() {
                  if (this.is_list_display) {
                    Column() {
                      Row() {
                        Image(fileUri.getUriFromPath(PathUtils.coverPath + item.date))
                          .attributeModifier(new ImageFancyModifier(10, 60, 90))
                        Column() {
                          Row() {
                            Text(VideoInfoUtil.getVideoTitle(this.video_meta_data, item))
                              .fontSize(15)
                              .fontWeight(FontWeight.Medium)
                              .maxLines(3)
                              .textOverflow({ overflow: TextOverflow.Ellipsis })
                              .width(this.multipleChooseState === Visibility.None ? '90%' : '75%')
                              .wordBreak(WordBreak.BREAK_ALL)
                            Checkbox({ name: 'check_box: ' + index, group: 'checkboxGroup' })
                              .width(30)
                              .height(30)
                              .select(this.itemMultipleChoose)
                              .selectedColor($r('app.color.main_color'))
                              .shape(CheckBoxShape.CIRCLE)
                              .visibility(this.multipleChooseState)
                              .onChange((value: boolean) => {
                                if (!this.itemMultipleChoose || !value) {
                                  if (item) {
                                    const delSet = new Set(DataSyncUtil.delMultipleList as VideoMetadata[]);
                                    value ? delSet.add(item) : delSet.delete(item);
                                    DataSyncUtil.delMultipleList = Array.from(delSet);
                                  }
                                }
                              })
                          }

                          VideoInfoComponent({ item })
                            .reuseId(item.date)
                        }.alignItems(HorizontalAlign.Start).padding({ left: 15, right: 15 }).width('90%')
                      }.justifyContent(FlexAlign.Center)
                    }
                    .height(100)
                    .justifyContent(FlexAlign.SpaceEvenly)
                  } else {
                    Column() {
                      Image(fileUri.getUriFromPath(PathUtils.coverPath + item.date))
                        .attributeModifier(new ImageFancyModifier({
                          topLeft: 10,
                          topRight: 10,
                          bottomLeft: 10,
                          bottomRight: 10
                        }, 60, 200))
                        .width('100%')
                        .objectFit(ImageFit.Auto)
                      Column() {
                        Row() {
                          Text(VideoInfoUtil.getVideoTitle(this.video_meta_data, item))
                            .fontSize(15)
                            .fontWeight(FontWeight.Medium)
                            .maxLines(1)// 减少行数以适应卡片布局
                            .textAlign(TextAlign.Center)
                            .textOverflow({ overflow: TextOverflow.Ellipsis })
                            .layoutWeight(1)// 占据剩余空间
                            .wordBreak(WordBreak.BREAK_ALL)
                          Checkbox({ name: 'check_box: ' + index, group: 'checkboxGroup' })
                            .width(30)
                            .height(30)
                            .select(this.itemMultipleChoose)
                            .selectedColor($r('app.color.main_color'))
                            .shape(CheckBoxShape.CIRCLE)
                            .visibility(this.multipleChooseState)
                            .onChange((value: boolean) => {
                              if (!this.itemMultipleChoose || !value) {
                                if (item) {
                                  const delSet = new Set(DataSyncUtil.delMultipleList as VideoMetadata[]);
                                  value ? delSet.add(item) : delSet.delete(item);
                                  DataSyncUtil.delMultipleList = Array.from(delSet);
                                }
                              }
                            })
                        }
                        .width('100%')
                        .padding({ top: 5 })

                        VideoInfoComponent({ item })
                          .reuseId(item.date)
                      }.padding({ left: 5, right: 5, bottom: 5 })
                      .width('100%')
                    }
                    .width('100%')
                    .height('auto')
                    .backgroundColor($r('app.color.start_window_background_blur'))
                    .borderRadius(10)
                  }
                }
                .padding({
                  left: 10,
                  right: 10,
                  top: 5,
                  bottom: 5
                })
                .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
                .transition(TransitionEffect.OPACITY.animation({ duration: 150, curve: Curve.Sharp }))
                .width('100%')
                .bindContextMenu(this.MenuBuilder(item), ResponseType.LongPress)
                .swipeAction({
                  start: this.itemStart(),
                  edgeEffect: SwipeEdgeEffect.Spring
                })
                .onClick(async () => {
                  if (!this.video_meta_data.some(i => i.date == item?.date!)) {
                    ToolsUtil.showToast('数据正在加载中，请重试')
                    this.videoDataSource.refreshData()
                    return
                  }
                  if (this.MenuBuilderState || this.multipleChooseState != Visibility.None) {
                    this.MenuBuilderState = false
                    return
                  }
                  this.listScroller.closeAllSwipeActions()
                  await ToolsUtil.isFileExist(item) ?
                  ToolsUtil.routerWhere(this.pathStack, 'Player', item, this.video_meta_data) :
                  this.deleteUnExistFile(item)
                })
              }, (item: VideoMetadata) => JSON.stringify(item))
            }
            .cachedCount(3)
            .contentStartOffset(this.topSafeHeight + 55)
            .contentEndOffset(this.bottomSafeHeight)
            .lanes(this.list_line)
            .animation({ duration: 300, curve: Curve.Smooth })
            .scrollBar(BarState.Off)
            .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true }) // 滚动边缘效果
            .chainAnimation(true)
            .width('100%')
            .height('100%') // 新增高度设置
            .onTouch(() => {
              this.searchController.stopEditing()
            })
            .onAppear(() => {
              this.listScroller.scrollEdge(Edge.Top)
            })
          }

          if (this.video_meta_data.length == 0) {
            Row() { //顶栏
              if (!this.loading) {
                Column() {
                  Text($r('app.string.nothing')).fontSize(25).fontWeight(FontWeight.Bold)
                  Text($r('app.string.open_side_bar_tip'))
                    .fontSize(15)
                    .textAlign(TextAlign.Center)
                    .fontWeight(FontWeight.Lighter)
                    .margin({ top: 20 })
                }
              }
            }
            .height('100%')
            .animation({ duration: 150, curve: Curve.Ease })
          }

          Column() {
            Row({ space: 15 }) {
              if (!this.is_edit && this.side_bar_mode == SideBarContainerType.Overlay) {
                Button({ type: ButtonType.Circle, stateEffect: true }) {
                  SymbolGlyph($r('sys.symbol.close_sidebar'))
                    .attributeModifier(new SymbolGlyphFancyModifier(25, '', ''))
                }
                .attributeModifier(new ButtonFancyModifier(40, 40))
                .animation({ duration: 300, curve: Curve.Ease })
                .onClick(() => {
                  this.openSideBar()
                })
                .attributeModifier(new ShadowModifier())
                .zIndex(0)
              }

              SearchComponent({
                controller: this.searchController,
                placeholder: $r('app.string.search_placeholder'),
                searchValue: this.searchValue,
                onChange: () => {
                  this.searchValue === '' ? this.video_meta_data = Preferences.getVideoMetaData(PathUtils.appContext!) :
                    this.video_meta_data = SelectFileUtil.getItemFromSearch(this.video_meta_data, this.searchValue)
                  this.videoDataSource.updateData(this.video_meta_data)
                },
                onSubmit: (value: string) => {
                  if (value == '') {
                    if (this.video_meta_data.length == 0) {
                      ToolsUtil.showToast(PathUtils.appContext!.resourceManager.getStringSync($r('app.string.add_video_first')))
                      return
                    }
                    this.searchController.stopEditing()
                    return
                  }
                  if (value == this.passwd) {
                    ToolsUtil.showToast(PathUtils.appContext!
                      .resourceManager.getStringSync($r('app.string.enter_privacy_space')))
                    this.pathStack.pushPathByName('PrivacySpace', null)
                    this.searchValue = ''
                    return
                  }
                  if (this.video_meta_data.length == 0) {
                    ToolsUtil.showToast(PathUtils.appContext!.resourceManager.getStringSync($r('app.string.no_search_result')))
                  }
                },
                onEditChange: (isEditing: boolean) => {
                  animateToImmediately({ duration: 300, curve: Curve.Ease }, () => {
                    this.is_edit = isEditing
                  })
                }
              })

              if (!this.is_edit) {
                Button({ type: ButtonType.Circle, stateEffect: true }) {
                  SymbolGlyph($r('sys.symbol.text_and_arrow_down'))
                    .attributeModifier(new SymbolGlyphFancyModifier(25, '', ''))
                }
                .attributeModifier(new ButtonFancyModifier(40, 40))
                .animation({ duration: 300, curve: Curve.Ease })
                .bindMenu(this.SortMenuBuilder)
                .attributeModifier(new ShadowModifier())
                .zIndex(0)

                if (this.multipleChooseState === Visibility.Visible) {
                  Button({ type: ButtonType.Circle, stateEffect: true }) {
                    SymbolGlyph($r('sys.symbol.checkmark_square_on_square'))
                      .attributeModifier(new SymbolGlyphFancyModifier(25, '', ''))
                  }
                  .attributeModifier(new ButtonFancyModifier(40, 40))
                  .animation({ duration: 300, curve: Curve.Ease })
                  .bindMenu(this.SelectItemMenuBuilder)
                  .attributeModifier(new ShadowModifier())
                  .zIndex(0)
                }
              }
            }
          }
          .padding({ top: this.topSafeHeight, left: 10, right: 10 })
          .width('100%')

          if (this.loading) {
            Stack() {
              ImportProgressComponent({
                current_import: this.current_import,
                import_sum: this.import_sum
              })
            }.width('100%')
            .height('100%')
          }
        }.backgroundColor($r('app.color.start_window_background'))
        .onAreaChange(async (_oldValue: Area, newValue: Area) => {
          const width = Number(newValue.width);
          this.reDeployListDisplay(width)
        })
        .gesture(SwipeGesture({ direction: SwipeDirection.Horizontal }).onAction((event: GestureEvent) => {
          if (event) {
            this.sideBarStatusTmp === Visibility.Visible ?
            this.closeSideBar(true) : this.openSideBar()
          }
        }))
      }
      .minSideBarWidth(DataSyncUtil.minSideBarWidth) // 设置侧边栏最小宽度
      .minContentWidth(DataSyncUtil.minContentWidth) // 设置内容区最小宽度
      .allowDrop([uniformTypeDescriptor.UniformDataType.PLAIN_TEXT, uniformTypeDescriptor.UniformDataType.VIDEO])
      .onSizeChange((_oldValue: SizeResult, newValue: SizeResult) => {
        if (newValue.width >= DataSyncUtil.minSideBarWidth + DataSyncUtil.minContentWidth) {
          this.side_bar_mode = SideBarContainerType.Embed
          this.sideBarStatusTmp = Visibility.Visible
          this.sideBarStatus = true
        } else {
          this.side_bar_mode = SideBarContainerType.Overlay
          this.sideBarStatusTmp = Visibility.Hidden
          this.sideBarStatus = false
        }
      })
      .onDrop((dragEvent: DragEvent) => {
        let records: Array<unifiedDataChannel.UnifiedRecord> = dragEvent.getData().getRecords();
        let video: unifiedDataChannel.Video = records[0] as unifiedDataChannel.Video;
        WantProcessUtil.want_uri = video.uri
        WantProcessUtil.hasWant(PathUtils.appContext!, this.pathStack)
      })
      .onChange((value: boolean) => {
        this.sideBarStatus = value;
      })
      .showSideBar(this.sideBarStatus)
      .showControlButton(false)
      .divider({ strokeWidth: 0 })
      .gesture(SwipeGesture({ direction: SwipeDirection.Horizontal }).onAction((event: GestureEvent) => {
        if (event) {
          this.closeSideBar(true)
        }
      }))
    }
    .hideTitleBar(true).mode(NavigationMode.Stack).navDestination(this.Pages)
    .onNavBarStateChange((isVisible: boolean) => {
      if (isVisible) {
        this.videoDataSource.refreshData()
        this.passwd = Preferences.getPassword(PathUtils.appContext!)
        this.reDeployListDisplay(this.screen_width)
      }
    })
  }

  reDeployListDisplay(width: number) {
    const base = Math.floor(width / 500);
    this.list_line = this.is_list_display
      ? base + 1
      : base + 2;
    // 增加判断，旋转时保持滚动位置不变
    if (this.listScroller.currentOffset().yOffset == -55) {
      this.listScroller.scrollEdge(Edge.Top)
    }
  }

  @Builder
  Pages(name: string) {
    if (name == 'SettingsPage') {
      SettingsPage()
    } else if (name == 'AboutPage') {
      AboutApp()
    } else if (name == 'FileFolderContent') {
      FileFolderContent()
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
    if (this.multipleChooseState === Visibility.Visible) {
      this.closeMultipleChoose()
      return true
    }
    if (this.sideBarStatusTmp === Visibility.Visible && this.side_bar_mode === SideBarContainerType.Overlay) {
      this.closeSideBar(true)
      return true
    }
    if (this.searchValue.length > 0) {
      this.searchValue = ''
      return true
    }
    return false
  }

  @Builder
  itemStart() {
    Stack() {
    }
    .onVisibleAreaChange([0, 1], (visible: boolean, a: number) => {
      if (visible && a > 0.999999) {
        this.openSideBar()
        setTimeout(() => this.listScroller.closeAllSwipeActions(), 100)
      }
    }).width(50).height(1)
  }
}