import { LightMaterialModifier } from '../../common/AttributeModifierConfig'
import {
  PlaybackProgressMarker,
  PlaybackRangeMarker,
  PlaybackRangeMarkerLabel,
  PLAYBACK_SLIDER_BLOCK_SIZE,
  PLAYBACK_SLIDER_TRACK_INSET,
  PLAYBACK_SLIDER_TRACK_THICKNESS,
  playbackRangeMarkerLabels,
  playbackRangeMarkerLabelWidth,
  playbackRangeMarkerPosition,
  playbackRangeMarkers
} from './PlaybackRangeMarkers'

export { PlaybackProgressMarker } from './PlaybackRangeMarkers'

export interface AnimatedPlaybackTimeBuilderParams {
  playTime: number
  totalTime: number
  fontSize?: number
  fontColor?: ResourceColor
  textOpacity?: number
}

@Builder
export function AnimatedPlaybackTimeBuilder(params: AnimatedPlaybackTimeBuilderParams) {
  Row() {
    if (params.totalTime > 0) {
      if (showHours(params)) {
        Text(Math.floor(currentSeconds(params) / 3600).toString().padStart(2, '0'))
          .fontWeight(FontWeight.Medium)
          .fontSize(params.fontSize ?? 16)
          .fontColor(params.fontColor ?? Color.White)
          .opacity(params.textOpacity ?? 0.9)
          .textShadow({ color: Color.Black, type: ShadowType.BLUR, radius: 4 })
          .contentTransition({ flipDirection: FlipDirection.DOWN, enableBlur: true })
        Text(':')
          .fontWeight(FontWeight.Medium)
          .fontSize(params.fontSize ?? 16)
          .fontColor(params.fontColor ?? Color.White)
          .opacity(params.textOpacity ?? 0.9)
      }
      Text(Math.floor((currentSeconds(params) % 3600) / 60).toString().padStart(2, '0'))
        .fontWeight(FontWeight.Medium)
        .fontSize(params.fontSize ?? 16)
        .fontColor(params.fontColor ?? Color.White)
        .opacity(params.textOpacity ?? 0.9)
        .textShadow({ color: Color.Black, type: ShadowType.BLUR, radius: 4 })
        .contentTransition({ flipDirection: FlipDirection.DOWN, enableBlur: true })
      Text(':')
        .fontWeight(FontWeight.Medium)
        .fontSize(params.fontSize ?? 16)
        .fontColor(params.fontColor ?? Color.White)
        .opacity(params.textOpacity ?? 0.9)
      Text((currentSeconds(params) % 60).toString().padStart(2, '0'))
        .fontWeight(FontWeight.Medium)
        .fontSize(params.fontSize ?? 16)
        .fontColor(params.fontColor ?? Color.White)
        .opacity(params.textOpacity ?? 0.9)
        .textShadow({ color: Color.Black, type: ShadowType.BLUR, radius: 4 })
        .contentTransition({ flipDirection: FlipDirection.DOWN, enableBlur: true })
      Text(' / ')
        .fontWeight(FontWeight.Medium)
        .fontSize(params.fontSize ?? 16)
        .fontColor(params.fontColor ?? Color.White)
        .opacity(params.textOpacity ?? 0.9)
      if (showHours(params)) {
        Text(Math.floor(totalSeconds(params) / 3600).toString().padStart(2, '0'))
          .fontWeight(FontWeight.Medium)
          .fontSize(params.fontSize ?? 16)
          .fontColor(params.fontColor ?? Color.White)
          .opacity(params.textOpacity ?? 0.9)
          .textShadow({ color: Color.Black, type: ShadowType.BLUR, radius: 4 })
          .contentTransition({ flipDirection: FlipDirection.DOWN, enableBlur: true })
        Text(':')
          .fontWeight(FontWeight.Medium)
          .fontSize(params.fontSize ?? 16)
          .fontColor(params.fontColor ?? Color.White)
          .opacity(params.textOpacity ?? 0.9)
      }
      Text(Math.floor((totalSeconds(params) % 3600) / 60).toString().padStart(2, '0'))
        .fontWeight(FontWeight.Medium)
        .fontSize(params.fontSize ?? 16)
        .fontColor(params.fontColor ?? Color.White)
        .opacity(params.textOpacity ?? 0.9)
        .textShadow({ color: Color.Black, type: ShadowType.BLUR, radius: 4 })
        .contentTransition({ flipDirection: FlipDirection.DOWN, enableBlur: true })
      Text(':')
        .fontWeight(FontWeight.Medium)
        .fontSize(params.fontSize ?? 16)
        .fontColor(params.fontColor ?? Color.White)
        .opacity(params.textOpacity ?? 0.9)
      Text((totalSeconds(params) % 60).toString().padStart(2, '0'))
        .fontWeight(FontWeight.Medium)
        .fontSize(params.fontSize ?? 16)
        .fontColor(params.fontColor ?? Color.White)
        .opacity(params.textOpacity ?? 0.9)
        .textShadow({ color: Color.Black, type: ShadowType.BLUR, radius: 4 })
        .contentTransition({ flipDirection: FlipDirection.DOWN, enableBlur: true })
    } else {
      Text('--:-- / --:--')
        .fontWeight(FontWeight.Medium)
        .fontSize(params.fontSize ?? 16)
        .fontColor(params.fontColor ?? Color.White)
        .opacity(params.textOpacity ?? 0.9)
        .textShadow({ color: Color.Black, type: ShadowType.BLUR, radius: 4 })
    }
  }
}

function currentSeconds(params: AnimatedPlaybackTimeBuilderParams): number {
  return Math.floor(Math.min(Math.max(params.playTime, 0), params.totalTime) / 1000)
}

function totalSeconds(params: AnimatedPlaybackTimeBuilderParams): number {
  return Math.floor(Math.max(params.totalTime, 0) / 1000)
}

function showHours(params: AnimatedPlaybackTimeBuilderParams): boolean {
  return params.totalTime >= 3600000
}

export interface PlaybackProgressSliderParams {
  height?: number
  playTime: number
  totalTime: number
  markers?: PlaybackProgressMarker[]
  onSliderChange?: (value: number, mode?: SliderChangeMode) => void
  onSliderTouch?: (event: TouchEvent) => void
}

@Builder
export function PlaybackProgressSliderBuilder($$: PlaybackProgressSliderParams) {
  Stack({ alignContent: Alignment.TopStart }) {
    Slider({
      value: Math.max(0, Math.min($$.playTime, Math.max($$.totalTime, 0))),
      min: 0,
      max: Math.max($$.totalTime, 1),
      style: SliderStyle.InSet
    })
      .selectedBorderRadius(16)
      .trackThickness(PLAYBACK_SLIDER_TRACK_THICKNESS)
      .blockSize({ width: PLAYBACK_SLIDER_BLOCK_SIZE, height: PLAYBACK_SLIDER_BLOCK_SIZE })
      .onChange((value: number, mode: SliderChangeMode) => $$.onSliderChange?.(value, mode))
      .onTouch((event: TouchEvent) => $$.onSliderTouch?.(event))
      .animation({ duration: 100, curve: Curve.Smooth })
      .selectedColor('#e0e0e0')
      .blockColor(Color.White)
      .attributeModifier(new LightMaterialModifier())
      .height($$.height ?? 40)
      .width('100%')
      .opacity(0.9)

    if (playbackRangeMarkers($$.markers, $$.totalTime).length > 0) {
      Stack({ alignContent: Alignment.TopStart }) {
        ForEach(playbackRangeMarkers($$.markers, $$.totalTime), (marker: PlaybackRangeMarker) => {
          Rect()
            .width(marker.kind === 'chapter' ? 1 : 2)
            .height(marker.kind === 'chapter' ? 8 : 12)
            .fill(marker.color)
            .stroke('#99000000')
            .strokeWidth(0.5)
            .position({ x: playbackRangeMarkerPosition(marker.ratio), y: '50%' })
            .translate({ x: marker.kind === 'chapter' ? -0.5 : -1, y: marker.kind === 'chapter' ? -4 : -6 })
            .hitTestBehavior(HitTestMode.Transparent)
        }, (marker: PlaybackRangeMarker): string =>
          `${marker.key}:${marker.timeMs}:${marker.label}:${JSON.stringify(marker.color)}:${marker.ratio}:${marker.kind ?? 'range'}`)
        ForEach(playbackRangeMarkerLabels(playbackRangeMarkers($$.markers, $$.totalTime)),
          (label: PlaybackRangeMarkerLabel) => {
            Text(label.label)
              .fontSize(10)
              .minFontSize(7)
              .maxFontSize(10)
              .fontWeight(FontWeight.Medium)
              .fontColor(label.color)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .textAlign(TextAlign.Center)
              .textShadow({ color: Color.Black, type: ShadowType.BLUR, radius: 3 })
              .width(playbackRangeMarkerLabelWidth(label))
              .height(12)
              .position({ x: playbackRangeMarkerPosition(label.ratio), y: 0 })
              .translate({ x: '-50%' })
              .hitTestBehavior(HitTestMode.Transparent)
          }, (label: PlaybackRangeMarkerLabel): string =>
            `${label.key}:${label.ratio}:${label.label}:${JSON.stringify(label.color)}:${label.compact ?? false}`)
      }
      .width('100%')
      .height($$.height ?? 40)
      .padding({ left: PLAYBACK_SLIDER_TRACK_INSET, right: PLAYBACK_SLIDER_TRACK_INSET })
      .hitTestBehavior(HitTestMode.Transparent)
      .accessibilityLevel('no-hide-descendants')
    }
  }
  .width('100%')
  .height($$.height ?? 40)
}
