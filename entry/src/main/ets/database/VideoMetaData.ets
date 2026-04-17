import { FileFolder } from '../interfaces/FileFolderInterface';
import { VideoMetadata } from '../interfaces/VideoMetadataInterface';
import { PathUtils } from '../utils/PathUtils';
import { VideoListController } from '../component/VideoItemComponent/VideoItemComponent';
import FileFolderUtil from '../utils/FileFolderUtil';
import { FileFolderDataSource } from '../utils/DataUtil';
import { DeleteType } from '../common/enum/DeleteType';
import { FolderRepository } from '../repository/FolderRepository';
import { VideoRepository } from '../repository/VideoRepository';

export class VideoMetaDataOperator {
  // ORM 改造：从 FolderRepository 关联查询视频，替代 Preferences.getFileFolder 的直接索引访问
  static async getVideoMetaDataByFolderName(folderName: string): Promise<VideoMetadata[]> {
    const folderRepo = FolderRepository.getInstance()
    const folder = await folderRepo.findByName(folderName)
    return folder ? folder.videos?.map(v => FileFolderUtil.toVideoMetadata(v)) || [] : []
  }

  static async deleteItem(videoListController: VideoListController, fileFolderSource: FileFolderDataSource,
    deleteType: DeleteType, deleteItem: VideoMetadata): Promise<void> {
    await videoListController.videoDataSource.deleteItem(deleteType, deleteItem);
    // ORM 改造：删除操作改为异步，确保数据库事务完成后再刷新 UI
    await FileFolderUtil.delVideoInFileFolder(PathUtils.appContext!, videoListController, fileFolderSource)
  }
}

export class FolderOperator {
  // ORM 改造：所有文件夹读取改为异步 Repository 查询
  static async getFolderByName(folderName: string): Promise<FileFolder | undefined> {
    const folderRepo = FolderRepository.getInstance()
    const folder = await folderRepo.findByName(folderName)
    return folder ? FileFolderUtil.toFileFolder(folder) : undefined
  }
  // 已移除 saveFolders 方法，文件夹持久化统一由各个 Repository / FileFolderUtil 方法负责
}
