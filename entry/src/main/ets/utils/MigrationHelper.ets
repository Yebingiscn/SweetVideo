import { Context } from '@kit.AbilityKit'
import { getORM } from '@ibestservices/ibest-orm'
import { relationalStore } from '@kit.ArkData'
import { FolderEntity } from '../entity/FolderEntity'
import { VideoEntity } from '../entity/VideoEntity'
import { RecentPlayEntity } from '../entity/RecentPlayEntity'
import { PrivacyVideoEntity } from '../entity/PrivacyVideoEntity'
import PreferencesUtil from '../database/PreferencesUtil'
import { VideoRepository } from '../repository/VideoRepository'
import { FolderRepository } from '../repository/FolderRepository'
import { RecentPlayRepository } from '../repository/RecentPlayRepository'
import { PrivacyVideoRepository } from '../repository/PrivacyVideoRepository'
import { FileFolder } from '../interfaces/FileFolderInterface'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import PrivacySpaceUtil from './PrivacySpaceUtil'

const DATABASE_NAME = 'sweet_video'
// 旧版本所有数据（包括隐私视频）都存储在 sweet_video 中
const PRIVACY_DB_NAME = 'sweet_video'

interface MigrationResult {
  migrated: number
  skipped: number
}

class MigrationSummary {
  folderVideos: number = 0
  recentPlays: number = 0
  privacyVideos: number = 0
  skipped: number = 0
}

// =============================================================================
// 结构迁移（Schema Migration）
// =============================================================================
export class SchemaMigrationHelper {
  static async migrateSchema(context: Context): Promise<void> {
    const orm = getORM()

    orm.migrate(FolderEntity)
    orm.migrate(VideoEntity)
    orm.migrate(RecentPlayEntity)
    orm.migrate(PrivacyVideoEntity)

    await SchemaMigrationHelper.createUriUniqueIndex(context)
    console.info('[SchemaMigrationHelper] 表结构迁移完成')
  }

  private static async createUriUniqueIndex(context: Context): Promise<void> {
    try {
      const store = await relationalStore.getRdbStore(context, {
        name: DATABASE_NAME + '.db',
        securityLevel: relationalStore.SecurityLevel.S1
      })
      const sql = 'CREATE UNIQUE INDEX IF NOT EXISTS idx_video_uri ON video_entity (uri)'
      await store.execute(sql)
      console.info('[SchemaMigrationHelper] uri 唯一索引创建/检查完成')
    } catch (error) {
      console.error('[SchemaMigrationHelper] 创建 uri 唯一索引失败:', error)
      throw new Error(`创建 uri 唯一索引失败: ${error}`)
    }
  }
}

// =============================================================================
// 数据迁移（Data Migration）
// =============================================================================
// 特性：
// 1. 幂等：已存在的数据自动跳过
// 2. 可恢复：每处理一条立即从 Preferences 中删除，崩溃后可重复执行
// 3. 细粒度：按单条视频/记录迁移
// =============================================================================
export class DataMigrationHelper {
  static async migrateFromPreferences(
    context: Context,
    onProgress?: (processed: number, total: number, message: string) => void
  ): Promise<MigrationSummary> {
    console.info('[DataMigrationHelper] migrateFromPreferences started')
    const total = DataMigrationHelper.estimateTotal(context)
    console.info(`[DataMigrationHelper] estimated total: ${total}`)
    let processed = 0
    const stats = new MigrationSummary()

    const report = (message: string) => {
      processed++
      onProgress?.(processed, total, message)
    }

    const folderResult = await DataMigrationHelper.migrateFoldersAndVideos(context, report)
    stats.folderVideos = folderResult.migrated
    stats.skipped += folderResult.skipped

    const recentResult = await DataMigrationHelper.migrateRecentPlays(context, report)
    stats.recentPlays = recentResult.migrated
    stats.skipped += recentResult.skipped

    const privacyResult = await DataMigrationHelper.migratePrivacyVideos(context, report)
    stats.privacyVideos = privacyResult.migrated
    stats.skipped += privacyResult.skipped

    console.info('[DataMigrationHelper] migrateFromPreferences completed', JSON.stringify(stats))
    return stats
  }

  private static getPreferencesArray<T>(context: Context, name: string, key: string): T[] {
    const raw = PreferencesUtil.getPreferencesValue(context, name, key, []) as object | string
    console.info(`[DataMigrationHelper] read ${name}/${key}, type: ${typeof raw}, isArray: ${Array.isArray(raw)}`)
    if (Array.isArray(raw)) {
      return raw as T[]
    }
    if (typeof raw === 'string') {
      try {
        const parsed = JSON.parse(raw) as T[]
        console.info(`[DataMigrationHelper] parsed ${name}/${key} string, length: ${parsed.length}`)
        return parsed
      } catch (e) {
        console.error(`[DataMigrationHelper] JSON.parse failed for ${name}/${key}:`, e)
        return []
      }
    }
    console.error(`[DataMigrationHelper] unexpected type for ${name}/${key}:`, typeof raw)
    return []
  }

  private static estimateTotal(context: Context): number {
    let total = 0
    const folders = DataMigrationHelper.getPreferencesArray<FileFolder>(context, DATABASE_NAME, 'file_folder')
    total += folders.reduce((sum, f) => sum + (f.video_list?.length || 0), 0)
    const recent = DataMigrationHelper.getPreferencesArray<VideoMetadata>(context, DATABASE_NAME, 'recent_play')
    total += recent.length
    const privacy = DataMigrationHelper.getPreferencesArray<VideoMetadata>(context, PRIVACY_DB_NAME, 'video_meta_data_encryption')
    total += privacy.length
    console.info(`[DataMigrationHelper] estimateTotal: folders=${folders.length}, recent=${recent.length}, privacy=${privacy.length}`)
    return total
  }

  private static async migrateFoldersAndVideos(
    context: Context,
    onItem?: (message: string) => void
  ): Promise<MigrationResult> {
    const folders = DataMigrationHelper.getPreferencesArray<FileFolder>(context, DATABASE_NAME, 'file_folder')
    console.info(`[DataMigrationHelper] migrateFoldersAndVideos: ${folders.length} folders`)

    if (folders.length === 0) {
      return { migrated: 0, skipped: 0 }
    }

    const folderRepo = FolderRepository.getInstance()
    const videoRepo = VideoRepository.getInstance()
    let migrated = 0
    let skipped = 0

    for (let i = folders.length - 1; i >= 0; i--) {
      const folder = folders[i]
      if (!folder.video_list) {
        folder.video_list = []
      }

      let folderEntity = await folderRepo.findByDate(folder.date.toString())
      // "首页"文件夹去重与合并：如果按 date 找不到，或者找到的不是"首页"，则按 name 查找真正的"首页"
      if (folder.name === '首页' && (!folderEntity || folderEntity.name !== '首页' || folderEntity.id === undefined)) {
        const homeByName = await folderRepo.findByName('首页')
        if (homeByName && homeByName.id !== undefined) {
          folderEntity = homeByName
        }
      }
      let folderId: number
      if (!folderEntity || folderEntity.id === undefined) {
        const newFolder = new FolderEntity()
        newFolder.name = folder.name
        newFolder.date = folder.date.toString()
        await folderRepo.insert(newFolder)
        folderEntity = await folderRepo.findByDate(folder.date.toString())
        if (!folderEntity || folderEntity.id === undefined) {
          folderEntity = await folderRepo.findByName(folder.name)
        }
        folderId = folderEntity!.id!
      } else {
        folderId = folderEntity.id!
      }

      for (let j = folder.video_list.length - 1; j >= 0; j--) {
        const video = folder.video_list[j]
        const exists = await videoRepo.existsByUri(video.uri)
        if (exists) {
          skipped++
          onItem?.(`跳过已存在: ${video.title}`)
        } else {
          await DataMigrationHelper.saveVideoToRepo(video, folderId, videoRepo)
          migrated++
          onItem?.(`迁移视频: ${video.title}`)
        }
        folder.video_list.splice(j, 1)
        PreferencesUtil.putPreferencesValue(context, DATABASE_NAME, 'file_folder', folders)
      }

      if (folder.video_list.length === 0) {
        folders.splice(i, 1)
        PreferencesUtil.putPreferencesValue(context, DATABASE_NAME, 'file_folder', folders)
      }
    }

    const result: MigrationResult = { migrated, skipped }
    console.info(`[DataMigrationHelper] migrateFoldersAndVideos result:`, JSON.stringify(result))
    return result
  }

  private static async migrateRecentPlays(
    context: Context,
    onItem?: (message: string) => void
  ): Promise<MigrationResult> {
    const recent = DataMigrationHelper.getPreferencesArray<VideoMetadata>(context, DATABASE_NAME, 'recent_play')
    console.info(`[DataMigrationHelper] migrateRecentPlays: ${recent.length} records`)

    if (recent.length === 0) {
      const emptyResult: MigrationResult = { migrated: 0, skipped: 0 }
      return emptyResult
    }

    const recentRepo = RecentPlayRepository.getInstance()
    let migrated = 0
    let skipped = 0
    const currentTime = new Date().toISOString()

    for (let i = recent.length - 1; i >= 0; i--) {
      const video = recent[i]
      const exists = await recentRepo.existsByUri(video.uri)
      if (exists) {
        skipped++
        onItem?.(`跳过已存在最近播放: ${video.title}`)
      } else {
        const entity = DataMigrationHelper.convertToRecentPlayEntity(video, video.date || currentTime, currentTime)
        await recentRepo.insert(entity)
        migrated++
        onItem?.(`迁移最近播放: ${video.title}`)
      }
      recent.splice(i, 1)
      PreferencesUtil.putPreferencesValue(context, DATABASE_NAME, 'recent_play', recent)
    }

    const result: MigrationResult = { migrated, skipped }
    console.info(`[DataMigrationHelper] migrateRecentPlays result:`, JSON.stringify(result))
    return result
  }

  private static async migratePrivacyVideos(
    context: Context,
    onItem?: (message: string) => void
  ): Promise<MigrationResult> {
    PrivacySpaceUtil.setPrivacyMode(true)
    try {
      const privacyVideos = DataMigrationHelper.getPreferencesArray<VideoMetadata>(context, PRIVACY_DB_NAME, 'video_meta_data_encryption')
      console.info(`[DataMigrationHelper] migratePrivacyVideos: ${privacyVideos.length} records`)

      if (privacyVideos.length === 0) {
        return { migrated: 0, skipped: 0 }
      }

      const privacyRepo = PrivacyVideoRepository.getInstance()
      let migrated = 0
      let skipped = 0
      const importedAt = new Date().toISOString()

      for (let i = privacyVideos.length - 1; i >= 0; i--) {
        const video = privacyVideos[i]
        const exists = await privacyRepo.existsByOriginalUri(video.uri)
        if (exists) {
          skipped++
          onItem?.(`跳过已存在隐私视频: ${video.title}`)
        } else {
          const entity = DataMigrationHelper.convertToPrivacyVideoEntity(video, importedAt)
          await privacyRepo.insert(entity)
          migrated++
          onItem?.(`迁移隐私视频: ${video.title}`)
        }
        privacyVideos.splice(i, 1)
        PreferencesUtil.putPreferencesValue(context, PRIVACY_DB_NAME, 'video_meta_data_encryption', privacyVideos)
      }

      const result: MigrationResult = { migrated, skipped }
      console.info(`[DataMigrationHelper] migratePrivacyVideos result:`, JSON.stringify(result))
      return result
    } finally {
      PrivacySpaceUtil.setPrivacyMode(false)
    }
  }

  private static async saveVideoToRepo(
    video: VideoMetadata,
    folderId: number,
    videoRepo: VideoRepository
  ): Promise<void> {
    const entity = new VideoEntity()
    entity.uri = video.uri
    entity.folderId = folderId
    entity.title = video.title
    entity.date = video.date
    entity.width = video.size?.[0] || 0
    entity.height = video.size?.[1] || 0
    entity.duration = video.time || 0
    entity.lastPosition = video.last_play || 0
    entity.format = video.format || ''
    entity.fileSize = video.video_size || ''
    entity.hdrType = video.hdr_type || 0
    entity.startTime = video.start_time || 0
    entity.endTime = video.end_time || 0
    entity.externalSubtitle = video.external_subtitle_format || ''
    entity.pointA = video.pointA || 0
    entity.pointB = video.pointB || 0
    entity.subtitle_mode = video.subtitle_mode || 0
    entity.subtitle_visible = video.subtitle_visible !== false
    entity.subtitle_ai_asr_shown = video.subtitle_ai_asr_shown || false
    entity.subtitle_3d_mode = video.subtitle_3d_mode || 0
    entity.subtitle_offset_millis = video.subtitle_offset_millis || 0
    entity.subtitle_track_id = video.subtitle_track_id || 0
    await videoRepo.insert(entity)
  }

  private static convertToRecentPlayEntity(video: VideoMetadata, folderDate: string, playedAt: string): RecentPlayEntity {
    const entity = new RecentPlayEntity()
    entity.uri = video.uri
    entity.title = video.title
    entity.folderDate = folderDate
    entity.width = video.size?.[0] || 0
    entity.height = video.size?.[1] || 0
    entity.duration = video.time || 0
    entity.lastPosition = video.last_play || 0
    entity.format = video.format || ''
    entity.fileSize = video.video_size || ''
    entity.hdrType = video.hdr_type || 0
    entity.playedAt = playedAt
    return entity
  }

  private static convertToPrivacyVideoEntity(video: VideoMetadata, importedAt: string): PrivacyVideoEntity {
    const entity = new PrivacyVideoEntity()
    entity.uri = video.uri
    entity.title = video.title
    entity.originalUri = video.uri
    entity.date = video.date
    entity.width = video.size?.[0] || 0
    entity.height = video.size?.[1] || 0
    entity.duration = video.time || 0
    entity.lastPosition = video.last_play || 0
    entity.format = video.format || ''
    entity.fileSize = video.video_size || ''
    entity.hdrType = video.hdr_type || 0
    entity.startTime = video.start_time || 0
    entity.endTime = video.end_time || 0
    entity.pointA = video.pointA || 0
    entity.pointB = video.pointB || 0
    entity.importedAt = importedAt
    entity.subtitle_mode = video.subtitle_mode || 0
    entity.subtitle_visible = video.subtitle_visible !== false
    entity.subtitle_ai_asr_shown = video.subtitle_ai_asr_shown || false
    entity.subtitle_3d_mode = video.subtitle_3d_mode || 0
    entity.subtitle_offset_millis = video.subtitle_offset_millis || 0
    entity.subtitle_track_id = video.subtitle_track_id || 0
    return entity
  }
}
