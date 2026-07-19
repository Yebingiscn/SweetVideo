import { PiPWindow } from '@kit.ArkUI'
import { salmonLogger } from 'salmonlogger'

import { PlayerControllerInterface } from '../controller/PlayerControllerFactory'
import { Setting } from './ObservedUtil'
import { PathUtils } from './PathUtils'
import VideoInfoUtil from './VideoInfoUtil'

/***
 * 自动画中画工具类
 */
const TAG = 'PiPWindowUtil'
const PIP_BASE_SIZE = 480

class PipContentSize {
  width: number = 0
  height: number = 0

  constructor(width: number, height: number) {
    this.width = width
    this.height = height
  }
}

export default class PiPWindowUtil {
  static pipController?: PiPWindow.PiPController | undefined = undefined
  static playerController ?: PlayerControllerInterface | undefined = undefined
  static pipOpenState: boolean = false

  static async startPip() {
    if (PiPWindowUtil.pipController) {
      await PiPWindowUtil.pipController.startPiP().then(() => {
        PiPWindowUtil.pipOpenState = true
      }).catch(() => {
        salmonLogger.addLog(TAG, 'startPiP failed', true)
      })
    }
  }

  static async stopPip() {
    if (PiPWindowUtil.pipController) {
      await PiPWindowUtil.pipController.stopPiP().then(() => {
        PiPWindowUtil.pipOpenState = false
      }).catch(() => {
        salmonLogger.addLog(TAG, 'stopPiP failed', true)
      })
    }
  }

  static updateContentSize() {
    const controller = PiPWindowUtil.playerController
    const videoWidth =
      controller && controller.nowPlaying && controller.nowPlaying.size[0] ? controller.nowPlaying.size[0] : 0
    const videoHeight =
      controller && controller.nowPlaying && controller.nowPlaying.size[1] ? controller.nowPlaying.size[1] : 0
    const size = PiPWindowUtil.calculatePipContentSize(videoWidth, videoHeight)
    try {
      PiPWindowUtil.pipController?.updateContentSize(size.width, size.height)
    } catch (exception) {
      salmonLogger.addLog(TAG, `updateContentSize failed, Code:${exception.code}, message:${exception.message}`)
    }
  }

  static async createPipController(xComponentController: XComponentController,
    playerController ?: PlayerControllerInterface) {
    await PiPWindowUtil.destroyPipController()
    const controller = playerController
    const videoWidth =
      controller && controller.nowPlaying && controller.nowPlaying.size[0] ? controller.nowPlaying.size[0] : 0
    const videoHeight =
      controller && controller.nowPlaying && controller.nowPlaying.size[1] ? controller.nowPlaying.size[1] : 0
    const size = PiPWindowUtil.calculatePipContentSize(videoWidth, videoHeight)
    try {
      PiPWindowUtil.pipController = await PiPWindow.create({
        context: PathUtils.appContext!,
        componentController: xComponentController,
        templateType: PiPWindow.PiPTemplateType.VIDEO_PLAY,
        controlGroups: [PiPWindow.VideoPlayControlGroup.FAST_FORWARD_BACKWARD],
        contentWidth: size.width,
        contentHeight: size.height
      })
      PiPWindowUtil.playerController = playerController
    } catch (exception) {
      salmonLogger.addLog(TAG, `pipController init failed, Code:${exception.code}, message:${exception.message}`)
    }
    PiPWindowUtil.pipController?.on('stateChange', (State: PiPWindow.PiPState, reason: string) => {
      PiPWindowUtil.onStateChange(State, reason)
    })

    PiPWindowUtil.pipController?.on('controlPanelActionEvent',
      (event: PiPWindow.PiPActionEventType, status?: number) => {
        PiPWindowUtil.onActionEvent(event, status)
      })
    if (Setting.autoActivePip) {
      PiPWindowUtil.enableAutoStart()
    }
  }

  /**
   * 在需要时（例如播放器进入播放状态）打开自动画中画。
   */
  static enableAutoStart() {
    if (PiPWindowUtil.pipController && Setting.autoActivePip) {
      PiPWindowUtil.pipController.setAutoStartEnabled(true)
    }
  }

  static async destroyPipController() {
    if (!PiPWindowUtil.pipController) {
      return
    }
    if (PiPWindowUtil.pipOpenState) {
      await PiPWindowUtil.stopPip()
    }
    PiPWindowUtil.pipOpenState = false
    PiPWindowUtil.pipController.setAutoStartEnabled(false)
    PiPWindowUtil.pipController.off('stateChange')
    PiPWindowUtil.pipController.off('controlPanelActionEvent')
    PiPWindowUtil.pipController = undefined
  }

  /**
   * 在不希望触发画中画的场景（暂停、停止、离开页面等）关闭自动画中画。
   */
  static disableAutoStart() {
    if (PiPWindowUtil.pipController) {
      PiPWindowUtil.pipController.setAutoStartEnabled(false)
    }
  }

  static onActionEvent(event: PiPWindow.PiPActionEventType, status?: number) {
    const controller = PiPWindowUtil.playerController
    switch (event) {
      case 'playbackStateChanged':
        if (status === PiPWindow.PiPControlStatus.PAUSE) {
          controller?.pause()
        } else if (status === PiPWindow.PiPControlStatus.PLAY) {
          controller?.play()
        }
        break
      case 'fastForward':
        // 视频进度快进
        controller?.fastForward()
        break
      case 'fastBackward':
        // 视频进度后退
        controller?.backForward()
        break
      default:
        break
    }
  }

  static onStateChange(state: PiPWindow.PiPState, _reason: string) {
    switch (state) {
      case PiPWindow.PiPState.ABOUT_TO_START:
        break
      case PiPWindow.PiPState.STARTED:
        const controller = PiPWindowUtil.playerController
        let status: PiPWindow.PiPControlStatus =
          controller?.playing ? PiPWindow.PiPControlStatus.PLAY : PiPWindow.PiPControlStatus.PAUSE
        PiPWindowUtil.pipController?.updatePiPControlStatus(PiPWindow.PiPControlType.VIDEO_PLAY_PAUSE, status)
        PiPWindowUtil.pipOpenState = true
        break
      case PiPWindow.PiPState.ABOUT_TO_STOP:
        PiPWindowUtil.pipOpenState = false
        break
      case PiPWindow.PiPState.STOPPED:
        PiPWindowUtil.pipOpenState = false
        break
      case PiPWindow.PiPState.ABOUT_TO_RESTORE:
        PiPWindowUtil.pipOpenState = false
        break
      case PiPWindow.PiPState.ERROR:
        break
      default:
        break
    }
  }

  private static calculatePipContentSize(videoWidth: number, videoHeight: number): PipContentSize {
    const size = VideoInfoUtil.calculateAspectRatioSize(videoWidth, videoHeight, PIP_BASE_SIZE)
    return new PipContentSize(size.width, size.height)
  }
}