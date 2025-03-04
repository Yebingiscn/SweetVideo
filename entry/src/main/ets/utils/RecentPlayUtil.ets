import PreferencesUtil from './PreferencesUtil';
import { VideoMetadata } from './VideoInfoUtil';

class RecentPlayUtil {
  private readonly MAX_SIZE = 30;
  private deque: VideoMetadata[] = [];
  private videoIdMap: Map<string, number> = new Map(); // ID -> Index in deque

  constructor() {
    this.init();
  }

  async addPlayback(item: VideoMetadata): Promise<void> {
    if (this.videoIdMap.has(item.date)) {
      const existingIndex = this.videoIdMap.get(item.date)!;
      this.deque.splice(existingIndex, 1);
    }
    this.deque.unshift(item);
    if (this.deque.length > this.MAX_SIZE) {
      this.deque.pop();
    }
    this.updateMapIndices();
    await this.persistData();
  }

  async getRecentPlaybacks(): Promise<VideoMetadata[]> {
    return [...this.deque];
  }

  private async init() {
    await this.loadData();
  }

  private updateMapIndices() {
    this.videoIdMap.clear();
    this.deque.forEach((item, index) => {
      this.videoIdMap.set(item.date, index);
    });
  }

  private async persistData() {
    await PreferencesUtil.putPreferencesValue('sweet_video', 'recent_play', this.deque);
  }

  private async loadData() {
    this.deque = await PreferencesUtil.getPreferencesValue('sweet_video', 'recent_play', []) as VideoMetadata[]
    this.updateMapIndices();
  }
}

export default new RecentPlayUtil();