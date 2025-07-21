import { FileFolder } from '../interfaces/FileFolderInterface'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import PreferencesUtil from '../utils/PreferencesUtil'
import { Context } from '@kit.AbilityKit'

// 存储类
class Preferences {
  // 首页视频数据
  static getVideoMetaData(context: Context) {
    return Preferences.getFileFolder(context)[0]?.video_list ?? [] as VideoMetadata[]
  }

  // 隐私空间视频数据
  static getVideoMetaDataEncryption(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, 'sweet_video', 'video_meta_data_encryption',
      []) as VideoMetadata[]
  }

  // 所有文件夹视频数据
  static getFileFolder(context: Context) {
    const folders = PreferencesUtil.getPreferencesValue(context, 'sweet_video', 'file_folder', []) as FileFolder[]
    folders.sort((a, b) => Number(a.date) - Number(b.date))
    return folders
  }

  // 最近播放视频数据
  static getRecentPlay(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, 'sweet_video', 'recent_play', []) as VideoMetadata[]
  }

  static getPassword(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, 'sweet_video', 'passwd', '') as string
  }

  static getOOBEVersion(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, "sweet_video", "OOBEVersion", -1) as number
  }

  static getRecentPlayState(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, "sweet_video", "recentPlay", true) as boolean
  }

  static getAllowBackgroundPlayState(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, "sweet_video", "allowBackgroundPlay", true) as boolean
  }

  static getAllowPlayBackExistState(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, "sweet_video", "allowPlayBackExist", false) as boolean
  }

  static getSubtitleSize(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, "sweet_video", "subtitleSize", '22') as string
  }

  static getFastForwardSeconds(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, "sweet_video", "fastForwardSeconds", '15') as string
  }

  static getDefaultPlayer(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, "sweet_video", "defaultPlayer", 'FFMpeg播放器') as string
  }

  static getAllowDoubleFastForwardState(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, "sweet_video", "allowDoubleFastForward", true) as boolean
  }

  static getVideoSpeed(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, 'sweet_video', 'video_speed', '1x') as string
  }

  static getCirclePlayState(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, 'sweet_video', 'circle_play', false) as boolean
  }

  static getSkipIntroTime(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, 'sweet_video', 'skipIntroTime', '0') as string
  }

  static getListDisplayMode(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, 'sweet_video', 'is_list_display', true) as boolean
  }

  static saveSkipIntroTime(context: Context, skipIntroTime: string) {
    PreferencesUtil.putPreferencesValue(context, 'sweet_video', 'skipIntroTime', skipIntroTime);
  }

  static saveVideoSpeed(context: Context, video_speed: string) {
    PreferencesUtil.putPreferencesValue(context, 'sweet_video', 'video_speed', video_speed);
  }

  static saveCirclePlayState(context: Context, isEnabled: boolean) {
    PreferencesUtil.putPreferencesValue(context, 'sweet_video', 'circle_play', isEnabled)
  }

  static saveDefaultPlayer(context: Context, defaultPlayer: string) {
    PreferencesUtil.putPreferencesValue(context, "sweet_video", "defaultPlayer", defaultPlayer)
  }

  static saveSubtitleSize(context: Context, subtitleSize: string) {
    PreferencesUtil.putPreferencesValue(context, "sweet_video", "subtitleSize", subtitleSize)
  }

  static saveFastForwardSeconds(context: Context, fastForwardSeconds: string) {
    PreferencesUtil.putPreferencesValue(context, "sweet_video", "fastForwardSeconds", fastForwardSeconds)
  }

  static saveAllowDoubleFastForwardState(context: Context, isEnabled: boolean) {
    PreferencesUtil.putPreferencesValue(context, "sweet_video", "allowDoubleFastForward", isEnabled)
  }

  static saveAllowPlayBackExistState(context: Context, isEnabled: boolean) {
    PreferencesUtil.putPreferencesValue(context, "sweet_video", "allowPlayBackExist", isEnabled)
  }

  static saveAllowBackgroundPlayState(context: Context, isEnabled: boolean) {
    PreferencesUtil.putPreferencesValue(context, "sweet_video", "allowBackgroundPlay", isEnabled)
  }

  static saveRecentPlayState(context: Context, isEnabled: boolean) {
    PreferencesUtil.putPreferencesValue(context, "sweet_video", "recentPlay", isEnabled)
  }

  static savePassword(context: Context, password: string) {
    PreferencesUtil.putPreferencesValue(context, 'sweet_video', 'passwd', password)
  }

  static saveOOBEVersion(context: Context, OOBEVersion: number) {
    PreferencesUtil.putPreferencesValue(context, "sweet_video", "OOBEVersion", OOBEVersion)
  }

  static saveSingleVideoMetaData(context: Context, video_meta_data: VideoMetadata, folder: FileFolder) {

  }

  //保存首页 TODO 这里需要施工
  static saveVideoMetaData(context: Context, video_meta_data: VideoMetadata[]) {
    const folders = Preferences.getFileFolder(context)
    const rootFolderIndex: number = folders.findIndex(i => i.name === '首页')
    if (rootFolderIndex !== -1) {
      folders[rootFolderIndex].video_list = video_meta_data
      Preferences.saveFileFolder(context, folders)
    }
  }

  static saveVideoMetaDataEncryption(context: Context, video_meta_data_encryption: VideoMetadata[]) {
    PreferencesUtil.putPreferencesValue(context, 'sweet_video', 'video_meta_data_encryption',
      video_meta_data_encryption);
  }

  // 保存所有文件夹视频数据
  static saveFileFolder(context: Context, file_folder: FileFolder[]) {
    PreferencesUtil.putPreferencesValue(context, 'sweet_video', 'file_folder', file_folder);
  }

  static saveRecentPlay(context: Context, recent_play_deque: VideoMetadata[]) {
    PreferencesUtil.putPreferencesValue(context, 'sweet_video', 'recent_play', recent_play_deque);
  }

  static saveListDisplayMode(context: Context, is_list_display: boolean) {
    PreferencesUtil.putPreferencesValue(context, 'sweet_video', 'is_list_display', is_list_display);
  }
}

export default Preferences