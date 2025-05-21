import { avSession as avSessionManager } from '@kit.AVSessionKit';
import { image } from '@kit.ImageKit';
import { AvSessionState } from '../interfaces/AvSessionStateInterface';
import { VideoMetadataFromPlayer } from '../interfaces/VideoMetadataFromPlayerInterface';
import { Context } from '@kit.AbilityKit';

// 播控中心设置类
class AVSessionUtil {
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
    let type: avSessionManager.AVSessionType = 'audio';
    this.avSession = await avSessionManager.createAVSession(this.context, 'sweet_video', type);
    this.avSession.activate()
  }

  async setSessionInfo(metadata_json: string) {
    let metadata: VideoMetadataFromPlayer = JSON.parse(metadata_json)
    let pixelMap: image.PixelMap | undefined;
    try {
      const imageSource = image.createImageSource(this.sandbox_path + metadata.date);
      pixelMap = imageSource.createPixelMapSync();
    } catch (e) { //视频没有封面时加载默认封面
      const resourceMgr = this.context.resourceManager.getMediaContentSync($r('app.media.sweet_video').id)
      const defaultImageSource = image.createImageSource(resourceMgr.buffer);
      pixelMap = defaultImageSource.createPixelMapSync();
    }
    let session_metadata: avSessionManager.AVMetadata = {
      assetId: metadata.date,
      title: metadata.title,
      mediaImage: pixelMap,
      duration: metadata.time,
    };
    this.avSession?.setAVMetadata(session_metadata)
  }

  updateSession(state: string) {
    let avSessionState: AvSessionState = JSON.parse(state);
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

export default new AVSessionUtil();