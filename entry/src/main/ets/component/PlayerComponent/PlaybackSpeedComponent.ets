import { SelectItemTextFancyModifier } from '../../utils/AttributeModifierUtil';
import VideoInfoUtil from '../../utils/VideoInfoUtil';

@Component
export struct PlaybackSpeedMenuComponent {
  @Prop speed: number;
  onSpeedChange = (_speed: number) => {
  }

  build() {
    List() {
      ForEach(VideoInfoUtil.video_speed_list, (speed: number) => {
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