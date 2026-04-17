import { getORM } from '@ibestservices/ibest-orm'
import { PrivacyVideoEntity } from '../entity/PrivacyVideoEntity'

export class PrivacyVideoRepository {
  private static instance: PrivacyVideoRepository
  private orm = getORM()

  private constructor() {}

  static getInstance(): PrivacyVideoRepository {
    if (!PrivacyVideoRepository.instance) {
      PrivacyVideoRepository.instance = new PrivacyVideoRepository()
    }
    return PrivacyVideoRepository.instance
  }

  query() {
    return this.orm.query(PrivacyVideoEntity)
  }

  async insert(entity: PrivacyVideoEntity): Promise<void> {
    await this.orm.insert(entity)
  }

  async insertBatch(entities: PrivacyVideoEntity[]): Promise<void> {
    if (entities.length === 0) return
    await this.orm.insert(entities)
  }

  async save(entity: PrivacyVideoEntity): Promise<void> {
    await this.orm.save(entity)
  }

  async delete(entity: PrivacyVideoEntity): Promise<void> {
    await this.orm.delete(entity)
  }

  async findAll(): Promise<PrivacyVideoEntity[]> {
    return this.query().find()
  }

  async findAllOrdered(sortType: 'name' | 'datetime' | 'time' = 'datetime',
    order: 'asc' | 'desc' = 'desc'): Promise<PrivacyVideoEntity[]> {
    let query = this.query()

    // datetime 排序在 SQL 层完成
    if (sortType === 'datetime') {
      query = query.orderBy('importedAt', order)
    }
    // name 和 time 排序在应用层处理

    return query.find()
  }

  // ✅ 添加：按原始 URI 查询，用于去重检测
  async existsByOriginalUri(originalUri: string): Promise<boolean> {
    const results = await this.query()
      .where({ originalUri: originalUri })
      .find()
    return results.length > 0
  }

  migrate(): void {
    this.orm.migrate(PrivacyVideoEntity)
  }
}
