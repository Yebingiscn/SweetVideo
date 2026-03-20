import { PiPWindow } from '@kit.ArkUI';
import { AVPlayerController } from '../controller/AVPlayerController';
import { MpvController } from '../controller/MpvController/MpvController';
import { PlayerControllerInterface } from '../controller/PlayerControllerFactory';
import { PathUtils } from './PathUtils';
/***
 * 自动画中画工具类
 */
export default class PiPWindowUtil {
  static pipController?: PiPWindow.PiPController | undefined = undefined
  static playerController ?: PlayerControllerInterface | undefined = undefined


  static async createPipController(xComponentController:XComponentController,playerController ?: PlayerControllerInterface) {
    try {
      PiPWindowUtil.pipController = await PiPWindow.create({
        context: PathUtils.appContext!,
        componentController: xComponentController,
        templateType: PiPWindow.PiPTemplateType.VIDEO_PLAY,
        contentWidth: 480,
        contentHeight: 270
      });
      PiPWindowUtil.playerController = playerController
    } catch (exception) {
      console.log(`pipController init failed, Code:${exception.code}, message:${exception.message}`);
    }
    PiPWindowUtil.pipController?.on('stateChange', (State: PiPWindow.PiPState, reason: string) => {
      PiPWindowUtil.onStateChange(State, reason);
    })

    PiPWindowUtil.pipController?.on('controlPanelActionEvent',
      (event: PiPWindow.PiPActionEventType, status?: number) => {
        PiPWindowUtil.onActionEvent(event, status);
      })
    // 默认不开启自动进入画中画，由播放器在真正“播放中”时按需打开，
    // 避免暂停或非播放页时返回桌面也自动触发画中画。
    PiPWindowUtil.pipController?.setAutoStartEnabled(false);

  }

  /**
   * 在需要时（例如播放器进入播放状态）打开自动画中画。
   */
  static enableAutoStart() {
    if (PiPWindowUtil.pipController) {
      PiPWindowUtil.pipController.setAutoStartEnabled(true);
    }
  }

  static destroyPipController() {
    if (!PiPWindowUtil.pipController) {
      return;
    }
    PiPWindowUtil.pipController.setAutoStartEnabled(false);
    PiPWindowUtil.pipController.off('stateChange');
    PiPWindowUtil.pipController.off('controlPanelActionEvent');
    PiPWindowUtil.pipController = undefined;
  }

  /**
   * 在不希望触发画中画的场景（暂停、停止、离开页面等）关闭自动画中画。
   */
  static disableAutoStart() {
    if (PiPWindowUtil.pipController) {
      PiPWindowUtil.pipController.setAutoStartEnabled(false);
    }
  }

  static onActionEvent(event: PiPWindow.PiPActionEventType, status?: number) {
    if(PiPWindowUtil.playerController instanceof AVPlayerController){
      const controller = PiPWindowUtil.playerController as AVPlayerController
      switch (event) {
        case 'playbackStateChanged':
          if (status === 0) {
            controller.pause()
          } else {
            controller.play()
          }
          break;
        default:
          break;
      }
    }
  }

  static onStateChange(state: PiPWindow.PiPState, reason: string) {
    switch (state) {
      case PiPWindow.PiPState.ABOUT_TO_START:
        break;
      case PiPWindow.PiPState.STARTED:
        if(PiPWindowUtil.playerController instanceof AVPlayerController){
          const controller = PiPWindowUtil.playerController as AVPlayerController
          let status: PiPWindow.PiPControlStatus = controller.playing ? PiPWindow.PiPControlStatus.PLAY : PiPWindow.PiPControlStatus.PAUSE;
          PiPWindowUtil.pipController?.updatePiPControlStatus(PiPWindow.PiPControlType.VIDEO_PLAY_PAUSE, status);
        }
        if(PiPWindowUtil.playerController instanceof MpvController){
          const controller = PiPWindowUtil.playerController as MpvController
          let status: PiPWindow.PiPControlStatus = controller.playing ? PiPWindow.PiPControlStatus.PLAY : PiPWindow.PiPControlStatus.PAUSE;
          PiPWindowUtil.pipController?.updatePiPControlStatus(PiPWindow.PiPControlType.VIDEO_PLAY_PAUSE, status);
        }
        break;
      case PiPWindow.PiPState.ABOUT_TO_STOP:
        break;
      case PiPWindow.PiPState.STOPPED:
        break;
      case PiPWindow.PiPState.ABOUT_TO_RESTORE:
        break;
      case PiPWindow.PiPState.ERROR:
        break;
      default:
        break;
    }
  }
}