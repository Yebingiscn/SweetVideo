import { AVCastPickerState, avSession, avSession as avSessionManager } from '@kit.AVSessionKit'
import { image } from '@kit.ImageKit'
import { AvSessionState } from '../interfaces/AvSessionStateInterface'
import { VideoMetadataFromPlayer } from '../interfaces/VideoMetadataFromPlayerInterface'
import { fileIo as fs } from '@kit.CoreFileKit'
import PermissionUtil from './PermissionUtil'
import { media } from '@kit.MediaKit'
import PrivacySpaceUtil from './PrivacySpaceUtil'
import VideoInfoUtil from './VideoInfoUtil'
import { PathUtils } from './PathUtils'
import { BusinessError, systemDateTime } from '@kit.BasicServicesKit'
import { RepeatMode } from '../common/enum/RepeatMode'

// 播控中心设置类
export default class AVSessionUtil {
  static avSession: avSessionManager.AVSession | undefined = undefined
  static castController: avSession.AVCastController | undefined = undefined
  static pixelMap: image.PixelMap | undefined
  static imageSource: image.ImageSource | undefined
  static repeatModeMapping: Map<RepeatMode, avSession.LoopMode> = new Map([
    [RepeatMode.LIST, avSession.LoopMode.LOOP_MODE_LIST],
    [RepeatMode.SINGLE, avSession.LoopMode.LOOP_MODE_SINGLE],
    [RepeatMode.RANDOM, avSession.LoopMode.LOOP_MODE_SHUFFLE],
    [RepeatMode.SEQUENCE, avSession.LoopMode.LOOP_MODE_SEQUENCE],
    [RepeatMode.ONCE, avSession.LoopMode.LOOP_MODE_CUSTOM],
  ])

  static getRepeatModeFromAvSession(loopMode: avSession.LoopMode): RepeatMode {
    // 遍历重复模式映射表
    for (let entry of AVSessionUtil.repeatModeMapping.entries()) {
      let key: RepeatMode = entry[0] // 目标重复模式
      let value: avSession.LoopMode = entry[1] // AVSession循环模式
      // 如果找到匹配的AVSession循环模式，返回对应的重复模式
      if (value === loopMode) {
        return key
      }
    }
    // 如果没有找到匹配项，返回默的列表循环模式
    return RepeatMode.LIST
  }

  static async getAVSession() {
    if (!AVSessionUtil.avSession) {
      await AVSessionUtil.createSession()
    }
    return AVSessionUtil.avSession
  }

  static async checkOtherCast(avSession: avSessionManager.AVSession) {
    try {
      let currentOutputDevice: avSession.OutputDeviceInfo = avSession.getOutputDeviceSync()
      return currentOutputDevice
    } catch (err) {
      let error = err as BusinessError
      console.error(`getOutputDeviceSync error, error code: ${error.code}, error message: ${error.message}`)
      return null
    }
  }

  // 更新播控中心状态
  static updatePlaybackSessionState(playing: boolean, play_time: number, repeatMode?: RepeatMode) {
    let data: AvSessionState = {
      playing: playing,
      duration: play_time,
    }
    AVSessionUtil.updateSession(data, repeatMode)
  }

  static castOnStateChange(state: AVCastPickerState) {
    if (state == AVCastPickerState.STATE_APPEARING) {
      console.log('The picker starts showing.')
    } else if (state == AVCastPickerState.STATE_DISAPPEARING) {
      console.log('The picker finishes presenting.')
    }
  }

  static async createSession() {
    let type: avSessionManager.AVSessionType = 'audio'
    try {
      AVSessionUtil.avSession = await avSessionManager.createAVSession(PathUtils.appContext!, 'sweet_video', type)
      AVSessionUtil.avSession.activate()?.catch(() => {
        console.error('activate avSession erro')
      })
    } catch (error) {
      console.error('create session error:' + error)
    }
  }

  static async setSessionInfo(metadata: VideoMetadataFromPlayer) {
    try {
      AVSessionUtil.imageSource = image.createImageSource(PathUtils.coverPath + metadata.date)
      let decodingOptions: image.DecodingOptions = {
        //设置为AUTO会根据图片资源格式解码，如果图片资源为HDR资源则会解码为HDR的pixel map。
        desiredDynamicRange: image.DecodingDynamicRange.AUTO,
      }
      AVSessionUtil.pixelMap = AVSessionUtil.imageSource.createPixelMapSync(decodingOptions)
    } catch (e) { //视频没有封面时加载默认封面
      const resourceMgr = PathUtils.appContext!.resourceManager.getMediaContentSync($r('app.media.sweet_video').id)
      const defaultImageSource = image.createImageSource(resourceMgr.buffer)
      AVSessionUtil.pixelMap = defaultImageSource.createPixelMapSync()
    }
    let session_metadata: avSessionManager.AVMetadata = {
      assetId: metadata.date,
      title: metadata.title.slice(0, metadata.title.lastIndexOf('.')),
      mediaImage: AVSessionUtil.pixelMap,
      duration: metadata.time,
      filter: avSession.ProtocolType.TYPE_CAST_PLUS_STREAM | avSession.ProtocolType.TYPE_DLNA,
    }
    AVSessionUtil.avSession?.setAVMetadata(session_metadata)?.catch(() => {
      console.error('setAVMetadata error')
    })
    await AVSessionUtil.getAVCastController(metadata)
  }

  static updateSession(avSessionState: AvSessionState, repeatMode?: RepeatMode) {
    let playbackState: avSessionManager.AVPlaybackState = {
      state: avSessionState.playing ? avSessionManager.PlaybackState.PLAYBACK_STATE_PLAY :
        avSessionManager.PlaybackState.PLAYBACK_STATE_PAUSE,
      position: {
        elapsedTime: avSessionState.duration,
        updateTime: systemDateTime.getTime(false),
      },
      loopMode: repeatMode !== undefined
        ? AVSessionUtil.repeatModeMapping.get(repeatMode)
        : avSession.LoopMode.LOOP_MODE_CUSTOM,
    }
    AVSessionUtil.avSession?.setAVPlaybackState(playbackState)?.catch(() => {
      console.error('updateSession error')
    })
  }

  static destroySession() {
    AVSessionUtil.avSession?.destroy()?.catch(() => {
      console.error('destroy Session error')
    })
    AVSessionUtil.avSession = undefined
    AVSessionUtil.pixelMap?.release()
    AVSessionUtil.imageSource?.release()
  }

  static async getAVCastController(now_playing: VideoMetadataFromPlayer) {
    // 如支持投播，可使用下面接口监听设备连接状态的变化
    try {
      await AVSessionUtil.avSession?.setExtras({
        requireAbilityList: ['url-cast']
      })
      AVSessionUtil.avSession?.on('outputDeviceChange', async (connectState: avSession.ConnectionState,
        device: avSession.OutputDeviceInfo) => {
        // 可以通过当前设备及设备连接状态来更新应用内播放界面的显示
        let currentDevice: avSession.DeviceInfo = device?.devices?.[0]
        if (currentDevice.castCategory === avSession.AVCastCategory.CATEGORY_REMOTE &&
          connectState === avSession.ConnectionState.STATE_CONNECTED) { // 设备连接成功
          console.error(`Device connected: ${device}`)
          console.error('Succeeded in getting a cast controller')
          // 查询当前播放的状态
          AVSessionUtil.castController = await AVSessionUtil.avSession?.getAVCastController()
          let avPlaybackState = await AVSessionUtil.castController?.getAVPlaybackState()
          console.error(`Succeeded in AVPlaybackState resource obtained: ${avPlaybackState}`)
          // 监听播放状态的变化
          AVSessionUtil.castController?.on('playbackStateChange', 'all', (state: avSession.AVPlaybackState) => {
            console.error(`Succeeded in Playback state changed: ${state}`)
          })
          if (currentDevice.supportedProtocols === avSession.ProtocolType.TYPE_CAST_PLUS_STREAM) {
            AVSessionUtil.playItem(now_playing)
            // 此设备支持cast+投播协议
          } else if (currentDevice.supportedProtocols === avSession.ProtocolType.TYPE_DLNA) {
            // 此设备支持DLNA投播协议
            AVSessionUtil.playItem(now_playing)
          }
        }
      })
    } catch (error) {
      console.error('getAVCastController error' + error)
    }
  }

  static async playItem(now_playing: VideoMetadataFromPlayer) {
    await PermissionUtil.activatePermission(now_playing?.uri)
    try {
      const file = fs.openSync(now_playing?.uri)
      let avFileDescriptor: media.AVFileDescriptor = { fd: file.fd }
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
      }
      // 准备播放，这个不会触发真正的播放，会进行加载和缓冲
      AVSessionUtil.castController?.prepare(playItem, () => {
        console.info('Preparation done')
        // 启动播放，真正触发对端播放。请在Prepare成功后再调用start。
        AVSessionUtil.castController?.start(playItem, () => {
          console.info('Playback started')
        })
      })
    } catch (error) {
      console.error('play item error:' + error)
    }
  }
}