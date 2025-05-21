// 数据类
class DataSyncUtil {
  public topSafeHeight: number = 0;
  public last_time: number = 0;
  public editing_video: string = '';
  public bottomSafeHeight: number = 0
}

export default new DataSyncUtil();

export const OOBEVersion = 0