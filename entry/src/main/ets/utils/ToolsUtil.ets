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
import NavigationAddress from '../common/NavigationAddress';
import { media } from '@kit.MediaKit';

// 工具类
export class ToolsUtil {
  private splitRegex = /(\d+)/g; // 只匹配连续数字
  private pinyinCache = new WeakMap<VideoMetadata, string>(); // 缓存排序列表

  // Toast设置
  showToast(text: string) {
    try {
      promptAction.showToast({
        message: text,
        duration: 3500,
        backgroundBlurStyle: BlurStyle.COMPONENT_ULTRA_THICK,
      });
    } catch (error) {
      console.error('show toast error：' + error)
    }
  }

  // 震动设置
  startVibration() {
    if (canIUse("SystemCapability.Sensors.MiscDevice")) {
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
    } else {
      console.log('device unsupport vibration')
    }
  }

  getStringResource(resource: number) {
    try {
      return PathUtils.appContext!.resourceManager.getStringSync(resource)
    } catch (error) {
      console.error('get String Resource error' + error)
      return '未知'
    }
  }

  errorCatchExec(name: string, error?: string) {
    console.error(`sweet_video error log name: ${name}: error: ${error}`)
    this.showToast(`流心出错了，方法名：${name} 内容：${error}`)
  }

  // 名称排序处理，如果单纯使用普通排序逻辑会造成卡顿，这里结合华为提供的排序进行排序
  sortByNameProcess(list: VideoMetadata[]) {
    const collator = new Intl.Collator("zh-CN", {
      sensitivity: "variant",
      numeric: true,
      ignorePunctuation: false,
      caseFirst: "upper"
    });
    const naturalCompare = (a: string, b: string) => {
      // 使用新正则拆分数字部分
      const aParts = a.split(this.splitRegex).filter(Boolean);
      const bParts = b.split(this.splitRegex).filter(Boolean);
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
    this.showToast(this.getStringResource($r('app.string.set_passwd_tip').id))
  }

  // 检查文件是否存在
  async isFileExist(uri: string) {
    await PermissionUtil.activatePermission(uri)
    try {
      await fs.open(String(uri))
      return true
    } catch (e) {
      console.log('file error' + e)
      return false
    }
  }

  // 点击视频跳转到播放器
  async routerWhere(pathStack: NavPathStack, uri: string, item: VideoMetadata, list: VideoMetadata[]) {
    // 没有长宽的视频/音频系统播放器播不了
    if (VideoInfoUtil.videoWidthAndHeightFormat(String(item?.size)) === '0 x 0') {
      this.showToast(this.getStringResource($r('app.string.video_error').id))
      uri = NavigationAddress.FFMPEG_PLAYER
    }
    // 红薯播放器不允许播放 HDR VIVID 视频，否则可能会导致卡屏
    if (uri === NavigationAddress.RED_PLAYER && item.hdr_type === media.HdrType.AV_HDR_TYPE_VIVID) {
      this.showToast('该播放器不支持 HDR VIVID，已智能切换到合适播放器')
      uri = NavigationAddress.AV_PLAYER
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

  // 检查文件夹是否存在
  fileFolderExistCheck() {
    const paths = [
      PathUtils.videoPath,
      PathUtils.subtitlePath,
      PathUtils.photoPath
    ];

    paths.forEach(path => {
      try {
        if (!fs.accessSync(path)) {
          fs.mkdirSync(path);
        }
      } catch (error) {
        console.error(`Failed to create directory ${path}:`, error);
      }
    });
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

  getTextByTime() {
    const now = new Date();
    const hours = now.getHours();
    if (hours === 15) {
      return '饮茶啦！流心';
    }
    // 常规时间问候
    if (hours >= 0 && hours < 5) {
      return '晚安！流心';
    } else if (hours >= 5 && hours < 12) {
      return '早上好！流心';
    } else if (hours >= 12 && hours < 14) {
      return '中午好！流心';
    } else if (hours >= 14 && hours < 18) {
      return '下午好！流心';
    } else {
      return '晚上好！流心';
    }
  }
}

export default new ToolsUtil()