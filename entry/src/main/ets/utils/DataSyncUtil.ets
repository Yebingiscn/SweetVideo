import { FileFolder } from '../interfaces/FileFolderInterface';
import { VideoMetadata } from '../interfaces/VideoMetadataInterface';

// 数据类
class DataSyncUtil {
  public topSafeHeight: number = 0;
  public lastTime: number = 0;
  public editingVideo: VideoMetadata | undefined = undefined
  public editingFolder: FileFolder | undefined = undefined
  public deletedVideos: VideoMetadata[] = []
  public bottomSafeHeight: number = 0
  public delMultipleList: VideoMetadata[] = []
  public minSideBarWidth: number = 100; // 最小侧边栏宽度
  public minContentWidth: number = 345; // 最小内容区宽度
  public lastPlayVideoIndex: number = -1
}

export default new DataSyncUtil();

export const OOBEVersion = 0