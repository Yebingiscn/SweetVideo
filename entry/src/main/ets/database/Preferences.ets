import { FileFolder } from '../interfaces/FileFolderInterface'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'

import PreferencesUtil from './PreferencesUtil'
import { Context } from '@kit.AbilityKit'
import { SweetRepeatMode } from '../common/enum/SweetRepeatMode'
import { BackgroundColorMode } from '../common/enum/BackgroundColorMode'
import { CoverLayoutMode, ListDisplayMode } from '../common/enum/DisplayMode'
import { MpvDecodingMethod, MpvGpuApi } from '../controller/MpvController/MpvTypes'
import { IPTVSource } from '../interfaces/IPTVInterface'
import { fileIo as fs } from '@kit.CoreFileKit'
import { PathUtils } from '../utils/PathUtils'
import { salmonLogger } from 'salmonlogger'
import { util } from '@kit.ArkTS'
import { SubtitlePreferredLanguage } from '../common/enum/SubtitleLanguage'

const DATA_BASE_NAME = 'sweet_video'
const MAX_PREFERENCES_STRING_BYTES = 16 * 1024 * 1024

export default class Preferences {
  private static fileFolderCache: FileFolder[] | null = null
  private static videoDateToFolderDate: Map<string, string> | null = null
  private static videoUriSet: Set<string> | null = null

  static invalidateFileFolderCache() {
    Preferences.fileFolderCache = null
    Preferences.videoDateToFolderDate = null
    Preferences.videoUriSet = null
  }

  static findVideoByDate(context: Context, videoDate: string):
    [VideoMetadata | undefined, VideoMetadata[], string | undefined] {
    const folders = Preferences.getFileFolder(context)
    if (!Preferences.videoDateToFolderDate) {
      Preferences.buildVideoDateIndex(folders)
    }
    const folderDate = Preferences.videoDateToFolderDate!.get(videoDate)
    if (folderDate) {
      const folder = folders.find(f => f.date === folderDate)
      if (folder) {
        return [folder.video_list.find(v => v.date === videoDate), folder.video_list, folderDate]
      }
    }
    return [undefined, [], undefined]
  }

  static getVideoUriSet(context: Context): Set<string> {
    if (Preferences.videoUriSet !== null) {
      return Preferences.videoUriSet!
    }
    const folders = Preferences.getFileFolder(context)
    Preferences.buildVideoUriSet(folders)
    return Preferences.videoUriSet!
  }

  static saveMpvDecodingMethod(context: Context, decodingMethod: MpvDecodingMethod) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'mpv_decoding_method', decodingMethod)
  }

  static saveMpvGpuApi(context: Context, gpuApi: MpvGpuApi) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'mpv_gpu_api', gpuApi)
  }

  // 首页视频数据
  static getVideoMetaData(context: Context) {
    return Preferences.getFileFolder(context)[0]?.video_list ?? [] as VideoMetadata[]
  }

  // 隐私空间视频数据
  static getVideoMetaDataEncryption(context: Context) {
    const videos = PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, 'video_meta_data_encryption',
      []) as VideoMetadata[]
    videos.forEach(video => Preferences.normalizePlayableResolution(video))
    return videos
  }

  // 所有文件夹视频数据
  static getFileFolder(context: Context) {
    if (Preferences.fileFolderCache !== null) {

      return Preferences.fileFolderCache!
    }
    const folders = PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, 'file_folder', []) as FileFolder[]
    folders.forEach(f => {
      if (f.parent_date == undefined) {
        f.parent_date = null
      }
      f.video_list.forEach(video => Preferences.normalizePlayableResolution(video))
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
    // 读取持久化数据必须保持轻量：排序属于展示层，不能阻塞启动首帧。
    // 仍保持首页在首位，兼容依赖 folders[0] 的既有调用方。
    const homeFolder = folders.find(f => f.name === '首页' && f.parent_date === null)
    const result = homeFolder ? [homeFolder, ...folders.filter(f => f.date !== homeFolder.date)] : folders
    Preferences.fileFolderCache = result
    return result
  }

  // 最近播放视频数据
  static getRecentPlay(context: Context) {
    const videos = PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, 'recent_play', []) as VideoMetadata[]
    videos.forEach(video => Preferences.normalizePlayableResolution(video))
    return videos
  }

  static getPassword(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, 'passwd', '') as string
  }

  static getDefaultPlayerEngine(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, "defaultPlayerEngine", '系统播放器') as string
  }

  static getVideoSpeed(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, 'video_speed', '1x') as string
  }

  static getRepeatModeState(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, 'repeatMode',
      SweetRepeatMode.LIST) as SweetRepeatMode
  }

  static getBackgroundColorMode(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, 'backgroundColorMode',
      BackgroundColorMode.AUTO) as BackgroundColorMode
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

  static saveSkipOutroTime(context: Context, skipOutroTime: string) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'skipOutroTime', skipOutroTime)
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

  static saveShortVideoMode(context: Context, enabled: boolean) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'shortVideoMode', enabled)
  }

  static saveSubtitleSize(context: Context, subtitleSize: string) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, "subtitleSize", subtitleSize)
  }

  static saveSubtitlePosition(context: Context, value: number) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'subtitlePosition', value)
  }

  static saveSubtitlePreferredLanguage(context: Context, value: SubtitlePreferredLanguage) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'subtitlePreferredLanguage', value)
  }

  static saveSubtitleColor(context: Context, value: string) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'subtitleColor', value)
  }

  static saveSubtitleBold(context: Context, value: boolean) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'subtitleBold', value)
  }

  static saveSubtitleItalic(context: Context, value: boolean) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'subtitleItalic', value)
  }

  static saveSubtitleBorderSize(context: Context, value: number) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'subtitleBorderSize', value)
  }

  static saveSubtitleBorderColor(context: Context, value: string) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'subtitleBorderColor', value)
  }

  static saveSubtitleShadowEnabled(context: Context, value: boolean) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'subtitleShadowEnabled', value)
  }

  static saveSubtitleShadowSize(context: Context, value: number) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'subtitleShadowSize', value)
  }

  static saveSubtitleShadowColor(context: Context, value: string) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'subtitleShadowColor', value)
  }

  static saveSubtitleBackgroundOpacity(context: Context, value: number) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'subtitleBackgroundOpacity', value)
  }

  static saveFastForwardSeconds(context: Context, fastForwardSeconds: string) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, "fastForwardSeconds", fastForwardSeconds)
  }

  static saveSmartGestureEnabled(context: Context, enabled: boolean) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'smartGestureEnabled', enabled)
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

  static saveAllowConcurrentPlayState(context: Context, isEnabled: boolean) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, "allowConcurrentPlay", isEnabled)
  }

  static saveAutoActivePip(context: Context, isEnabled: boolean) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, "autoActivePip", isEnabled)
  }

  static saveAutoResumeOnReturn(context: Context, isEnabled: boolean) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, "autoResumeOnReturn", isEnabled)
  }

  static getAutoResumeOnReturn(context: Context) {
    return PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, "autoResumeOnReturn", false) as boolean
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
    const copied = Preferences.deepCopyFileFolders(file_folder)
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'file_folder', copied)
    Preferences.fileFolderCache = copied
    Preferences.buildVideoDateIndex(copied)
    Preferences.buildVideoUriSet(copied)
  }

  static saveRecentPlay(context: Context, recent_play_deque: VideoMetadata[]) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'recent_play', recent_play_deque)
  }

  static saveEnableBackgroundDarkImage(context: Context, enableBackgroundDarkImage: boolean) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'enableBackgroundDarkImage', enableBackgroundDarkImage)
  }

  static saveListItemBackgroundBlur(context: Context, listItemBackgroundBlur: boolean) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'listItemBackgroundBlur', listItemBackgroundBlur)
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

  static saveMpvShaderMode(context: Context, mpvShaderMode: number) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'mpvShaderMode', mpvShaderMode)
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

  static saveUserIsVip(context: Context, isVip: boolean) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'userIsVip', isVip)
  }

  static getUserIsVip(context: Context): boolean {
    return PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, 'userIsVip', false) as boolean
  }

  static saveDefaultBrightness(context: Context, defaultBrightness: number) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'defaultBrightness', defaultBrightness)
  }

  static saveDefaultDensityEnabled(context: Context, defaultDensityEnabled: boolean) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'defaultDensityEnabled', defaultDensityEnabled)
  }

  static getDefaultDensityEnabled(context: Context): boolean {
    return PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, 'defaultDensityEnabled', true) as boolean
  }

  static saveCollapsedFolderDates(context: Context, dates: string[]) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'collapsedFolderDates', dates)
  }

  static getCollapsedFolderDates(context: Context): string[] {
    return PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, 'collapsedFolderDates', []) as string[]
  }

  static saveEmbedSidebarVisible(context: Context, visible: boolean) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'embedSidebarVisible', visible)
  }

  static getEmbedSidebarVisible(context: Context): boolean {
    return PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, 'embedSidebarVisible', true) as boolean
  }

  static saveDefaultStartupFolder(context: Context, folderDate: string) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'defaultStartupFolder', folderDate)
  }

  static getDefaultStartupFolder(context: Context): string {
    return PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, 'defaultStartupFolder', '') as string
  }

  static saveMaxListLine(context: Context, maxListLine: number) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'maxListLine', maxListLine)
  }

  static getNetworkStreams(context: Context): VideoMetadata[] {
    return PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, 'network_streams', []) as VideoMetadata[]
  }

  static saveNetworkStreams(context: Context, streams: VideoMetadata[]) {
    PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'network_streams', streams)
  }

  static getIPTVSources(context: Context): IPTVSource[] {
    try {
      const path = Preferences.getIPTVCachePath()
      if (path && fs.accessSync(path)) {
        return JSON.parse(fs.readTextSync(path)) as IPTVSource[]
      }
      const value = PreferencesUtil.getPreferencesValue(context, DATA_BASE_NAME, 'iptv_sources', '[]') as string
      return JSON.parse(value) as IPTVSource[]
    } catch (error) {
      salmonLogger.addLog('Preferences', `read IPTV sources failed: ${String(error)}`, true)
      return []
    }
  }

  static saveIPTVSources(context: Context, sources: IPTVSource[]) {
    try {
      const path = Preferences.getIPTVCachePath()
      if (!path) {
        return
      }
      const tempPath = `${path}.tmp`
      const file = fs.openSync(tempPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC)
      fs.writeSync(file.fd, JSON.stringify(sources), { encoding: 'utf-8' })
      fs.closeSync(file)
      if (fs.accessSync(path)) {
        fs.unlinkSync(path)
      }
      fs.renameSync(tempPath, path)
      const summaries = sources.map(source => ({
        id: source.id,
        name: source.name,
        sourceType: source.sourceType,
        location: source.location,
        userAgent: source.userAgent,
        epgUrl: source.epgUrl,
        channels: [],
        channelCount: source.channelCount,
        groupCount: source.groupCount,
        createdTime: source.createdTime,
        updatedTime: source.updatedTime,
        lastRefreshTime: source.lastRefreshTime,
        lastEpgRefreshTime: source.lastEpgRefreshTime,
        lastRefreshStatus: source.lastRefreshStatus,
        lastError: source.lastError,
        epgMatchedCount: source.epgMatchedCount
      } as IPTVSource))
      const summaryText = JSON.stringify(summaries)
      const summaryBytes = new util.TextEncoder().encodeInto(summaryText).byteLength
      if (summaryBytes <= MAX_PREFERENCES_STRING_BYTES) {
        PreferencesUtil.putPreferencesValue(context, DATA_BASE_NAME, 'iptv_sources', summaryText)
      } else {
        PreferencesUtil.delPreferencesValue(context, DATA_BASE_NAME, 'iptv_sources')
      }
    } catch (error) {
      salmonLogger.addLog('Preferences', `save IPTV sources failed: ${String(error)}`, true)
    }
  }

  private static getIPTVCachePath(): string {
    return PathUtils.sandboxPath ? `${PathUtils.sandboxPath}/iptv_sources.json` : ''
  }

  private static deepCopyFileFolders(source: FileFolder[]): FileFolder[] {
    const result: FileFolder[] = []
    for (const folder of source) {
      const copiedVideos: VideoMetadata[] = []
      for (const v of folder.video_list) {
        const copiedVideo: VideoMetadata = {
          uri: v.uri,
          title: v.title,
          date: v.date,
          size: Preferences.resolvePlayableResolution(v),
          cover_size: v.cover_size ? v.cover_size.slice() : undefined,
          has_video_track: v.has_video_track,
          time: v.time,
          last_play: v.last_play,
          format: v.format,
          video_size: v.video_size,
          hdr_type: v.hdr_type,
          audio_type: v.audio_type,
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
        copiedVideos.push(copiedVideo)
      }
      const copiedFolder: FileFolder = {
        name: folder.name,
        date: folder.date,
        video_list: copiedVideos,
        parent_date: folder.parent_date
      }
      result.push(copiedFolder)
    }
    return result
  }

  private static resolvePlayableResolution(video: VideoMetadata): number[] {
    if (video.size && video.size.length >= 2 && video.size[0] > 0 && video.size[1] > 0) {
      return video.size.slice()
    }
    if (video.cover_size && video.cover_size.length >= 2 &&
      video.cover_size[0] > 0 && video.cover_size[1] > 0) {
      return video.cover_size.slice()
    }
    return [1, 1]
  }

  private static normalizePlayableResolution(video: VideoMetadata): void {
    video.size = Preferences.resolvePlayableResolution(video)
  }

  private static buildVideoDateIndex(folders: FileFolder[]) {
    const map = new Map<string, string>()
    for (const folder of folders) {
      for (const video of folder.video_list) {
        map.set(video.date, folder.date)
      }
    }
    Preferences.videoDateToFolderDate = map
  }

  private static buildVideoUriSet(folders: FileFolder[]) {
    const set = new Set<string>()
    for (const folder of folders) {
      for (const video of folder.video_list) {
        set.add(video.uri)
      }
    }
    Preferences.videoUriSet = set
  }
}
