import { router, window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { audio } from '@kit.AudioKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { VideoMetadata, VideoMetadataFromPlayer } from './VideoInfoUtil';
import ToolsUtil from './ToolsUtil';
import SelectFileUtil from './SelectFileUtil';
import { media } from '@kit.MediaKit';
import AVSessionUtil, { avSessionState } from './AVSessionUtil';

export interface AudioTrack {
  index: number;
  language: string;
  name: string;
  mime: string
}

class VideoOperateUtil {
  public max_volume: number = 0
  public min_volume: number = 0
  public lastSyncTime: number = 0;
  public syncCoolDown: number = 1000; // 同步冷却时间1秒
  public driftHistory: number[] = []; // 差异记录用于趋势分析
  public initPinchDistance: number = 0;
  public clearSubtitleTimer: number | null = null;
  public mIjkMediaPlayerActive: boolean = false
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
                this.max_volume = maxVolume
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
                this.min_volume = minVolume
                resolveMin();
              });
          }));
          Promise.all(volumePromises)
            .then(() => resolve(volume_list))// 所有音量均成功获取，返回 volume_list
            .catch(reject); // 如果有任何一个 Promise 失败，拒绝整个 Promise
        });
    });
  }

  playErrorExecute(video_meta_data: VideoMetadata[], date: string) {
    ToolsUtil.showToast(getContext().resourceManager.getStringSync($r('app.string.video_error')))
    const now_play_item = video_meta_data.find(item => {
      const target_item = SelectFileUtil.getItem(video_meta_data, item?.date)?.date;
      return date === target_item;
    });
    router.replaceUrl({
      url: 'pages/FFMpegPlayer',
      params: {
        metadata: JSON.stringify(now_play_item),
        metadata_list: JSON.stringify(video_meta_data)
      }
    }, router.RouterMode.Standard)
  }

  audioTrackErrorExecute(audio_track: AudioTrack[]) {
    if (audio_track.length === 0) {
      ToolsUtil.showToast('未识别到音轨，已开启实验性解码，可能会导致闪退、发热、耗电以及音画不同步')
      return false
    }
    return true
  }

  calcFingerDistance(f1: FingerInfo, f2: FingerInfo): number {
    const dx = f2.localX - f1.localX;
    const dy = f2.localY - f1.localY;
    return Math.sqrt(dx * dx + dy * dy);
  }

  async getAudioTracks(avPlayer: media.AVPlayer): Promise<AudioTrack[]> {
    const getTrackDescriptions = (): Promise<AudioTrack[]> => {
      return new Promise((resolve, reject) => {
        avPlayer.getTrackDescription((error: BusinessError, arrList: Array<media.MediaDescription>) => {
          if (error || !arrList || arrList.length === 0) {
            console.error(`Failed to get TrackDescription, error: ${error}`);
            return reject(error || new Error("No audio tracks available"));
          }
          const audioTracks: AudioTrack[] = arrList
            .filter(description =>
            description[media.MediaDescriptionKey.MD_KEY_TRACK_TYPE] === media.MediaType.MEDIA_TYPE_AUD
            )
            .map((description): AudioTrack => {
              return {
                index: description[media.MediaDescriptionKey.MD_KEY_TRACK_INDEX] as number,
                language: description[media.MediaDescriptionKey.MD_KEY_LANGUAGE] as string,
                name: description[media.MediaDescriptionKey.MD_KEY_TRACK_NAME] as string,
                mime: description[media.MediaDescriptionKey.MD_KEY_CODEC_MIME] as string
              };
            });
          resolve(audioTracks);
        });
      });
    };

    try {
      const audioTracks = await getTrackDescriptions();
      return audioTracks; // 返回包含音轨索引、语言和名称的对象数组
    } catch (error) {
      console.error("获取 audioTracks 失败:", error);
      return []; // 返回空数组表示没有获取到音轨
    }
  }

  async saveVideoTime(play_time: number, now_playing: VideoMetadataFromPlayer,
    video_meta_data: VideoMetadata[], context: Context) {
    const save_time = play_time < now_playing?.time! * 0.9 ? play_time : 0
    video_meta_data[video_meta_data.findIndex(i => i.date == now_playing?.date)].last_play = save_time
    await SelectFileUtil.saveData(context, video_meta_data, now_playing!)
  }

  updateSession(playing: boolean, play_time: number) {
    let data: avSessionState = {
      playing: playing,
      duration: play_time
    }
    AVSessionUtil.updateSession(JSON.stringify(data))
  }
}

export default new VideoOperateUtil()