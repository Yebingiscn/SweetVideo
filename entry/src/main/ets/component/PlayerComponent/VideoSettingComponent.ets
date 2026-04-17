import { AVPlayerController } from '../../controller/AVPlayerController'
import { MpvController } from '../../controller/MpvController/MpvController'
import { PathUtils } from '../../utils/PathUtils'
import TimeUtil from '../../utils/TimeUtil'
import ToolsUtil from '../../utils/ToolsUtil'
import VideoOperateUtil from '../../utils/VideoOperateUtil'
import { SymbolGlyphModifier } from '@kit.ArkUI'

@Component
export struct VideoSettingComponent {
  @Link exitVideoTime: number
  @State startTime: string = '00:00'
  @State endTime: string = '00:00'
  @State pointA: string = '00:00'
  @State pointB: string = '00:00'
  @Consume('player') player: AVPlayerController | MpvController
  forward_80_s = (_time: number) => {
  }
  closeAfter15min = (_time: number) => {
  }
  closeAfter30min = (_time: number) => {
  }
  closeAfter60min = (_time: number) => {
  }
  toggleListenVideo = () => {
  }
  captureScreen = () => {
  }
  updateStarTime = (_time: number) => {
  }
  updateEndTime = (_time: number) => {
  }
  updatePointATime = (_time: number) => {
  }
  updatePointBTime = (_time: number) => {
  }
  onScreenMirror = () => {
  }
  setRepeatModeToOnce = () => {
  }
  onABCircleStatusClick = () => {
  }

  aboutToAppear(): void {
    this.startTime = TimeUtil.convertMSToHHMMSS(this.player.nowPlaying?.start_time)
    this.endTime = TimeUtil.convertMSToHHMMSS(this.player.nowPlaying?.end_time)
    this.pointA = TimeUtil.convertMSToHHMMSS(this.player.nowPlaying?.pointA)
    this.pointB = TimeUtil.convertMSToHHMMSS(this.player.nowPlaying?.pointB)
  }

  build() {
    Menu() {
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.clock')),
        content: '定时器',
        builder: (): void => this.TimerMenuExtend()
      })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.time_lapse')),
        content: '片头片尾时间',
        builder: (): void => this.OPEDMenuExtend()
      })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.time_lapse')),
        content: 'AB循环',
        builder: (): void => this.ABMenuExtend()
      })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.fast_forward')),
        content: '前进 80s'
      }).onClick(() => {
        this.forward_80_s(this.player.playTime + 80 * 1000)
      })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.camera')),
        content: '截图并保存'
      }).onClick(() => {
        this.captureScreen()
      })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.trapezoid_and_line_vertical')),
        content: '屏幕镜像'
      }).onClick(() => {
        this.onScreenMirror()
      })
      if (this.player instanceof AVPlayerController) {
        MenuItem({
          symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.time_lapse')),
          content: '响度调节',
          builder: (): void => this.VolumeLoudnessGainBuilder()
        })
      }
      if (this.player instanceof AVPlayerController) {
        MenuItem({
          symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.headphones')),
          content: '听视频'
        }).onClick(() => {
          this.toggleListenVideo()
        })
      }
      if (this.player instanceof AVPlayerController) {
        MenuItem({
          symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.time_lapse')),
          content: this.player.superResolutionState ? '关闭视频超分辨率' : '开启视频超分辨率',
        }).onClick(() => {
          if (this.player instanceof AVPlayerController) {
            this.player.setSuperResolutionState(!this.player.superResolutionState)
          }
        })
      }
    }
  }

  @Builder
  TimerMenuExtend() {
    Menu() {
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.clock')),
        content: '15min'
      }).onClick(() => {
        clearTimeout(this.exitVideoTime)
        ToolsUtil.showToast('设置成功，15分钟后自动关闭')
        this.closeAfter15min(15 * 60000)
      })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.clock')),
        content: '30min'
      }).onClick(() => {
        clearTimeout(this.exitVideoTime)
        ToolsUtil.showToast('设置成功，30分钟后自动关闭')
        this.closeAfter30min(30 * 60000)
      })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.clock')),
        content: '60min'
      }).onClick(() => {
        clearTimeout(this.exitVideoTime)
        ToolsUtil.showToast('设置成功，60分钟后自动关闭')
        this.closeAfter60min(60 * 60000)
      })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.clock')),
        content: '播完本集'
      }).onClick(() => {
        clearTimeout(this.exitVideoTime)
        ToolsUtil.showToast('设置成功，播完本集后自动关闭')
        this.setRepeatModeToOnce()
      })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.clock')),
        content: '不启用'
      }).onClick(() => {
        clearTimeout(this.exitVideoTime)
        ToolsUtil.showToast('设置成功，已清除定时器')
      })
    }
  }

  @Builder
  OPEDMenuExtend() {
    Menu() {
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.time_lapse')),
        content: '设置片头时间：' + this.startTime,
      // ORM 改造：所有 VideoOperateUtil.save* 方法已改为 async，确保片头/片尾/AB 点等数据正确写入数据库
      }).onClick(async () => {
        this.startTime = TimeUtil.convertMSToHHMMSS(this.player.playTime)
        await VideoOperateUtil.saveVideoStartTime(this.player.playTime, this.player.nowPlaying!, PathUtils.appContext!)
        ToolsUtil.showToast(this.player.nowPlaying?.title + '成功设置片头时间为:' +
          TimeUtil.convertMSToHHMMSS(this.player.playTime))
        this.updateStarTime(this.player.playTime)
      })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.time_lapse')),
        content: '设置片尾时间：' + this.endTime,
      }).onClick(async () => {
        this.endTime = TimeUtil.convertMSToHHMMSS(this.player.playTime)
        await VideoOperateUtil.saveVideoEndTime(this.player.playTime, this.player.nowPlaying!, PathUtils.appContext!)
        ToolsUtil.showToast(this.player?.nowPlaying?.title + '成功设置片尾时间为:' +
          TimeUtil.convertMSToHHMMSS(this.player.playTime))
        this.updateEndTime(this.player.playTime)
      })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.time_lapse')),
        content: '取消片头片尾时间'
      }).onClick(async () => {
        this.startTime = TimeUtil.convertMSToHHMMSS(0)
        await VideoOperateUtil.saveVideoStartTime(0, this.player.nowPlaying!, PathUtils.appContext!)
        this.endTime = TimeUtil.convertMSToHHMMSS(this.player.nowPlaying?.time)
        await VideoOperateUtil.saveVideoEndTime(this.player!.nowPlaying!.time, this.player.nowPlaying!, PathUtils.appContext!)
        ToolsUtil.showToast('取消片头片尾时间成功')
        this.updateStarTime(0)
        this.updateEndTime(this.player.nowPlaying!.time)
      })
    }
  }

  @Builder
  ABMenuExtend() {
    Menu() {
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.time_lapse')),
        content: this.player.abCircleStatus ? '停止 AB 循环' : '启动 AB 循环'
      }).onClick(() => {
        this.onABCircleStatusClick()
      })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.time_lapse')),
        content: '设置A点时间：' + this.pointA,
      }).onClick(async () => {
        this.pointA = TimeUtil.convertMSToHHMMSS(this.player.playTime)
        await VideoOperateUtil.saveVideoPointA(PathUtils.appContext!, this.player.nowPlaying!, this.player.playTime)
        ToolsUtil.showToast(this.player.nowPlaying?.title + '成功设置A点时间为:' +
          TimeUtil.convertMSToHHMMSS(this.player.playTime))
        this.updatePointATime(this.player.playTime)
      })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.time_lapse')),
        content: '设置B点时间：' + this.pointB,
      }).onClick(async () => {
        this.pointB = TimeUtil.convertMSToHHMMSS(this.player.playTime)
        await VideoOperateUtil.saveVideoPointB(PathUtils.appContext!, this.player.nowPlaying!, this.player.playTime)
        ToolsUtil.showToast(this.player?.nowPlaying?.title + '成功设置B点时间为:' +
          TimeUtil.convertMSToHHMMSS(this.player.playTime))
        this.updatePointBTime(this.player.playTime)
      })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.time_lapse')),
        content: '取消AB点时间'
      }).onClick(async () => {
        this.pointA = TimeUtil.convertMSToHHMMSS(0)
        await VideoOperateUtil.saveVideoPointA(PathUtils.appContext!, this.player.nowPlaying!, 0)
        this.pointB = TimeUtil.convertMSToHHMMSS(this.player.nowPlaying!.time)
        await VideoOperateUtil.saveVideoPointB(PathUtils.appContext!, this.player.nowPlaying!, this.player.nowPlaying!.time)
        ToolsUtil.showToast('取消AB点时间成功')
        this.updatePointATime(0)
        this.updatePointBTime(this.player.nowPlaying!.time)
      })
    }
  }

  @Builder
  VolumeLoudnessGainBuilder() {
    if (this.player instanceof AVPlayerController) {
      Column() {
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.undo'))
            .fontSize(20)
            .fontColor([$r('app.color.text_color')])
        }
        .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.8 })
        .height(40)
        .width(80)
        .backgroundColor($r('app.color.start_window_background_blur'))
        .backdropBlur(150)
        .onClick(() => {
          if (this.player instanceof AVPlayerController) {
            this.player.setLoudnessGain(0)
          }
        })

        Slider({
          value: this.player.volumeLoudnessGain,
          min: -90,
          max: 24,
          step: 1,
          style: SliderStyle.NONE,
          direction: Axis.Vertical,
          reverse: true
        })
          .onChange((value) => {
            if (this.player instanceof AVPlayerController) {
              this.player.setLoudnessGain(value)
            }
          })
          .selectedColor($r('app.color.main_color'))
          .enableHapticFeedback(true)
          .width(40)
          .height(160)
          .trackThickness(40)
          .selectedBorderRadius(16)
          .padding({ top: 5 })
      }.width(40).backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THIN).borderRadius(16)
    }
  }
}