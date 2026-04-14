import { getORM } from '@ibestservices/ibest-orm'
import { RecentPlayEntity } from '../entity/RecentPlayEntity'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'

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

  async findRecent(limit: number = 100): Promise<RecentPlayEntity[]> {
    return this.query()
      .orderBy('playedAt', 'desc')
      .limit(limit)
      .find()
  }

  async recordPlay(video: VideoMetadata, folderDate: string): Promise<void> {
    const entity = new RecentPlayEntity()
    entity.uri = video.uri
    entity.title = video.title
    entity.folderDate = folderDate
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
