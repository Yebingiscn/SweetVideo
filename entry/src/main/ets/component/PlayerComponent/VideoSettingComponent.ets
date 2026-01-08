import { SymbolGlyphModifier } from '@kit.ArkUI'
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import { PathUtils } from '../../utils/PathUtils'
import TimeUtil from '../../utils/TimeUtil'
import ToolsUtil from '../../utils/ToolsUtil'
import VideoOperateUtil from '../../utils/VideoOperateUtil'
import { RepeatMode } from '../../common/enum/RepeatMode'
import { deviceInfo } from '@kit.BasicServicesKit'

@Component
export struct VideoSettingComponent {
  @Prop playTime: number
  @Prop nowPlaying: VideoMetadata
  @Prop videoMetaData: VideoMetadata[]
  @Link angle: number
  @Link repeatMode: RepeatMode
  @Link exitVideoTime: number
  @Link abCircleStatus: boolean
  @State startTime: string = '00:00'
  @State endTime: string = '00:00'
  @State pointA: string = '00:00'
  @State pointB: string = '00:00'
  forward_80_s = (_time: number) => {
  }
  onActiveEnhanceAudio = () => {
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

  aboutToAppear(): void {
    this.startTime = TimeUtil.convertMSToHHMMSS(this.nowPlaying.start_time)
    this.endTime = TimeUtil.convertMSToHHMMSS(this.nowPlaying.end_time)
    this.pointA = TimeUtil.convertMSToHHMMSS(this.nowPlaying.pointA)
    this.pointB = TimeUtil.convertMSToHHMMSS(this.nowPlaying.pointB)
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
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.camera')),
        content: '截图并保存'
      }).onClick(() => {
        this.captureScreen()
      })
      if (deviceInfo.sdkApiVersion >= 20) {
        MenuItem({
          symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.headphones')),
          content: '听视频'
        }).onClick(() => {
          this.toggleListenVideo()
        })
      }
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.trapezoid_and_line_vertical')),
        content: '屏幕镜像'
      }).onClick(() => {
        this.angle === 0 ? this.angle = 180 : this.angle = 0
      })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.fast_forward')),
        content: '前进 80s'
      }).onClick(() => {
        this.forward_80_s(this.playTime + 80 * 1000)
      })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.service')),
        content: '启用增强型音频解码（仅在放不出来声音时使用）'
      }).onClick(() => {
        this.onActiveEnhanceAudio()
      })
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
        this.repeatMode = RepeatMode.ONCE
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
        this.startTime = TimeUtil.convertMSToHHMMSS(this.playTime)
        VideoOperateUtil.saveVideoStartTime(this.playTime, this.nowPlaying, PathUtils.appContext!)
        ToolsUtil.showToast(this.nowPlaying.title + '成功设置片头时间为:' + TimeUtil.convertMSToHHMMSS(this.playTime))
        this.updateStarTime(this.playTime)
      })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.time_lapse')),
        content: '设置片尾时间：' + this.endTime,
      }).onClick(() => {
        this.endTime = TimeUtil.convertMSToHHMMSS(this.playTime)
        VideoOperateUtil.saveVideoEndTime(this.playTime, this.nowPlaying, PathUtils.appContext!)
        ToolsUtil.showToast(this.nowPlaying.title + '成功设置片尾时间为:' + TimeUtil.convertMSToHHMMSS(this.playTime))
        this.updateEndTime(this.playTime)
      })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.time_lapse')),
        content: '取消片头片尾时间'
      }).onClick(() => {
        this.startTime = TimeUtil.convertMSToHHMMSS(0)
        VideoOperateUtil.saveVideoStartTime(0, this.nowPlaying, PathUtils.appContext!)
        this.endTime = TimeUtil.convertMSToHHMMSS(this.nowPlaying.time)
        VideoOperateUtil.saveVideoEndTime(this.nowPlaying.time, this.nowPlaying, PathUtils.appContext!)
        ToolsUtil.showToast('取消片头片尾时间成功')
        this.updateStarTime(0)
        this.updateEndTime(this.nowPlaying.time)
      })
    }
  }

  @Builder
  ABMenuExtend() {
    Menu() {
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.time_lapse')),
        content: this.abCircleStatus ? '停止 AB 循环' : '启动 AB 循环'
      }).onClick(() => {
        this.abCircleStatus = !this.abCircleStatus
      })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.time_lapse')),
        content: '设置A点时间：' + this.pointA,
      }).onClick(() => {
        this.pointA = TimeUtil.convertMSToHHMMSS(this.playTime)
        VideoOperateUtil.saveVideoPointA(PathUtils.appContext!, this.nowPlaying, this.playTime)
        ToolsUtil.showToast(this.nowPlaying.title + '成功设置A点时间为:' + TimeUtil.convertMSToHHMMSS(this.playTime))
        this.updatePointATime(this.playTime)
      })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.time_lapse')),
        content: '设置B点时间：' + this.pointB,
      }).onClick(() => {
        this.pointB = TimeUtil.convertMSToHHMMSS(this.playTime)
        VideoOperateUtil.saveVideoPointB(PathUtils.appContext!, this.nowPlaying, this.playTime)
        ToolsUtil.showToast(this.nowPlaying.title + '成功设置B点时间为:' + TimeUtil.convertMSToHHMMSS(this.playTime))
        this.updatePointBTime(this.playTime)
      })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.time_lapse')),
        content: '取消AB点时间'
      }).onClick(() => {
        this.pointA = TimeUtil.convertMSToHHMMSS(0)
        VideoOperateUtil.saveVideoPointA(PathUtils.appContext!, this.nowPlaying, 0)
        this.pointB = TimeUtil.convertMSToHHMMSS(this.nowPlaying.time)
        VideoOperateUtil.saveVideoPointB(PathUtils.appContext!, this.nowPlaying, this.nowPlaying.time)
        ToolsUtil.showToast('取消AB点时间成功')
        this.updatePointATime(0)
        this.updatePointBTime(this.nowPlaying.time)
      })
    }
  }
}