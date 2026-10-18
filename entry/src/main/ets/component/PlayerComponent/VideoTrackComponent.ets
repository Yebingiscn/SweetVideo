import type { PlayerControllerInterface } from '../../controller/PlayerControllerFactory'
import { VideoTrack } from '../../controller/PlayerVideoTracks'
import ToolsUtil from '../../utils/ToolsUtil'
import { salmonLogger } from 'salmonlogger'

@ComponentV2
export struct VideoTrackComponent {
  @Require @Param player: PlayerControllerInterface

  aboutToAppear(): void {
    this.player.videoTracks.refresh().catch(() => {
      ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.video_tracks_read_failed').id))
    })
  }

  private label(track: VideoTrack): string {
    const details: string[] = []
    if (track.title) details.push(track.title)
    if (track.width > 0 && track.height > 0) details.push(`${track.width}×${track.height}`)
    if (track.fps > 0) details.push(`${Math.round(track.fps * 100) / 100} fps`)
    if (track.codec) details.push(track.codec)
    return `${track.id} : ${details.join(' · ') || ToolsUtil.getStringResource($r('app.string.video_track').id)}`
  }

  build() {
    Column({ space: 4 }) {
      Text($r('app.string.video_track')).fontSize(18).fontColor($r('app.color.text_color'))
      Scroll() {
        Column() {
          Repeat<VideoTrack>(this.player.videoTracks.tracks)
            .each((item: RepeatItem<VideoTrack>) => {
              Text(`${item.item.selected ? '✓ ' : ''}${this.label(item.item)}`)
                .fontSize(16)
                .fontColor(item.item.selected ? Color.White : $r('app.color.text_color'))
                .padding(12)
                .width('100%')
                .borderRadius(16)
                .backgroundColor(item.item.selected ? $r('app.color.main_color') : Color.Transparent)
                .enabled(!this.player.videoTracks.switching)
                .onClick(() => {
                  this.player.videoTracks.select(item.item.id).catch(() => {
                    salmonLogger.addLog('VideoTrack', '视频轨道切换未成功，保留引擎实际选择', true)
                    ToolsUtil.showToast(ToolsUtil.getStringResource(this.player.isMpvPlayer() ?
                      $r('app.string.video_track_switch_failed').id : $r('app.string.video_track_system_failed').id))
                  })
                })
            })
            .key((track: VideoTrack) => `${track.id}`)
        }.width('100%')
      }.constraintSize({ maxHeight: 320 }).width('100%')
      if (this.player.videoTracks.switching) {
        Text($r('app.string.video_track_switching')).fontSize(14).fontColor($r('app.color.text_color'))
      }
    }.width(300).padding(8)
  }
}
