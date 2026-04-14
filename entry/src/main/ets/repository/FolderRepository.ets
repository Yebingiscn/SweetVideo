import { getORM } from '@ibestservices/ibest-orm'
import { FolderEntity } from '../entity/FolderEntity'
import { VideoRepository } from './VideoRepository'

export class FolderRepository {
  private static instance: FolderRepository
  private orm = getORM()

  private constructor() {}

  static getInstance(): FolderRepository {
    if (!FolderRepository.instance) {
      FolderRepository.instance = new FolderRepository()
    }
    return FolderRepository.instance
  }

  query() {
    return this.orm.query(FolderEntity)
  }

  async insert(entity: FolderEntity): Promise<void> {
    await this.orm.insert(entity)
  }

  async insertBatch(entities: FolderEntity[]): Promise<void> {
    if (entities.length === 0) return
    await this.orm.insert(entities)
  }

  async save(entity: FolderEntity): Promise<void> {
    await this.orm.save(entity)
  }

  async delete(entity: FolderEntity): Promise<void> {
    await this.orm.delete(entity)
  }

  async findAll(): Promise<FolderEntity[]> {
    return this.query().find()
  }

  async findAllWithVideos(): Promise<FolderEntity[]> {
    // ✅ 修复：避免使用 with('videos') 关联查询，手动加载视频
    const folders = await this.query()
      .orderBy('sortOrder', 'asc')
      .find()
    // 手动加载每个文件夹的视频
    const videoRepo = VideoRepository.getInstance()
    for (const folder of folders) {
      if (folder.id !== undefined) {
        folder.videos = await videoRepo.findByFolderId(folder.id)
      }
    }
    return folders
  }

  async findById(id: number): Promise<FolderEntity | undefined> {
    const results = await this.query()
      .where({ id: id })
      .find()
    if (results.length > 0 && results[0].id !== undefined) {
      // 手动加载视频
      const videoRepo = VideoRepository.getInstance()
      results[0].videos = await videoRepo.findByFolderId(results[0].id)
    }
    return results[0]
  }

  async findByDate(date: string): Promise<FolderEntity | undefined> {
    const results = await this.query()
      .where({ date: date })
      .find()
    if (results.length > 0 && results[0].id !== undefined) {
      // 手动加载视频
      const videoRepo = VideoRepository.getInstance()
      results[0].videos = await videoRepo.findByFolderId(results[0].id)
    }
    return results[0]
  }

  async findByName(name: string): Promise<FolderEntity | undefined> {
    const results = await this.query()
      .where({ name: name })
      .find()
    if (results.length > 0 && results[0].id !== undefined) {
      // 手动加载视频
      const videoRepo = VideoRepository.getInstance()
      results[0].videos = await videoRepo.findByFolderId(results[0].id)
    }
    return results[0]
  }

  async existsByName(name: string): Promise<boolean> {
    const results = await this.query()
      .where({ name: name })
      .find()
    return results.length > 0
  }

  migrate(): void {
    this.orm.migrate(FolderEntity)
  }
}
