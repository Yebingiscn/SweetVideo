import { media } from '@kit.MediaKit';
import { salmonLogger } from 'salmonlogger';
import ToolsUtil from './ToolsUtil';

// 系统播放器类
export class AVPlayerUtil {
  static avPlayer: media.AVPlayer | undefined = undefined

  public static async getAVPlayer() {
    try {
      if (!AVPlayerUtil.avPlayer) {
        AVPlayerUtil.avPlayer = await media.createAVPlayer()
      }
    } catch (error) {
      ToolsUtil.showToast('播放异常')
      salmonLogger.addLog('avplayer',
        'create avplayer error: ' + error.code + ':' + error.message, true)
    }
    return AVPlayerUtil.avPlayer
  }
}