import { AVPlayerController } from '../../controller/AVPlayerController'
import { MpvController } from '../../controller/MpvController/MpvController'
import { SpeedDataSource } from '../../utils/DataUtil'
import VideoInfoUtil from '../../utils/VideoInfoUtil'

@Component
export struct PlaybackSpeedMenuComponent {
  @State speedDataSource: SpeedDataSource = new SpeedDataSource([])
  @Consume('player') player: AVPlayerController | MpvController
  onSpeedChange = (_speed: number) => {
  }

  aboutToAppear(): void {
    this.speedDataSource = new SpeedDataSource(VideoInfoUtil.videoSpeedListAll)
  }

  build() {
    List() {
      LazyForEach(this.speedDataSource, (speedAvailable: number) => {
        ListItem() {
          Text(`${speedAvailable}x`).fontColor(this.player.speed && speedAvailable === this.player.speed ?
            $r('sys.color.white') : $r('app.color.text_color'))
        }
        .onClick(() => {
          this.onSpeedChange(speedAvailable) // 触发回调
        })
        .height(40)
        .backgroundColor(this.player.speed && speedAvailable === this.player.speed ?
          $r('app.color.main_color') : '')
        .borderRadius(16)
        .width('100%')
      }, (speedAvailable: number) => speedAvailable.toString())
    }.cachedCount(2)
    .width(100).height('auto').scrollBar(BarState.Off)
  }
}