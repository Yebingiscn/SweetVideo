import { ImageFancyModifier } from '../../common/AttributeModifierConfig'
import { Setting } from '../../utils/ObservedUtil'
import TimeUtil from '../../utils/TimeUtil'
import VideoOperateUtil from '../../utils/VideoOperateUtil'
import { DIALOG_TITLE_FONT_SIZE } from '../../common/Constants'
import { salmonLogger } from 'salmonlogger'

@ObservedV2
class SwipingPlayTimeValue {
  @Trace isSliderPlayTimeChange: boolean = false
  @Trace playTime: number = 0
  @Trace totalTime: number = 0
  @Trace pixelMap: PixelMap | null = null
}

const DEFAULT_TIME = '00:00'

@Builder
export function SwipingPlayTimePanelBuilder(swipingPlayTimeValue: SwipingPlayTimeValue) {
  if (swipingPlayTimeValue) {
    Column() {
      Text(buildSwipingTimeText(swipingPlayTimeValue))
        .fontColor($r('sys.color.white')).fontSize(DIALOG_TITLE_FONT_SIZE).fontWeight(FontWeight.Bold)

      if (Setting?.showFrameImgStatus) {
        if (swipingPlayTimeValue?.pixelMap) {
          Image(swipingPlayTimeValue?.pixelMap)
            .attributeModifier(new ImageFancyModifier(16, 160, 90))
            .objectFit(ImageFit.Cover)
            .borderRadius(16)
            .clip(true)
        }
      }
    }
    .padding({
      left: 25,
      right: 25,
      top: 10,
      bottom: 10
    })
    .borderRadius(16)
    .backgroundColor('#30000000')
    .backdropBlur(100)
    .animation({ duration: 300, curve: Curve.Friction })
  }
}

function timeDiffSign(v: SwipingPlayTimeValue): string {
  const playTime = v.playTime || 0
  const lastPlayTime = typeof VideoOperateUtil?.lastPlayTime === 'number' ? VideoOperateUtil.lastPlayTime : 0
  const diff = Math.floor((playTime - lastPlayTime) / 1000)
  return diff > 0 ? '+' : diff < 0 ? '-' : ''
}

function timeDiffSeconds(v: SwipingPlayTimeValue): number {
  const playTime = v.playTime || 0
  const lastPlayTime = typeof VideoOperateUtil?.lastPlayTime === 'number' ? VideoOperateUtil.lastPlayTime : 0
  return Math.abs(Math.floor((playTime - lastPlayTime) / 1000))
}

function percentValue(v: SwipingPlayTimeValue): number {
  const playTime = v.playTime || 0
  const totalTime = v.totalTime || 0
  return totalTime > 0 ? Math.floor(playTime / totalTime * 100) : 0
}

function buildSwipingTimeText(v: SwipingPlayTimeValue): string {
  let text = ''
  if (!v.isSliderPlayTimeChange) {
    text += `${timeDiffSign(v)}${timeDiffSeconds(v)}s : `
  }
  const playSec = Math.floor((v.playTime || 0) / 1000)
  const totalSec = Math.floor((v.totalTime || 0) / 1000)
  if (v.totalTime >= 3600000) {
    text += `${Math.floor(playSec / 3600).toString().padStart(2, '0')}:`
  }
  text += `${Math.floor((playSec % 3600) / 60).toString().padStart(2, '0')}:${(playSec % 60).toString()
    .padStart(2, '0')}`
  text += ' / '
  if (v.totalTime >= 3600000) {
    text += `${Math.floor(totalSec / 3600).toString().padStart(2, '0')}:`
  }
  text += `${Math.floor((totalSec % 3600) / 60).toString().padStart(2, '0')}:${(totalSec % 60).toString()
    .padStart(2, '0')}`
  text += `  ${percentValue(v)}%`
  return text
}

export function getFormattedTimeText(swipingPlayTimeValue: SwipingPlayTimeValue): string {
  try {
    if (!swipingPlayTimeValue) {
      return '00:00/00:00'
    }
    if (swipingPlayTimeValue.playTime == null || swipingPlayTimeValue.totalTime == null) {
      return '00:00/00:00'
    }
    const playTime = swipingPlayTimeValue.playTime || 0
    const totalTime = swipingPlayTimeValue.totalTime || 0
    const currentTime = TimeUtil.convertMSToHHMMSS(playTime) ?? DEFAULT_TIME
    const totalTimeStr = TimeUtil.convertMSToHHMMSS(totalTime) ?? DEFAULT_TIME

    if (swipingPlayTimeValue.isSliderPlayTimeChange) {
      return `${currentTime}/${totalTimeStr}`
    } else {
      const lastPlayTime = typeof VideoOperateUtil?.lastPlayTime === 'number' ? VideoOperateUtil.lastPlayTime : 0
      const timeDiff = Math.floor((playTime - lastPlayTime) / 1000)
      const sign = timeDiff > 0 ? '+' : ''
      return `${sign}${timeDiff}s : ${currentTime}/${totalTimeStr}`
    }
  } catch (error) {
    salmonLogger.addLog('getFormattedTimeText', error, true)
    return '00:00/00:00'
  }
}