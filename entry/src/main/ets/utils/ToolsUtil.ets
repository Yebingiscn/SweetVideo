import promptAction from '@ohos.promptAction';
import { vibrator } from '@kit.SensorServiceKit';
import { BusinessError, systemDateTime } from '@kit.BasicServicesKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { bundleManager } from '@kit.AbilityKit';
import { pinyin4js } from '@ohos/pinyin4js';
import PermissionUtil from './PermissionUtil';
import { PlayerParams } from '../common/PlayerParams';
import { VideoMetadata } from '../interfaces/VideoMetadataInterface';
import { FileFolder } from '../interfaces/FileFolderInterface';
import Preferences from '../database/Preferences';
import PrivacySpaceUtil from './PrivacySpaceUtil';
import FileFolderUtil from './FileFolderUtil';
import { PathUtils } from './PathUtils';
import VideoInfoUtil from './VideoInfoUtil';

// 工具类
export class ToolsUtil {
  private splitRegex = /(\d+\.?\d*)/; // 分离数字和文字，排序使用
  private pinyinCache = new WeakMap<VideoMetadata, string>(); // 缓存排序列表

  // Toast设置
  showToast(text: string) {
    promptAction.showToast({
      message: text,
      duration: 3500,
      backgroundBlurStyle: BlurStyle.COMPONENT_ULTRA_THICK,
    });
  }

  // 震动设置
  startVibration() {
    vibrator.startVibration({
      type: 'preset',
      effectId: 'haptic.effect.soft',
      count: 1,
      intensity: 100,
    }, {
      usage: 'unknown'
    }, (error: BusinessError) => {
      if (error) {
        console.error(`Failed to start vibration. Code: ${error.code}, message: ${error.message}`);
      }
    })
  }

  // 名称排序处理，如果单纯使用普通排序逻辑会造成卡顿，这里结合华为提供的排序进行排序
  sortByNameProcess(list: VideoMetadata[]) {
    const collator = new Intl.Collator("zh-CN", {
      sensitivity: "variant",
      numeric: true,
      ignorePunctuation: false,
      caseFirst: "upper"
    });
    const naturalCompare = (a: string, b: string) => { // 自然排序逻辑
      const aParts = a.split(this.splitRegex);
      const bParts = b.split(this.splitRegex);
      for (let i = 0; i < Math.min(aParts.length, bParts.length); i++) {
        const aVal = aParts[i], bVal = bParts[i];
        if (i % 2 === 0) { // 文本部分
          const cmp = collator.compare(aVal, bVal);
          if (cmp !== 0) {
            return cmp;
          }
        } else { // 数字部分
          const numA = parseFloat(aVal);
          const numB = parseFloat(bVal);
          if (numA !== numB) {
            return numA - numB;
          }
        }
      }
      return aParts.length - bParts.length;
    };
    const sortedList = [...list].sort((a, b): number => { // 实现一个排序缓存
      const getCachedPinyin = (item: VideoMetadata) => {
        if (!this.pinyinCache.has(item)) {
          this.pinyinCache.set(item, pinyin4js.getShortPinyin(item.title || ""));
        }
        return this.pinyinCache.get(item)!;
      };
      return naturalCompare(getCachedPinyin(a), getCachedPinyin(b));
    });
    return sortedList;
  }

  sortByTimeProcess(list: VideoMetadata[]) {
    return [...list].sort((a, b) => Number(b.date) - Number(a.date)
    );
  }

  // 名称排序
  async sortByName(context: Context, list: VideoMetadata[], file_folder: FileFolder | undefined) {
    const sorted_list = this.sortByNameProcess(list)
    if (file_folder) {
      FileFolderUtil.updateFileFolder(context, file_folder, sorted_list)
    } else {
      PrivacySpaceUtil.getPrivacyMode() ? Preferences.saveVideoMetaDataEncryption(context, sorted_list)
        : Preferences.saveVideoMetaData(context, sorted_list);
    }
  }

  //时间排序，从近到久
  async sortByTime(context: Context, list: VideoMetadata[], file_folder: FileFolder | undefined) {
    const sorted_list = this.sortByTimeProcess(list)
    if (file_folder) {
      FileFolderUtil.updateFileFolder(context, file_folder, sorted_list)
    } else {
      PrivacySpaceUtil.getPrivacyMode() ? Preferences.saveVideoMetaDataEncryption(context, sorted_list)
        : Preferences.saveVideoMetaData(context, sorted_list)
    }
  }

  // 保存密码
  savePwd(context: Context, passwd: string) {
    Preferences.savePassword(context, passwd)
    this.showToast(PathUtils.appContext!.resourceManager.getStringSync($r('app.string.set_passwd_tip')))
  }

  // 检查文件是否存在
  async isFileExist(item: VideoMetadata | undefined) {
    await PermissionUtil.activatePermission(item?.uri!)
    try {
      fs.openSync(String(item?.uri))
      return true
    } catch (e) {
      hilog.error(777, 'testFlag', 'file error' + e)
      this.showToast(String(item?.title) +
      PathUtils.appContext!.resourceManager.getStringSync($r('app.string.re_import_info')))
      return false
    }
  }

  // 点击视频跳转到播放器
  async routerWhere(pathStack: NavPathStack, uri: string, item: VideoMetadata, list: VideoMetadata[]) {
    // 没有长宽的视频/音频系统播放器播不了
    if (VideoInfoUtil.videoWidthAndHeightFormat(String(item?.size)) === '0 x 0') {
      this.showToast(PathUtils.appContext!.resourceManager.getStringSync($r('app.string.video_error')))
      uri = 'FFMpegPlayer'
    }
    const playerParams = new PlayerParams(item, list, undefined)
    pathStack.pushPathByName(uri, playerParams, true)
  }

  // 获取版本号
  async getVersionCode() {
    try {
      const bundleInfo =
        await bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
      return bundleInfo.versionName;
    } catch (error) {
      hilog.error(777, 'testFlag', "get bundleInfo failed, error is " + error)
      return ''
    }
  }

  // 检查字幕文件夹是否存在
  isSubtitleFileFolderExist(sandbox_video: string, sandbox_subtitle: string) {
    if (!fs.accessSync(sandbox_video)) {
      fs.mkdirSync(sandbox_video)
    }
    if (!fs.accessSync(sandbox_subtitle)) {
      fs.mkdirSync(sandbox_subtitle)
    }
  }

  // 获取当前时间
  getTime() {
    let timestamp = systemDateTime.getTime(false)
    const date = new Date(timestamp);
    const hours = date.getHours().toString().padStart(2, '0');
    const minutes = date.getMinutes().toString().padStart(2, '0');
    const timeString = `${hours}:${minutes}`;
    return timeString
  }
}

export default new ToolsUtil()