import { media } from '@kit.MediaKit';
import ToolsUtil from './ToolsUtil';

// 系统播放器类
export class AVPlayerUtil {
  static avPlayer: media.AVPlayer | undefined = undefined

  public static async getAVPlayer() {
    try {
      AVPlayerUtil.avPlayer = await media.createAVPlayer()
    } catch (error) {
      ToolsUtil.errorCatchExec('生成 avplayer error', String(error))
    }
    return AVPlayerUtil.avPlayer
  }
}