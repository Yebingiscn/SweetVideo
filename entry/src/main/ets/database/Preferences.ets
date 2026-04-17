import PreferencesUtil from './PreferencesUtil'
import { Context } from '@kit.AbilityKit'
import { SweetRepeatMode } from '../common/enum/SweetRepeatMode'
import { BackgroundColorMode } from '../common/enum/BackgroundColorMode'
import { CoverLayoutMode, ListDisplayMode } from '../common/enum/DisplayMode'
import { MpvDecodingMethod } from '../controller/MpvController/MpvTypes'

const DATA_BASE_NAME = 'sweet_video'

// 存储类 - ORM 改造后职责收缩：仅用于纯设置项（如播放器配置、主题、密码等）。
// 视频元数据、文件夹、最近播放等结构化数据已迁移到各自的 Repository（ibest-orm），不再通过 Preferences 存储。
export default class Preferences {
  static saveMpvDecodingMethod(context: Context, decodingMethod: MpvDecodingMethod) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'mpv_decoding_method', decodingMethod)
  }

  static getMpvDecodingMethod(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, 'mpv_decoding_method',
      MpvDecodingMethod.HARDWARE_SURFACE) as MpvDecodingMethod
  }

  static getPassword(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, 'passwd', '') as string
  }

  static getOOBEVersion(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, "OOBEVersion", -1) as number
  }

  static getRecentPlayState(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, "recentPlay", true) as boolean
  }

  static getShowToastState(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, "showToast", true) as boolean
  }

  static getAllowBackgroundPlayState(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, "allowBackgroundPlay", true) as boolean
  }

  static getAllowPlayBackExistState(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, "allowPlayBackExist", false) as boolean
  }

  static getSubtitleSize(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, "subtitleSize", '22') as string
  }

  static getFastForwardSeconds(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, "fastForwardSeconds", '15') as string
  }

  static getDefaultPlayerEngine(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, "defaultPlayerEngine", '系统播放器') as string
  }

  static getAllowDoubleFastForwardState(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, "allowDoubleFastForward", true) as boolean
  }

  static getVideoSpeed(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, 'video_speed', '1x') as string
  }

  static getRepeatModeState(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, 'repeatMode',
      SweetRepeatMode.LIST) as SweetRepeatMode
  }

  static getSkipIntroTime(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, 'skipIntroTime', '0') as string
  }

  static getListDisplayMode(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, 'listDisplayMode',
      ListDisplayMode.LIST_DISPLAY) as ListDisplayMode
  }

  static getSmartRotationState(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, "smartRotation", true) as boolean
  }

  static getLongPressSpeed(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, 'longPressSpeed', 3) as number
  }

  static getBackgroundDropBlur(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, 'backgroundDropBlur', 0) as number
  }

  static getShowSettingPageEntry(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, 'showSettingPageEntry', true) as boolean
  }

  static getBackgroundColorMode(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, 'backgroundColorMode',
      BackgroundColorMode.AUTO) as BackgroundColorMode
  }

  static getAllowGestureEntry(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, 'allowGestureEntry', true) as boolean
  }

  static getShowFrameTime(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, 'showFrameTime', true) as boolean
  }

  static getJumpToHistoryTime(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, 'jumpToHistoryTime', true) as boolean
  }

  static getCoverLayoutMode(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, 'coverLayoutMode',
      CoverLayoutMode.VERTICAL_PLATE) as CoverLayoutMode
  }

  static saveCoverLayoutMode(context: Context, coverLayoutMode: CoverLayoutMode) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'coverLayoutMode', coverLayoutMode)
  }

  static saveBackgroundColorMode(context: Context, backgroundColorMode: BackgroundColorMode) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'backgroundColorMode', backgroundColorMode)
  }

  static saveShowSettingPageEntry(context: Context, showSettingPageEntry: boolean) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'showSettingPageEntry', showSettingPageEntry)
  }

  static saveAllowGestureEntry(context: Context, allowGestureEntry: boolean) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'allowGestureEntry', allowGestureEntry)
  }

  static saveSkipIntroTime(context: Context, skipIntroTime: string) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'skipIntroTime', skipIntroTime)
  }

  static saveVideoSpeed(context: Context, video_speed: string) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'video_speed', video_speed)
  }

  static saveRepeatModeState(context: Context, repeatMode: SweetRepeatMode) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'repeatMode', repeatMode)
  }

  static saveDefaultPlayerEngine(context: Context, defaultPlayerEngine: string) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, "defaultPlayerEngine", defaultPlayerEngine)
  }

  static saveSubtitleSize(context: Context, subtitleSize: string) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, "subtitleSize", subtitleSize)
  }

  static saveFastForwardSeconds(context: Context, fastForwardSeconds: string) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, "fastForwardSeconds", fastForwardSeconds)
  }

  static saveAllowDoubleFastForwardState(context: Context, isEnabled: boolean) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, "allowDoubleFastForward", isEnabled)
  }

  static saveAllowPlayBackExistState(context: Context, isEnabled: boolean) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, "allowPlayBackExist", isEnabled)
  }

  static saveAllowBackgroundPlayState(context: Context, isEnabled: boolean) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, "allowBackgroundPlay", isEnabled)
  }

  static saveAutoActivePip(context: Context, isEnabled: boolean) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, "autoActivePip", isEnabled)
  }

  static getAutoActivePip(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, "autoActivePip", false) as boolean
  }

  static saveRecentPlayState(context: Context, isEnabled: boolean) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, "recentPlay", isEnabled)
  }

  static saveShowToast(context: Context, isEnabled: boolean) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, "showToast", isEnabled)
  }

  static savePassword(context: Context, password: string) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'passwd', password)
  }

  static saveOOBEVersion(context: Context, OOBEVersion: number) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, "OOBEVersion", OOBEVersion)
  }

  static saveSmartRotation(context: Context, smartRotationState: boolean) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, "smartRotation", smartRotationState)
  }

  static saveEnableBackgroundDarkImage(context: Context, enableBackgroundDarkImage: boolean) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'enableBackgroundDarkImage', enableBackgroundDarkImage)
  }

  static getEnableBackgroundDarkImage(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, 'enableBackgroundDarkImage', false) as boolean
  }

  static saveListDisplayMode(context: Context, listDisplayMode: ListDisplayMode) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'listDisplayMode', listDisplayMode)
  }

  static saveLongPressSpeed(context: Context, longPressSpeed: number) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'longPressSpeed', longPressSpeed)
  }

  static saveBackgroundDropBlur(context: Context, backgroundDropBlur: number) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'backgroundDropBlur', backgroundDropBlur)
  }

  static saveShowFrameTime(context: Context, showFrameTime: boolean) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'showFrameTime', showFrameTime)
  }

  static saveJumpToHistoryTime(context: Context, jumpToHistoryTime: boolean) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'jumpToHistoryTime', jumpToHistoryTime)
  }

  static saveSuperResolutionState(context: Context, superResolutionState: boolean) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'superResolutionState', superResolutionState)
  }

  static getSuperResolutionState(context: Context): boolean {
    return PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, 'superResolutionState', false) as boolean
  }

  // ========== 视频排序偏好 ==========
  // ORM 改造新增：排序类型与排序方向不再硬编码或依赖旧数据结构，
  // 而是保存到 Preferences 中，供 Repository 查询时动态拼接 ORDER BY 条件。
  // 区分普通模式与隐私空间模式，两者可独立设置排序偏好。
  private static readonly VIDEO_SORT_NORMAL_KEY = 'video_sort_normal'
  private static readonly VIDEO_SORT_PRIVACY_KEY = 'video_sort_privacy'
  private static readonly VIDEO_SORT_NORMAL_ORDER_KEY = 'video_sort_normal_order'
  private static readonly VIDEO_SORT_PRIVACY_ORDER_KEY = 'video_sort_privacy_order'

  static getVideoSortType(context: Context, isPrivacy: boolean = false): 'name' | 'datetime' | 'time' {
    const key = isPrivacy ? Preferences.VIDEO_SORT_PRIVACY_KEY : Preferences.VIDEO_SORT_NORMAL_KEY
    return PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, key, 'name') as 'name' | 'datetime' | 'time'
  }

  static saveVideoSortType(context: Context, sortType: 'name' | 'datetime' | 'time', isPrivacy: boolean = false): void {
    const key = isPrivacy ? Preferences.VIDEO_SORT_PRIVACY_KEY : Preferences.VIDEO_SORT_NORMAL_KEY
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, key, sortType)
  }

  static getVideoSortOrder(context: Context, isPrivacy: boolean = false): 'asc' | 'desc' {
    const key = isPrivacy ? Preferences.VIDEO_SORT_PRIVACY_ORDER_KEY : Preferences.VIDEO_SORT_NORMAL_ORDER_KEY
    return PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, key, 'desc') as 'asc' | 'desc'
  }

  static saveVideoSortOrder(context: Context, order: 'asc' | 'desc', isPrivacy: boolean = false): void {
    const key = isPrivacy ? Preferences.VIDEO_SORT_PRIVACY_ORDER_KEY : Preferences.VIDEO_SORT_NORMAL_ORDER_KEY
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, key, order)
  }
}