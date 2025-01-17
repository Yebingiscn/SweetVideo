import { fileUri, fileIo as fs, picker } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { router, window } from '@kit.ArkUI';
import { media } from '@kit.MediaKit';
import { BusinessError } from '@kit.BasicServicesKit';
import PreferencesUtil from '../utils/PreferencesUtil';
import DataSyncUtil from '../utils/DataSyncUtil';
import PermissionUtil from '../utils/PermissionUtil';
import DataUtil from '../utils/DataUtil';
import ToolsUtil from '../utils/ToolsUtil';
import { hilog } from '@kit.PerformanceAnalysisKit';
import VideoUtil, { VideoMetadata } from '../utils/VideoUtil';
import TimeUtil from '../utils/TimeUtil';
import { delConfirmDialog } from '../component/DelConfirmDialog';
import { editPasswordDialog } from '../component/EditPasswordDialog';
import { editMetadataDialog } from '../component/EditMetadataDialog';
import ReqPermission from '../utils/ReqPermissionUtil';
import WantProcess from '../utils/WantProcessUtil';
import SelectFileUtil from '../utils/SelectFileUtil';

const context = getContext() as common.UIAbilityContext;
const sandbox_path = getContext().filesDir + '/'
const sandbox_video = getContext().filesDir + '/video/'

@Entry
@Component
struct Index {
  windowClass = window.getLastWindow(context)
  @State topSafeHeight: number = 0;
  @State bottomSafeHeight: number = 0;
  sandbox_path = getContext().filesDir + '/';
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

  @Builder
  MenuBuilder(item: VideoMetadata | undefined) {
    Flex({ direction: FlexDirection.Column, justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center }) {
      Row() {
        SymbolGlyph($r('sys.symbol.trash_fill'))
          .fontSize(20)
          .fontColor([$r('app.color.text_color')])
          .width(25)
          .height(40)
        Text($r('app.string.delete'))
          .fontSize(20)
          .width(100)
          .height(50)
      }
      .padding(10)
      .onClick(() => {
        DataSyncUtil.editing_video = JSON.stringify(item)
        this.delConfirmDialog.open()
      })

      Divider().height(10)
      Row() {
        SymbolGlyph($r('sys.symbol.rename'))
          .fontSize(20)
          .fontColor([$r('app.color.text_color')])
          .width(25)
          .height(40)
        Text($r('app.string.edit'))
          .fontSize(20)
          .width(100)
          .height(50)
      }.padding(10)
      .onClick(() => {
        DataSyncUtil.editing_video = JSON.stringify(item)
        this.editMetadataDialogController.open()
      })
    }.width(100).onAppear(() => {
      ToolsUtil.startVibration()
    })
  }

  @Builder
  SortMenuBuilder() {
    Flex({ direction: FlexDirection.Column, justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center }) {
      Row() {
        SymbolGlyph($r('sys.symbol.textformat'))
          .fontSize(20)
          .fontColor([$r('app.color.text_color')])
          .width(25)
          .height(40)
        Text($r('app.string.sort_by_name'))
          .fontSize(20)
          .width(100)
          .height(50)
      }
      .padding(10)
      .onClick(() => {
        this.show_list =ToolsUtil.compareName(this.show_list,this.encryption,this.video_meta_data_encryption, this.video_meta_data)
        PreferencesUtil.putPreferencesValue('sweet_video', 'video_meta_data', this.video_meta_data);
        PreferencesUtil.putPreferencesValue('sweet_video', 'video_meta_data_encryption',
          this.video_meta_data_encryption)
      })
      Divider().height(10)
      Row() {
        SymbolGlyph($r('sys.symbol.clock'))
          .fontSize(20)
          .fontColor([$r('app.color.text_color')])
          .width(25)
          .height(40)
        Text($r('app.string.sort_by_time'))
          .fontSize(20)
          .width(100)
          .height(50)
      }.padding(10)
      .onClick(() => {
        this.show_list = this.encryption
          ? this.video_meta_data_encryption.sort((a, b) => a.date.localeCompare(b.date)).map(i => i.date)
          : this.video_meta_data.sort((a, b) => a.date.localeCompare(b.date)).map(i => i.date);
        PreferencesUtil.putPreferencesValue('sweet_video', 'video_meta_data', this.video_meta_data);
        PreferencesUtil.putPreferencesValue('sweet_video', 'video_meta_data_encryption',
          this.video_meta_data_encryption)
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
        let index = this.encryption ? this.video_meta_data_encryption.findIndex(i => i.title == tmp.title) :
        this.video_meta_data.findIndex(i => i.title == tmp.title)
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
          this.encryption ? this.video_meta_data_encryption.map(i => i.date) : this.video_meta_data.map(i => i.date)
        PreferencesUtil.putPreferencesValue('sweet_video', 'video_meta_data', this.video_meta_data)
        PreferencesUtil.putPreferencesValue('sweet_video', 'video_meta_data_encryption',
          this.video_meta_data_encryption)
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
        let tmp = JSON.parse(DataSyncUtil.editing_video) as VideoMetadata
        if (this.encryption) {
          this.video_meta_data_encryption = this.video_meta_data_encryption.filter(i => i.date != tmp.date)
          if (fs.accessSync(sandbox_video + tmp.date)) {
            fs.unlinkSync(sandbox_video + tmp.date)
          }
          PreferencesUtil.putPreferencesValue('sweet_video', 'video_meta_data_encryption',
            this.video_meta_data_encryption)
        } else {
          this.video_meta_data = this.video_meta_data.filter(i => i.date != tmp.date)
        }
        this.show_list = this.show_list.filter(i => i != tmp.date)
        if (fs.accessSync(sandbox_path + tmp.date)) {
          fs.unlinkSync(sandbox_path + tmp.date)
        }
        PreferencesUtil.putPreferencesValue('sweet_video', 'video_meta_data', this.video_meta_data)
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
        PreferencesUtil.putPreferencesValue('sweet_video', 'passwd', passwd)
        ToolsUtil.showToast(getContext().resourceManager.getStringSync($r('app.string.set_passwd_tip')))
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
    if (this.encryption) {
      this.show_list = this.video_meta_data_encryption.map(i => i.date)
    } else {
      this.show_list = this.video_meta_data.map(i => i.date)
    }
  }

  async aboutToAppear(): Promise<void> {
    if (WantProcess.want_uri != '') {
      WantProcess.hasWant()
    }
    ReqPermission.reqPermissionsFromUser(ReqPermission.permissions, context);
    this.video_meta_data =
      await PreferencesUtil.getPreferencesValue('sweet_video', 'video_meta_data', []) as VideoMetadata[]
    this.video_meta_data_encryption =
      await PreferencesUtil.getPreferencesValue('sweet_video', 'video_meta_data_encryption', []) as VideoMetadata[]
    this.passwd = await PreferencesUtil.getPreferencesValue('sweet_video', 'passwd', '') as string
    this.show_list = this.video_meta_data.map(i => i.date)
    this.activePermission()
    await (await this.windowClass).setWindowLayoutFullScreen(true)
    this.topSafeHeight = px2vp((await this.windowClass).getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM)
      .topRect.height)
    DataSyncUtil.topSafeHeight = this.topSafeHeight
    this.bottomSafeHeight =
      px2vp((await this.windowClass).getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR)
        .bottomRect.height)
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
    for (let uri of tmp) {
      PermissionUtil.activatePermission(uri)
    }
  }

  async onPageShow() {
    if (this.now_playing) {
      if (this.encryption) {
        this.video_meta_data_encryption[this.video_meta_data_encryption.findIndex(i => i.date ==
          this.now_playing?.date)].last_play = DataSyncUtil.last_time
        PreferencesUtil.putPreferencesValue('sweet_video', 'video_meta_data_encryption',
          this.video_meta_data_encryption)
      } else {
        this.video_meta_data[this.video_meta_data.findIndex(i => i.date == this.now_playing?.date)].last_play =
          DataSyncUtil.last_time
        PreferencesUtil.putPreferencesValue('sweet_video', 'video_meta_data', this.video_meta_data)
      }
    }
  }

  // 持久化视频存储
  async toMetaData(list: string[]) {
    const CONCURRENT_LIMIT = 3; // 最大并发数
    let index = 0; // 当前处理的文件索引
    this.loading = true;
    if (list.length != 0) {
      ToolsUtil.showToast(getContext().resourceManager.getStringSync($r('app.string.add_time_info')))
    }
    const processFile = async (uri: string) => {
      ReqPermission.persistPermission(uri);
      const avMetadataExtractor: media.AVMetadataExtractor = await media.createAVMetadataExtractor();
      const file = fs.openSync(uri);
      avMetadataExtractor.fdSrc = file;
      const metadata = await new Promise<media.AVMetadata>((resolve, reject) => {
        avMetadataExtractor.fetchMetadata((error: BusinessError, metadata: media.AVMetadata) => {
          if (error) {
            reject(error);
          } else {
            resolve(metadata);
          }
        });
      });
      const date = new Date().getTime().toString();
      if ((!this.encryption && !this.video_meta_data.some(item => item.title === file.name)) ||
        (this.encryption && !this.video_meta_data_encryption.some(item => item.title === file.name))) {
        if (this.encryption) {
          const file1 = fs.openSync(uri, fs.OpenMode.READ_ONLY);
          const file2 = fs.openSync(sandbox_video + date, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
          fs.copyFile(file1.fd, file2.fd, async () => {
            this.video_meta_data_encryption.push(await VideoUtil.setVideoInfo(date, uri, file.name, metadata,
              this.encryption, sandbox_video, sandbox_path)); // Go ahead and change this to await
            PreferencesUtil.putPreferencesValue('sweet_video', 'video_meta_data_encryption',
              this.video_meta_data_encryption);
            fs.closeSync(file1);
            fs.closeSync(file2);
            this.show_list = this.video_meta_data_encryption.map(i => i.date);
          });
        } else {
          this.video_meta_data.push(await VideoUtil.setVideoInfo(date, uri, file.name, metadata, this.encryption,
            sandbox_video, sandbox_path)); // Use await here
          PreferencesUtil.putPreferencesValue('sweet_video', 'video_meta_data', this.video_meta_data);
        }
      }
    };
    const processNext = async () => {
      while (index < list.length) {
        const uri = list[index++];
        await processFile(uri);
      }
    };
    // 启动并发处理
    const promises: Promise<void>[] = [];
    for (let i = 0; i < CONCURRENT_LIMIT; i++) {
      promises.push(processNext());
    }
    await Promise.all(promises);
    this.show_list =
      this.encryption ? this.video_meta_data_encryption.map(i => i.date) : this.video_meta_data.map(i => i.date);
    this.loading = false;
  }

  build() {
    SideBarContainer(SideBarContainerType.Overlay) {
      Column() {
        Row() {
          Button({ type: ButtonType.Circle, stateEffect: true }) {
            SymbolGlyph($r('sys.symbol.open_sidebar'))
              .fontSize(20)
              .fontColor([$r('app.color.text_color')])
          }
          .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
          .height(40)
          .width(80)
          .backgroundColor($r('app.color.start_window_background_blur'))
          .backdropBlur(150)
          .onClick(() => {
            this.sideBarStatusTmp = Visibility.Hidden
            setTimeout(() => {
              this.sideBarStatus = false
            }, 500)
          })
          .shadow({
            radius: 15,
            color: $r('app.color.shadow_color'),
            offsetX: 0,
            offsetY: 0
          })
        }.justifyContent(FlexAlign.Start)

        Column() {
          Stack() {
            Image($r("app.media.background"))
              .backgroundImageSize(ImageSize.Cover)
              .borderRadius(10)
              .width('100%')
              .height('17%')
              .zIndex(1)
            Row() {
              Image($r("app.media.foreground"))
                .backgroundImageSize(ImageSize.Cover)
                .width(40)
                .height(40)
              Text($r('app.string.EntryAbility_label'))
                .fontSize(20)
                .fontColor('#ffff')
                .margin({ left: 5, right: 12 })
            }.width('100%')
            .justifyContent(FlexAlign.Center)
            .zIndex(2)
          }
        }.margin({ top: '4%' })

        Divider().height(10).margin({ top: '5%' })
        Row() {
          Button({ type: ButtonType.Normal, stateEffect: true }) {
            Row() {
              SymbolGlyph($r('sys.symbol.folder')).fontSize(25).fontColor([$r('app.color.text_color')])
              Text($r('app.string.import_from_files'))
                .fontSize(15)
                .fontColor($r('app.color.text_color'))
                .margin({ left: 10, right: 12 })
            }
          }
          .align(Alignment.Start)
          .padding(10)
          .borderRadius(10)
          .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
          .height('11%')
          .width('100%')
          .backgroundColor($r('app.color.start_window_background_blur'))
          .backdropBlur(150)
          .transition(TransitionEffect.OPACITY.animation({ duration: 500 })
            .combine(TransitionEffect.translate({ x: 100 })))
          .onClick(() => {
            this.sideBarStatus = false
            this.sideBarStatusTmp = Visibility.Hidden
            this.selectFiles()
          })
        }.width('100%')
        .justifyContent(FlexAlign.Start)
        .margin({ top: '6%' })

        Row() {
          Button({ type: ButtonType.Normal, stateEffect: true }) {
            Row() {
              SymbolGlyph($r('sys.symbol.video'))
                .fontSize(25)
                .fontColor([$r('app.color.text_color')])
              Text($r('app.string.import_from_album'))
                .fontSize(15)
                .fontColor($r('app.color.text_color'))
                .margin({ left: 10, right: 12 })
            }
          }
          .backgroundColor($r('app.color.start_window_background_blur'))
          .align(Alignment.Start)
          .padding(10)
          .borderRadius(10)
          .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
          .height('11%')
          .width('100%')
          .backdropBlur(150)
          .onClick(() => {
            this.sideBarStatus = false
            this.sideBarStatusTmp = Visibility.Hidden
            this.selectVideo()
          })
        }.width('100%')
        .justifyContent(FlexAlign.Start)
        .margin({ top: '4%' })

        Row() {
          Button({ type: ButtonType.Normal, stateEffect: true }) {
            Row() {
              SymbolGlyph($r('sys.symbol.lock'))
                .fontSize(25)
                .fontColor([$r('app.color.text_color')])
              Text($r('app.string.privacy_space'))
                .fontSize(15)
                .fontColor($r('app.color.text_color'))
                .margin({ left: 10, right: 12 })
            }
          }
          .visibility(this.passwd == '' || this.encryption ? Visibility.Visible : Visibility.None)
          .backgroundColor($r('app.color.start_window_background_blur'))
          .align(Alignment.Start)
          .padding(10)
          .borderRadius(10)
          .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
          .height('11%')
          .width('100%')
          .backdropBlur(150)
          .onClick(() => {
            this.sideBarStatus = false
            this.sideBarStatusTmp = Visibility.Hidden
            if (this.passwd == '') {
              this.editPasswdDialogController.open()
              return
            }
            this.encryption = false
          })
          .gesture(LongPressGesture().onAction(() => {
            this.sideBarStatus = false
            this.sideBarStatusTmp = Visibility.Hidden
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
      .transition(TransitionEffect.OPACITY.animation({ duration: 500 })
        .combine(TransitionEffect.translate({ x: -100 })))
      .visibility(this.sideBarStatusTmp)
      .gesture(
        SwipeGesture({ direction: SwipeDirection.Horizontal })
          .onAction((event: GestureEvent) => {
            if (event) {
              this.sideBarStatusTmp = Visibility.Hidden
              setTimeout(() => {
                this.sideBarStatus = false
              }, 500)
            }
          }))
      .borderRadius(20)
      .shadow({
        radius: 15,
        color: $r('app.color.shadow_color'),
        offsetX: 0,
        offsetY: 0
      })

      // 内容区
      Stack({ alignContent: Alignment.Top }) {
        // 遮罩
        Column()
          .height('100%')
          .width('100%')
          .backgroundBlurStyle(BlurStyle.BACKGROUND_THIN)
          .zIndex(1)
          .visibility(this.sideBarStatus ? Visibility.Visible : Visibility.Hidden)
          .onClick(() => {
            this.sideBarStatusTmp = Visibility.Hidden
            setTimeout(() => {
              this.sideBarStatus = false
            }, 500)
          })
        List({ scroller: this.listScroller }) {
          ForEach(this.list_empty_item, () => {
            ListItem().height(this.topSafeHeight + 55)
          })
          // 加载视频列表
          LazyForEach(this.lazy_show_list, (item: string) => {
            ListItem() {
              Column() {
                Row() {
                  Image(fileUri.getUriFromPath(sandbox_path + item))
                    .width(70)
                    .height(70)
                    .backgroundImageSize(ImageSize.Cover)
                    .borderRadius(5)
                    .sourceSize({
                      width: 70,
                      height: 70
                    })
                  Column() {
                    Text((String(this.encryption ?
                      this.video_meta_data_encryption.find(i => i.date == item)?.title :
                      this.video_meta_data.find(i => i.date == item)?.title)
                    ).slice(0, String(this.encryption ?
                      this.video_meta_data_encryption.find(i => i.date == item)?.title :
                      this.video_meta_data.find(i => i.date == item)?.title).lastIndexOf('.')))
                      .fontSize(20)
                      .fontWeight(FontWeight.Medium)
                      .maxLines(2)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .width('90%')
                    Row() {
                      if ((this.encryption ?
                        this.video_meta_data_encryption.find(i => i.date == item)?.hdr_type :
                        this.video_meta_data.find(i => i.date == item)?.hdr_type) ===
                      media.HdrType.AV_HDR_TYPE_VIVID) {
                        Image($r("app.media.hdr_vivid_icon"))
                          .backgroundImageSize(ImageSize.Cover)
                          .borderRadius(5)
                          .width('20%')
                          .height('35%')
                      } else if (VideoUtil.videoSizeFormat(String(this.encryption ?
                        this.video_meta_data_encryption.find(i => i.date == item)?.size :
                        this.video_meta_data.find(i => i.date == item)?.size))
                        .includes('HD')) {
                        Text(VideoUtil.videoSizeFormat(String(this.encryption ?
                          this.video_meta_data_encryption.find(i => i.date == item)?.size :
                          this.video_meta_data.find(i => i.date == item)?.size)))
                          .fontSize(10)
                          .fontWeight(FontWeight.Bold)
                          .opacity(0.8)
                          .fontColor($r('sys.color.ohos_dialog_text_alert'))
                          .backgroundColor('#E4BF3E')
                          .padding(5)
                          .borderRadius(5)
                      } else if (VideoUtil.videoSizeFormat(String(this.encryption ?
                        this.video_meta_data_encryption.find(i => i.date == item)?.size :
                        this.video_meta_data.find(i => i.date == item)?.size)) === '0 x 0') {
                        Text($r('app.string.unknown_resolution'))
                          .fontSize(10)
                          .fontWeight(FontWeight.Normal)
                          .opacity(0.8)
                          .backgroundColor('#808080')
                          .padding(5)
                          .borderRadius(5)
                      } else {
                        Text(VideoUtil.videoSizeFormat(String(this.encryption ?
                          this.video_meta_data_encryption.find(i => i.date == item)?.size :
                          this.video_meta_data.find(i => i.date == item)?.size)))
                          .fontSize(15)
                          .fontWeight(FontWeight.Normal)
                          .opacity(0.8)
                      }
                      Text(' | ' + String(this.encryption ?
                        this.video_meta_data_encryption.find(i => i.date == item)?.format :
                        this.video_meta_data.find(i => i.date == item)?.format) + " | " +
                      TimeUtil.convertMsToMMSS(this.encryption ?
                        this.video_meta_data_encryption.find(i => i.date == item)?.time :
                        this.video_meta_data.find(i => i.date == item)?.time) + " | " +
                      String(this.encryption ?
                        this.video_meta_data_encryption.find(i => i.date == item)?.video_size :
                        this.video_meta_data.find(i => i.date == item)?.video_size))
                        .fontSize(15)
                        .fontWeight(FontWeight.Normal)
                        .opacity(0.8)
                    }.justifyContent(FlexAlign.Center).padding({
                      top: 5,
                    })
                  }.alignItems(HorizontalAlign.Start).padding(10).width('90%')
                }.justifyContent(FlexAlign.Center)
              }
              .padding({
                left: 10
              })
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
            .bindContextMenu(this.MenuBuilder(this.encryption ?
            this.video_meta_data_encryption.find(i => i.date == item) :
            this.video_meta_data.find(i => i.date == item)), ResponseType.LongPress)
            .swipeAction({
              end: this.itemEnd(this.encryption ? this.video_meta_data_encryption.find(i => i.date == item) :
              this.video_meta_data.find(i => i.date == item)),
              edgeEffect: SwipeEdgeEffect.Spring
            })
            .onClick(() => {
              this.listScroller.closeAllSwipeActions()
              this.now_playing = this.encryption ? this.video_meta_data_encryption.find(i => i.date == item) :
              this.video_meta_data.find(i => i.date == item)
              if (VideoUtil.videoSizeFormat(String(this.encryption ?
                this.video_meta_data_encryption.find(i => i.date == item)?.size :
                this.video_meta_data.find(i => i.date == item)?.size)) === '0 x 0') {
                ToolsUtil.showToast(getContext().resourceManager.getStringSync($r('app.string.video_error')))
              }
              router.pushUrl({
                url: 'pages/Player',
                params: {
                  metadata: JSON.stringify(this.encryption ?
                  this.video_meta_data_encryption.find(i => i.date == item) :
                  this.video_meta_data.find(i => i.date == item))
                }
              }, router.RouterMode.Standard, (err) => {
                hilog.info(0xFF00, "testTag", String(err));
              });
            })
          })
          ForEach(this.list_empty_item, () => {
            ListItem().height(50)
          })
        }
        .layoutWeight('100%')
        .edgeEffect(EdgeEffect.Spring) // 边缘效果设置为Spring
        .lanes(this.list_line)
        .animation({ duration: 300, curve: Curve.Smooth })
        .scrollBar(BarState.Auto)
        .chainAnimation(true)
        .width('100%')
        .onTouch(() => {
          this.searchController.stopEditing()
        })

        //顶栏
        Row() {
          Column() {
            Text($r('app.string.nothing')).fontSize(30).fontWeight(FontWeight.Bold)
            Text($r('app.string.open_side_bar_tip')).fontSize(15).fontWeight(FontWeight.Lighter).margin({ top: 20 })
          }.visibility(this.loading ? Visibility.Hidden : Visibility.Visible)
        }
        .height('100%')
        .visibility(this.show_list.length == 0 ? Visibility.Visible : Visibility.Hidden)
        .animation({ duration: 150, curve: Curve.Ease })

        Column() {
          Row({ space: 15 }) {
            Button({ type: ButtonType.Circle, stateEffect: true }) {
              SymbolGlyph($r('sys.symbol.close_sidebar'))
                .fontSize(25)
                .fontColor([$r('app.color.text_color')])
            }
            .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
            .height(40)
            .width(40)
            .backgroundColor($r('app.color.start_window_background_blur'))
            .backdropBlur(150)
            .onClick(() => {
              this.sideBarStatusTmp = Visibility.Visible
              this.sideBarStatus = true
            })
            .shadow({
              radius: 15,
              color: $r('app.color.shadow_color'),
              offsetX: 0,
              offsetY: 0
            })

            //搜索框
            Search({
              value: $$this.search_input,
              controller: this.searchController,
              placeholder: $r('app.string.search_placeholder')
            })
              .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
              .backgroundColor($r('app.color.start_window_background_blur'))
              .backdropBlur(150)
              .searchButton(getContext(this).resourceManager.getStringSync($r('app.string.search')),
                { fontSize: '16fp', fontColor: $r('app.color.main_color') })

              .shadow({
                radius: 15,
                color: $r('app.color.shadow_color'),
                offsetX: 0,
                offsetY: 0
              })
              .width('60%')
              .animation({ duration: 300, curve: Curve.Ease })
              .onChange((value: string) => {
                if (value == '' && this.video_meta_data) {
                  this.show_list =
                    this.encryption ? this.video_meta_data_encryption.map(i => i.date) :
                    this.video_meta_data.map(i => i.date)
                }
              })
              .onSubmit((value: string) => {
                if (value == '' && this.video_meta_data) {
                  this.show_list = this.encryption ? this.video_meta_data_encryption.map(i => i.date) :
                  this.video_meta_data.map(i => i.date)
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
                    .getStringSync($r('app.string.entered_privacy_space')))
                  return
                }
                try {
                  this.show_list =
                    this.encryption ?
                    this.video_meta_data_encryption.filter(i => i.title.toLowerCase().includes(value.toLowerCase()))
                      .map(i => i.date) :
                    this.video_meta_data.filter(i => i.title.toLowerCase().includes(value.toLowerCase()))
                      .map(i => i.date)
                  if (this.show_list.length == 0) {
                    ToolsUtil.showToast(getContext().resourceManager.getStringSync($r('app.string.no_search_result')))
                  }
                } catch (err) {
                  hilog.error(0xFF00, "testTag", "search fail:" + err)
                }
              })
              .height(40)
            Button({ type: ButtonType.Circle, stateEffect: true }) {
              SymbolGlyph($r('sys.symbol.text_and_arrow_down'))
                .fontSize(25)
                .fontColor([$r('app.color.text_color')])
            }
            .animation({ duration: 300, curve: Curve.Ease })
            .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
            .height(40)
            .width(40)
            .backgroundColor($r('app.color.start_window_background_blur'))
            .backdropBlur(150)
            .bindMenu(this.SortMenuBuilder)
            .shadow({
              radius: 15,
              color: $r('app.color.shadow_color'),
              offsetX: 0,
              offsetY: 0
            })
          }
        }.padding({ top: this.topSafeHeight }).width('100%')

        Stack() {
          LoadingProgress().width(85).height(85)
        }
        .width('100%')
        .height('100%')
        .visibility(this.loading ? Visibility.Visible : Visibility.Hidden)
        .animation({ duration: 150, curve: Curve.Sharp })
      }
      .backgroundColor($r('app.color.start_window_background'))
      .onAreaChange((_oldValue: Area, newValue: Area) => {
        this.list_line = Math.floor(new Number(newValue.width).valueOf() / 500 + 1)
        this.list_empty_item = []
        for (let i = 1; i <= this.list_line; i++) {
          this.list_empty_item.push(i.toString())
        }
      })
      .gesture(
        SwipeGesture({ direction: SwipeDirection.Horizontal })
          .onAction((event: GestureEvent) => {
            if (event) {
              this.sideBarStatusTmp = Visibility.Visible
              this.sideBarStatus = true
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
        .fontSize(28)
        .fontColor([$r('app.color.text_color')])
        .width(40)
        .height(40)
        .onClick(() => {
          this.listScroller.closeAllSwipeActions()
          DataSyncUtil.editing_video = JSON.stringify(item)
          this.delConfirmDialog.open()
        })
      Stack().width(10)
      SymbolGlyph($r('sys.symbol.rename'))
        .fontSize(28)
        .fontColor([$r('app.color.text_color')])
        .width(40)
        .height(40)
        .onClick(() => {
          this.listScroller.closeAllSwipeActions()
          DataSyncUtil.editing_video = JSON.stringify(item)
          this.editMetadataDialogController.open()
        })
      Stack().width(10).visibility(this.encryption ? Visibility.Visible : Visibility.None)
      SymbolGlyph($r('sys.symbol.arrow_right_folder_circle'))
        .fontSize(28)
        .fontColor([$r('app.color.text_color')])
        .width(40)
        .height(40)
        .onClick(() => {
          let file = fs.openSync(item.uri)
          let saverOption = new picker.DocumentSaveOptions()
          saverOption.newFileNames =
            [item.title.split('.')[item.title.split('.').length - 1] == item.format ? item.title :
              item.title + '.' + item.format]
          let saver = new picker.DocumentViewPicker(context)
          saver.save(saverOption, (err: BusinessError, documentSaveResult: string[]) => {
            if (!err) {
              let file1 = fs.openSync(documentSaveResult[0], fs.OpenMode.READ_WRITE)
              fs.copyFileSync(file.fd, file1.fd)
              fs.close(file.fd)
              fs.close(file1.fd)
            }
          })
        })
        .visibility(this.encryption ? Visibility.Visible : Visibility.None)
    }.padding(10).justifyContent(FlexAlign.SpaceEvenly)
  }
}