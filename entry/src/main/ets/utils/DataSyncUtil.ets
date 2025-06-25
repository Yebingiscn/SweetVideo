import { VideoMetadata } from '../interfaces/VideoMetadataInterface';

// 数据类
class DataSyncUtil {
  public topSafeHeight: number = 0;
  public last_time: number = 0;
  public editing_video: string = '';
  public bottomSafeHeight: number = 0
  public delMultipleList: VideoMetadata[] = []
  public minSideBarWidth: number = 100; // 最小侧边栏宽度
  public minContentWidth: number = 345; // 最小内容区宽度
}

export default new DataSyncUtil();

export const OOBEVersion = 0