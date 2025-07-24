import { FileFolder } from '../interfaces/FileFolderInterface';
import { VideoMetadata } from '../interfaces/VideoMetadataInterface';
import Preferences from '../database/Preferences';
import { PathUtils } from './PathUtils';
import DataSyncUtil from '../utils/DataSyncUtil';
import SubtitleUtil from '../utils/SubtitleUtil';
import SelectFileUtil from '../utils/SelectFileUtil';

import { fileIo as fs } from '@kit.CoreFileKit';
import { FolderOperator, VideoMetaDataOperator } from '../database/VideoMetaData';
import RecentPlayUtil from './RecentPlayUtil';
import { VideoListController } from '../component/VideoItemComponent/VideoItemComponent';
import FileFolderUtil from './FileFolderUtil';
import VideoUtils from './VideoUtil';

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

  public async deleteUnExistFile(item: VideoMetadata | undefined, videoListController: VideoListController,
    fileFolderSource: FileFolderDataSource) {
    if (!item) {
      return
    }
    DataSyncUtil.editingVideo = JSON.stringify(item);
    await this.deleteItem()
    SelectFileUtil.deleteVideo(item);
    await VideoMetaDataOperator.deleteItem(videoListController, fileFolderSource)
    VideoUtils.refresh(videoListController, fileFolderSource, videoListController.folder)
  }

  async deleteItem(): Promise<void> {
    const tmp = JSON.parse(DataSyncUtil.editingVideo) as VideoMetadata;
    await SubtitleUtil.deleteSubtitle(PathUtils.subtitlePath, tmp.date!)
    this.deleteData(this.data.findIndex(i => i.date === tmp.date));
    RecentPlayUtil.delData(PathUtils.appContext!, tmp);

    return new Promise<void>((resolve, reject) => {
      fs.access(PathUtils.coverPath + tmp.date, (err) => {
        if (!err) {
          fs.unlink(PathUtils.coverPath + tmp.date, (unlinkErr) => {
            if (unlinkErr) {
              if (unlinkErr.code == 13900002) {
                resolve();
              } else {
                reject(new Error(`删除封面失败: ${unlinkErr.message}`));
              }
            } else {
              resolve();
            }
          });
        } else {
          resolve(); // 文件不存在也算删除成功
        }
      });
    });
  }
}

@Observed
export class FileFolderDataSource extends BaseDataSource<FileFolder> {
  getFileFolder(fileFolderName: string): FileFolder {
    return Preferences.getFileFolder(PathUtils.appContext!).find(item => item.name === fileFolderName)!
  }
}