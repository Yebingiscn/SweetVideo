import { bundleManager, ConfigurationConstant } from '@kit.AbilityKit'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import { FileFolder } from '../interfaces/FileFolderInterface'
import { PathUtils } from './PathUtils'
import { SortField } from '../common/enum/SortField'
import { salmonLogger } from 'salmonlogger'
import { GB, KB, MB } from '../common/Constants'
import { PromptAction, window } from '@kit.ArkUI'
import { pinyin4js } from '@ohos/pinyin4js'
import { BackgroundColorMode } from '../common/enum/BackgroundColorMode'
import NavigationAddress, { PlayerParams, ShortVideoParams } from '../common/NavigationCommon'
import Preferences from '../database/Preferences'
import { ItemWithPinyin } from '../interfaces/VideoItemWithPinyinInterface'
import DataSyncUtil from './DataSyncUtil'
import FileFolderUtil from './FileFolderUtil'
import { Setting } from './ObservedUtil'
import PrivacySpaceUtil from './PrivacySpaceUtil'
import { FolderNameSortItem, sortFolderNamesInTaskPool } from './TaskpoolUtil'
import VideoOperateUtil from './VideoOperateUtil'
import { WindowUtil } from './WindowUtil'
import { updateManager } from '@kit.AppGalleryKit'
import { util } from '@kit.ArkTS'
import { fileIo } from '@kit.CoreFileKit'
import { vibrator } from '@kit.SensorServiceKit'
import { thermal } from '@kit.BasicServicesKit'


const TAG = 'ToolsUtil'

// 工具类
export default class ToolsUtil {
  static BASE64_PADDING_MOD: number = 4;
  static BASE64_PADDING_INVALID: number = 1;
  private static splitRegex = /(\d+)/g
  private static readonly COLLATOR = new Intl.Collator("zh-CN", {
    sensitivity: "variant",
    numeric: true,
    ignorePunctuation: false,
    caseFirst: "upper"
  })
  private static cachedPromptAction: PromptAction | null = null
  // 震动设置
  private static vibrationEnabled: boolean = true

  static showToast(text: string, duration: number = 3500) {
    try {
      if (ToolsUtil.cachedPromptAction) {
        ToolsUtil.cachedPromptAction.showToast({
          message: text,
          duration: duration,
          backgroundBlurStyle: BlurStyle.Regular,
          alignment: Alignment.Bottom,
          offset: { dx: 0, dy: -100 }
        })
        return
      }
      window.getLastWindow(PathUtils.appContext!).then((windowClass: window.Window) => {
        ToolsUtil.cachedPromptAction = windowClass.getUIContext().getPromptAction()
        ToolsUtil.cachedPromptAction.showToast({
          message: text,
          duration: duration,
          backgroundBlurStyle: BlurStyle.Regular,
          alignment: Alignment.Bottom,
          offset: { dx: 0, dy: -100 }
        })
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
    if (!ToolsUtil.vibrationEnabled) {
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
        }
      })
    }
  }

  static getStringResource(resource: number) {
    try {
      return PathUtils.appContext!.resourceManager.getStringSync(resource)
    } catch (error) {
      salmonLogger.addLog(TAG, 'get String Resource error' + error, true)
      return '未知'
    }
  }

  static sortByNameProcess(list: VideoMetadata[], ascending: boolean = true, pinyinSort: boolean = true) {
    return ToolsUtil.sortByName(list, item => item.title || '', ascending, pinyinSort)
  }

  static sortFolderByNameProcess(list: FileFolder[], ascending: boolean = true, pinyinSort: boolean = true) {
    return ToolsUtil.sortByName(list, item => item.name || '', ascending, pinyinSort)
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
      const dates = await sortFolderNamesInTaskPool(items, ascending, pinyinSort)
      const foldersByDate = new Map<string, FileFolder>()
      list.forEach(folder => foldersByDate.set(folder.date, folder))
      const sortedFolders: FileFolder[] = []
      dates.forEach(date => {
        const folder = foldersByDate.get(date)
        if (folder) {
          sortedFolders.push(folder)
        }
      })
      return sortedFolders
    } catch (error) {
      salmonLogger.addLog(TAG, `folder name sort task failed: ${error}`, true)
      // 任务失败时保留当前顺序，绝不退回 UI 线程的同步拼音排序。
      return [...list]
    }
  }

  static sortByNumericProperty(list: VideoMetadata[], key: 'date' | 'time', ascending: boolean = false) {
    return [...list].sort((a, b) => {
      let aVal: number
      let bVal: number
      if (key === 'date') {
        aVal = Number(a.date)
        bVal = Number(b.date)
      } else {
        aVal = Number(a.time)
        bVal = Number(b.time)
      }
      const cmp = aVal - bVal
      return ascending ? cmp : -cmp
    })
  }

  static sortByDatetimeProcess(list: VideoMetadata[], ascending: boolean = false): VideoMetadata[] {
    return ToolsUtil.sortByNumericProperty(list, 'date', ascending)
  }

  static sortByTimeProcess(list: VideoMetadata[], ascending: boolean = false): VideoMetadata[] {
    return ToolsUtil.sortByNumericProperty(list, 'time', ascending)
  }

  static sortBy(context: Context, list: VideoMetadata[], file_folder: FileFolder | undefined,
    sortType: SortField | '', ascending?: boolean, pinyinSort?: boolean): VideoMetadata[] {
    let sorted_list: VideoMetadata[]
    switch (sortType) {
      case SortField.NAME:
        sorted_list = ToolsUtil.sortByNameProcess(list, ascending, pinyinSort)
        break
      case SortField.DATETIME:
        sorted_list = ToolsUtil.sortByDatetimeProcess(list, ascending)
        break
      case SortField.TIME:
        sorted_list = ToolsUtil.sortByTimeProcess(list, ascending)
        break
      default:
        sorted_list = ToolsUtil.sortByNameProcess(list, ascending)
    }
    const isSameOrder = list.length === sorted_list.length &&
      list.every((item, i) => item.date === sorted_list[i].date)
    if (isSameOrder) {
      return sorted_list
    }
    if (file_folder) {
      FileFolderUtil.updateFileFolder(context, file_folder, sorted_list)
    } else {
      if (PrivacySpaceUtil.getPrivacyMode()) {
        Preferences.saveVideoMetaDataEncryption(context, sorted_list)
      } else {
        Preferences.saveVideoMetaData(context, sorted_list)
      }
    }
    return sorted_list
  }

  static getFirstLetter(title: string): string {
    if (!title || title.length === 0) {
      return '#'
    }
    const pinyin = pinyin4js.getShortPinyin(title) as string
    if (pinyin.length === 0) {
      return '#'
    }
    const first = pinyin[0].toUpperCase()
    if (first >= 'A' && first <= 'Z') {
      return first
    }
    return '#'
  }

  // 保存密码
  static savePwd(context: Context, passwd: string) {
    Preferences.savePassword(context, passwd)
    ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.set_passwd_tip').id))
  }

  // 点击视频跳转到播放器
  static async routerWhere(pathStack: NavPathStack, item: VideoMetadata, list: VideoMetadata[],
    reverse: boolean = false, skipHistory: boolean = false): Promise<void> {
    const uri = VideoOperateUtil.resolvePlayerType(item, reverse)
    DataSyncUtil.lastPlayVideoIndex = list.findIndex(i => i.date === item?.date)
    WindowUtil.setBarColor('#FFFFFF')
    const findResult = Preferences.findVideoByDate(PathUtils.appContext!, item.date)
    const latestItem = findResult[0] ?? item
    const folder_date = findResult[2]
    if (Setting.shortVideoMode && !reverse) {
      const latestList = list.map(video => video.date === latestItem.date ? latestItem : video)
      const initialIndex = Math.max(0, latestList.findIndex(video => video.date === latestItem.date))
      pathStack.pushPathByName(NavigationAddress.SHORT_VIDEO,
        new ShortVideoParams(latestList, initialIndex, skipHistory), true)
      return
    }
    const metadata_list = folder_date ? undefined : list
    const playerParams = new PlayerParams(latestItem, metadata_list, undefined, skipHistory, uri, folder_date)
    pathStack.pushPathByName(NavigationAddress.VIDEO_PLAYER, playerParams, true)
  }

  // 以短视频模式播放：忽略 shortVideoMode 开关，直接跳转短视频页面
  static async routerToShortVideo(pathStack: NavPathStack, item: VideoMetadata, list: VideoMetadata[],
    skipHistory: boolean = false) {
    const findResult = Preferences.findVideoByDate(PathUtils.appContext!, item.date)
    const latestItem = findResult[0] ?? item
    const latestList = list.map(video => video.date === latestItem.date ? latestItem : video)
    const initialIndex = Math.max(0, latestList.findIndex(video => video.date === latestItem.date))
    WindowUtil.setBarColor('#FFFFFF')
    pathStack.pushPathByName(NavigationAddress.SHORT_VIDEO,
      new ShortVideoParams(latestList, initialIndex, skipHistory), true)
  }

  // 获取版本号
  static async getVersionName(): Promise<string> {
    try {
      if (canIUse("SystemCapability.BundleManager.BundleFramework.Core")) {
        const bundleInfo =
          await bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION)
        return bundleInfo.versionName + '(' + bundleInfo.versionCode + ')'
      } else {
        return '未知版本'
      }
    } catch (error) {
      salmonLogger.addLog(TAG, 'get bundleInfo failed, error is ' + error, true)
      return '未知版本'
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
                ToolsUtil.showToast('更新弹窗生成失败，原因是：' + error.message)
                salmonLogger.addLog(TAG, `showUpdateDialog onError.code is ${error.code}, message is ${error.message}`)
              })
          } else {
            ToolsUtil.showToast('还没有新版本~')
          }
        }).catch((error: BusinessError) => {
        ToolsUtil.showToast('检查更新失败，原因是：' + error.message)
        salmonLogger.addLog(TAG, `checkAppUpdate onError.code is ${error.code}, message is ${error.message}`, true)
      })
    } else {
      ToolsUtil.showToast('不支持该功能')
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
      let textDecoder = util.TextDecoder.create(decode, { ignoreBOM: true })
      let text = textDecoder.decodeToString(new Uint8Array(buffer), { stream: false })
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
    return /^(https?|rtmps?|rtsp|rtp|udp|srt|hls):\/\//i.test(uri.trim())
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

  private static sortByName<T>(list: T[], nameExtractor: (item: T) => string, ascending: boolean = true,
    pinyinSort: boolean = true): T[] {
    if (list.length <= 1) {
      return [...list]
    }
    if (pinyinSort) {
      const itemsWithPinyin: ItemWithPinyin<T>[] = list.map(item => {
        const entry: ItemWithPinyin<T> = {
          item: item,
          pinyin: pinyin4js.getShortPinyin(nameExtractor(item))
        }
        return entry
      })
      const sortedItems = [...itemsWithPinyin].sort((a, b) => {
        const cmp = ToolsUtil.naturalCompare(a.pinyin, b.pinyin)
        return ascending ? cmp : -cmp
      })
      return sortedItems.map(entry => entry.item)
    } else {
      return [...list].sort((a, b) => {
        const cmp = ToolsUtil.COLLATOR.compare(nameExtractor(a), nameExtractor(b))
        return ascending ? cmp : -cmp
      })
    }
  }

  private static naturalCompare(a: string, b: string): number {
    const aParts = a.split(ToolsUtil.splitRegex).filter(Boolean)
    const bParts = b.split(ToolsUtil.splitRegex).filter(Boolean)

    for (let i = 0; i < Math.min(aParts.length, bParts.length); i++) {
      const aVal = aParts[i]
      const bVal = bParts[i]
      const aIsNum = /^\d+$/.test(aVal)
      const bIsNum = /^\d+$/.test(bVal)

      if (aIsNum && bIsNum) {
        const numA = parseInt(aVal, 10)
        const numB = parseInt(bVal, 10)
        if (numA !== numB) {
          return numA - numB
        }
      } else {
        const cmp = ToolsUtil.COLLATOR.compare(aVal, bVal)
        if (cmp !== 0) {
          return cmp
        }
      }
    }
    return aParts.length - bParts.length
  }
}
