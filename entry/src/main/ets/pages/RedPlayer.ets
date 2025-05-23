import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { PlayerCoreType, RedPlayerXComponentController, SourceType } from '@rte-xhs/redplayer';
import RedPlayerSettingsConfig from '../global/RedPlayerSettingsConfig';
import RedPlayerStateHolder from '../global/RedPlayerStateHolder';
import { VideoMetadataFromPlayer } from '../interfaces/VideoMetadataFromPlayerInterface';
import PermissionUtil from '../utils/PermissionUtil';
import RedPlayerControllerUtil from '../utils/RedPlayerControllerUtil';
import { fileIo as fs } from '@kit.CoreFileKit';
import ToolsUtil from '../utils/ToolsUtil';
import TimeUtil from '../utils/TimeUtil';
import { KeyCode } from '@kit.InputKit';
import { PlayerParams } from '../common/PlayerParams';
import { VideoMetadata } from '../interfaces/VideoMetadataInterface';
import { FileFolder } from '../interfaces/FileFolderInterface';
import AVSessionUtil from '../utils/AVSessionUtil';
import { avSession as avSessionManager } from '@kit.AVSessionKit';
import VideoOperateUtil from '../utils/VideoOperateUtil';
import VideoInfoUtil from '../utils/VideoInfoUtil';

const context = getContext() as common.UIAbilityContext;

@Component
export struct RedPlayer { // 红薯播放器页
  @Consume('pathStack') pathStack: NavPathStack
  windowClass = window.getLastWindow(context)
  coreType: PlayerCoreType =
    RedPlayerSettingsConfig.useSystemPlayer ? PlayerCoreType.TYPE_AV_PLAYER : PlayerCoreType.TYPE_RED_PLAYER
  xComponentController: RedPlayerXComponentController = new RedPlayerXComponentController(this.coreType)
  avSession: avSessionManager.AVSession | undefined = undefined;
  @State @Watch('setScreen') ShowControl: boolean = false
  @State screen_width: number = 0
  @State screen_height: number = 0
  @State last_play_time: number = 0
  @State played: boolean = false
  @State now_playing: VideoMetadataFromPlayer | undefined = undefined
  @State redPlayerStateHolder: RedPlayerStateHolder = new RedPlayerStateHolder()
  @State onSwiping: boolean = false
  @State isSliderPlayTimeChange: boolean = false
  playerController = new RedPlayerControllerUtil(this.redPlayerStateHolder)
  @StorageProp('topSafeHeight') topSafeHeight: number = 0;
  @StorageLink('allowBackgroundPlay') allowBackgroundPlay: boolean = true
  @StorageLink('skipIntroTime') skipIntroTime: string = '0'
  @StorageLink('allowDoubleFastForward') allowDoubleFastForward: boolean = true
  @StorageLink('fastForwardSeconds') fastForwardSeconds: string = '15'
  @State video_meta_data: VideoMetadata[] = []
  private file_folder: FileFolder = {
    name: '',
    date: '',
    video_list: []
  }

  build() {
    NavDestination() {
      Stack() {
        Stack() {
          Stack() {
            XComponent({
              id: this.xComponentController.getSurfaceId(),
              type: this.xComponentController.getSurfaceType(),
              libraryname: this.xComponentController.getLibraryName(),
              controller: this.xComponentController
            })
              .onLoad(() => {
                this.playerController.createMediaPlayer(this.coreType).then(async () => {
                  await PermissionUtil.activatePermission(this.now_playing?.uri || '')
                  const file = fs.openSync(this.now_playing?.uri)
                  this.playerController.setDataSource({
                    fd: file.fd,
                    logHead: "RedPlayer",
                    sourceType: SourceType.FD,
                    enableAccurateSeek: true,
                    isAutoLoop: RedPlayerSettingsConfig.useLoopPlay,
                    isAutoStart: true
                  })?.then(async () => {
                    this.playerController.setSurfaceId(this.xComponentController.getSurfaceId())
                    this.playerController.prepare()?.then(() => {
                      if (this.now_playing?.last_play! < this.redPlayerStateHolder.videoDuration * 0.9 &&
                        this.now_playing?.last_play != 0) {
                        this.playerController.seek(this.now_playing?.last_play!)
                      } else if (this.skipIntroTime !== '0' &&
                        Number(this.skipIntroTime) * 1000 < this.now_playing?.time! &&
                        !VideoInfoUtil.support_audio_format.includes(this.now_playing?.title.split('.')[this.now_playing?.title.split('.')
                          .length-1].toLowerCase()!)) {
                        this.playerController.seek(this.redPlayerStateHolder.videoDuration +
                          Number(this.skipIntroTime) * 1000)
                      }
                      this.playerController.start()
                    })
                    this.avSession = await AVSessionUtil.getAVSession()
                    await this.setSessionListener()
                    AVSessionUtil.setSessionInfo(JSON.stringify(this.now_playing))
                    VideoOperateUtil.updateSession(this.isSliderPlayTimeChange, this.redPlayerStateHolder.videoPosition)
                  })
                })
              })
              .onDestroy(() => {
                this.playerController.release()
              })
          }
          .width(this.redPlayerStateHolder.videoViewWidth)
          .height(this.redPlayerStateHolder.videoViewHeight)
          .animation({ duration: this.played ? 300 : 0, curve: Curve.Ease })

          Stack() {
            Flex({
              justifyContent: FlexAlign.SpaceBetween,
              alignItems: ItemAlign.Center,
              direction: FlexDirection.Column
            }) { //顶栏
              Flex({ justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Center }) {
                Column() {
                  if (this.screen_width > this.screen_height) {
                    Row() {
                      Text(ToolsUtil.getTime())
                        .fontWeight(FontWeight.Medium)
                        .fontSize(16)
                        .fontColor($r('sys.color.white'))
                        .textAlign(TextAlign.Center)
                        .align(Alignment.Center)
                    }
                    .width('100%')
                    .height(5)
                    .justifyContent(FlexAlign.Center)
                  }
                  this.VideoTop()
                }.width('100%')
              }.height(85)
              .width('100%')
              .backgroundColor('#61000000')
              .padding({
                left: (this.screen_height > this.screen_width ? 5 : 5),
                right: 20,
                top: (this.screen_height > this.screen_width ? this.topSafeHeight : 0),
                bottom: 0
              })

              Stack() { //底栏
                if (this.screen_height > this.screen_width) {
                  Column({ space: 15 }) {
                    this.VideoButtons()
                    this.VideoSlider()
                  }
                } else {
                  Row({ space: 15 }) {
                    Column() {
                      this.VideoSlider()
                      this.VideoButtons()
                    }
                  }
                }
              }
              .backgroundColor('#61000000')
              .height(this.screen_height > this.screen_width ? 180 : 110)
              .width('100%')
            }.height('100%').width('100%')
          }
          .animation({ duration: 300, curve: Curve.Smooth })
          .visibility(this.ShowControl ? Visibility.Visible : Visibility.Hidden)
        }

        if (this.onSwiping) {
          Stack() {
            Text(this.isSliderPlayTimeChange ?
              TimeUtil.convertMsToMMSS(this.redPlayerStateHolder.videoPosition) + '/' +
              TimeUtil.convertMsToMMSS(this.redPlayerStateHolder.videoDuration) :
              (this.redPlayerStateHolder.videoPosition - this.last_play_time > 0 ? '+' : '') +
              Math.floor((this.redPlayerStateHolder.videoPosition - this.last_play_time) / 1000) + 's : ' +
              TimeUtil.convertMsToMMSS(this.redPlayerStateHolder.videoPosition) + '/' +
              TimeUtil.convertMsToMMSS(this.redPlayerStateHolder.videoDuration))
              .fontColor($r('sys.color.white'))
              .fontSize(25)
              .fontWeight(FontWeight.Bold)
          }
          .padding({
            left: 25,
            right: 25,
            top: 10,
            bottom: 10
          })
          .borderRadius(1000)
          .backgroundColor('#30000000')
          .backdropBlur(100)
          .animation({ duration: 300, curve: Curve.Smooth })
        }

        Column()
          .width('100%')
          .height(this.ShowControl ? '50%' : '80%')//触控区域
          .gesture(GestureGroup(GestureMode.Parallel,
            TapGesture({ count: 2 })
              .onAction((event: GestureEvent) => {
                if (this.allowDoubleFastForward) {
                  const tapX = event.fingerList[0].localX;
                  const adjustWidth = this.screen_width / 5; // 计算五分之一宽度
                  if (tapX < adjustWidth) { // 左侧1/5区域
                    this.playerController.seek(this.redPlayerStateHolder.videoPosition -
                      Number(this.fastForwardSeconds) * 1000);
                  } else if (tapX > adjustWidth * 4) { // 右侧1/5区域
                    this.playerController.seek(this.redPlayerStateHolder.videoPosition +
                      Number(this.fastForwardSeconds) * 1000);
                  } else { // 中间3/5区域
                    this.redPlayerStateHolder.isStart ? this.playerController.pause() : this.playerController.start()
                  }
                } else {
                  this.redPlayerStateHolder.isStart ? this.playerController.pause() : this.playerController.start()

                }
              }),
            TapGesture({ count: 1 })
              .onAction(() => { //单击屏幕
                this.ShowControl = !this.ShowControl
              }))
          )
      }
      .onAreaChange(async (_oldValue: Area, newValue: Area) => {
        this.screen_width = Math.floor(new Number(newValue.width).valueOf())
        this.screen_height = Math.floor(new Number(newValue.height).valueOf())
        this.playerController.getVideoSize()
      })
      .backgroundColor($r('sys.color.black'))
    }.onReady(() => {
      const playerParams: PlayerParams = this.pathStack.getParamByName('RedPlayer')[0] as PlayerParams
      try {
        this.now_playing = playerParams.metadata as VideoMetadataFromPlayer
        this.video_meta_data = playerParams.metadata_list as VideoMetadata[];
        this.file_folder = playerParams.file_folder as FileFolder
      } catch (e) {
        console.error(e)
      }
    })
    .onBackPressed(() => {
      if (this.ShowControl) {
        this.ShowControl = false
        return true
      } else {
        return false
      }
    }).onWillDisappear(async () => {
      if (this.video_meta_data.length > 0 && this.redPlayerStateHolder.videoPosition > 0) {
        await VideoOperateUtil.saveVideoTime(this.redPlayerStateHolder.videoPosition, this.now_playing!,
          this.video_meta_data, context,
          this.file_folder)
      }
      if (this.allowBackgroundPlay) {
        AVSessionUtil.destroySession()
        PermissionUtil.stopContinuousTask()
      }
    }).hideTitleBar(true)
  }

  async setScreen() {
    await (await this.windowClass).setSpecificSystemBarEnabled('status', this.ShowControl)
    await (await this.windowClass).setSpecificSystemBarEnabled('navigationIndicator', this.ShowControl)
  }

  async aboutToAppear(): Promise<void> {
    if (this.allowBackgroundPlay) {
      PermissionUtil.startContinuousTask()
    }
    await this.setScreen()
    await (await this.windowClass).setPreferredOrientation(window.Orientation.AUTO_ROTATION_RESTRICTED);
    await (await this.windowClass).setWindowKeepScreenOn(true)
  }

  async aboutToDisappear() {
    await (await this.windowClass).setWindowKeepScreenOn(false)
    await (await this.windowClass).setSpecificSystemBarEnabled('status', true)
    await (await this.windowClass).setSpecificSystemBarEnabled('navigationIndicator', true)
    await (await this.windowClass).setPreferredOrientation(window.Orientation.FOLLOW_DESKTOP);
  }

  async setSessionListener() {
    this.avSession?.on('play', () => {
      this.playerController.start()
    });
    this.avSession?.on('pause', () => {
      this.playerController.pause()
    });
    this.avSession?.on('seek', (position: number) => {
      let seekValue = position;
      this.playerController.seek(seekValue)
    })
  }

  @Builder
  VideoTop() {
    Row() {
      SymbolGlyph($r('sys.symbol.chevron_left'))// 返回图标
        .fontSize(40)
        .fontColor(['#f0f0f0'])
        .onClick(() => {
          this.pathStack.pop()
        })
        .padding({ right: 10 })
        .margin({ left: 15 })
      Text(String(this.now_playing?.title).slice(0, this.now_playing?.title.lastIndexOf('.')))
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .width('100%')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.MARQUEE })
        .fontColor($r('sys.color.white'))
    }
  }

  @Builder
  VideoSlider() {
    Row({ space: 10 }) {
      Row() {
        Text(TimeUtil.convertMsToMMSS(Math.min(Math.max(this.redPlayerStateHolder.videoPosition, 0),
          (this.redPlayerStateHolder.videoDuration || 0))) + '/' +
        TimeUtil.convertMsToMMSS(this.redPlayerStateHolder.videoDuration || 0))
          .fontWeight(FontWeight.Medium)
          .fontSize(16)
          .fontColor($r('sys.color.white'))
          .textAlign(TextAlign.Start)
      }.backgroundColor('#50000000').padding(5).borderRadius(10).margin({ left: 5 })

      Slider({
        value: this.redPlayerStateHolder.videoPosition,
        min: 0,
        max: this.redPlayerStateHolder.videoDuration,
        style: SliderStyle.InSet
      })
        .onChange((value: number) => {
          this.redPlayerStateHolder.videoPosition = value
          this.isSliderPlayTimeChange = true
          this.onSwiping = true
          this.onSwiping = true
        })
        .onTouch((event) => {
          if (event.type == TouchType.Up) {
            let seekValue = this.redPlayerStateHolder.videoPosition
            this.playerController.seek(seekValue)
            this.onSwiping = false
            this.isSliderPlayTimeChange = false
          }
        })
        .layoutWeight(1)
        .animation({ duration: 100, curve: Curve.Smooth })
        .selectedColor('#e0e0e0')
      Row() {
        Text(TimeUtil.convertMsToMMSS(Math.min(Math.max((this.redPlayerStateHolder.videoDuration || 0) -
        this.redPlayerStateHolder.videoPosition, 0),
          (this.redPlayerStateHolder.videoDuration || 0))))
          .fontWeight(FontWeight.Medium).fontSize(15)
          .fontColor($r('sys.color.white'))
      }.backgroundColor('#50000000').padding(5).borderRadius(10).margin({ right: 5 })
    }
  }

  @Builder
  VideoButtons() {
    GridRow({ columns: 14, gutter: 5 }) {
      GridCol() {
        Button({ type: ButtonType.Circle, stateEffect: true }) { // 播放按钮
          SymbolGlyph(this.redPlayerStateHolder.isStart ? $r('sys.symbol.pause_fill') : $r('sys.symbol.play_fill'))
            .fontSize(27)
            .fontColor(['#f0f0f0'])
            .symbolEffect(new ReplaceSymbolEffect(EffectScope.WHOLE), Number(this.redPlayerStateHolder.isStart))
        }
        .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
        .height(40)
        .width(40)
        .backgroundColor('#50000000')
        .defaultFocus(true)
        .onKeyEvent((event?: KeyEvent) => {
          if (event) {
            if (event.type === KeyType.Down && event.keyCode === KeyCode.KEYCODE_SPACE) { // 空格键按下触发
              this.redPlayerStateHolder.isStart ? this.playerController.pause() : this.playerController.start()
            }
          }
        })
        .onClick(() => {
          ToolsUtil.startVibration()
          this.redPlayerStateHolder.isStart ? this.playerController.pause() : this.playerController.start()
        })
      }.span({ xs: 2, sm: 2, md: 2 })

      GridCol() {
        Button({ type: ButtonType.Circle, stateEffect: true }) { // 全屏按钮
          SymbolGlyph($r('sys.symbol.screen_rotation'))
            .fontSize(23)
            .fontColor(['#f0f0f0'])
        }
        .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
        .height(40)
        .width(40)
        .backgroundColor('#50000000')
        .onClick(async () => {
          this.screen_height > this.screen_width ?
          (await (this.windowClass)).setPreferredOrientation(window.Orientation.AUTO_ROTATION_LANDSCAPE)
            : (await (this.windowClass)).setPreferredOrientation(window.Orientation.AUTO_ROTATION_PORTRAIT)
        })
      }.span({ xs: 2, sm: 2, md: 2 })
    }.width('95%')
  }
}