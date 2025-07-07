import { FileFolder } from '../interfaces/FileFolderInterface';
import { VideoMetadata } from '../interfaces/VideoMetadataInterface';
import Preferences from '../database/Preferences';
import { PathUtils } from './PathUtils';
import DataSyncUtil from '../utils/DataSyncUtil';
import SubtitleUtil from '../utils/SubtitleUtil';
import RecentPlayUtil from '../utils/RecentPlayUtil';

import { fileIo as fs } from '@kit.CoreFileKit';

// 基础数据源抽象类（泛型实现）
abstract class BaseDataSource<T> implements IDataSource {
  protected data: T[];
  private listeners: DataChangeListener[] = [];

  constructor(data: T[]) {
    this.data = [...data];
  }

  // 公共方法实现
  registerDataChangeListener(listener: DataChangeListener): void {
    this.listeners.push(listener);
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const index = this.listeners.indexOf(listener);
    if (index >= 0) {
      this.listeners.splice(index, 1);
    }
  }

  updateData(newData: T[]): void {
    this.data = [...newData];
    this.notifyDataReloaded();
  }

  totalCount(): number {
    return this.data.length;
  }

  getData(index: number): T {
    return this.data[index];
  }

  deleteData(index: number): void {
    if (index < 0 || index >= this.data.length) {
      return;
    }
    this.data.splice(index, 1);
    this.notifyDataDelete(index);
  }

  getAllData(): T[] {
    return [...this.data];
  }

  // 通知方法
  protected notifyDataReloaded(): void {
    this.listeners.forEach(listener => listener.onDataReloaded());
  }

  protected notifyDataDelete(index: number): void {
    this.listeners.forEach(listener => listener.onDataDelete(index));
  }
}

// 具体实现类
export class VideoDataSource extends BaseDataSource<VideoMetadata> {
  public refreshData(){
    const video_meta_data: VideoMetadata[] = Preferences.getVideoMetaData(PathUtils.appContext!)
    this.updateData(video_meta_data)
  }
  public deleteUnExistFile(item: VideoMetadata | undefined) {
    DataSyncUtil.editing_video = JSON.stringify(item)
    new Promise<void>((resolve, reject) => {
      this.deleteItem(resolve, reject);
    });
  }

  async deleteItem(resolve: () => void, reject: (reason?: Error) => void) {
    let tmp = JSON.parse(DataSyncUtil.editing_video) as VideoMetadata;
    SubtitleUtil.deleteSubtitle(PathUtils.subtitlePath, tmp.date!)
    this.deleteData(this.data.findIndex(i => i.date === tmp.date))
    this.data = this.data.filter(i => i.date != tmp.date);
    RecentPlayUtil.delData(PathUtils.appContext!, tmp) // 删除最近播放的记录
    fs.access(PathUtils.coverPath + tmp.date, (err) => {
      if (!err) { // 文件存在
        fs.unlink(PathUtils.coverPath + tmp.date, (unlinkErr) => {
          if (unlinkErr) {
            reject(new Error(`Error deleting file from sandbox_path: ${unlinkErr.message}`));
            return;
          }
          Preferences.saveVideoMetaData(PathUtils.appContext!, this.data)
          resolve(); // 在所有操作完成后调用 resolve
        });
      } else {
        resolve(); // 文件不存在时直接调用 resolve
      }
    });
  }
}

export class FileFolderDataSource extends BaseDataSource<FileFolder> {
}