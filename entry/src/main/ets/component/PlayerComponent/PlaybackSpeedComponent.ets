import { SpeedDataSource } from '../../utils/DataUtil';
import VideoInfoUtil from '../../utils/VideoInfoUtil';

@Component
export struct PlaybackSpeedMenuComponent {
  @State speedDataSource: SpeedDataSource = new SpeedDataSource([])
  @Link speed: number
  @Prop player: string
  onSpeedChange = (_speed: number) => {
  }

  aboutToAppear(): void {
    this.speedDataSource = new SpeedDataSource(VideoInfoUtil.getVideoSpeedList(this.player))
  }

  build() {
    List() {
      LazyForEach(this.speedDataSource, (speedAvailable: number) => {
        ListItem() {
          Text(`${speedAvailable}x`).fontColor(this.speed && speedAvailable === this.speed ?
            $r('sys.color.white') : $r('app.color.text_color'))
        }
        .onClick(() => {
          this.onSpeedChange(speedAvailable); // 触发回调
        })
        .height(40)
        .backgroundColor(this.speed && speedAvailable === this.speed ?
          $r('app.color.main_color') : '')
        .borderRadius(16)
        .width('100%')
      }, (speedAvailable: number) => speedAvailable.toString())
    }.cachedCount(2)
    .width(100).height('auto').scrollBar(BarState.Off)
  }
}