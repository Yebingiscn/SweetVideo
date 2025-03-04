class DataSyncUtil {
  public topSafeHeight: number = 0;
  public last_time: number = 0;
  public editing_video: string = '';
  public bottomSafeHeight: number = 0
  private actuallyTopSafeHeight: number | null = null; // 用于存储第一次不为0的值

  setTopSafeHeight(value: number) {
    this.topSafeHeight = value;
    if (this.actuallyTopSafeHeight === null && value !== 0) {
      this.actuallyTopSafeHeight = value; // 存储第一次不为0的值
    }
  }

  getActuallyTopSafeHeight() {
    return this.actuallyTopSafeHeight; // 获取第一次不为0的值
  }
}

export default new DataSyncUtil();