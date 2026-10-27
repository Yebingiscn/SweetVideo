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

export interface AVSessionControlCallbacks {
  play: () => void | Promise<void>
  pause: () => void | Promise<void>
  seek: (position: number) => void | Promise<void>
  fastForward: () => void | Promise<void>
  rewind: () => void | Promise<void>
  setLoopMode: (mode: avSession.LoopMode) => void | Promise<void>
  playNext?: () => void | Promise<void>
  playPrevious?: () => void | Promise<void>
  outputDeviceChange?: (state: avSession.ConnectionState, device: avSession.OutputDeviceInfo) => void | Promise<void>
}

interface AVSessionPlayerBinding {
  session: avSessionManager.AVSession
  owner: Object
  callbacks: AVSessionControlCallbacks
  unsubscribe: Array<() => void>
}

const TAG = 'AVSessionUtil'

// 播控中心设置类
export default class AVSessionUtil {
  static avSession: avSessionManager.AVSession | undefined = undefined
  static castController: avSession.AVCastController | undefined = undefined
  static currentNowPlaying: VideoMetadata | undefined = undefined
  static pixelMap: image.PixelMap | undefined
  static isOutputDeviceListenerRegistered: boolean = false
  private static sessionCreationTask: Promise<avSessionManager.AVSession | undefined> | undefined = undefined
  private static sessionVersion: number = 0
  private static castRequestVersion: number = 0
  private static castDeviceId: string = ''
  private static currentPositionReader: (() => number) | undefined = undefined
  private static currentPlaybackPosition: number = 0
  private static outputDeviceListener: ((state: avSession.ConnectionState,
    device: avSession.OutputDeviceInfo) => void) | undefined = undefined
  private static playerBinding: AVSessionPlayerBinding | undefined = undefined
  private static castExtrasConfigured: boolean = false
  private static metadataKey: string = ''
  private static coverAssetKey: string = ''
  private static coverRequestVersion: number = 0
  static playbackSpeed: number = 1
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

  static isPlayerBound(session: avSessionManager.AVSession | undefined, owner: Object): boolean {
    const binding = AVSessionUtil.playerBinding
    return session !== undefined && session === AVSessionUtil.avSession &&
      binding?.session === session && binding.owner === owner
  }

  static bindPlayer(session: avSessionManager.AVSession | undefined, owner: Object,
    callbacks: AVSessionControlCallbacks): boolean {
    if (!session || session !== AVSessionUtil.avSession) return false
    const previous = AVSessionUtil.playerBinding
    if (AVSessionUtil.isPlayerBound(session, owner) && previous &&
      !!previous.callbacks.playNext === !!callbacks.playNext &&
      !!previous.callbacks.playPrevious === !!callbacks.playPrevious) {
      previous.callbacks = callbacks
      return true
    }
    AVSessionUtil.clearPlayerBinding()
    if (!AVSessionUtil.ensureOutputDeviceListener(session)) return false
    const binding: AVSessionPlayerBinding = { session, owner, callbacks, unsubscribe: [] }
    AVSessionUtil.playerBinding = binding
    const current = (): AVSessionControlCallbacks | undefined =>
      AVSessionUtil.playerBinding === binding && AVSessionUtil.avSession === session ? binding.callbacks : undefined
    const subscribe = (register: () => void, unregister: () => void): void => {
      // 即使注册中途失败，也精确清理本次尝试，避免重试时遗留部分回调。
      binding.unsubscribe.push(unregister)
      register()
    }
    const play = (): void => AVSessionUtil.runControl(() => current()?.play())
    const pause = (): void => AVSessionUtil.runControl(() => current()?.pause())
    const seek = (position: number): void => AVSessionUtil.runControl(() => current()?.seek(position))
    const fastForward = (): void => AVSessionUtil.runControl(() => current()?.fastForward())
    const rewind = (): void => AVSessionUtil.runControl(() => current()?.rewind())
    const setLoopMode = (mode: avSession.LoopMode): void =>
      AVSessionUtil.runControl(() => current()?.setLoopMode(mode))
    const playNext = (): void => AVSessionUtil.runControl(() => current()?.playNext?.())
    const playPrevious = (): void => AVSessionUtil.runControl(() => current()?.playPrevious?.())
    try {
      subscribe(() => session.on('play', play), () => session.off('play', play))
      subscribe(() => session.on('pause', pause), () => session.off('pause', pause))
      subscribe(() => session.on('seek', seek), () => session.off('seek', seek))
      subscribe(() => session.on('fastForward', fastForward), () => session.off('fastForward', fastForward))
      subscribe(() => session.on('rewind', rewind), () => session.off('rewind', rewind))
      subscribe(() => session.on('setLoopMode', setLoopMode), () => session.off('setLoopMode', setLoopMode))
      if (callbacks.playNext) {
        subscribe(() => session.on('playNext', playNext), () => session.off('playNext', playNext))
      }
      if (callbacks.playPrevious) {
        subscribe(() => session.on('playPrevious', playPrevious), () => session.off('playPrevious', playPrevious))
      }
      if (AVSessionUtil.playerBinding !== binding) {
        AVSessionUtil.clearPlayerBinding(binding)
        return false
      }
      return true
    } catch (error) {
      AVSessionUtil.clearPlayerBinding(binding)
      salmonLogger.addLog(TAG, `注册播控监听失败: code=${(error as BusinessError).code}`, true)
      return false
    }
  }

  static unbindPlayer(owner: Object): void {
    if (AVSessionUtil.playerBinding?.owner === owner) AVSessionUtil.clearPlayerBinding()
  }

  private static clearPlayerBinding(binding: AVSessionPlayerBinding | undefined = AVSessionUtil.playerBinding): void {
    if (!binding) return
    if (AVSessionUtil.playerBinding === binding) {
      AVSessionUtil.playerBinding = undefined
      AVSessionUtil.currentPositionReader = undefined
    }
    const unsubscribe = binding.unsubscribe
    binding.unsubscribe = []
    unsubscribe.forEach((unregister: () => void) => {
      try {
        unregister()
      } catch (error) {
        salmonLogger.addLog(TAG, `注销播控监听失败: code=${(error as BusinessError).code}`, true)
      }
    })
  }

  private static runControl(action: () => void | Promise<void>): void {
    try {
      Promise.resolve(action()).catch((error: BusinessError) => {
        salmonLogger.addLog(TAG, `执行播控指令失败: code=${error?.code}`, true)
      })
    } catch (error) {
      salmonLogger.addLog(TAG, `执行播控指令失败: code=${(error as BusinessError).code}`, true)
    }
  }

  static async getAVSession(): Promise<avSessionManager.AVSession | undefined> {
    if (!AVSessionUtil.avSession) {
      if (!AVSessionUtil.sessionCreationTask) {
        AVSessionUtil.sessionCreationTask = AVSessionUtil.createSession()
      }
      try {
        await AVSessionUtil.sessionCreationTask
      } finally {
        AVSessionUtil.sessionCreationTask = undefined
      }
    }
    return AVSessionUtil.avSession
  }

  static async stopCastingIfActive(): Promise<void> {
    const session = AVSessionUtil.avSession
    if (!session || !AVSessionUtil.castController) {
      return
    }
    AVSessionUtil.castRequestVersion++
    AVSessionUtil.castDeviceId = ''
    AVSessionUtil.castController = undefined
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
  static updatePlaybackSessionState(playing: boolean, playTime: number,
    repeatMode?: SweetRepeatMode, speed?: number) {
    if (Number.isFinite(playTime)) {
      AVSessionUtil.currentPlaybackPosition = Math.max(0, playTime)
    }
    if (!AVSessionUtil.avSession) {
      return
    }
    if (speed !== undefined && speed > 0) {
      AVSessionUtil.playbackSpeed = speed
    }
    let data: AvSessionState = {
      playing: playing,
      duration: Math.max(0, playTime),
      speed: AVSessionUtil.playbackSpeed,
    }
    AVSessionUtil.updateSession(data, repeatMode)
  }

  static castOnStateChange(state: AVCastPickerState) {
    if (state == AVCastPickerState.STATE_APPEARING) {
      salmonLogger.addLog(TAG, 'The picker starts showing.')
    } else if (state == AVCastPickerState.STATE_DISAPPEARING) {
      salmonLogger.addLog(TAG, 'The picker finishes presenting.')
    }
  }

  static async updateBackgroundPlayMode(enabled: boolean): Promise<void> {
    const session = AVSessionUtil.avSession
    if (!session) {
      return
    }
    const backgroundMode = enabled ?
      avSession.BackgroundPlayMode.ENABLE_BACKGROUND_PLAY :
      avSession.BackgroundPlayMode.DISABLE_BACKGROUND_PLAY
    try {
      await session.setBackgroundPlayMode(backgroundMode)
      salmonLogger.addLog(TAG, `AVSession background mode updated: ${backgroundMode}`, false)
    } catch (error) {
      salmonLogger.addLog(TAG, `update AVSession background mode error: ${error}`, true)
    }
  }

  private static async createSession(): Promise<avSessionManager.AVSession | undefined> {
    let type: avSessionManager.AVSessionType = 'video'
    const sessionVersion = AVSessionUtil.sessionVersion
    let session: avSessionManager.AVSession | undefined = undefined
    try {
      session = await avSessionManager.createAVSession(PathUtils.appContext!, 'sweet_video', type)
      const backgroundMode = Setting.allowBackgroundPlay ?
        avSession.BackgroundPlayMode.ENABLE_BACKGROUND_PLAY :
        avSession.BackgroundPlayMode.DISABLE_BACKGROUND_PLAY
      try {
        await session.setBackgroundPlayMode(backgroundMode)
      } catch (error) {
        salmonLogger.addLog(TAG, `setBackgroundPlayMode error: ${error}`, true)
      }
      await session.activate()
      if (sessionVersion !== AVSessionUtil.sessionVersion) {
        await session.destroy()
        return undefined
      }
      AVSessionUtil.avSession = session
      salmonLogger.addLog(TAG, `AVSession created and activated, backgroundMode=${backgroundMode}`, false)
      return session
    } catch (error) {
      salmonLogger.addLog(TAG, 'create session error:' + error, true)
      if (session) {
        try {
          await session.destroy()
        } catch (_destroyError) {
        }
      }
      return undefined
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

  static async setSessionInfo(metadata: VideoMetadata, positionReader?: () => number, owner?: Object) {
    const binding = AVSessionUtil.playerBinding
    if (owner !== undefined && binding?.owner !== owner) return
    const session = await AVSessionUtil.getAVSession()
    if (!session) {
      salmonLogger.addLog(TAG, 'setSessionInfo skipped: AVSession is unavailable', true)
      return
    }
    if (owner !== undefined && (AVSessionUtil.playerBinding !== binding ||
      !AVSessionUtil.isPlayerBound(session, owner))) return
    const sameAsset = AVSessionUtil.currentNowPlaying?.date === metadata.date &&
      AVSessionUtil.currentNowPlaying?.uri === metadata.uri
    if (!sameAsset) {
      AVSessionUtil.castRequestVersion++
      AVSessionUtil.castDeviceId = ''
      AVSessionUtil.currentPlaybackPosition = Math.max(0, metadata.last_play || 0)
      AVSessionUtil.coverRequestVersion++
      AVSessionUtil.coverAssetKey = ''
    }
    AVSessionUtil.currentNowPlaying = metadata
    AVSessionUtil.currentPositionReader = positionReader
    const metadataKey = JSON.stringify([metadata.date, metadata.uri, metadata.title, metadata.time,
      metadata.artist || '', metadata.album || ''])
    const isCurrent = (): boolean => session === AVSessionUtil.avSession &&
      AVSessionUtil.metadataKey === metadataKey && (owner === undefined || AVSessionUtil.playerBinding === binding)
    if (AVSessionUtil.metadataKey === metadataKey && AVSessionUtil.isOutputDeviceListenerRegistered &&
      AVSessionUtil.castExtrasConfigured) {
      return
    }
    AVSessionUtil.metadataKey = metadataKey
    const session_metadata = AVSessionUtil.buildSessionMetadata(metadata, sameAsset ? AVSessionUtil.pixelMap : undefined)
    try {
      await session.setAVMetadata(session_metadata)
    } catch (error) {
      if (isCurrent()) AVSessionUtil.metadataKey = ''
      salmonLogger.addLog(TAG, `setAVMetadata failed: code=${(error as BusinessError).code}`, true)
      return
    }
    if (!isCurrent()) return
    if (!sameAsset) {
      const oldPixelMap = AVSessionUtil.pixelMap
      AVSessionUtil.pixelMap = undefined
      await AVSessionUtil.releaseSessionImage(oldPixelMap)
    }
    if (!isCurrent()) return
    if (!AVSessionUtil.castExtrasConfigured) await AVSessionUtil.registerCastOutputListener(session)
    if (!isCurrent()) return
    const coverKey = JSON.stringify([metadata.date, metadata.uri])
    if (AVSessionUtil.coverAssetKey !== coverKey) {
      AVSessionUtil.coverAssetKey = coverKey
      const coverVersion = ++AVSessionUtil.coverRequestVersion
      // 基础播控信息先就绪；封面异步补齐，不阻塞播放或暂停后的恢复。
      void AVSessionUtil.refreshSessionCover(session, metadata, coverVersion)
    }
  }

  private static buildSessionMetadata(metadata: VideoMetadata, pixelMap?: image.PixelMap): avSessionManager.AVMetadata {
    let session_metadata: avSessionManager.AVMetadata = {
      assetId: metadata.date,
      title: VideoInfoUtil.getVideoTitle(metadata.title),
      duration: metadata.time,
      filter: avSession.ProtocolType.TYPE_CAST_PLUS_STREAM | avSession.ProtocolType.TYPE_DLNA,
    }
    // 封面未就绪时省略字段，显式 undefined 会被系统判为非法参数。
    if (pixelMap) {
      session_metadata.mediaImage = pixelMap
    }
    const artist = metadata.artist?.trim()
    if (artist) {
      session_metadata.artist = artist
    }
    const album = metadata.album?.trim()
    if (album) {
      session_metadata.album = album
    }
    return session_metadata
  }

  private static async releaseSessionImage(pixelMap: image.PixelMap | undefined): Promise<void> {
    if (!pixelMap) return
    try {
      await pixelMap.release()
    } catch (_error) {
    }
  }

  private static async refreshSessionCover(session: avSessionManager.AVSession, metadata: VideoMetadata,
    coverVersion: number): Promise<void> {
    let source: image.ImageSource | undefined
    let pixelMap: image.PixelMap | undefined
    try {
      try {
        source = image.createImageSource(PathUtils.coverPath + metadata.date)
        pixelMap = await source.createPixelMap({ desiredDynamicRange: image.DecodingDynamicRange.AUTO })
      } catch (_error) {
        if (source) {
          await source.release().catch(() => {})
          source = undefined
        }
        if (session !== AVSessionUtil.avSession || coverVersion !== AVSessionUtil.coverRequestVersion) return
        const resource = await PathUtils.appContext!.resourceManager.getMediaContent($r('app.media.sweet_video').id)
        source = image.createImageSource(resource.buffer)
        pixelMap = await source.createPixelMap()
      }
      if (session !== AVSessionUtil.avSession || coverVersion !== AVSessionUtil.coverRequestVersion) return
      const current = AVSessionUtil.currentNowPlaying
      if (!current || current.date !== metadata.date || current.uri !== metadata.uri) return
      await session.setAVMetadata(AVSessionUtil.buildSessionMetadata(current, pixelMap))
      if (session !== AVSessionUtil.avSession || coverVersion !== AVSessionUtil.coverRequestVersion) return
      const oldPixelMap = AVSessionUtil.pixelMap
      AVSessionUtil.pixelMap = pixelMap
      pixelMap = undefined
      await AVSessionUtil.releaseSessionImage(oldPixelMap)
    } catch (error) {
      salmonLogger.addLog(TAG, `Session cover failed: code=${(error as BusinessError).code}`, true)
    } finally {
      await AVSessionUtil.releaseSessionImage(pixelMap)
      if (source) await source.release().catch(() => {})
    }
  }

  static updateSession(avSessionState: AvSessionState, repeatMode?: SweetRepeatMode) {
    let playbackState: avSessionManager.AVPlaybackState = {
      state: avSessionState.playing ? avSessionManager.PlaybackState.PLAYBACK_STATE_PLAY :
        avSessionManager.PlaybackState.PLAYBACK_STATE_PAUSE,
      speed: avSessionState.speed,
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
    AVSessionUtil.clearPlayerBinding()
    AVSessionUtil.metadataKey = ''
    AVSessionUtil.coverAssetKey = ''
    AVSessionUtil.coverRequestVersion++
    const oldPixelMap = AVSessionUtil.pixelMap
    AVSessionUtil.pixelMap = undefined
    void AVSessionUtil.releaseSessionImage(oldPixelMap)
    AVSessionUtil.sessionVersion++
    AVSessionUtil.castRequestVersion++
    AVSessionUtil.castDeviceId = ''
    AVSessionUtil.currentPositionReader = undefined
    AVSessionUtil.currentPlaybackPosition = 0
    AVSessionUtil.currentNowPlaying = undefined
    const session = AVSessionUtil.avSession
    AVSessionUtil.avSession = undefined
    const outputDeviceListener = AVSessionUtil.outputDeviceListener
    AVSessionUtil.isOutputDeviceListenerRegistered = false
    AVSessionUtil.outputDeviceListener = undefined
    AVSessionUtil.castExtrasConfigured = false
    if (session && outputDeviceListener) {
      try {
        session.off('outputDeviceChange', outputDeviceListener)
      } catch (e) {
        salmonLogger.addLog(TAG, 'off outputDeviceChange error: ' + e, true)
      }
    }
    try {
      AVSessionUtil.castController?.off('playbackStateChange')
    } catch (e) {
      salmonLogger.addLog(TAG, 'off playbackStateChange error: ' + e, true)
    }
    AVSessionUtil.castController = undefined
    AVSessionUtil.currentNowPlaying = undefined
    AVSessionUtil.playbackSpeed = 1
    session?.destroy()?.catch(() => {
      salmonLogger.addLog(TAG, 'destroy Session error', true)
    })
  }

  private static ensureOutputDeviceListener(session: avSessionManager.AVSession): boolean {
    if (session !== AVSessionUtil.avSession) return false
    if (AVSessionUtil.isOutputDeviceListenerRegistered) return true
    const listener = (connectState: avSession.ConnectionState, device: avSession.OutputDeviceInfo): void => {
      if (session !== AVSessionUtil.avSession || AVSessionUtil.outputDeviceListener !== listener) return
      const binding = AVSessionUtil.playerBinding
      if (binding?.session === session) {
        AVSessionUtil.runControl(() => binding.callbacks.outputDeviceChange?.(connectState, device))
      }
      AVSessionUtil.handleOutputDeviceChange(session, connectState, device).catch((error: BusinessError) => {
        salmonLogger.addLog(TAG, `handle outputDeviceChange failed: code=${error.code}`, true)
      })
    }
    try {
      session.on('outputDeviceChange', listener)
      AVSessionUtil.outputDeviceListener = listener
      AVSessionUtil.isOutputDeviceListenerRegistered = true
      salmonLogger.addLog(TAG, 'Cast output device listener registered', false)
      return true
    } catch (error) {
      try {
        session.off('outputDeviceChange', listener)
      } catch (_error) {
      }
      salmonLogger.addLog(TAG, `注册输出设备监听失败: code=${(error as BusinessError).code}`, true)
      return false
    }
  }

  private static async registerCastOutputListener(session: avSessionManager.AVSession): Promise<void> {
    try {
      await session.setExtras({ requireAbilityList: ['url-cast'] })
      if (session !== AVSessionUtil.avSession) return
      AVSessionUtil.castExtrasConfigured = AVSessionUtil.ensureOutputDeviceListener(session)
    } catch (error) {
      salmonLogger.addLog(TAG, 'registerCastOutputListener error: ' + error, true)
    }
  }

  private static async handleOutputDeviceChange(session: avSessionManager.AVSession,
    connectState: avSession.ConnectionState, outputDevice: avSession.OutputDeviceInfo): Promise<void> {
    if (session !== AVSessionUtil.avSession) {
      return
    }
    const devices = outputDevice?.devices ?? []
    salmonLogger.addLog(TAG, `outputDeviceChange: state=${connectState}, deviceCount=${devices.length}`, false)
    const currentDevice = devices[0]
    if (connectState !== avSession.ConnectionState.STATE_CONNECTED || !currentDevice ||
      currentDevice.castCategory !== avSession.AVCastCategory.CATEGORY_REMOTE) {
      AVSessionUtil.castRequestVersion++
      AVSessionUtil.castDeviceId = ''
      AVSessionUtil.castController = undefined
      return
    }
    // 同一连接的重复通知不再次 prepare/start，避免把电视播放进度重置。
    if (AVSessionUtil.castDeviceId !== '' && AVSessionUtil.castDeviceId === currentDevice.deviceId) {
      return
    }
    const nowPlaying = AVSessionUtil.currentNowPlaying
    if (!nowPlaying) {
      salmonLogger.addLog(TAG, 'No current nowPlaying data, skip playItem', true)
      return
    }
    const supportedProtocols = currentDevice.supportedProtocols ?? 0
    if ((supportedProtocols & avSession.ProtocolType.TYPE_CAST_PLUS_STREAM) !== 0 ||
      (supportedProtocols & avSession.ProtocolType.TYPE_DLNA) !== 0) {
      const requestVersion = ++AVSessionUtil.castRequestVersion
      AVSessionUtil.castDeviceId = currentDevice.deviceId
      // 连接时读取真实位置，零也有效，不能用 last_play 覆盖主动跳到片头的操作。
      const livePosition = AVSessionUtil.currentPositionReader?.() ?? AVSessionUtil.currentPlaybackPosition
      const startPosition = Number.isFinite(livePosition) ? Math.max(0, Math.floor(livePosition)) : 0
      try {
        const controller = await session.getAVCastController()
        if (!AVSessionUtil.isCastRequestCurrent(session, nowPlaying, requestVersion)) {
          return
        }
        AVSessionUtil.castController = controller
        await AVSessionUtil.playItem(nowPlaying, controller, startPosition, requestVersion, session)
      } catch (error) {
        if (AVSessionUtil.isCastRequestCurrent(session, nowPlaying, requestVersion)) {
          AVSessionUtil.castDeviceId = ''
          salmonLogger.addLog(TAG, `Cast connection failed: code=${(error as BusinessError).code}`, true)
          ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.cast_failed').id))
        }
      }
      return
    }
    salmonLogger.addLog(TAG, `Unsupported protocol: ${supportedProtocols}`, true)
    ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.cast_protocol_unsupported').id))
  }

  private static isCastRequestCurrent(session: avSessionManager.AVSession, metadata: VideoMetadata,
    requestVersion: number): boolean {
    return AVSessionUtil.avSession === session && AVSessionUtil.currentNowPlaying === metadata &&
      AVSessionUtil.castRequestVersion === requestVersion
  }

  private static async playItem(now_playing: VideoMetadata, controller: avSession.AVCastController,
    startPosition: number, requestVersion: number, session: avSessionManager.AVSession): Promise<void> {
    let fd: number | undefined = undefined
    try {
      await PermissionUtil.activatePermission(now_playing.uri)
      if (!AVSessionUtil.isCastRequestCurrent(session, now_playing, requestVersion)) {
        return
      }
      const uri = now_playing?.uri
      if (!uri) {
        salmonLogger.addLog(TAG, 'playItem: uri is empty', true)
        ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.cast_failed_empty_url').id))
        return
      }
      const isNetworkUri = ToolsUtil.isNetworkUrl(uri)
      let playItem: avSession.AVQueueItem
      if (isNetworkUri) {
        playItem = {
          itemId: 0,
          description: {
            assetId: now_playing.date,
            title: VideoInfoUtil.getVideoTitle(now_playing.title),
            artist: now_playing.artist || '',
            mediaType: 'VIDEO',
            mediaSize: 0,
            startPosition: startPosition,
            duration: now_playing.time,
            albumCoverUri: PathUtils.coverPath + now_playing.date,
            albumTitle: now_playing.album || '',
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
            assetId: now_playing.date,
            title: VideoInfoUtil.getVideoTitle(now_playing.title),
            artist: now_playing.artist || '',
            mediaType: 'VIDEO',
            mediaSize: videoSize,
            startPosition: startPosition,
            duration: now_playing.time,
            albumCoverUri: PathUtils.coverPath + now_playing.date,
            albumTitle: now_playing.album || '',
            fdSrc: avFileDescriptor,
            appName: ToolsUtil.getStringResource(($r('app.string.EntryAbility_label').id))
          }
        }
      }
      if (!AVSessionUtil.isCastRequestCurrent(session, now_playing, requestVersion)) {
        return
      }
      salmonLogger.addLog(TAG, `Cast prepare: assetId=${now_playing.date}, startPosition=${startPosition}ms`, false)
      await controller.prepare(playItem)
      if (!AVSessionUtil.isCastRequestCurrent(session, now_playing, requestVersion)) {
        return
      }
      await controller.start(playItem)
      salmonLogger.addLog(TAG, `Cast start command sent: startPosition=${startPosition}ms`, false)
    } catch (error) {
      if (AVSessionUtil.isCastRequestCurrent(session, now_playing, requestVersion)) {
        AVSessionUtil.castDeviceId = ''
        salmonLogger.addLog(TAG, `Cast play failed: code=${(error as BusinessError).code}`, true)
        ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.cast_failed').id))
      }
    } finally {
      if (fd !== undefined) {
        try {
          fileIo.closeSync(fd)
        } catch (error) {
          salmonLogger.addLog(TAG, `Cast close file failed: code=${(error as BusinessError).code}`, true)
        }
      }
    }
  }
}
