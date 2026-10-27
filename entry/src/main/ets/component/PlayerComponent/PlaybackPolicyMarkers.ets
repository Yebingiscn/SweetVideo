import { PlaybackPolicyController } from '../../controller/PlaybackPolicyController'
import { PlaybackProgressMarker } from './PlaybackProgressComponent'
import ToolsUtil from '../../utils/ToolsUtil'

/** 两种播放界面共用点位来源，避免滑条标记与实际策略各算一遍。 */
export function playbackPolicyMarkers(policy: PlaybackPolicyController): PlaybackProgressMarker[] {
  const markers: PlaybackProgressMarker[] = []
  const range = policy.openingEnding
  if (range.introEndMs > 0) {
    markers.push({ key: 'intro', timeMs: range.introEndMs,
      label: ToolsUtil.getStringResource($r('app.string.playback_intro_marker').id), color: '#FFD27F' })
  }
  if (range.outroStartMs > 0) {
    markers.push({ key: 'outro', timeMs: range.outroStartMs,
      label: ToolsUtil.getStringResource($r('app.string.playback_outro_marker').id), color: '#C9A0FF' })
  }
  const loop = policy.abLoop
  if (loop.pointA > 0 || loop.pointB > 0) {
    const color = loop.enabled ? '#73D7FF' : '#B3C3CE'
    markers.push({ key: 'ab-a', timeMs: loop.pointA, label: 'A', color: color })
    if (loop.pointB > 0) { markers.push({ key: 'ab-b', timeMs: loop.pointB, label: 'B', color: color }) }
  }
  return markers
}
