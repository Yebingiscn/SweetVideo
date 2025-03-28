import promptAction from '@ohos.promptAction';
import { vibrator } from '@kit.SensorServiceKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { pinyin4js } from '@ohos/pinyin4js';
import { VideoMetadata } from './VideoInfoUtil';
import { fileIo as fs } from '@kit.CoreFileKit';
import PreferencesUtil from './PreferencesUtil';
import { router } from '@kit.ArkUI';
import { JSON } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { bundleManager } from '@kit.AbilityKit';
import RecentPlayUtil from './RecentPlayUtil';
import SelectFileUtil from './SelectFileUtil';

class ToolsUtil {
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

  async sortByName(context: Context, list: VideoMetadata[], encryption: boolean) {
    const sortedList = [...list].sort((a, b) =>
    String(pinyin4js.getShortPinyin(a.title))
      .localeCompare(String(pinyin4js.getShortPinyin(b.title)),"zh-CN", {
        numeric: true,
        sensitivity: "base"
      })
    );
    await (encryption ? SelectFileUtil.saveVideoMetaDataEncryption(context, sortedList)
      : SelectFileUtil.saveVideoMetaData(context,sortedList));
    return sortedList // 返回处理后的数据
  }

  async sortByTime(context: Context,list: VideoMetadata[], encryption: boolean) {
    const sortedList = [...list].sort((a, b) => b.date.localeCompare(a.date));
    await (encryption ? SelectFileUtil.saveVideoMetaDataEncryption(context,sortedList)
      : SelectFileUtil.saveVideoMetaData(context,sortedList));
    const latestData = encryption ? await SelectFileUtil.getVideoMetaDataEncryption(context)
      : await SelectFileUtil.getVideoMetaData(context);
    return latestData
  }

  savePwd(context: Context,passwd: string) {
    PreferencesUtil.putPreferencesValue(context,'sweet_video', 'passwd', passwd)
    this.showToast(getContext().resourceManager.getStringSync($r('app.string.set_passwd_tip')))
  }

  calculateDelta(offset: number, stepSize: number, stepValue: number, directionSign: number) {
    const steps = Math.floor(Math.abs(offset) / stepSize);
    return steps > 0 ? steps * stepValue * directionSign : 0;
  }

  isFileExist(item: VideoMetadata | undefined) {
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

  async routerWhere(context: Context,uri: string, item: string | undefined, encryption: boolean) {
    let list: VideoMetadata [] = []
    encryption ? list = await SelectFileUtil.getVideoMetaDataEncryption(context) :
      list = await SelectFileUtil.getVideoMetaData(context)
    const recentPlay = await PreferencesUtil.getPreferencesValue(context, "sweet_video", "recentPlay", true) as boolean
    if (!encryption && recentPlay) {
      RecentPlayUtil.addPlayback(context, list.find(i => i.date === item)!)
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
}

export default new ToolsUtil()