import { fileShare, fileUri, fileIo as fs, picker } from '@kit.CoreFileKit';
import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { router, window } from '@kit.ArkUI';
import { media } from '@kit.MediaKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { image } from '@kit.ImageKit';
import PreferencesUtil from '../utils/PreferencesUtil';
import DataSyncUtil from '../utils/DataSyncUtil';
import PermissionUtil from '../utils/PermissionUtil';
import DataUtil from '../utils/DataUtil';
import ToolsUtil from '../utils/ToolsUtil';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import VideoUtil from '../utils/VideoUtil';
import TimeUtil from '../utils/TimeUtil';

interface VideoMetadata {
  uri: string
  title: string
  date: string
  size: number[]
  time: number
  last_play: number
  format: string
  video_size: string
  hdr_type: string
}

const permissions: Permissions[] = ['ohos.permission.FILE_ACCESS_PERSIST', 'ohos.permission.VIBRATE'];
const context = getContext() as common.UIAbilityContext;
const sandbox_path = getContext().filesDir + '/'
const sandbox_video = getContext().filesDir + '/video/'

// 重新
function reqPermissionsFromUser(permissions: Permissions[], context: common.UIAbilityContext): void {
  let atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
  atManager.requestPermissionsFromUser(context, permissions).then((data) => {
    let grantStatus: number[] = data.authResults;
    let length: number = grantStatus.length;
    for (let i = 0; i < length; i++) {
      if (grantStatus[i] === 0) {
      } else {
        return;
      }
    }
  })
}

async function persistPermission(uri: string): Promise<boolean> {
  try {
    let policyInfo: fileShare.PolicyInfo = {
      uri: uri,
      operationMode: fileShare.OperationMode.READ_MODE | fileShare.OperationMode.WRITE_MODE,
    };
    let policies: Array<fileShare.PolicyInfo> = [policyInfo];
    fileShare.persistPermission(policies).then(() => {
    }).catch((err: BusinessError<Array<fileShare.PolicyErrorResult>>) => {
      hilog.info(0xFF00, "testTag", String(err));
    });
    let fd = await fs.open(uri);
    await fs.close(fd);
  } catch (error) {
    return true
  }
  return false
}

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
      this.show_list =
        this.video_meta_data.map(i => i.date)
    }
  }

  async aboutToAppear(): Promise<void> {
    reqPermissionsFromUser(permissions, context);
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
    const documentSelectOptions = new picker.DocumentSelectOptions();
    documentSelectOptions.fileSuffixFilters = ['mp4', 'flv', 'mkv', 'ts', 'mov'];
    let context = getContext(this) as common.Context;
    const documentViewPicker = new picker.DocumentViewPicker(context);
    documentViewPicker.select(documentSelectOptions).then(async (documentSelectResult: Array<string>) => {
      if (documentSelectResult.length > 0) {
        this.toMetadata(documentSelectResult)
      }
    });
  }

  async selectVideo() {
    const photoSelectOptions = new photoAccessHelper.PhotoSelectOptions
    photoSelectOptions.MIMEType = photoAccessHelper.PhotoViewMIMETypes.VIDEO_TYPE
    const photoViewPicker = new photoAccessHelper.PhotoViewPicker();
    photoViewPicker.select(photoSelectOptions).then((photoSelectResult: photoAccessHelper.PhotoSelectResult) => {
      if (photoSelectResult.photoUris.length > 0) {
        this.toMetadata(photoSelectResult.photoUris)
      }
    });
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
  async toMetadata(list: string[]) {
    for (let uri of list) {
      persistPermission(uri)
      let avMetadataExtractor: media.AVMetadataExtractor = await media.createAVMetadataExtractor()
      let file = fs.openSync(uri)
      avMetadataExtractor.fdSrc = file
      avMetadataExtractor.fetchMetadata(async (_error: BusinessError, metadata: media.AVMetadata) => {
        let date = new Date().getTime().toString()
        if (this.video_meta_data || this.video_meta_data_encryption) {
          if ((!this.encryption && !this.video_meta_data.some(item => item.title === file.name)) ||
            (this.encryption && !this.video_meta_data_encryption.some(item => item.title === file.name))) {
            if (this.encryption) {
              let file1 = fs.openSync(uri, fs.OpenMode.READ_ONLY)
              let file2 = fs.openSync(sandbox_video + date, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE)
              this.loading = true
              fs.copyFile(file1.fd, file2.fd).then(async () => {
                this.video_meta_data_encryption.push(await this.setVideoInfo(date, uri, file.name, metadata))
                PreferencesUtil.putPreferencesValue('sweet_video', 'video_meta_data_encryption',
                  this.video_meta_data_encryption)
                fs.closeSync(file1)
                fs.closeSync(file2)
                this.show_list =
                  this.encryption ? this.video_meta_data_encryption.map(i => i.date) :
                  this.video_meta_data.map(i => i.date)
                this.loading = false
              })
            } else {
              this.video_meta_data.push(await this.setVideoInfo(date, uri, file.name, metadata))
              PreferencesUtil.putPreferencesValue('sweet_video', 'video_meta_data', this.video_meta_data)
            }
          }
        } else {
          //初始化video_meta_data 和 video_meta_data_encryption
          this.video_meta_data = []
          this.video_meta_data_encryption = []
          this.video_meta_data.push(await this.setVideoInfo(date, uri, file.name, metadata))
          PreferencesUtil.putPreferencesValue('sweet_video', 'video_meta_data', this.video_meta_data)
        }
      });
    }
    setTimeout(() => this.show_list =
      this.encryption ? this.video_meta_data_encryption.map(i => i.date) : this.video_meta_data.map(i => i.date), 500)
  }

  // 设置存储的视频信息
  async setVideoInfo(date: string, uri: string, file_name: string, metadata: media.AVMetadata) {
    let tmp: VideoMetadata = {
      uri: this.encryption ? sandbox_video + date : uri,
      title: file_name,
      date: date,
      size: [parseInt((metadata.videoOrientation == '90' || metadata.videoOrientation == '270' ?
      metadata.videoHeight : metadata.videoWidth) || '0'),
        parseInt((metadata.videoOrientation == '90' || metadata.videoOrientation == '270' ? metadata.videoWidth :
        metadata.videoHeight) || '0')],
      time: parseInt(metadata.duration || '0'),
      last_play: 0,
      format: file_name.split('.')[file_name.split('.').length - 1],
      video_size: await VideoUtil.getVideoSize(this.encryption ? sandbox_video + date : uri),
      hdr_type: metadata.hdrType ? 'HDR Vivid' : ''
    }
    this.testFetchFrameByTime(uri, tmp.size, date)
    return tmp
  }

  async testFetchFrameByTime(uri: string, size: number[], date: string) {
    let avImageGenerator: media.AVImageGenerator = await media.createAVImageGenerator()
    let file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
    let avFileDescriptor: media.AVFileDescriptor = { fd: file.fd };
    avImageGenerator.fdSrc = avFileDescriptor;
    let timeUs = 0
    let queryOption = media.AVImageQueryOptions.AV_IMAGE_QUERY_NEXT_SYNC
    let param: media.PixelMapParams = {
      width: size[0],
      height: size[1],
    }
    avImageGenerator.fetchFrameByTime(timeUs, queryOption, param).then((pixelMap: PixelMap) => {
      let packer = image.createImagePacker()
      let file1 = fs.openSync(sandbox_path + date, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE)
      packer.packToFile(pixelMap, file1.fd, { format: 'image/jpeg', quality: 100 }).then(() => {
        fs.closeSync(file1)
      }).catch()
      avImageGenerator.release()
      fs.closeSync(file);
    })
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
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
                    this.video_meta_data.find(i => i.date == item)?.title)).split('.')[0])
                    .fontSize(20)
                    .fontWeight(FontWeight.Medium)
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .width('90%')
                  Row() {
                    if (String(this.encryption ?
                      this.video_meta_data_encryption.find(i => i.date == item)?.hdr_type :
                      this.video_meta_data.find(i => i.date == item)?.hdr_type) != '') {
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
          .swipeAction({
            end: this.itemEnd(this.encryption ? this.video_meta_data_encryption.find(i => i.date == item) :
            this.video_meta_data.find(i => i.date == item)),
            edgeEffect: SwipeEdgeEffect.Spring
          })
          .onClick(() => {
            this.listScroller.closeAllSwipeActions()
            this.now_playing = this.encryption ? this.video_meta_data_encryption.find(i => i.date == item) :
            this.video_meta_data.find(i => i.date == item)
            router.pushUrl({
              url: 'pages/Player',
              params: {
                metadata: JSON.stringify(this.encryption ? this.video_meta_data_encryption.find(i => i.date == item) :
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
        Text($r('app.string.nothing')).fontSize(25).fontWeight(FontWeight.Bold)
      }
      .height('100%')
      .visibility(this.show_list.length == 0 ? Visibility.Visible : Visibility.Hidden)
      .animation({ duration: 150, curve: Curve.Ease })

      Column() {
        Row({ space: 15 }) {
          Button({ type: ButtonType.Circle, stateEffect: true }) {
            SymbolGlyph($r('sys.symbol.folder'))
              .fontSize(25)
              .fontColor([$r('app.color.text_color')])
          }
          .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
          .height(40)
          .width(40)
          .backgroundColor($r('app.color.start_window_background_blur'))
          .backdropBlur(150)
          .onClick(() => {
            this.selectFiles()
          })
          .shadow({
            radius: 15,
            color: $r('app.color.shadow_color'),
            offsetX: 0,
            offsetY: 0
          })

          Button({ type: ButtonType.Circle, stateEffect: true }) {
            SymbolGlyph($r('sys.symbol.video'))
              .fontSize(25)
              .fontColor([$r('app.color.text_color')])
          }
          .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
          .height(40)
          .width(40)
          .backgroundColor($r('app.color.start_window_background_blur'))
          .backdropBlur(150)
          .onClick(() => {
            this.selectVideo()
          })
          .shadow({
            radius: 15,
            color: $r('app.color.shadow_color'),
            offsetX: 0,
            offsetY: 0
          })

          //搜索框
          Search({ value: $$this.search_input, controller: this.searchController })
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
            .width(this.passwd == '' || this.encryption ? '55%' : '70%')
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
                ToolsUtil.showToast(getContext().resourceManager.getStringSync($r('app.string.entered_privacy_space')))
                return
              }
              try {
                this.show_list =
                  this.encryption ?
                  this.video_meta_data_encryption.filter(i => i.title.includes(value)).map(i => i.date) :
                  this.video_meta_data.filter(i => i.title.includes(value)).map(i => i.date)
                if (this.show_list.length == 0) {
                  ToolsUtil.showToast(getContext().resourceManager.getStringSync($r('app.string.no_search_result')))
                }
              } catch (err) {
                hilog.error(0xFF00, "testTag", "search fail:" + err)
              }
            })
            .height(40)
          //加密按钮
          Button({ type: ButtonType.Circle, stateEffect: true }) {
            SymbolGlyph($r('sys.symbol.lock'))
              .fontSize(25)
              .fontColor([$r('app.color.text_color')])
          }
          .visibility(this.passwd == '' || this.encryption ? Visibility.Visible : Visibility.None)
          .animation({ duration: 300, curve: Curve.Ease })
          .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
          .height(40)
          .width(40)
          .backgroundColor($r('app.color.start_window_background_blur'))
          .backdropBlur(150)
          .onClick(() => {
            if (this.passwd == '') {
              this.editPasswdDialogController.open()
              return
            }
            this.encryption = false
          })
          .gesture(LongPressGesture().onAction(() => {
            this.editPasswdDialogController.open()
          }))
          .shadow({
            radius: 15,
            color: $r('app.color.shadow_color'),
            offsetX: 0,
            offsetY: 0
          })
        }
      }.padding({ top: this.topSafeHeight }).width('100%')

      Stack() {
        LoadingProgress().width(100).height(100)
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
    // 拓展安全区
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
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

@CustomDialog
struct editMetadataDialog { //编辑元数据弹窗
  confirm?: (name: string | undefined) => void
  controller?: CustomDialogController
  name: string | undefined = undefined

  aboutToAppear(): void {
    let tmp = JSON.parse(DataSyncUtil.editing_video) as VideoMetadata
    this.name = tmp.title
  }

  build() {
    Column({ space: 25 }) {
      Text($r('app.string.rename'))
        .fontSize(25)
        .fontColor($r('app.color.text_color'))
        .fontWeight(FontWeight.Bold)
        .margin({ top: 10 })
      TextInput({ text: this.name?.split('.')[0] })
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
        .onChange((input: string) => this.name = input + "." + this.name?.split('.')[1])
      Flex({ justifyContent: FlexAlign.SpaceAround }) {
        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Row({ space: 5 }) {
            SymbolGlyph($r('sys.symbol.xmark')).fontSize(18).fontColor([$r('app.color.text_color')])
            Text($r('app.string.cancel'))
              .fontSize(18)
              .fontColor($r('app.color.text_color'))
              .fontWeight(FontWeight.Medium)
          }.alignItems(VerticalAlign.Center).padding({ left: 12, right: 12 })
        }
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
        .backgroundColor('#00000000')
        .borderRadius(8)
        .height(40)
        .onClick(() => this.controller?.close())

        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Row({ space: 5 }) {
            SymbolGlyph($r('sys.symbol.checkmark')).fontSize(18).fontColor([$r('app.color.text_color')])
            Text($r('app.string.sure')).fontSize(18).fontColor($r('app.color.text_color')).fontWeight(FontWeight.Medium)
          }.alignItems(VerticalAlign.Center).padding({ left: 12, right: 12 })
        }
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
        .backgroundColor('#00000000')
        .borderRadius(8)
        .height(40)
        .onClick(() => {
          this.controller?.close()
          if (this.confirm && ToolsUtil.hasMultipleDots(this.name)) {
            this.confirm(this.name)
          } else {
            ToolsUtil.showToast(getContext().resourceManager.getStringSync($r('app.string.illegal_input')))
          }
        })
      }.margin({ bottom: 10 })
    }.padding(20)
  }
}

@CustomDialog
struct editPasswordDialog { //编辑元数据弹窗
  confirm?: (name: string | undefined) => void
  controller?: CustomDialogController
  passwd: string | undefined = undefined
  @State passwordState: boolean = false

  build() {
    Column({ space: 25 }) {
      Text($r('app.string.set_passwd'))
        .fontSize(25)
        .fontColor($r('app.color.text_color'))
        .fontWeight(FontWeight.Bold)
        .margin({ top: 10 })
      TextInput()
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
        .onChange((input: string) => this.passwd = input)
        .showPassword(this.passwordState)
        .type(InputType.Password)
        .showPasswordIcon(true)
        .onSecurityStateChange((isShowPassword: boolean) => {
          this.passwordState = isShowPassword
        })
        .id('input_pwd')
        .onAppear(() => {
          focusControl.requestFocus('input_pwd')
        })

      Flex({ justifyContent: FlexAlign.SpaceAround }) {
        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Row({ space: 5 }) {
            SymbolGlyph($r('sys.symbol.xmark')).fontSize(18).fontColor([$r('app.color.text_color')])
            Text($r('app.string.cancel'))
              .fontSize(18)
              .fontColor($r('app.color.text_color'))
              .fontWeight(FontWeight.Medium)
          }.alignItems(VerticalAlign.Center).padding({ left: 12, right: 12 })
        }
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
        .backgroundColor('#00000000')
        .borderRadius(8)
        .height(40)
        .onClick(() => this.controller?.close())

        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Row({ space: 5 }) {
            SymbolGlyph($r('sys.symbol.checkmark')).fontSize(18).fontColor([$r('app.color.text_color')])
            Text($r('app.string.sure')).fontSize(18).fontColor($r('app.color.text_color')).fontWeight(FontWeight.Medium)
          }.alignItems(VerticalAlign.Center).padding({ left: 12, right: 12 })
        }
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
        .backgroundColor('#00000000')
        .borderRadius(8)
        .height(40)
        .onClick(() => {
          this.controller?.close()
          if (this.confirm) {
            this.confirm(this.passwd)
          }
        })
      }.margin({ bottom: 10 })
    }.padding(20)
  }
}

@CustomDialog
struct delConfirmDialog { //删除确认弹窗
  confirm?: (confirm_del: boolean | undefined) => void
  controller?: CustomDialogController

  build() {
    Column({ space: 25 }) {
      Text($r('app.string.del_confirm'))
        .fontSize(25)
        .fontColor($r('app.color.text_color'))
        .fontWeight(FontWeight.Bold)
        .margin({ top: 10 })

      Flex({ justifyContent: FlexAlign.SpaceAround }) {
        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Row({ space: 5 }) {
            SymbolGlyph($r('sys.symbol.xmark')).fontSize(18).fontColor([$r('app.color.text_color')])
            Text($r('app.string.cancel'))
              .fontSize(18)
              .fontColor($r('app.color.text_color'))
              .fontWeight(FontWeight.Medium)
          }.alignItems(VerticalAlign.Center).padding({ left: 12, right: 12 })
        }
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
        .backgroundColor('#00000000')
        .borderRadius(8)
        .height(40)
        .onClick(() => this.controller?.close())

        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Row({ space: 5 }) {
            SymbolGlyph($r('sys.symbol.checkmark')).fontSize(18).fontColor([$r('app.color.text_color')])
            Text($r('app.string.sure')).fontSize(18).fontColor($r('app.color.text_color')).fontWeight(FontWeight.Medium)
          }.alignItems(VerticalAlign.Center).padding({ left: 12, right: 12 })
        }
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
        .backgroundColor('#00000000')
        .borderRadius(8)
        .height(40)
        .onClick(() => {
          this.controller?.close()
          if (this.confirm) {
            this.confirm(true)
          }
        })
      }.margin({ bottom: 10 })
    }.padding(20)
  }
}