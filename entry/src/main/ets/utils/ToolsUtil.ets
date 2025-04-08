import promptAction from '@ohos.promptAction';
import { vibrator } from '@kit.SensorServiceKit';
import { BusinessError, systemDateTime } from '@kit.BasicServicesKit';
import VideoInfoUtil, { VideoMetadata } from './VideoInfoUtil';
import { fileIo as fs } from '@kit.CoreFileKit';
import PreferencesUtil from './PreferencesUtil';
import { router } from '@kit.ArkUI';
import { JSON } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { bundleManager } from '@kit.AbilityKit';
import RecentPlayUtil from './RecentPlayUtil';
import SelectFileUtil from './SelectFileUtil';
import { pinyin4js } from '@ohos/pinyin4js';
import { FileFolder } from './FileFolderUtil';
import PermissionUtil from './PermissionUtil';


class ToolsUtil {
  private splitRegex = /(\d+\.?\d*)/; // 分离数字和文字
  private pinyinCache = new WeakMap<VideoMetadata, string>();

  showToast(text: string) {
    promptAction.showToast({
      message: text,
      duration: 3500,
      backgroundBlurStyle: BlurStyle.COMPONENT_ULTRA_THICK,
    });
  }

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
    const sortedList = [...list].sort((a, b): number => { // 缓存读取逻辑
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

  async sortByName(context: Context, list: VideoMetadata[], encryption: boolean) {
    const sorted_list = this.sortByNameProcess(list)
    await (encryption ? SelectFileUtil.saveVideoMetaDataEncryption(context, sorted_list)
      : SelectFileUtil.saveVideoMetaData(context, sorted_list));
    return sorted_list // 返回处理后的数据
  }

  async sortByTime(context: Context, list: VideoMetadata[], encryption: boolean) {
    const sortedList = [...list].sort((a, b) => b.date.localeCompare(a.date));
    await (encryption ? SelectFileUtil.saveVideoMetaDataEncryption(context, sortedList)
      : SelectFileUtil.saveVideoMetaData(context, sortedList));
    const latestData = encryption ? await SelectFileUtil.getVideoMetaDataEncryption(context)
      : await SelectFileUtil.getVideoMetaData(context);
    return latestData
  }

  savePwd(context: Context, passwd: string) {
    PreferencesUtil.putPreferencesValue(context, 'sweet_video', 'passwd', passwd)
    this.showToast(getContext().resourceManager.getStringSync($r('app.string.set_passwd_tip')))
  }

  calculateDelta(offset: number, stepSize: number, stepValue: number, directionSign: number) {
    const steps = Math.floor(Math.abs(offset) / stepSize);
    return steps > 0 ? steps * stepValue * directionSign : 0;
  }

  isFileExist(item: VideoMetadata | undefined) {
    PermissionUtil.activatePermission(item?.uri!)
    try {
      fs.openSync(String(item?.uri))
      return true
    } catch (e) {
      hilog.error(777, 'testFlag', 'file error' + e)
      this.showToast(String(item?.title) + getContext().resourceManager.getStringSync($r('app.string.re_import_info')))
      return false
    }
  }

  routerWhereOnlyUri(uri: string) {
    router.pushUrl({
      url: uri,
    }, router.RouterMode.Single, (err) => {
      hilog.info(0xFF00, "testTag", String(err));
    });
  }

  async routerToFileFolder(file_folder: FileFolder) {
    router.pushUrl({
      url: 'pages/FileFolderContent',
      params: {
        file_folder: JSON.stringify(file_folder)
      }
    }, router.RouterMode.Single, (err) => {
      hilog.info(0xFF00, "testTag", String(err));
    });
  }

  async routerToVideoFromFileFolder(context: Context, uri: string, item: VideoMetadata,
    video_meta_data: VideoMetadata[]) {
    PermissionUtil.activatePermission(item?.uri!)
    if (VideoInfoUtil.videoWidthAndHeightFormat(String(item?.size)) === '0 x 0') {
      this.showToast(getContext().resourceManager.getStringSync($r('app.string.video_error')))
      uri = 'pages/FFMpegPlayer'
    }
    const recentPlay = await PreferencesUtil.getPreferencesValue(context, "sweet_video", "recentPlay", true) as boolean
    if (recentPlay) {
      RecentPlayUtil.addPlayback(context, item)
    }
    router.pushUrl({
      url: uri,
      params: {
        metadata: JSON.stringify(item),
        metadata_list: JSON.stringify(video_meta_data)
      }
    }, router.RouterMode.Single, (err) => {
      hilog.info(0xFF00, "testTag", String(err));
    });
  }

  async routerWhere(context: Context, uri: string, item: string, encryption: boolean) {
    PermissionUtil.activatePermission(item)
    let list: VideoMetadata [] = []
    encryption ? list = await SelectFileUtil.getVideoMetaDataEncryption(context) :
      list = await SelectFileUtil.getVideoMetaData(context)
    const recentPlay = await PreferencesUtil.getPreferencesValue(context, "sweet_video", "recentPlay", true) as boolean
    if (!encryption && recentPlay) {
      RecentPlayUtil.addPlayback(context, list.find(i => i.date === item)!)
    }
    let target_item = SelectFileUtil.getItem(list, item!)
    if (VideoInfoUtil.videoWidthAndHeightFormat(String(target_item?.size)) === '0 x 0') {
      this.showToast(getContext().resourceManager.getStringSync($r('app.string.video_error')))
      uri = 'pages/FFMpegPlayer'
    }
    router.pushUrl({
      url: uri,
      params: {
        metadata: JSON.stringify(list.find(i => i.date === item)),
        metadata_list: JSON.stringify(list)
      }
    }, router.RouterMode.Single, (err) => {
      hilog.info(0xFF00, "testTag", String(err));
    });
  }

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

  isFileFolderExist(sandbox_video: string, sandbox_subtitle: string) {
    if (!fs.accessSync(sandbox_video)) {
      fs.mkdirSync(sandbox_video)
    }
    if (!fs.accessSync(sandbox_subtitle)) {
      fs.mkdirSync(sandbox_subtitle)
    }
  }

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