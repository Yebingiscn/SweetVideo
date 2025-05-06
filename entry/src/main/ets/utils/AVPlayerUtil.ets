import { media } from '@kit.MediaKit'

// 系统播放器类
class AVPlayerUtil {
  avPlayer: media.AVPlayer | undefined = undefined

  async getAVPlayer() {
    this.avPlayer = await media.createAVPlayer()
    return this.avPlayer
  }
}

export default new AVPlayerUtil()