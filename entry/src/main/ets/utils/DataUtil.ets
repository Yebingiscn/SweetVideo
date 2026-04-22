import { FileFolder } from '../interfaces/FileFolderInterface'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'

import { VideoListController } from '../component/VideoItemComponent/VideoItemComponent'
import { AudioTrack, SubtitleTrack } from '../interfaces/AudioTrackInterface'
import { DeleteType } from '../common/enum/DeleteType'
import { MpvAudioTrack, MpvSubtitleTrack } from '../controller/MpvController/MpvTypes'
import { salmonLogger, SalmonLogLine } from 'salmonlogger'
import Preferences from '../database/Preferences'
import { FolderOperator, VideoMetaDataOperator } from '../database/VideoMetaData'
import { PathUtils } from './PathUtils'
import RecentPlayUtil from './RecentPlayUtil'
import SelectFileUtil from './SelectFileUtil'
import SubtitleUtil from './SubtitleUtil'
import ToolsUtil from './ToolsUtil'
import VideoUtils from './VideoUtil'
import { fileManagerService } from '@kit.FileManagerServiceKit'
import { fileIo, fileUri } from '@kit.CoreFileKit'

const TAG = 'DataUtil'

// 基础数据源抽象类（泛型实现）
@ObservedV2
abstract class BaseDataSource<T> implements IDataSource {
  @Trace protected data: T[]
  private listeners: DataChangeListener[] = []

  constructor(data: T[]) {
    this.data = [...data]
  }

  // 公共方法实现
  registerDataChangeListener(listener: DataChangeListener): void {
    this.listeners.push(listener)
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const index = this.listeners.indexOf(listener)
    if (index >= 0) {
      this.listeners.splice(index, 1)
    }
  }

  updateData(newData: T[]): void {
    this.data = [...newData]
    this.notifyDataReloaded()
  }

  totalCount(): number {
    return this.data.length
  }

  getData(index: number): T {
    return this.data[index]
  }

  deleteData(index: number): void {
    if (index < 0 || index >= this.data.length) {
      return
    }
    this.data.splice(index, 1)
    this.notifyDataDelete(index)
  }

  getAllData(): T[] {
    return [...this.data]
  }

  // 增量更新单个项
  updateItem(index: number, newItem: T): void {
    if (index >= 0 && index < this.data.length) {
      this.data[index] = newItem
      this.notifyDataChange(index)
    }
  }

  // 通知方法
  protected notifyDataReloaded(): void {
    this.listeners.forEach(listener => listener.onDataReloaded())
  }

  protected notifyDataDelete(index: number): void {
    this.listeners.forEach(listener => listener.onDataDelete(index))
  }

  protected notifyDataChange(index: number): void {
    this.listeners.forEach(listener => listener.onDataChange(index))
  }
}

@ObservedV2
export class AudioTrackSource extends BaseDataSource<AudioTrack | MpvAudioTrack> {
}

@ObservedV2
export class PlayerSideBarSource extends BaseDataSource<VideoMetadata> {
}

@ObservedV2
export class DeletedVideosDataSource extends BaseDataSource<VideoMetadata> {
}

@ObservedV2
export class PrivacySpaceErrorListDataSource extends BaseDataSource<String> {
}

@ObservedV2
export class InnerSubtitleDataSource extends BaseDataSource<MpvSubtitleTrack | SubtitleTrack> {
}

@ObservedV2
export class SweetLogDataSource extends BaseDataSource<SalmonLogLine> {
}

// 具体实现类
@ObservedV2
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
    await this.deleteItem(DeleteType.SOFT, item)
    SelectFileUtil.deleteVideo(item)
    await VideoMetaDataOperator.deleteItem(videoListController, fileFolderSource, DeleteType.SOFT, item)
    VideoUtils.refresh(videoListController, fileFolderSource, videoListController.folder)
  }

  async deleteItem(deleteType: DeleteType, item: VideoMetadata): Promise<void> {
    await SubtitleUtil.deleteSubtitle(PathUtils.subtitlePath, item.date!)
    this.deleteData(this.data.findIndex(i => i.date === item.date))
    RecentPlayUtil.delData(PathUtils.appContext!, item.uri)
    await SelectFileUtil.deleteCover(item.date)

    if (deleteType == DeleteType.HARD) {
      fileIo.unlink(item.uri, (err: BusinessError) => {
        if (err) {
          salmonLogger.addLog(TAG,
            "remove file failed with error message: " + err.message + ", error code: " + err.code, true)
        } else {
          salmonLogger.addLog(TAG, "remove file succeed")
        }
      })
    } else if (deleteType == DeleteType.RECENT) {
      try {
        if (canIUse('SystemCapability.FileManagement.FileManagerService.Core')) {
          await fileManagerService.deleteToTrash(fileUri.getUriFromPath(item.uri))
        }
        ToolsUtil.showToast(item.title + ' 已经移动到回收站')
      } catch (error) {
        salmonLogger.addLog(TAG, "test delete failed, errCode:" + error.code + ", errMessage:" + error.message, true)
        ToolsUtil.showToast('视频快捷方式已删除，但移动到最近回收失败，原因是：errCode:' + error.code + ", errMessage:" +
          error.message)
      }
    }
  }
}

@ObservedV2
export class FileFolderDataSource extends BaseDataSource<FileFolder> {
  getFileFolder(fileFolderName: string): FileFolder {
    return Preferences.getFileFolder(PathUtils.appContext!).find(item => item.name === fileFolderName)!
  }
}