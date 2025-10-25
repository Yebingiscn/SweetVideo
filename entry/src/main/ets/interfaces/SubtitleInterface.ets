export interface SubtitleItem {
  startTimestampMillis: number; // 毫秒时间戳
  endTimestampMillis: number; // 毫秒时间戳
  text: string;
}

// 定义解析器接口
export interface Parser<T> {
  init(): Promise<void>;

  readLines(): Promise<T[]>;
}