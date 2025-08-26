import { AVCastPickerState, avSession, avSession as avSessionManager } from '@kit.AVSessionKit';
import { image } from '@kit.ImageKit';
import { AvSessionState } from '../interfaces/AvSessionStateInterface';
import { VideoMetadataFromPlayer } from '../interfaces/VideoMetadataFromPlayerInterface';
import { fileIo as fs } from '@kit.CoreFileKit';
import PermissionUtil from './PermissionUtil';
import { media } from '@kit.MediaKit';
import PrivacySpaceUtil from './PrivacySpaceUtil';
import VideoInfoUtil from './VideoInfoUtil';
import { PathUtils } from './PathUtils';
import { BusinessError, systemDateTime } from '@kit.BasicServicesKit';

// 播控中心设置类
class AVSessionUtil {
  avSession: avSessionManager.AVSession | undefined = undefined;
  castController: avSession.AVCastController | undefined = undefined;
  pixelMap: image.PixelMap | undefined
  imageSource: image.ImageSource | undefined

  async getAVSession() {
    if (!this.avSession) {
      await this.createSession();
    }
    return this.avSession;
  }

  async checkOtherCast(avSession: avSessionManager.AVSession) {
    try {
      let currentOutputDevice: avSession.OutputDeviceInfo = avSession.getOutputDeviceSync();
      return currentOutputDevice
    } catch (err) {
      let error = err as BusinessError;
      console.error(`getOutputDeviceSync error, error code: ${error.code}, error message: ${error.message}`);
      return null
    }
  }

  // 更新播控中心状态
  updatePlaybackSessionState(playing: boolean, play_time: number) {
    let data: AvSessionState = {
      playing: playing,
      duration: play_time
    }
    this.updateSession(data)
  }

  castOnStateChange(state: AVCastPickerState) {
    if (state == AVCastPickerState.STATE_APPEARING) {
      console.log('The picker starts showing.');
    } else if (state == AVCastPickerState.STATE_DISAPPEARING) {
      console.log('The picker finishes presenting.');
    }
  }

  async createSession() {
    let type: avSessionManager.AVSessionType = 'audio';
    this.avSession = await avSessionManager.createAVSession(PathUtils.appContext!, 'sweet_video', type);
    this.avSession.activate()
  }

  async setSessionInfo(metadata: VideoMetadataFromPlayer) {
    try {
      this.imageSource = image.createImageSource(PathUtils.coverPath + metadata.date);
      let decodingOptions: image.DecodingOptions = {
        //设置为AUTO会根据图片资源格式解码，如果图片资源为HDR资源则会解码为HDR的pixel map。
        desiredDynamicRange: image.DecodingDynamicRange.AUTO,
      };
      this.pixelMap = this.imageSource.createPixelMapSync(decodingOptions);
    } catch (e) { //视频没有封面时加载默认封面
      const resourceMgr = PathUtils.appContext!.resourceManager.getMediaContentSync($r('app.media.sweet_video').id)
      const defaultImageSource = image.createImageSource(resourceMgr.buffer);
      this.pixelMap = defaultImageSource.createPixelMapSync();
    }
    let session_metadata: avSessionManager.AVMetadata = {
      assetId: metadata.date,
      title: metadata.title.slice(0, metadata.title.lastIndexOf('.')),
      mediaImage: this.pixelMap,
      duration: metadata.time,
      filter: avSession.ProtocolType.TYPE_CAST_PLUS_STREAM | avSession.ProtocolType.TYPE_DLNA,
    };
    this.avSession?.setAVMetadata(session_metadata)
    await this.getAVCastController(metadata)
  }

  updateSession(avSessionState: AvSessionState) {
    let playbackState: avSessionManager.AVPlaybackState = {
      state: avSessionState.playing ? avSessionManager.PlaybackState.PLAYBACK_STATE_PLAY :
      avSessionManager.PlaybackState.PLAYBACK_STATE_PAUSE,
      position: {
        elapsedTime: avSessionState.duration,
        updateTime: systemDateTime.getTime(false),
      },
    };
    this.avSession?.setAVPlaybackState(playbackState);
  }

  destroySession() {
    this.avSession?.destroy()
    this.avSession = undefined
    this.pixelMap?.release();
    this.imageSource?.release();
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
        assetId: 'VIDEO-' + now_playing.title,
        title: now_playing.title.slice(0, now_playing.title.lastIndexOf('.')),
        artist: '',
        mediaType: 'VIDEO',
        mediaSize: await VideoInfoUtil.getVideoSize(PrivacySpaceUtil.getPrivacyMode()! ?
          PathUtils.videoPath + now_playing.date : now_playing?.uri, true) as number,
        //startPosition为投播当前进度，设置该字段可将本机播放进度同步到远端
        startPosition: now_playing.last_play,
        // 投播资源播放时长，设置该字段可将本机播放时长同步到远端显示
        duration: now_playing.time,
        albumCoverUri: PathUtils.coverPath + now_playing.date,
        albumTitle: '',
        fdSrc: avFileDescriptor,
        appName: PathUtils.appContext!.resourceManager.getStringSync($r('app.string.EntryAbility_label').id),
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