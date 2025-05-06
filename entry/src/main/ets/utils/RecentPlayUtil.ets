import { common, Context } from '@kit.AbilityKit';
import { VideoMetadata } from '../interfaces/VideoMetadataInterface';
import SelectFileUtil from './SelectFileUtil';

// 最近播放类
class RecentPlayUtil {
  public deque: VideoMetadata[] = [];
  private readonly MAX_SIZE = 30;
  private videoIdMap: Map<string, number> = new Map(); // ID -> Index in deque
  private context = getContext() as common.UIAbilityContext;

  constructor() {
    this.init(this.context);
  }

  async addPlayback(context: Context, item: VideoMetadata): Promise<void> {
    if (this.videoIdMap.has(item.date)) {
      const existingIndex = this.videoIdMap.get(item.date)!;
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
    return [...this.deque];
  }

  public async delData(context: Context, item: VideoMetadata) {
    if (this.deque.findIndex(i => i.date === item.date) !== -1) {
      this.deque = this.deque.filter(i => i.date != item?.date)
      await SelectFileUtil.saveRecentPlay(context, this.deque)
    }
  }

  private async init(context: Context) {
    await this.loadData(context);
  }

  private updateMapIndices() {
    this.videoIdMap.clear();
    this.deque.forEach((item, index) => {
      this.videoIdMap.set(item.date, index);
    });
  }

  private async persistData(context: Context) {
    await SelectFileUtil.saveRecentPlay(context, this.deque)
  }

  private async loadData(context: Context) {
    this.deque = await SelectFileUtil.getRecentPlay(context)
    this.updateMapIndices();
  }
}

export default new RecentPlayUtil();