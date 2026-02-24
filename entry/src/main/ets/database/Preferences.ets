import { FileFolder } from '../interfaces/FileFolderInterface'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import PreferencesUtil from './PreferencesUtil'
import { Context } from '@kit.AbilityKit'
import { RepeatMode } from '../common/enum/RepeatMode'
import { BackgroundColorMode } from '../common/enum/BackgroundColorMode'
import { ListDisplayMode } from '../common/enum/ListDisplayMode'

// 存储类
export default class Preferences {
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
    return PreferencesUtil.getPreferencesValue(context, "sweet_video", "defaultPlayer", '系统播放器') as string
  }

  static getAllowDoubleFastForwardState(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, "sweet_video", "allowDoubleFastForward", true) as boolean
  }

  static getVideoSpeed(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, 'sweet_video', 'video_speed', '1x') as string
  }

  static getRepeatModeState(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, 'sweet_video', 'repeatMode', RepeatMode.LIST) as RepeatMode
  }

  static getSkipIntroTime(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, 'sweet_video', 'skipIntroTime', '0') as string
  }

  static getListDisplayMode(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, 'sweet_video', 'listDisplayMode',
      ListDisplayMode.LIST_DISPLAY) as ListDisplayMode
  }

  static getSmartRotationState(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, "sweet_video", "smartRotation", true) as boolean
  }

  static getLongPressSpeed(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, 'sweet_video', 'longPressSpeed', 3) as number
  }

  static getBackgroundDropBlur(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, 'sweet_video', 'backgroundDropBlur', 0) as number
  }

  static getShowSettingPageEntry(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, 'sweet_video', 'showSettingPageEntry', true) as boolean
  }

  static getBackgroundColorMode(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, 'sweet_video', 'backgroundColorMode',
      BackgroundColorMode.AUTO) as BackgroundColorMode
  }

  static getAllowGestureEntry(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, 'sweet_video', 'allowGestureEntry', true) as boolean
  }

  static getShowFrameTime(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, 'sweet_video', 'showFrameTime', true) as boolean
  }

  static getJumpToHistoryTime(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, 'sweet_video', 'jumpToHistoryTime', true) as boolean
  }

  static saveBackgroundColorMode(context: Context, backgroundColorMode: BackgroundColorMode) {
    PreferencesUtil.putPreferencesValue(context, 'sweet_video', 'backgroundColorMode', backgroundColorMode)
  }

  static saveShowSettingPageEntry(context: Context, showSettingPageEntry: boolean) {
    PreferencesUtil.putPreferencesValue(context, 'sweet_video', 'showSettingPageEntry', showSettingPageEntry)
  }

  static saveAllowGestureEntry(context: Context, allowGestureEntry: boolean) {
    PreferencesUtil.putPreferencesValue(context, 'sweet_video', 'allowGestureEntry', allowGestureEntry)
  }

  static saveSkipIntroTime(context: Context, skipIntroTime: string) {
    PreferencesUtil.putPreferencesValue(context, 'sweet_video', 'skipIntroTime', skipIntroTime)
  }

  static saveVideoSpeed(context: Context, video_speed: string) {
    PreferencesUtil.putPreferencesValue(context, 'sweet_video', 'video_speed', video_speed)
  }

  static saveRepeatModeState(context: Context, repeatMode: RepeatMode) {
    PreferencesUtil.putPreferencesValue(context, 'sweet_video', 'repeatMode', repeatMode)
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

  static saveSmartRotation(context: Context, smartRotationState: boolean) {
    PreferencesUtil.putPreferencesValue(context, "sweet_video", "smartRotation", smartRotationState)
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
      video_meta_data_encryption)
  }

  // 保存所有文件夹视频数据
  static saveFileFolder(context: Context, file_folder: FileFolder[]) {
    PreferencesUtil.putPreferencesValue(context, 'sweet_video', 'file_folder', file_folder)
  }

  static saveRecentPlay(context: Context, recent_play_deque: VideoMetadata[]) {
    PreferencesUtil.putPreferencesValue(context, 'sweet_video', 'recent_play', recent_play_deque)
  }

  static saveListDisplayMode(context: Context, listDisplayMode: ListDisplayMode) {
    PreferencesUtil.putPreferencesValue(context, 'sweet_video', 'listDisplayMode', listDisplayMode)
  }

  static saveLongPressSpeed(context: Context, longPressSpeed: number) {
    PreferencesUtil.putPreferencesValue(context, 'sweet_video', 'longPressSpeed', longPressSpeed)
  }

  static saveBackgroundDropBlur(context: Context, backgroundDropBlur: number) {
    PreferencesUtil.putPreferencesValue(context, 'sweet_video', 'backgroundDropBlur', backgroundDropBlur)
  }

  static saveShowFrameTime(context: Context, showFrameTime: boolean) {
    PreferencesUtil.putPreferencesValue(context, 'sweet_video', 'showFrameTime', showFrameTime)
  }

  static saveJumpToHistoryTime(context: Context, jumpToHistoryTime: boolean) {
    PreferencesUtil.putPreferencesValue(context, 'sweet_video', 'jumpToHistoryTime', jumpToHistoryTime)
  }
}