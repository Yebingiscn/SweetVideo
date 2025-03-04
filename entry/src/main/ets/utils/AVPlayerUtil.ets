import { media } from '@kit.MediaKit'

class AVPlayerUtil {
  avPlayer: media.AVPlayer | undefined = undefined

  async getAVPlayer() {
    this.avPlayer = await media.createAVPlayer()
    return this.avPlayer
  }
}

export default new AVPlayerUtil()