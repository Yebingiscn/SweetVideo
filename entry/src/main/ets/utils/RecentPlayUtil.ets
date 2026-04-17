import { Context } from '@kit.AbilityKit'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import { RecentPlayRepository } from '../repository/RecentPlayRepository'
import { PathUtils } from './PathUtils'

// 最近播放类
// ORM 改造：最近播放列表从 Preferences 数组存储迁移到 RecentPlayRepository（RDB 表）。
// 设计说明：
// 1. 内存中保留 deque + videoIdMap 用于快速去重和索引访问；
// 2. 持久化时采用“清空重插”策略（clearAll + recordPlayBatch），避免单条更新带来的复杂主键同步问题；
// 3. MAX_SIZE = 30 限制内存与数据库记录数量，防止无限增长。
export default class RecentPlayUtil {
  public static deque: VideoMetadata[] = []
  private static readonly MAX_SIZE = 30
  private static videoIdMap: Map<string, number> = new Map()
  private static initialized = false

  static async addPlayback(context: Context, item: VideoMetadata): Promise<void> {
    if (!RecentPlayUtil.initialized) {
      await RecentPlayUtil.init(context)
    }
    if (item?.uri == null) {
      return
    }
    if (RecentPlayUtil.videoIdMap.has(item.uri)) {
      const existingIndex = RecentPlayUtil.videoIdMap.get(item.uri)!
      RecentPlayUtil.deque.splice(existingIndex, 1)
    }
    RecentPlayUtil.deque.unshift(item)
    if (RecentPlayUtil.deque.length > RecentPlayUtil.MAX_SIZE) {
      const removed = RecentPlayUtil.deque.pop()!
      RecentPlayUtil.videoIdMap.delete(removed.uri)
    }
    RecentPlayUtil.updateMapIndicesAfterAdd()
    await RecentPlayUtil.persistData(context)
  }

  static async getRecentPlaybacks(): Promise<VideoMetadata[]> {
    await RecentPlayUtil.loadData(PathUtils.appContext!)
    return [...RecentPlayUtil.deque]
  }

  public static async delData(context: Context, uri: string): Promise<void> {
    if (RecentPlayUtil.videoIdMap.size === 0) {
      await RecentPlayUtil.init(context)
    }
    if (RecentPlayUtil.videoIdMap.has(uri)) {
      const index = RecentPlayUtil.videoIdMap.get(uri)!
      RecentPlayUtil.deque.splice(index, 1)
      RecentPlayUtil.videoIdMap.delete(uri)
      // 更新后续元素的索引
      for (let i = index; i < RecentPlayUtil.deque.length; i++) {
        RecentPlayUtil.videoIdMap.set(RecentPlayUtil.deque[i].uri, i)
      }
      await RecentPlayUtil.persistData(context)
    }
  }

  private static async init(context: Context): Promise<void> {
    if (context) {
      await RecentPlayUtil.loadData(context)
      RecentPlayUtil.initialized = true
    }
  }

  private static updateMapIndices() {
    RecentPlayUtil.videoIdMap.clear()
    RecentPlayUtil.deque.forEach((item, index) => {
      RecentPlayUtil.videoIdMap.set(item.uri, index)
    })
  }

  private static async persistData(context: Context): Promise<void> {
    const repo = RecentPlayRepository.getInstance()
    // ORM 改造：采用“清空重插”策略，先删除全部旧记录再批量插入新列表。
    // 原因：RecentPlayEntity 使用自增主键，单条更新需要维护 id 映射，复杂且易出错；
    //       最近播放列表数据量小（<=30），清空重插的性能开销可忽略，逻辑更简单可靠。
    await repo.clearAll()
    await repo.recordPlayBatch(RecentPlayUtil.deque)
  }

  // 增量更新索引（替代全量重建）
  private static updateMapIndicesAfterAdd() {
    // 新插入项索引为0，后续元素索引+1
    RecentPlayUtil.videoIdMap.set(RecentPlayUtil.deque[0].uri, 0)
    for (let i = 1; i < RecentPlayUtil.deque.length; i++) {
      RecentPlayUtil.videoIdMap.set(RecentPlayUtil.deque[i].uri, i)
    }
  }

  private static async loadData(context: Context): Promise<void> {
    const repo = RecentPlayRepository.getInstance()
    const entities = await repo.findRecent(RecentPlayUtil.MAX_SIZE)
    // ORM 改造：将 RecentPlayEntity 按字段映射回 VideoMetadata，缺失字段使用默认值填充
    // 说明：最近播放表不保存 start_time、end_time、subtitle 等播放细节，这些字段在跳转到播放器时
    //       会通过 VideoRepository / PrivacyVideoRepository 重新按 uri 查询补充。
    RecentPlayUtil.deque = entities.map((entity): VideoMetadata => ({
      uri: entity.uri,
      title: entity.title,
      date: entity.folderDate,
      size: [Number(entity.width) || 0, Number(entity.height) || 0],
      time: Number(entity.duration) || 0,
      last_play: Number(entity.lastPosition) || 0,
      format: entity.format,
      video_size: entity.fileSize,
      hdr_type: Number(entity.hdrType) || 0,
      start_time: 0,
      end_time: 0,
      external_subtitle_format: '',
      pointA: 0,
      pointB: 0
    }))
    RecentPlayUtil.updateMapIndices()
  }
}
