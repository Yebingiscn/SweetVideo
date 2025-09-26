import { VideoListController } from '../component/VideoItemComponent/VideoItemComponent';
import Preferences from '../database/Preferences';
import { FileFolder } from '../interfaces/FileFolderInterface';
import { FileFolderDataSource } from './DataUtil';
import { PathUtils } from './PathUtils';
import ToolsUtil from './ToolsUtil';

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
    if (videoListController.folder?.video_list || currentFolder) {
      videoListController.videoDataSource.updateData(currentFolder!.video_list)
      //更新VideoListController
      videoListController.updateData(videoListController.videoDataSource, currentFolder!)
    } else {
      ToolsUtil.showToast('出异常了：数据刷新失败')
    }
  }
}