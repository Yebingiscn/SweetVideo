import { VideoListController } from '../component/VideoItemComponent/VideoItemComponent'
import { FileFolder } from '../interfaces/FileFolderInterface'
import { FileFolderDataSource } from './DataUtil'
import { PathUtils } from './PathUtils'
import ToolsUtil from './ToolsUtil'
import FileFolderUtil from './FileFolderUtil'

export default class VideoUtils {
  // ORM 改造：refresh 方法从 Preferences.getFileFolder 改为异步调用 FileFolderUtil.getAllFolderAsync
  // 说明：UI 层在调用此方法时需要注意 await，否则可能在数据库查询完成前就尝试读取 folders 导致空数组。
  static async refresh(videoListController: VideoListController, fileFolderDataSource: FileFolderDataSource,
    folder?: FileFolder): Promise<FileFolder[]> {
    // 从 ORM 获取最新的文件夹与视频数据
    const folders: FileFolder[] = await FileFolderUtil.getAllFolderAsync(PathUtils.appContext!)
    // 更新 FileFolderDataSource（侧边栏列表）
    fileFolderDataSource.updateData([...folders])
    let currentFolder: FileFolder | undefined
    // 定位当前需要显示的 folder
    if (folder) {
      currentFolder = folders.find(item => item.name === folder.name)
    } else {
      currentFolder = folders[0]
    }
    if (!currentFolder) {
      ToolsUtil.showToast('出异常了：数据刷新失败')
      return folders
    }
    // 同步刷新 videoDataSource（右侧视频列表），即使 video_list 为空也显式更新
    videoListController.videoDataSource.updateData(currentFolder.video_list || [])
    // 更新 VideoListController 内部状态（当前 folder、列数等）
    videoListController.updateData(videoListController.videoDataSource, currentFolder!)
    return folders
  }
}