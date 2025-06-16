import { avSession, avSession as avSessionManager } from '@kit.AVSessionKit';
import { image } from '@kit.ImageKit';
import { AvSessionState } from '../interfaces/AvSessionStateInterface';
import { VideoMetadataFromPlayer } from '../interfaces/VideoMetadataFromPlayerInterface';
import { Context } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import PermissionUtil from './PermissionUtil';
import { media } from '@kit.MediaKit';
import PrivacySpaceUtil from './PrivacySpaceUtil';
import VideoInfoUtil from './VideoInfoUtil';

// 播控中心设置类
class AVSessionUtil {
  avSession: avSessionManager.AVSession | undefined = undefined;
  context: Context = getContext()
  sandbox_path: string = this.context.filesDir + '/'
  castController: avSession.AVCastController | undefined = undefined;
  sandbox_video: string = this.context.filesDir + '/video/'

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
      filter: avSession.ProtocolType.TYPE_CAST_PLUS_STREAM | avSession.ProtocolType.TYPE_DLNA,
    };
    this.avSession?.setAVMetadata(session_metadata)
    await this.getAVCastController(metadata)
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

  async getAVCastController(now_playing: VideoMetadataFromPlayer) {
    // 如支持投播，可使用下面接口监听设备连接状态的变化
    await this.avSession?.setExtras({
      requireAbilityList: ['url-cast']
    })
    this.avSession?.on('outputDeviceChange', async (connectState: avSession.ConnectionState,
      device: avSession.OutputDeviceInfo) => {
      // 可以通过当前设备及设备连接状态来更新应用内播放界面的显示
      let currentDevice: avSession.DeviceInfo = device?.devices?.[0];
      if (currentDevice.castCategory === avSession.AVCastCategory.CATEGORY_REMOTE &&
        connectState === avSession.ConnectionState.STATE_CONNECTED) { // 设备连接成功
        console.error(`Device connected: ${device}`);
        console.error('Succeeded in getting a cast controller');
        // 查询当前播放的状态
        this.castController = await this.avSession?.getAVCastController();
        let avPlaybackState = await this.castController?.getAVPlaybackState();
        console.error(`Succeeded in AVPlaybackState resource obtained: ${avPlaybackState}`);
        // 监听播放状态的变化
        this.castController?.on('playbackStateChange', 'all', (state: avSession.AVPlaybackState) => {
          console.error(`Succeeded in Playback state changed: ${state}`);
        });
        if (currentDevice.supportedProtocols === avSession.ProtocolType.TYPE_CAST_PLUS_STREAM) {
          this.playItem(now_playing)
          // 此设备支持cast+投播协议
        } else if (currentDevice.supportedProtocols === avSession.ProtocolType.TYPE_DLNA) {
          // 此设备支持DLNA投播协议
          this.playItem(now_playing)
        }
      }
    })
  }

  async playItem(now_playing: VideoMetadataFromPlayer) {
    await PermissionUtil.activatePermission(now_playing?.uri || '')
    const file = fs.openSync(now_playing?.uri)
    let avFileDescriptor: media.AVFileDescriptor = { fd: file.fd };
    // 设置播放参数，开始播放
    let playItem: avSession.AVQueueItem = {
      itemId: 0,
      description: {
        assetId: 'VIDEO-' + JSON.stringify(now_playing.title),
        title: now_playing.title,
        artist: '',
        // 该字段大写，音频'AUDIO'，视频'VIDEO'
        mediaType: 'VIDEO',
        mediaSize: await VideoInfoUtil.getVideoSize(PrivacySpaceUtil.getPrivacyMode()! ?
          this.sandbox_video + now_playing.date : now_playing?.uri, true) as number,
        //startPosition为投播当前进度，设置该字段可将本机播放进度同步到远端
        startPosition: now_playing.last_play,
        // 投播资源播放时长，设置该字段可将本机播放时长同步到远端显示
        duration: now_playing.time,
        albumCoverUri: this.sandbox_path + now_playing.date,
        albumTitle: '',
        fdSrc: avFileDescriptor,
        appName: this.context.resourceManager.getStringSync($r('app.string.app_name').id),
      }
    };
    // 准备播放，这个不会触发真正的播放，会进行加载和缓冲
    this.castController?.prepare(playItem, () => {
      console.info('Preparation done');
      // 启动播放，真正触发对端播放。请在Prepare成功后再调用start。
      this.castController?.start(playItem, () => {
        console.info('Playback started');
      });
    });
  }
}

export default new AVSessionUtil();