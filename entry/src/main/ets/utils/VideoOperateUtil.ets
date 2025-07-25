import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { audio } from '@kit.AudioKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { media } from '@kit.MediaKit';
import AVSessionUtil from './AVSessionUtil';
import { PlayerParams } from '../common/PlayerParams';
import { VideoMetadata } from '../interfaces/VideoMetadataInterface';
import { VideoMetadataFromPlayer } from '../interfaces/VideoMetadataFromPlayerInterface';
import SelectFileUtil from './SelectFileUtil';
import { AudioTrack } from '../interfaces/AudioTrackInterface';
import { AvSessionState } from '../interfaces/AvSessionStateInterface';
import ReqPermissionUtil from './ReqPermissionUtil';
import { common } from '@kit.AbilityKit';
import Preferences from '../database/Preferences';
import RecentPlayUtil from './RecentPlayUtil';
import PrivacySpaceUtil from './PrivacySpaceUtil';
import { AVCastPickerState, avSession, avSession as avSessionManager } from '@kit.AVSessionKit';
import { PathUtils } from './PathUtils';
import { LanguageConfig } from '../common/LanguageConfig';
import ToolsUtil from './ToolsUtil';
import VideoInfoUtil from './VideoInfoUtil';
import { WindowUtil } from './WindowUtil';

// 视频操作类
class VideoOperateUtil {
  public max_volume: number = 0 // 最大音量
  public min_volume: number = 0 // 最小音量
  public lastSyncTime: number = 0; //最小同步时间
  public syncCoolDown: number = 3000; // 同步冷却时间
  public driftHistory: number[] = []; // 差异记录用于趋势分析
  public initPinchDistance: number = 0; // 初始双指距离
  public clearSubtitleTimer: number | null = null; // 清除字幕时间
  public timePerPixel: number = 300 // 时间调节灵敏度
  public screenBrightnessTmp: number = 0
  public volumeTmp: number = 0
  public aspectRatioMap = new Map([[VideoInfoUtil.screen_extend_map[2], 16 / 9],
    [VideoInfoUtil.screen_extend_map[3], 4 / 3]]);
  private windowStage: window.WindowStage = AppStorage.get('windowStage') as window.WindowStage;
  private mainWin: window.Window = this.windowStage.getMainWindowSync();

  // 设置亮度
  setBrightness(screenBrightness: number) {
    try {
      this.mainWin.setWindowBrightness(screenBrightness, (err) => {
        if (err && err.code !== 0) {
          console.error(`Failed to obtain the main window. Cause code: ${err.code}, message: ${err.message}`);
          hilog.error(0x0000, 'AVPlayer', `Failed to set the brightness. Cause: ${JSON.stringify(err)}`);
          return;
        }
        // hilog.info(0x0000, 'AVPlayer', `Succeeded in setting the brightness.`);
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
  playErrorExecute(pathStack: NavPathStack, video_meta_data: VideoMetadata[], date: string) {
    ToolsUtil.showToast(PathUtils.appContext!.resourceManager.getStringSync($r('app.string.video_error')))
    const now_play_item = video_meta_data.find(item => {
      const target_item = SelectFileUtil.getItem(video_meta_data, item?.date)?.date;
      return date === target_item;
    });
    const playerParams = new PlayerParams(now_play_item, video_meta_data, undefined)
    pathStack.replacePathByName('FFMpegPlayer', playerParams, true)
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
  saveVideoTime(play_time: number, now_playing: VideoMetadataFromPlayer,
    video_meta_data: VideoMetadata[], context: Context) {
    // 保存文件数据
    SelectFileUtil.saveData(context, now_playing!, play_time)
    const recentPlay = Preferences.getRecentPlayState(context) // 判断最近播放开关是否开启
    if (recentPlay && !PrivacySpaceUtil.getPrivacyMode()) { // 最近播放开启且非隐私空间视频则添加到最近播放
      RecentPlayUtil.addPlayback(context, video_meta_data[video_meta_data.findIndex(i => i.date == now_playing?.date)])
    }
  }

  // 保存音视频宽高信息
  async saveVideoWeightAndHeight(context: Context, now_playing: VideoMetadataFromPlayer) {
    SelectFileUtil.saveData(context, now_playing!, undefined, now_playing.size)
  }

  // 更新播控中心状态
  updateSession(playing: boolean, play_time: number) {
    let data: AvSessionState = {
      playing: playing,
      duration: play_time
    }
    AVSessionUtil.updateSession(data)
  }

  // 启动时初始化已保存的设置项
  async initSetting(context: common.UIAbilityContext) {
    AppStorage.setOrCreate('allowBackgroundPlay', Preferences.getAllowBackgroundPlayState(context))
    AppStorage.setOrCreate('allowPlayBackExist', Preferences.getAllowPlayBackExistState(context))
    AppStorage.setOrCreate('fastForwardSeconds', Preferences.getFastForwardSeconds(context))
    AppStorage.setOrCreate('recentPlay', Preferences.getRecentPlayState(context))
    AppStorage.setOrCreate('defaultPlayer', Preferences.getDefaultPlayer(context))
    AppStorage.setOrCreate('subtitleSize', Preferences.getSubtitleSize(context))
    AppStorage.setOrCreate('allowDoubleFastForward', Preferences.getAllowDoubleFastForwardState(context))
    AppStorage.setOrCreate('skipIntroTime', Preferences.getSkipIntroTime(context))
    AppStorage.setOrCreate('is_list_display', Preferences.getListDisplayMode(context))
    ReqPermissionUtil.reqPermissionsFromUser(ReqPermissionUtil.permissions, context);
  }

  async checkOtherCast(avSession: avSessionManager.AVSession) {
    try {
      let currentOutputDevice: avSession.OutputDeviceInfo = avSession.getOutputDeviceSync();
      return currentOutputDevice
    } catch (err) {
      let error = err as BusinessError;
      console.error(`getOutputDeviceSync error, error code: ${error.code}, error message: ${error.message}`);
      return null
    }
  }

  castOnStateChange(state: AVCastPickerState) {
    if (state == AVCastPickerState.STATE_APPEARING) {
      console.log('The picker starts showing.');
    } else if (state == AVCastPickerState.STATE_DISAPPEARING) {
      console.log('The picker finishes presenting.');
    }
  }

  getLanguageName(code: string): string {
    if (!code) {
      return code;
    }
    const lowerCode = code.toLowerCase();
    return LanguageConfig.languageMap[lowerCode] || code;
  }

  setVideoAspectRatio(targetRatio: number, containerWidth: number, containerHeight: number) {
    let finalWidth = 0
    let finalHeight = 0
    const containerRatio = containerWidth / containerHeight;
    // 3. 根据比例动态调整
    if (containerRatio > targetRatio) {
      // 容器比目标“更宽” → 固定高度，按比例缩小宽度
      finalHeight = containerHeight;
      finalWidth = containerHeight * targetRatio; // 宽度 = 高度 × 目标比例
    } else {
      // 容器比目标“更高” → 固定宽度，按比例缩小高度
      finalWidth = containerWidth;
      finalHeight = containerWidth / targetRatio; // 高度 = 宽度 ÷ 目标比例
    }
    return [finalWidth, finalHeight]
  }

  fullScreenOperate() {
    if (canIUse('SystemCapability.Window.SessionManager')) {
      const windowUtil = WindowUtil?.getInstance?.()
      const windowStatus = windowUtil?.getWindowsStatus?.()
      switch (windowStatus) {
        case window.WindowStatusType.FLOATING:
          windowUtil?.maximize?.()
          return
        case window.WindowStatusType.FULL_SCREEN:
          windowUtil?.recover?.()
          return
      }
    }
  }
}

export default new VideoOperateUtil()