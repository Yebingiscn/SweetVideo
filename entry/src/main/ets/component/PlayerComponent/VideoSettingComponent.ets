import { SymbolGlyphModifier } from '@kit.ArkUI'
import { VideoMetadataFromPlayer } from '../../interfaces/VideoMetadataFromPlayerInterface'
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import { PathUtils } from '../../utils/PathUtils'
import TimeUtil from '../../utils/TimeUtil'
import ToolsUtil from '../../utils/ToolsUtil'
import VideoOperateUtil from '../../utils/VideoOperateUtil'

@Component
export struct VideoSettingComponent {
  @Link playTime: number
  @Prop nowPlaying: VideoMetadataFromPlayer
  @Link videoMetaData: VideoMetadata[]
  @Link angle: number
  forward_80_s = () => {
  }
  onActiveEnhanceAudio = () => {
  }
  closeAfter15min = () => {
  }
  closeAfter30min = () => {
  }
  closeAfter60min = () => {
  }
  closeAfterVideoEnd = () => {
  }
  closeAfterIsClose = () => {
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
        this.forward_80_s()
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
        ToolsUtil.showToast('设置成功，15分钟后自动关闭')
        this.closeAfter15min()
      })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.clock')),
        content: '30min'
      }).onClick(() => {
        ToolsUtil.showToast('设置成功，30分钟后自动关闭')
        this.closeAfter30min()
      })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.clock')),
        content: '60min'
      }).onClick(() => {
        ToolsUtil.showToast('设置成功，60分钟后自动关闭')
        this.closeAfter60min()
      })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.clock')),
        content: '播完本集'
      }).onClick(() => {
        ToolsUtil.showToast('设置成功，播完本集后自动关闭')
        this.closeAfterVideoEnd()
      })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.clock')),
        content: '不启用'
      }).onClick(() => {
        ToolsUtil.showToast('设置成功，已清除定时器')
        this.closeAfterIsClose()
      })
    }
  }
}