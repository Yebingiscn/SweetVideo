import { FileFolder } from '../interfaces/FileFolderInterface';
import { VideoMetadata } from '../interfaces/VideoMetadataInterface';
import { VideoListController } from '../component/VideoItemComponent/VideoItemComponent';
import { FileFolderDataSource } from '../utils/DataUtil';
import { DeleteType } from '../common/enum/DeleteType';
import FileFolderUtil from '../utils/FileFolderUtil';
import { PathUtils } from '../utils/PathUtils';
import Preferences from './Preferences';
import PreferencesUtil from './PreferencesUtil';

export class VideoMetaDataOperator {
  static getVideoMetaDataByFolderName(folderName: string): VideoMetadata[] {
    const folders = Preferences.getFileFolder(PathUtils.appContext!)
    return folders.find(item => item.name === folderName)?.video_list ?? []
  }

  static migrationRootVideoMetaToRootFolder() {
    const folders = Preferences.getFileFolder(PathUtils.appContext!)
    const folder = folders.find(item => item.name === '首页')
    if (!folder) {
      const rootFolder: FileFolder = {
        name: '首页',
        date: '0',
        video_list: PreferencesUtil.getPreferencesValue(PathUtils.appContext!, 'sweet_video', 'recent_video_meta_data',
          []) as VideoMetadata[],
        parent_date: null
      }
      Preferences.saveFileFolder(PathUtils.appContext!, [rootFolder, ...folders])
    }
  }

  static async deleteItem(videoListController: VideoListController, fileFolderSource: FileFolderDataSource,
    deleteType: DeleteType, deleteItem: VideoMetadata) {
    await videoListController.videoDataSource.deleteItem(deleteType, deleteItem);
    FileFolderUtil.delVideoInFileFolder(PathUtils.appContext!, videoListController, fileFolderSource)
  }
}

export class FolderOperator {
  static getFolderByName(folderName: string): FileFolder {
    return Preferences.getFileFolder(PathUtils.appContext!).find(item => item.name === folderName)!
  }

  static getFolderByDate(folderDate: string): FileFolder | undefined {
    return Preferences.getFileFolder(PathUtils.appContext!).find(item => item.date === folderDate)
  }

  static saveFolders(folders: FileFolder[]) {
    Preferences.saveFileFolder(PathUtils.appContext!, folders)
  }
}