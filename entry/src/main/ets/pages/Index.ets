import { fileUri, fileIo as fs } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { media } from '@kit.MediaKit';
import { BusinessError } from '@kit.BasicServicesKit';
import DataSyncUtil from '../utils/DataSyncUtil';
import PermissionUtil from '../utils/PermissionUtil';
import DataUtil from '../utils/DataUtil';
import ToolsUtil from '../utils/ToolsUtil';
import VideoUtil, { VideoMetadata } from '../utils/VideoInfoUtil';
import TimeUtil from '../utils/TimeUtil';
import { delConfirmDialog } from '../component/DelConfirmDialog';
import { editPasswordDialog } from '../component/EditPasswordDialog';
import { editMetadataDialog } from '../component/EditMetadataDialog';
import ReqPermission from '../utils/ReqPermissionUtil';
import WantProcess from '../utils/WantProcessUtil';
import SelectFileUtil from '../utils/SelectFileUtil';
import { JSON } from '@kit.ArkTS';

const context = getContext() as common.UIAbilityContext;
const sandbox_path = getContext().filesDir + '/'
const sandbox_video = getContext().filesDir + '/video/'

@Extend(Image)
function imageFancy(borderRadius: number, width: number | string, height: number | string) {
  .backgroundImageSize(ImageSize.Cover)
  .borderRadius(borderRadius)
  .width(width)
  .height(height)
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
    radius: 15,
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
  @State bottomSafeHeight: number = 0;
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
  @State search_input: string = ''
  @State sideBarStatus: boolean = false
  @State sideBarStatusTmp: Visibility = Visibility.Hidden
  @State itemMultipleChoose: boolean = false
  @State multipleChooseState: Visibility = Visibility.None
  @State MenuBuilderState: boolean = false
  @State delMultipleList: VideoMetadata[] = []

  @Builder
  MenuBuilder(item: VideoMetadata | undefined) {
    Flex({ direction: FlexDirection.Column, justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center }) {
      Row() {
        Image($r("app.media.ffmpeg"))
          .imageFancy(10, 25, 25)
        Text($r('app.string.FFmpeg_Player'))
          .fontSize(15)
          .width(180)
          .height(30)
      }.padding(10).onClick(() => {
        this.MenuBuilderState = false
        setTimeout(() => {
          let item_selected = SelectFileUtil.getItem(this.encryption ? this.video_meta_data_encryption :
          this.video_meta_data, item?.date!)
          ToolsUtil.isFileExist(item_selected) ? ToolsUtil.routerWhere('pages/FFmpegPlayer', item?.date,
            this.encryption ? this.video_meta_data_encryption : this.video_meta_data) :
          this.deleteUnExistFile(item_selected)
        }, 200)
      })

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
          .width(25)
          .height(40)
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
          .width(25)
          .height(40)
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
      }.padding(10).onClick(() => {
        this.show_list = ToolsUtil.compareByName(this.show_list,
          this.encryption ? this.video_meta_data_encryption : this.video_meta_data)
        this.encryption ? SelectFileUtil.saveVideoMetaDataEncryption(this.video_meta_data_encryption) :
        SelectFileUtil.saveVideoMetaData(this.video_meta_data)
      })

      Divider().height(10)
      Row() {
        SymbolGlyph($r('sys.symbol.clock'))
          .symbolGlyphFancy(20, 25, 40)
        Text($r('app.string.sort_by_time'))
          .fontSize(15)
          .width(100)
          .height(30)
      }.padding(10).onClick(() => {
        this.show_list = ToolsUtil.compareByTime(this.show_list,
          this.encryption ? this.video_meta_data_encryption : this.video_meta_data)
        this.encryption ? SelectFileUtil.saveVideoMetaDataEncryption(this.video_meta_data_encryption) :
        SelectFileUtil.saveVideoMetaData(this.video_meta_data)
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

  editMetadataDialogController: CustomDialogController = new CustomDialogController({
    builder: editMetadataDialog({
      confirm: (title: string | undefined) => {
        if (!title || title == '') {
          return
        }
        let tmp = JSON.parse(DataSyncUtil.editing_video) as VideoMetadata
        let index =
          SelectFileUtil.getItemIndex(this.encryption ? this.video_meta_data_encryption : this.video_meta_data, tmp)
        if (this.encryption) {
          if (this.video_meta_data_encryption.map(i => i.title).includes(title)) {
            return
          }
          this.video_meta_data_encryption[index].title = title
        } else {
          if (this.video_meta_data.map(i => i.title).includes(title)) {
            return
          }
          this.video_meta_data[index].title = title
        }
        this.show_list =
          SelectFileUtil.getAllItem(this.encryption ? this.video_meta_data_encryption : this.video_meta_data)
        SelectFileUtil.saveVideoMetaData(this.video_meta_data)
        SelectFileUtil.saveVideoMetaDataEncryption(this.video_meta_data_encryption)
      },
    }),
    cornerRadius: 20,
    shadow: {
      radius: 20,
      color: $r('app.color.shadow_color'),
      offsetX: 0,
      offsetY: 0
    }
  })
  delConfirmDialog: CustomDialogController = new CustomDialogController({
    builder: delConfirmDialog({
      confirm: (confirm_del: boolean | undefined) => {
        if (!confirm_del) {
          return
        }
        return new Promise<void>((resolve, reject) => {
          this.deleteItem(resolve, reject);
        });
      }
    }),
    cornerRadius: 20,
    shadow: {
      radius: 20,
      color: $r('app.color.shadow_color'),
      offsetX: 0,
      offsetY: 0
    }
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
    }),
    cornerRadius: 20,
    shadow: {
      radius: 20,
      color: $r('app.color.shadow_color'),
      offsetX: 0,
      offsetY: 0
    }
  })
  listScroller: ListScroller = new ListScroller()
  searchController: SearchController = new SearchController()

  deleteItem(resolve: () => void, reject: (reason?: Error) => void) {
    let tmp = JSON.parse(DataSyncUtil.editing_video) as VideoMetadata;
    if (this.encryption) {
      this.video_meta_data_encryption = this.video_meta_data_encryption.filter(i => i.date != tmp.date);
      fs.access(sandbox_video + tmp.date, (err) => {
        if (!err) { // 文件存在
          fs.unlink(sandbox_video + tmp.date, (unlinkErr) => {
            if (unlinkErr) {
              reject(new Error(`Error deleting file from sandbox_video: ${unlinkErr.message}`));
              return;
            }
            SelectFileUtil.saveVideoMetaDataEncryption(this.video_meta_data_encryption)
          });
        } else {
          resolve(); // 如果文件访问失败，直接 resolve
        }
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
    let total = this.lazy_show_list.totalCount()
    for (let i = 0; i <= total; i++) {
      this.lazy_show_list.delData()
    }
    let a = 0
    for (let item of this.show_list) {
      this.lazy_show_list.addData1(a, item)
      a++
    }
  }

  updateList() {
    this.show_list = []
    this.encryption ? this.show_list = this.video_meta_data_encryption.map(i => i.date) :
      this.show_list = this.video_meta_data.map(i => i.date)
  }

  onBackPress(): boolean | void {
    if (this.multipleChooseState === Visibility.Visible) {
      this.closeMultipleChoose()
      return true
    }
  }

  async aboutToAppear(): Promise<void> {
    SelectFileUtil.getDownloadUri()
    WantProcess.checkWant()
    ReqPermission.reqPermissionsFromUser(ReqPermission.permissions, context);
    this.video_meta_data = await SelectFileUtil.getVideMetaData()
    this.video_meta_data_encryption = await SelectFileUtil.getVideoMetaDataEncryption()
    this.passwd = await SelectFileUtil.getPassword()
    this.show_list = this.video_meta_data.map(i => i.date)
    this.activePermission()
    this.getSafeHeightAndButton()
    if (!fs.accessSync(sandbox_video)) {
      fs.mkdirSync(sandbox_video)
    }
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
        SelectFileUtil.saveVideoMetaDataEncryption(this.video_meta_data_encryption)
      } else {
        this.video_meta_data[this.video_meta_data.findIndex(i => i.date == this.now_playing?.date)].last_play =
          DataSyncUtil.last_time
        SelectFileUtil.saveVideoMetaData(this.video_meta_data)
      }
    }
  }

  async toMetaData(list: string[]) { // 持久化视频存储
    const CONCURRENT_LIMIT = 3; // 最大并发数
    let index = 0; // 当前处理的文件索引
    if (list.length == 0) {
      return
    }
    ToolsUtil.showToast(getContext().resourceManager.getStringSync($r('app.string.add_time_info')))
    this.loading = true;
    const processFile = async (uri: string) => {
      ReqPermission.persistPermission(uri);
      const avMetadataExtractor: media.AVMetadataExtractor = await media.createAVMetadataExtractor();
      const file = fs.openSync(uri);
      avMetadataExtractor.fdSrc = file;
      const metadata = await new Promise<media.AVMetadata>((resolve, reject) => {
        avMetadataExtractor.fetchMetadata((error: BusinessError, metadata: media.AVMetadata) => {
          error ? reject(error) : resolve(metadata)
        });
      });
      if ((!this.encryption && !this.video_meta_data.some(item => item.title === file.name)) ||
        (this.encryption && !this.video_meta_data_encryption.some(item => item.title === file.name))) {
        if (this.encryption) {
          this.show_list =
            await ToolsUtil.copyFileToPrivacySpace(this.video_meta_data_encryption, uri, sandbox_video, this.encryption,
              sandbox_path, new Date().getTime().toString(), metadata, file)
        } else {
          this.video_meta_data.push(await VideoUtil.setVideoInfo(new Date().getTime().toString(), uri, file.name,
            metadata, this.encryption, sandbox_video, sandbox_path)); // Use await here
          SelectFileUtil.saveVideoMetaData(this.video_meta_data)
        }
      }
    };
    const processNext = async () => {
      while (index < list.length) {
        const uri = list[index++];
        await processFile(uri);
      }
    };
    const promises: Promise<void>[] = [];
    for (let i = 0; i < CONCURRENT_LIMIT; i++) {
      promises.push(processNext());
    }
    await Promise.all(promises);
    this.show_list = SelectFileUtil.getAllItem(this.encryption ? this.video_meta_data_encryption : this.video_meta_data)
    this.loading = false;
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
    ToolsUtil.showToast(String(item?.title) +
    getContext().resourceManager.getStringSync($r('app.string.re_import_info')))
  }

  async getSafeHeightAndButton() {
    await (await this.windowClass).setWindowLayoutFullScreen(true)
    this.topSafeHeight = px2vp((await this.windowClass).getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM)
      .topRect.height)
    DataSyncUtil.topSafeHeight = this.topSafeHeight
    this.bottomSafeHeight = px2vp((await this.windowClass)
      .getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR).bottomRect.height)
  }

  build() {
    SideBarContainer(SideBarContainerType.Overlay) {
      Column() {
        Row() {
          Button({ type: ButtonType.Circle, stateEffect: true }) {
            SymbolGlyph($r('sys.symbol.open_sidebar'))
              .symbolGlyphFancy(20, '', '')
          }
          .buttonFancy(80, 40)
          .onClick(() => {
            this.closeSideBar(true)
          })
          .shadowFancy()
        }.justifyContent(FlexAlign.Start)

        Column() {
          Stack() {
            Image($r("app.media.Background"))
              .imageFancy(10, '100%', 120)
              .zIndex(1)
            Row() {
              Image($r("app.media.Foreground"))
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
                SymbolGlyph($r('sys.symbol.info_circle')).symbolGlyphFancy(25, '', '')
                Text('关于应用')
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
              ToolsUtil.routerWhereOnlyUri('pages/AboutApp')
            })
          }.margin({ top: '4%' })
        }.margin({ top: '4%' })

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
            await this.toMetaData(SelectFileUtil.getDownloadFilesUri());
          })
        }.width('100%')
        .justifyContent(FlexAlign.Start)
        .margin({ top: '6%' }).visibility(this.encryption ? Visibility.None : Visibility.Visible)

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

        Row() {
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
          .visibility(this.passwd == '' || this.encryption ? Visibility.Visible : Visibility.None)
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
        }.width('100%')
        .justifyContent(FlexAlign.Start)
        .margin({ top: '4%' })
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
      .backgroundColor($r('app.color.start_window_background'))
      .padding({ top: 50, left: 20, right: 20 })
      .transition(TransitionEffect.translate({ x: -300 })
        .animation({ duration: 500 }))
      .visibility(this.sideBarStatusTmp)
      .borderRadius(20)
      .shadowFancy()

      Stack({ alignContent: Alignment.Top }) { // 内容区
        Column()// 遮罩
          .height('100%')
          .width('100%')
          .backgroundBlurStyle(BlurStyle.BACKGROUND_THIN)
          .zIndex(1)
          .visibility(this.sideBarStatus ? Visibility.Visible : Visibility.Hidden)
          .onClick(() => {
            this.closeSideBar(true)
          })
        List({ scroller: this.listScroller }) {
          ForEach(this.list_empty_item, () => {
            ListItem().height(this.topSafeHeight + 55)
          })
          LazyForEach(this.lazy_show_list, (item: string, index: number) => { // 加载视频列表
            ListItem() {
              Column() {
                Row() {
                  Image(fileUri.getUriFromPath(sandbox_path + item))
                    .imageFancy(5, 60, 90)
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
                          .imageFancy(5, 65, 25)
                      } else if (VideoUtil.videoWidthAndHeightFormat(String(SelectFileUtil.getItem(this.encryption ?
                      this.video_meta_data_encryption : this.video_meta_data, item)?.size)).includes('HD')) {
                        Text(VideoUtil.videoWidthAndHeightFormat(String(SelectFileUtil.getItem(this.encryption ?
                        this.video_meta_data_encryption : this.video_meta_data, item)?.size)))
                          .fontSize(10)
                          .fontWeight(FontWeight.Bold)
                          .opacity(0.8)
                          .fontColor($r('sys.color.ohos_dialog_text_alert'))
                          .backgroundColor('#E4BF3E')
                          .padding(5)
                          .borderRadius(5)
                      } else if (VideoUtil.videoWidthAndHeightFormat(String(SelectFileUtil.getItem(this.encryption ?
                      this.video_meta_data_encryption : this.video_meta_data, item)?.size)) === '0 x 0') {
                        Text($r('app.string.unknown_resolution'))
                          .fontSize(10)
                          .fontWeight(FontWeight.Normal)
                          .opacity(0.8)
                          .backgroundColor('#808080')
                          .padding(5)
                          .borderRadius(5)
                      } else {
                        Text(VideoUtil.videoWidthAndHeightFormat(String(SelectFileUtil.getItem(this.encryption ?
                        this.video_meta_data_encryption : this.video_meta_data, item)?.size)))
                          .fontSize(15)
                          .fontWeight(FontWeight.Normal)
                          .opacity(0.8)
                      }
                      Text(' | ' + String(SelectFileUtil.getItem(this.encryption ? this.video_meta_data_encryption :
                      this.video_meta_data, item)?.format) + " | " +
                      TimeUtil.convertMsToMMSS(SelectFileUtil.getItem(this.encryption ?
                      this.video_meta_data_encryption : this.video_meta_data, item)?.time) + " | " +
                      String(SelectFileUtil.getItem(this.encryption ? this.video_meta_data_encryption :
                      this.video_meta_data, item)?.video_size))
                        .fontSize(15)
                        .fontWeight(FontWeight.Normal)
                        .opacity(0.8)
                    }.justifyContent(FlexAlign.Center).padding({ top: 5, })
                  }.alignItems(HorizontalAlign.Start).padding(10).width('90%')
                }.justifyContent(FlexAlign.Center)
              }
              .padding({ left: 10 })
              .height(100)
              .backgroundColor($r('app.color.list_item_background'))
              .borderRadius(10)
              .justifyContent(FlexAlign.SpaceEvenly)
            }
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
              end: this.itemEnd(SelectFileUtil.getItem(this.encryption ? this.video_meta_data_encryption :
              this.video_meta_data, item)),
              edgeEffect: SwipeEdgeEffect.Spring
            })
            .gesture(SwipeGesture({ direction: SwipeDirection.Horizontal }).onAction((event: GestureEvent) => {
              if (event) {
                this.openSideBar()
              }
            }))
            .onClick(() => {
              let item_list = SelectFileUtil.getItem(this.encryption ? this.video_meta_data_encryption :
              this.video_meta_data, item)
              if (this.MenuBuilderState || this.multipleChooseState != Visibility.None) {
                this.MenuBuilderState = false
                return
              }
              this.listScroller.closeAllSwipeActions()
              this.now_playing = item_list
              if (VideoUtil.videoWidthAndHeightFormat(String(item_list?.size)) === '0 x 0') {
                ToolsUtil.showToast(getContext().resourceManager.getStringSync($r('app.string.video_error')))
                ToolsUtil.isFileExist(item_list) ?
                ToolsUtil.routerWhere('pages/FFmpegPlayer', item, this.encryption ? this.video_meta_data_encryption
                  : this.video_meta_data) : this.deleteUnExistFile(item_list)
                return
              }
              ToolsUtil.isFileExist(item_list) ?
              ToolsUtil.routerWhere('pages/Player', item, this.encryption ? this.video_meta_data_encryption
                : this.video_meta_data) : this.deleteUnExistFile(item_list)
            })
          })
          ForEach(this.list_empty_item, () => {
            ListItem().height(50)
          })
        }
        .lanes(this.list_line)
        .animation({ duration: 300, curve: Curve.Smooth })
        .scrollBar(BarState.Off)
        .chainAnimation(true)
        .width('100%')
        .onTouch(() => {
          this.searchController.stopEditing()
        })

        Row() { //顶栏
          Column() {
            Text($r('app.string.nothing')).fontSize(30).fontWeight(FontWeight.Bold)
            Text(this.encryption ? $r('app.string.privacy_space_info') : $r('app.string.open_side_bar_tip'))
              .fontSize(15)
              .fontWeight(FontWeight.Lighter)
              .margin({ top: 20 })
          }.visibility(this.loading ? Visibility.Hidden : Visibility.Visible)
        }.height('100%')
        .visibility(this.show_list.length == 0 ? Visibility.Visible : Visibility.Hidden)
        .animation({ duration: 150, curve: Curve.Ease })

        Column() {
          Row({ space: 15 }) {
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

            Search({
              value: $$this.search_input, //搜索框
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
              .shadowFancy()
              .width(this.multipleChooseState == Visibility.None ? '60%' : '55%')
              .animation({ duration: 300, curve: Curve.Ease })
              .onChange((value: string) => {
                if (value == '' && this.video_meta_data) {
                  this.show_list =
                    SelectFileUtil.getAllItem(this.encryption ? this.video_meta_data_encryption : this.video_meta_data)
                }
              })
              .onSubmit((value: string) => {
                const currentMeta = this.encryption ? this.video_meta_data_encryption : this.video_meta_data;
                if (value == '' && this.video_meta_data) {
                  this.show_list = SelectFileUtil.getAllItem(currentMeta)
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
                this.show_list = SelectFileUtil.getSearchItem(currentMeta, value)
                if (this.show_list.length == 0) {
                  ToolsUtil.showToast(getContext().resourceManager.getStringSync($r('app.string.no_search_result')))
                }
              })
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
        }.padding({ top: this.topSafeHeight }).width('90%')

        Stack() {
          LoadingProgress().width(85).height(85)
        }.width('100%')
        .height('100%')
        .visibility(this.loading ? Visibility.Visible : Visibility.Hidden)
        .animation({ duration: 150, curve: Curve.Sharp })
      }.backgroundColor($r('app.color.start_window_background'))
      .onAreaChange(async (_oldValue: Area, newValue: Area) => {
        this.getSafeHeightAndButton()
        this.list_line = Math.floor(new Number(newValue.width).valueOf() / 500 + 1)
        this.list_empty_item = []
        for (let i = 1; i <= this.list_line; i++) {
          this.list_empty_item.push(i.toString())
        }
      })
      .gesture(SwipeGesture({ direction: SwipeDirection.Horizontal }).onAction((event: GestureEvent) => {
        if (event) {
          this.openSideBar()
        }
      }))
    }
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .onChange((value: boolean) => {
      this.sideBarStatus = value;
    })
    .showSideBar(this.sideBarStatus)
    .showControlButton(false)
    .divider({ strokeWidth: 0 })
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
      Stack().width(10).visibility(this.encryption ? Visibility.Visible : Visibility.None)
      SymbolGlyph($r('sys.symbol.arrow_right_folder_circle'))
        .symbolGlyphFancy(28, 40, 40)
        .onClick(() => {
          SelectFileUtil.copyFile(item, context)
        })
        .visibility(this.encryption ? Visibility.Visible : Visibility.None)
    }.padding(10).justifyContent(FlexAlign.SpaceEvenly)
  }
}