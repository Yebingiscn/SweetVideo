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

export default class PrivacyBatchDeleteUtil {
  static async deleteItems(items: VideoMetadata[], isCancelled: () => boolean,
    onProgress: (info: MediaBatchProgress) => void): Promise<MediaBatchResult> {
    const result: MediaBatchResult = { successDates: [], failedCount: 0, cancelled: false }
    let processed = 0
    const dates = Array.from(new Set(items.map(item => item.date)))
    for (const date of dates) {
      if (isCancelled()) break
      let deletedItem: VideoMetadata | undefined
      const lock = ConcurrencyManagerUtil.getLock('global_data')
      await lock.acquire()
      try {
        if (isCancelled()) break
        if (!date || date === '.' || date === '..' || /[\\/\u0000]/.test(date)) {
          throw new Error('Invalid private media ID')
        }
        const latest = Preferences.getVideoMetaDataEncryption(PathUtils.appContext!, true)
        const item = latest.find(video => video.date === date)
        if (item) {
          // 只删除沙箱中该 ID 对应的文件，绝不使用可能过期的原始导入 URI。
          const path = PathUtils.videoPath + date
          try {
            await fileIo.unlink(path)
          } catch (error) {
            if ((error as BusinessError).code !== 13900002) throw new Error('Private file deletion failed')
          }
          // 删除开始后即使取消，也完成当前记录提交；持锁读取全量记录，不覆盖并发导入。
          const current = Preferences.getVideoMetaDataEncryption(PathUtils.appContext!, true)
          Preferences.saveVideoMetaDataEncryption(PathUtils.appContext!,
            current.filter(video => video.date !== date), true)
          deletedItem = JSON.parse(JSON.stringify(item)) as VideoMetadata
          deletedItem.uri = path
        }
        result.successDates.push(date)
      } catch (_) {
        result.failedCount++
        salmonLogger.addLog('PrivacyBatchDeleteUtil', '批量删除失败，保留未成功移除的记录', true)
      } finally {
        lock.release()
      }
      if (deletedItem) {
        // 复用封面、字幕、外挂音频和播放历史清理，不再重复删除视频文件。
        try {
          await MediaLibraryService.deleteVideoResource(deletedItem, DeleteType.SOFT)
        } catch (_) {
          salmonLogger.addLog('PrivacyBatchDeleteUtil', '视频已删除，关联资源清理失败', true)
        }
      }
      processed++
      onProgress({ processedItems: processed, totalItems: dates.length,
        currentFileName: items.find(item => item.date === date)?.title || '', failedCount: result.failedCount })
    }
    result.cancelled = isCancelled()
    return result
  }
}
