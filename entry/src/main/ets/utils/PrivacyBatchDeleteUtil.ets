import { fileIo } from '@kit.CoreFileKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { salmonLogger } from 'salmonlogger'
import Preferences from '../database/Preferences'
import { MediaBatchProgress, MediaBatchResult } from '../interfaces/MediaBatchInterface'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import { DeleteType } from '../common/enum/DeleteType'
import { ConcurrencyManagerUtil } from './FileProcessorUtil'
import MediaLibraryService from './MediaLibraryService'
import { PathUtils } from './PathUtils'
import PrivacyFolderUtil from './PrivacyFolderUtil'

export default class PrivacyBatchDeleteUtil {
  // 调用方持有 global_data 锁；一旦开始删除，取消请求也必须等待当前项完成提交。
  private static async deleteItemLocked(date: string): Promise<void> {
    if (!date || date === '.' || date === '..' || /[\\/\u0000]/.test(date)) {
      throw new Error('Invalid private media ID')
    }
    if (!PathUtils.appContext || !PathUtils.sandboxPath) throw new Error('Private sandbox is unavailable')
    const context = PathUtils.appContext!
    const latest = Preferences.getVideoMetaDataEncryption(context, true)
    const item = latest.find(video => video.date === date)
    const path = PathUtils.videoPath + date
    const deletedItem = item ? JSON.parse(JSON.stringify(item)) as VideoMetadata : { date, title: date, uri: path } as VideoMetadata
    // 仅操作该 ID 的沙箱文件，不跟随可能过期的原始导入 URI。
    deletedItem.uri = path
    try {
      await fileIo.unlink(path)
    } catch (error) {
      if ((error as BusinessError).code !== 13900002) throw new Error('Private file deletion failed')
    }
    // 封面、字幕、外挂音频、弹幕及播放记录必须完成清理，失败留下记录供重试。
    await MediaLibraryService.deleteVideoResource(deletedItem, DeleteType.SOFT, true)
    const current = Preferences.getVideoMetaDataEncryption(context, true)
    Preferences.saveVideoMetaDataEncryption(context, current.filter(video => video.date !== date), true)
  }

  private static async deleteLockedItems(items: VideoMetadata[], isCancelled: () => boolean,
    onProgress: (info: MediaBatchProgress) => void): Promise<MediaBatchResult> {
    const result: MediaBatchResult = { successDates: [], failedCount: 0, cancelled: false }
    const unique = new Map<string, VideoMetadata>()
    items.forEach(item => unique.set(item.date, item))
    let processed = 0
    onProgress({ processedItems: 0, totalItems: unique.size, currentFileName: '', failedCount: 0 })
    for (const item of unique.values()) {
      if (isCancelled()) break
      try {
        await PrivacyBatchDeleteUtil.deleteItemLocked(item.date)
        result.successDates.push(item.date)
      } catch (_) {
        result.failedCount++
        salmonLogger.addLog('PrivacyBatchDeleteUtil', '隐私目录内媒体删除未完成，保留记录供重试', true)
      }
      processed++
      onProgress({ processedItems: processed, totalItems: unique.size,
        currentFileName: item.title || '', failedCount: result.failedCount })
    }
    result.cancelled = isCancelled()
    return result
  }

  static async deleteFolder(date: string, isCancelled: () => boolean,
    onProgress: (info: MediaBatchProgress) => void): Promise<MediaBatchResult> {
    const lock = ConcurrencyManagerUtil.getLock('global_data')
    await lock.acquire()
    try {
      if (isCancelled()) return { successDates: [], failedCount: 0, cancelled: true }
      const context = PathUtils.appContext!
      const folders = Preferences.getPrivacyFolders(context)
      const plan = PrivacyFolderUtil.deletionPlan(folders, date)
      const latest = Preferences.getVideoMetaDataEncryption(context, true)
      const byDate = new Map<string, VideoMetadata>()
      latest.forEach(item => byDate.set(item.date, item))
      const items = plan.videoDates.map((videoDate): VideoMetadata => byDate.get(videoDate) ??
        { date: videoDate, title: videoDate, uri: PathUtils.videoPath + videoDate } as VideoMetadata)
      // 整个删除过程共用同一把锁，禁止导入、恢复或移动在中途改变目标目录范围。
      const result = await PrivacyBatchDeleteUtil.deleteLockedItems(items, isCancelled, onProgress)
      if (!result.cancelled && result.failedCount === 0) {
        Preferences.savePrivacyFolders(context, PrivacyFolderUtil.remove(folders, date))
      }
      return result
    } finally {
      lock.release()
    }
  }

  static async deleteItems(items: VideoMetadata[], isCancelled: () => boolean,
    onProgress: (info: MediaBatchProgress) => void): Promise<MediaBatchResult> {
    const result: MediaBatchResult = { successDates: [], failedCount: 0, cancelled: false }
    let processed = 0
    const dates = Array.from(new Set(items.map(item => item.date)))
    for (const date of dates) {
      if (isCancelled()) break
      const lock = ConcurrencyManagerUtil.getLock('global_data')
      await lock.acquire()
      try {
        if (isCancelled()) break
        await PrivacyBatchDeleteUtil.deleteItemLocked(date)
        result.successDates.push(date)
      } catch (_) {
        result.failedCount++
        salmonLogger.addLog('PrivacyBatchDeleteUtil', '批量删除失败，保留未成功移除的记录', true)
      } finally {
        lock.release()
      }
      processed++
      onProgress({ processedItems: processed, totalItems: dates.length,
        currentFileName: items.find(item => item.date === date)?.title || '', failedCount: result.failedCount })
    }
    result.cancelled = isCancelled()
    return result
  }
}
