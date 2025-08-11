import { window } from '@kit.ArkUI';
import { PlayerCoreType, RedPlayerXComponentController, SourceType } from '@rte-xhs/redplayer';
import { VideoMetadataFromPlayer } from '../interfaces/VideoMetadataFromPlayerInterface';
import PermissionUtil from '../utils/PermissionUtil';
import RedPlayerControllerUtil from '../utils/RedPlayerControllerUtil';
import { fileIo as fs } from '@kit.CoreFileKit';
import ToolsUtil from '../utils/ToolsUtil';
import { KeyCode } from '@kit.InputKit';
import { PlayerParams } from '../common/PlayerParams';
import { VideoMetadata } from '../interfaces/VideoMetadataInterface';
import AVSessionUtil from '../utils/AVSessionUtil';
import { AVCastPicker, avSession as avSessionManager } from '@kit.AVSessionKit';
import VideoOperateUtil from '../utils/VideoOperateUtil';
import VideoInfoUtil from '../utils/VideoInfoUtil';
import { audio } from '@kit.AudioKit';
import { settings } from '@kit.BasicServicesKit';
import { ButtonFancyModifier } from '../utils/AttributeModifierUtil';
import { PathUtils } from '../utils/PathUtils';
import RedPlayerSettingsConfig from '../common/RedPlayerSettingsConfig';
import RedPlayerStateHolder from '../common/RedPlayerStateHolder';
import { AVCastPickerBuilder } from '../component/PlayerComponent/AVCastPickerBuilder';
import { VolumeSwipingComponent } from '../component/PlayerComponent/VolumeSwipingComponent';
import { BrightnessSwipingComponent } from '../component/PlayerComponent/BrightnessSwipingComponent';
import { FastForwardInfoComponent } from '../component/PlayerComponent/FastForwardInfoComponent';
import { SwipingPlayTimeDisplay } from '../component/PlayerComponent/SwipingPlayTimeDisplay';
import { VideoSliderComponent } from '../component/PlayerComponent/VideoSliderComponent';
import { GestureComponent } from '../component/PlayerComponent/GestureComponent';
import { VideoStartTimeMode } from '../common/enum/VideoStartTimeMode';

@Component
export struct RedPlayer { // 红薯播放器页
  @Consume('pathStack') pathStack: NavPathStack
  windowClass = window.getLastWindow(PathUtils.appContext!)
  xComponentController: RedPlayerXComponentController =
    new RedPlayerXComponentController(PlayerCoreType.TYPE_RED_PLAYER)
  avSession: avSessionManager.AVSession | undefined = undefined;
  @State @Watch('setScreen') showControl: boolean = false
  @State screen_width: number = 0
  @State screen_height: number = 0
  @State last_play_time: number = 0
  @State now_playing: VideoMetadataFromPlayer | undefined = undefined
  @State redPlayerStateHolder: RedPlayerStateHolder = new RedPlayerStateHolder()
  @State play_time: number = this.redPlayerStateHolder.videoPosition
  @State onSwiping: boolean = false
  @State isSliderPlayTimeChange: boolean = false
  @State play_speed: number = 1
  @State last_speed: number = 1
  @State currentSpeedIndex: number = 0
  @State long_press: boolean = false
  @State longPressStartX: number = 0
  @State isLeftSideSwipe: boolean = false
  @State isRightSideSwipe: boolean = false
  @State isVerticalSwiping: boolean = false
  @State swipe_start_y: number = 0
  @State onSwipingVoice: boolean = false
  @State onSwipingBrightness: boolean = false
  @State screenBrightnessAtFirst: number = 0
  @State swipe_start_x: number = 0
  @State isHorizontalSwiping: boolean = false
  @State volumeTmp: number = 0
  @State isLock: boolean = false
  @State volume: number = 1.0
  @State screenBrightness: number = 0
  @State volumeActually: number = 0
  playerController = new RedPlayerControllerUtil(this.redPlayerStateHolder)
  @StorageProp('topSafeHeight') topSafeHeight: number = 0;
  @StorageLink('allowBackgroundPlay') allowBackgroundPlay: boolean = true
  @StorageLink('skipIntroTime') skipIntroTime: string = '0'
  @StorageLink('allowDoubleFastForward') allowDoubleFastForward: boolean = true
  @StorageLink('fastForwardSeconds') fastForwardSeconds: string = '15'
  @State video_meta_data: VideoMetadata[] = []
  private audioVolumeManager: audio.AudioVolumeManager | null = null

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
                this.playerController.createMediaPlayer(PlayerCoreType.TYPE_RED_PLAYER).then(async () => {
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
                      this.playerController.setVolume(1.0)
                      this.videoStartPlayTime(VideoOperateUtil.getVideoStartPlayTimeMode(this.now_playing!,
                        this.skipIntroTime))
                      this.playerController.start()
                    })
                    this.avSession = await AVSessionUtil.getAVSession()
                    await this.setSessionListener()
                    AVSessionUtil.setSessionInfo(this.now_playing!)
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
          .animation({ duration: 300, curve: Curve.Ease })

          Stack() {
            Flex({
              justifyContent: FlexAlign.SpaceBetween,
              alignItems: ItemAlign.Center,
              direction: FlexDirection.Column
            }) { //顶栏
              Flex({ justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Center }) {
                Column() {
                  this.VideoTop()
                }.width('100%')
              }.height(85)
              .width('100%')
              .backgroundColor($r('sys.color.mask_fourth'))
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
              .backgroundColor($r('sys.color.mask_fourth'))
              .height(this.screen_height > this.screen_width ? 180 : 110)
              .width('100%')
            }.height('100%').width('100%')
          }
          .animation({ duration: 300, curve: Curve.Smooth })
          .visibility(this.showControl ? Visibility.Visible : Visibility.Hidden)
        }

        if (this.onSwiping) {
          SwipingPlayTimeDisplay({
            isSliderPlayTimeChange: this.isSliderPlayTimeChange,
            playTime: this.play_time,
            totalTime: this.redPlayerStateHolder.videoDuration,
            lastPlayTime: this.last_play_time
          })
        }

        if (this.onSwipingVoice) {
          VolumeSwipingComponent({
            videoVolume: this.volume,
            videoVolumeShow: this.volumeActually
          })
        }

        if (this.onSwipingBrightness) {
          BrightnessSwipingComponent({
            screenBrightness: this.screenBrightness,
          })
        }

        if (this.long_press) {
          FastForwardInfoComponent({
            speed: Number(this.play_speed),
            location: this.screen_width > this.screen_height ? -160 : -80
          })
        }

        GestureComponent({
          showControl: this.showControl,
          onDoubleClickAction: (event: GestureEvent) => {
            if (!this.allowDoubleFastForward) { // 非快进模式直接切换播放状态
              this.togglePlayback();
              return;
            }
            const tapX = event.fingerList[0].localX;
            const zoneWidth = this.screen_width / 5; // 计算区域分割宽度
            const seekOffset = Number(this.fastForwardSeconds) * 1000;
            if (tapX < zoneWidth) { // 左侧区域：回退
              const newPosition = this.play_time - seekOffset;
              this.seekTime(newPosition);
              return;
            }
            if (tapX > zoneWidth * 4) { // 右侧区域：快进
              const newPosition = this.play_time + seekOffset;
              this.seekTime(newPosition);
              return;
            }
            this.togglePlayback(); // 中间区域：播放/暂停切换
          },
          onSingleClickAction: () => {
            this.showControl = !this.showControl
          },
          onVerticalPanStart: (event: GestureEvent) => {
            if (!this.isLock) {
              const firstTouch = event.fingerList[0];
              this.swipe_start_x = firstTouch.localX;
              this.swipe_start_y = firstTouch.localY;
              this.isLeftSideSwipe = firstTouch.localX < this.screen_width / 2;
              VideoOperateUtil.screenBrightnessTmp = this.screenBrightness
              VideoOperateUtil.lastVolume = this.volume; // 记录起始音量
              VideoOperateUtil.lastVolumeTime = Date.now(); // 记录起始时间
            }
          },
          onVerticalPanUpdate: (event: GestureEvent) => {
            if (!this.isLock && event.fingerList.length === 1) {
              const currentY = event.fingerList[0].localY;
              const deltaY = currentY - this.swipe_start_y;
              const deltaYScale = deltaY / this.screen_height * 2.5;
              if (this.isLeftSideSwipe) {
                this.onSwipingBrightness = true
                this.screenBrightness = VideoOperateUtil.calNewBrightness(deltaYScale)
                VideoOperateUtil.setBrightness(this.screenBrightness);
              } else {
                this.onSwipingVoice = true
                this.volume = VideoOperateUtil.calNewVolume(deltaYScale)
                VideoOperateUtil.lastVolumeTime = VideoOperateUtil.volumeGestureActiveTime;
                VideoOperateUtil.lastVolume = this.volume
              }
            }
          },
          onVerticalPanEnd: () => {
            this.onSwiping = false;
            this.onSwipingVoice = false;
            this.onSwipingBrightness = false;
          },
          onHorizonPanStart: (event: GestureEvent) => {
            if (this.isLock) {
              return
            }
            const firstTouch = event.fingerList[0];
            this.swipe_start_x = firstTouch.localX;
            this.swipe_start_y = firstTouch.localY;
            this.play_time = this.redPlayerStateHolder.videoPosition;
            this.last_play_time = this.redPlayerStateHolder.videoPosition;
            this.onSwiping = true
          },
          onHorizonPanUpdate: (event: GestureEvent) => {
            if (event?.fingerList?.[0]?.localX !== undefined &&
              typeof event.fingerList[0].localX === 'number') {
              const currentX = event.fingerList[0].localX;
              const deltaX = currentX - this.swipe_start_x;
              this.play_time = Math.max(0,
                Math.min(this.last_play_time + (deltaX * VideoOperateUtil.timePerPixel),
                  this.now_playing?.time!));
            }
          },
          onHorizonPanEnd: () => {
            this.seekTime(this.play_time)
            this.onSwiping = false;
          },
          onLongPressAction: () => {
            this.long_press = true
            this.last_speed = this.play_speed
            this.play_speed = 2
            this.playerController.setSpeed(this.play_speed)
            this.currentSpeedIndex = VideoInfoUtil.video_speed_list.indexOf(2);
          },
          onLongPressEnd: () => {
            this.long_press = false
            this.play_speed = this.last_speed
            this.playerController.setSpeed(this.last_speed)
          },
          onLongPressPanStart: (event: GestureEvent) => {
            if (this.isLock) {
              return
            }
            this.longPressStartX = event.fingerList[0].localX;
          },
          onLongPressPanUpdate: (event: GestureEvent) => {
            if (!this.isLock && this.long_press) { // 长按状态下的滑动处理
              const deltaX = event.fingerList[0].localX - this.longPressStartX;
              const SWIPE_THRESHOLD = 30;
              if (Math.abs(deltaX) <= SWIPE_THRESHOLD) { // 未达到滑动阈值则直接返回
                return;
              }
              const direction = deltaX > 0 ? 1 : -1; // 确定滑动方向（正值为右滑，负值为左滑）
              const newIndex = this.currentSpeedIndex + direction; // 计算新的速度索引
              const clampedIndex = Math.max(0, Math.min(newIndex, VideoInfoUtil.video_speed_list.length - 1));
              // 检查速度索引是否变化且速度值是否在允许范围内 (0.5-2.0)
              if (clampedIndex === this.currentSpeedIndex ||
                VideoInfoUtil.video_speed_list[clampedIndex] < 0.5 ||
                VideoInfoUtil.video_speed_list[clampedIndex] > 2) {
                return;
              }
              this.currentSpeedIndex = clampedIndex
              this.play_speed = VideoInfoUtil.video_speed_list[clampedIndex]; // 更新播放速度
              this.playerController.setSpeed(this.play_speed);
              this.longPressStartX = event.fingerList[0].localX; // 重置起始点实现分档切换效果
            }
          }
        })
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
      } catch (e) {
        console.error(e)
      }
    })
    .onBackPressed(() => {
      if (this.showControl) {
        this.showControl = false
        return true
      } else {
        return false
      }
    }).onWillDisappear(async () => {
      if (this.video_meta_data.length > 0 && this.redPlayerStateHolder.videoPosition > 0) {
        VideoOperateUtil.saveVideoTime(this.redPlayerStateHolder.videoPosition, this.now_playing!,
          this.video_meta_data, PathUtils.appContext!)
      }
      await (await this.windowClass).setWindowKeepScreenOn(false)
      if (canIUse('SystemCapability.Window.SessionManager')) {
        await (await this.windowClass).setSpecificSystemBarEnabled('status', true)
        await (await this.windowClass).setSpecificSystemBarEnabled('navigationIndicator', true)
      }
      await (await this.windowClass).setPreferredOrientation(window.Orientation.AUTO_ROTATION_RESTRICTED);
      if (this.allowBackgroundPlay) {
        AVSessionUtil.destroySession()
        PermissionUtil.stopContinuousTask()
      }
    }).hideTitleBar(true)
  }

  async setScreen() {
    if (canIUse('SystemCapability.Window.SessionManager')) {
      await (await this.windowClass).setSpecificSystemBarEnabled('status', this.showControl, true)
      await (await this.windowClass).setSpecificSystemBarEnabled('navigationIndicator', this.showControl, true)
    }
  }

  async aboutToAppear(): Promise<void> {
    if (this.allowBackgroundPlay) {
      PermissionUtil.startContinuousTask()
    }
    await this.setScreen()
    await (await this.windowClass).setPreferredOrientation(window.Orientation.AUTO_ROTATION_RESTRICTED);
    await (await this.windowClass).setWindowKeepScreenOn(true)
    let groupId: number = audio.DEFAULT_VOLUME_GROUP_ID;
    let audioManager = audio.getAudioManager();
    this.audioVolumeManager = audioManager.getVolumeManager();
    let volume_list = await VideoOperateUtil.getVolume(this.audioVolumeManager, groupId)
    this.volume = volume_list.get('volume')!
    if (canIUse('SystemCapability.Applications.Settings.Core')) {
      settings.getValue(PathUtils.appContext!, settings.display.SCREEN_BRIGHTNESS_STATUS,
        settings.domainName.DEVICE_SHARED)
        .then((value) => {
          this.screenBrightness = Number(value) / 255;
        })
    }
    this.volumeActually = this.volume
    this.audioVolumeManager.on('volumeChange', (volumeEvent: audio.VolumeEvent) => {
      this.volumeActually = volumeEvent.volume
      ToolsUtil.startVibration()
    });
  }

  async aboutToDisappear() {
    VideoOperateUtil.setBrightness(-1)
    this.audioVolumeManager?.off('volumeChange');
    this.audioVolumeManager = null
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
      this.seekTime(seekValue)
    })
  }

  @Builder
  VideoTop() {
    Row({ space: 8 }) {
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
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.MARQUEE })
        .fontColor($r('sys.color.white'))
        .layoutWeight(1) // 关键布局属性
    }
  }

  @Builder
  VideoSlider() {
    VideoSliderComponent({
      playTime: this.redPlayerStateHolder.videoPosition,
      totalTime: this.redPlayerStateHolder.videoDuration,
      screenHeight: this.screen_height,
      screenWidth: this.screen_width,
      onSliderChange: (value: number) => {
        this.play_time = value
        if (this.redPlayerStateHolder.videoPosition >= this.redPlayerStateHolder.videoDuration ||
          this.play_time >= this.redPlayerStateHolder.videoDuration) {
          this.seekTime(0)
          this.onSwiping = false
        } else {
          this.isSliderPlayTimeChange = true
          this.onSwiping = true
        }
      },
      onSliderTouch: (event: TouchEvent) => {
        if (event.type == TouchType.Down) {
          this.play_time = this.redPlayerStateHolder.videoPosition
        }
        if (event.type == TouchType.Up) {
          this.seekTime(this.play_time)
          this.onSwiping = false
          this.isSliderPlayTimeChange = false
        }
      }
    })
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
        .attributeModifier(new ButtonFancyModifier(40, 40))
        .backgroundColor('#50000000')
        .defaultFocus(true)
        .onKeyEvent((event?: KeyEvent) => {
          if (event) {
            if (event.type === KeyType.Down && event.keyCode === KeyCode.KEYCODE_SPACE) { // 空格键按下触发
              this.togglePlayback()
            }
          }
        })
        .onClick(() => {
          ToolsUtil.startVibration()
          this.togglePlayback()
        })
      }.span({ xs: 2, sm: 2, md: 2 })

      GridCol() {
        Button({ type: ButtonType.Circle, stateEffect: true }) { // 全屏按钮
          SymbolGlyph($r('sys.symbol.screen_rotation'))
            .fontSize(23)
            .fontColor(['#f0f0f0'])
        }
        .attributeModifier(new ButtonFancyModifier(40, 40))
        .backgroundColor('#50000000')
        .onClick(async () => {
          VideoOperateUtil.fullScreenOperate()
          const orientation = this.screen_height > this.screen_width
            ? window.Orientation.AUTO_ROTATION_LANDSCAPE
            : window.Orientation.AUTO_ROTATION_PORTRAIT;
          (await this.windowClass).setPreferredOrientation(orientation)
        })
      }.span({ xs: 2, sm: 2, md: 2 })

      GridCol() { // 投播
        AVCastPicker({
          normalColor: Color.White,
          onStateChange: VideoOperateUtil.castOnStateChange,
          customPicker: () => this.AVCastPickerBuilderBridge()
        })
          .width(23)
          .height(23)
          .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
      }.span({ xs: 2, sm: 2, md: 2 })
    }.width('95%')
  }

  @Builder
  AVCastPickerBuilderBridge() { // 桥接AVCastPickerBuilder避免crash
    AVCastPickerBuilder()
  }

  videoStartPlayTime(seekMode: number) {
    switch (seekMode) {
      case VideoStartTimeMode.SEEK_TO_LAST_PLAY_TIME:
        this.seekTime(this.now_playing?.last_play || 0)
        break
      case VideoStartTimeMode.SEEK_TO_START_TIME:
        this.seekTime(this.now_playing?.start_time || 0)
        break
      case VideoStartTimeMode.SEEK_TO_INTRO_TIME:
        this.seekTime(this.play_time + Number(this.skipIntroTime) * 1000)
        break
      default:
        return
    }
  }

  private seekTime(position: number) { // 视频跳转操作封装
    this.playerController.seek(position);
    this.redPlayerStateHolder.videoPosition = position;
  }

  private togglePlayback() { // 播放/暂停切换封装
    this.redPlayerStateHolder.isStart ? this.playerController.pause() : this.playerController.start();
  }
}