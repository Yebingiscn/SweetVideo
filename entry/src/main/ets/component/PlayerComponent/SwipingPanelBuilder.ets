import { SymbolGlyphFancyModifier } from '../../common/AttributeModifierConfig'
import VideoOperateUtil from '../../utils/VideoOperateUtil'
import { AVVolumePanel } from '@kit.AudioKit'

class SwipingPanelValue {
  videoVolume: number = 0
  videoVolumeShow: number = 0
  onSwipingVoice: boolean = false
  onSwipingBrightness: boolean = false
  screenBrightness: number = 0
  playAreaHeight: number = 0
}

@Builder
export function SwipingPanelBuilder(value: SwipingPanelValue) {
  AVVolumePanel({
    volumeLevel: value.videoVolume,
    volumeParameter: {
      position: {
        x: -1,
        y: -1
      }
    }
  }).visibility(Visibility.None)

  if (value.onSwipingVoice || value.onSwipingBrightness) {
    Row() {
      if (value.onSwipingVoice) {
        SymbolGlyph(getVolumeIcon(value.videoVolumeShow))
          .attributeModifier(new SymbolGlyphFancyModifier(23, '', ''))
          .fontColor(['#f0f0f0'])
      } else {
        SymbolGlyph($r('sys.symbol.sun_max'))
          .attributeModifier(new SymbolGlyphFancyModifier(23, '', ''))
          .fontColor(['#f0f0f0'])
          .rotate({ angle: value.screenBrightness * 360 })
          .animation({ duration: 300, curve: Curve.Smooth })
      }
      Slider({
        value: value.onSwipingVoice ? value.videoVolumeShow : value.screenBrightness,
        min: value.onSwipingVoice ? VideoOperateUtil.minVolume : 0,
        max: value.onSwipingVoice ? VideoOperateUtil.maxVolume : 1,
        step: 0.1,
        style: SliderStyle.NONE,
        direction: Axis.Horizontal,
        reverse: false
      })
        .trackBorderRadius(16)
        .selectedColor($r('app.color.main_color'))
        .enableHapticFeedback(true)
        .width(160)
        .height(40)
        .trackThickness(40)
        .selectedBorderRadius(16)
        .padding({ left: 5 })
    }
    .animation({ duration: 300, curve: Curve.Friction })
    .offset({
      x: 0,
      y: -value.playAreaHeight / 2.5
    })
    .borderRadius(16)
    .backgroundColor('#30000000')
    .backdropBlur(100)
    .padding(5)
  }
}

export function getVolumeIcon(videoVolume: number) {
  if (videoVolume <= VideoOperateUtil.minVolume) {
    return $r('sys.symbol.speaker_slash')
  }
  if (videoVolume >= VideoOperateUtil.maxVolume * 2 / 3) {
    return $r('sys.symbol.speaker_wave_3')
  }
  if (videoVolume >= VideoOperateUtil.maxVolume * 1 / 3) {
    return $r('sys.symbol.speaker_wave_2')
  }
  return $r('sys.symbol.speaker_wave_1')
}