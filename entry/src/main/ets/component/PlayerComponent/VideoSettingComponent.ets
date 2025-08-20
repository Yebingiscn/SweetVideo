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
    }
  }
}