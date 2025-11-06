import { FileFolder } from '../interfaces/FileFolderInterface';
import { VideoMetadata } from '../interfaces/VideoMetadataInterface';
import Preferences from '../database/Preferences';
import { PathUtils } from './PathUtils';
import DataSyncUtil from '../utils/DataSyncUtil';
import SubtitleUtil from '../utils/SubtitleUtil';
import SelectFileUtil from '../utils/SelectFileUtil';

import { FolderOperator, VideoMetaDataOperator } from '../database/VideoMetaData';
import RecentPlayUtil from './RecentPlayUtil';
import { VideoListController } from '../component/VideoItemComponent/VideoItemComponent';
import VideoUtils from './VideoUtil';
import { AudioTrack } from '../interfaces/AudioTrackInterface';
import { DeleteType } from '../common/enum/DeleteType';
import { fileManagerService } from '@kit.FileManagerServiceKit';
import { BusinessError } from '@kit.BasicServicesKit';
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

@Observed
export class SpeedDataSource extends BaseDataSource<number> {
}

@Observed
export class AudioTrackSource extends BaseDataSource<AudioTrack> {
}

@Observed
export class PlayerSideBarSource extends BaseDataSource<VideoMetadata> {
}

@Observed
export class SpeedListDataSource extends BaseDataSource<string> {
}

@Observed
export class DeletedVideosDataSource extends BaseDataSource<VideoMetadata> {
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
    await this.deleteItem(DeleteType.SOFT)
    SelectFileUtil.deleteVideo(item);
    await VideoMetaDataOperator.deleteItem(videoListController, fileFolderSource, DeleteType.SOFT)
    VideoUtils.refresh(videoListController, fileFolderSource, videoListController.folder)
  }

  async deleteItem(deleteType: DeleteType): Promise<void> {
    const item = JSON.parse(DataSyncUtil.editingVideo) as VideoMetadata;
    await SubtitleUtil.deleteSubtitle(PathUtils.subtitlePath, item.date!)
    this.deleteData(this.data.findIndex(i => i.date === item.date));
    RecentPlayUtil.delData(PathUtils.appContext!, item.uri);
    await SelectFileUtil.deleteCover(item.date)

    if (deleteType == DeleteType.HARD) {
      fs.unlink(item.uri, (err: BusinessError) => {
        if (err) {
          console.error("remove file failed with error message: " + err.message + ", error code: " + err.code);
        } else {
          console.info("remove file succeed");
        }
      });
    } else if (deleteType == DeleteType.RECENT) {
      try {
        let trashUri: string = await fileManagerService.deleteToTrash(item.uri);
        console.info("trashUri: " + trashUri);
      } catch (err) {
        let error: BusinessError = err as BusinessError;
        console.error("delete failed, errCode:" + error.code + ", errMessage:" + error.message);
      }
    }
  }
}

@Observed
export class FileFolderDataSource extends BaseDataSource<FileFolder> {
  getFileFolder(fileFolderName: string): FileFolder {
    return Preferences.getFileFolder(PathUtils.appContext!).find(item => item.name === fileFolderName)!
  }
}