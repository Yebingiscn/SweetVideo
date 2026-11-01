import lazy VideoInfoUtil from './VideoInfoUtil'
import BluRayDirectory from './BluRayDirectory'
import { HiCar } from './HiCarUtil'
import lazy { FolderNameSortItem, sortFolderNamesInTaskPool } from './TaskpoolUtil'
import lazy MediaSortUtil from './MediaSortUtil'
import { bundleManager, ConfigurationConstant } from '@kit.AbilityKit'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import { FileFolder } from '../interfaces/FileFolderInterface'
import { PathUtils } from './PathUtils'
import { SortField } from '../common/enum/SortField'
import { salmonLogger } from 'salmonlogger'
import { GB, KB, MB } from '../common/Constants'
import { PromptAction, window } from '@kit.ArkUI'
import { BackgroundColorMode } from '../common/enum/BackgroundColorMode'
import NavigationAddress, { PlayerParams, ShortVideoParams } from '../common/NavigationCommon'
import Preferences from '../database/Preferences'
import DataSyncUtil from './DataSyncUtil'
import FileFolderUtil from './FileFolderUtil'
import { Setting } from './ObservedUtil'
import PrivacySpaceUtil from './PrivacySpaceUtil'
import lazy VideoOperateUtil from './VideoOperateUtil'
import { WindowUtil } from './WindowUtil'
import { updateManager } from '@kit.AppGalleryKit'
import { util } from '@kit.ArkTS'
import { fileIo } from '@kit.CoreFileKit'
import { vibrator } from '@kit.SensorServiceKit'
import { thermal } from '@kit.BasicServicesKit'

const TAG = 'ToolsUtil'

// 工具类
export default class ToolsUtil {
  private static sortRequests: Map<string, number> = new Map()
  static BASE64_PADDING_MOD: number = 4;
  static BASE64_PADDING_INVALID: number = 1;
  private static cachedPromptAction: PromptAction | null = null
  // 震动设置
  private static vibrationEnabled: boolean = true
  private static vibrationEffectSupported: boolean | undefined = undefined

  static checkVipFeature(): boolean {
    const isVip = Preferences.getUserIsVip(PathUtils.appContext!)
    if (!isVip) {
      ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.vip_feature_only').id))
    }
    return isVip
  }

  static showToast(text: string, duration: number = 3500) {
    try {
      const show = (action: PromptAction): void => {
        action.showToast({
          message: text,
          duration: duration,
          alignment: Alignment.Bottom,
          offset: { dx: 0, dy: -100 }
        })
      }
      if (ToolsUtil.cachedPromptAction) {
        show(ToolsUtil.cachedPromptAction)
        return
      }
      window.getLastWindow(PathUtils.appContext!).then((windowClass: window.Window) => {
        ToolsUtil.cachedPromptAction = windowClass.getUIContext().getPromptAction()
        show(ToolsUtil.cachedPromptAction)
      }).catch(() => {
        salmonLogger.addLog(TAG, 'getLastWindow error', true)
      })
    } catch {
      salmonLogger.addLog(TAG, 'show toast error', true)
    }
  }

  static setVibrationEnabled(enabled: boolean) {
    ToolsUtil.vibrationEnabled = enabled
  }

  static startVibration() {
    if (!ToolsUtil.vibrationEnabled || ToolsUtil.vibrationEffectSupported == false) {
      return
    }
    if (canIUse("SystemCapability.Sensors.MiscDevice")) {
      vibrator.startVibration({
        type: 'preset',
        effectId: 'haptic.effect.hard',
        count: 1,
        intensity: 100,
      }, {
        usage: 'physicalFeedback'
      }, (error: BusinessError) => {
        if (error) {
          salmonLogger.addLog(TAG, `Failed to start vibration. Code: ${error.code}, message: ${error.message}` + error,
            true)
          ToolsUtil.vibrationEffectSupported = false
        }
      })
    } else {
      ToolsUtil.vibrationEffectSupported = false
    }
  }

  static getStringResource(resource: number): string {
    try {
      return PathUtils.appContext!.resourceManager.getStringSync(resource)
    } catch (error) {
      salmonLogger.addLog(TAG, 'get String Resource error' + error, true)
      return ''
    }
  }

  // 带占位符的资源取值（Toast 等只能是 string 的场景）
  static getStringResourceArgs(resource: number, arg: string | number): string {
    try {
      return PathUtils.appContext!.resourceManager.getStringSync(resource, arg)
    } catch (error) {
      salmonLogger.addLog(TAG, 'get String Resource Args error' + error, true)
      return ''
    }
  }

  // 双占位符版本（例如「介绍下视频：%s，格式：%s」这类需要 string 的场合）
  static getStringResourceArgs2(resource: number, arg1: string | number, arg2: string | number): string {
    try {
      return PathUtils.appContext!.resourceManager.getStringSync(resource, arg1, arg2)
    } catch (error) {
      salmonLogger.addLog(TAG, 'get String Resource Args2 error' + error, true)
      return ''
    }
  }

  // 五占位符版本（崩溃反馈信息等长模板）
  static getStringResourceArgs5(resource: number, arg1: string | number, arg2: string | number,
    arg3: string | number, arg4: string | number, arg5: string | number): string {
    try {
      return PathUtils.appContext!.resourceManager.getStringSync(resource, arg1, arg2, arg3, arg4, arg5)
    } catch (error) {
      salmonLogger.addLog(TAG, 'get String Resource Args5 error' + error, true)
      return ''
    }
  }

  // 系统文件选择器的过滤项是「名称|扩展名」形式，名称需要本地化；扩展名部分保持不变。
  static localizeSuffixFilter(filters: string[], labelRes: Resource): string[] {
    if (filters.length === 0) {
      return filters
    }
    const pipe = filters[0].indexOf('|')
    if (pipe < 0) {
      return filters
    }
    return [ToolsUtil.getStringResource(labelRes.id) + filters[0].substring(pipe), ...filters.slice(1)]
  }

  static async sortFoldersByNameInTaskPool(list: FileFolder[], ascending: boolean = true,
    pinyinSort: boolean = true): Promise<FileFolder[]> {
    if (list.length <= 1) {
      return [...list]
    }
    const items: FolderNameSortItem[] = list.map((folder, index) =>
    new FolderNameSortItem(folder.date, folder.name || '', index)
    )
    try {
      const indices = await sortFolderNamesInTaskPool(items, ascending, pinyinSort)
      if (indices.length !== list.length || new Set(indices).size !== list.length ||
        indices.some(index => !Number.isInteger(index) || index < 0 || index >= list.length)) {
        throw new Error(ToolsUtil.getStringResource($r('app.string.folder_sort_incomplete').id))
      }
      const sortedFolders = indices.map(index => list[index])
      return sortedFolders
    } catch (error) {
      salmonLogger.addLog(TAG, `folder name sort task failed: ${error}`, true)
      // 任务失败时保留当前顺序，绝不退回 UI 线程的同步拼音排序。
      return [...list]
    }
  }

  static async sortBy(context: Context, list: VideoMetadata[], file_folder: FileFolder | undefined,
    sortType: SortField | '', ascending?: boolean, pinyinSort?: boolean): Promise<VideoMetadata[]> {
    // AppStorage returns undefined until privacy mode is first initialized.
    const privacyAtStart = PrivacySpaceUtil.getPrivacyMode() === true
    const privateMode = !file_folder && privacyAtStart
    const latestFolder = privateMode ? undefined : file_folder
      ? Preferences.getFileFolder(context).find(folder => folder.date === file_folder.date)
      : Preferences.getFileFolder(context).find(folder => folder.name === '首页')
    const latestVideos = privateMode ? Preferences.getVideoMetaDataEncryption(context) : latestFolder?.video_list
    if (!latestVideos) return []
    const key = privateMode ? 'private' : latestFolder?.date ?? 'home'
    const version = (ToolsUtil.sortRequests.get(key) ?? 0) + 1
    ToolsUtil.sortRequests.set(key, version)
    const signature = latestVideos.map(video => video.date + '\n' + video.title)
    const order = latestVideos.map(video => video.date)
    // 调用方列表只提供 ID 顺序；播放中缓存会替换对象，旧元数据不能再写回数据库。
    const source = ToolsUtil.reorderLatestVideos(list, latestVideos)
    let sorted_list: VideoMetadata[]
    switch (sortType) {
      case SortField.NAME:
        sorted_list = await MediaSortUtil.sortByNameProcess(source, ascending, pinyinSort)
        break
      case SortField.DATETIME:
        sorted_list = MediaSortUtil.sortByDatetimeProcess(source, ascending)
        break
      case SortField.TIME:
        sorted_list = MediaSortUtil.sortByTimeProcess(source, ascending)
        break
      case SortField.RECENT_PLAY:
        sorted_list = MediaSortUtil.sortByRecentPlayProcess(source, ascending)
        break
      default:
        sorted_list = await MediaSortUtil.sortByNameProcess(source, ascending)
    }
    // Re-read after the worker: only persist order, never stale playback metadata or deleted items.
    const currentFolder = privateMode ? undefined : Preferences.getFileFolder(context)
      .find(folder => folder.date === latestFolder?.date)
    const current = privateMode ? Preferences.getVideoMetaDataEncryption(context) : currentFolder?.video_list
    if (!current) return []
    if (ToolsUtil.sortRequests.get(key) !== version ||
      (PrivacySpaceUtil.getPrivacyMode() === true) !== privacyAtStart || current.length !== signature.length ||
      current.some((video, index) => video.date !== order[index] || video.date + '\n' + video.title !== signature[index])) {
      return current
    }
    sorted_list = ToolsUtil.reorderLatestVideos(sorted_list, current)
    const isSameOrder = current.length === sorted_list.length &&
      current.every((item, i) => item.date === sorted_list[i].date)
    if (isSameOrder) {
      return sorted_list
    }
    if (currentFolder) {
      FileFolderUtil.updateFileFolder(context, currentFolder, sorted_list)
    } else {
      if (PrivacySpaceUtil.getPrivacyMode()) {
        Preferences.saveVideoMetaDataEncryption(context, sorted_list)
      } else {
        Preferences.saveVideoMetaData(context, sorted_list)
      }
    }
    return sorted_list
  }

  private static reorderLatestVideos(order: VideoMetadata[], latest: VideoMetadata[]): VideoMetadata[] {
    const byDate = new Map<string, VideoMetadata[]>()
    latest.forEach(video => {
      const group = byDate.get(video.date)
      if (group) group.push(video)
      else byDate.set(video.date, [video])
    })
    const result: VideoMetadata[] = []
    const included = new Set<string>()
    order.forEach(video => {
      const current = byDate.get(video.date)
      if (current && !included.has(video.date)) {
        result.push(...current)
        included.add(video.date)
      }
    })
    latest.forEach(video => {
      if (!included.has(video.date)) {
        result.push(...byDate.get(video.date)!)
        included.add(video.date)
      }
    })
    return result
  }

  // 保存密码
  static savePwd(context: Context, passwd: string) {
    Preferences.savePassword(context, passwd)
    ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.set_passwd_tip').id))
  }

  // 点击视频跳转到播放器
  static async routerWhere(pathStack: NavPathStack, item: VideoMetadata, list: VideoMetadata[],
    reverse: boolean = false, skipHistory: boolean = false): Promise<void> {
    DataSyncUtil.lastPlayVideoIndex = list.findIndex(i => i.date === item?.date)
    WindowUtil.setBarColor('#FFFFFF')
    const findResult = Preferences.findVideoByDate(PathUtils.appContext!, item.date)
    const latestItem = findResult[0] ?? item
    const folder_date = findResult[2]
    const playerType = VideoOperateUtil.resolvePlayerType(latestItem, reverse)
    if (!HiCar.enabled && Setting.shortVideoMode && !reverse && !BluRayDirectory.isEntry(latestItem.uri) && !VideoInfoUtil.isMxf(latestItem)) {
      const latestList = list.map(video => video.date === latestItem.date ? latestItem : video)
      .filter(video => !VideoInfoUtil.isMxf(video))
      const initialIndex = Math.max(0, latestList.findIndex(video => video.date === latestItem.date))
      const shortVideoParams = new ShortVideoParams(latestList, initialIndex, skipHistory)
      pathStack.pushPathByName(NavigationAddress.SHORT_VIDEO, shortVideoParams, true)
      return
    }
    const metadata_list = folder_date ? undefined : list
    const playerParams = new PlayerParams(latestItem, metadata_list, undefined, skipHistory, playerType, folder_date)
    pathStack.pushPathByName(NavigationAddress.VIDEO_PLAYER, playerParams, true)
  }

  // 以短视频模式播放：忽略 shortVideoMode 开关，直接跳转短视频页面
  static async routerToShortVideo(pathStack: NavPathStack, item: VideoMetadata, list: VideoMetadata[],
    skipHistory: boolean = false) {
    const findResult = Preferences.findVideoByDate(PathUtils.appContext!, item.date)
    const latestItem = findResult[0] ?? item
    if (BluRayDirectory.isEntry(latestItem.uri) || VideoInfoUtil.isMxf(latestItem)) {
      await ToolsUtil.routerWhere(pathStack, latestItem, list, true, skipHistory)
      return
    }
    const latestList = list.map(video => video.date === latestItem.date ? latestItem : video)
      .filter(video => !VideoInfoUtil.isMxf(video))
    const initialIndex = Math.max(0, latestList.findIndex(video => video.date === latestItem.date))
    WindowUtil.setBarColor('#FFFFFF')
    const shortVideoParams = new ShortVideoParams(latestList, initialIndex, skipHistory)
    pathStack.pushPathByName(NavigationAddress.SHORT_VIDEO, shortVideoParams, true)
  }

  // 获取版本号
  static async getVersionName(): Promise<string> {
    try {
      if (canIUse("SystemCapability.BundleManager.BundleFramework.Core")) {
        const bundleInfo =
          await bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION)
        return bundleInfo.versionName + '(' + bundleInfo.versionCode + ')'
      } else {
        return ToolsUtil.getStringResource($r('app.string.unknown_version').id)
      }
    } catch (error) {
      salmonLogger.addLog(TAG, 'get bundleInfo failed, error is ' + error, true)
      return ToolsUtil.getStringResource($r('app.string.unknown_version').id)
    }
  }

  static checkUpdate() {
    if (canIUse("SystemCapability.AppGalleryService.Distribution.Update")) {
      updateManager.checkAppUpdate(PathUtils.appContext)
        .then((checkResult: updateManager.CheckUpdateResult) => {
          if (checkResult.updateAvailable == updateManager.UpdateAvailableCode.LATER_VERSION_EXIST) {
            updateManager.showUpdateDialog(PathUtils.appContext)
              .then((resultCode: updateManager.ShowUpdateResultCode) => {
                salmonLogger.addLog(TAG, 'showUpdateDialog resultCode:' + resultCode)
              })
              .catch((error: BusinessError) => {
                ToolsUtil.showToast(
                  ToolsUtil.getStringResourceArgs($r('app.string.update_dialog_failed').id, error.message))
                salmonLogger.addLog(TAG, `showUpdateDialog onError.code is ${error.code}, message is ${error.message}`)
              })
          } else {
            ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.no_new_version').id))
          }
        }).catch((error: BusinessError) => {
        ToolsUtil.showToast(ToolsUtil.getStringResourceArgs($r('app.string.check_update_failed').id, error.message))
        salmonLogger.addLog(TAG, `checkAppUpdate onError.code is ${error.code}, message is ${error.message}`, true)
      })
    } else {
      ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.feature_not_supported_short').id))
    }
  }

  static setColorMode(context: Context, select: number) {
    try {
      switch (select) {
        case BackgroundColorMode.AUTO:
          context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET)
          break
        case BackgroundColorMode.LIGHT:
          context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT)
          break
        case BackgroundColorMode.DARK:
          context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK)
          break
      }
    } catch (error) {
      salmonLogger.addLog(TAG, 'set color mode error: ' + error, true)
    }
  }

  static transFileDecodeAsUTF8(filePath: string, decode: string) {
    try {
      const readStream = fileIo.createStreamSync(filePath, "r+")
      const stat = fileIo.statSync(filePath)
      const buffer = new ArrayBuffer(stat.size)
      readStream.readSync(buffer)
      const textDecoder = util.TextDecoder.create(decode, { ignoreBOM: true })
      const text = textDecoder.decodeToString(new Uint8Array(buffer), { stream: false })
      readStream.close()?.catch(() => {
        salmonLogger.addLog(TAG, `文件解码转换失败: ${'未知错误'}`, true)
      })
      const writeStream = fileIo.createStreamSync(filePath, "w+")
      writeStream.writeSync(text, { encoding: 'utf-8' })
      writeStream.close()?.catch(() => {
        salmonLogger.addLog(TAG, `文件解码转换失败: ${'未知错误'}`, true)
      })
    } catch (error) {
      salmonLogger.addLog('subtitle', 'decode failed: ' + error.code + ':' + error.message, true)
    }
  }

  static formatFileSize(bytes: number) {
    if (bytes >= GB) {
      return (bytes / GB).toFixed(2) + ' GB';
    } else if (bytes >= MB) {
      return (bytes / MB).toFixed(2) + ' MB';
    } else {
      return (bytes / KB).toFixed(2) + ' KB';
    }
  }

  static getDeleteDialogMessage(isPermanentDelete: boolean, isMoveToRecent: boolean) {
    if (isPermanentDelete) {
      return $r('app.string.hard_del_confirm')
    } else if (isMoveToRecent) {
      return $r('app.string.recent_del_confirm')
    } else {
      return $r('app.string.soft_del_confirm')
    }
  }

  static decodeJwsObj(data: string): string {
    const jws: string[] = data.split('.')
    let result: string = ''
    if (jws.length < 3) {
      return result
    }
    try {
      const textDecoder = util.TextDecoder.create('utf-8', { ignoreBOM: true })
      const base64 = new util.Base64Helper()
      let payload = jws[1]
      const centerLineRegex: RegExp = new RegExp('-', 'g')
      const underLineRegex: RegExp = new RegExp('_', 'g')
      payload = payload.replace(centerLineRegex, '+').replace(underLineRegex, '/')
      const pad = payload.length % ToolsUtil.BASE64_PADDING_MOD
      if (pad) {
        if (pad === ToolsUtil.BASE64_PADDING_INVALID) {
          throw new Error('InvalidLengthError: Input base64 string is the wrong length to determine padding')
        }
        payload += new Array(ToolsUtil.BASE64_PADDING_MOD - pad + 1).join('=')
      }
      result = textDecoder.decodeToString(base64.decodeSync(payload))
    } catch (err) {
      salmonLogger.addLog(TAG, `decodeJwsObj parse err: ${JSON.stringify(err)}`, true)
    }
    return result
  }

  static getThermalLevel() {
    return thermal.getLevel()
  }

  static isNetworkUrl(uri: string | undefined): boolean {
    if (!uri) {
      return false
    }
    const trimmed = uri.trim()
    return /^(https?|rtmps?|rtsp|rtp|udp|srt|hls|smb|webdav|ftp|sweetftp):\/\//i.test(trimmed) ||
      /\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/.test(trimmed)
  }

  static fileNameFromUri(uri: string | undefined): string {
    if (!uri) {
      return ''
    }
    const raw = uri.includes('/') ? uri.substring(uri.lastIndexOf('/') + 1) : uri
    return ToolsUtil.safeDecodeURIComponent(raw)
  }

  static safeDecodeURI(uri: string | undefined): string {
    if (!uri) {
      return ''
    }
    try {
      return decodeURI(uri)
    } catch (e) {
      return uri
    }
  }

  static safeDecodeURIComponent(uri: string | undefined): string {
    if (!uri) {
      return ''
    }
    try {
      return decodeURIComponent(uri)
    } catch (e) {
      return uri
    }
  }
}
