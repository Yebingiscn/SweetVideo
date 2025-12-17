import promptAction from '@ohos.promptAction';
import { vibrator } from '@kit.SensorServiceKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { bundleManager, ConfigurationConstant } from '@kit.AbilityKit';
import { pinyin4js } from '@ohos/pinyin4js';
import { VideoMetadata } from '../interfaces/VideoMetadataInterface';
import { FileFolder } from '../interfaces/FileFolderInterface';
import Preferences from '../database/Preferences';
import PrivacySpaceUtil from './PrivacySpaceUtil';
import FileFolderUtil from './FileFolderUtil';
import { PathUtils } from './PathUtils';
import VideoInfoUtil from './VideoInfoUtil';
import NavigationAddress, { PlayerParams } from '../common/NavigationCommon';
import { media } from '@kit.MediaKit';
import { updateManager } from '@kit.StoreKit';
import { BackgroundColorMode } from '../common/enum/BackgroundColorMode';
import { UniversalDetector } from '@ohos/juniversalchardet';
import { fileIo } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { salmonLogger } from 'salmonlogger';

// 工具类
export default class ToolsUtil {
  private static splitRegex = /(\d+)/g;
  private static pinyinCache = new WeakMap<VideoMetadata, string>();

  // Toast设置
  static showToast(text: string) {
    try {
      promptAction.showToast({
        message: text,
        duration: 3500,
        backgroundBlurStyle: BlurStyle.Regular,
      });
    } catch (error) {
      console.error('show toast error：' + error)
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
          console.error(`Failed to start vibration. Code: ${error.code}, message: ${error.message}`);
        }
      })
    }
  }

  static getStringResource(resource: number) {
    try {
      return PathUtils.appContext!.resourceManager.getStringSync(resource)
    } catch (error) {
      console.error('get String Resource error' + error)
      return '未知'
    }
  }

  static errorCatchExec(name: string, error?: string) {
    console.error(`sweet_video error log name: ${name}: error: ${error}`)
    ToolsUtil.showToast(`流心出错了，方法名：${name} 内容：${error}`)
  }

  // 名称排序处理，如果单纯使用普通排序逻辑会造成卡顿，这里结合华为提供的排序进行排序
  static sortByNameProcess(list: VideoMetadata[]) {
    const collator = new Intl.Collator("zh-CN", {
      sensitivity: "variant",
      numeric: true,
      ignorePunctuation: false,
      caseFirst: "upper"
    });
    const naturalCompare = (a: string, b: string) => {
      // 使用新正则拆分数字部分
      const aParts = a.split(ToolsUtil.splitRegex).filter(Boolean);
      const bParts = b.split(ToolsUtil.splitRegex).filter(Boolean);
      for (let i = 0; i < Math.min(aParts.length, bParts.length); i++) {
        const aVal = aParts[i];
        const bVal = bParts[i];
        // 判断当前部分是否为数字
        const aIsNum = /^\d+$/.test(aVal);
        const bIsNum = /^\d+$/.test(bVal);
        if (aIsNum && bIsNum) {
          // 数字部分按数值比较
          const numA = parseInt(aVal, 10);
          const numB = parseInt(bVal, 10);
          if (numA !== numB) {
            return numA - numB;
          }
        } else {
          // 非数字部分按文本比较
          const cmp = collator.compare(aVal, bVal);
          if (cmp !== 0) {
            return cmp;
          }
        }
      }
      return aParts.length - bParts.length;
    };
    const sortedList = [...list].sort((a, b): number => { // 实现一个排序缓存
      const getCachedPinyin = (item: VideoMetadata) => {
        if (!ToolsUtil.pinyinCache.has(item)) {
          ToolsUtil.pinyinCache.set(item, pinyin4js.getShortPinyin(item.title || ""));
        }
        return ToolsUtil.pinyinCache.get(item)!;
      };
      return naturalCompare(getCachedPinyin(a), getCachedPinyin(b));
    });
    return sortedList;
  }

  static sortByDatetimeProcess(list: VideoMetadata[]) {
    return [...list].sort((a, b) => Number(b.date) - Number(a.date)
    );
  }

  static sortByTimeProcess(list: VideoMetadata[]) {
    return [...list].sort((a, b) => Number(b.time) - Number(a.time)
    );
  }

  static sortBy(context: Context, list: VideoMetadata[], file_folder: FileFolder | undefined,
    sortType: 'name' | 'datetime' | 'time') {
    let sorted_list: VideoMetadata[]
    switch (sortType) {
      case 'name':
        sorted_list = ToolsUtil.sortByNameProcess(list)
        break
      case 'datetime':
        sorted_list = ToolsUtil.sortByDatetimeProcess(list)
        break;
      case 'time':
        sorted_list = ToolsUtil.sortByTimeProcess(list)
        break;
      default:
        sorted_list = ToolsUtil.sortByNameProcess(list)
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
    // 没有长宽的视频/音频系统播放器播不了
    if (VideoInfoUtil.videoWidthAndHeightFormat(String(item?.size)) === '0 x 0') {
      ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.video_error').id))
      uri = NavigationAddress.FFMPEG_PLAYER
    }
    // 红薯播放器不允许播放 HDR VIVID 视频，否则可能会导致卡屏
    if (uri === NavigationAddress.RED_PLAYER && item.hdr_type === media.HdrType.AV_HDR_TYPE_VIVID) {
      ToolsUtil.showToast('该播放器不支持 HDR VIVID，已智能切换到合适播放器')
      uri = NavigationAddress.AV_PLAYER
    }
    const playerParams = new PlayerParams(item, list, undefined)
    pathStack.pushPathByName(uri, playerParams, true)
  }

  // 获取版本号
  static async getVersionName() {
    try {
      if (canIUse("SystemCapability.BundleManager.BundleFramework.Core")) {
        const bundleInfo =
          await bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
        return bundleInfo.versionName + '(' + bundleInfo.versionCode + ')';
      } else {
        return '未知版本'
      }
    } catch (error) {
      hilog.error(777, 'testFlag', "get bundleInfo failed, error is " + error)
      return '未知版本'
    }
  }

  static checkUpdate() {
    updateManager.checkAppUpdate(PathUtils.appContext)
      .then((checkResult: updateManager.CheckUpdateResult) => {
        hilog.info(0, 'TAG', "Succeeded in checking Result updateAvailable:" + checkResult.updateAvailable);
        if (checkResult.updateAvailable == updateManager.UpdateAvailableCode.LATER_VERSION_EXIST) {
          updateManager.showUpdateDialog(PathUtils.appContext)
            .then((resultCode: updateManager.ShowUpdateResultCode) => {
              hilog.info(0, 'TAG', "Succeeded in showing UpdateDialog resultCode:" + resultCode);
            })
            .catch((error: BusinessError) => {
              ToolsUtil.showToast('更新弹窗生成失败，原因是：' + error)
              hilog.error(0, 'TAG', `showUpdateDialog onError.code is ${error.code}, message is ${error.message}`);
            });
        } else {
          ToolsUtil.showToast('还没有新版本~')
        }
      }).catch((error: BusinessError) => {
      ToolsUtil.showToast('检查更新失败，原因是：' + error)
      hilog.error(0, 'TAG', `checkAppUpdate onError.code is ${error.code}, message is ${error.message}`);
    });
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
      console.error('set color mode errro: ' + error)
    }
  }

  static addLogger(text: string, isError: boolean, pathStack?: NavPathStack, className?: string) {
    const title = pathStack?.getAllPathName()[0] ?? className ?? 'sweet_video';
    salmonLogger.addLog(title, text, isError)
  }

  static async detectFileDecoder(filePath: string) {
    try {
      const encoding = await UniversalDetector.detectCharset(filePath);
      return encoding
    } catch (error) {
      console.error('File encoding detection failed:', JSON.stringify(error));
      return '';
    }
  }

  static transFileDecodeAsUTF8(filePath: string, decode: string) {
    try {
      const readStream = fileIo.createStreamSync(filePath, "r+");
      const stat = fileIo.statSync(filePath);
      const buffer = new ArrayBuffer(stat.size);
      readStream.readSync(buffer);
      let textDecoder = util.TextDecoder.create(decode, { ignoreBOM: true });
      let text = textDecoder.decodeToString(new Uint8Array(buffer), { stream: false });
      readStream.close().catch(() => {
        throw new Error(`文件解码转换失败: ${'未知错误'}`);
      });
      const writeStream = fileIo.createStreamSync(filePath, "w+");
      writeStream.writeSync(text, { encoding: 'utf-8' });
      writeStream.close().catch(() => {
        throw new Error(`文件解码转换失败: ${'未知错误'}`);
      });
    } catch (error) {
      console.error("操作失败: " + JSON.stringify(error));
      salmonLogger.addLog('subtitle', 'decode failed: ' + error.code + ':' + error.message, true)
      throw new Error(`文件解码转换失败: ${error.message || '未知错误'}`);
    }
  }
}