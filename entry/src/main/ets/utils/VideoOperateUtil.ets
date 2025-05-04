import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { audio } from '@kit.AudioKit';
import { BusinessError } from '@kit.BasicServicesKit';
import ToolsUtil from './ToolsUtil';
import { media } from '@kit.MediaKit';
import AVSessionUtil from './AVSessionUtil';
import { PlayerParams } from '../common/PlayerParams';
import { VideoMetadata } from '../interfaces/VideoMetadata';
import { VideoMetadataFromPlayer } from '../interfaces/VideoMetadataFromPlayer';
import SelectFileUtil from './SelectFileUtil';
import { AudioTrack } from '../interfaces/AudioTrack';
import { FileFolder } from '../interfaces/FileFolder';
import { AvSessionState } from '../interfaces/AvSessionState';

// 视频操作类
class VideoOperateUtil {
  public max_volume: number = 0 // 最大音量
  public min_volume: number = 0 // 最小音量
  public lastSyncTime: number = 0; //最小同步时间
  public syncCoolDown: number = 1000; // 同步冷却时间1秒
  public driftHistory: number[] = []; // 差异记录用于趋势分析
  public initPinchDistance: number = 0; // 初始双指距离
  public clearSubtitleTimer: number | null = null; // 清除字幕时间
  public mIjkMediaPlayerActive: boolean = false // 激活增强型解码
  private windowStage: window.WindowStage = AppStorage.get('windowStage') as window.WindowStage;
  private mainWin: window.Window = this.windowStage.getMainWindowSync();

  // 设置亮度
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

  // 获取系统音量
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

  // 系统播放器播放失败处理
  playErrorExecute(pathStack: NavPathStack,video_meta_data: VideoMetadata[], date: string) {
    ToolsUtil.showToast(getContext().resourceManager.getStringSync($r('app.string.video_error')))
    const now_play_item = video_meta_data.find(item => {
      const target_item = SelectFileUtil.getItem(video_meta_data, item?.date)?.date;
      return date === target_item;
    });
    const playerParams = new PlayerParams(now_play_item, video_meta_data, undefined)
    pathStack.pushPathByName('FFMpegPlayer', playerParams, false)
  }

  // 未识别到音轨处理
  audioTrackErrorExecute(audio_track: AudioTrack[]) {
    if (audio_track.length === 0) {
      ToolsUtil.showToast('未识别到音轨，已开启实验性解码，可能会导致闪退、发热、耗电以及音画不同步')
      return false
    }
    return true
  }

  // 计算手指移动距离
  calcFingerDistance(f1: FingerInfo, f2: FingerInfo): number {
    const dx = f2.localX - f1.localX;
    const dy = f2.localY - f1.localY;
    return Math.sqrt(dx * dx + dy * dy);
  }

  // 获取音轨
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

  // 保存视频播放进度
  async saveVideoTime(play_time: number, now_playing: VideoMetadataFromPlayer,
    video_meta_data: VideoMetadata[], context: Context, file_folder: FileFolder) {
    const save_time = play_time < now_playing?.time! * 0.9 ? play_time : 0
    video_meta_data[video_meta_data.findIndex(i => i.date == now_playing?.date)].last_play = save_time
    if (file_folder) {
      console.error('test2')
      file_folder.video_list = video_meta_data
      let file_folder_list = await SelectFileUtil.getFileFolder(context)
      file_folder_list = file_folder_list.filter(i => i.date !== file_folder?.date)
      file_folder_list.push(file_folder!)
      await SelectFileUtil.saveFileFolder(context, file_folder_list)
    } else {
      console.error('test3')
      await SelectFileUtil.saveData(context, video_meta_data, now_playing!)
    }
  }

  // 保存视频长宽
  async saveVideoWeightAndHeight(now_playing: VideoMetadataFromPlayer,
    video_meta_data: VideoMetadata[], context: Context, file_folder: FileFolder) {
    video_meta_data[video_meta_data.findIndex(i => i.date == now_playing?.date)].size = now_playing.size
    if (file_folder.name.length !== 0) {
      file_folder.video_list = video_meta_data
      let file_folder_list = await SelectFileUtil.getFileFolder(context)
      file_folder_list = file_folder_list.filter(i => i.date !== file_folder?.date)
      file_folder_list.push(file_folder!)
      await SelectFileUtil.saveFileFolder(context, file_folder_list)
    } else {
      await SelectFileUtil.saveData(context, video_meta_data, now_playing!)
    }
  }

  // 更新播控中心状态
  updateSession(playing: boolean, play_time: number) {
    let data: AvSessionState = {
      playing: playing,
      duration: play_time
    }
    AVSessionUtil.updateSession(JSON.stringify(data))
  }
}

export default new VideoOperateUtil()