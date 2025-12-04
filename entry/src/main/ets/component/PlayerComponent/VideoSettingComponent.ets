import { SymbolGlyphModifier } from '@kit.ArkUI'
import { VideoMetadataFromPlayer } from '../../interfaces/VideoMetadataFromPlayerInterface'
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import { PathUtils } from '../../utils/PathUtils'
import TimeUtil from '../../utils/TimeUtil'
import ToolsUtil from '../../utils/ToolsUtil'
import VideoOperateUtil from '../../utils/VideoOperateUtil'
import { RepeatMode } from '../../common/enum/RepeatMode'

@Component
export struct VideoSettingComponent {
  @Prop playTime: number
  @Prop nowPlaying: VideoMetadataFromPlayer
  @Link videoMetaData: VideoMetadata[]
  @Link angle: number
  @Link repeatMode: RepeatMode
  @Link exitVideoTime: number
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

  build() {
    Menu() {
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.clock')),
        content: '定时器',
        builder: (): void => this.MenuExtend()
      })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.time_lapse')),
        content: '设置片头时间'
      }).onClick(() => {
        VideoOperateUtil.saveVideoStartTime(this.playTime, this.nowPlaying, PathUtils.appContext!)
        ToolsUtil.showToast(this.nowPlaying.title + '成功设置片头时间为:' + TimeUtil.convertMSToHHMMSS(this.playTime))
      })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.time_lapse')),
        content: '设置片尾时间'
      }).onClick(() => {
        VideoOperateUtil.saveVideoEndTime(this.playTime, this.nowPlaying, PathUtils.appContext!)
        ToolsUtil.showToast(this.nowPlaying.title + '成功设置片尾时间为:' + TimeUtil.convertMSToHHMMSS(this.playTime))
      })
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
  MenuExtend() {
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
        this.repeatMode = RepeatMode.SINGLE_PLAY
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
}