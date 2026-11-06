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
  danmakuHeatmapPath?: string
  onSliderWidthChange?: (width: number) => void
  onSliderChange?: (value: number, mode?: SliderChangeMode) => void
  onSliderTouch?: (event: TouchEvent) => void
}

export const PLAYBACK_HEATMAP_HEIGHT: number = 22
const PLAYBACK_MARKER_LABEL_HEIGHT: number = 12
const PLAYBACK_MARKER_LABEL_GAP: number = 2

// Leave a separate caption row for A/B and intro/outro labels above the track.
export function playbackHeatmapInset(params: PlaybackProgressSliderParams): number {
  if (!params.danmakuHeatmapPath) { return 0 }
  const hasCaption = params.markers?.some((marker: PlaybackProgressMarker): boolean =>
    marker.kind !== 'chapter' && marker.key.length > 0 && marker.label.length > 0 &&
    Number.isFinite(marker.timeMs) && marker.timeMs >= 0 && marker.timeMs <= params.totalTime) ?? false
  return hasCaption ? 28 : 16
}

export function playbackHeatmapTop(params: PlaybackProgressSliderParams): number {
  const captionSpace = playbackHeatmapInset(params) > 16 ?
    PLAYBACK_MARKER_LABEL_HEIGHT + PLAYBACK_MARKER_LABEL_GAP * 2 : 0
  return (params.height ?? 40) / 2 - PLAYBACK_SLIDER_TRACK_THICKNESS / 2 -
    PLAYBACK_HEATMAP_HEIGHT - captionSpace
}

function playbackMarkerLabelTop(params: PlaybackProgressSliderParams): number {
  return params.danmakuHeatmapPath ? (params.height ?? 40) / 2 - PLAYBACK_SLIDER_TRACK_THICKNESS / 2 -
    PLAYBACK_MARKER_LABEL_HEIGHT - PLAYBACK_MARKER_LABEL_GAP : 0
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
      .margin({ top: playbackHeatmapInset($$) })
      .width('100%')
      .opacity(0.9)

    if ($$.danmakuHeatmapPath || playbackRangeMarkers($$.markers, $$.totalTime).length > 0) {
      Stack({ alignContent: Alignment.TopStart }) {
        if ($$.danmakuHeatmapPath) {
          Path().commands($$.danmakuHeatmapPath ?? '').fill($r('app.color.main_color'))
          .fillOpacity(0.8)
          .strokeWidth(0)
          .width('100%')
          .height(PLAYBACK_HEATMAP_HEIGHT)
          .position({ x: 0, y: playbackHeatmapTop($$) })
          .hitTestBehavior(HitTestMode.None)
        }
        Repeat<PlaybackRangeMarker>(playbackRangeMarkers($$.markers, $$.totalTime))
          .each((repeatItem: RepeatItem<PlaybackRangeMarker>) => {
            Rect()
              .width(repeatItem.item.kind === 'chapter' ? 1 : 2)
              .height(repeatItem.item.kind === 'chapter' ? 8 : 12)
              .fill(repeatItem.item.color)
              .stroke($r('sys.color.mask_secondary'))
              .strokeWidth(0.5)
              .position({ x: playbackRangeMarkerPosition(repeatItem.item.ratio), y: '50%' })
              .translate({ x: repeatItem.item.kind === 'chapter' ? -0.5 : -1, y: repeatItem.item.kind === 'chapter' ? -4 : -6 })
              .hitTestBehavior(HitTestMode.Transparent)
          })
          .key((marker: PlaybackRangeMarker): string => marker.key)
        Repeat<PlaybackRangeMarkerLabel>(playbackRangeMarkerLabels(playbackRangeMarkers($$.markers, $$.totalTime)))
          .each((repeatItem: RepeatItem<PlaybackRangeMarkerLabel>) => {
            Text(repeatItem.item.label)
              .fontSize(10)
              .minFontSize(7)
              .maxFontSize(10)
              .fontWeight(FontWeight.Medium)
              .fontColor(repeatItem.item.color)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .textAlign(TextAlign.Center)
              .textShadow({ color: Color.Black, type: ShadowType.BLUR, radius: 3 })
              .width(playbackRangeMarkerLabelWidth(repeatItem.item))
              .height(PLAYBACK_MARKER_LABEL_HEIGHT)
              .position({ x: playbackRangeMarkerPosition(repeatItem.item.ratio), y: playbackMarkerLabelTop($$) })
              .translate({ x: '-50%' })
              .hitTestBehavior(HitTestMode.Transparent)
          })
          .key((label: PlaybackRangeMarkerLabel): string => label.key)
      }
      .width('100%')
      .height($$.height ?? 40)
      .padding({ left: PLAYBACK_SLIDER_TRACK_INSET, right: PLAYBACK_SLIDER_TRACK_INSET })
      .margin({ top: playbackHeatmapInset($$) })
      .hitTestBehavior(HitTestMode.None)
      .accessibilityLevel('no-hide-descendants')
    }
  }
  .width('100%')
  .height(($$.height ?? 40) + playbackHeatmapInset($$))
  .onSizeChange((_oldSize: SizeResult, size: SizeResult) => $$.onSliderWidthChange?.(Number(size.width)))
}
