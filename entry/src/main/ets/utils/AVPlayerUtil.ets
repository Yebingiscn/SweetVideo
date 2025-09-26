import { media } from '@kit.MediaKit';
import ToolsUtil from './ToolsUtil';

// 系统播放器类
class AVPlayerUtil {
  avPlayer: media.AVPlayer | undefined = undefined

  async getAVPlayer() {
    try {
      this.avPlayer = await media.createAVPlayer()
    } catch (error) {
      ToolsUtil.errorCatchExec('生成 avplayer error', String(error))
    }
    return this.avPlayer
  }
}

export default new AVPlayerUtil()