import { AVCastPickerState, avSession, avSession as avSessionManager } from '@kit.AVSessionKit'
import { image } from '@kit.ImageKit'
import { AvSessionState } from '../interfaces/AvSessionStateInterface'
import { BusinessError, systemDateTime } from '@kit.BasicServicesKit'
import { SweetRepeatMode } from '../common/enum/SweetRepeatMode'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import { salmonLogger } from 'salmonlogger'
import { Setting } from './ObservedUtil'
import { PathUtils } from './PathUtils'
import PermissionUtil from './PermissionUtil'
import PrivacySpaceUtil from './PrivacySpaceUtil'
import VideoInfoUtil from './VideoInfoUtil'
import fileIo from '@ohos.file.fs'
import { media } from '@kit.MediaKit'

const TAG = 'AVSessionUtil'

// 播控中心设置类
export default class AVSessionUtil {
  static avSession: avSessionManager.AVSession | undefined = undefined
  static castController: avSession.AVCastController | undefined = undefined
  static pixelMap: image.PixelMap | undefined
  static imageSource: image.ImageSource | undefined
  static repeatModeMapping: Map<SweetRepeatMode, avSession.LoopMode> = new Map([
    [SweetRepeatMode.LIST, avSession.LoopMode.LOOP_MODE_LIST],
    [SweetRepeatMode.SINGLE, avSession.LoopMode.LOOP_MODE_SINGLE],
    [SweetRepeatMode.RANDOM, avSession.LoopMode.LOOP_MODE_SHUFFLE],
    [SweetRepeatMode.SEQUENCE, avSession.LoopMode.LOOP_MODE_SEQUENCE],
    [SweetRepeatMode.ONCE, avSession.LoopMode.LOOP_MODE_CUSTOM],
  ])

  static getRepeatModeFromAvSession(loopMode: avSession.LoopMode): SweetRepeatMode {
    // 遍历重复模式映射表
    for (let entry of AVSessionUtil.repeatModeMapping.entries()) {
      let key: SweetRepeatMode = entry[0] // 目标重复模式
      let value: avSession.LoopMode = entry[1] // AVSession循环模式
      // 如果找到匹配的AVSession循环模式，返回对应的重复模式
      if (value === loopMode) {
        return key
      }
    }
    // 如果没有找到匹配项，返回默的列表循环模式
    return SweetRepeatMode.LIST
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
      salmonLogger.addLog(TAG, `getOutputDeviceSync error, error code: ${error.code}, error message: ${error.message}`,
        true)
      return null
    }
  }

  // 更新播控中心状态
  static updatePlaybackSessionState(playing: boolean, playTime: number, repeatMode?: SweetRepeatMode) {
    if (Setting.allowBackgroundPlay) {
      let data: AvSessionState = {
        playing: playing,
        duration: playTime,
      }
      AVSessionUtil.updateSession(data, repeatMode)
    }
  }

  static castOnStateChange(state: AVCastPickerState) {
    if (state == AVCastPickerState.STATE_APPEARING) {
      salmonLogger.addLog(TAG, 'The picker starts showing.')
    } else if (state == AVCastPickerState.STATE_DISAPPEARING) {
      salmonLogger.addLog(TAG, 'The picker finishes presenting.')
    }
  }

  static async createSession() {
    let type: avSessionManager.AVSessionType = 'audio'
    try {
      AVSessionUtil.avSession = await avSessionManager.createAVSession(PathUtils.appContext!, 'sweet_video', type)
      AVSessionUtil.avSession.activate()?.catch(() => {
        salmonLogger.addLog(TAG, 'activate avSession erro', true)
      })
    } catch (error) {
      salmonLogger.addLog(TAG, 'create session error:' + error, true)
    }
  }

  static async setSessionInfo(metadata: VideoMetadata) {
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
      salmonLogger.addLog(TAG, 'setAVMetadata error', true)
    })
    await AVSessionUtil.getAVCastController(metadata)
  }

  static updateSession(avSessionState: AvSessionState, repeatMode?: SweetRepeatMode) {
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
      salmonLogger.addLog(TAG, 'updateSession error', true)
    })
  }

  static destroySession() {
    AVSessionUtil.avSession?.destroy()?.catch(() => {
      salmonLogger.addLog(TAG, 'destroy Session error', true)
    })
    AVSessionUtil.avSession = undefined
    AVSessionUtil.pixelMap?.release()
    AVSessionUtil.imageSource?.release()
  }

  static async getAVCastController(now_playing: VideoMetadata) {
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
          salmonLogger.addLog(TAG, `Device connected: ${device}`)
          salmonLogger.addLog(TAG, 'Succeeded in getting a cast controller')
          // 查询当前播放的状态
          AVSessionUtil.castController = await AVSessionUtil.avSession?.getAVCastController()
          let avPlaybackState = await AVSessionUtil.castController?.getAVPlaybackState()
          salmonLogger.addLog(TAG, `Succeeded in AVPlaybackState resource obtained: ${avPlaybackState}`)
          // 监听播放状态的变化
          AVSessionUtil.castController?.on('playbackStateChange', 'all', (state: avSession.AVPlaybackState) => {
            salmonLogger.addLog(TAG, `Succeeded in Playback state changed: ${state}`)
          })
          if (currentDevice.supportedProtocols === avSession.ProtocolType.TYPE_CAST_PLUS_STREAM) {
            await AVSessionUtil.playItem(now_playing)
            // 此设备支持cast+投播协议
          } else if (currentDevice.supportedProtocols === avSession.ProtocolType.TYPE_DLNA) {
            // 此设备支持DLNA投播协议
            await AVSessionUtil.playItem(now_playing)
          }
        }
      })
    } catch (error) {
      salmonLogger.addLog(TAG, 'getAVCastController error' + error, true)
    }
  }

  static async playItem(now_playing: VideoMetadata) {
    await PermissionUtil.activatePermission(now_playing?.uri)
    try {
      const file = fileIo.openSync(now_playing?.uri)
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
        salmonLogger.addLog(TAG, 'Preparation done')
        // 启动播放，真正触发对端播放。请在Prepare成功后再调用start。
        AVSessionUtil.castController?.start(playItem, () => {
          salmonLogger.addLog(TAG, 'Playback started')
        })
      })
    } catch (error) {
      salmonLogger.addLog(TAG, 'play item error:' + error, true)
    }
  }
}