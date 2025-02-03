import promptAction from '@ohos.promptAction';
import { vibrator } from '@kit.SensorServiceKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { pinyin4js } from '@ohos/pinyin4js';
import VideoInfoUtil, { VideoMetadata } from './VideoInfoUtil';
import { fileIo as fs } from '@kit.CoreFileKit';
import PreferencesUtil from './PreferencesUtil';
import { media } from '@kit.MediaKit';
import { router } from '@kit.ArkUI';
import { JSON } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';
import SelectFileUtil from './SelectFileUtil';

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

  async copyFileToPrivacySpace(video_meta_data_encryption: VideoMetadata[], uri: string, sandbox_video: string,
    encryption: boolean, sandbox_path: string, date: string, metadata: media.AVMetadata,
    file: fs.File): Promise<string[]> {
    const file1 = fs.openSync(uri, fs.OpenMode.READ_ONLY);
    const file2 = fs.openSync(sandbox_video + date, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
    // 使用 Promise 封装 fs.copyFile
    return new Promise<string[]>((resolve, reject) => {
      fs.copyFile(file1.fd, file2.fd, async (error) => {
        if (error) {
          reject(error); // 处理错误
        } else {
          // 更新视频元数据
          video_meta_data_encryption.push(await VideoInfoUtil.setVideoInfo(date, uri, file.name, metadata,
            encryption, sandbox_video, sandbox_path));
          // 存储更新后的视频元数据
          SelectFileUtil.saveVideoMetaDataEncryption(video_meta_data_encryption)
          // 关闭文件描述符
          fs.closeSync(file1);
          fs.closeSync(file2);
          resolve(video_meta_data_encryption.map(i => i.date)); // 返回结果
        }
      });
    });
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

  routerWhere(uri: string, item: string | undefined, list: VideoMetadata []) {
    router.pushUrl({
      url: uri,
      params: {
        metadata: JSON.stringify(list.find(i => i.date === item)),
        metadata_list: JSON.stringify(list.find(i => i.date))
      }
    }, router.RouterMode.Standard, (err) => {
      hilog.info(0xFF00, "testTag", String(err));
    });
  }
}

const ToolsUtil = new Tools()

export default ToolsUtil