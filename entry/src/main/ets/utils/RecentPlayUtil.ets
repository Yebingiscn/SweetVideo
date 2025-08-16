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

  async addPlayback(context: Context, item: VideoMetadata): Promise<void> {
    // 这里可能包含外链传进来的视频，用uri去重
    if (this.videoIdMap.has(item.uri)) {
      const existingIndex = this.videoIdMap.get(item.uri)!;
      this.deque.splice(existingIndex, 1);
    }
    this.deque.unshift(item);
    if (this.deque.length > this.MAX_SIZE) {
      this.deque.pop();
    }
    this.updateMapIndices();
    await this.persistData(context);
  }

  async getRecentPlaybacks(): Promise<VideoMetadata[]> {
    this.loadData(PathUtils.appContext!)
    return [...this.deque];
  }

  public async delData(context: Context, item: VideoMetadata) {
    if (this.deque.findIndex(i => i.uri === item.uri) !== -1) {
      this.deque = this.deque.filter(i => i.uri != item?.uri)
      Preferences.saveRecentPlay(context, this.deque)
    }
  }

  private async init(context: Context) {
    await this.loadData(context);
  }

  private updateMapIndices() {
    this.videoIdMap.clear();
    this.deque.forEach((item, index) => {
      this.videoIdMap.set(item.uri, index);
    });
  }

  private async persistData(context: Context) {
    Preferences.saveRecentPlay(context, this.deque)
  }

  private async loadData(context: Context) {
    this.deque = Preferences.getRecentPlay(context)
    this.updateMapIndices();
  }
}

export default new RecentPlayUtil();