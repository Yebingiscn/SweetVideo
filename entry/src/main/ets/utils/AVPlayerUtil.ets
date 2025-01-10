import { media } from '@kit.MediaKit'

class AVPlayer {
  avPlayer: media.AVPlayer | undefined = undefined

  async getAVPlayer() {
    this.avPlayer = await media.createAVPlayer()
    return this.avPlayer
  }
}

const AVPlayerUtil = new AVPlayer()

export default AVPlayerUtil