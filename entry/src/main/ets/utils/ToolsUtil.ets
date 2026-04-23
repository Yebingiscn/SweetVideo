import { bundleManager, ConfigurationConstant } from '@kit.AbilityKit'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import { FileFolder } from '../interfaces/FileFolderInterface'
import { PathUtils } from './PathUtils'
import { UniversalDetector } from '@ohos/juniversalchardet'
import { salmonLogger } from 'salmonlogger'
import { VideoItemWithPinyin } from '../interfaces/VideoItemWithPinyinInterface'
import { GB, MB } from '../common/Constants'
import { BackgroundColorMode } from '../common/enum/BackgroundColorMode'
import NavigationAddress, { PlayerParams } from '../common/NavigationCommon'
import Preferences from '../database/Preferences'
import DataSyncUtil from './DataSyncUtil'
import FileFolderUtil from './FileFolderUtil'
import PrivacySpaceUtil from './PrivacySpaceUtil'
import VideoInfoUtil from './VideoInfoUtil'
import { WindowUtil } from './WindowUtil'
import fileIo from '@ohos.file.fs'
import { util } from '@kit.ArkTS'
import { window } from '@kit.ArkUI'
import { vibrator } from '@kit.SensorServiceKit'
import { pinyin4js } from '@ohos/pinyin4js'
import { updateManager } from '@kit.AppGalleryKit'

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

  static sortByNameProcess(list: VideoMetadata[], ascending: boolean = true) {
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
      const cmp = ToolsUtil.naturalCompare(a.pinyin, b.pinyin)
      return ascending ? cmp : -cmp
    })
    return sortedItems.map(entry => entry.item)
  }

  static sortByDatetimeProcess(list: VideoMetadata[], ascending: boolean = false) {
    return [...list].sort((a, b) => {
      const cmp = Number(a.date) - Number(b.date)
      return ascending ? cmp : -cmp
    })
  }

  static sortByTimeProcess(list: VideoMetadata[], ascending: boolean = false) {
    return [...list].sort((a, b) => {
      const cmp = Number(a.time) - Number(b.time)
      return ascending ? cmp : -cmp
    })
  }

  static sortBy(context: Context, list: VideoMetadata[], file_folder: FileFolder | undefined,
    sortType: 'name' | 'datetime' | 'time', ascending?: boolean) {
    let sorted_list: VideoMetadata[]
    switch (sortType) {
      case 'name':
        sorted_list = ToolsUtil.sortByNameProcess(list, ascending)
        break
      case 'datetime':
        sorted_list = ToolsUtil.sortByDatetimeProcess(list, ascending)
        break
      case 'time':
        sorted_list = ToolsUtil.sortByTimeProcess(list, ascending)
        break
      default:
        sorted_list = ToolsUtil.sortByNameProcess(list, ascending)
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

  static formatFileSize(bytes: number) {
    if (bytes >= GB) {
      return (bytes / GB).toFixed(2) + ' GB';
    } else {
      return (bytes / MB).toFixed(2) + ' MB';
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