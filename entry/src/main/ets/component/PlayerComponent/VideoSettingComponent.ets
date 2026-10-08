import VideoInfoUtil from '../../utils/VideoInfoUtil'
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
    this.endTime = TimeUtil.convertMSToHHMMSS(Math.max(0, VideoInfoUtil.getEndingPosition(this.player.nowPlaying)))
    this.pointA = TimeUtil.convertMSToHHMMSS(this.player.nowPlaying?.pointA)
    this.pointB = TimeUtil.convertMSToHHMMSS(this.player.nowPlaying?.pointB)
  }

  build() {
    Menu() {
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.clock')),
        content: $r('app.string.timer'),
        builder: (): void => this.TimerMenuExtend()
      })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.time_lapse')),
        content: $r('app.string.op_ed_time'),
        builder: (): void => this.OPEDMenuExtend()
      })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.time_lapse')),
        content: $r('app.string.ab_loop'),
        builder: (): void => this.ABMenuExtend()
      })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.fast_forward')),
        content: $r('app.string.forward_80s')
      }).onClick(() => {
        this.forward_80_s(this.player.playTime + 80 * 1000)
      })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.trapezoid_and_line_vertical')),
        content: $r('app.string.screen_mirror')
      }).onClick(() => {
        this.onScreenMirror()
      })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.arrow_left_arrow_right')),
        content: this.player.isMpvPlayer() ? $r('app.string.switch_to_system_player') : $r('app.string.switch_to_mpv_player')
      }).onClick(() => {
        this.onSwitchPlayerEngine(this.player.isMpvPlayer() ? PlayerEngine.AV_PLAYER : PlayerEngine.MPV_PLAYER)
      })

      if (this.player instanceof AVPlayerController) {
        MenuItem({
          symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.headphones')),
          content: $r('app.string.listen_video')
        }).onClick(() => {
          this.toggleListenVideo()
        })
      }
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.camera_master_ai')),
        content: this.player.superResolutionState ? $r('app.string.disable_super_resolution') : $r('app.string.enable_super_resolution'),
      }).onClick(() => {
        this.player.setSuperResolutionState(!this.player.superResolutionState)
      })
      if (this.player instanceof MpvController) {
        MenuItem({
          symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.doc_plaintext')),
          content: this.player.debugInfoVisible ? $r('app.string.hide_debug_info') : $r('app.string.show_debug_info'),
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
        ToolsUtil.showToast(ToolsUtil.getStringResourceArgs($r('app.string.timer_set_minutes').id, 15))
        this.closeAfter15min(15 * 60000)
      })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.clock')),
        content: '30min'
      }).onClick(() => {
        clearTimeout(this.exitVideoTime)
        ToolsUtil.showToast(ToolsUtil.getStringResourceArgs($r('app.string.timer_set_minutes').id, 30))
        this.closeAfter30min(30 * 60000)
      })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.clock')),
        content: '60min'
      }).onClick(() => {
        clearTimeout(this.exitVideoTime)
        ToolsUtil.showToast(ToolsUtil.getStringResourceArgs($r('app.string.timer_set_minutes').id, 60))
        this.closeAfter60min(60 * 60000)
      })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.clock')),
        content: $r('app.string.play_episode_end')
      }).onClick(() => {
        clearTimeout(this.exitVideoTime)
        ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.timer_set_episode_end').id))
        this.setRepeatModeToOnce()
      })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.clock')),
        content: $r('app.string.not_enabled')
      }).onClick(() => {
        clearTimeout(this.exitVideoTime)
        ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.timer_cleared').id))
      })
    }
  }

  @Builder
  OPEDMenuExtend() {
    Menu() {
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.time_lapse')),
        content: $r('app.string.set_intro_time', this.startTime),
      }).onClick(() => {
        this.startTime = TimeUtil.convertMSToHHMMSS(this.player.playTime)
        VideoOperateUtil.saveVideoStartTime(this.player.playTime, this.player.nowPlaying!, PathUtils.appContext!)
        ToolsUtil.showToast(this.player.nowPlaying?.title + ToolsUtil.getStringResource($r('app.string.success_set_intro_time').id) +
          TimeUtil.convertMSToHHMMSS(this.player.playTime))
        this.updateStarTime(this.player.playTime)
      })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.time_lapse')),
        content: $r('app.string.set_outro_time', this.endTime),
      }).onClick(() => {
        this.endTime = TimeUtil.convertMSToHHMMSS(this.player.playTime)
        VideoOperateUtil.saveVideoEndTime(this.player.playTime, this.player.nowPlaying!, PathUtils.appContext!)
        ToolsUtil.showToast(this.player?.nowPlaying?.title + ToolsUtil.getStringResource($r('app.string.success_set_outro_time').id) +
          TimeUtil.convertMSToHHMMSS(this.player.playTime))
        this.updateEndTime(this.player.playTime)
      })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.time_lapse')),
        content: $r('app.string.cancel_op_ed_time')
      }).onClick(() => {
        this.startTime = TimeUtil.convertMSToHHMMSS(0)
        VideoOperateUtil.saveVideoStartTime(0, this.player.nowPlaying!, PathUtils.appContext!)
        this.endTime = TimeUtil.convertMSToHHMMSS(this.player.nowPlaying?.time)
        VideoOperateUtil.saveVideoEndTime(this.player!.nowPlaying!.time, this.player.nowPlaying!, PathUtils.appContext!)
        ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.cancel_op_ed_time_success').id))
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
        content: this.player.abCircleStatus ? $r('app.string.stop_ab_loop') : $r('app.string.start_ab_loop')
      }).onClick(() => {
        this.onABCircleStatusClick()
      })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.time_lapse')),
        content: $r('app.string.set_point_a_time', this.pointA),
      }).onClick(() => {
        this.pointA = TimeUtil.convertMSToHHMMSS(this.player.playTime)
        VideoOperateUtil.saveVideoPointA(PathUtils.appContext!, this.player.nowPlaying!, this.player.playTime)
        ToolsUtil.showToast(this.player.nowPlaying?.title + ToolsUtil.getStringResource($r('app.string.success_set_point_a_time').id) +
          TimeUtil.convertMSToHHMMSS(this.player.playTime))
        this.updatePointATime(this.player.playTime)
      })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.time_lapse')),
        content: $r('app.string.set_point_b_time', this.pointB),
      }).onClick(() => {
        this.pointB = TimeUtil.convertMSToHHMMSS(this.player.playTime)
        VideoOperateUtil.saveVideoPointB(PathUtils.appContext!, this.player.nowPlaying!, this.player.playTime)
        ToolsUtil.showToast(this.player?.nowPlaying?.title + ToolsUtil.getStringResource($r('app.string.success_set_point_b_time').id) +
          TimeUtil.convertMSToHHMMSS(this.player.playTime))
        this.updatePointBTime(this.player.playTime)
      })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.time_lapse')),
        content: $r('app.string.cancel_ab_time')
      }).onClick(() => {
        this.pointA = TimeUtil.convertMSToHHMMSS(0)
        VideoOperateUtil.saveVideoPointA(PathUtils.appContext!, this.player.nowPlaying!, 0)
        this.pointB = TimeUtil.convertMSToHHMMSS(this.player.nowPlaying!.time)
        VideoOperateUtil.saveVideoPointB(PathUtils.appContext!, this.player.nowPlaying!, this.player.nowPlaying!.time)
        ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.cancel_ab_time_success').id))
        this.updatePointATime(0)
        this.updatePointBTime(this.player.nowPlaying!.time)
      })
    }
  }
}
