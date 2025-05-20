import { avSession as avSessionManager } from '@kit.AVSessionKit';
import { image } from '@kit.ImageKit';
import { AvSessionState } from '../interfaces/AvSessionStateInterface';
import { VideoMetadataFromPlayer } from '../interfaces/VideoMetadataFromPlayerInterface';

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
    let type: avSessionManager.AVSessionType = 'video';
    this.avSession = await avSessionManager.createAVSession(this.context, 'sweet_video', type);
    this.avSession.activate()
    console.error('test active success')
  }

  async setSessionInfo(metadata_json: string) {
    let metadata: VideoMetadataFromPlayer = JSON.parse(metadata_json)
    const imageSource = image.createImageSource(this.sandbox_path + metadata.date);
    let pixelMap: image.PixelMap | undefined;
    try {
      pixelMap = imageSource.createPixelMapSync();
    } catch (e) {
      //要想接入播控中心，必须传入图片，这里对于无法获取封面的视频，传入默认图/片
      const resourceMgr = this.context.resourceManager;
      // error报错: fail to get arraybufferinfo
      const resource = resourceMgr.getMediaContentSync($r('app.media.Foreground').id)
      // error报错 CreateImageSourceExec error
      const defaultImageSource = image.createImageSource(resource);
      try {
        pixelMap = defaultImageSource.createPixelMapSync();
        console.error('test4' + pixelMap)
      } catch (e) {
        console.error('test error' + e)
      }
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