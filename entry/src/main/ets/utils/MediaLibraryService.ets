import BluRayDirectory from './BluRayDirectory'
import { Context } from '@kit.AbilityKit'
import { fileIo, fileIo as fs, fileUri } from '@kit.CoreFileKit'
import VideoInfoUtil from './VideoInfoUtil'
import { SaveOptions, VideoMetadata } from '../interfaces/VideoMetadataInterface'
import { FileFolder } from '../interfaces/FileFolderInterface'
import ToolsUtil from './ToolsUtil'
import { DeleteType } from '../common/enum/DeleteType'
import { VideoSource } from '../common/enum/VideoSource'
import { salmonLogger } from 'salmonlogger'
import Preferences from '../database/Preferences'
import { Setting } from './ObservedUtil'
import { PathUtils } from './PathUtils'
import PrivacySpaceUtil from './PrivacySpaceUtil'
import RecentPlayUtil from './RecentPlayUtil'
import { BusinessError, systemDateTime } from '@kit.BasicServicesKit'
import { ExternalAudioStorage } from './ExternalAudioStorage'
import { Subtitle3DMode, SubtitleMode } from '../common/enum/SubtitleMode'
import { DanmakuStorage } from './DanmakuStorage'
import DataSyncUtil from './DataSyncUtil'
import SubtitleUtil from './SubtitleUtil'
import { fileManagerService } from '@kit.FileManagerServiceKit'

const TAG = 'MediaLibraryService'

interface MediaListIndex {
  length: number
  indices: Map<string, number>
}

export default class MediaLibraryService {
  private static queryCache: WeakMap<VideoMetadata[], MediaListIndex> = new WeakMap()

  public static videoSourcePath = new Map<number, string>([
    [VideoSource.SWEET_VIDEO_DOWNLOAD_FILE, '/storage/Users/currentUser/'],
    [VideoSource.DOCUMENT_SELECT_OPTION, 'file://docs/storage/Users'],
    [VideoSource.PHOTO_SELECT_OPTION, 'file://media/Photo'],
    [VideoSource.PRIVACY_SPACE, '/data/storage/el2'],
    [VideoSource.EXTERNAL_DEVICE, 'file://docs/storage/External']
  ])

  static saveData(context: Context, target_data: VideoMetadata, options: SaveOptions) {
    salmonLogger.addLog(TAG,
      `开始保存播放数据: playTime=${options.playTime}, totalTime=${options.totalTime}, target_time=${target_data.time}, last_play=${target_data.last_play}`,
      false)
    if (options.blurayTitleId !== undefined && (!BluRayDirectory.isEntry(target_data.uri) ||
      !Number.isInteger(options.blurayTitleId) || options.blurayTitleId < 0 || options.blurayTitleId > 99999)) {
      throw new Error('Invalid Blu-ray title')
    }
    let save_time: number = 0
    if (options.playTime !== undefined && (!Number.isFinite(options.playTime) || options.playTime < 0)) {
      salmonLogger.addLog(TAG, `拒绝无效播放进度: videoId=${target_data.date}`, true)
      return
    }
    if (options.playTime !== undefined) {
      const totalDuration = target_data.time || options.totalTime || 0
      const endTime = VideoInfoUtil.getEndingPosition(target_data)
      const skipOutroMs = Number(Setting.skipOutroTime) * 1000
      let shouldMarkAsWatched = false
      if (totalDuration && options.playTime > totalDuration * 0.95) {
        shouldMarkAsWatched = true
        salmonLogger.addLog(TAG, '播放进度超过95%，标记为已观看', false)
      } else if (options.playTime > 0 && endTime > 0 && options.playTime >= endTime - 1000) {
        shouldMarkAsWatched = true
        salmonLogger.addLog(TAG, '播放至指定结束时间，标记为已观看', false)
      } else if (options.playTime > 0 && totalDuration && skipOutroMs > 0 &&
        options.playTime >= totalDuration - skipOutroMs) {
        shouldMarkAsWatched = true
        salmonLogger.addLog(TAG, '播放至全局片尾跳过区域，标记为已观看', false)
      }
      save_time = shouldMarkAsWatched ? totalDuration : options.playTime
    }
    let lastPlayedAt: number | undefined = undefined
    if (options.playTime !== undefined && options.playTime > 0) {
      lastPlayedAt = systemDateTime.getTime(false)
    }
    const audioChange = options.externalAudioFile !== undefined || options.externalAudioName !== undefined ||
      options.externalAudioSelected !== undefined || options.externalAudioOffsetMs !== undefined
    const rangeChange = options.blurayTitleId !== undefined || options.pointA !== undefined || options.pointB !== undefined ||
      options.startTime !== undefined || options.endTime !== undefined
    const audioTargets: VideoMetadata[] = []
    const audioSnapshots: SaveOptions[] = []
    const updateVideo = (video: VideoMetadata) => {
      if (audioChange) {
        audioTargets.push(video)
        audioSnapshots.push({
          externalAudioFile: video.external_audio_file, externalAudioName: video.external_audio_name,
          externalAudioSelected: video.external_audio_selected, externalAudioOffsetMs: video.external_audio_offset_ms
        })
      }
      if (options.playTime !== undefined) {
        video.last_play = save_time
      }
      if (lastPlayedAt !== undefined) {
        video.last_played_at = lastPlayedAt
      }
      if (options.startTime !== undefined) {
        video.start_time = options.startTime
      }
      if (options.endTime !== undefined) {
        video.end_time = options.endTime
        video.end_time_is_duration = false
      }
      const hasFallbackVideoSize = VideoInfoUtil.hasVideoTrack(video) &&
        video.size[0] <= 1 && video.size[1] <= 1
      if (options.size?.[0] && (video.size[0] === 0 || hasFallbackVideoSize)) {
        video.size = options.size
      }
      if (options.totalTime && video.time === 0) {
        video.time = options.totalTime
      }
      if (options.pointA !== undefined) {
        video.pointA = options.pointA
      }
      if (options.pointB !== undefined) {
        video.pointB = options.pointB
      }
      if (options.subtitleMode !== undefined) {
        video.subtitle_mode = options.subtitleMode
      }
      if (options.subtitleVisible !== undefined) {
        video.subtitle_visible = options.subtitleVisible
      }
      if (options.subtitleAIAsrShown !== undefined) {
        video.subtitle_ai_asr_shown = options.subtitleAIAsrShown
      }
      if (options.externalSubtitleFormat !== undefined) {
        video.external_subtitle_format = options.externalSubtitleFormat
      }
      if (options.subtitle3DMode !== undefined) {
        video.subtitle_3d_mode = options.subtitle3DMode
      }
      if (options.subtitleOffsetMillis !== undefined) {
        video.subtitle_offset_millis = options.subtitleOffsetMillis
      }
      if (options.subtitleTrackId !== undefined) {
        video.subtitle_track_id = options.subtitleTrackId
      }
      if (options.audioTrackId !== undefined) {
        if (options.audioTrackId === null) {
          video.audio_track_id = undefined
        } else {
          video.audio_track_id = options.audioTrackId
        }
      }
      if (options.externalAudioFile !== undefined) video.external_audio_file = options.externalAudioFile
      if (options.externalAudioName !== undefined) video.external_audio_name = options.externalAudioName
      if (options.externalAudioSelected !== undefined) video.external_audio_selected = options.externalAudioSelected
      if (options.externalAudioOffsetMs !== undefined) video.external_audio_offset_ms = options.externalAudioOffsetMs
      if (options.hdrType !== undefined) {
        video.hdr_type = options.hdrType
      }
      if (options.audioType !== undefined) {
        video.audio_type = options.audioType
      }
      if (options.blurayTitleId !== undefined) {
        // A disc entry remains one library item, but each title has its own timeline/tracks.
        video.bluray_title_id = options.blurayTitleId
        video.last_play = 0
        video.time = 0
        video.start_time = 0
        video.end_time = 0
        video.end_time_is_duration = false
        video.pointA = 0
        video.pointB = 0
        video.audio_track_id = undefined
        video.subtitle_track_id = undefined
        video.size = [0, 0]
        video.hdr_type = 0
        video.audio_type = 0
      }
    }
    try {
      if (PrivacySpaceUtil.getPrivacyMode()) {
        salmonLogger.addLog(TAG, '当前处于隐私空间，更新隐私空间数据', false)
        const videoMetaDataEncryption = Preferences.getVideoMetaDataEncryption(context)
        const targetVideoMetaDataEncryption = videoMetaDataEncryption.find(v => v.date === target_data.date)
        if (targetVideoMetaDataEncryption) {
          const updatedVideo = Preferences.copyPlaybackMetadata(targetVideoMetaDataEncryption)
          updateVideo(updatedVideo)
          const updated = videoMetaDataEncryption.map(video => video.date === target_data.date ? updatedVideo : video)
          Preferences.saveVideoMetaDataEncryption(context, updated, true)
          updateVideo(target_data)
          salmonLogger.addLog(TAG, '隐私空间数据更新完成', false)
        } else {
          if (audioChange || rangeChange) throw new Error('Video metadata no longer exists')
          salmonLogger.addLog(TAG, '未在隐私空间中找到目标视频数据', true)
        }
        return
      }
      salmonLogger.addLog(TAG, '更新文件夹中的视频数据', false)
      const findResult = Preferences.findVideoByDate(context, target_data.date)
      const targetVideoMetaData = findResult[0]

      if (targetVideoMetaData) {
        Preferences.savePlaybackMetadata(context, target_data.date, true, updateVideo)
      } else {
        // External and network playback also need an up-to-date recent-play position.
        const updatedVideo = Preferences.copyPlaybackMetadata(target_data)
        updateVideo(updatedVideo)
        MediaLibraryService.saveExternalRecentPlay(context, updatedVideo, updateVideo)
      }
      if (audioChange) {
        const streams = Preferences.getNetworkStreams(context)
        const stream = streams.find((item: VideoMetadata) => item.date === target_data.date)
        if (stream) { updateVideo(stream); Preferences.saveNetworkStreams(context, streams, !targetVideoMetaData) }
        const recent = Preferences.getRecentPlay(context)
        const recentItem = recent.find((item: VideoMetadata) => item.date === target_data.date)
        if (recentItem) {
          try {
            updateVideo(recentItem)
            Preferences.saveRecentPlay(context, recent, !targetVideoMetaData && !stream)
          } catch (_error) {
            if (!targetVideoMetaData && !stream) throw new Error('Recent audio metadata could not be saved')
            salmonLogger.addLog(TAG, '更新最近播放中的外挂音频关联失败', true)
          }
        }
        if (!targetVideoMetaData && !stream && !recentItem) throw new Error('Video metadata no longer exists')
      }
      if (rangeChange) {
        try {
          // 最近播放可能是媒体唯一的持久记录；同时同步 AB 和片头片尾，避免从历史进入恢复旧区间。
          const recent = Preferences.getRecentPlay(context, true)
          const recentItem = recent.find((item: VideoMetadata) => item.date === target_data.date)
          if (recentItem) {
            const updatedItem = Preferences.copyPlaybackMetadata(recentItem)
            updateVideo(updatedItem)
            Preferences.saveRecentPlay(context,
              recent.map(item => item.date === target_data.date ? updatedItem : item), true)
          } else if (!targetVideoMetaData && Setting.recentPlay) {
            const updatedItem = Preferences.copyPlaybackMetadata(target_data)
            updateVideo(updatedItem)
            RecentPlayUtil.addPlayback(context, updatedItem, true)
          }
        } catch (error) {
          // The canonical title has already been committed. Do not keep playing the
          // old title and later save its position into the newly selected title.
          if (options.blurayTitleId === undefined || !targetVideoMetaData) throw new Error('Recent playback could not be saved')
          salmonLogger.addLog(TAG, '蓝光标题已保存，最近播放副本更新失败', true)
        }
      }
      // 播放页可能仍持有替换缓存前的对象，成功后同步它，不能依赖引用碰巧相同。
      updateVideo(target_data)
      salmonLogger.addLog(TAG, '文件夹数据更新完成', false)
      if (options.playTime !== undefined) {
        const canonicalPosition = Preferences.findVideoByDate(context, target_data.date)[0]?.last_play
        salmonLogger.addLog(TAG,
          `播放记录更新确认: videoId=${target_data.date}, positionMs=${save_time}, currentMs=${target_data.last_play}, canonicalMs=${canonicalPosition ?? 'external'}`,
          false)
      }
    } catch (_error) {
      for (let index = audioTargets.length - 1;index >= 0;index--) {
        const target = audioTargets[index]
        const previous = audioSnapshots[index]
        target.external_audio_file = previous.externalAudioFile
        target.external_audio_name = previous.externalAudioName
        target.external_audio_selected = previous.externalAudioSelected
        target.external_audio_offset_ms = previous.externalAudioOffsetMs
      }
      salmonLogger.addLog(TAG, `播放记录更新失败: videoId=${target_data.date}`, true)
      throw new Error('Video metadata could not be saved')
    }
  }

  // 网络串流不在文件夹里，按最新串流记录应用本次变更，避免旧播放对象覆盖其他字段。
  private static saveExternalRecentPlay(context: Context, target_data: VideoMetadata,
    update: (video: VideoMetadata) => void) {
    try {
      const streams = Preferences.getNetworkStreams(context)
      const targetStream = streams.find(stream => stream.date === target_data.date)
      if (!targetStream) {
        return
      }
      const savedStream = Preferences.copyPlaybackMetadata(targetStream)
      update(savedStream)
      const updated = streams.map(stream => stream.date === target_data.date ? savedStream : stream)
      Preferences.saveNetworkStreams(context, updated, true)
    } catch (error) {
      salmonLogger.addLog(TAG, '保存串流播放记录失败', true)
      throw new Error('Stream playback metadata could not be saved')
    }
  }

  static deleteVideo(videoMetaData: VideoMetadata) {
    MediaLibraryService.deleteVideoFromFolder(videoMetaData)
    MediaLibraryService.deleteVideoEncryption(videoMetaData)
    RecentPlayUtil.delData(PathUtils.appContext!, videoMetaData.uri)
  }

  static deleteVideoFromFolder(videoMetaData: VideoMetadata, currentFolder?: FileFolder) {
    const context = PathUtils.appContext!
    const folders = Preferences.getFileFolder(context)
    if (!folders || folders.length === 0) {
      return
    }
    const targetFolders = currentFolder
      ? folders.filter(f => f.date === currentFolder.date)
      : folders
    targetFolders.forEach(folder => {
      folder.video_list = folder.video_list.filter(video => video.date !== videoMetaData.date)
    })
    Preferences.saveFileFolder(context, folders)
  }

  static deleteVideoEncryption(videoMetaData: VideoMetadata) {
    //更新隐私空间的数据
    let videoMetaDataEncryption = Preferences.getVideoMetaDataEncryption(PathUtils.appContext!)
    videoMetaDataEncryption = videoMetaDataEncryption.filter(video => video.date !== videoMetaData.date)
    Preferences.saveVideoMetaDataEncryption(PathUtils.appContext!, videoMetaDataEncryption)
    fs.access(PathUtils.videoPath + videoMetaData.date).then((res: boolean) => {
      if (res) {
        fs.unlink(PathUtils.videoPath + videoMetaData.date, async (unlinkErr) => {
          if (unlinkErr) {
            ToolsUtil.showToast(ToolsUtil.getStringResourceArgs2($r('app.string.delete_video_failed_detail').id, videoMetaData.title, unlinkErr.message))
          }
          Preferences.saveVideoMetaDataEncryption(PathUtils.appContext!, videoMetaDataEncryption)
        })
      }
    })?.catch((err: BusinessError) => {
      salmonLogger.addLog(TAG, "access failed with error message: " + err.message + ", error code: " + err.code, true)
    })
  }

  static getItem(list: VideoMetadata[], item: string): VideoMetadata | undefined {
    if (!list || !item) {
      return undefined
    }
    let cached = MediaLibraryService.queryCache.get(list)
    if (!cached || cached.length !== list.length || cached.indices.size > list.length) {
      const indices = new Map<string, number>()
      for (let i = 0; i < list.length; i++) indices.set(list[i].date, i)
      cached = { length: list.length, indices: indices }
      MediaLibraryService.queryCache.set(list, cached)
      const index = indices.get(item)
      return index === undefined ? undefined : list[index]
    }
    const index = cached.indices.get(item)
    if (index !== undefined && list[index]?.date === item) return list[index]
    // 数组可能原地排序或替换条目；返回当前位置的对象，避免命中旧对象。
    for (let i = list.length - 1; i >= 0; i--) {
      if (list[i].date === item) {
        cached.indices.set(item, i)
        return list[i]
      }
    }
    cached.indices.delete(item)
    return undefined
  }

  // 按播放列表顺序取相邻项；音频、视频和探测信息不完整的文件都不能被隐式跳过。
  static getAdjacentItem(list: VideoMetadata[], date: string,
    direction: 'previous' | 'next', wrap: boolean): VideoMetadata | undefined {
    if (list.length === 0) {
      return undefined
    }
    const currentIndex = list.findIndex(i => i.date === date)
    if (currentIndex === -1) {
      return list[0]
    }
    const step = direction === 'next' ? 1 : -1
    const adjacentIndex = currentIndex + step
    if (!wrap && (adjacentIndex < 0 || adjacentIndex >= list.length)) {
      return undefined
    }
    return list[wrap ? (adjacentIndex + list.length) % list.length : adjacentIndex]
  }

  static getItemFromSearch(list: VideoMetadata[], value: string): VideoMetadata[] {
    const trimmedValue = value?.trim()
    if (!trimmedValue) {
      return []
    }
    const lowerValue = trimmedValue.toLowerCase()
    return list.filter(item => {
      if (item.title.toLowerCase().includes(lowerValue) || item.artist?.toLowerCase().includes(lowerValue) ||
        item.album?.toLowerCase().includes(lowerValue)) return true
      return ToolsUtil.fileNameFromUri(item.uri).toLowerCase().includes(lowerValue)
    })
  }

  static getItemIndex(list: VideoMetadata[], tmp: VideoMetadata) {
    return list.findIndex(i => i.date == tmp.date)
  }

  static async deletePrivacyVideo(date: string, title: string, video_meta_data_encryption: VideoMetadata[]) {
    const item = { uri: PathUtils.videoPath + date, date } as VideoMetadata
    await MediaLibraryService.deleteVideoResource(item, DeleteType.SOFT)
    Preferences.saveVideoMetaDataEncryption(PathUtils.appContext!, video_meta_data_encryption)
    try {
      await fs.unlink(PathUtils.videoPath + date)
      ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.delete_success').id))
    } catch (err) {
      const error = err as BusinessError
      if (error.code === 13900002) { // 文件或目录不存在错误码
        salmonLogger.addLog(TAG, 'file not exist', false)
      } else {
        salmonLogger.addLog(TAG, 'delete failed: ' + error.code + ':' + error.message, true)
      }
      ToolsUtil.showToast(ToolsUtil.getStringResourceArgs2($r('app.string.delete_video_failed_detail').id, title, String(err)))
    }
  }

  // 删除封面
  static async deleteCover(date: string, requireSuccess: boolean = false): Promise<void> {
    await new Promise<void>((resolve, reject) => {
      fs.access(PathUtils.coverPath + date, (err) => {
        if (!err) {
          fs.unlink(PathUtils.coverPath + date, (unlinkErr) => {
            if (unlinkErr) {
              if (unlinkErr.code == 13900002) {
                resolve()
              } else {
                reject(new Error(`删除封面失败: ${unlinkErr.message}`))
              }
            } else {
              resolve()
            }
          })
        } else if (!requireSuccess || err.code === 13900002) {
          resolve() // 文件不存在也算删除成功
        } else {
          reject(new Error('Cover access failed'))
        }
      })
    })
  }

  static saveVideoTime(play_time: number, nowPlaying: VideoMetadata, context: Context) {
    if (!Number.isFinite(play_time) || play_time < 0) return
    MediaLibraryService.saveData(context, nowPlaying, { playTime: play_time })
    if (Setting.recentPlay && !PrivacySpaceUtil.getPrivacyMode() &&
      !MediaLibraryService.isPathFromSource(nowPlaying.uri, VideoSource.PRIVACY_SPACE)) {
      const result = Preferences.findVideoByDate(context, nowPlaying.date)
      try {
        RecentPlayUtil.addPlayback(context, Preferences.copyPlaybackMetadata(result[0] ?? nowPlaying!), true)
      } catch (_error) {
        salmonLogger.addLog(TAG, `最近播放记录更新失败: videoId=${nowPlaying.date}`, true)
        throw new Error('Playback history could not be saved')
      }
    }
  }

  static saveVideoPlayTimeIfNeed(playTime: number, nowPlaying: VideoMetadata | undefined,
    skipHistory: boolean, context: Context): void {
    salmonLogger.addLog(TAG, `保存视频播放时间开始${playTime}, ${nowPlaying?.date}`, false)
    if (!nowPlaying || !Number.isFinite(playTime) || playTime < 0 || skipHistory) {
      return
    }
    MediaLibraryService.saveVideoTime(playTime, nowPlaying, context)
    salmonLogger.addLog(TAG, `保存视频播放时间完成`, false)
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

  static saveSubtitlePreference(
    nowPlaying: VideoMetadata | undefined,
    subtitleSelected: number,
    subtitleTrackSelected: number,
    subtitleVisibility: Visibility,
    isAIAsrShown: boolean,
    subtitle3DMode: Subtitle3DMode,
    selectionChanged?: boolean
  ): void {
    const appContext = PathUtils.appContext
    if (!nowPlaying || !appContext || selectionChanged === undefined) {
      return
    }
    if (selectionChanged && subtitleSelected === SubtitleMode.INNER_SUBTITLE && subtitleTrackSelected < 0) {
      return // An unavailable inner track is not a successful user selection.
    }

    // Only explicit UI changes are persisted. Exit/switch and failed detection
    // must not turn a temporary fallback into a remembered off / missing track.
    // Style/offset edits also must not manufacture a selection from auto mode.
    const subtitleMode = selectionChanged ? SubtitleUtil.normalizeSubtitleMode(subtitleSelected) : nowPlaying.subtitle_mode
    const subtitleVisible = selectionChanged ? subtitleVisibility === Visibility.Visible : nowPlaying.subtitle_visible
    const subtitleAIAsrShown = selectionChanged ? isAIAsrShown : nowPlaying.subtitle_ai_asr_shown
    const subtitle3DModeValue = SubtitleUtil.normalizeSubtitle3DMode(subtitle3DMode)
    const subtitleOffsetMillis = Math.max(-50000, Math.min(50000, Math.round(SubtitleUtil.offsetMillis)))
    const subtitleTrackId = selectionChanged ? subtitleTrackSelected : nowPlaying.subtitle_track_id
    const hasPreferenceChanged =
      nowPlaying.subtitle_mode !== subtitleMode ||
      nowPlaying.subtitle_visible !== subtitleVisible ||
      nowPlaying.subtitle_ai_asr_shown !== subtitleAIAsrShown ||
      nowPlaying.subtitle_3d_mode !== subtitle3DModeValue ||
      nowPlaying.subtitle_offset_millis !== subtitleOffsetMillis ||
      nowPlaying.subtitle_track_id !== subtitleTrackId

    if (!hasPreferenceChanged) {
      return
    }

    nowPlaying.subtitle_mode = subtitleMode
    nowPlaying.subtitle_visible = subtitleVisible
    nowPlaying.subtitle_ai_asr_shown = subtitleAIAsrShown
    nowPlaying.subtitle_3d_mode = subtitle3DModeValue
    nowPlaying.subtitle_offset_millis = subtitleOffsetMillis
    nowPlaying.subtitle_track_id = subtitleTrackId

    MediaLibraryService.saveData(appContext, nowPlaying, {
      subtitleMode,
      subtitleVisible,
      subtitleAIAsrShown,
      subtitle3DMode: subtitle3DModeValue,
      subtitleOffsetMillis,
      subtitleTrackId
    })
  }

  static saveAudioTrackPreference(
    nowPlaying: VideoMetadata | undefined,
    audioTrackSelected: number,
    audioTrackCount: number
  ): void {
    const appContext = PathUtils.appContext
    if (!nowPlaying || !appContext) {
      return
    }
    if (audioTrackCount <= 1) {
      return
    }
    if (audioTrackSelected === 0) {
      if (nowPlaying.audio_track_id !== undefined) {
        nowPlaying.audio_track_id = undefined
        MediaLibraryService.saveData(appContext, nowPlaying, { audioTrackId: null })
      }
      return
    }
    const audioTrackId = audioTrackSelected
    if (nowPlaying.audio_track_id === audioTrackId) {
      return
    }
    nowPlaying.audio_track_id = audioTrackId
    MediaLibraryService.saveData(appContext, nowPlaying, { audioTrackId })
  }

  static async deleteVideoResource(item: VideoMetadata, deleteType: DeleteType,
    requireSuccess: boolean = false): Promise<void> {
    if (!item.date) {
      return
    }
    let cleanupFailed = false
    try {
      RecentPlayUtil.delData(PathUtils.appContext!, item.uri, requireSuccess)
    } catch (_) {
      cleanupFailed = true
      salmonLogger.addLog(TAG, '删除播放记录失败', true)
    }
    await ExternalAudioStorage.remove(item.date).catch((_error: Error) => {
      cleanupFailed = true
      salmonLogger.addLog(TAG, '删除视频外挂音频失败', true)
    })
    await SubtitleUtil.deleteSubtitle(PathUtils.subtitlePath, item.date, true).catch((error: Error) => {
      cleanupFailed = true
      salmonLogger.addLog(TAG, `删除视频字幕失败: ${error.message}`, true)
    })
    try {
      await DanmakuStorage.remove(item.date)
    } catch (error) {
      cleanupFailed = true
      salmonLogger.addLog(TAG, `删除视频弹幕失败: ${error}`, true)
    }
    await MediaLibraryService.deleteCover(item.date, requireSuccess).catch((error: Error) => {
      cleanupFailed = true
      salmonLogger.addLog(TAG, `删除视频封面失败: ${error.message}`, true)
    })
    if (requireSuccess && cleanupFailed) throw new Error('Video resource cleanup incomplete')
    // Removing an index alone would corrupt a multi-file disc; only remove its library entry.
    if (BluRayDirectory.isEntry(item.uri) && deleteType !== DeleteType.SOFT) {
      ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.bluray_source_preserved').id))
      return
    }
    if (deleteType === DeleteType.HARD) {
      try {
        await fileIo.unlink(item.uri)
        salmonLogger.addLog(TAG, 'remove file succeed: ' + item.uri)
      } catch (err) {
        salmonLogger.addLog(TAG, 'remove file failed: ' + (err as Error).message, true)
      }
    } else if (deleteType === DeleteType.RECENT) {
      if (canIUse('SystemCapability.FileManagement.FileManagerService.Core')) {
        try {
          await fileManagerService.deleteToTrash(fileUri.getUriFromPath(item.uri))
        } catch (error) {
          salmonLogger.addLog(TAG, "test delete failed, errCode:" + error.code + ", errMessage:" + error.message, true)
          ToolsUtil.showToast(ToolsUtil.getStringResourceArgs2($r('app.string.move_to_recycle_failed').id, error.code, error.message))
        }
      }
    }
  }

  static async deleteVideoFiles(items: VideoMetadata[], deleteType: DeleteType): Promise<void> {
    for (const item of items) {
      try {
        await MediaLibraryService.deleteVideoResource(item, deleteType)
      } catch (error) {
        salmonLogger.addLog('BatchDelete', 'delete video failed: ' + (error as Error).message, true)
      }
    }
  }

  static isPathFromSource(path: string | undefined, key: VideoSource) {
    const prefix = MediaLibraryService.videoSourcePath.get(key)
    if (!path || !prefix) {
      return false
    }
    // 标准化路径比较
    const normalizedPath = path.replace(/\\/g, '/')
    const normalizedPrefix = prefix.replace(/\\/g, '/')
    return normalizedPath.startsWith(normalizedPrefix)
  }
}
