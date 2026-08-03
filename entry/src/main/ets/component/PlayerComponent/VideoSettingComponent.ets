import { PlayerControllerFactory, PlayerControllerInterface } from '../../controller/PlayerControllerFactory'
import { AVPlayerController } from '../../controller/AVPlayerController/AVPlayerController'
import { MpvController } from '../../controller/MpvController/MpvController'
import { PathUtils } from '../../utils/PathUtils'
import TimeUtil from '../../utils/TimeUtil'
import ToolsUtil from '../../utils/ToolsUtil'
import VideoOperateUtil from '../../utils/VideoOperateUtil'
import { SymbolGlyphModifier } from '@kit.ArkUI'
import { PlayerEngine } from '../../common/NavigationCommon'

@ComponentV2
export struct VideoSettingComponent {
  @Param exitVideoTime: number = 0
  @Local startTime: string = '00:00'
  @Local endTime: string = '00:00'
  @Local pointA: string = '00:00'
  @Local pointB: string = '00:00'
  @Consumer('player') player: PlayerControllerInterface =
    PlayerControllerFactory.createAVPlayerController() as PlayerControllerInterface
  @Event forward_80_s: (_time: number) => void = () => {
  }
  @Event closeAfter15min: (_time: number) => void = () => {
  }
  @Event closeAfter30min: (_time: number) => void = () => {
  }
  @Event closeAfter60min: (_time: number) => void = () => {
  }
  @Event toggleListenVideo: () => void = () => {
  }
  @Event captureScreen: () => void = () => {
  }
  @Event updateStarTime: (_time: number) => void = () => {
  }
  @Event updateEndTime: (_time: number) => void = () => {
  }
  @Event updatePointATime: (_time: number) => void = () => {
  }
  @Event updatePointBTime: (_time: number) => void = () => {
  }
  @Event onScreenMirror: () => void = () => {
  }
  @Event setRepeatModeToOnce: () => void = () => {
  }
  @Event onABCircleStatusClick: () => void = () => {
  }
  @Event onSwitchPlayerEngine: (_targetEngine: string) => void = () => {
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
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.arrow_left_arrow_right')),
        content: this.player.isMpvPlayer() ? '切换到系统播放器' : '切换到 MPV 播放器'
      }).onClick(() => {
        this.onSwitchPlayerEngine(this.player.isMpvPlayer() ? PlayerEngine.AV_PLAYER : PlayerEngine.MPV_PLAYER)
      })

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
          symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.camera_master_ai')),
          content: this.player.superResolutionState ? '关闭视频超分辨率' : '开启视频超分辨率',
        }).onClick(() => {
          if (this.player instanceof AVPlayerController) {
            this.player.setSuperResolutionState(!this.player.superResolutionState)
          }
        })
      }
      if (this.player instanceof MpvController) {
        MenuItem({
          symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.doc_plaintext')),
          content: this.player.debugInfoVisible ? '关闭调试信息' : '显示调试信息',
        }).onClick(() => {
          if (this.player instanceof MpvController) {
            this.player.toggleDebugInfo()
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
      }).onClick(() => {
        this.startTime = TimeUtil.convertMSToHHMMSS(this.player.playTime)
        VideoOperateUtil.saveVideoStartTime(this.player.playTime, this.player.nowPlaying!, PathUtils.appContext!)
        ToolsUtil.showToast(this.player.nowPlaying?.title + '成功设置片头时间为:' +
          TimeUtil.convertMSToHHMMSS(this.player.playTime))
        this.updateStarTime(this.player.playTime)
      })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.time_lapse')),
        content: '设置片尾时间：' + this.endTime,
      }).onClick(() => {
        this.endTime = TimeUtil.convertMSToHHMMSS(this.player.playTime)
        VideoOperateUtil.saveVideoEndTime(this.player.playTime, this.player.nowPlaying!, PathUtils.appContext!)
        ToolsUtil.showToast(this.player?.nowPlaying?.title + '成功设置片尾时间为:' +
          TimeUtil.convertMSToHHMMSS(this.player.playTime))
        this.updateEndTime(this.player.playTime)
      })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.time_lapse')),
        content: '取消片头片尾时间'
      }).onClick(() => {
        this.startTime = TimeUtil.convertMSToHHMMSS(0)
        VideoOperateUtil.saveVideoStartTime(0, this.player.nowPlaying!, PathUtils.appContext!)
        this.endTime = TimeUtil.convertMSToHHMMSS(this.player.nowPlaying?.time)
        VideoOperateUtil.saveVideoEndTime(this.player!.nowPlaying!.time, this.player.nowPlaying!, PathUtils.appContext!)
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
      }).onClick(() => {
        this.pointA = TimeUtil.convertMSToHHMMSS(this.player.playTime)
        VideoOperateUtil.saveVideoPointA(PathUtils.appContext!, this.player.nowPlaying!, this.player.playTime)
        ToolsUtil.showToast(this.player.nowPlaying?.title + '成功设置A点时间为:' +
          TimeUtil.convertMSToHHMMSS(this.player.playTime))
        this.updatePointATime(this.player.playTime)
      })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.time_lapse')),
        content: '设置B点时间：' + this.pointB,
      }).onClick(() => {
        this.pointB = TimeUtil.convertMSToHHMMSS(this.player.playTime)
        VideoOperateUtil.saveVideoPointB(PathUtils.appContext!, this.player.nowPlaying!, this.player.playTime)
        ToolsUtil.showToast(this.player?.nowPlaying?.title + '成功设置B点时间为:' +
          TimeUtil.convertMSToHHMMSS(this.player.playTime))
        this.updatePointBTime(this.player.playTime)
      })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.time_lapse')),
        content: '取消AB点时间'
      }).onClick(() => {
        this.pointA = TimeUtil.convertMSToHHMMSS(0)
        VideoOperateUtil.saveVideoPointA(PathUtils.appContext!, this.player.nowPlaying!, 0)
        this.pointB = TimeUtil.convertMSToHHMMSS(this.player.nowPlaying!.time)
        VideoOperateUtil.saveVideoPointB(PathUtils.appContext!, this.player.nowPlaying!, this.player.nowPlaying!.time)
        ToolsUtil.showToast('取消AB点时间成功')
        this.updatePointATime(0)
        this.updatePointBTime(this.player.nowPlaying!.time)
      })
    }
  }
}
