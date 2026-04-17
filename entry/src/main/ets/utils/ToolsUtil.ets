import { vibrator } from '@kit.SensorServiceKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { bundleManager, ConfigurationConstant } from '@kit.AbilityKit'
import { pinyin4js } from '@ohos/pinyin4js'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import { FileFolder } from '../interfaces/FileFolderInterface'
import Preferences from '../database/Preferences'
import PrivacySpaceUtil from './PrivacySpaceUtil'
import { PathUtils } from './PathUtils'
import VideoInfoUtil from './VideoInfoUtil'
import NavigationAddress, { PlayerParams } from '../common/NavigationCommon'
import { BackgroundColorMode } from '../common/enum/BackgroundColorMode'
import { UniversalDetector } from '@ohos/juniversalchardet'
import { fileIo } from '@kit.CoreFileKit'
import { util } from '@kit.ArkTS'
import { salmonLogger } from 'salmonlogger'
import DataSyncUtil from './DataSyncUtil'
import { VideoItemWithPinyin } from '../interfaces/VideoItemWithPinyinInterface'
import { updateManager } from '@kit.AppGalleryKit'
import { WindowUtil } from './WindowUtil'
import { window } from '@kit.ArkUI'
import { PrivacyVideoRepository } from '../repository/PrivacyVideoRepository'
import { VideoRepository } from '../repository/VideoRepository'
import { PrivacyVideoEntity } from '../entity/PrivacyVideoEntity'
import { VideoEntity } from '../entity/VideoEntity'

const TAG = 'ToolsUtil'

// 工具类
export default class ToolsUtil {
  private static splitRegex = /(\d+)/g
  private static readonly COLLATOR = new Intl.Collator("zh-CN", {
    sensitivity: "variant",
    numeric: true,
    ignorePunctuation: false,
    caseFirst: "upper"
  })

  // Toast设置
  static showToast(text: string, duration: number = 3500) {
    try {
      window.getLastWindow(PathUtils.appContext!).then((windowClass: window.Window) => {
        windowClass.getUIContext().getPromptAction().showToast({
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

  // 震动设置
  static startVibration() {
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

  static sortByNameProcess(list: VideoMetadata[], order: 'asc' | 'desc' = 'desc') {
    if (list.length <= 1) {
      return [...list]
    }
    const itemsWithPinyin: VideoItemWithPinyin[] = list.map(item => {
      const videoItem: VideoItemWithPinyin = {
        item: item,
        pinyin: pinyin4js.getShortPinyin(item.title || "")
      }
      return videoItem
    })
    const sortedItems = [...itemsWithPinyin].sort((a, b) => {
      const result = ToolsUtil.naturalCompare(a.pinyin, b.pinyin)
      return order === 'asc' ? result : -result
    })
    return sortedItems.map(entry => entry.item)
  }

  static sortByDatetimeProcess(list: VideoMetadata[], order: 'asc' | 'desc' = 'desc') {
    return [...list].sort((a, b) => {
      const result = Number(a.date) - Number(b.date)
      return order === 'asc' ? result : -result
    })
  }

  static sortByTimeProcess(list: VideoMetadata[], order: 'asc' | 'desc' = 'desc') {
    return [...list].sort((a, b) => {
      const result = Number(a.time) - Number(b.time)
      return order === 'asc' ? result : -result
    })
  }

  // 视频排序
  // ORM 改造 + 排序逻辑重构：
  // 1. 排序方向（asc/desc）和排序类型（name/datetime/time）统一保存到 Preferences；
  // 2. 实际列表排序改为“查询时动态应用”：Repository 在 findByFolderId / findAllOrdered 时读取 Preferences，
  //    拼接 SQL ORDER BY 或在应用层二次排序；
  // 3. 对于文件夹内的即时 UI 排序，仅更新内存中的 file_folder.video_list，不立即写入数据库的 sort_order 字段，
  //    减少不必要的全表更新。
  static sortBy(context: Context, list: VideoMetadata[], file_folder: FileFolder | undefined,
    sortType: 'name' | 'datetime' | 'time') {
    const isPrivacy = PrivacySpaceUtil.getPrivacyMode()
    const currentSortType = Preferences.getVideoSortType(context, isPrivacy)
    let currentOrder = Preferences.getVideoSortOrder(context, isPrivacy)

    // 如果点击的是相同的排序类型，则反转方向；否则使用默认降序
    if (currentSortType === sortType) {
      currentOrder = currentOrder === 'asc' ? 'desc' : 'asc'
    } else {
      currentOrder = 'desc'
    }

    // 保存排序偏好到 Preferences
    Preferences.saveVideoSortType(context, sortType, isPrivacy)
    Preferences.saveVideoSortOrder(context, currentOrder, isPrivacy)

    // 对当前列表进行排序（用于即时更新 UI）
    let sorted_list: VideoMetadata[]
    switch (sortType) {
      case 'name':
        sorted_list = ToolsUtil.sortByNameProcess(list, currentOrder)
        break
      case 'datetime':
        sorted_list = ToolsUtil.sortByDatetimeProcess(list, currentOrder)
        break
      case 'time':
        sorted_list = ToolsUtil.sortByTimeProcess(list, currentOrder)
        break
      default:
        sorted_list = ToolsUtil.sortByNameProcess(list, currentOrder)
    }

    // 更新内存中的列表（文件夹模式直接赋值；隐私空间/首页模式依赖查询时动态排序）
    if (file_folder) {
      file_folder.video_list = sorted_list
    } else {
      // 隐私空间/首页：排序偏好已保存，下次 loadPrivacyVideos / getAllFolderAsync 会自动按新偏好排序
      if (isPrivacy) {
        ToolsUtil.updatePrivacyVideoSortOrder(sorted_list).catch((error: Error) => {
          salmonLogger.addLog(TAG, '更新隐私空间视频排序失败: ' + error.message, true)
        })
      } else {
        ToolsUtil.updateVideoSortOrder(sorted_list).catch((error: Error) => {
          salmonLogger.addLog(TAG, '更新首页视频排序失败: ' + error.message, true)
        })
      }
    }
  }

  // 隐私空间排序占位（如需持久化具体顺序，可在此更新每个视频的 sortOrder 字段）
  private static async updatePrivacyVideoSortOrder(sortedList: VideoMetadata[]): Promise<void> {
    salmonLogger.addLog(TAG, `隐私空间视频排序已更新，共 ${sortedList.length} 个视频`, false)
  }

  // 首页排序占位（如需持久化具体顺序，可在此更新每个视频的 sortOrder 字段）
  private static async updateVideoSortOrder(sortedList: VideoMetadata[]): Promise<void> {
    salmonLogger.addLog(TAG, `首页视频排序已更新，共 ${sortedList.length} 个视频`, false)
  }

  // 保存密码
  static savePwd(context: Context, passwd: string) {
    Preferences.savePassword(context, passwd)
    ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.set_passwd_tip').id))
  }

  // 点击视频跳转到播放器
  static async routerWhere(pathStack: NavPathStack, uri: string, item: VideoMetadata, list: VideoMetadata[]) {
    if (uri === NavigationAddress.AV_PLAYER) {
      DataSyncUtil.lastPlayVideoIndex = list.findIndex(i => i.date === item?.date)
    }
    // 没有长宽的视频/音频系统播放器播不了
    if (VideoInfoUtil.videoWidthAndHeightFormat(String(item?.size)) === '0 x 0') {
      ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.video_error').id))
      uri = NavigationAddress.MPV_PLAYER
    }
    WindowUtil.setBarColor('#FFFFFF')
    const playerParams = new PlayerParams(item, list, undefined)
    pathStack.pushPathByName(uri, playerParams, true)
  }

  // 获取版本号
  static async getVersionName() {
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
    updateManager.checkAppUpdate(PathUtils.appContext)
      .then((checkResult: updateManager.CheckUpdateResult) => {
        hilog.info(0, 'TAG', "Succeeded in checking Result updateAvailable:" + checkResult.updateAvailable)
        if (checkResult.updateAvailable == updateManager.UpdateAvailableCode.LATER_VERSION_EXIST) {
          updateManager.showUpdateDialog(PathUtils.appContext)
            .then((resultCode: updateManager.ShowUpdateResultCode) => {
              salmonLogger.addLog(TAG, 'showUpdateDialog resultCode:' + resultCode)
            })
            ?.catch((error: BusinessError) => {
              ToolsUtil.showToast('更新弹窗生成失败，原因是：' + error)
              salmonLogger.addLog(TAG, `showUpdateDialog onError.code is ${error.code}, message is ${error.message}`)
            })
        } else {
          ToolsUtil.showToast('还没有新版本~')
        }
      })?.catch((error: BusinessError) => {
        ToolsUtil.showToast('检查更新失败，原因是：' + error)
        salmonLogger.addLog(TAG, `checkAppUpdate onError.code is ${error.code}, message is ${error.message}`, true)
      })
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

  static addLogger(text: string, isError: boolean, pathStack?: NavPathStack, className?: string) {
    const title = pathStack?.getAllPathName()[0] ?? className ?? 'sweet_video'
    salmonLogger.addLog(title, text, isError)
  }

  static async detectFileDecoder(filePath: string) {
    try {
      const encoding = await UniversalDetector.detectCharset(filePath)
      return encoding
    } catch (error) {
      salmonLogger.addLog(TAG, 'File encoding detection failed: ' + error, true)
      return ''
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