import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { audio } from '@kit.AudioKit';
import { BusinessError, settings } from '@kit.BasicServicesKit';
import { media } from '@kit.MediaKit';
import { PlayerParams } from '../common/PlayerParams';
import { VideoMetadata } from '../interfaces/VideoMetadataInterface';
import { VideoMetadataFromPlayer } from '../interfaces/VideoMetadataFromPlayerInterface';
import SelectFileUtil from './SelectFileUtil';
import { AudioTrack } from '../interfaces/AudioTrackInterface';
import { common } from '@kit.AbilityKit';
import Preferences from '../database/Preferences';
import RecentPlayUtil from './RecentPlayUtil';
import PrivacySpaceUtil from './PrivacySpaceUtil';
import { PathUtils } from './PathUtils';
import { LanguageConfig } from '../common/LanguageConfig';
import ToolsUtil from './ToolsUtil';
import VideoInfoUtil from './VideoInfoUtil';
import { VideoStartTimeMode } from '../common/enum/VideoStartTimeMode';
import PreferencesUtil from './PreferencesUtil';
import PermissionUtil from './PermissionUtil';
import { VideoSource } from '../common/enum/VideoSource';

// 视频操作类
class VideoOperateUtil {
  public max_volume: number = 0 // 最大音量
  public min_volume: number = 0 // 最小音量
  public lastSyncTime: number = 0; //最小同步时间
  public syncCoolDown: number = 3000; // 同步冷却时间
  public driftHistory: number[] = []; // 差异记录用于趋势分析
  public initPinchDistance: number = 0; // 初始双指距离
  public clearSubtitleTimer: number | null = null; // 清除字幕时间
  public screenBrightnessTmp: number = 0
  public lastSpeed: number = 1
  public last_play_time: number = 0
  public aspectRatioMap = new Map([[VideoInfoUtil.screenExtendMap[2], 16 / 9],
    [VideoInfoUtil.screenExtendMap[3], 4 / 3]]);
  public lastVolume: number = 0
  public windowStage: window.WindowStage | undefined = undefined
  public volumeGestureActiveTime: number = 0
  public longPressStartX: number = 0
  public leftSideSwipe: boolean = true
  public delayJumpToPlayer: number = 450
  private mainWin: window.Window | undefined = undefined

  // 设置亮度
  setBrightness(screenBrightness: number) {
    if (!this.windowStage) {
      return
    }
    try {
      if (!this.mainWin) {
        this.mainWin = this.windowStage.getMainWindowSync()
      }
      this.mainWin.setWindowBrightness(screenBrightness, (err) => {
        if (err && err.code !== 0) {
          console.error(`Failed to obtain the main window. Cause code: ${err.code}, message: ${err.message}`);
          hilog.error(0x0000, 'AVPlayer', `Failed to set the brightness. Cause: ${JSON.stringify(err)}`);
          return;
        }
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

  // 播放器播放失败处理
  playErrorExecute(pathStack: NavPathStack, video_meta_data: VideoMetadata[], date: string, playerName: string) {
    ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.video_error').id))
    const now_play_item = video_meta_data.find(item => item.date === date);
    const playerParams = new PlayerParams(now_play_item, video_meta_data, undefined)
    pathStack.replacePathByName(playerName, playerParams, true)
  }

  // 未识别到音轨处理
  validateAudioTracks(audio_track: AudioTrack[]) {
    if (audio_track.length === 0) {
      ToolsUtil.showToast('未识别到音轨，已开启实验性解码')
      return false
    }
    return true
  }

  // 计算手指移动距离
  calcFingerDistance(f1: FingerInfo, f2: FingerInfo): number {
    // 检查坐标是否存在
    if (
      typeof f1?.localX !== 'number' ||
        typeof f1?.localY !== 'number' ||
        typeof f2?.localX !== 'number' ||
        typeof f2?.localY !== 'number'
    ) {
      return -1;
    }

    const dx = f2.localX - f1.localX;
    const dy = f2.localY - f1.localY;
    return Math.sqrt(dx * dx + dy * dy);
  }

  checkLocalX(localX: number | undefined | null) {
    return typeof localX === 'number';
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
    const recentPlay = Preferences.getRecentPlayState(context) // 判断最近播放开关是否开启
    if (recentPlay && !PrivacySpaceUtil.getPrivacyMode() &&
      !SelectFileUtil.isPathFromSource(now_playing.uri, VideoSource.PRIVACY_SPACE)) { // 最近播放开启且非隐私空间视频则添加到最近播放
      const meta = video_meta_data.find(i => i.date == now_playing?.date)
      if (meta) {
        RecentPlayUtil.addPlayback(context, meta)
      }
    }
    // 保存文件数据
    SelectFileUtil.saveData(context, now_playing!, play_time)
  }

  // 保存视频片头时间
  saveVideoStartTime(startTime: number, nowPlaying: VideoMetadataFromPlayer, context: Context) {
    SelectFileUtil.saveData(context, nowPlaying, undefined, undefined, startTime, undefined)
  }

  // 保存视频片尾时间
  saveVideoEndTime(endTime: number, nowPlaying: VideoMetadataFromPlayer, context: Context) {
    SelectFileUtil.saveData(context, nowPlaying, undefined, undefined, undefined, endTime)
  }

  // 保存音视频宽高信息
  saveVideoWeightAndHeight(context: Context, now_playing: VideoMetadataFromPlayer) {
    SelectFileUtil.saveData(context, now_playing!, undefined, now_playing.size)
  }

  saveVideoTotalTime(context: Context, now_playing: VideoMetadataFromPlayer) {
    SelectFileUtil.saveData(context, now_playing!, undefined, undefined, undefined, undefined, now_playing.time)
  }

  // 启动时初始化已保存的设置项
  initSetting(context: common.UIAbilityContext) {
    PermissionUtil.reqPermissionsFromUser(PermissionUtil.permissions, context);
    AppStorage.setOrCreate('allowBackgroundPlay', Preferences.getAllowBackgroundPlayState(context))
    AppStorage.setOrCreate('allowPlayBackExist', Preferences.getAllowPlayBackExistState(context))
    AppStorage.setOrCreate('fastForwardSeconds', Preferences.getFastForwardSeconds(context))
    AppStorage.setOrCreate('recentPlay', Preferences.getRecentPlayState(context))
    AppStorage.setOrCreate('defaultPlayer', Preferences.getDefaultPlayer(context))
    AppStorage.setOrCreate('subtitleSize', Preferences.getSubtitleSize(context))
    AppStorage.setOrCreate('allowDoubleFastForward', Preferences.getAllowDoubleFastForwardState(context))
    AppStorage.setOrCreate('skipIntroTime', Preferences.getSkipIntroTime(context))
    AppStorage.setOrCreate('isListDisplay', Preferences.getListDisplayMode(context))
    AppStorage.setOrCreate('smartRotation', Preferences.getSmartRotationState(context))
    AppStorage.setOrCreate('longPressSpeed', Preferences.getLongPressSpeed(context))
    AppStorage.setOrCreate('backgroundImageSrc', SelectFileUtil.getImageUri())
    AppStorage.setOrCreate('backgroundDropBlur', Preferences.getBackgroundDropBlur(context))
    AppStorage.setOrCreate('showSettingPageEntry', Preferences.getShowSettingPageEntry(context))
    // 这里删掉没用的存储项
    PreferencesUtil.delPreferencesValue(context, 'sweet_video', 'circle_play')
  }

  // 封装获取屏幕亮度的方法
  async getScreenBrightness(): Promise<number> {
    if (canIUse('SystemCapability.Applications.Settings.Core')) {
      try {
        const value = await settings.getValue(
          PathUtils.appContext!,
          settings.display.SCREEN_BRIGHTNESS_STATUS,
          settings.domainName.DEVICE_SHARED
        );
        return Number(value) / 255;
      } catch (error) {
        return 0
      }
    }
    return 0
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

  getVideoStartPlayTimeMode(nowPlaying: VideoMetadataFromPlayer, skipIntroTime: string) {
    // 若为视频设置了片头时间，并且上次播放记录小于片头时间或者已经播完了，则自动跳到片头时间
    if (nowPlaying?.start_time && nowPlaying?.start_time > 0 &&
      (nowPlaying.start_time > nowPlaying.last_play || nowPlaying?.last_play > nowPlaying?.time! * 0.95)) {
      ToolsUtil.showToast('已跳过片头')
      return VideoStartTimeMode.SEEK_TO_START_TIME
    }
    // 若已有播放记录，则自动跳到上次播放时间
    if (nowPlaying?.last_play !== 0 && nowPlaying?.last_play! < nowPlaying?.time! * 0.95) {
      ToolsUtil.showToast('已跳到上次播放时间')
      return VideoStartTimeMode.SEEK_TO_LAST_PLAY_TIME
    }
    // 若无播放记录，并且设定了统一片头时间，则自动跳到片头时间（音频除外）
    if (Number(skipIntroTime) > 0 && Number(skipIntroTime) * 1000 < nowPlaying?.time! &&
      !VideoInfoUtil.support_audio_format.includes(nowPlaying?.title.split('.')[nowPlaying?.title.split('.')
        .length-1].toLowerCase()!)) {
      ToolsUtil.showToast('已跳过统一的片头时间')
      return VideoStartTimeMode.SEEK_TO_INTRO_TIME
    }
    return -1
  }

  calNewBrightness(deltaYScale: number) {
    const newBrightness = this.screenBrightnessTmp - deltaYScale
    return Math.min(Math.max(newBrightness, 0), 1)
  }

  getTimePixel(screenWidth: number, videoTime: number) {
    return videoTime > 600000 ? 600000 / screenWidth : videoTime / screenWidth
  }
}

export default new VideoOperateUtil()