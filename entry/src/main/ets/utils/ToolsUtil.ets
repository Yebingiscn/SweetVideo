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

class Tools {
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

  compareByName(show_list: string[], list: VideoMetadata[]): string[] {
    show_list = list
      .sort((a: VideoMetadata, b: VideoMetadata) => String(pinyin4js.getShortPinyin(a.title))
        .localeCompare(String(pinyin4js.getShortPinyin(b.title)))).map(i => i.date);
    return show_list
  }

  compareByTime(show_list: string[], list: VideoMetadata[]): string[] {
    show_list = list.sort((a, b) => a.date.localeCompare(b.date)).map(i => i.date)
    return show_list
  }

  savePwd(passwd: string) {
    PreferencesUtil.putPreferencesValue('sweet_video', 'passwd', passwd)
    ToolsUtil.showToast(getContext().resourceManager.getStringSync($r('app.string.set_passwd_tip')))
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

  routerWhere(uri: string, item: string | undefined, list: VideoMetadata []) {
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

const ToolsUtil = new Tools()

export default ToolsUtil