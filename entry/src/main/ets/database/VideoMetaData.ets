import { FileFolder } from '../interfaces/FileFolderInterface';
import { VideoMetadata } from '../interfaces/VideoMetadataInterface';
import { PathUtils } from '../utils/PathUtils';
import Preferences from './Preferences';
import PreferencesUtil from '../utils/PreferencesUtil';
import { VideoListController } from '../component/VideoItemComponent/VideoItemComponent';
import FileFolderUtil from '../utils/FileFolderUtil';
import { FileFolderDataSource } from '../utils/DataUtil';

export class VideoMetaDataOperator {
  static getVideoMetaDataByFolderName(folderName: string): VideoMetadata[] {
    return Preferences.getFileFolder(PathUtils.appContext!).filter(item => item.name === folderName)[0].video_list
  }

  static migrationRootVideoMetaToRootFolder() {
    // 判断首页Folder存不存在, 迁移数据到FileFolder中
    const folder = Preferences.getFileFolder(PathUtils.appContext!).find(item => item.name === '首页')
    if (!folder) {
      const rootFolder: FileFolder = {
        name: '首页',
        date: '0',
        video_list: PreferencesUtil.getPreferencesValue(PathUtils.appContext!, 'sweet_video', 'recent_video_meta_data',
          []) as VideoMetadata[]
      }
      Preferences.saveFileFolder(PathUtils.appContext!,
        [rootFolder, ...Preferences.getFileFolder(PathUtils.appContext!)])
    }
  }

  static async deleteItem(videoListController: VideoListController, fileFolderSource: FileFolderDataSource) {
    await videoListController.videoDataSource.deleteItem();
    FileFolderUtil.delVideoInFileFolder(PathUtils.appContext!, videoListController, fileFolderSource)
  }
}

export class FolderOperator {
  static getFolderByName(folderName: string): FileFolder {
    return Preferences.getFileFolder(PathUtils.appContext!).find(item => item.name === folderName)!
  }

  static saveFolders(folders: FileFolder[]) {
    Preferences.saveFileFolder(PathUtils.appContext!, folders)
  }
}