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
import ToolsUtil from './ToolsUtil'
import VideoInfoUtil from './VideoInfoUtil'
import { fileIo } from '@kit.CoreFileKit'
import { media } from '@kit.MediaKit'
import { audio } from '@kit.AudioKit'

const TAG = 'AVSessionUtil'

// 播控中心设置类
export default class AVSessionUtil {
  static avSession: avSessionManager.AVSession | undefined = undefined
  static castController: avSession.AVCastController | undefined = undefined
  static currentNowPlaying: VideoMetadata | undefined = undefined
  static pixelMap: image.PixelMap | undefined
  static imageSource: image.ImageSource | undefined
  static isOutputDeviceListenerRegistered: boolean = false
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

  static async stopCastingIfActive(): Promise<void> {
    const session = AVSessionUtil.avSession
    if (!session || !AVSessionUtil.castController) {
      return
    }
    try {
      await session.stopCasting()
    } catch (error) {
      salmonLogger.addLog(TAG, `stopCasting ignored during cleanup: ${error}`, false)
    }
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
    let type: avSessionManager.AVSessionType = 'video'
    try {
      AVSessionUtil.avSession = await avSessionManager.createAVSession(PathUtils.appContext!, 'sweet_video', type)
      AVSessionUtil.avSession?.setBackgroundPlayMode(avSession.BackgroundPlayMode.ENABLE_BACKGROUND_PLAY).catch(
        () => {
          salmonLogger.addLog(TAG, 'setBackgroundPlayMode error', true)
        })
      AVSessionUtil.avSession.activate()?.catch(() => {
        salmonLogger.addLog(TAG, 'activate avSession error', true)
      })
    } catch (error) {
      salmonLogger.addLog(TAG, 'create session error:' + error, true)
    }
  }

  static getInterruptMode(): audio.InterruptMode {
    return Setting.allowConcurrentPlay ? audio.InterruptMode.SHARE_MODE : audio.InterruptMode.INDEPENDENT_MODE
  }

  static applyAudioConcurrencyMode() {
    try {
      let sessionManager = audio.getAudioManager().getSessionManager()
      let strategy: audio.AudioSessionStrategy = {
        concurrencyMode: Setting.allowConcurrentPlay ?
          audio.AudioConcurrencyMode.CONCURRENCY_MIX_WITH_OTHERS :
          audio.AudioConcurrencyMode.CONCURRENCY_DEFAULT
      }
      sessionManager.activateAudioSession(strategy).then(() => {
        salmonLogger.addLog(TAG, 'activateAudioSession success', false)
      }).catch((err: BusinessError) => {
        salmonLogger.addLog(TAG, `activateAudioSession error: ${err.code} ${err.message}`, true)
      })
    } catch (err) {
      salmonLogger.addLog(TAG, `applyAudioConcurrencyMode error: ${err}`, true)
    }
  }

  static async setSessionInfo(metadata: VideoMetadata) {
    AVSessionUtil.currentNowPlaying = metadata
    try {
      AVSessionUtil.imageSource = image.createImageSource(PathUtils.coverPath + metadata.date)
      let decodingOptions: image.DecodingOptions = {
        desiredDynamicRange: image.DecodingDynamicRange.AUTO,
      }
      AVSessionUtil.pixelMap = AVSessionUtil.imageSource.createPixelMapSync(decodingOptions)
    } catch (e) {
      const resourceMgr = PathUtils.appContext!.resourceManager.getMediaContentSync($r('app.media.sweet_video').id)
      const defaultImageSource = image.createImageSource(resourceMgr.buffer)
      AVSessionUtil.pixelMap = defaultImageSource.createPixelMapSync()
    }
    let session_metadata: avSessionManager.AVMetadata = {
      assetId: metadata.date,
      title: metadata.title.lastIndexOf('.') !== -1 ?
        metadata.title.slice(0, metadata.title.lastIndexOf('.')) : metadata.title,
      mediaImage: AVSessionUtil.pixelMap,
      duration: metadata.time,
      filter: avSession.ProtocolType.TYPE_CAST_PLUS_STREAM | avSession.ProtocolType.TYPE_DLNA,
    }
    AVSessionUtil.avSession?.setAVMetadata(session_metadata)?.catch(() => {
      salmonLogger.addLog(TAG, 'setAVMetadata error', true)
    })
    await AVSessionUtil.getAVCastController()
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
    if (!AVSessionUtil.avSession) {
      return
    }
    if (AVSessionUtil.isOutputDeviceListenerRegistered) {
        try {
          AVSessionUtil.avSession?.off('outputDeviceChange')
        } catch (e) {
          salmonLogger.addLog(TAG, 'off outputDeviceChange error: ' + e, true)
        }
        AVSessionUtil.isOutputDeviceListenerRegistered = false
      }
      try {
        AVSessionUtil.castController?.off('playbackStateChange')
      } catch (e) {
        salmonLogger.addLog(TAG, 'off playbackStateChange error: ' + e, true)
      }
      AVSessionUtil.castController = undefined
    AVSessionUtil.currentNowPlaying = undefined
    AVSessionUtil.avSession?.destroy()?.catch(() => {
      salmonLogger.addLog(TAG, 'destroy Session error', true)
    })
    AVSessionUtil.avSession = undefined
    AVSessionUtil.pixelMap?.release()
    AVSessionUtil.imageSource?.release()
  }

  static async getAVCastController() {
    try {
      await AVSessionUtil.avSession?.setExtras({
        requireAbilityList: ['url-cast']
      })
      if (AVSessionUtil.isOutputDeviceListenerRegistered) {
        try {
          AVSessionUtil.avSession?.off('outputDeviceChange')
        } catch (e) {
          salmonLogger.addLog(TAG, 'off outputDeviceChange error: ' + e, true)
        }
        AVSessionUtil.isOutputDeviceListenerRegistered = false
      }
      AVSessionUtil.avSession?.on('outputDeviceChange', async (connectState: avSession.ConnectionState,
        device: avSession.OutputDeviceInfo) => {
        let currentDevice: avSession.DeviceInfo = device?.devices?.[0]
        if (currentDevice.castCategory === avSession.AVCastCategory.CATEGORY_REMOTE &&
          connectState === avSession.ConnectionState.STATE_CONNECTED) {
          salmonLogger.addLog(TAG, `Device connected: ${device}`)
          salmonLogger.addLog(TAG, 'Succeeded in getting a cast controller')
          AVSessionUtil.castController = await AVSessionUtil.avSession?.getAVCastController()
          let avPlaybackState = await AVSessionUtil.castController?.getAVPlaybackState()
          salmonLogger.addLog(TAG, `Succeeded in AVPlaybackState resource obtained: ${avPlaybackState}`)
          try {
            AVSessionUtil.castController?.off('playbackStateChange')
          } catch (e) {
            salmonLogger.addLog(TAG, 'off playbackStateChange error: ' + e, true)
          }
          AVSessionUtil.castController?.on('playbackStateChange', 'all', (state: avSession.AVPlaybackState) => {
            salmonLogger.addLog(TAG, `Succeeded in Playback state changed: ${state}`)
          })
          const nowPlaying = AVSessionUtil.currentNowPlaying
          if (!nowPlaying) {
            salmonLogger.addLog(TAG, 'No current nowPlaying data, skip playItem', true)
            return
          }
          const supportedProtocols = currentDevice.supportedProtocols ?? 0
          if ((supportedProtocols & avSession.ProtocolType.TYPE_CAST_PLUS_STREAM) !== 0 ||
            (supportedProtocols & avSession.ProtocolType.TYPE_DLNA) !== 0) {
            await AVSessionUtil.playItem(nowPlaying)
          } else {
            salmonLogger.addLog(TAG, `Unsupported protocol: ${supportedProtocols}`, true)
            ToolsUtil.showToast('当前设备不支持投播协议')
          }
        }
      })
      AVSessionUtil.isOutputDeviceListenerRegistered = true
    } catch (error) {
      salmonLogger.addLog(TAG, 'getAVCastController error' + error, true)
    }
  }

  static async playItem(now_playing: VideoMetadata) {
    await PermissionUtil.activatePermission(now_playing?.uri)
    try {
      const uri = now_playing?.uri
      if (!uri) {
        salmonLogger.addLog(TAG, 'playItem: uri is empty', true)
        ToolsUtil.showToast('投播失败：视频地址为空')
        return
      }
      const isNetworkUri = uri.startsWith('http://') || uri.startsWith('https://')
      let playItem: avSession.AVQueueItem
      let fd: number | undefined = undefined
      if (isNetworkUri) {
        playItem = {
          itemId: 0,
          description: {
            assetId: 'VIDEO-' + now_playing.title,
            title: now_playing.title.lastIndexOf('.') !== -1 ?
              now_playing.title.slice(0, now_playing.title.lastIndexOf('.')) : now_playing.title,
            artist: '',
            mediaType: 'VIDEO',
            mediaSize: 0,
            startPosition: now_playing.last_play,
            duration: now_playing.time,
            albumCoverUri: PathUtils.coverPath + now_playing.date,
            albumTitle: '',
            mediaUri: uri,
            appName: ToolsUtil.getStringResource(($r('app.string.EntryAbility_label').id))
          }
        }
      } else {
        const file = fileIo.openSync(uri)
        fd = file.fd
        let avFileDescriptor: media.AVFileDescriptor = { fd: file.fd }
        const videoSize = await VideoInfoUtil.getVideoSize(PrivacySpaceUtil.getPrivacyMode()! ?
          PathUtils.videoPath + now_playing.date : uri, true) as number
        playItem = {
          itemId: 0,
          description: {
            assetId: 'VIDEO-' + now_playing.title,
            title: now_playing.title.lastIndexOf('.') !== -1 ?
              now_playing.title.slice(0, now_playing.title.lastIndexOf('.')) : now_playing.title,
            artist: '',
            mediaType: 'VIDEO',
            mediaSize: videoSize,
            startPosition: now_playing.last_play,
            duration: now_playing.time,
            albumCoverUri: PathUtils.coverPath + now_playing.date,
            albumTitle: '',
            fdSrc: avFileDescriptor,
            appName: ToolsUtil.getStringResource(($r('app.string.EntryAbility_label').id))
          }
        }
      }
      AVSessionUtil.castController?.prepare(playItem, () => {
        salmonLogger.addLog(TAG, 'Preparation done')
        AVSessionUtil.castController?.start(playItem, () => {
          salmonLogger.addLog(TAG, 'Playback started')
          if (fd !== undefined) {
            try {
              fileIo.closeSync(fd)
            } catch (e) {
              salmonLogger.addLog(TAG, 'closeSync error: ' + e, true)
            }
          }
        })
      })
    } catch (error) {
      salmonLogger.addLog(TAG, 'play item error:' + error, true)
      ToolsUtil.showToast('投播失败')
    }
  }
}
