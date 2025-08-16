import { SelectItemTextFancyModifier } from '../../utils/AttributeModifierUtil';
import { SpeedDataSource } from '../../utils/DataUtil';
import VideoInfoUtil from '../../utils/VideoInfoUtil';

@Component
export struct PlaybackSpeedMenuComponent {
  @State speedDataSource: SpeedDataSource = new SpeedDataSource([])
  @Prop speed: number
  onSpeedChange = (_speed: number) => {
  }

  aboutToAppear(): void {
    this.speedDataSource = new SpeedDataSource(VideoInfoUtil.video_speed_list)
  }

  build() {
    List() {
      LazyForEach(this.speedDataSource, (speedAvailable: number) => {
        PlaybackSpeedItemComponent({
          speedAvailable: speedAvailable,
          speedSelected: this.speed
        }).onClick(() => {
          this.onSpeedChange(speedAvailable); // 触发回调
        }).height(40)
      })
    }.cachedCount(2)
    .width(100).height('auto').scrollBar(BarState.Off)
  }
}

@Reusable
@Component
export struct PlaybackSpeedItemComponent {
  @Link speedSelected: number
  @Prop speedAvailable: number

  build() {
    ListItem() {
      Text(`${this.speedAvailable}x`)
        .attributeModifier(new SelectItemTextFancyModifier(this.speedAvailable === this.speedSelected))
    }
  }
}