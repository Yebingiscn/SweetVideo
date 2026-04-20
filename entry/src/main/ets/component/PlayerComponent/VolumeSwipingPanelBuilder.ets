import { SymbolGlyphFancyModifier } from '../../common/AttributeModifierConfig'
import VideoOperateUtil from '../../utils/VideoOperateUtil'
import { AVVolumePanel } from '@kit.AudioKit'

class VolumeValue {
  videoVolume: number = 0
  videoVolumeShow: number = 0
  onSwipingVoice: boolean = false
  playAreaHeight: number = 0
}

@Builder
export function VolumeSwipingPanelBuilder(volumeValue: VolumeValue) {
  // AVVolumePanel 必须保留，用于系统音量联动
  AVVolumePanel({
    volumeLevel: volumeValue.videoVolume,
    volumeParameter: {
      position: {
        x: -1,
        y: -1
      }
    }
  }).visibility(Visibility.None)

  // 自定义音量提示面板（扁平化布局）
  if (volumeValue.onSwipingVoice) {
    Row() {
      SymbolGlyph(getVoiceIcon(volumeValue.videoVolumeShow))
        .attributeModifier(new SymbolGlyphFancyModifier(23, '', ''))
        .fontColor(['#f0f0f0'])
      Slider({
        value: volumeValue.videoVolumeShow,
        min: VideoOperateUtil.minVolume,
        max: VideoOperateUtil.maxVolume,
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
    .offset({
      x: 0,
      y: -volumeValue.playAreaHeight / 2.5
    })
    .borderRadius(16)
    .backgroundColor('#30000000')
    .backdropBlur(100)
    .padding(5)
  }
}

export function getVoiceIcon(videoVolume: number) {
  if (videoVolume <= VideoOperateUtil.minVolume) {
    return $r('sys.symbol.speaker_slash') // 静音
  }
  if (videoVolume >= VideoOperateUtil.maxVolume * 2 / 3) {
    return $r('sys.symbol.speaker_wave_3') // 高音量
  }
  if (videoVolume >= VideoOperateUtil.maxVolume * 1 / 3) {
    return $r('sys.symbol.speaker_wave_2') // 中音量
  }
  return $r('sys.symbol.speaker_wave_1') // 低音量
}