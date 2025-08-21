import { AVVolumePanel } from '@kit.AudioKit'
import VideoOperateUtil from '../../utils/VideoOperateUtil'

@Component
export struct VolumeButtonComponent {
  @Prop volume: number
  onChange = (_value: number) => {
  }

  build() {
    Flex({ direction: FlexDirection.Column, justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center }) {
      Row() {
        AVVolumePanel({
          volumeLevel: this.volume,
          volumeParameter: {
            position: {
              x: -1,
              y: -1
            }
          }
        })
      }.visibility(Visibility.None)

      Row() {
        Slider({
          value: this.volume,
          min: VideoOperateUtil.min_volume,
          max: VideoOperateUtil.max_volume,
          step: 0.1,
          style: SliderStyle.NONE,
          direction: Axis.Vertical,
          reverse: true
        })
          .width(40)
          .height(160)
          .selectedColor('#e0e0e0')
          .trackColor(Color.Black)
          .trackThickness(40)
          .onChange((value) => {
            this.onChange(value)
          })
      }
    }.width(40)
  }
}