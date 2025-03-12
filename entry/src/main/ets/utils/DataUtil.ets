import { VideoMetadata } from './VideoInfoUtil';

export default class DataUtil<T> implements IDataSource {
  private sources: T[] = [];
  private listeners: DataChangeListener[] = [];

  constructor(sources: T[]) {
    this.sources = [...sources]; // 防御性拷贝
  }

  totalCount(): number {
    return this.sources.length;
  }

  getData(index: number): T | undefined {
    if (index < 0 || index >= this.sources.length) {
      console.error(`Index ${index} out of bounds`);
      return undefined;
    }
    return this.sources[index];
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (!this.listeners.includes(listener)) {
      this.listeners.push(listener);
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const pos = this.listeners.indexOf(listener);
    if (pos >= 0) {
      this.listeners.splice(pos, 1);
    }
  }

  //--------------- 数据操作方法 ---------------
  appendData(item: T): void {
    this.sources.push(item);
    const index = this.sources.length - 1;
    this.listeners.forEach(listener => {
      listener.onDataAdd(index);
    });
  }

  insertData(index: number, item: T): void {
    if (index < 0 || index > this.sources.length) {
      console.error(`Invalid insert index: ${index}`);
      return;
    }
    this.sources.splice(index, 0, item);
    this.listeners.forEach(listener => {
      listener.onDataAdd(index);
    });
  }

  removeLastData(): void {
    if (this.sources.length === 0) {
      return;
    }
    const lastIndex = this.sources.length - 1;
    this.sources.pop();
    this.listeners.forEach(listener => {
      listener.onDataDelete(lastIndex);
    });
  }

  removeDataAt(index: number): void {
    if (index < 0 || index >= this.sources.length) {
      console.error(`Invalid delete index: ${index}`);
      return;
    }
    this.sources.splice(index, 1);
    this.listeners.forEach(listener => {
      listener.onDataDelete(index);
    });
  }

  clearAllData(): void {
    const length = this.sources.length;
    this.sources = [];
    this.listeners.forEach(listener => {
      for (let i = 0; i < length; i++) {
        listener.onDataDelete(i);
      }
    });
  }

  updateData(index: number, newData: T): void {
    if (index < 0 || index >= this.sources.length) {
      console.error(`Invalid update index: ${index}`);
      return;
    }
    this.sources.splice(index, 1, newData);
    this.listeners.forEach(listener => {
      listener.onDataChange(index);
    });
  }

  reloadAllData(newData: T[]): void {
    const oldLength = this.sources.length;
    // 1. 触发旧数据删除事件
    this.listeners.forEach(listener => {
      for (let i = oldLength - 1; i >= 0; i--) {
        listener.onDataDelete(i);
      }
    });
    // 2. 更新数据源
    this.sources = [...newData]; // 防御性拷贝
    // 3. 触发新数据添加事件
    this.listeners.forEach(listener => {
      for (let i = 0; i < this.sources.length; i++) {
        listener.onDataAdd(i);
      }
    });
  }
}

export class VideoDataSource implements IDataSource {
  private listeners: DataChangeListener[] = []; // 存储监听器
  private data: VideoMetadata[] = [];

  constructor(data: VideoMetadata[]) {
    this.data = data;
  }

  // 必须实现的方法：注册数据变化监听
  registerDataChangeListener(listener: DataChangeListener): void {
    this.listeners.push(listener);
  }

  // 必须实现的方法：取消注册
  unregisterDataChangeListener(listener: DataChangeListener): void {
    const index = this.listeners.indexOf(listener);
    if (index >= 0) {
      this.listeners.splice(index, 1);
    }
  }

  // 数据更新时需要触发的逻辑
  updateData(newData: VideoMetadata[]) {
    this.data = newData;
    this.listeners.forEach(listener => {
      listener.onDataReloaded(); // 通知所有监听器数据已更新
    });
  }

  totalCount(): number {
    return this.data.length;
  }

  getData(index: number): VideoMetadata {
    return this.data[index];
  }

  getKey(index: number): string {
    return this.data[index].date; // 确保date是唯一标识
  }
}

export class RecentVideoDataSource implements IDataSource {
  private listeners: DataChangeListener[] = []; // 存储监听器
  private data: VideoMetadata[] = [];

  constructor(data: VideoMetadata[]) {
    this.data = data;
  }

  // 必须实现的方法：注册数据变化监听
  registerDataChangeListener(listener: DataChangeListener): void {
    this.listeners.push(listener);
  }

  // 必须实现的方法：取消注册
  unregisterDataChangeListener(listener: DataChangeListener): void {
    const index = this.listeners.indexOf(listener);
    if (index >= 0) {
      this.listeners.splice(index, 1);
    }
  }

  // 数据更新时需要触发的逻辑
  updateData(newData: VideoMetadata[]) {
    this.data = newData;
    this.listeners.forEach(listener => {
      listener.onDataReloaded(); // 通知所有监听器数据已更新
    });
  }

  totalCount(): number {
    return this.data.length;
  }

  getData(index: number): VideoMetadata {
    return this.data[index];
  }

  getKey(index: number): string {
    return this.data[index].date; // 确保date是唯一标识
  }
}