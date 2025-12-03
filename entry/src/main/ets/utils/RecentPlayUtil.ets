import { Context } from '@kit.AbilityKit';
import { VideoMetadata } from '../interfaces/VideoMetadataInterface';
import Preferences from '../database/Preferences';
import { PathUtils } from './PathUtils';

// 最近播放类
export default class RecentPlayUtil {
  public static deque: VideoMetadata[] = [];
  private static readonly MAX_SIZE = 30;
  private static videoIdMap: Map<string, number> = new Map();
  private static initialized = false;

  static addPlayback(context: Context, item: VideoMetadata): void {
    if (!RecentPlayUtil.initialized) {
      RecentPlayUtil.init(context)
    }
    if (item?.uri == null) {
      return;
    }
    if (RecentPlayUtil.videoIdMap.has(item.uri)) {
      const existingIndex = RecentPlayUtil.videoIdMap.get(item.uri)!;
      RecentPlayUtil.deque.splice(existingIndex, 1);
    }
    RecentPlayUtil.deque.unshift(item);
    if (RecentPlayUtil.deque.length > RecentPlayUtil.MAX_SIZE) {
      const removed = RecentPlayUtil.deque.pop()!;
      RecentPlayUtil.videoIdMap.delete(removed.uri);
    }
    RecentPlayUtil.updateMapIndicesAfterAdd(); // 增量更新替代全量重建
    RecentPlayUtil.persistData(context);
  }

  static getRecentPlaybacks(): VideoMetadata[] {
    RecentPlayUtil.loadData(PathUtils.appContext!)
    return [...RecentPlayUtil.deque];
  }

  public static delData(context: Context, uri: string) {
    if (RecentPlayUtil.videoIdMap.size === 0) { // 如果为空，则初始化一下
      RecentPlayUtil.init(context)
    }
    if (RecentPlayUtil.videoIdMap.has(uri)) {
      const index = RecentPlayUtil.videoIdMap.get(uri)!;
      RecentPlayUtil.deque.splice(index, 1);
      RecentPlayUtil.videoIdMap.delete(uri);
      // 更新后续元素的索引
      for (let i = index; i < RecentPlayUtil.deque.length; i++) {
        RecentPlayUtil.videoIdMap.set(RecentPlayUtil.deque[i].uri, i);
      }
      RecentPlayUtil.persistData(context);
    }
  }

  private static init(context: Context) {
    if (context) {
      RecentPlayUtil.loadData(context);
      RecentPlayUtil.initialized = true
    }
  }

  private static updateMapIndices() {
    RecentPlayUtil.videoIdMap.clear();
    RecentPlayUtil.deque.forEach((item, index) => {
      RecentPlayUtil.videoIdMap.set(item.uri, index);
    });
  }

  private static persistData(context: Context) {
    Preferences.saveRecentPlay(context, RecentPlayUtil.deque)
  }

  // 增量更新索引（替代全量重建）
  private static updateMapIndicesAfterAdd() {
    // 新插入项索引为0，后续元素索引+1
    RecentPlayUtil.videoIdMap.set(RecentPlayUtil.deque[0].uri, 0);
    for (let i = 1; i < RecentPlayUtil.deque.length; i++) {
      RecentPlayUtil.videoIdMap.set(RecentPlayUtil.deque[i].uri, i);
    }
  }

  private static loadData(context: Context) {
    RecentPlayUtil.deque = Preferences.getRecentPlay(context)
    RecentPlayUtil.updateMapIndices();
  }
}
