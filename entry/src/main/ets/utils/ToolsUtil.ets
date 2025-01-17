import promptAction from '@ohos.promptAction';
import { vibrator } from '@kit.SensorServiceKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { pinyin4js } from '@ohos/pinyin4js';
import { VideoMetadata } from './VideoUtil';

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
}

const ToolsUtil = new Tools()

export default ToolsUtil