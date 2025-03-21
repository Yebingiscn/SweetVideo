import { fileUri, fileIo as fs } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { curves, window } from '@kit.ArkUI';
import { media } from '@kit.MediaKit';
import { BusinessError } from '@kit.BasicServicesKit';
import DataSyncUtil from '../utils/DataSyncUtil';
import PermissionUtil from '../utils/PermissionUtil';
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
  .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
  .width(width)
  .height(height)
  .backgroundColor($r('app.color.start_window_background_blur'))
  .animation({ duration: 300, curve: Curve.Ease })
}

@Styles
function shadowFancy() {
  .shadow({
    radius: 26,
    color: $r('app.color.shadow_color'),
    offsetX: 0,
    offsetY: 0
  })
}

@Entry
@Component
struct Index {
  windowClass = window.getLastWindow(context)
  @State topSafeHeight: number = 0;
  @State video_meta_data: VideoMetadata[] = []
  @State video_meta_data_encryption: VideoMetadata[] = []
  @State now_playing: VideoMetadata | undefined = undefined
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
        await saveAction(currentData)
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
        if (!passwd || passwd == '') {
          return
        }
        this.passwd = passwd
        this.encryption = false
        ToolsUtil.savePwd(passwd)
      },
    }), cornerRadius: 20, shadow: DEFAULT_DIALOG_SHADOW
  })
  VideoDetailDialog: CustomDialogController = new CustomDialogController({
    builder: VideoDetailDialog(), cornerRadius: 20,
    shadow: DEFAULT_DIALOG_SHADOW
  })
  listScroller: ListScroller = new ListScroller()
  searchController: SearchController = new SearchController()

  @Builder
  MenuBuilder(item: VideoMetadata | undefined) {
    Flex({ direction: FlexDirection.Column, justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center }) {
      Row() {
        Image($r("app.media.ffmpeg"))
          .imageFancy(10, 25, 25)
        Text($r('app.string.FFMpeg_Player'))
          .fontSize(15)
          .width(180)
          .height(30)
      }.padding(10).onClick(() => {
        this.MenuBuilderState = false
        setTimeout(() => {
          const target_data = this.encryption ? this.video_meta_data_encryption : this.video_meta_data;
          let item_selected = SelectFileUtil.getItem(target_data, item?.date!)
          if (!target_data.find(i => i.date == item?.date!)) {
            ToolsUtil.showToast('数据正在加载中，请重试')
            this.show_list =
              SelectFileUtil.getAllItems(target_data);
            return
          }
          ToolsUtil.isFileExist(item_selected) ?
          ToolsUtil.routerWhere('pages/FFMpegPlayer', item?.date, target_data, this.encryption) :
          this.deleteUnExistFile(item_selected)
        }, 200)
      })

      Divider().height(2)
      Row() {
        SymbolGlyph($r('sys.symbol.info_circle'))
          .symbolGlyphFancy(20, 25, 40)
        Text('详情')
          .fontSize(15)
          .width(180)
          .height(30)
      }.padding(10).onClick(() => {
        DataSyncUtil.editing_video = JSON.stringify(item)
        this.VideoDetailDialog.open()
      })

      if (!this.encryption) {
        Divider().height(2)
        Row() {
          SymbolGlyph($r('sys.symbol.textformat_size_square'))
            .symbolGlyphFancy(20, 25, 40)
          Text('导入或删除字幕')
            .fontSize(15)
            .width(180)
            .height(30)
        }.padding(10).onClick(async () => {
          await SelectFileUtil.isSubtitleExist(sandbox_subtitle, item?.date!) ?
          SelectFileUtil.deleteSubtitle(sandbox_subtitle, item?.date!) :
          SelectFileUtil.selectExternalSubtitles(sandbox_subtitle, item?.date!)
        })
      }

      Divider().height(2)
      Row() {
        SymbolGlyph($r('sys.symbol.trash_fill'))
          .symbolGlyphFancy(20, 25, 40)
        Text($r('app.string.delete'))
          .fontSize(15)
          .width(180)
          .height(30)
      }.padding(10).onClick(() => {
        DataSyncUtil.editing_video = JSON.stringify(item)
        this.delConfirmDialog.open()
      })

      Divider().height(2)
      Row() {
        SymbolGlyph($r('sys.symbol.rename'))
          .symbolGlyphFancy(20, 25, 40)
        Text($r('app.string.edit'))
          .fontSize(15)
          .width(180)
          .height(30)
      }.padding(10).onClick(() => {
        DataSyncUtil.editing_video = JSON.stringify(item)
        this.editMetadataDialogController.open()
      })

      Divider().height(2)
      Row() {
        SymbolGlyph($r('sys.symbol.checkmark_square_on_square'))
          .symbolGlyphFancy(20, 25, 40)
        Text($r('app.string.multiple_choice'))
          .fontSize(15)
          .width(180)
          .height(30)
      }.padding(10).onClick(() => {
        this.multipleChooseState = this.multipleChooseState == Visibility.None ? Visibility.Visible : Visibility.None
        this.delMultipleList.length = 0
      })
    }.width(150).onAppear(() => {
      ToolsUtil.startVibration()
      this.MenuBuilderState = true
    })
  }

  @Builder
  SortMenuBuilder() {
    Flex({ direction: FlexDirection.Column, justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center }) {
      Row() {
        SymbolGlyph($r('sys.symbol.textformat'))
          .symbolGlyphFancy(20, 25, 40)
        Text($r('app.string.sort_by_name'))
          .fontSize(15)
          .width(100)
          .height(30)
      }.padding(10).onClick(async () => {
        const target_data = this.encryption ? this.video_meta_data_encryption : this.video_meta_data;
        await ToolsUtil.compareByName(target_data, this.encryption)
        this.show_list = SelectFileUtil.getAllItems(target_data);
      })

      Divider().height(10)
      Row() {
        SymbolGlyph($r('sys.symbol.clock'))
          .symbolGlyphFancy(20, 25, 40)
        Text($r('app.string.sort_by_time'))
          .fontSize(15)
          .width(100)
          .height(30)
      }.padding(10).onClick(async () => {
        const target_data = this.encryption ? this.video_meta_data_encryption : this.video_meta_data;
        await ToolsUtil.compareByTime(target_data, this.encryption)
        this.show_list = SelectFileUtil.getAllItems(target_data);
      })
    }.width(150)
  }

  @Builder
  SelectItemMenuBuilder() {
    Flex({ direction: FlexDirection.Column, justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center }) {
      Row() {
        SymbolGlyph($r('sys.symbol.xmark'))
          .symbolGlyphFancy(20, 25, 40)
        Text($r('app.string.cancel'))
          .fontSize(15)
          .width(100)
          .height(30)
      }.padding(10).onClick(() => {
        this.closeMultipleChoose()
        this.delMultipleList.length = 0
      })

      Divider().height(10)
      Row() {
        SymbolGlyph($r('sys.symbol.checkmark_square_on_square'))
          .symbolGlyphFancy(20, 25, 40)
        Text($r('app.string.select_all'))
          .fontSize(15)
          .width(100)
          .height(30)
      }.padding(10).onClick(() => {
        this.itemMultipleChoose = !this.itemMultipleChoose
        this.delMultipleList.length = 0
        for (let index = 0; index < this.show_list.length; index++) {
          this.delMultipleList.push((this.encryption ?
          this.video_meta_data_encryption.find(i => i.date === this.show_list[index])
            : this.video_meta_data.find(i => i.date === this.show_list[index]))!)
        }
      })

      Divider().height(10)
      Row() {
        SymbolGlyph($r('sys.symbol.trash_fill'))
          .symbolGlyphFancy(20, 25, 40)
        Text($r('app.string.delete_selected'))
          .fontSize(15)
          .width(100)
          .height(30)
      }.padding(10).onClick(async () => {
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
            await SelectFileUtil.saveVideoMetaDataEncryption(this.video_meta_data_encryption)
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
    fs.access(sandbox_path + tmp.date, (err) => {
      if (!err) { // 文件存在
        fs.unlink(sandbox_path + tmp.date, (unlinkErr) => {
          if (unlinkErr) {
            reject(new Error(`Error deleting file from sandbox_path: ${unlinkErr.message}`));
            return;
          }
          SelectFileUtil.saveVideoMetaData(this.video_meta_data)
          resolve(); // 在所有操作完成后调用 resolve
        });
      } else {
        resolve(); // 文件不存在时直接调用 resolve
      }
    });
  }

  updateShowList() {
    this.lazy_show_list.clearAllData();
    const safeData = [...this.show_list];
    this.lazy_show_list.reloadAllData(safeData);
  }

  updateList() {
    const source = this.encryption ? this.video_meta_data_encryption : this.video_meta_data
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
    ReqPermission.reqPermissionsFromUser(ReqPermission.permissions, context);
    this.video_meta_data = await SelectFileUtil.getVideoMetaData()
    this.video_meta_data_encryption = await SelectFileUtil.getVideoMetaDataEncryption()
    this.passwd = await SelectFileUtil.getPassword()
    this.show_list = this.video_meta_data.map(i => i.date)
    this.activePermission()
    await this.getSafeHeightAndButton()
    ToolsUtil.isFileFolderExist(sandbox_video, sandbox_subtitle)
  }

  async selectFiles() {
    const selectedFiles: string[] = await SelectFileUtil.selectFiles();
    await this.toMetaData(selectedFiles);
  }

  async selectVideo() {
    const selectedVideos: string[] = await SelectFileUtil.selectVideo();
    await this.toMetaData(selectedVideos);
  }

  activePermission() {
    let tmp = this.video_meta_data.map(i => i.uri)
    PermissionUtil.activePermission(tmp)
  }

  async onPageShow() {
    if (this.now_playing) {
      if (this.encryption) {
        this.video_meta_data_encryption[this.video_meta_data_encryption.findIndex(i => i.date ==
          this.now_playing?.date)].last_play = DataSyncUtil.last_time
        await SelectFileUtil.saveVideoMetaDataEncryption(this.video_meta_data_encryption)
      } else {
        this.video_meta_data[this.video_meta_data.findIndex(i => i.date == this.now_playing?.date)].last_play =
          DataSyncUtil.last_time
        await SelectFileUtil.saveVideoMetaData(this.video_meta_data)
      }
    }
  }

  async toMetaData(list: string[]) {
    const CONCURRENT_LIMIT = 3;
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
              await SelectFileUtil.copyFileToPrivacySpace(this.video_meta_data_encryption, uri, sandbox_video,
                this.encryption, sandbox_path, new Date().getTime().toString(), metadata, file)
            } else {
              const videoInfo = await VideoUtil.setVideoInfo(new Date().getTime().toString(), uri, file.name, metadata,
                this.encryption, sandbox_video, sandbox_path);
              this.video_meta_data.push(videoInfo);
              await SelectFileUtil.saveVideoMetaData(this.video_meta_data);
            }
          }
        } finally {
          fs.closeSync(file);
        }
      };
      const chunkSize = Math.ceil(list.length / CONCURRENT_LIMIT);
      const workers: Promise<void>[] = [];
      for (let i = 0; i < CONCURRENT_LIMIT; i++) {
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
        this.encryption ? this.video_meta_data_encryption : this.video_meta_data);
      ToolsUtil.showToast(`${getContext().resourceManager
        .getStringSync($r('app.string.add_time_info'))}${this.import_sum}`);
    } catch (error) {
      console.error('元数据处理流程错误:', error);
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
    DataSyncUtil.bottomSafeHeight = px2vp(areas[1])
  }

  build() {
    SideBarContainer(SideBarContainerType.Overlay) {
      Column() {
        Scroll() {
          Column() {
            Column() {
              Stack() {
                Image($r("app.media.Background"))
                  .imageFancy(10, '100%', 120)
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
                      .fontColor($r('app.color.text_color'))
                      .margin({ left: 10, right: 12 })
                  }
                }
                .align(Alignment.Start)
                .padding(10)
                .buttonFancy('100%', 60)
                .borderRadius(10)
                .onClick(() => {
                  this.closeSideBar(false)
                  ToolsUtil.routerWhereOnlyUri('pages/Setting')
                })
              }.margin({ top: '4%' })
            }

            Divider().height(10).margin({ top: '5%' })
            Row() {
              Button({ type: ButtonType.Normal, stateEffect: true }) {
                Row() {
                  SymbolGlyph($r('sys.symbol.folder')).symbolGlyphFancy(25, '', '')
                  Text($r('app.string.import_from_files'))
                    .fontSize(15)
                    .fontColor($r('app.color.text_color'))
                    .margin({ left: 10, right: 12 })
                }
              }
              .align(Alignment.Start)
              .padding(10)
              .borderRadius(10)
              .buttonFancy('100%', 60)
              .onClick(() => {
                this.closeSideBar(false)
                this.selectFiles()
              })
            }.width('100%')
            .justifyContent(FlexAlign.Start)
            .margin({ top: '6%' })

            Row() {
              Button({ type: ButtonType.Normal, stateEffect: true }) {
                Row() {
                  SymbolGlyph($r('sys.symbol.video'))
                    .symbolGlyphFancy(25, '', '')
                  Text($r('app.string.import_from_album'))
                    .fontSize(15)
                    .fontColor($r('app.color.text_color'))
                    .margin({ left: 10, right: 12 })
                }
              }
              .align(Alignment.Start)
              .padding(10)
              .borderRadius(10)
              .buttonFancy('100%', 60)
              .onClick(() => {
                this.closeSideBar(false)
                this.selectVideo()
              })
            }.width('100%')
            .justifyContent(FlexAlign.Start)
            .margin({ top: '4%' })

            if (!this.encryption) {
              Row() {
                Button({ type: ButtonType.Normal, stateEffect: true }) {
                  Row() {
                    SymbolGlyph($r('sys.symbol.folder')).symbolGlyphFancy(25, '', '')
                    Text('从下载文件夹导入')
                      .fontSize(15)
                      .fontColor($r('app.color.text_color'))
                      .margin({ left: 10, right: 12 })
                  }
                }
                .align(Alignment.Start)
                .padding(10)
                .borderRadius(10)
                .buttonFancy('100%', 60)
                .onClick(async () => {
                  this.closeSideBar(false)
                  await this.toMetaData(await SelectFileUtil.getDownloadFilesUri());
                })
              }.width('100%')
              .justifyContent(FlexAlign.Start)
              .margin({ top: '6%' })

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
                .borderRadius(10)
                .buttonFancy('100%', 60)
                .onClick(async () => {
                  this.closeSideBar(false)
                  ToolsUtil.routerWhereOnlyUri('pages/RecentPlay')
                })
              }.width('100%')
              .justifyContent(FlexAlign.Start)
              .margin({ top: '6%' })
            }

            Row() {
              if (this.passwd == '' || this.encryption) {
                Button({ type: ButtonType.Normal, stateEffect: true }) {
                  Row() {
                    SymbolGlyph($r('sys.symbol.lock'))
                      .symbolGlyphFancy(25, '', '')
                    Text(this.encryption ? $r('app.string.exist_privacy_space') : $r('app.string.privacy_space'))
                      .fontSize(15)
                      .fontColor($r('app.color.text_color'))
                      .margin({ left: 10, right: 12 })
                  }
                }
                .align(Alignment.Start)
                .padding(10)
                .borderRadius(10)
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
            .margin({ top: '4%' })
          }.width('100%').padding({ left: 20, right: 20, top: 50 })
        }
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
      .transition(TransitionEffect.translate({ x: -300 }).animation({ duration: 500, curve: Curve.Smooth }))
      .visibility(this.sideBarStatusTmp)
      .borderRadius(20)
      .shadowFancy()

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
                          .fontColor($r('sys.color.ohos_dialog_text_alert'))
                          .backgroundColor('rgba(255, 189, 0, 0.8)')
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
                    }.justifyContent(FlexAlign.Center).padding({ top: 5, })
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
            .bindContextMenu(this.MenuBuilder(SelectFileUtil.getItem(this.encryption ? this.video_meta_data_encryption :
            this.video_meta_data, item)), ResponseType.LongPress)
            .swipeAction({
              start: this.itemStart(),
              end: this.itemEnd(SelectFileUtil.getItem(this.encryption ? this.video_meta_data_encryption :
              this.video_meta_data, item)),
              edgeEffect: SwipeEdgeEffect.Spring
            })
            .onClick(() => {
              const target_data = this.encryption ? this.video_meta_data_encryption : this.video_meta_data;
              let item_list = SelectFileUtil.getItem(target_data, item)
              if (!target_data.some(i => i.date == item_list?.date!)) {
                ToolsUtil.showToast('数据正在加载中，请重试')
                this.show_list =
                  SelectFileUtil.getAllItems(target_data);
                return
              }
              if (this.MenuBuilderState || this.multipleChooseState != Visibility.None) {
                this.MenuBuilderState = false
                return
              }
              this.listScroller.closeAllSwipeActions()
              this.now_playing = item_list
              if (VideoUtil.videoWidthAndHeightFormat(String(item_list?.size)) === '0 x 0') {
                ToolsUtil.showToast(getContext().resourceManager.getStringSync($r('app.string.video_error')))
                ToolsUtil.isFileExist(item_list) ?
                ToolsUtil.routerWhere('pages/FFMpegPlayer', item, target_data, this.encryption) :
                this.deleteUnExistFile(item_list)
                return
              }
              ToolsUtil.isFileExist(item_list) ?
              ToolsUtil.routerWhere('pages/Player', item, target_data, this.encryption) :
              this.deleteUnExistFile(item_list)
            })
          })
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
                  ToolsUtil.showToast(getContext().resourceManager.getStringSync($r('app.string.enter_privacy_space')))
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

              Button({ type: ButtonType.Circle, stateEffect: true }) {
                SymbolGlyph($r('sys.symbol.checkmark_square_on_square'))
                  .symbolGlyphFancy(25, '', '')
              }
              .backdropBlur(150)
              .visibility(this.multipleChooseState)
              .buttonFancy(40, 40)
              .bindMenu(this.SelectItemMenuBuilder)
              .shadowFancy()
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
    .allowDrop([uniformTypeDescriptor.UniformDataType.PLAIN_TEXT,uniformTypeDescriptor.UniformDataType.VIDEO])
    .onDrop((dragEvent: DragEvent) => {
      let records: Array<unifiedDataChannel.UnifiedRecord> = dragEvent.getData().getRecords();
      let video: unifiedDataChannel.Video = records[0] as unifiedDataChannel.Video;
      WantProcessUtil.want_uri = video.uri
      WantProcessUtil.hasWant()
    })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
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