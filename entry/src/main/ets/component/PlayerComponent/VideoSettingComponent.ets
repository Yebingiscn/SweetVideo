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
  @Link circlePlay: boolean
  @Link nowPlaying: VideoMetadataFromPlayer
  @Link videoMetaData: VideoMetadata[]
  @State repeatMode: string = '列表循环'
  onMirrorClick = () => {
  }

  build() {
    Menu() {
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.time_lapse')),
        content: '设置片头时间'
      }).onClick(() => {
        VideoOperateUtil.saveVideoStartTime(this.playTime, this.nowPlaying, PathUtils.appContext!)
        ToolsUtil.showToast(this.nowPlaying.title + '成功设置片头时间为:' + TimeUtil.convertMSToMMSS(this.playTime))
      })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.time_lapse')),
        content: '设置片尾时间'
      }).onClick(() => {
        VideoOperateUtil.saveVideoEndTime(this.playTime, this.nowPlaying, PathUtils.appContext!)
        ToolsUtil.showToast(this.nowPlaying.title + '成功设置片尾时间为:' + TimeUtil.convertMSToMMSS(this.playTime))
      })
      MenuItem({
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.trapezoid_and_line_vertical')),
        content: '屏幕镜像'
      }).onClick(() => {
        this.onMirrorClick()
      })
      MenuItem({
        symbolStartIcon: this.circlePlay ? new SymbolGlyphModifier($r('sys.symbol.repeat_1')) :
          new SymbolGlyphModifier($r('sys.symbol.order_play')),
        content: this.repeatMode
      })
        .onClick(() => {
          this.circlePlay = !this.circlePlay
          this.circlePlay ? this.repeatMode = '单曲循环' : this.repeatMode = '列表循环'
        })
    }.onAppear(() => {
      this.circlePlay ? this.repeatMode = '单曲循环' : this.repeatMode = '列表循环'
    })
  }
}