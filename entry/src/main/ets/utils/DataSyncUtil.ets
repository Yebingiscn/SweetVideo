class DataSync {
  public topSafeHeight: number = 0
  public last_time: number = 0
  public editing_video: string = ''
}

const DataSyncUtil = new DataSync();

export default DataSyncUtil;