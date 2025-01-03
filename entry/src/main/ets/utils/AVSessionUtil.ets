import { avSession as avSessionManager } from '@kit.AVSessionKit';
import { image } from '@kit.ImageKit';


interface VideoMetadata {
  uri: string
  title: string
  date: string,
  size: number[]
  time: number
  last_play: number
}


interface avSessionState {
  playing: boolean
  duration: number
}


class AVSession {
  avSession: avSessionManager.AVSession | undefined = undefined;
  context: Context = getContext()
  sandbox_path: string = this.context.filesDir + '/'

  async getAVSession() {
    if (!this.avSession) {
      await this.createSession();
    }
    return this.avSession;
  }

  async createSession() {
    let type: avSessionManager.AVSessionType = 'video';
    this.avSession = await avSessionManager.createAVSession(this.context, 'sweetvideo', type);
    this.avSession.activate()
  }

  async setSessionInfo(metadata_json: string) {
    let metadata: VideoMetadata = JSON.parse(metadata_json)
    const imageSource = image.createImageSource(this.sandbox_path + metadata.date);
    const pixelMap = await imageSource.createPixelMap();
    let session_metadata: avSessionManager.AVMetadata = {
      assetId: metadata.date,
      title: metadata.title,
      mediaImage: pixelMap,
      duration: metadata.time
    };
    this.avSession?.setAVMetadata(session_metadata)
  }

  updateSession(state: string) {
    let avSessionState: avSessionState = JSON.parse(state);
    let playbackState: avSessionManager.AVPlaybackState = {
      state: avSessionState.playing ? avSessionManager.PlaybackState.PLAYBACK_STATE_PLAY :
      avSessionManager.PlaybackState.PLAYBACK_STATE_PAUSE,
      position: {
        elapsedTime: avSessionState.duration,
        updateTime: new Date().getTime(),
      },
    };
    this.avSession?.setAVPlaybackState(playbackState);
  }

  destroySession() {
    this.avSession?.destroy()
    this.avSession = undefined
  }
}

const AVSessionUtil = new AVSession();

export default AVSessionUtil;