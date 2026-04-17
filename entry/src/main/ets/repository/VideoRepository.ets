import { getORM } from '@ibestservices/ibest-orm'
import { VideoEntity } from '../entity/VideoEntity'

export class VideoRepository {
  private static instance: VideoRepository
  private orm = getORM()

  private constructor() {}

  static getInstance(): VideoRepository {
    if (!VideoRepository.instance) {
      VideoRepository.instance = new VideoRepository()
    }
    return VideoRepository.instance
  }

  query() {
    return this.orm.query(VideoEntity)
  }

  async insert(entity: VideoEntity): Promise<void> {
    console.info(`[VideoRepository] insert: uri=${entity.uri}, title=${entity.title}, folderId=${entity.folderId}`)
    await this.orm.insert(entity)
  }

  async insertBatch(entities: VideoEntity[]): Promise<void> {
    if (entities.length === 0) return
    await this.orm.insert(entities)
  }

  async save(entity: VideoEntity): Promise<void> {
    await this.orm.save(entity)
  }

  async delete(entity: VideoEntity): Promise<void> {
    await this.orm.delete(entity)
  }

  async findAll(): Promise<VideoEntity[]> {
    const results = await this.query().find()
    console.info(`[VideoRepository] findAll: ${results.length} videos`)
    results.forEach((v, i) => console.info(`[VideoRepository] findAll[${i}]: uri=${v.uri}, title=${v.title}, folderId=${v.folderId}`))
    return results
  }

  async findByFolderId(folderId: number, sortType: 'name' | 'datetime' | 'time' = 'name',
    order: 'asc' | 'desc' = 'desc'): Promise<VideoEntity[]> {
    let query = this.query().where({ folderId: folderId })

    // datetime 排序在 SQL 层完成
    if (sortType === 'datetime') {
      query = query.orderBy('date', order)
    }
    // name 和 time 排序在应用层处理（name 需要中文拼音，time 确保数字正确排序）

    const results = await query.find()
    console.info(`[VideoRepository] findByFolderId(${folderId}, ${sortType}, ${order}) returned ${results.length} videos`)
    return results
  }

  async updateLastPosition(uri: string, position: number): Promise<void> {
    await this.query()
      .where({ uri: uri })
      .update({ lastPosition: position })
  }

  async searchByTitle(keyword: string): Promise<VideoEntity[]> {
    return this.query()
      .whereLike('title', `%${keyword}%`)
      .find()
  }

  // ✅ 添加：按 URI 直接查询，用于去重检测
  async existsByUri(uri: string): Promise<boolean> {
    console.info(`[VideoRepository] existsByUri: 查询URI=${uri}`)
    const results = await this.query()
      .where({ uri: uri })
      .find()
    console.info(`[VideoRepository] existsByUri: 查询结果=${results.length > 0}, 匹配数=${results.length}`)
    return results.length > 0
  }

  migrate(): void {
    this.orm.migrate(VideoEntity)
  }
}
