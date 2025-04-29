import { fileUri, fileIo as fs } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { curves, SymbolGlyphModifier, window } from '@kit.ArkUI';
import { media } from '@kit.MediaKit';
import { BusinessError } from '@kit.BasicServicesKit';
import DataSyncUtil from '../utils/DataSyncUtil';
import DataUtil from '../utils/DataUtil';
import ToolsUtil from '../utils/ToolsUtil';
import VideoUtil, { DEFAULT_DIALOG_SHADOW, VideoMetadata } from '../utils/VideoInfoUtil';
import TimeUtil from '../utils/TimeUtil';
import { delConfirmDialog } from '../component/DelConfirmDialog';
import { editPasswordDialog } from '../component/EditPasswordDialog';
import { editMetadataDialog } from '../component/EditMetadataDialog';
import ReqPermission from '../utils/ReqPermissionUtil';
import SelectFileUtil from '../utils/SelectFileUtil';
import { JSON } from '@kit.ArkTS';
import { VideoDetailDialog } from '../component/VideoDetailDialog';
import WantProcessUtil from '../utils/WantProcessUtil';
import { unifiedDataChannel, uniformTypeDescriptor } from '@kit.ArkData';
import RecentPlayUtil from '../utils/RecentPlayUtil';
import { addFileFolderNameDialog } from '../component/AddFileFolderNameDialog';
import FileFolderUtil, { FileFolder } from '../utils/FileFolderUtil';
import { editFileFolderNameDialog } from '../component/EditFileFolderNameDialog';

const context = getContext() as common.UIAbilityContext;
const sandbox_path = getContext().filesDir + '/'
const sandbox_video = getContext().filesDir + '/video/'
const sandbox_subtitle = getContext().filesDir + '/subtitle/'

@Extend(Image)
function imageFancy(borderRadius: number, width: number | string, height: number | string) {
  .alt($r("app.media.sweet_video_alt"))
  .backgroundImageSize(ImageSize.Cover)
  .borderRadius(borderRadius)
  .width(width)
  .height(height)
  .autoResize(true)
  .interpolation(ImageInterpolation.Low)
}

@Extend(SymbolGlyph)
function symbolGlyphFancy(fontSize: number, width: number | string, height: number | string) {
  .fontSize(fontSize)
  .fontColor([$r('app.color.text_color')])
  .width(width)
  .height(height)
}

@Extend(Button)
function buttonFancy(width: number | string, height: number | string) {
  .borderRadius(16)
  .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
  .width(width)
  .height(height)
  .backgroundColor($r('app.color.start_window_background_blur'))
  .animation({ duration: 300, curve: Curve.Ease })
}

@Styles
function shadowFancy() {
  .backgroundColor('rgba(0, 0, 0, 0.05)')
  .shadow({
    radius: 26,
    color: $r('app.color.shadow_color'),
    offsetX: 0,
    offsetY: 0
  })
}

@Builder
export function IndexBuilder() {
  Index()
}

@Entry
@Component
struct Index {
  windowClass = window.getLastWindow(context)
  @State topSafeHeight: number = 0;
  @State video_meta_data: VideoMetadata[] = []
  @State video_meta_data_encryption: VideoMetadata[] = []
  @State @Watch('updateShowList') show_list: string[] = []
  @State lazy_show_list: DataUtil<string> = new DataUtil<string>(this.show_list)
  @State @Watch('updateList') encryption: boolean = false
  @State passwd: string = 'passwd'
  @State list_line: number = 1
  @State list_empty_item: string[] = ['']
  @State loading: boolean = false
  @State sideBarStatus: boolean = false
  @State current_iport: number = 0
  @State is_edit: boolean = false
  @State import_sum: number = 0
  @State sideBarStatusTmp: Visibility = Visibility.Hidden
  @State itemMultipleChoose: boolean = false
  @State multipleChooseState: Visibility = Visibility.None
  @State MenuBuilderState: boolean = false
  @State delMultipleList: VideoMetadata[] = []
  @State file_folder_list: FileFolder[] = []
  @State screen_width: number = 0
  @State screen_height: number = 0
  pathStack: NavPathStack = new NavPathStack()
  editMetadataDialogController: CustomDialogController = new CustomDialogController({
    builder: editMetadataDialog({
      confirm: async (title: string | undefined) => {
        if (!title?.trim()) {
          return;
        } // 更严格的空值判断
        const currentData = this.encryption ? this.video_meta_data_encryption : this.video_meta_data;
        const editingVideo = JSON.parse(DataSyncUtil.editing_video) as VideoMetadata;
        const targetIndex = SelectFileUtil.getItemIndex(currentData, editingVideo);
        if (targetIndex === -1) {
          console.error('Target video not found');
          return;
        }
        const titleSet = new Set(currentData.map(v => v.title));
        if (titleSet.has(title)) {
          return;
        }
        currentData[targetIndex].title = title.trim();
        this.show_list = SelectFileUtil.getAllItems(currentData);
        const saveAction =
          this.encryption ? SelectFileUtil.saveVideoMetaDataEncryption : SelectFileUtil.saveVideoMetaData;
        await saveAction(context, currentData)
      },
    }), cornerRadius: 20, shadow: DEFAULT_DIALOG_SHADOW
  })
  delConfirmDialog: CustomDialogController = new CustomDialogController({
    builder: delConfirmDialog({
      confirm: async (confirm_del: boolean | undefined) => {
        if (!confirm_del) {
          return
        }
        await new Promise<void>((resolve, reject) => {
          this.deleteItem(resolve, reject);
        });
        if (this.delMultipleList.length > 0) {
          const deletePromises = this.delMultipleList.map(item => {
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
    }), cornerRadius: 20, shadow: DEFAULT_DIALOG_SHADOW
  })
  editPasswdDialogController: CustomDialogController = new CustomDialogController({
    builder: editPasswordDialog({
      confirm: (passwd: string | undefined) => {
        if (!passwd || passwd.trim() == '') {
          return
        }
        this.passwd = passwd
        this.encryption = false
        ToolsUtil.savePwd(context, passwd)
      },
    }), cornerRadius: 20, shadow: DEFAULT_DIALOG_SHADOW
  })
  addFileFolderNameDialogController: CustomDialogController = new CustomDialogController({
    builder: addFileFolderNameDialog({
      confirm: async (file_folder: string | undefined) => {
        if (!file_folder || file_folder.trim() == '') {
          return
        }
        this.file_folder_list = await FileFolderUtil.createNewFolder(context, file_folder)
      },
    }), cornerRadius: 20, shadow: DEFAULT_DIALOG_SHADOW
  })
  editFileFolderNameDialogController: CustomDialogController = new CustomDialogController({
    builder: editFileFolderNameDialog({
      confirm: async (file_folder: string | undefined) => {
        if (!file_folder || file_folder.trim() == '') {
          return
        }
        this.file_folder_list =
          await FileFolderUtil.changeFileFolderName(context, JSON.parse(DataSyncUtil.editing_video) as FileFolder,
            file_folder, this.file_folder_list)
      }
    }), cornerRadius: 20, shadow: DEFAULT_DIALOG_SHADOW
  })
  VideoDetailDialog: CustomDialogController = new CustomDialogController({
    builder: VideoDetailDialog(), cornerRadius: 20,
    shadow: DEFAULT_DIALOG_SHADOW
  })
  listScroller: ListScroller = new ListScroller()
  searchController: SearchController = new SearchController()

  @Builder
  FileFolderMenu(video_item: VideoMetadata | undefined) {
    Flex({ direction: FlexDirection.Column, justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center }) {
      Menu() {
        ForEach(this.file_folder_list, (item: FileFolder) => {
          MenuItem({ symbolStartIcon: new SymbolGlyphModifier($r("sys.symbol.folder")), content: item.name })
            .onClick(async () => {
              if (this.delMultipleList.length > 0) {
                for (let i = 0; i < this.delMultipleList.length; i++) {
                  await this.addVideoToFileFolder(this.delMultipleList[i]!, item)
                }
                this.delMultipleList = []
                this.closeMultipleChoose()
              } else if (this.multipleChooseState === Visibility.None) {
                await this.addVideoToFileFolder(video_item!, item)
              }
            })
        })
      }.font({ size: 15, weight: FontWeight.Normal })
    }.width(150)
  }

  async addVideoToFileFolder(video_item: VideoMetadata, item: FileFolder) {
    if (!item.video_list.some(v => v.title === video_item.title)) {
      this.file_folder_list = await FileFolderUtil.addVideoInFileFolder(context, video_item!, item.date)
      this.video_meta_data = this.video_meta_data.filter(i => i.date !== video_item?.date)
      this.show_list = this.show_list.filter(i => i !== video_item?.date);
      await SelectFileUtil.saveVideoMetaData(context, this.video_meta_data)
    }
  }

  @Builder
  FileFolderSelectMenu(file_folder: FileFolder) {
    Flex({ direction: FlexDirection.Column, justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center }) {
      Menu() {
        MenuItem({ symbolStartIcon: new SymbolGlyphModifier($r("sys.symbol.trash_fill")), content: '删除' })
          .onClick(async () => {
            this.delMultipleList = Array.from(file_folder.video_list);
            const deletePromises = this.delMultipleList.map(item => {
              return new Promise<void>((resolve, reject) => {
                DataSyncUtil.editing_video = JSON.stringify(item);
                this.deleteItem(resolve, reject);
                this.closeMultipleChoose()
              });
            });
            await Promise.all(deletePromises);
            this.file_folder_list = await FileFolderUtil.deleteFileFolder(context, file_folder, this.file_folder_list)
          })
        MenuItem({
          symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.rename')), content: $r('app.string.edit')
        }).onClick(() => {
          DataSyncUtil.editing_video = JSON.stringify(file_folder);
          this.editFileFolderNameDialogController.open()
        })
      }.font({ size: 15, weight: FontWeight.Normal })
    }.onAppear(() => {
      ToolsUtil.startVibration()
    })
  }

  @Builder
  MenuBuilder(item: VideoMetadata | undefined) {
    Flex({ direction: FlexDirection.Column, justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center }) {
      Menu() {
        MenuItem({ startIcon: $r("app.media.ffmpeg"), content: $r('app.string.FFMpeg_Player') }).onClick(() => {
          this.MenuBuilderState = false
          setTimeout(async () => {
            const target_data = this.encryption ? this.video_meta_data_encryption : this.video_meta_data;
            let target_item = SelectFileUtil.getItem(target_data, item?.date!)
            if (!target_data.find(i => i.date == item?.date!)) {
              ToolsUtil.showToast('数据正在加载中，请重试')
              this.show_list = SelectFileUtil.getAllItems(target_data);
              return
            }
            await ToolsUtil.isFileExist(target_item) ?
            ToolsUtil.routerWhere(this.pathStack, context, 'FFMpegPlayer', item?.date!, this.encryption) :
            this.deleteUnExistFile(target_item)
          }, 200)
        })
        MenuItem({ symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.info_circle')), content: '详情' })
          .onClick(() => {
            DataSyncUtil.editing_video = JSON.stringify(item)
            this.VideoDetailDialog.open()
          })
        if (!this.encryption) {
          MenuItem({
            symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.arrow_right_folder_circle')),
            content: "添加到文件夹",
            builder: (): void => this.FileFolderMenu(item)
          })
          MenuItem({
            symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.textformat_size_square')), content: '导入或删除字幕'
          })
            .onClick(async () => {
              await SelectFileUtil.isSubtitleExist(sandbox_subtitle, item?.date!) ?
              SelectFileUtil.deleteSubtitle(sandbox_subtitle, item?.date!) :
              SelectFileUtil.selectExternalSubtitles(sandbox_subtitle, item?.date!)
            })
        }
        MenuItem({
          symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.trash_fill')), content: $r('app.string.delete')
        })
          .onClick(() => {
            DataSyncUtil.editing_video = JSON.stringify(item)
            this.delConfirmDialog.open()
          })
        MenuItem({
          symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.rename')), content: $r('app.string.edit')
        })
          .onClick(() => {
            DataSyncUtil.editing_video = JSON.stringify(item)
            this.editMetadataDialogController.open()
          })
        MenuItem({
          symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.checkmark_square_on_square')),
          content: $r('app.string.multiple_choice')
        })
          .onClick(() => {
            this.multipleChooseState =
              this.multipleChooseState == Visibility.None ? Visibility.Visible : Visibility.None
            this.delMultipleList.length = 0
          })
      }.font({ size: 15, weight: FontWeight.Normal })
    }.width(180).onAppear(() => {
      ToolsUtil.startVibration()
      this.MenuBuilderState = true
    })
  }

  @Builder
  SortMenuBuilder() {
    Flex({ direction: FlexDirection.Column, justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center }) {
      Menu() {
        MenuItem({
          symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.textformat')),
          content: $r('app.string.sort_by_name')
        })
          .onClick(async () => {
            const targetDataSource = this.encryption ? this.video_meta_data_encryption : this.video_meta_data;
            const sortedData = await ToolsUtil.sortByName(context, targetDataSource, this.encryption);
            this.encryption ? this.video_meta_data_encryption = sortedData : this.video_meta_data = sortedData
            this.show_list = SelectFileUtil.getAllItems(sortedData);
          })
        MenuItem({
          symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.clock')),
          content: $r('app.string.sort_by_time')
        })
          .onClick(async () => {
            const targetDataSource = this.encryption ? this.video_meta_data_encryption : this.video_meta_data;
            const sortedData = await ToolsUtil.sortByTime(context, targetDataSource, this.encryption)
            this.encryption ? this.video_meta_data_encryption = sortedData : this.video_meta_data = sortedData
            this.show_list = SelectFileUtil.getAllItems(sortedData);
          })
      }.font({ size: 15, weight: FontWeight.Normal })
    }.width(150)
  }

  @Builder
  selectFileMenuBuilder() {
    Flex({ direction: FlexDirection.Column, justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center }) {
      Menu() {
        MenuItem({
          symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.folder')),
          content: $r('app.string.import_from_files')
        })
          .onClick(async () => {
            this.closeSideBar(false)
            await this.selectFiles()
          })
        MenuItem({
          symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.picture')),
          content: $r('app.string.import_from_album')
        })
          .onClick(async () => {
            this.closeSideBar(false)
            await this.selectVideo()
          })
        if (!this.encryption) {
          MenuItem({
            symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.folder_badge_eye')),
            content: '从下载文件夹导入（路径：Download/流心视频）'
          })
            .onClick(async () => {
              this.closeSideBar(false)
              await this.toMetaData(await SelectFileUtil.getDownloadFilesUri());
            })
        }
      }.font({ size: 15, weight: FontWeight.Normal })
    }.width(200)
  }

  @Builder
  SelectItemMenuBuilder() {
    Flex({ direction: FlexDirection.Column, justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center }) {
      Menu() {
        MenuItem({
          symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.xmark')),
          content: $r('app.string.cancel')
        })
          .onClick(() => {
            this.closeMultipleChoose()
            this.delMultipleList.length = 0
          })
        MenuItem({
          symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.checkmark_square_on_square')),
          content: $r('app.string.select_all')
        })
          .onClick(() => {
            this.itemMultipleChoose = !this.itemMultipleChoose
            this.delMultipleList.length = 0
            for (let index = 0; index < this.show_list.length; index++) {
              this.delMultipleList.push((this.encryption ?
              this.video_meta_data_encryption.find(i => i.date === this.show_list[index])
                : this.video_meta_data.find(i => i.date === this.show_list[index]))!)
            }
          })
        MenuItem({
          symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.trash_fill')),
          content: $r('app.string.delete_selected')
        })
          .onClick(async () => {
            this.closeMultipleChoose()
            this.multipleChooseState = Visibility.None;
            if (this.delMultipleList.length > 0) {
              const deletePromises = this.delMultipleList.map(item => {
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
      }.font({ size: 15, weight: FontWeight.Normal })
    }.width(150)
  }

  async deleteItem(resolve: () => void, reject: (reason?: Error) => void) {
    let tmp = JSON.parse(DataSyncUtil.editing_video) as VideoMetadata;
    if (await SelectFileUtil.isSubtitleExist(sandbox_subtitle, tmp.date!)) {
      SelectFileUtil.deleteSubtitle(sandbox_subtitle, tmp.date!)
    }
    if (this.encryption) {
      this.video_meta_data_encryption = this.video_meta_data_encryption.filter(i => i.date != tmp.date);
      fs.access(sandbox_video + tmp.date).then((res: boolean) => {
        if (res) {
          fs.unlink(sandbox_video + tmp.date, async (unlinkErr) => {
            if (unlinkErr) {
              reject(new Error(`Error deleting file from sandbox_video: ${unlinkErr.message}`));
              return;
            }
            await SelectFileUtil.saveVideoMetaDataEncryption(context, this.video_meta_data_encryption)
          });
        } else {
          resolve();
        }
      }).catch((err: BusinessError) => {
        console.error("access failed with error message: " + err.message + ", error code: " + err.code);
        resolve();
      });
    } else {
      this.video_meta_data = this.video_meta_data.filter(i => i.date != tmp.date);
    }
    this.show_list = this.show_list.filter(i => i != tmp.date);
    RecentPlayUtil.delData(context, tmp)
    fs.access(sandbox_path + tmp.date, (err) => {
      if (!err) { // 文件存在
        fs.unlink(sandbox_path + tmp.date, (unlinkErr) => {
          if (unlinkErr) {
            reject(new Error(`Error deleting file from sandbox_path: ${unlinkErr.message}`));
            return;
          }
          SelectFileUtil.saveVideoMetaData(context, this.video_meta_data)
          resolve(); // 在所有操作完成后调用 resolve
        });
      } else {
        resolve(); // 文件不存在时直接调用 resolve
      }
    });
  }

  updateShowList() {
    this.lazy_show_list.reloadAllData(this.show_list);
  }

  async updateList() {
    const source = this.encryption ? await SelectFileUtil.getVideoMetaDataEncryption(context) :
      await SelectFileUtil.getVideoMetaData(context)
    this.show_list = source.map(i => i.date)
  }

  onBackPress(): boolean | void {
    if (this.multipleChooseState === Visibility.Visible) {
      this.closeMultipleChoose()
      return true
    }
    if (this.sideBarStatusTmp === Visibility.Visible) {
      this.closeSideBar(true)
      return true
    }
  }

  async aboutToAppear(): Promise<void> {
    SelectFileUtil.getDownloadUri()
    this.passwd = await SelectFileUtil.getPassword(context)
    ToolsUtil.isFileFolderExist(sandbox_video, sandbox_subtitle)
  }

  async onPageShow(): Promise<void> {
    this.video_meta_data = await SelectFileUtil.getVideoMetaData(context)
    this.video_meta_data_encryption = await SelectFileUtil.getVideoMetaDataEncryption(context)
    this.show_list = this.video_meta_data.map(i => i.date)
    this.file_folder_list = await SelectFileUtil.getFileFolder(context)
  }

  async selectFiles() {
    await this.toMetaData(await SelectFileUtil.selectFiles());
  }

  async selectVideo() {
    await this.toMetaData(await SelectFileUtil.selectVideo());
  }

  async toMetaData(list: string[]) {
    if (list.length === 0) {
      ToolsUtil.showToast('没有任何文件被导入哦~');
      return;
    }
    this.loading = true;
    this.import_sum = list.length
    try {
      const processFile = async (uri: string) => {
        await ReqPermission.persistPermission(uri);
        const avMetadataExtractor: media.AVMetadataExtractor = await media.createAVMetadataExtractor();
        const file = fs.openSync(uri);
        try {
          avMetadataExtractor.fdSrc = file;
          const metadata = await new Promise<media.AVMetadata>((resolve, reject) => {
            avMetadataExtractor.fetchMetadata((error: BusinessError, metadata: media.AVMetadata) => {
              error ? reject(error) : resolve(metadata);
            });
          });
          const isDuplicate = this.encryption
            ? this.video_meta_data_encryption.some(item => item.title === file.name)
            : this.video_meta_data.some(item => item.title === file.name);
          if (!isDuplicate) {
            if (this.encryption) {
              await SelectFileUtil.copyFileToPrivacySpace(context, this.video_meta_data_encryption, uri, sandbox_video,
                this.encryption, sandbox_path, new Date().getTime().toString(), metadata, file)
            } else {
              const videoInfo = await VideoUtil.setVideoInfo(new Date().getTime().toString(), uri, file.name, metadata,
                this.encryption, sandbox_video, sandbox_path);
              this.video_meta_data.push(videoInfo);
              await SelectFileUtil.saveVideoMetaData(context, this.video_meta_data);
            }
          }
        } finally {
          fs.closeSync(file);
        }
      };
      const chunkSize = Math.ceil(list.length / VideoUtil.MAX_CONCURRENT);
      const workers: Promise<void>[] = [];
      for (let i = 0; i < VideoUtil.MAX_CONCURRENT; i++) {
        const start = i * chunkSize;
        const end = Math.min(start + chunkSize, list.length);
        const chunk = list.slice(start, end);
        workers.push((async () => {
          for (const uri of chunk) {
            await processFile(uri);
            this.current_iport++; // 安全地更新进度
          }
        })());
      }
      await Promise.all(workers);
      this.show_list = SelectFileUtil.getAllItems(
        this.encryption ? await SelectFileUtil.getVideoMetaDataEncryption(context) :
          await SelectFileUtil.getVideoMetaData(context));
      ToolsUtil.showToast(`${getContext().resourceManager
        .getStringSync($r('app.string.add_time_info'))}${this.import_sum}`);
    } catch (error) {
      ToolsUtil.showToast('处理过程中发生意外错误');
    } finally {
      this.loading = false;
      this.current_iport = 0
    }
  }

  closeSideBar(isPlayAnimation: boolean) {
    this.sideBarStatusTmp = Visibility.Hidden
    isPlayAnimation ? setTimeout(() => {
      this.sideBarStatus = false
    }, 400) : this.sideBarStatus = false
  }

  openSideBar() {
    this.sideBarStatusTmp = Visibility.Visible
    this.sideBarStatus = true
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

  async getSafeHeightAndButton() {
    await (await this.windowClass).setWindowLayoutFullScreen(true)
    const areas = await Promise.all([
      (await this.windowClass).getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM).topRect.height,
      (await this.windowClass).getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR).bottomRect.height]);
    this.topSafeHeight = px2vp(areas[0]);
    DataSyncUtil.setTopSafeHeight(this.topSafeHeight)
    if (this.screen_height > this.screen_width && this.topSafeHeight === 0) {
      this.topSafeHeight = DataSyncUtil.getActuallyTopSafeHeight()!
    }
  }

  build() {
    Navigation(this.pathStack) {
      SideBarContainer(SideBarContainerType.Overlay) {
        Column() {
          Scroll() {
            Column() {
              Stack() {
                Image($r("app.media.Background"))
                  .imageFancy(16, '100%', 120)
                  .zIndex(1)
                Row() {
                  Image($r("app.media.Foreground"))
                    .autoResize(true)
                    .interpolation(ImageInterpolation.Low)
                    .backgroundImageSize(ImageSize.Cover)
                    .width(50)
                    .height(50)
                  Text($r('app.string.EntryAbility_label'))
                    .fontSize(20)
                    .fontColor('#ffff')
                    .margin({ left: 5, right: 12 })
                }.width('100%')
                .justifyContent(FlexAlign.Center)
                .zIndex(2)
              }

              Row() {
                Button({ type: ButtonType.Normal, stateEffect: true }) {
                  Row() {
                    SymbolGlyph($r('sys.symbol.gearshape')).symbolGlyphFancy(25, '', '')
                    Text('设置')
                      .fontSize(15)
                      .margin({ left: 10, right: 12 })
                  }
                }
                .align(Alignment.Start)
                .padding(10)
                .buttonFancy('100%', 60)
                .onClick(() => {
                  this.closeSideBar(false)
                  this.pathStack.pushPathByName('SettingsPage', null)
                })
              }.margin({ top: 10 })

              Row() {
                if (this.passwd == '' || this.encryption) {
                  Button({ type: ButtonType.Normal, stateEffect: true }) {
                    Row() {
                      SymbolGlyph($r('sys.symbol.lock'))
                        .symbolGlyphFancy(25, '', '')
                      Text(this.encryption ? $r('app.string.exist_privacy_space') : $r('app.string.privacy_space'))
                        .fontSize(15)
                        .margin({ left: 10, right: 12 })
                    }
                  }
                  .align(Alignment.Start)
                  .padding(10)
                  .buttonFancy('100%', 60)
                  .onClick(() => {
                    this.closeSideBar(false)
                    if (this.passwd == '') {
                      this.editPasswdDialogController.open()
                      return
                    }
                    this.encryption = false
                  })
                  .gesture(LongPressGesture().onAction(() => {
                    this.closeSideBar(false)
                    this.editPasswdDialogController.open()
                  }))
                }
              }.width('100%')
              .justifyContent(FlexAlign.Start)
              .margin({ top: 10 })

              if (!this.encryption) {
                Row() {
                  Button({ type: ButtonType.Normal, stateEffect: true }) {
                    Row() {
                      SymbolGlyph($r('sys.symbol.clock')).symbolGlyphFancy(25, '', '')
                      Text('最近播放')
                        .fontSize(15)
                        .fontColor($r('app.color.text_color'))
                        .margin({ left: 10, right: 12 })
                    }
                  }
                  .align(Alignment.Start)
                  .padding(10)
                  .buttonFancy('100%', 60)
                  .onClick(async () => {
                    this.closeSideBar(false)
                    this.pathStack.pushPathByName('RecentPlay', null)
                  })
                }.width('100%')
                .justifyContent(FlexAlign.Start)
                .margin({ top: this.passwd == '' || this.encryption ? 10 : 0 })
              }
              Column() {
                Row() {
                  Button({ type: ButtonType.Normal, stateEffect: true }) {
                    Row() {
                      SymbolGlyph($r('sys.symbol.plus_square')).symbolGlyphFancy(25, '', '')
                      Text('导入视频')
                        .fontSize(15)
                        .margin({ left: 10, right: 12 })
                    }
                  }
                  .align(Alignment.Start)
                  .padding(10)
                  .buttonFancy('100%', 60)
                  .bindMenu(this.selectFileMenuBuilder)
                }.width('100%')
                .justifyContent(FlexAlign.Start)

                if (!this.encryption) {
                  Row() {
                    Button({ type: ButtonType.Normal, stateEffect: true }) {
                      Row() {
                        SymbolGlyph($r('sys.symbol.folder_badge_plus')).symbolGlyphFancy(25, '', '')
                        Text('添加文件夹')
                          .fontSize(15)
                          .margin({ left: 10, right: 12 })
                      }
                    }
                    .align(Alignment.Start)
                    .padding(10)
                    .buttonFancy('100%', 60)
                    .onClick(() => {
                      this.addFileFolderNameDialogController.open()
                    })
                  }.width('100%')
                  .justifyContent(FlexAlign.Start)
                }
              }
              .margin({ top: 10 })
              .justifyContent(FlexAlign.Start)
              .backgroundColor($r('app.color.start_window_background_blur'))
              .borderRadius(16)

              if (!this.encryption) {
                List() {
                  ForEach(this.file_folder_list, (item: FileFolder) => {
                    ListItem() {
                      Row() {
                        SymbolGlyph($r('sys.symbol.folder')).symbolGlyphFancy(25, '', '')
                        Text(item.name)
                          .fontSize(15)
                          .margin({ left: 10, right: 12 })
                      }.width('100%')
                    }
                    .onClick(() => {
                      ToolsUtil.routerToFileFolder(this.pathStack, item)
                    })
                    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
                    .bindContextMenu(this.FileFolderSelectMenu(item), ResponseType.LongPress)
                    .height(60)
                    .align(Alignment.Start)
                    .padding(10)
                  })
                }
                .borderRadius(16)
                .width('100%')
                .height('auto')
                .align(Alignment.Start)
                .margin({ top: 10 })
                .backgroundColor($r('app.color.start_window_background_blur'))
              }
            }.width('100%')
          }
          .padding({ left: 20, right: 20, top: 50 })
          .layoutWeight(1)
          .align(Alignment.Top)
          .scrollBar(BarState.Off)
          .scrollable(ScrollDirection.Vertical) // 启用垂直滚动
          .edgeEffect(EdgeEffect.Spring) // 滚动边缘效果
          .width('100%')
          .height('100%')
        }
        .width('100%')
        .justifyContent(FlexAlign.Start)
        .backgroundColor($r('app.color.start_window_background'))
        .transition(TransitionEffect.translate({ x: -300 }).animation({ duration: 500, curve: Curve.Friction }))
        .visibility(this.sideBarStatusTmp)
        .borderRadius(16)

        Stack({ alignContent: Alignment.Top }) { // 内容区
          if (this.sideBarStatus) {
            Column()// 遮罩
              .height('100%')
              .width('100%')
              .backgroundBlurStyle(BlurStyle.BACKGROUND_THIN)
              .transition(TransitionEffect.OPACITY.animation({ curve: curves.springMotion(0, 1) }))
              .zIndex(1)
              .onClick(() => {
                this.closeSideBar(true)
              })
          }

          List({ scroller: this.listScroller }) {
            ForEach(this.list_empty_item, () => {
              ListItem().height(this.topSafeHeight + 55)
            })
            LazyForEach(this.lazy_show_list, (item: string, index: number) => { // 加载视频列表
              ListItem() {
                Column() {
                  Row() {
                    Image(fileUri.getUriFromPath(sandbox_path + item))
                      .imageFancy(10, 60, 90)
                    Column() {
                      Row() {
                        Text((String(SelectFileUtil.getItem(this.encryption ? this.video_meta_data_encryption :
                        this.video_meta_data, item)?.title)).slice(0,
                          String(SelectFileUtil.getItem(this.encryption ? this.video_meta_data_encryption :
                          this.video_meta_data, item)?.title).lastIndexOf('.')))
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
                              const foundMetadata = SelectFileUtil.getItem(this.encryption ?
                              this.video_meta_data_encryption : this.video_meta_data, item)
                              if (foundMetadata) {
                                const delSet = new Set(this.delMultipleList as VideoMetadata[]);
                                value ? delSet.add(foundMetadata) : delSet.delete(foundMetadata);
                                this.delMultipleList = Array.from(delSet);
                              }
                            }
                          })
                      }

                      Row() {
                        if ((SelectFileUtil.getItem(this.encryption ? this.video_meta_data_encryption :
                        this.video_meta_data, item)?.hdr_type) === media.HdrType.AV_HDR_TYPE_VIVID) {
                          Image($r("app.media.hdr_vivid_icon"))
                            .imageFancy(10, 65, 25)
                        } else if (VideoUtil.videoWidthAndHeightFormat(String(SelectFileUtil.getItem(this.encryption ?
                        this.video_meta_data_encryption : this.video_meta_data, item)?.size)).includes('HD')) {
                          Text(VideoUtil.videoWidthAndHeightFormat(String(SelectFileUtil.getItem(this.encryption ?
                          this.video_meta_data_encryption : this.video_meta_data, item)?.size)))
                            .fontWeight(FontWeight.Bold)
                            .fontSize(10)
                            .opacity(0.8)
                            .backgroundColor('rgba(255, 189, 0, 0.4)')
                            .padding(5)
                            .borderRadius(10)
                        } else if (VideoUtil.videoWidthAndHeightFormat(String(SelectFileUtil.getItem(this.encryption ?
                        this.video_meta_data_encryption : this.video_meta_data, item)?.size)) === '0 x 0') {
                          Text($r('app.string.unknown_resolution'))
                            .fontSize(10)
                            .opacity(0.8)
                            .backgroundColor('#808080')
                            .padding(5)
                            .borderRadius(10)
                        } else {
                          Text(VideoUtil.videoWidthAndHeightFormat(String(SelectFileUtil.getItem(this.encryption ?
                          this.video_meta_data_encryption : this.video_meta_data, item)?.size)))
                            .fontSize(15)
                            .opacity(0.8)
                        }
                        Text("  " + TimeUtil.convertMsToMMSS(SelectFileUtil.getItem(this.encryption ?
                        this.video_meta_data_encryption : this.video_meta_data, item)?.time))
                          .fontSize(15)
                          .fontWeight(FontWeight.Normal)
                          .opacity(0.8)
                      }.justifyContent(FlexAlign.Center).padding({ top: 5 })
                    }.alignItems(HorizontalAlign.Start).padding(10).width('90%')
                  }.justifyContent(FlexAlign.Center)
                }
                .padding({ left: 10 })
                .height(100)
                .justifyContent(FlexAlign.SpaceEvenly)
              }
              .key(item)
              .width('100%')
              .padding({
                left: 10,
                right: 10,
                top: 5,
                bottom: 5
              })
              .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
              .transition(TransitionEffect.OPACITY.animation({ duration: 150, curve: Curve.Sharp }))
              .width('100%')
              .bindContextMenu(this.MenuBuilder(SelectFileUtil.getItem(this.encryption ?
              this.video_meta_data_encryption :
              this.video_meta_data, item)), ResponseType.LongPress)
              .swipeAction({
                start: this.itemStart(),
                end: this.itemEnd(SelectFileUtil.getItem(this.encryption ? this.video_meta_data_encryption :
                this.video_meta_data, item)),
                edgeEffect: SwipeEdgeEffect.Spring
              })
              .onClick(async () => {
                const list_data = this.encryption ? this.video_meta_data_encryption : this.video_meta_data;
                let target_item = SelectFileUtil.getItem(list_data, item)
                if (!list_data.some(i => i.date == target_item?.date!)) {
                  ToolsUtil.showToast('数据正在加载中，请重试')
                  this.show_list = SelectFileUtil.getAllItems(list_data);
                  return
                }
                if (this.MenuBuilderState || this.multipleChooseState != Visibility.None) {
                  this.MenuBuilderState = false
                  return
                }
                this.listScroller.closeAllSwipeActions()
                await ToolsUtil.isFileExist(target_item) ?
                ToolsUtil.routerWhere(this.pathStack, context, 'Player', item, this.encryption) :
                this.deleteUnExistFile(target_item)
              })
            }, (item: string) => item)
            ForEach(this.list_empty_item, () => {
              ListItem().height(50)
            })
          }
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

          Row() { //顶栏
            if (!this.loading) {
              Column() {
                Text($r('app.string.nothing')).fontSize(25).fontWeight(FontWeight.Bold)
                Text(this.encryption ? $r('app.string.privacy_space_info') : $r('app.string.open_side_bar_tip'))
                  .fontSize(15)
                  .textAlign(TextAlign.Center)
                  .fontWeight(FontWeight.Lighter)
                  .margin({ top: 20 })
              }
            }
          }.height('100%')
          .visibility(this.show_list.length == 0 ? Visibility.Visible : Visibility.Hidden)
          .animation({ duration: 150, curve: Curve.Ease })

          Column() {
            Row({ space: 15 }) {
              if (!this.is_edit) {
                Button({ type: ButtonType.Circle, stateEffect: true }) {
                  SymbolGlyph($r('sys.symbol.close_sidebar'))
                    .symbolGlyphFancy(25, '', '')
                }
                .buttonFancy(40, 40)
                .backdropBlur(150)
                .onClick(() => {
                  this.openSideBar()
                })
                .shadowFancy()
              }

              Search({
                controller: this.searchController,
                placeholder: $r('app.string.search_placeholder')
              })
                .layoutWeight(1)
                .height(40)
                .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
                .backgroundColor($r('app.color.start_window_background_blur'))
                .backdropBlur(150)
                .searchButton(getContext(this).resourceManager.getStringSync($r('app.string.search')),
                  { fontSize: '16fp', fontColor: $r('app.color.main_color') })
                .animation({ duration: 300, curve: Curve.Ease })
                .shadowFancy()
                .onChange((value: string) => {
                  const item = this.encryption ? this.video_meta_data_encryption : this.video_meta_data
                  value === '' ? this.show_list = SelectFileUtil.getAllItems(item)
                    : this.show_list = SelectFileUtil.getItemFromSearch(item, value)
                })
                .onSubmit((value: string) => {
                  const currentMeta = this.encryption ? this.video_meta_data_encryption : this.video_meta_data;
                  if (value == '') {
                    this.show_list = SelectFileUtil.getAllItems(currentMeta)
                    if (this.show_list.length == 0) {
                      ToolsUtil.showToast(getContext().resourceManager.getStringSync($r('app.string.add_video_first')))
                      return
                    }
                    this.searchController.stopEditing()
                    return
                  }
                  if (value == this.passwd && !this.encryption) {
                    this.encryption = true
                    ToolsUtil.showToast(getContext()
                      .resourceManager
                      .getStringSync($r('app.string.enter_privacy_space')))
                    return
                  }
                  this.show_list = SelectFileUtil.getItemFromSearch(currentMeta, value)
                  if (this.show_list.length == 0) {
                    ToolsUtil.showToast(getContext().resourceManager.getStringSync($r('app.string.no_search_result')))
                  }
                })
                .onEditChange((isEditing: boolean) => {
                  this.is_edit = isEditing
                })

              if (!this.is_edit) {
                Button({ type: ButtonType.Circle, stateEffect: true }) {
                  SymbolGlyph($r('sys.symbol.text_and_arrow_down'))
                    .symbolGlyphFancy(25, '', '')
                }
                .backdropBlur(150)
                .buttonFancy(40, 40)
                .bindMenu(this.SortMenuBuilder)
                .shadowFancy()

                if (this.multipleChooseState === Visibility.Visible) {
                  Button({ type: ButtonType.Circle, stateEffect: true }) {
                    SymbolGlyph($r('sys.symbol.checkmark_square_on_square'))
                      .symbolGlyphFancy(25, '', '')
                  }
                  .backdropBlur(150)
                  .buttonFancy(40, 40)
                  .bindMenu(this.SelectItemMenuBuilder)
                  .shadowFancy()
                }
              }
            }
          }.padding({ top: this.topSafeHeight }).width('90%')

          Stack() {
            Column() {
              Progress({ value: this.current_iport, total: this.import_sum, type: ProgressType.Ring })
                .width(100)
                .height(100)
                .color($r('app.color.main_color'))
                .style({ strokeWidth: 15 })
                .margin({ bottom: 8 }) // 添加底部间距分隔文字
              Text(this.current_iport + '/' + this.import_sum)
                .fontSize(16)
                .fontColor($r('app.color.main_color'))
            }
          }.width('100%')
          .height('100%')
          .visibility(this.loading ? Visibility.Visible : Visibility.Hidden)
          .animation({ duration: 150, curve: Curve.Sharp })
        }.backgroundColor($r('app.color.start_window_background'))
        .onAreaChange(async (_oldValue: Area, newValue: Area) => {
          this.screen_width = Math.floor(new Number(newValue.width).valueOf())
          this.screen_height = Math.floor(new Number(newValue.height).valueOf())
          await this.getSafeHeightAndButton()
          this.list_line = Math.floor(new Number(newValue.width).valueOf() / 500 + 1)
          this.list_empty_item = []
          for (let i = 1; i <= this.list_line; i++) {
            this.list_empty_item.push(i.toString())
          }
        })
        .gesture(SwipeGesture({ direction: SwipeDirection.Horizontal }).onAction((event: GestureEvent) => {
          if (event) {
            this.sideBarStatusTmp === Visibility.Visible ?
            this.closeSideBar(true) : this.openSideBar()
          }
        }))
      }
      .allowDrop([uniformTypeDescriptor.UniformDataType.PLAIN_TEXT, uniformTypeDescriptor.UniformDataType.VIDEO])
      .onDrop((dragEvent: DragEvent) => {
        let records: Array<unifiedDataChannel.UnifiedRecord> = dragEvent.getData().getRecords();
        let video: unifiedDataChannel.Video = records[0] as unifiedDataChannel.Video;
        WantProcessUtil.want_uri = video.uri
        WantProcessUtil.hasWant(context)
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
    }.mode(NavigationMode.Stack).hideToolBar(true).hideTitleBar(true)
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

  @Builder
  itemEnd(item: VideoMetadata) {
    Row({ space: 10 }) {
      Stack().width(10)
      SymbolGlyph($r('sys.symbol.trash_fill'))
        .symbolGlyphFancy(28, 40, 40)
        .onClick(() => {
          this.listScroller.closeAllSwipeActions()
          DataSyncUtil.editing_video = JSON.stringify(item)
          this.delConfirmDialog.open()
        })
      Stack().width(10)
      SymbolGlyph($r('sys.symbol.rename'))
        .symbolGlyphFancy(28, 40, 40)
        .onClick(() => {
          this.listScroller.closeAllSwipeActions()
          DataSyncUtil.editing_video = JSON.stringify(item)
          this.editMetadataDialogController.open()
        })
      Stack().width(10)
      SymbolGlyph($r('sys.symbol.checkmark_square_on_square'))
        .symbolGlyphFancy(28, 40, 40)
        .onClick(() => {
          this.multipleChooseState = this.multipleChooseState == Visibility.None ? Visibility.Visible : Visibility.None
          this.itemMultipleChoose = false
          this.listScroller.closeAllSwipeActions()
          this.delMultipleList.length = 0
        })
      if (this.encryption) {
        Stack().width(10)
        SymbolGlyph($r('sys.symbol.arrow_right_folder_circle'))
          .symbolGlyphFancy(28, 40, 40)
          .onClick(() => {
            SelectFileUtil.copyFile(item, context)
          })
      }
    }.padding(10).justifyContent(FlexAlign.SpaceEvenly)
  }
}