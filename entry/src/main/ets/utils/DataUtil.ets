import { FileFolder } from '../interfaces/FileFolderInterface';
import { VideoMetadata } from '../interfaces/VideoMetadataInterface';
import Preferences from '../database/Preferences';
import { PathUtils } from './PathUtils';
import DataSyncUtil from '../utils/DataSyncUtil';
import SubtitleUtil from '../utils/SubtitleUtil';
import RecentPlayUtil from '../utils/RecentPlayUtil';

import { fileIo as fs } from '@kit.CoreFileKit';
import { FolderOperator } from '../database/VideoMetaData';

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
@Observed
export class VideoDataSource extends BaseDataSource<VideoMetadata> {
  public refreshData(folder: FileFolder) {
    const videoMetaData: VideoMetadata[] = FolderOperator.getFolderByName(folder.name).video_list
    this.updateData(videoMetaData)
  }

  public deleteUnExistFile(item: VideoMetadata | undefined) {
    DataSyncUtil.editingVideo = JSON.stringify(item)
    new Promise<void>((resolve, reject) => {
      this.deleteItem(resolve, reject);
    });
  }

  async deleteItem(resolve: () => void, reject: (reason?: Error) => void) {
    // 取出editingVideo赋值给tmp
    let tmp = JSON.parse(DataSyncUtil.editingVideo) as VideoMetadata;
    // 删除这个editingVideo的字幕
    SubtitleUtil.deleteSubtitle(PathUtils.subtitlePath, tmp.date!)
    //从videoList中找到这个video，然后调用deleteData方法删除
    this.deleteData(this.data.findIndex(i => i.date === tmp.date))
    // this.data = this.data.filter(i => i.date != tmp.date);
    RecentPlayUtil.delData(PathUtils.appContext!, tmp) // 删除最近播放的记录
    fs.access(PathUtils.coverPath + tmp.date, (err) => {
      if (!err) { // 文件存在
        fs.unlink(PathUtils.coverPath + tmp.date, (unlinkErr) => {
          if (unlinkErr) {
            reject(new Error(`Error deleting file from sandbox_path: ${unlinkErr.message}`));
            return;
          }
          resolve(); // 在所有操作完成后调用 resolve
        });
      } else {
        resolve(); // 文件不存在时直接调用 resolve
      }
    });
  }
}

@Observed
export class FileFolderDataSource extends BaseDataSource<FileFolder> {
  getFileFolder(fileFolderName: string): FileFolder {
    return Preferences.getFileFolder(PathUtils.appContext!).find(item => item.name === fileFolderName)!
  }
}