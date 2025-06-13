import { FileFolder } from '../interfaces/FileFolderInterface'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import PreferencesUtil from '../utils/PreferencesUtil'
import { Context } from '@kit.AbilityKit'

// 存储类
class Preferences {
  getVideoMetaData(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, 'sweet_video', 'recent_video_meta_data',
      []) as VideoMetadata[]
  }

  getVideoMetaDataEncryption(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, 'sweet_video', 'video_meta_data_encryption',
      []) as VideoMetadata[]
  }

  getFileFolder(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, 'sweet_video', 'file_folder', []) as FileFolder[]
  }

  getPassword(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, 'sweet_video', 'passwd', '') as string
  }

  getRecentPlay(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, 'sweet_video', 'recent_play', []) as VideoMetadata[]
  }

  getOOBEVersion(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, "sweet_video", "OOBEVersion", -1) as number
  }

  getRecentPlayState(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, "sweet_video", "recentPlay", true) as boolean
  }

  getAllowBackgroundPlayState(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, "sweet_video", "allowBackgroundPlay", true) as boolean
  }

  getAllowPlayBackExistState(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, "sweet_video", "allowPlayBackExist", false) as boolean
  }

  getSubtitleSize(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, "sweet_video", "subtitleSize", '22') as string
  }

  getFastForwardSeconds(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, "sweet_video", "fastForwardSeconds", '15') as string
  }

  getDefaultPlayer(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, "sweet_video", "defaultPlayer", 'FFMpeg播放器') as string
  }

  getAllowDoubleFastForwardState(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, "sweet_video", "allowDoubleFastForward", true) as boolean
  }

  getVideoSpeed(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, 'sweet_video', 'video_speed', '1x') as string
  }

  getCirclePlayState(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, 'sweet_video', 'circle_play', false) as boolean
  }

  getSkipIntroTime(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, 'sweet_video', 'skipIntroTime', '0') as string
  }

  getListDisplayMode(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, 'sweet_video', 'is_list_display', true) as boolean
  }

  saveSkipIntroTime(context: Context, skipIntroTime: string) {
    PreferencesUtil.putPreferencesValue(context, 'sweet_video', 'skipIntroTime', skipIntroTime);
  }

  saveVideoSpeed(context: Context, video_speed: string) {
    PreferencesUtil.putPreferencesValue(context, 'sweet_video', 'video_speed', video_speed);
  }

  saveCirclePlayState(context: Context, isEnabled: boolean) {
    PreferencesUtil.putPreferencesValue(context, 'sweet_video', 'circle_play', isEnabled)
  }

  saveDefaultPlayer(context: Context, defaultPlayer: string) {
    PreferencesUtil.putPreferencesValue(context, "sweet_video", "defaultPlayer", defaultPlayer)
  }

  saveSubtitleSize(context: Context, subtitleSize: string) {
    PreferencesUtil.putPreferencesValue(context, "sweet_video", "subtitleSize", subtitleSize)
  }

  saveFastForwardSeconds(context: Context, fastForwardSeconds: string) {
    PreferencesUtil.putPreferencesValue(context, "sweet_video", "fastForwardSeconds", fastForwardSeconds)
  }

  saveAllowDoubleFastForwardState(context: Context, isEnabled: boolean) {
    PreferencesUtil.putPreferencesValue(context, "sweet_video", "allowDoubleFastForward", isEnabled)
  }

  saveAllowPlayBackExistState(context: Context, isEnabled: boolean) {
    PreferencesUtil.putPreferencesValue(context, "sweet_video", "allowPlayBackExist", isEnabled)
  }

  saveAllowBackgroundPlayState(context: Context, isEnabled: boolean) {
    PreferencesUtil.putPreferencesValue(context, "sweet_video", "allowBackgroundPlay", isEnabled)
  }

  saveRecentPlayState(context: Context, isEnabled: boolean) {
    PreferencesUtil.putPreferencesValue(context, "sweet_video", "recentPlay", isEnabled)
  }

  savePassword(context: Context, password: string) {
    PreferencesUtil.putPreferencesValue(context, 'sweet_video', 'passwd', password)
  }

  saveOOBEVersion(context: Context, OOBEVersion: number) {
    PreferencesUtil.putPreferencesValue(context, "sweet_video", "OOBEVersion", OOBEVersion)
  }

  saveVideoMetaData(context: Context, video_meta_data: VideoMetadata[]) {
    PreferencesUtil.putPreferencesValue(context, 'sweet_video', 'recent_video_meta_data', video_meta_data);
  }

  saveVideoMetaDataEncryption(context: Context, video_meta_data_encryption: VideoMetadata[]) {
    PreferencesUtil.putPreferencesValue(context, 'sweet_video', 'video_meta_data_encryption',
      video_meta_data_encryption);
  }

  saveFileFolder(context: Context, file_folder: FileFolder[]) {
    PreferencesUtil.putPreferencesValue(context, 'sweet_video', 'file_folder', file_folder);
  }

  saveRecentPlay(context: Context, recent_play_deque: VideoMetadata[]) {
    PreferencesUtil.putPreferencesValue(context, 'sweet_video', 'recent_play', recent_play_deque);
  }

  saveListDisplayMode(context: Context, is_list_display: boolean) {
    PreferencesUtil.putPreferencesValue(context, 'sweet_video', 'is_list_display', is_list_display);
  }
}

export default new Preferences()