import { Context } from '@kit.AbilityKit'
import { fileIo as fs, fileUri } from '@kit.CoreFileKit'
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
import { systemDateTime } from '@kit.BasicServicesKit'
import { ExternalAudioStorage } from './ExternalAudioStorage'
import { BusinessError } from '@kit.BasicServicesKit'
import { fileIo } from '@kit.CoreFileKit'
import { Subtitle3DMode } from '../common/enum/SubtitleMode'
import { DanmakuStorage } from './DanmakuStorage'
import DataSyncUtil from './DataSyncUtil'
import SubtitleUtil from './SubtitleUtil'
import { fileManagerService } from '@kit.FileManagerServiceKit'

const TAG = 'MediaLibraryService'

export default class MediaLibraryService {
  private static queryCache = new WeakMap<VideoMetadata[], Map<string, VideoMetadata>>()

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
    let save_time: number = 0
    if (target_data.time === 0 && options.totalTime) {
      target_data.time = options.totalTime
    }
    if (options.playTime) {
      const totalDuration = target_data?.time
      const endTime = VideoInfoUtil.getEndingPosition(target_data)
      const skipOutroMs = Number(Setting.skipOutroTime) * 1000
      let shouldMarkAsWatched = false
      if (totalDuration && options.playTime > totalDuration * 0.95) {
        shouldMarkAsWatched = true
        salmonLogger.addLog(TAG, '播放进度超过95%，标记为已观看', false)
      } else if (endTime > 0 && options.playTime >= endTime - 1000) {
        shouldMarkAsWatched = true
        salmonLogger.addLog(TAG, '播放至指定结束时间，标记为已观看', false)
      } else if (totalDuration && skipOutroMs > 0 && options.playTime >= totalDuration - skipOutroMs) {
        shouldMarkAsWatched = true
        salmonLogger.addLog(TAG, '播放至全局片尾跳过区域，标记为已观看', false)
      }
      save_time = shouldMarkAsWatched ? totalDuration : options.playTime
    }
    let lastPlayedAt: number | undefined = undefined
    if (options.playTime !== undefined && options.playTime > 0) {
      lastPlayedAt = systemDateTime.getTime(false)
      // 网络流等临时播放项可能不在本地文件夹数据库中，也要让最近播放记录拿到时间戳。
      target_data.last_played_at = lastPlayedAt
    }
    const audioChange = options.externalAudioFile !== undefined || options.externalAudioName !== undefined ||
      options.externalAudioSelected !== undefined || options.externalAudioOffsetMs !== undefined
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
      if (options.playTime) {
        video.last_play = save_time
      }
      if (lastPlayedAt !== undefined) {
        video.last_played_at = lastPlayedAt
      }
      if (options.startTime) {
        video.start_time = options.startTime
      }
      if (options.endTime) {
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
      if (options.pointA) {
        video.pointA = options.pointA
      }
      if (options.pointB) {
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
    }
    try {
      if (PrivacySpaceUtil.getPrivacyMode()) {
        salmonLogger.addLog(TAG, '当前处于隐私空间，更新隐私空间数据', false)
        const videoMetaDataEncryption = Preferences.getVideoMetaDataEncryption(context)
        const targetVideoMetaDataEncryption = videoMetaDataEncryption.find(v => v.date === target_data.date)
        if (targetVideoMetaDataEncryption) {
          updateVideo(targetVideoMetaDataEncryption)
          Preferences.saveVideoMetaDataEncryption(context, videoMetaDataEncryption, audioChange)
          salmonLogger.addLog(TAG, '隐私空间数据更新完成', false)
        } else {
          if (audioChange) throw new Error('Video metadata no longer exists')
          salmonLogger.addLog(TAG, '未在隐私空间中找到目标视频数据', true)
        }
        return
      }
      salmonLogger.addLog(TAG, '更新文件夹中的视频数据', false)
      const findResult = Preferences.findVideoByDate(context, target_data.date)
      const targetVideoMetaData = findResult[0]

      if (targetVideoMetaData) {
        updateVideo(targetVideoMetaData)
        const folders = Preferences.getFileFolder(context)
        Preferences.saveFileFolder(context, folders, audioChange)
      } else {
        // External and network playback also need an up-to-date recent-play position.
        updateVideo(target_data)
        MediaLibraryService.saveExternalRecentPlay(context, target_data)
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
      salmonLogger.addLog(TAG, '文件夹数据更新完成', false)
    } catch (_error) {
      for (let index = audioTargets.length - 1;index >= 0;index--) {
        const target = audioTargets[index]
        const previous = audioSnapshots[index]
        target.external_audio_file = previous.externalAudioFile
        target.external_audio_name = previous.externalAudioName
        target.external_audio_selected = previous.externalAudioSelected
        target.external_audio_offset_ms = previous.externalAudioOffsetMs
      }
      throw new Error('Video metadata could not be saved')
    }
  }

  // 网络串流不在文件夹里，把最近播放时间写回串流列表，供“按最近播放”排序和详情使用。
  private static saveExternalRecentPlay(context: Context, target_data: VideoMetadata) {
    const playedAt = target_data.last_played_at
    if (playedAt === undefined || playedAt <= 0) {
      return
    }
    try {
      const streams = Preferences.getNetworkStreams(context)
      const targetStream = streams.find(stream => stream.date === target_data.date)
      if (!targetStream || targetStream.last_played_at === playedAt) {
        return
      }
      targetStream.last_played_at = playedAt
      Preferences.saveNetworkStreams(context, streams)
    } catch (error) {
      salmonLogger.addLog(TAG, `保存串流最近播放时间失败: ${error}`, true)
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
    if (!MediaLibraryService.queryCache.has(list)) {
      MediaLibraryService.queryCache.set(list, new Map())
    }
    const listCache = MediaLibraryService.queryCache.get(list)!
    if (listCache.has(item)) {
      return listCache.get(item)
    }
    const dateMap = new Map(list.map(i => [i.date, i]))
    const foundItem = dateMap.get(item)
    if (foundItem) {
      const typedListCache: Map<string, VideoMetadata> = listCache
      typedListCache.set(item, foundItem)
      if (typedListCache.size > (list.length >= 100 ? 100 : list.length * 0.5)) {
        const iterator: IterableIterator<string> = typedListCache.keys()
        const oldestEntry: IteratorResult<string, undefined> = iterator.next()
        if (!oldestEntry.done) {
          const oldestKey: string = oldestEntry.value
          typedListCache.delete(oldestKey)
        }
      }
    }
    return foundItem
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
      const uriFileName = ToolsUtil.fileNameFromUri(item.uri).toLowerCase()
      const artist = item.artist?.toLowerCase() || ''
      const album = item.album?.toLowerCase() || ''
      return item.title.toLowerCase().includes(lowerValue) || artist.includes(lowerValue) ||
        album.includes(lowerValue) || uriFileName.includes(lowerValue)
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
  static async deleteCover(date: string): Promise<void> {
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
        } else {
          resolve() // 文件不存在也算删除成功
        }
      })
    })
  }

  static saveVideoTime(play_time: number, nowPlaying: VideoMetadata, context: Context) {
    MediaLibraryService.saveData(context, nowPlaying, { playTime: play_time })
    if (Setting.recentPlay && !PrivacySpaceUtil.getPrivacyMode() &&
      !MediaLibraryService.isPathFromSource(nowPlaying.uri, VideoSource.PRIVACY_SPACE)) {
      const result = Preferences.findVideoByDate(context, nowPlaying.date)
      RecentPlayUtil.addPlayback(context, result[0] ?? nowPlaying!)
    }
  }

  static saveVideoPlayTimeIfNeed(playTime: number, nowPlaying: VideoMetadata | undefined,
    skipHistory: boolean, context: Context): void {
    salmonLogger.addLog(TAG, `保存视频播放时间开始${playTime}, ${nowPlaying?.date}`, false)
    if (!nowPlaying || playTime <= 0 || skipHistory) {
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
    subtitle3DMode: Subtitle3DMode
  ): void {
    const appContext = PathUtils.appContext
    if (!nowPlaying || !appContext) {
      return
    }

    const subtitleMode = SubtitleUtil.normalizeSubtitleMode(subtitleSelected)
    const subtitleVisible = subtitleVisibility === Visibility.Visible
    const subtitleAIAsrShown = isAIAsrShown
    const subtitle3DModeValue = SubtitleUtil.normalizeSubtitle3DMode(subtitle3DMode)
    const subtitleOffsetMillis = Math.max(-50000, Math.min(50000, Math.round(SubtitleUtil.offsetMillis)))
    const subtitleTrackId = subtitleTrackSelected
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

  static async deleteVideoResource(item: VideoMetadata, deleteType: DeleteType): Promise<void> {
    if (!item.date) {
      return
    }
    RecentPlayUtil.delData(PathUtils.appContext!, item.uri)
    await ExternalAudioStorage.remove(item.date).catch((_error: Error) => {
      salmonLogger.addLog(TAG, '删除视频外挂音频失败', true)
    })
    await SubtitleUtil.deleteSubtitle(PathUtils.subtitlePath, item.date, true).catch((error: Error) => {
      salmonLogger.addLog(TAG, `删除视频字幕失败: ${error.message}`, true)
    })
    try {
      DanmakuStorage.remove(item.date)
    } catch (error) {
      salmonLogger.addLog(TAG, `删除视频弹幕失败: ${error}`, true)
    }
    await MediaLibraryService.deleteCover(item.date).catch((error: Error) => {
      salmonLogger.addLog(TAG, `删除视频封面失败: ${error.message}`, true)
    })
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
