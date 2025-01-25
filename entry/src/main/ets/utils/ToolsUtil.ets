import promptAction from '@ohos.promptAction';
import { vibrator } from '@kit.SensorServiceKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { pinyin4js } from '@ohos/pinyin4js';
import VideoInfoUtil, { VideoMetadata } from './VideoInfoUtil';
import { fileIo as fs } from '@kit.CoreFileKit';
import PreferencesUtil from './PreferencesUtil';
import { media } from '@kit.MediaKit';

class Tools {
  showToast(text: string) {
    promptAction.showToast({
      message: text,
      duration: 2000,
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

  compareName(show_list: string[], encryption: boolean, video_meta_data_encryption: VideoMetadata[],
    video_meta_data: VideoMetadata[]): string[] {
    if (encryption) {
      show_list = video_meta_data_encryption
        .sort((a: VideoMetadata, b: VideoMetadata) => String(pinyin4js.getShortPinyin(a.title))
          .localeCompare(String(pinyin4js.getShortPinyin(b.title)))).map(i => i.date);
    } else {
      show_list = video_meta_data
        .sort((a: VideoMetadata, b: VideoMetadata) => String(pinyin4js.getShortPinyin(a.title))
          .localeCompare(String(pinyin4js.getShortPinyin(b.title)))).map(i => i.date);
    }
    return show_list;
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
          PreferencesUtil.putPreferencesValue('sweet_video', 'video_meta_data_encryption', video_meta_data_encryption);
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
}

const ToolsUtil = new Tools()

export default ToolsUtil