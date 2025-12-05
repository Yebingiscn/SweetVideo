import { SymbolGlyphFancyModifier } from '../../common/AttributeModifierConfig'
import VideoOperateUtil from '../../utils/VideoOperateUtil'
import { AVVolumePanel } from '@kit.AudioKit'

class VolumeValue {
  videoVolume: number = 0
  videoVolumeShow: number = 0
  onSwipingVoice: boolean = false
}

@Builder
export function VolumeSwipingPanelBuilder(volumeValue: VolumeValue) {
  Stack() { //音量提示
    AVVolumePanel({
      volumeLevel: volumeValue.videoVolume,
      volumeParameter: {
        position: {
          x: -1,
          y: -1
        }
      }
    }).visibility(Visibility.None)
    if (volumeValue.onSwipingVoice) {
      Column() {
        SymbolGlyph(getVoiceIcon(volumeValue.videoVolume))
          .attributeModifier(new SymbolGlyphFancyModifier(23, '', ''))
          .fontColor(['#f0f0f0'])
        Slider({
          value: volumeValue.videoVolumeShow,
          min: VideoOperateUtil.min_volume,
          max: VideoOperateUtil.max_volume,
          step: 0.1,
          style: SliderStyle.NONE,
          direction: Axis.Horizontal,
          reverse: false
        })
          .width(60)
          .height(30)
          .selectedColor($r('app.color.main_color'))
          .trackColor(Color.Black)
          .trackThickness(40)
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
}

export function getVoiceIcon(videoVolume: number) {
  if (videoVolume <= VideoOperateUtil.min_volume) {
    return $r('sys.symbol.speaker_slash'); // 静音
  }
  if (videoVolume >= VideoOperateUtil.max_volume * 2 / 3) {
    return $r('sys.symbol.speaker_wave_3'); // 高音量
  }
  if (videoVolume >= VideoOperateUtil.max_volume * 1 / 3) {
    return $r('sys.symbol.speaker_wave_2'); // 中音量
  }
  return $r('sys.symbol.speaker_wave_1'); // 低音量
}