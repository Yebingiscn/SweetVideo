import { SymbolGlyphModifier } from '@kit.ArkUI'
import { RepeatMode } from '../../common/enum/RepeatMode'
import { VideoMetadataFromPlayer } from '../../interfaces/VideoMetadataFromPlayerInterface'
import { VideoMetadata } from '../../interfaces/VideoMetadataInterface'
import { PathUtils } from '../../utils/PathUtils'
import TimeUtil from '../../utils/TimeUtil'
import ToolsUtil from '../../utils/ToolsUtil'
import VideoOperateUtil from '../../utils/VideoOperateUtil'

@Component
export struct VideoSettingComponent {
  @Link playTime: number
  @Link nowPlaying: VideoMetadataFromPlayer
  @Link videoMetaData: VideoMetadata[]
  @Link repeatMode: RepeatMode
  onMirrorClick = () => {
  }

  build() {
    Menu() {
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
        this.onMirrorClick()
      })
      MenuItem({
        symbolStartIcon: this.getRepeatModeIcon(),
        content: this.getRepeatModeText()
      })
        .onClick(() => {
          // 循环切换播放模式：列表循环 -> 单曲循环 -> 随机播放 -> 列表循环
          switch (this.repeatMode) {
            case RepeatMode.LIST_LOOP:
              this.repeatMode = RepeatMode.SINGLE_LOOP
              break
            case RepeatMode.SINGLE_LOOP:
              this.repeatMode = RepeatMode.RANDOM
              break
            case RepeatMode.RANDOM:
              this.repeatMode = RepeatMode.LIST_LOOP
              break
          }
        })
    }
  }

  /**
   * 获取当前播放模式对应的图标
   * @returns 播放模式图标
   */
  private getRepeatModeIcon(): SymbolGlyphModifier {
    switch (this.repeatMode) {
      case RepeatMode.SINGLE_LOOP:
        return new SymbolGlyphModifier($r('sys.symbol.repeat_1'))
      case RepeatMode.RANDOM:
        return new SymbolGlyphModifier($r('sys.symbol.shuffle'))
      case RepeatMode.LIST_LOOP:
      default:
        return new SymbolGlyphModifier($r('sys.symbol.order_play'))
    }
  }

  /**
   * 获取当前播放模式对应的文本
   * @returns 播放模式文本
   */
  private getRepeatModeText(): string {
    switch (this.repeatMode) {
      case RepeatMode.SINGLE_LOOP:
        return '单曲循环'
      case RepeatMode.RANDOM:
        return '随机播放'
      case RepeatMode.LIST_LOOP:
      default:
        return '列表循环'
    }
  }
}