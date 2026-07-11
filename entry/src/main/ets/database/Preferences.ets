import { FileFolder } from '../interfaces/FileFolderInterface'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import PreferencesUtil from './PreferencesUtil'
import { Context } from '@kit.AbilityKit'
import { SweetRepeatMode } from '../common/enum/SweetRepeatMode'
import { BackgroundColorMode } from '../common/enum/BackgroundColorMode'
import { CoverLayoutMode, ListDisplayMode } from '../common/enum/DisplayMode'
import { MpvDecodingMethod } from '../controller/MpvController/MpvTypes'
import { SortField } from '../common/enum/SortField'
import ToolsUtil from '../utils/ToolsUtil'

const DATA_BASE_NAME = 'sweet_video'

// 存储类
export default class Preferences {
  private static fileFolderCache: FileFolder[] | null = null
  private static videoDateToFolderDate: Map<string, string> | null = null
  private static cacheDirty: boolean = false

  private static deepCopyFileFolders(source: FileFolder[]): FileFolder[] {
    const result: FileFolder[] = []
    for (const f of source) {
      const videos: VideoMetadata[] = []
      for (const v of f.video_list) {
        const copy: VideoMetadata = {
          uri: v.uri,
          title: v.title,
          date: v.date,
          size: v.size,
          time: v.time,
          last_play: v.last_play,
          format: v.format,
          video_size: v.video_size,
          hdr_type: v.hdr_type,
          frame_rate: v.frame_rate,
          start_time: v.start_time,
          end_time: v.end_time,
          external_subtitle_format: v.external_subtitle_format,
          pointA: v.pointA,
          pointB: v.pointB,
          subtitle_mode: v.subtitle_mode,
          subtitle_visible: v.subtitle_visible,
          subtitle_ai_asr_shown: v.subtitle_ai_asr_shown,
          subtitle_3d_mode: v.subtitle_3d_mode,
          subtitle_offset_millis: v.subtitle_offset_millis,
          subtitle_track_id: v.subtitle_track_id,
          audio_track_id: v.audio_track_id
        }
        videos.push(copy)
      }
      const folder: FileFolder = {
        name: f.name,
        date: f.date,
        video_list: videos,
        parent_date: f.parent_date
      }
      result.push(folder)
    }
    return result
  }

  static invalidateFileFolderCache() {
    Preferences.fileFolderCache = null
    Preferences.videoDateToFolderDate = null
    Preferences.cacheDirty = false
  }

  static findVideoByDate(context: Context, videoDate: string):
    [VideoMetadata | undefined, VideoMetadata[], string | undefined] {
    const folders = Preferences.getFileFolder(context)
    if (!Preferences.videoDateToFolderDate) {
      const map = new Map<string, string>()
      for (const folder of folders) {
        for (const video of folder.video_list) {
          map.set(video.date, folder.date)
        }
      }
      Preferences.videoDateToFolderDate = map
    }
    const folderDate = Preferences.videoDateToFolderDate.get(videoDate)
    if (folderDate) {
      const folder = folders.find(f => f.date === folderDate)
      if (folder) {
        return [folder.video_list.find(v => v.date === videoDate), folder.video_list, folderDate]
      }
    }
    return [undefined, [], undefined]
  }

  static saveMpvDecodingMethod(context: Context, decodingMethod: MpvDecodingMethod) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'mpv_decoding_method', decodingMethod)
  }

  static getMpvDecodingMethod(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, 'mpv_decoding_method',
      MpvDecodingMethod.HARDWARE_SURFACE) as MpvDecodingMethod
  }

  // 首页视频数据
  static getVideoMetaData(context: Context) {
    return Preferences.getFileFolder(context)[0]?.video_list ?? [] as VideoMetadata[]
  }

  // 隐私空间视频数据
  static getVideoMetaDataEncryption(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, 'video_meta_data_encryption',
      []) as VideoMetadata[]
  }

  // 所有文件夹视频数据
  static getFileFolder(context: Context) {
    if (Preferences.fileFolderCache !== null) {
      if (Preferences.cacheDirty) {
        Preferences.fileFolderCache = Preferences.deepCopyFileFolders(Preferences.fileFolderCache!)
        Preferences.cacheDirty = false
      }
      return Preferences.fileFolderCache!
    }
    const folders = PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, 'file_folder', []) as FileFolder[]
    folders.forEach(f => {
      if (f.parent_date == undefined) {
        f.parent_date = null
      }
    })
    const allDates = new Set(folders.map(f => f.date))
    const orphanIndices: number[] = []
    folders.forEach((f, index) => {
      if (f.parent_date != null && !allDates.has(f.parent_date)) {
        orphanIndices.push(index)
      }
    })
    if (orphanIndices.length > 0) {
      for (let i = orphanIndices.length - 1; i >= 0; i--) {
        folders.splice(orphanIndices[i], 1)
      }
      PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'file_folder', folders)
    }
    const folderSortField = Preferences.getFolderSortField(context) as SortField
    const folderSortAsc = Preferences.getFolderSortAsc(context)
    const folderPinyinSort = Preferences.getPinyinSort(context)
    const homeFolder = folders.find(f => f.name === '首页' && f.parent_date === null)
    let otherFolders = folders.filter(f => f.name !== '首页')
    switch (folderSortField) {
      case SortField.FOLDER_NAME:
        otherFolders = ToolsUtil.sortFolderByNameProcess(otherFolders, folderSortAsc, folderPinyinSort)
        break
      case SortField.FOLDER_DATETIME:
        otherFolders.sort((a, b) => {
          const cmp = Number(a.date) - Number(b.date)
          return folderSortAsc ? cmp : -cmp
        })
        break
      case SortField.FOLDER_COUNT:
        otherFolders.sort((a, b) => {
          const cmp = a.video_list.length - b.video_list.length
          return folderSortAsc ? cmp : -cmp
        })
        break
      default:
        otherFolders.sort((a, b) => Number(a.date) - Number(b.date))
    }
    const result = homeFolder ? [homeFolder, ...otherFolders] : otherFolders
    Preferences.fileFolderCache = result
    return result
  }

  // 最近播放视频数据
  static getRecentPlay(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, 'recent_play', []) as VideoMetadata[]
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
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'video_meta_data_encryption',
      video_meta_data_encryption)
  }

  // 保存所有文件夹视频数据
  static saveFileFolder(context: Context, file_folder: FileFolder[]) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'file_folder', file_folder)
    Preferences.fileFolderCache = file_folder
    Preferences.videoDateToFolderDate = null
    Preferences.cacheDirty = true
  }

  static saveRecentPlay(context: Context, recent_play_deque: VideoMetadata[]) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'recent_play', recent_play_deque)
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

  static saveMpvShaderMode(context: Context, mpvShaderMode: number) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'mpvShaderMode', mpvShaderMode)
  }

  static getMpvShaderMode(context: Context): number {
    return PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, 'mpvShaderMode', 0) as number
  }

  static getSortField(context: Context): string {
    return PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, 'sortField', '') as string
  }

  static saveSortField(context: Context, sortField: string) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'sortField', sortField)
  }

  static getSortAsc(context: Context): boolean {
    return PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, 'sortAsc', true) as boolean
  }

  static saveSortAsc(context: Context, sortAsc: boolean) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'sortAsc', sortAsc)
  }

  static getFolderSortField(context: Context): string {
    return PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, 'folderSortField', '') as string
  }

  static saveFolderSortField(context: Context, sortField: string) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'folderSortField', sortField)
    Preferences.invalidateFileFolderCache()
  }

  static getFolderSortAsc(context: Context): boolean {
    return PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, 'folderSortAsc', true) as boolean
  }

  static saveFolderSortAsc(context: Context, sortAsc: boolean) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'folderSortAsc', sortAsc)
    Preferences.invalidateFileFolderCache()
  }

  static getPinyinSort(context: Context): boolean {
    return PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, 'pinyinSort', true) as boolean
  }

  static savePinyinSort(context: Context, pinyinSort: boolean) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'pinyinSort', pinyinSort)
    Preferences.invalidateFileFolderCache()
  }

  static getUserIsLogin(context: Context): boolean {
    return PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, 'userIsLogin', false) as boolean
  }

  static saveUserIsLogin(context: Context, isLogin: boolean) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'userIsLogin', isLogin)
  }

  static getUserAvatar(context: Context): string {
    return PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, 'userAvatar', '') as string
  }

  static saveUserAvatar(context: Context, userAvatar: string) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'userAvatar', userAvatar)
  }

  static getUserNickName(context: Context): string {
    return PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, 'userNickName', '') as string
  }

  static saveUserNickName(context: Context, nickName: string) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'userNickName', nickName)
  }

  static getUserAuthorizationCode(context: Context): string {
    return PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, 'userAuthorizationCode', '') as string
  }

  static saveUserAuthorizationCode(context: Context, authorizationCode: string) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'userAuthorizationCode', authorizationCode)
  }

  static getUserUnionID(context: Context): string {
    return PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, 'userUnionID', '') as string
  }

  static saveUserUnionID(context: Context, unionID: string) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'userUnionID', unionID)
  }

  static getUserOpenID(context: Context): string {
    return PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, 'userOpenID', '') as string
  }

  static saveUserOpenID(context: Context, openID: string) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'userOpenID', openID)
  }

  static getUserIdToken(context: Context): string {
    return PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, 'userIdToken', '') as string
  }

  static saveUserIdToken(context: Context, idToken: string) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'userIdToken', idToken)
  }

  static saveScreenExtend(context: Context, screenExtend: string) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'screenExtend', screenExtend)
  }

  static getScreenExtend(context: Context): string {
    return PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, 'screenExtend', '原始比例') as string
  }

  static saveEnableAiPrivacyAntiPeep(context: Context, enableAiPrivacyAntiPeep: boolean) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'enableAiPrivacyAntiPeep', enableAiPrivacyAntiPeep)
  }

  static getEnableAiPrivacyAntiPeep(context: Context): boolean {
    return PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, 'enableAiPrivacyAntiPeep', false) as boolean
  }

  static saveUserIsVip(context: Context, isVip: boolean) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'userIsVip', isVip)
  }

  static getUserIsVip(context: Context): boolean {
    return PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, 'userIsVip', false) as boolean
  }

  static saveDefaultBrightness(context: Context, defaultBrightness: number) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'defaultBrightness', defaultBrightness)
  }

  static getDefaultBrightness(context: Context): number {
    return PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, 'defaultBrightness', 0) as number
  }


  static saveDefaultDensityEnabled(context: Context, defaultDensityEnabled: boolean) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'defaultDensityEnabled', defaultDensityEnabled)
  }

  static getDefaultDensityEnabled(context: Context): boolean {
    return PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, 'defaultDensityEnabled', true) as boolean
  }
}