import { VideoMetadata } from '../interfaces/VideoMetadataInterface';

// LazyForEach 设置类
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
    this.data = [...newData];
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

  notifyDataDelete(index: number): void {
    this.listeners.forEach(listener => {
      listener.onDataDelete(index);
    })
  }

  public deleteData(index: number): void {
    this.data.splice(index, 1);
    this.notifyDataDelete(index);
  }

  public getAllData(): VideoMetadata[] {
    return this.data;
  }
}

export class FileFolderContentDataSource implements IDataSource {
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
    this.data = [...newData];
    this.listeners.forEach(listener => {
      for (let index = 0; index < this.data.length; index++) {
        listener.onDataChange(index);
      }
    });
    this.notifyDataReload()
  }

  notifyDataReload(): void {
    this.listeners.forEach(listener => {
      listener.onDataReloaded();
    })
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

  notifyDataDelete(index: number): void {
    this.listeners.forEach(listener => {
      listener.onDataDelete(index);
    })
  }

  public deleteData(index: number): void {
    this.data.splice(index, 1);
    this.notifyDataDelete(index);
  }

  public getAllData(): VideoMetadata[] {
    return this.data;
  }
}

export class PrivacySpaceDataSource implements IDataSource {
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
    this.data = [...newData];
    this.listeners.forEach(listener => {
      for (let index = 0; index < this.data.length; index++) {
        listener.onDataChange(index);
      }
    });
    this.notifyDataReload()
  }

  notifyDataReload(): void {
    this.listeners.forEach(listener => {
      listener.onDataReloaded();
    })
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

  notifyDataDelete(index: number): void {
    this.listeners.forEach(listener => {
      listener.onDataDelete(index);
    })
  }

  public deleteData(index: number): void {
    this.data.splice(index, 1);
    this.notifyDataDelete(index);
  }

  public getAllData(): VideoMetadata[] {
    return this.data;
  }
}

export class IndexDataSource implements IDataSource {
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
    this.data = [...newData];
    this.listeners.forEach(listener => {
      listener.onDataReloaded();
    })
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

  notifyDataDelete(index: number): void {
    this.listeners.forEach(listener => {
      listener.onDataDelete(index);
    })
  }

  public deleteData(index: number): void {
    this.data.splice(index, 1);
    this.notifyDataDelete(index);
  }

  public getAllData(): VideoMetadata[] {
    return this.data;
  }
}