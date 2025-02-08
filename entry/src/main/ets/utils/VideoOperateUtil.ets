import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { audio } from '@kit.AudioKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { media } from '@kit.MediaKit';

class VideoOperateUtil {
  private windowStage: window.WindowStage = AppStorage.get('windowStage') as window.WindowStage;
  private mainWin: window.Window = this.windowStage.getMainWindowSync();

  setBrightness(screenBrightness: number) {
    try {
      this.mainWin.setWindowBrightness(screenBrightness, (err) => {
        if (err) {
          hilog.error(0x0000, 'AVPlayer', `Failed to set the brightness. Cause: ${JSON.stringify(err)}`);
          return;
        }
        hilog.info(0x0000, 'AVPlayer', `Succeeded in setting the brightness.`);
      });
    } catch (exception) {
      hilog.error(0x0000, 'AVPlayer', `Failed to set the brightness.`);
    }
  }

  async getVolume(audioVolumeManager: audio.AudioVolumeManager, groupId: number): Promise<Map<string, number>> {
    let volume_list: Map<string, number> = new Map();
    return new Promise((resolve, reject) => {
      audioVolumeManager.getVolumeGroupManager(groupId,
        (err: BusinessError, audioVolumeGroupManager: audio.AudioVolumeGroupManager) => {
          if (err) {
            hilog.error(0x0000, 'AVPlayer', `Failed to obtain the volume group info list. ${err}`);
            return reject(err);
          }
          const volumePromises: Promise<void>[] = [];
          volumePromises.push(new Promise((resolveVolume, rejectVolume) => {
            audioVolumeGroupManager.getVolume(audio.AudioVolumeType.MEDIA, (err: BusinessError, volume: number) => {
              if (err) {
                hilog.error(0x0000, 'AVPlayer', `Failed to obtain the volume. ${err}`);
                return rejectVolume(err);
              }
              volume_list.set('volume', volume);
              resolveVolume();
            });
          }));
          volumePromises.push(new Promise((resolveMax, rejectMax) => {
            audioVolumeGroupManager.getMaxVolume(audio.AudioVolumeType.MEDIA,
              (err: BusinessError, maxVolume: number) => {
                if (err) {
                  hilog.error(0x0000, 'AVPlayer', `Failed to obtain the maximum volume. ${err}`);
                  return rejectMax(err);
                }
                volume_list.set('max_volume', maxVolume);
                resolveMax();
              });
          }));
          volumePromises.push(new Promise((resolveMin, rejectMin) => {
            audioVolumeGroupManager.getMinVolume(audio.AudioVolumeType.MEDIA,
              (err: BusinessError, minVolume: number) => {
                if (err) {
                  hilog.error(0x0000, 'AVPlayer', `Failed to obtain the minimum volume. ${err}`);
                  return rejectMin(err);
                }
                volume_list.set('min_volume', minVolume);
                resolveMin();
              });
          }));
          Promise.all(volumePromises)
            .then(() => resolve(volume_list))// 所有音量均成功获取，返回 volume_list
            .catch(reject); // 如果有任何一个 Promise 失败，拒绝整个 Promise
        });
    });
  }

  async getAudioTrack(avPlayer: media.AVPlayer) {
    const getTrackDescription = (): Promise<Object> => {
      return new Promise((resolve, reject) => {
        let audioTrackIndex: Object = 0;
        avPlayer.getTrackDescription((error: BusinessError, arrList: Array<media.MediaDescription>) => {
          if (arrList != null) {
            for (let i = 0; i < arrList.length; i++) {
              if (i != 0) {
                hilog.error(777, 'testFlag', 'audio test' + arrList[i][media.MediaDescriptionKey.MD_KEY_TRACK_INDEX])
                audioTrackIndex = arrList[i][media.MediaDescriptionKey.MD_KEY_TRACK_INDEX];
              }
            }
            resolve(audioTrackIndex); // 成功时 resolve Promise
          } else {
            console.error(`Failed to get TrackDescription, error:${error}`);
            reject(error); // 失败时 reject Promise
          }
        });
      });
    };
    try {
      let audioTrackIndex = await getTrackDescription();
      return audioTrackIndex; // 返回获取到的 audioTrackIndex
    } catch (error) {
      console.error("获取 audioTrackIndex 失败:", error);
      return null; // 可以返回一个默认值或者抛出异常
    }
  }

}

const videoOperateUtil = new VideoOperateUtil()

export default videoOperateUtil as VideoOperateUtil