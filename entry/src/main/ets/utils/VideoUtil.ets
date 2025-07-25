import { VideoListController } from '../component/VideoItemComponent/VideoItemComponent';
import Preferences from '../database/Preferences';
import { FileFolder } from '../interfaces/FileFolderInterface';
import { FileFolderDataSource } from './DataUtil';
import { PathUtils } from './PathUtils';

export default class VideoUtils {
  static refresh(videoListController: VideoListController, fileFolderDataSource: FileFolderDataSource,
    folder?: FileFolder) {
    //获取最新的folders
    const folders: FileFolder[] = Preferences.getFileFolder(PathUtils.appContext!)
    //更新FileFolderDataSource
    fileFolderDataSource.updateData(folders)
    let currentFolder: FileFolder | undefined
    //获取当前的folder
    if (folder) {
      currentFolder = folders.find(item => item.name === folder.name)
    } else {
      currentFolder = folders[0]
    }
    //更新videoDataSource
    videoListController.videoDataSource.updateData(currentFolder!.video_list)
    //更新VideoListController
    videoListController.updateData(videoListController.videoDataSource, currentFolder!)
  }
}