import { SelectItemFancyModifier, SelectItemTextFancyModifier } from '../utils/AttributeModifierUtil';
import VideoInfoUtil from '../utils/VideoInfoUtil';

@Component
export struct PlaybackSpeedMenuComponent {
  @Prop speed: number;
  onSpeedChange = (speed: number) => {
    console.log(speed.toString()); // 无实际作用，只是消除未使用警告
  }

  build() {
    Flex({ direction: FlexDirection.Column, justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center }) {
      ForEach(VideoInfoUtil.video_speed_list, (speed: number) => {
        Column() {
          Row() {
            Text(`${speed}x`)
              .attributeModifier(new SelectItemTextFancyModifier(this.speed === speed))
          }
          .width('100%')
          .height(40)
          .justifyContent(FlexAlign.Start)
          .align(Alignment.Center)
          .onClick(() => {
            this.onSpeedChange?.(speed); // 触发回调
          })
        }
        .attributeModifier(new SelectItemFancyModifier(this.speed === speed))
      })
    }
    .width(100)
  }
}