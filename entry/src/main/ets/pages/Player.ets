import { media } from '@kit.MediaKit';
import AVPlayerUtil from '../utils/AVPlayerUtil';
import DataSyncUtil from '../utils/DataSyncUtil';
import { fileIo as fs } from '@kit.CoreFileKit';
import PermissionUtil from '../utils/PermissionUtil';
import { common } from '@kit.AbilityKit';
import { router, window } from '@kit.ArkUI';
import { avSession as avSessionManager } from '@kit.AVSessionKit';
import AVSessionUtil from '../utils/AVSessionUtil';
import ToolsUtil from '../utils/ToolsUtil';
import { hilog } from '@kit.PerformanceAnalysisKit';
import VideoSpeedUtil from '../utils/VideoUtil';
import TimeUtil from '../utils/TimeUtil';

interface VideoMetadata {
  uri: string
  title: string
  date: string,
  size: number[]
  time: number
  last_play: number
}

interface avSessionState {
  playing: boolean
  duration: number
}

const context = getContext() as common.UIAbilityContext;

@Entry
@Component
struct Player {
  avPlayer: media.AVPlayer | undefined = undefined
  avSession: avSessionManager.AVSession | undefined = undefined;
  now_playing: VideoMetadata | undefined = undefined
  @State playing: boolean = false
  @State speed: number = 1.0
  @State last_speed: number = 1
  @State play_time: number = 0
  @State last_play_time: number = 0
  surfaceID: string = ''
  @State SwipeStartX: number = 0
  @State SwipeMovingX: number = 0
  seek_time: number | undefined = undefined
  @State LongPress: boolean = false
  @State played: boolean = false
  @State @Watch('setScreen') ShowControl: boolean = false
  @State lock_rotation: boolean = false
  xComponentController: XComponentController = new XComponentController()
  windowClass = window.getLastWindow(context)
  @State screen_width: number = 0
  @State screen_height: number = 0
  @State play_area_height: number = 0
  @State play_area_width: number = 0
  @State onSwiping: boolean = false

  onBackPress(): boolean | void {
    if (this.ShowControl) {
      this.ShowControl = false
      return true
    } else {
      this.avPlayer?.reset()
      return false
    }
  }

  async setSessionListener() {
    this.avSession?.on('play', () => {
      this.avPlayer?.play()
    });
    this.avSession?.on('pause', () => {
      this.avPlayer?.pause()
    });
    this.avSession?.on('seek', (position: number) => {
      this.avPlayer?.seek(position)
    })
    this.avSession?.on('fastForward', () => {
      this.avPlayer?.seek(this.play_time + 15000)
    })
    this.avSession?.on('rewind', () => {
      this.avPlayer?.seek(this.play_time - 15000)
    })
  }

  async setScreen() {
    await (await this.windowClass).setSpecificSystemBarEnabled('status', this.ShowControl)
    await (await this.windowClass).setSpecificSystemBarEnabled('navigationIndicator', this.ShowControl)
  }

  async aboutToAppear(): Promise<void> {
    let record = router.getParams() as Record<string, string>
    if (record) {
      this.now_playing = JSON.parse(record['metadata'])
    }
    this.seek_time = this.now_playing?.last_play
    PermissionUtil.startContinuousTask()
    this.setScreen()
    this.avPlayer = await AVPlayerUtil.getAVPlayer()
    await (await this.windowClass).setPreferredOrientation(window.Orientation.AUTO_ROTATION_RESTRICTED);
    await (await this.windowClass).setWindowKeepScreenOn(true)
  }

  async aboutToDisappear(): Promise<void> {
    AVSessionUtil.destroySession()
    PermissionUtil.stopContinuousTask()
    await (await this.windowClass).setWindowKeepScreenOn(false)
    await (await this.windowClass).setSpecificSystemBarEnabled('status', true)
    await (await this.windowClass).setSpecificSystemBarEnabled('navigationIndicator', true)
    await (await this.windowClass).setPreferredOrientation(window.Orientation.AUTO_ROTATION_RESTRICTED);
  }

  async setRotation() {
    if (!this.now_playing) {
      return
    }
    if (this.now_playing.size[0] > this.now_playing.size[1]) {
      if (this.screen_width > this.screen_height) {
        if (this.now_playing.size[0] / this.now_playing.size[1] > this.screen_width / this.screen_height) {
          this.play_area_width = this.screen_width
          this.play_area_height = this.play_area_width * (this.now_playing?.size[1] / this.now_playing?.size[0])
        } else {
          this.play_area_height = this.screen_height
          this.play_area_width = this.play_area_height * (this.now_playing?.size[0] / this.now_playing?.size[1])
        }
      } else {
        if (this.now_playing.size[0] / this.now_playing.size[1] > this.screen_width / this.screen_height) {
          this.play_area_width = this.screen_width
          this.play_area_height = this.play_area_width * (this.now_playing?.size[1] / this.now_playing?.size[0])
        } else {
          this.play_area_height = this.screen_height
          this.play_area_width = this.play_area_height * (this.now_playing?.size[0] / this.now_playing?.size[1])
        }
      }
    } else {
      if (this.screen_width > this.screen_height) {
        if (this.now_playing.size[0] / this.now_playing.size[1] > this.screen_width / this.screen_height) {
          this.play_area_width = this.screen_width
          this.play_area_height = this.play_area_width * (this.now_playing?.size[1] / this.now_playing?.size[0])
        } else {
          this.play_area_height = this.screen_height
          this.play_area_width = this.play_area_height * (this.now_playing?.size[0] / this.now_playing?.size[1])
        }
      } else {
        if (this.now_playing.size[0] / this.now_playing.size[1] > this.screen_width / this.screen_height) {
          this.play_area_width = this.screen_width
          this.play_area_height = this.play_area_width * (this.now_playing?.size[1] / this.now_playing?.size[0])
        } else {
          this.play_area_height = this.screen_height
          this.play_area_width = this.play_area_height * (this.now_playing?.size[0] / this.now_playing?.size[1])
        }
      }

    }
  }

  async setAVPlayerCallback() {
    this.avPlayer?.on('timeUpdate', (duration) => {
      if (!this.onSwiping) {
        animateTo({ duration: 300, curve: Curve.Ease }, () => {
          this.play_time = duration
        })
      }
      DataSyncUtil.last_time = duration
    })

    this.avPlayer?.on('seekDone', (percent) => {
      this.play_time = percent
      this.updateSession()
    })

    this.avPlayer?.on('speedDone', (speed) => {
      try {
        this.speed = VideoSpeedUtil.getVideoSpeed(parseFloat(speed.toFixed(2)))
      } catch (e) {
        hilog.error(777, 'testFlag', 'speed return undefined: ' + e)
      }
    })

    this.avPlayer?.on('stateChange', async (state) => {
      switch (state) {
        case 'initialized':
          if (this.avPlayer) {
            this.avPlayer.surfaceId = this.surfaceID
            this.avPlayer.prepare();
          }
          break;
        case 'prepared':
          this.avPlayer?.play();
          break;
        case 'completed':
          this.avPlayer?.play()
          this.avPlayer?.seek(0)
          break;
        case 'playing':
          this.played = true
          this.playing = true
          if (this.seek_time) {
            this.avPlayer?.seek(this.seek_time)
            this.seek_time = undefined
          }
          if (!this.avSession) {
            this.avSession = await AVSessionUtil.getAVSession()
            await this.setSessionListener()
            AVSessionUtil.setSessionInfo(JSON.stringify(this.now_playing))
            this.updateSession()
          }
          this.updateSession()
          break
        case 'paused':
          this.playing = false
          this.updateSession()
          break
        case 'released':
          this.playing = false
          this.updateSession()
          break
        case 'idle':
          break;
      }
    })
  }

  async getData() {
    if (this.avPlayer) {
      this.setAVPlayerCallback()
      await PermissionUtil.activatePermission(this.now_playing?.uri || '')
      this.avPlayer.fdSrc = fs.openSync(this.now_playing?.uri);
      this.setRotation()
    }
  }

  updateSession() {
    let data: avSessionState = {
      playing: this.playing,
      duration: this.play_time
    }
    AVSessionUtil.updateSession(JSON.stringify(data))
  }

  build() {
    Stack() {
      Stack() { //播放器
        Stack() {
          XComponent({ type: XComponentType.SURFACE, controller: this.xComponentController })
            .onLoad(() => {
              this.surfaceID = this.xComponentController.getXComponentSurfaceId()
              this.getData()
            })
        }
        .width(this.play_area_width)
        .height(this.play_area_height)
        .animation({ duration: this.played ? 300 : 0, curve: Curve.Ease })
      }
      .height('100%')
      .width('100%')
      // 图片组件的绘制区域扩展至状态栏和导航条。
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

      Stack() {
        Flex({
          justifyContent: FlexAlign.SpaceBetween,
          alignItems: ItemAlign.Center,
          direction: FlexDirection.Column
        }) {
          //顶栏
          Flex({ justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Center }) {
            SymbolGlyph($r('sys.symbol.chevron_left'))
              .fontSize(40)
              .fontColor(['#f0f0f0'])
              .onClick(() => {
                this.avPlayer?.reset()
                router.back()
              })
              .padding({
                right: 10
              })
            Row() {
              Text((String(this.now_playing?.title).split('.')[0]))
                .fontSize(20)
                .fontWeight(FontWeight.Medium)
                .width('77%')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.MARQUEE })
                .fontColor($r('sys.color.white'))
              Select([//倍速
                { value: '0.5x' },
                { value: '0.75x' },
                { value: '1.0x' },
                { value: '1.25x' },
                { value: '1.5x' },
                { value: '2.0x' },
                { value: '3.0x' }])
                .font({ size: 18, weight: FontWeight.Medium })
                .fontColor($r('sys.color.white'))
                .width('70%')
                .value(this.speed.toFixed(2) + 'x')
                .onSelect((_index: number, text?: string | undefined) => {
                  this.avPlayer?.setSpeed(VideoSpeedUtil.getVideoSpeed(parseFloat(text?.replace('x', '') || '1')))
                })
                .backgroundColor('#00000000')
                .menuBackgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THIN)
            }

            Button({ type: ButtonType.Circle, stateEffect: true }) { // 旋转锁定
              SymbolGlyph(this.lock_rotation ? $r('sys.symbol.lock_fill') : $r('sys.symbol.rotate_left'))
                .fontSize(23)
                .fontColor(['#f0f0f0'])
                .symbolEffect(new ReplaceSymbolEffect(EffectScope.WHOLE), Number(this.lock_rotation))
            }
            .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
            .height(40)
            .width(35)
            .backgroundColor('#00000000')
            .onClick(async () => {
              this.lock_rotation = !this.lock_rotation
              if (this.lock_rotation) {
                if (this.screen_width >
                this.screen_height) {
                  (await this.windowClass).setPreferredOrientation(window.Orientation.AUTO_ROTATION_LANDSCAPE_RESTRICTED)
                } else {
                  (await this.windowClass).setPreferredOrientation(window.Orientation.AUTO_ROTATION_PORTRAIT_RESTRICTED)
                }
              } else {
                (await this.windowClass).setPreferredOrientation(window.Orientation.AUTO_ROTATION_RESTRICTED)
              }
              if (this.lock_rotation) {
                ToolsUtil.showToast(getContext().resourceManager.getStringSync($r('app.string.open_rotation_lock')))
              } else {
                ToolsUtil.showToast(getContext().resourceManager.getStringSync($r('app.string.close_rotation_lock')))
              }
            })
          }
          .width('100%')
          .padding({
            left: (this.screen_height > this.screen_width ? 20 : 35),
            right: 20,
            top: (this.screen_height > this.screen_width ? DataSyncUtil.topSafeHeight : 5),
            bottom: 10
          })
          .backgroundColor('#61000000')

          Stack() { //底栏
            if (this.screen_height > this.screen_width) {
              Column({ space: 15 }) {
                this.VideoButtons()
                this.VideoSlider()
              }
            } else {
              Row({ space: 15 }) {
                this.VideoSlider()
                this.VideoButtons()
              }
            }
          }
          .height(this.screen_height > this.screen_width ? '25%' : '15%')
          .width('100%')
          .padding(1)
          .backgroundColor('#61000000')
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        }.height('100%').width('100%')
      }
      .visibility(this.ShowControl ? Visibility.Visible : Visibility.Hidden)
      .animation({ duration: 300, curve: Curve.Smooth })

      Stack() { //快进提示
        Text('3.0x').fontColor($r('sys.color.white')).fontSize(25).fontWeight(FontWeight.Bold)
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
      .visibility(this.LongPress ? Visibility.Visible : Visibility.Hidden)
      .animation({ duration: 300, curve: Curve.Smooth })

      //快进提示
      Stack() {
        Text((this.play_time - this.last_play_time > 0 ? '+' : '') +
        Math.floor((this.play_time - this.last_play_time) / 1000) + 's')
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
      .visibility(this.onSwiping ? Visibility.Visible : Visibility.Hidden)
      .animation({ duration: 300, curve: Curve.Smooth })

      Column()
        .width('100%')
        .height('50%')//触控区域
        .onTouch((event: TouchEvent) => {
          if (event.type == TouchType.Down) {
            if (this.speed > 1) {
              return
            }
            this.last_play_time = this.play_time
            this.SwipeStartX = Math.floor(event.touches[0].x)
          }
          if (event.type == TouchType.Move) {
            if (this.speed > 1) {
              return
            }
            this.SwipeMovingX = Math.floor(event.touches[0].x) + 10
            if (Math.abs(this.SwipeStartX - this.SwipeMovingX) > 10) {
              this.onSwiping = true
              this.ShowControl = true
              this.play_time = this.last_play_time + (this.SwipeMovingX - this.SwipeStartX) *
                (Math.abs(this.SwipeStartX - this.SwipeMovingX) > 150 ?
                  40 * (Math.abs(this.SwipeStartX - this.SwipeMovingX)) / 100 : 30)
            }
          }
          if (event.type == TouchType.Up) {
            if (Math.abs(this.SwipeStartX - this.SwipeMovingX) > 10) {
              this.avPlayer?.seek(this.play_time)
            }
            this.onSwiping = false
            if (this.LongPress) {
              this.LongPress = false
              this.avPlayer?.setSpeed(this.last_speed)
            }
          }
        })
        .gesture(LongPressGesture().onAction(() => {
          this.LongPress = true
          this.last_speed = this.speed
          this.avPlayer?.setSpeed(3)
        }))
        .gesture(GestureGroup(GestureMode.Exclusive,
          TapGesture({ count: 2 })
            .onAction(() => {
              this.playing ? this.avPlayer?.pause() : this.avPlayer?.play()
            }),
          TapGesture({ count: 1 })
            .onAction(() => {
              this.ShowControl = !this.ShowControl
            })
        ))
    }.onAreaChange(async (_oldValue: Area, newValue: Area) => {
      this.screen_width = Math.floor(new Number(newValue.width).valueOf())
      this.screen_height = Math.floor(new Number(newValue.height).valueOf())
      this.setRotation()
    })
    .backgroundColor($r('sys.color.black'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  @Builder
  VideoSlider() {
    Row({ space: 10 }) {
      Text(TimeUtil.convertMsToMMSS(Math.min(Math.max(this.play_time, 0), (this.now_playing?.time || 0))) + '/' +
      TimeUtil.convertMsToMMSS(this.now_playing?.time || 0))
        .fontWeight(FontWeight.Medium)
        .fontSize(16)
        .fontColor($r('sys.color.white'))
      Slider({
        value: this.play_time,
        min: 0,
        max: this.now_playing?.time,
        style: SliderStyle.InSet
      })
        .onChange((value) => {
          this.play_time = value
          this.avPlayer?.seek(value)
        })
        .width(this.screen_width > this.screen_height ? '45%' : '50%')
        .animation({ duration: 100, curve: Curve.Smooth })
        .selectedColor('#e0e0e0')
      Text(TimeUtil.convertMsToMMSS(Math.min(Math.max((this.now_playing?.time || 0) - this.play_time, 0),
        (this.now_playing?.time || 0))))
        .fontWeight(FontWeight.Medium).fontSize(15)
        .fontColor($r('sys.color.white'))
    }
  }

  @Builder
  VideoButtons() {
    Row({ space: 15 }) {
      Button({ type: ButtonType.Circle, stateEffect: true }) { // 后退按钮
        SymbolGlyph($r('sys.symbol.gobackward_15'))
          .fontSize(23)
          .fontColor(['#f0f0f0'])
      }
      .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
      .height(40)
      .width(40)
      .backgroundColor('#50000000')
      .onClick(() => {
        this.avPlayer?.seek(this.play_time - 15000)
      })

      Button({ type: ButtonType.Circle, stateEffect: true }) { // 快进按钮
        SymbolGlyph($r('sys.symbol.goforward_15'))
          .fontSize(23)
          .fontColor(['#f0f0f0'])
      }
      .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
      .height(40)
      .width(40)
      .backgroundColor('#50000000')
      .onClick(() => {
        this.avPlayer?.seek(this.play_time + 15000)
      })

      Button({ type: ButtonType.Circle, stateEffect: true }) { // 播放按钮
        SymbolGlyph(this.playing ? $r('sys.symbol.pause_fill') : $r('sys.symbol.play_fill'))
          .fontSize(30)
          .fontColor(['#f0f0f0'])
          .symbolEffect(new ReplaceSymbolEffect(EffectScope.WHOLE), Number(this.playing))
      }
      .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
      .height(50)
      .width(50)
      .backgroundColor('#50000000')
      .onClick(() => {
        if (this.playing) {
          this.avPlayer?.pause()
        } else {
          this.avPlayer?.play()
        }
      })


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
        if (this.screen_height > this.screen_width) {
          (await (this.windowClass)).setPreferredOrientation(window.Orientation.USER_ROTATION_LANDSCAPE)
        } else {
          (await (this.windowClass)).setPreferredOrientation(window.Orientation.USER_ROTATION_PORTRAIT)
        }
      })
    }
  }
}