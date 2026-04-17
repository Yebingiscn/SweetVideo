import { getORM } from '@ibestservices/ibest-orm'
import { RecentPlayEntity } from '../entity/RecentPlayEntity'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'

// 最近播放数据访问层（Repository）
// ORM 改造：封装 ibest-orm 对 RecentPlayEntity 的增删改查，供 RecentPlayUtil 调用。
export class RecentPlayRepository {
  private static instance: RecentPlayRepository
  private orm = getORM()

  private constructor() {}

  static getInstance(): RecentPlayRepository {
    if (!RecentPlayRepository.instance) {
      RecentPlayRepository.instance = new RecentPlayRepository()
    }
    return RecentPlayRepository.instance
  }

  query() {
    return this.orm.query(RecentPlayEntity)
  }

  async insert(entity: RecentPlayEntity): Promise<void> {
    await this.orm.insert(entity)
  }

  async insertBatch(entities: RecentPlayEntity[]): Promise<void> {
    if (entities.length === 0) return
    await this.orm.insert(entities)
  }

  async save(entity: RecentPlayEntity): Promise<void> {
    await this.orm.save(entity)
  }

  async delete(entity: RecentPlayEntity): Promise<void> {
    await this.orm.delete(entity)
  }

  async findAll(): Promise<RecentPlayEntity[]> {
    return this.query().find()
  }

  // 按 playedAt 降序查询最近的 N 条记录
  async findRecent(limit: number = 100): Promise<RecentPlayEntity[]> {
    return this.query()
      .orderBy('playedAt', 'desc')
      .limit(limit)
      .find()
  }

  // 单条记录插入/更新（uri 为主键，save 会自动判断 insert 或 update）
  async recordPlay(video: VideoMetadata): Promise<void> {
    const entity = new RecentPlayEntity()
    entity.uri = video.uri
    entity.title = video.title
    entity.folderDate = video.date
    entity.width = video.size[0] || 0
    entity.height = video.size[1] || 0
    entity.duration = video.time
    entity.lastPosition = video.last_play
    entity.format = video.format
    entity.fileSize = video.video_size
    entity.hdrType = video.hdr_type
    entity.playedAt = new Date().toISOString()

    await this.save(entity)
  }

  // 批量插入（用于 RecentPlayUtil.persistData 的“清空重插”策略）
  async recordPlayBatch(videos: VideoMetadata[]): Promise<void> {
    const entities = videos.map(video => {
      const entity = new RecentPlayEntity()
      entity.uri = video.uri
      entity.title = video.title
      entity.folderDate = video.date
      entity.width = video.size[0] || 0
      entity.height = video.size[1] || 0
      entity.duration = video.time
      entity.lastPosition = video.last_play
      entity.format = video.format
      entity.fileSize = video.video_size
      entity.hdrType = video.hdr_type
      entity.playedAt = new Date().toISOString()
      return entity
    })
    await this.insertBatch(entities)
  }

  async existsByUri(uri: string): Promise<boolean> {
    const results = await this.query()
      .where({ uri: uri })
      .find()
    return results.length > 0
  }

  async clearAll(): Promise<void> {
    const all = await this.findAll()
    for (const item of all) {
      await this.delete(item)
    }
  }

  migrate(): void {
    this.orm.migrate(RecentPlayEntity)
  }
}
