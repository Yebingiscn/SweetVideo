import { Context } from '@kit.AbilityKit';
import { VideoMetadata } from '../interfaces/VideoMetadataInterface';
import Preferences from '../database/Preferences';
import { PathUtils } from './PathUtils';

// 最近播放类
class RecentPlayUtil {
  public deque: VideoMetadata[] = [];
  private readonly MAX_SIZE = 30;
  private videoIdMap: Map<string, number> = new Map(); // ID -> Index in deque

  constructor() {
    this.init(PathUtils.appContext!);
  }

  addPlayback(context: Context, item: VideoMetadata): void {
    if (this.videoIdMap.has(item.uri)) {
      const existingIndex = this.videoIdMap.get(item.uri)!;
      this.deque.splice(existingIndex, 1);
    }
    this.deque.unshift(item);
    if (this.deque.length > this.MAX_SIZE) {
      const removed = this.deque.pop()!;
      this.videoIdMap.delete(removed.uri);
    }
    this.updateMapIndicesAfterAdd(); // 增量更新替代全量重建
    this.persistData(context);
  }

  getRecentPlaybacks(): VideoMetadata[] {
    this.loadData(PathUtils.appContext!)
    return [...this.deque];
  }

  public delData(context: Context, uri: string) {
    if (this.videoIdMap.has(uri)) {
      const index = this.videoIdMap.get(uri)!;
      this.deque.splice(index, 1);
      this.videoIdMap.delete(uri);
      // 更新后续元素的索引
      for (let i = index; i < this.deque.length; i++) {
        this.videoIdMap.set(this.deque[i].uri, i);
      }
      this.persistData(context);
    }
  }

  private init(context: Context) {
    this.loadData(context);
  }

  private updateMapIndices() {
    this.videoIdMap.clear();
    this.deque.forEach((item, index) => {
      this.videoIdMap.set(item.uri, index);
    });
  }

  private persistData(context: Context) {
    Preferences.saveRecentPlay(context, this.deque)
  }

  // 增量更新索引（替代全量重建）
  private updateMapIndicesAfterAdd() {
    // 新插入项索引为0，后续元素索引+1
    this.videoIdMap.set(this.deque[0].uri, 0);
    for (let i = 1; i < this.deque.length; i++) {
      this.videoIdMap.set(this.deque[i].uri, i);
    }
  }

  private loadData(context: Context) {
    this.deque = Preferences.getRecentPlay(context)
    this.updateMapIndices();
  }
}

export default new RecentPlayUtil();