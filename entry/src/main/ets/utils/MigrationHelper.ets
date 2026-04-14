import { Context } from '@kit.AbilityKit'
import { getORM } from '@ibestservices/ibest-orm'
import { relationalStore } from '@kit.ArkData'
import { FolderEntity } from '../entity/FolderEntity'
import { VideoEntity } from '../entity/VideoEntity'
import { RecentPlayEntity } from '../entity/RecentPlayEntity'
import { PrivacyVideoEntity } from '../entity/PrivacyVideoEntity'
import PreferencesUtil from '../database/PreferencesUtil'
import Preferences from '../database/Preferences'
import { VideoRepository } from '../repository/VideoRepository'
import { FolderRepository } from '../repository/FolderRepository'
import { RecentPlayRepository } from '../repository/RecentPlayRepository'
import { PrivacyVideoRepository } from '../repository/PrivacyVideoRepository'
import { FileFolder } from '../interfaces/FileFolderInterface'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import PrivacySpaceUtil from './PrivacySpaceUtil'

const DATABASE_NAME = 'sweet_video'
const PRIVACY_DB_NAME = 'privacy_space'
const MIGRATION_KEY_V3 = 'ibest_orm_migration_done_v3'

export class MigrationHelper {
  /**
   * 执行数据库表结构迁移
   */
  static async migrate(context: Context): Promise<void> {
    const orm = getORM()

    // 迁移表结构
    orm.migrate(FolderEntity)
    orm.migrate(VideoEntity)
    orm.migrate(RecentPlayEntity)
    orm.migrate(PrivacyVideoEntity)

    // 创建 uri 唯一索引（VideoEntity 的 id 改为自增主键后，需要手动添加 uri 唯一约束）
    await MigrationHelper.createUriUniqueIndex(context)

    console.info('[MigrationHelper] 表结构迁移完成')
  }

  /**
   * 从 Preferences 迁移数据到 ORM（原子操作，单一标记）
   */
  static async migrateFromPreferences(context: Context): Promise<void> {
    // 检查是否已迁移
    const hasMigrated = PreferencesUtil.getPreferencesValue(context, DATABASE_NAME, MIGRATION_KEY_V3, false) as boolean
    if (hasMigrated) {
      console.info('[MigrationHelper] 数据已迁移，跳过')
      return
    }

    console.info('[MigrationHelper] 开始数据迁移')

    // 执行所有迁移（原子操作，任一失败都会抛出错误）
    await MigrationHelper.migrateFoldersAndVideos(context)
    await MigrationHelper.migrateRecentPlays(context)
    await MigrationHelper.migratePrivacyVideos(context)

    // 标记迁移完成
    PreferencesUtil.putPreferencesValue(context, DATABASE_NAME, MIGRATION_KEY_V3, true)
    console.info('[MigrationHelper] 数据迁移完成')
  }

  // 创建 uri 唯一索引
  private static async createUriUniqueIndex(context: Context): Promise<void> {
    try {
      const store = await relationalStore.getRdbStore(context, {
        name: DATABASE_NAME + '.db',
        securityLevel: relationalStore.SecurityLevel.S1
      })
      // 创建 uri 唯一索引（如果不存在）
      const sql = 'CREATE UNIQUE INDEX IF NOT EXISTS idx_video_uri ON video_entity (uri)'
      await store.execute(sql)
      console.info('[MigrationHelper] uri 唯一索引创建成功')
    } catch (error) {
      console.error('[MigrationHelper] 创建 uri 唯一索引失败:', error)
      throw new Error(`创建 uri 唯一索引失败: ${error}`)
    }
  }

  // 迁移文件夹和视频数据
  private static async migrateFoldersAndVideos(context: Context): Promise<void> {
    // 获取旧数据（从 Preferences 的遗留键读取）
    const foldersJson = PreferencesUtil.getPreferencesValue(context, DATABASE_NAME, 'file_folder', '[]') as string
    let folders: FileFolder[] = []
    try {
      folders = JSON.parse(foldersJson)
    } catch (e) {
      console.warn('[MigrationHelper] 解析旧文件夹数据失败:', e)
      return
    }

    if (!Array.isArray(folders) || folders.length === 0) {
      console.info('[MigrationHelper] 没有旧文件夹数据需要迁移')
      return
    }

    console.info(`[MigrationHelper] 开始迁移 ${folders.length} 个文件夹`)

    const folderRepo = FolderRepository.getInstance()
    const videoRepo = VideoRepository.getInstance()

    // 只有在确认有旧数据需要迁移时，才清空现有数据
    const existingVideos = await videoRepo.findAll()
    if (existingVideos.length > 0) {
      console.info(`[MigrationHelper] 清空现有 ${existingVideos.length} 条视频数据`)
      for (const video of existingVideos) {
        await videoRepo.delete(video)
      }
    }

    const existingFolders = await folderRepo.findAll()
    if (existingFolders.length > 0) {
      console.info(`[MigrationHelper] 清空现有 ${existingFolders.length} 个文件夹`)
      for (const folder of existingFolders) {
        await folderRepo.delete(folder)
      }
    }

    // 迁移文件夹和视频
    for (const folder of folders) {
      try {
        // 创建 FolderEntity
        const folderEntity = new FolderEntity()
        folderEntity.name = folder.name
        folderEntity.date = folder.date.toString()

        // 先保存文件夹
        await folderRepo.insert(folderEntity)
        console.info(`[MigrationHelper] 迁移文件夹: ${folder.name}`)

        // 重新查询获取带 id 的实体
        const savedFolder = await folderRepo.findByDate(folder.date.toString())
        if (!savedFolder || savedFolder.id === undefined) {
          console.error(`[MigrationHelper] 无法获取文件夹 ${folder.name} 的 id`)
          continue
        }

        // 迁移该文件夹下的视频
        if (folder.video_list && folder.video_list.length > 0) {
          for (const video of folder.video_list) {
            await MigrationHelper.saveVideoToRepo(video, savedFolder.id, videoRepo)
          }
          console.info(`[MigrationHelper] 文件夹 ${folder.name} 迁移了 ${folder.video_list.length} 个视频`)
        }
      } catch (error) {
        console.error(`[MigrationHelper] 迁移文件夹 ${folder.name} 失败:`, error)
        // 继续迁移其他文件夹，不中断整体流程
      }
    }

    console.info('[MigrationHelper] 文件夹和视频迁移完成')
  }

  // 迁移最近播放数据
  private static async migrateRecentPlays(context: Context): Promise<void> {
    // 获取旧数据
    const recentJson = PreferencesUtil.getPreferencesValue(context, DATABASE_NAME, 'recent_play', '[]') as string
    let recentVideos: VideoMetadata[] = []
    try {
      recentVideos = JSON.parse(recentJson)
    } catch (e) {
      console.warn('[MigrationHelper] 解析旧最近播放数据失败:', e)
      return
    }

    if (!Array.isArray(recentVideos) || recentVideos.length === 0) {
      console.info('[MigrationHelper] 没有旧最近播放数据需要迁移')
      return
    }

    console.info(`[MigrationHelper] 开始迁移 ${recentVideos.length} 条最近播放记录`)

    const recentRepo = RecentPlayRepository.getInstance()

    // 清空现有数据
    const existing = await recentRepo.findAll()
    for (const item of existing) {
      await recentRepo.delete(item)
    }

    // 预生成当前时间，避免在循环中重复创建 Date 对象
    const currentTime = new Date().toISOString()

    // 迁移数据
    for (const video of recentVideos) {
      try {
        // 旧数据可能没有 folderDate，使用默认值
        const folderDate = video.date || currentTime
        const entity = MigrationHelper.convertToRecentPlayEntity(video, folderDate, currentTime)
        await recentRepo.save(entity)
      } catch (error) {
        console.error(`[MigrationHelper] 迁移最近播放 ${video.title} 失败:`, error)
      }
    }

    console.info('[MigrationHelper] 最近播放迁移完成')
  }

  // 迁移隐私空间视频数据
  private static async migratePrivacyVideos(context: Context): Promise<void> {
    // 切换到隐私空间模式读取数据
    PrivacySpaceUtil.setPrivacyMode(true)

    try {
      // 获取旧数据（从隐私空间的 Preferences 读取）
      const privacyJson = PreferencesUtil.getPreferencesValue(context, PRIVACY_DB_NAME, 'video_meta_data_encryption', '[]') as string
      let privacyVideos: VideoMetadata[] = []
      try {
        privacyVideos = JSON.parse(privacyJson)
      } catch (e) {
        console.warn('[MigrationHelper] 解析旧隐私空间数据失败:', e)
        return
      }

      if (!Array.isArray(privacyVideos) || privacyVideos.length === 0) {
        console.info('[MigrationHelper] 没有旧隐私空间数据需要迁移')
        return
      }

      console.info(`[MigrationHelper] 开始迁移 ${privacyVideos.length} 条隐私空间记录`)

      const privacyRepo = PrivacyVideoRepository.getInstance()

      // 清空现有数据
      const existing = await privacyRepo.findAll()
      for (const item of existing) {
        await privacyRepo.delete(item)
      }

      // 预生成当前时间，避免在循环中重复创建 Date 对象
      const importedAt = new Date().toISOString()

      // 迁移数据
      for (const video of privacyVideos) {
        try {
          const entity = MigrationHelper.convertToPrivacyVideoEntity(video, importedAt)
          await privacyRepo.save(entity)
        } catch (error) {
          console.error(`[MigrationHelper] 迁移隐私视频 ${video.title} 失败:`, error)
        }
      }

      console.info('[MigrationHelper] 隐私空间迁移完成')
    } finally {
      // 恢复隐私空间模式
      PrivacySpaceUtil.setPrivacyMode(false)
    }
  }

  // 辅助方法：保存视频到 Repository
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
    // 字幕相关字段
    entity.subtitle_mode = video.subtitle_mode || 0
    entity.subtitle_visible = video.subtitle_visible !== false // 默认 true
    entity.subtitle_ai_asr_shown = video.subtitle_ai_asr_shown || false
    entity.subtitle_3d_mode = video.subtitle_3d_mode || 0
    entity.subtitle_offset_millis = video.subtitle_offset_millis || 0
    entity.subtitle_track_id = video.subtitle_track_id || 0

    await videoRepo.save(entity)
  }

  // 辅助方法：转换为 RecentPlayEntity
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

  // 辅助方法：转换为 PrivacyVideoEntity
  private static convertToPrivacyVideoEntity(video: VideoMetadata, importedAt: string): PrivacyVideoEntity {
    const entity = new PrivacyVideoEntity()
    entity.uri = video.uri
    entity.title = video.title
    entity.originalUri = video.uri // 隐私视频原始 URI 与当前 URI 相同
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
    // 字幕相关字段
    entity.subtitle_mode = video.subtitle_mode || 0
    entity.subtitle_visible = video.subtitle_visible !== false
    entity.subtitle_ai_asr_shown = video.subtitle_ai_asr_shown || false
    entity.subtitle_3d_mode = video.subtitle_3d_mode || 0
    entity.subtitle_offset_millis = video.subtitle_offset_millis || 0
    entity.subtitle_track_id = video.subtitle_track_id || 0
    return entity
  }
}
