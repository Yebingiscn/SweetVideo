import { AVVolumePanel } from '@kit.AudioKit'
import { SymbolGlyphFancyModifier } from '../../utils/AttributeModifierUtil'
import VideoOperateUtil from '../../utils/VideoOperateUtil'

@Component
export struct VolumeSwipingComponent {
  @Link videoVolume: number

  build() {
    Stack() { //音量提示
      Column() {
        AVVolumePanel({
          volumeLevel: this.videoVolume,
          volumeParameter: {
            position: {
              x: 10000,
              y: 20000
            }
          }
        }).visibility(Visibility.None)
        SymbolGlyph($r('sys.symbol.speaker_wave_1'))
          .attributeModifier(new SymbolGlyphFancyModifier(23, '', ''))
          .fontColor(['#f0f0f0'])
        Slider({
          value: this.videoVolume,
          min: VideoOperateUtil.min_volume,
          max: VideoOperateUtil.max_volume,
          step: 0.1,
          style: SliderStyle.NONE,
          direction: Axis.Horizontal,
          reverse: false
        })
          .width(60)
          .height(30)
          .selectedColor('#e0e0e0')
          .trackColor(Color.Black)
          .trackThickness(40)
          .onChange((value) => {
            this.videoVolume = value
          })
      }
    }
    .padding({
      left: 25,
      right: 25,
      top: 10,
      bottom: 10
    })
    .borderRadius(1000)
    .backgroundColor('#30000000')
    .backdropBlur(100)
    .animation({ duration: 300, curve: Curve.Smooth })
  }
}