import { FileFolder } from '../interfaces/FileFolderInterface';
import { VideoMetadata } from '../interfaces/VideoMetadataInterface';
import { VideoListController } from '../controller/VideoListController';
import { FileFolderDataSource } from '../utils/DataUtil';
import { DeleteType } from '../common/enum/DeleteType';
import FileFolderUtil from '../utils/FileFolderUtil';
import { PathUtils } from '../utils/PathUtils';
import Preferences from './Preferences';
import PreferencesUtil from './PreferencesUtil';
import MediaLibraryService from '../utils/MediaLibraryService';
import ToolsUtil from '../utils/ToolsUtil';

export class VideoMetaDataOperator {
  static getVideoMetaDataByFolderName(folderName: string): VideoMetadata[] {
    const folders = Preferences.getFileFolder(PathUtils.appContext!)
    return folders.find(item => item.name === folderName)?.video_list ?? []
  }

  static migrationRootVideoMetaToRootFolder() {
    const context = PathUtils.appContext!
    const folders = Preferences.getFileFolder(context, true)
    const folder = folders.find(item => item.name === '首页')
    if (!folder) {
      const rootFolder: FileFolder = {
        name: '首页',
        date: '0',
        video_list: PreferencesUtil.getPreferencesValue(context, 'sweet_video', 'recent_video_meta_data',
          [], true) as VideoMetadata[],
        parent_date: null
      }
      Preferences.saveFileFolder(context, [rootFolder, ...folders], true)
    }
  }

  static async deleteItem(videoListController: VideoListController, fileFolderSource: FileFolderDataSource,
    deleteType: DeleteType, deleteItem: VideoMetadata) {
    // 元数据写入失败时，不先移除列表项、删除附件或处理原文件。
    if (!FileFolderUtil.delVideoInFileFolder(PathUtils.appContext!, videoListController, fileFolderSource, deleteItem)) {
      throw new Error('Video no longer exists in the folder')
    }
    await MediaLibraryService.deleteVideoResource(deleteItem, deleteType)
    if (deleteType === DeleteType.RECENT) {
      ToolsUtil.showToast(ToolsUtil.getStringResourceArgs($r('app.string.moved_to_recycle').id, deleteItem.title))
    }
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

  static updateFolderOpeningEndingTimes(folderDate: string, startTime: number, endTime: number): FileFolder[] {
    const context = PathUtils.appContext!
    const folders = Preferences.getFileFolderForUpdate(context)
    const targetFolder = folders.find(item => item.date === folderDate)
    if (!targetFolder) {
      return folders
    }
    targetFolder.video_list.forEach(video => {
      video.start_time = startTime
      video.end_time = endTime
      video.end_time_is_duration = true
    })
    Preferences.saveFileFolder(context, folders, true)
    return Preferences.getFileFolder(context, true)
  }
}
