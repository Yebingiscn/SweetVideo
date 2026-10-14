import { fileIo } from '@kit.CoreFileKit'
import { salmonLogger } from 'salmonlogger'
import Preferences from '../database/Preferences'
import { ConcurrencyManagerUtil } from './FileProcessorUtil'
import FFmpegThumbnailUtil from './FFmpegThumbnailUtil'
import MediaExportUtil from './MediaExportUtil'
import { PathUtils } from './PathUtils'
import TextEncodingUtil from './TextEncodingUtil'
import VideoInfoUtil from './VideoInfoUtil'

export type PrivacyRecoveryResult = 'recovered' | 'skipped' | 'failed' | 'cancelled'

// 异常文件仍在沙箱，仅重建丢失的记录。保留内部 ID，不移动、复制或删除源文件。
export default class PrivacyRecoveryUtil {
  static async recover(date: string, isCancelled: () => boolean): Promise<PrivacyRecoveryResult> {
    try {
      if (isCancelled()) return 'cancelled'
      if (!date || date === '.' || date === '..' || /[\\/\u0000]/.test(date)) return 'failed'
      const context = PathUtils.appContext!
      if (Preferences.getVideoMetaDataEncryption(context, true).some(item => item.date === date)) return 'skipped'
      const path = PathUtils.videoPath + date
      const stat = await fileIo.lstat(path)
      if (isCancelled()) return 'cancelled'
      if (!stat.isFile() || stat.size <= 0) return 'failed'
      const result = await FFmpegThumbnailUtil.probeUri(path)
      if (isCancelled()) return 'cancelled'
      const probe = result.probe
      if (!result.success || !probe ||
        (!VideoInfoUtil.probeHasVideoTrack(probe) && probe.audioStreamCount <= 0)) return 'failed'
      const extension = await MediaExportUtil.detectExtension(path, probe)
      if (isCancelled()) return 'cancelled'
      const metadata = VideoInfoUtil.buildVideoMetadata(date, path,
        MediaExportUtil.buildFileName(date, extension), PathUtils.videoPath, stat.size, probe)
      metadata.uri = path
      const embeddedTitle = probe.title.trim()
      if (TextEncodingUtil.isUsable(embeddedTitle)) metadata.title = embeddedTitle

      // 与导入共用锁。探测后重新读取全量记录，不覆盖扫描期间新增的媒体，也不重复恢复。
      const lock = ConcurrencyManagerUtil.getLock('global_data')
      await lock.acquire()
      try {
        if (isCancelled()) return 'cancelled'
        const latest = Preferences.getVideoMetaDataEncryption(context, true)
        if (latest.some(item => item.date === date)) return 'skipped'
        const currentStat = await fileIo.lstat(path)
        if (isCancelled()) return 'cancelled'
        if (!currentStat.isFile() || currentStat.size !== stat.size) return 'failed'
        Preferences.saveVideoMetaDataEncryption(context, [...latest, metadata], true)
      } finally {
        lock.release()
      }

      // 元数据保存成功才算恢复；封面失败不回退记录，也不覆盖已有封面。
      if (!isCancelled()) {
        try {
          if (!fileIo.accessSync(PathUtils.coverPath + date)) {
            await VideoInfoUtil.saveCoverDeferred(path, PathUtils.coverPath, date, probe.durationMs, undefined)
          }
        } catch (_) {
          salmonLogger.addLog('PrivacyRecoveryUtil', '恢复记录成功，补充封面失败', true)
        }
      }
      return 'recovered'
    } catch (_) {
      salmonLogger.addLog('PrivacyRecoveryUtil', '异常媒体恢复失败，保留原文件', true)
      return isCancelled() ? 'cancelled' : 'failed'
    }
  }
}
