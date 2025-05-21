import { media } from '@kit.MediaKit';

// 系统播放器类
class AVPlayerUtil {
  avPlayer: media.AVPlayer | undefined = undefined

  async getAVPlayer() {
    this.avPlayer = await media.createAVPlayer()
    let playStrategy: media.PlaybackStrategy =
      { showFirstFrameOnPrepare: true, preferredAudioLanguage: 'chi', preferredSubtitleLanguage: 'chi' }
    this.avPlayer.setPlaybackStrategy(playStrategy);
    return this.avPlayer
  }
}

export default new AVPlayerUtil()