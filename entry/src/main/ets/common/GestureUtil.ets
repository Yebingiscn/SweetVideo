import { Setting } from '../utils/ObservedUtil'
import { LEFT_ZONE_DIVISION, RIGHT_ZONE_DIVISION, SCREEN_DIVISIONS } from './Constants'

export function handleScreenDoubleClick(
  tapX: number,
  screenWidth: number,
  togglePlayback: () => void,
  backForward: () => void,
  fastForward: () => void
): void {
  if (!Setting.allowDoubleFastForward) { // 非双击快进模式时执行暂停
    togglePlayback()
    return
  }
  const zoneWidth = screenWidth / SCREEN_DIVISIONS
  if (tapX < zoneWidth * LEFT_ZONE_DIVISION) {
    backForward()
    return
  }
  if (tapX > zoneWidth * RIGHT_ZONE_DIVISION) {
    fastForward()
    return
  }
  togglePlayback()
}