import { SelectItemTextFancyModifier } from '../../utils/AttributeModifierUtil';
import { SpeedDataSource } from '../../utils/DataUtil';
import VideoInfoUtil from '../../utils/VideoInfoUtil';

@Component
export struct PlaybackSpeedMenuComponent {
  @State speedDataSource: SpeedDataSource = new SpeedDataSource([])
  @Prop speed: number;
  onSpeedChange = (_speed: number) => {
  }

  aboutToAppear(): void {
    this.speedDataSource = new SpeedDataSource(VideoInfoUtil.video_speed_list)
  }

  build() {
    List() {
      LazyForEach(this.speedDataSource, (speed: number) => {
        ListItem() {
          Text(`${speed}x`)
            .attributeModifier(new SelectItemTextFancyModifier(this.speed === speed))
        }.onClick(() => {
          this.onSpeedChange(speed); // 触发回调
        }).height(40)
      })
    }
    .width(100).height('auto').scrollBar(BarState.Off)
  }
}