import { uniformTypeDescriptor } from '@kit.ArkData'
import { deviceInfo, SuppressWarnings, SuppressWarningsType } from '@kit.BasicServicesKit'
import { fileIo, fileUri } from '@kit.CoreFileKit'
import { window } from '@kit.ArkUI'
import { harmonyShare, systemShare } from '@kit.ShareKit'
import { salmonLogger } from 'salmonlogger'
import { SUPPORT_AUDIO_FORMAT } from '../common/Constants'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import PermissionUtil from './PermissionUtil'
import { PathUtils } from './PathUtils'
import ToolsUtil from './ToolsUtil'
import PrivacySpaceUtil from './PrivacySpaceUtil'
import KnockReceiveStorage from './KnockReceiveStorage'

const TAG = 'KnockShareUtil'

export const KNOCK_SHARE_INDEX_OWNER = 'index'

export const KNOCK_SHARE_VIDEO_PLAYER_OWNER = 'video-player'

const MAX_RECEIVE_COUNT = 5

export class KnockCoordinate {
  x: number
  y: number

  constructor(x: number, y: number) {
    this.x = x
    this.y = y
  }
}

export class KnockReceivePayload {
  uris: string[]
  anchorVideoDate: string | undefined
  privateMode: boolean
  receivePath: string

  constructor(uris: string[], anchorVideoDate: string | undefined, privateMode: boolean, receivePath: string) {
    this.uris = uris
    this.anchorVideoDate = anchorVideoDate
    this.privateMode = privateMode
    this.receivePath = receivePath
  }
}

class KnockVideoRegion {
  video: VideoMetadata
  left: number
  top: number
  right: number
  bottom: number

  constructor(video: VideoMetadata, left: number, top: number, right: number, bottom: number) {
    this.video = video
    this.left = left
    this.top = top
    this.right = right
    this.bottom = bottom
  }

  contains(coordinate: KnockCoordinate): boolean {
    return coordinate.x >= this.left && coordinate.x <= this.right &&
      coordinate.y >= this.top && coordinate.y <= this.bottom
  }
}

export type KnockShareProvider = (coordinate: KnockCoordinate | undefined) => VideoMetadata[]

export type KnockReceiveHandler = (payload: KnockReceivePayload) => Promise<void>

export type KnockProviderActiveResolver = () => boolean

/**
 * 应用级碰一碰控制器。
 *
 * EntryAbility 负责前后台注册；页面只提供当前可分享媒体和接收后的导入处理。
 */
export default class KnockShareUtil {
  private static context: Context | undefined = undefined
  private static mainWindow: window.Window | undefined = undefined
  private static sendCapability: harmonyShare.SendCapabilityRegistry | undefined = undefined
  private static receiveCapability: harmonyShare.RecvCapabilityRegistry | undefined = undefined
  private static sendRegistered: boolean = false
  private static receiveRegistered: boolean = false
  private static providerOwner: string = ''
  private static shareProvider: KnockShareProvider | undefined = undefined
  private static providerActiveResolver: KnockProviderActiveResolver | undefined = undefined
  private static receiveHandler: KnockReceiveHandler | undefined = undefined
  private static pendingReceivePayloads: KnockReceivePayload[] = []
  private static receiveQueue: Promise<void> = Promise.resolve()
  private static videoRegions: Map<string, KnockVideoRegion> = new Map()

  @SuppressWarnings({ rules: [SuppressWarningsType.SYSCAP] })
  static isSupported(): boolean {
    return canIUse('SystemCapability.Collaboration.HarmonyShare')
  }

  static isPc(): boolean {
    return deviceInfo.deviceType === deviceInfo.DeviceTypes.TYPE_2IN1
  }

  @SuppressWarnings({ rules: [SuppressWarningsType.SYSCAP] })
  static isPreciseSupported(): boolean {
    return KnockShareUtil.isPc() && deviceInfo.apiAvailable('26.0.0')
  }

  @SuppressWarnings({ rules: [SuppressWarningsType.SYSCAP] })
  static start(context: Context, mainWindow: window.Window): void {
    if (!KnockShareUtil.isSupported()) {
      return
    }
    let windowId = 0
    try {
      windowId = mainWindow.getWindowProperties().id
      if (KnockShareUtil.sendRegistered && KnockShareUtil.mainWindow?.getWindowProperties().id === windowId) {
        return
      }
      KnockShareUtil.stop()
      KnockShareUtil.context = context
      KnockShareUtil.mainWindow = mainWindow
      if (KnockShareUtil.isPc()) {
        KnockShareUtil.sendCapability = { windowId: windowId, sendOnly: false }
        harmonyShare.on('knockShare', KnockShareUtil.sendCapability, KnockShareUtil.knockCallback)
      } else {
        harmonyShare.on('knockShare', KnockShareUtil.knockCallback)
      }
      KnockShareUtil.sendRegistered = true
      salmonLogger.addLog(TAG, '碰一碰发送监听已注册', false)
    } catch (error) {
      salmonLogger.addLog(TAG, `注册碰一碰发送监听失败: ${error}`, true)
    }

    if (!KnockShareUtil.isPc()) {
      return
    }
    try {
      KnockShareUtil.receiveCapability = {
        windowId: windowId,
        capabilities: [
          { utd: uniformTypeDescriptor.UniformDataType.VIDEO, maxSupportedCount: MAX_RECEIVE_COUNT },
          { utd: uniformTypeDescriptor.UniformDataType.AUDIO, maxSupportedCount: MAX_RECEIVE_COUNT }
        ]
      }
      harmonyShare.on('dataReceive', KnockShareUtil.receiveCapability, KnockShareUtil.receiveCallback)
      KnockShareUtil.receiveRegistered = true
      salmonLogger.addLog(TAG, '碰一碰沙箱接收监听已注册', false)
    } catch (error) {
      salmonLogger.addLog(TAG, `注册碰一碰接收监听失败: ${error}`, true)
    }
  }

  @SuppressWarnings({ rules: [SuppressWarningsType.SYSCAP] })
  static stop(): void {
    if (!KnockShareUtil.isSupported()) {
      return
    }
    if (KnockShareUtil.sendRegistered) {
      try {
        if (KnockShareUtil.sendCapability) {
          harmonyShare.off('knockShare', KnockShareUtil.sendCapability, KnockShareUtil.knockCallback)
        } else {
          harmonyShare.off('knockShare', KnockShareUtil.knockCallback)
        }
      } catch (error) {
        salmonLogger.addLog(TAG, `取消碰一碰发送监听失败: ${error}`, true)
      }
    }
    if (KnockShareUtil.receiveRegistered && KnockShareUtil.receiveCapability) {
      try {
        harmonyShare.off('dataReceive', KnockShareUtil.receiveCapability, KnockShareUtil.receiveCallback)
      } catch (error) {
        salmonLogger.addLog(TAG, `取消碰一碰接收监听失败: ${error}`, true)
      }
    }
    KnockShareUtil.sendRegistered = false
    KnockShareUtil.receiveRegistered = false
    KnockShareUtil.sendCapability = undefined
    KnockShareUtil.receiveCapability = undefined
  }

  static setShareProvider(owner: string, provider: KnockShareProvider,
    activeResolver?: KnockProviderActiveResolver): void {
    KnockShareUtil.providerOwner = owner
    KnockShareUtil.shareProvider = provider
    KnockShareUtil.providerActiveResolver = activeResolver
  }

  static clearShareProvider(owner: string): void {
    if (KnockShareUtil.providerOwner !== owner) {
      return
    }
    KnockShareUtil.providerOwner = ''
    KnockShareUtil.shareProvider = undefined
    KnockShareUtil.providerActiveResolver = undefined
  }

  static setReceiveHandler(handler: KnockReceiveHandler): void {
    KnockShareUtil.receiveHandler = handler
    const pendingPayloads = [...KnockShareUtil.pendingReceivePayloads]
    KnockShareUtil.pendingReceivePayloads = []
    pendingPayloads.forEach((payload: KnockReceivePayload) => {
      KnockShareUtil.enqueueReceive(payload)
    })
  }

  static updateVideoRegion(video: VideoMetadata, area: Area): void {
    if (!KnockShareUtil.isPreciseSupported()) {
      return
    }
    const x = Number(area.globalPosition.x)
    const y = Number(area.globalPosition.y)
    const width = Number(area.width)
    const height = Number(area.height)
    if (!Number.isFinite(x) || !Number.isFinite(y) || !Number.isFinite(width) || !Number.isFinite(height) ||
      width <= 0 || height <= 0) {
      KnockShareUtil.videoRegions.delete(video.date)
      return
    }
    const left = vp2px(x)
    const top = vp2px(y)
    KnockShareUtil.videoRegions.set(video.date,
      new KnockVideoRegion(video, left, top, left + vp2px(width), top + vp2px(height)))
  }

  static setVideoRegionVisible(videoDate: string, visible: boolean): void {
    if (!visible) {
      KnockShareUtil.videoRegions.delete(videoDate)
    }
  }

  private static readonly knockCallback = (target: harmonyShare.SharableTarget): void => {
    void KnockShareUtil.handleKnockShare(target)
  }
  private static readonly receiveCallback = (target: harmonyShare.ReceivableTarget): void => {
    KnockShareUtil.handleDataReceive(target)
  }

  private static enqueueReceive(payload: KnockReceivePayload): void {
    KnockShareUtil.receiveQueue = KnockShareUtil.receiveQueue.then(async (): Promise<void> => {
      const handler = KnockShareUtil.receiveHandler
      if (!handler) {
        KnockShareUtil.pendingReceivePayloads.push(payload)
        return
      }
      let saveFailed = 0
      if (!payload.privateMode) {
        let directory = ''
        try {
          directory = await KnockReceiveStorage.getDownloadDirectory()
        } catch (error) {
          salmonLogger.addLog(TAG, `获取碰一碰下载目录失败: ${error}`, true)
        }
        const savedUris: string[] = []
        for (const uri of payload.uris) {
          try {
            if (!directory) {
              throw new Error('下载目录不可用或未授权')
            }
            savedUris.push(await KnockReceiveStorage.saveToDownloads(uri, payload.receivePath, directory))
          } catch (error) {
            // 转存失败也保留可操作的媒体库条目，用户可以从列表导出或删除源文件。
            savedUris.push(uri)
            saveFailed++
            salmonLogger.addLog(TAG, `碰一碰文件转存失败: ${error}`, true)
          }
        }
        payload.uris = savedUris
      }
      try {
        const receiveTask: Promise<void> = handler(payload)
        await receiveTask
      } finally {
        await KnockReceiveStorage.removeEmptyReceiveDirectory(payload.receivePath)
        if (saveFailed > 0) {
          ToolsUtil.showToast(`${saveFailed} 个文件未能转存到下载目录，暂留应用内，可从列表导出`)
        }
      }
    }).catch((error: Error) => {
      salmonLogger.addLog(TAG, `导入碰一碰接收文件失败: ${error.message}`, true)
      ToolsUtil.showToast('文件已接收，但导入媒体库失败')
    })
  }

  private static findVideoAt(coordinate: KnockCoordinate): VideoMetadata | undefined {
    let matched: KnockVideoRegion | undefined = undefined
    for (const region of KnockShareUtil.videoRegions.values()) {
      if (!region.contains(coordinate)) {
        continue
      }
      if (!matched || (region.right - region.left) * (region.bottom - region.top) <
        (matched.right - matched.left) * (matched.bottom - matched.top)) {
        matched = region
      }
    }
    return matched ? matched.video : undefined
  }

  private static getFallbackPlayingVideo(): VideoMetadata | undefined {
    const nowPlayingData = AppStorage.get('nowPlayingData') as (number | VideoMetadata | boolean)[] | undefined
    return nowPlayingData && nowPlayingData[1] ? nowPlayingData[1] as VideoMetadata : undefined
  }

  @SuppressWarnings({ rules: [SuppressWarningsType.SYSCAP] })
  private static getWindowCoordinate(target: harmonyShare.SharableTarget | harmonyShare.ReceivableTarget):
  KnockCoordinate | undefined {
    if (!KnockShareUtil.isPreciseSupported()) {
      return undefined
    }
    try {
      const coordinate = target.getInfo().coordinate
      if (!coordinate) {
        return undefined
      }
      const windowRect = KnockShareUtil.mainWindow?.getWindowProperties().windowRect
      return new KnockCoordinate(coordinate.screenX - (windowRect?.left ?? 0),
        coordinate.screenY - (windowRect?.top ?? 0))
    } catch (error) {
      salmonLogger.addLog(TAG, `获取精准碰一碰坐标失败: ${error}`, true)
      return undefined
    }
  }

  private static getShareVideos(coordinate: KnockCoordinate | undefined): VideoMetadata[] {
    if (KnockShareUtil.providerActiveResolver && !KnockShareUtil.providerActiveResolver()) {
      return []
    }
    const provided = KnockShareUtil.shareProvider?.(coordinate) ?? []
    if (provided.length > 0) {
      return provided
    }
    if (KnockShareUtil.providerOwner === KNOCK_SHARE_INDEX_OWNER && coordinate) {
      const hitVideo = KnockShareUtil.findVideoAt(coordinate)
      if (hitVideo) {
        return [hitVideo]
      }
    }
    if (KnockShareUtil.shareProvider) {
      return []
    }
    const playingVideo = KnockShareUtil.getFallbackPlayingVideo()
    return playingVideo ? [playingVideo] : []
  }

  private static getFileExtension(video: VideoMetadata): string {
    const titleDotIndex = video.title.lastIndexOf('.')
    if (titleDotIndex >= 0 && titleDotIndex < video.title.length - 1) {
      return video.title.substring(titleDotIndex)
    }
    const format = video.format.startsWith('.') ? video.format : `.${video.format}`
    return format === '.' ? '' : format
  }

  private static createSharedRecord(video: VideoMetadata): systemShare.SharedRecord {
    let utd: string = SUPPORT_AUDIO_FORMAT.includes(video.format.toLowerCase()) ?
      uniformTypeDescriptor.UniformDataType.AUDIO : uniformTypeDescriptor.UniformDataType.VIDEO
    const extension = KnockShareUtil.getFileExtension(video)
    if (extension) {
      try {
        const detectedUtd = uniformTypeDescriptor.getUniformDataTypeByFilenameExtension(extension)
        if (detectedUtd) {
          utd = detectedUtd
        }
      } catch (error) {
        salmonLogger.addLog(TAG, `通过扩展名获取 UTD 失败: ${extension}, ${error}`, true)
      }
    }
    const record: systemShare.SharedRecord = {
      utd: utd,
      uri: video.uri,
      title: video.title,
      description: '流心播放器碰一碰分享'
    }
    if (canIUse('SystemCapability.Collaboration.SystemShare')) {
      try {
        if (fileIo.accessSync(`${PathUtils.coverPath}${video.date}`)) {
          record.thumbnailUri = PathUtils.coverUri(video.date)
        }
      } catch (error) {
        salmonLogger.addLog(TAG, `碰一碰分享封面不可用: ${error}`, false)
      }
    }
    return record
  }

  @SuppressWarnings({ rules: [SuppressWarningsType.SYSCAP] })
  private static async rejectNoContent(target: harmonyShare.SharableTarget): Promise<void> {
    try {
      await target.reject(harmonyShare.SharableErrorCode.NO_CONTENT_ERROR)
    } catch (error) {
      salmonLogger.addLog(TAG, `拒绝空内容分享失败: ${error}`, true)
    }
  }

  @SuppressWarnings({ rules: [SuppressWarningsType.SYSCAP] })
  private static async handleKnockShare(target: harmonyShare.SharableTarget): Promise<void> {
    const coordinate = KnockShareUtil.getWindowCoordinate(target)
    let videos = KnockShareUtil.getShareVideos(coordinate)
    videos = videos.filter((video: VideoMetadata, index: number, items: VideoMetadata[]) =>
    !ToolsUtil.isNetworkUrl(video.uri) && items.findIndex((item: VideoMetadata) => item.uri === video.uri) === index)
    if (videos.length === 0) {
      await KnockShareUtil.rejectNoContent(target)
      return
    }

    const records: systemShare.SharedRecord[] = []
    for (const video of videos) {
      if (await PermissionUtil.activatePermission(video.uri)) {
        records.push(KnockShareUtil.createSharedRecord(video))
      }
    }
    if (records.length === 0) {
      await KnockShareUtil.rejectNoContent(target)
      return
    }

    const sharedData = new systemShare.SharedData(records[0])
    try {
      for (let index = 1; index < records.length; index++) {
        sharedData.addRecord(records[index])
      }
      await target.share(sharedData)
      salmonLogger.addLog(TAG, `碰一碰分享已发起，文件数=${records.length}`, false)
    } catch (error) {
      salmonLogger.addLog(TAG, `碰一碰分享失败: ${error}`, true)
      ToolsUtil.showToast('碰一碰分享失败')
    }
  }

  private static resolveReceiveAnchor(coordinate: KnockCoordinate | undefined): string | undefined {
    if (!coordinate) {
      return undefined
    }
    if (KnockShareUtil.providerActiveResolver && !KnockShareUtil.providerActiveResolver()) {
      return undefined
    }
    if (KnockShareUtil.providerOwner === KNOCK_SHARE_INDEX_OWNER) {
      return KnockShareUtil.findVideoAt(coordinate)?.date
    }
    if (KnockShareUtil.providerOwner === KNOCK_SHARE_VIDEO_PLAYER_OWNER) {
      return KnockShareUtil.getFallbackPlayingVideo()?.date
    }
    return undefined
  }

  @SuppressWarnings({ rules: [SuppressWarningsType.SYSCAP] })
  private static handleDataReceive(target: harmonyShare.ReceivableTarget): void {
    const context = KnockShareUtil.context
    if (!context) {
      void target.reject(harmonyShare.ReceivableErrorCode.NO_RECEIVABLE_ERROR)
      return
    }
    const anchorVideoDate = KnockShareUtil.resolveReceiveAnchor(KnockShareUtil.getWindowCoordinate(target))
    // 在传输开始时固定目的地，退出隐私空间也不能把本次私密文件公开。
    const privateMode = PrivacySpaceUtil.getPrivacyMode() === true
    let receivePath = ''
    try {
      const receiveRoot = `${context.filesDir}/knock_share`
      fileIo.mkdirSync(receiveRoot, true)
      receivePath = fileIo.mkdtempSync(`${receiveRoot}/receive-XXXXXX`)
    } catch (error) {
      salmonLogger.addLog(TAG, `创建碰一碰接收目录失败: ${error}`, true)
      void target.reject(harmonyShare.ReceivableErrorCode.NO_RECEIVABLE_ERROR)
      return
    }

    void target.receive(fileUri.getUriFromPath(receivePath), {
      onDataReceived: (sharedData: systemShare.SharedData): void => {
        const uris: string[] = []
        sharedData.getRecords().forEach((record: systemShare.SharedRecord) => {
          if (record.uri) {
            uris.push(record.uri)
          }
        })
        if (uris.length === 0) {
          return
        }
        KnockShareUtil.enqueueReceive(new KnockReceivePayload(uris, anchorVideoDate, privateMode, receivePath))
      },
      onResult: (resultCode: harmonyShare.ShareResultCode): void => {
        if (resultCode === harmonyShare.ShareResultCode.SHARE_SUCCESS) {
          salmonLogger.addLog(TAG, '碰一碰文件接收成功', false)
        } else {
          salmonLogger.addLog(TAG, `碰一碰文件接收失败，resultCode=${resultCode}`, true)
        }
      }
    }).catch((error: BusinessError) => {
      salmonLogger.addLog(TAG, `启动碰一碰文件接收失败: ${error.code}, ${error.message}`, true)
      ToolsUtil.showToast('碰一碰文件接收失败')
    })
  }
}
