import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { audio } from '@kit.AudioKit';
import { BusinessError, settings } from '@kit.BasicServicesKit';
import { media } from '@kit.MediaKit';
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
import PreferencesUtil from '../database/PreferencesUtil';
import PermissionUtil from './PermissionUtil';
import { VideoSource } from '../common/enum/VideoSource';
import { PlayerParams } from '../common/NavigationCommon';
import { Setting } from './ObservedUtil';
import DataSyncUtil from './DataSyncUtil';
import { fileIo, fileIo as fs } from '@kit.CoreFileKit';

// 视频操作类
export default class VideoOperateUtil {
  public static max_volume: number = 0
  public static min_volume: number = 0
  public static lastSyncTime: number = 0;
  public static syncCoolDown: number = 3000;
  public static driftHistory: number[] = [];
  public static initPinchDistance: number = 0;
  public static clearSubtitleTimer: number | null = null;
  public static screenBrightnessTmp: number = 0
  public static lastSpeed: number = 1
  public static lastPlayTime: number = 0
  public static aspectRatioMap = new Map([[VideoInfoUtil.screenExtendMap[2], 16 / 9],
    [VideoInfoUtil.screenExtendMap[3], 4 / 3]]);
  public static config: ImageAnalyzerConfig = {
    types: [ImageAnalyzerType.SUBJECT, ImageAnalyzerType.TEXT]
  };
  public static aiController: ImageAnalyzerController = new ImageAnalyzerController();
  public static options: ImageAIOptions = {
    types: [ImageAnalyzerType.SUBJECT, ImageAnalyzerType.TEXT],
    aiController: VideoOperateUtil.aiController
  };
  public static lastVolume: number = 0
  public static windowStage: window.WindowStage | undefined = undefined
  public static volumeGestureActiveTime: number = 0
  public static longPressStartX: number = 0
  public static leftSideSwipe: boolean = true
  public static delayJumpToPlayer: number = 450
  public static avImageGenerator: media.AVImageGenerator | undefined = undefined
  public static fileTest: fileIo.File | undefined = undefined
  public static timeTmp: number = 0
  private static mainWin: window.Window | undefined = undefined

  // 设置亮度
  static setBrightness(screenBrightness: number) {
    if (!VideoOperateUtil.windowStage) {
      return
    }
    try {
      if (!VideoOperateUtil.mainWin) {
        VideoOperateUtil.mainWin = VideoOperateUtil.windowStage.getMainWindowSync()
      }
      VideoOperateUtil.mainWin.setWindowBrightness(screenBrightness, (err) => {
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
  static async getVolume(audioVolumeManager: audio.AudioVolumeManager, groupId: number): Promise<Map<string, number>> {
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
                VideoOperateUtil.max_volume = maxVolume
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
                VideoOperateUtil.min_volume = minVolume
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
  static playErrorExecute(pathStack: NavPathStack, video_meta_data: VideoMetadata[], date: string, playerName: string) {
    ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.video_error').id))
    const now_play_item = video_meta_data.find(item => item.date === date);
    const playerParams = new PlayerParams(now_play_item, video_meta_data, undefined)
    pathStack.replacePathByName(playerName, playerParams, true)
  }

  // 未识别到音轨处理
  static validateAudioTracks(audio_track: AudioTrack[]) {
    if (audio_track.length === 0) {
      ToolsUtil.showToast('未识别到音轨，已开启实验性解码')
      return false
    }
    return true
  }

  // 计算手指移动距离
  static calcFingerDistance(f1: FingerInfo, f2: FingerInfo): number {
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

  static checkLocalX(localX: number | undefined | null) {
    return typeof localX === 'number';
  }

  // 获取音轨
  static async getAudioTracks(avPlayer: media.AVPlayer): Promise<AudioTrack[]> {
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
  static saveVideoTime(play_time: number, now_playing: VideoMetadataFromPlayer,
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
  static saveVideoStartTime(startTime: number, nowPlaying: VideoMetadataFromPlayer, context: Context) {
    SelectFileUtil.saveData(context, nowPlaying, undefined, undefined, startTime, undefined)
  }

  // 保存视频片尾时间
  static saveVideoEndTime(endTime: number, nowPlaying: VideoMetadataFromPlayer, context: Context) {
    SelectFileUtil.saveData(context, nowPlaying, undefined, undefined, undefined, endTime)
  }

  // 保存音视频宽高信息
  static saveVideoWeightAndHeight(context: Context, now_playing: VideoMetadataFromPlayer) {
    SelectFileUtil.saveData(context, now_playing!, undefined, now_playing.size)
  }

  static saveVideoTotalTime(context: Context, now_playing: VideoMetadataFromPlayer) {
    SelectFileUtil.saveData(context, now_playing!, undefined, undefined, undefined, undefined, now_playing.time)
  }

  static saveLastPlayVideoIndex(list: VideoMetadata[], date: string | undefined) {
    if (!date) {
      return
    }
    const targetIndex = list.findIndex(i => i.date === date)
    if (targetIndex === DataSyncUtil.lastPlayVideoIndex) {
      DataSyncUtil.lastPlayVideoIndex = -1
    } else {
      DataSyncUtil.lastPlayVideoIndex = targetIndex
    }
  }

  static async getFrameTimeProcess(uri: string) {
    try {
      VideoOperateUtil.avImageGenerator = await media.createAVImageGenerator();
      VideoOperateUtil.fileTest = fs.openSync(uri, fs.OpenMode.READ_ONLY)
      let avFileDescriptor: media.AVFileDescriptor = { fd: VideoOperateUtil.fileTest.fd };
      VideoOperateUtil.avImageGenerator.fdSrc = avFileDescriptor
    } catch (error) {
      // TODO: Implement error handling.
    }
  }

  // 启动时初始化已保存的设置项
  static initSetting(context: common.UIAbilityContext) {
    PermissionUtil.reqPermissionsFromUser(PermissionUtil.permissions, context);
    // 这里删掉没用的存储项
    PreferencesUtil.delPreferencesValue(context, 'sweet_video', 'circle_play')
    PreferencesUtil.delPreferencesValue(context, 'sweet_video', 'is_list_display')

    Setting.backgroundImageSrc = SelectFileUtil.getImageUri()
    Setting.backgroundDropBlur = Preferences.getBackgroundDropBlur(context)
    Setting.backgroundColorMode = Preferences.getBackgroundColorMode(context)
    Setting.allowBackgroundPlay = Preferences.getAllowBackgroundPlayState(context)
    Setting.allowPlayBackExist = Preferences.getAllowPlayBackExistState(context)
    Setting.fastForwardSeconds = Preferences.getFastForwardSeconds(context)
    Setting.recentPlay = Preferences.getRecentPlayState(context)
    Setting.defaultPlayer = Preferences.getDefaultPlayer(context)
    Setting.subtitleSize = Preferences.getSubtitleSize(context)
    Setting.allowDoubleFastForward = Preferences.getAllowDoubleFastForwardState(context)
    Setting.skipIntroTime = Preferences.getSkipIntroTime(context)
    Setting.listDisplayMode = Preferences.getListDisplayMode(context)
    Setting.smartRotation = Preferences.getSmartRotationState(context)
    Setting.longPressSpeed = Preferences.getLongPressSpeed(context)
    Setting.showSettingPageEntry = Preferences.getShowSettingPageEntry(context)
    Setting.allowGestureEntry = Preferences.getAllowGestureEntry(context)
  }

  // 封装获取屏幕亮度的方法
  static async getScreenBrightness(): Promise<number> {
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

  static getLanguageName(code: string): string {
    if (!code) {
      return code;
    }
    const lowerCode = code.toLowerCase();
    return LanguageConfig.languageMap[lowerCode] || code;
  }

  static setVideoAspectRatio(targetRatio: number, containerWidth: number, containerHeight: number) {
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

  static getVideoStartPlayTimeMode(nowPlaying: VideoMetadataFromPlayer): number {
    // 先判断 nowPlaying 是否有效
    if (!nowPlaying) {
      return -1;
    }
    const start_time = nowPlaying.start_time;
    const end_time = nowPlaying.end_time;
    const last_play = nowPlaying.last_play ?? 0;
    const time = nowPlaying.time ?? 0;
    const title = nowPlaying.title;
    // 条件1：若设置了片头时间（start_time > 0）
    if (start_time != null && start_time > 0) {
      const isBeforeStart = last_play < start_time
      const isAlmostComplete = last_play > time * 0.95
      const isBeyondEnd = end_time != null && end_time > 0 && last_play >= end_time
      if (isBeforeStart || isAlmostComplete || isBeyondEnd) {
        ToolsUtil.showToast('已跳过片头')
        return VideoStartTimeMode.SEEK_TO_START_TIME
      }
    }
    // 条件2：若有有效播放记录（且未接近结尾），则跳转到上次播放位置
    if (last_play !== 0 && last_play < time * 0.95) {
      ToolsUtil.showToast('已跳到上次播放时间')
      return VideoStartTimeMode.SEEK_TO_LAST_PLAY_TIME
    }
    // 条件3：若无播放记录，但全局设置了统一片头跳过时间（仅适用于视频）
    const skipIntroSeconds = Number(Setting.skipIntroTime)
    if (skipIntroSeconds > 0) {
      const skipIntroMs = skipIntroSeconds * 1000
      if (skipIntroMs < time && title != null) {
        const parts = title.split('.')
        const fileExt = parts.length > 0 ? parts[parts.length - 1].toLowerCase() : ''
        if (fileExt !== '' && !VideoInfoUtil.support_audio_format.includes(fileExt)) {
          ToolsUtil.showToast('已跳过统一的片头时间')
          return VideoStartTimeMode.SEEK_TO_INTRO_TIME
        }
      }
    }
    return -1
  }

  static calNewBrightness(deltaYScale: number) {
    const newBrightness = VideoOperateUtil.screenBrightnessTmp - deltaYScale
    return Math.min(Math.max(newBrightness, 0), 1)
  }

  static getTimePixel(screenWidth: number, videoTime: number) {
    return videoTime > 600000 ? 600000 / screenWidth : videoTime / screenWidth
  }
}