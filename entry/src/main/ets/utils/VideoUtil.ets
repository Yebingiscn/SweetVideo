import { VideoListController } from '../component/VideoItemComponent/VideoItemComponent'
import Preferences from '../database/Preferences'
import { FileFolder } from '../interfaces/FileFolderInterface'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import { XAnimation } from './AnimationUtil'
import { FileFolderDataSource } from './DataUtil'
import { PathUtils } from './PathUtils'
import SelectFileUtil from './SelectFileUtil'
import ToolsUtil from './ToolsUtil'

export interface SwitchFolderResult {
  refreshedFolders: FileFolder[]
  currentFolder: FileFolder | undefined
}

export default class VideoUtils {
  static refresh(videoListController: VideoListController, fileFolderDataSource: FileFolderDataSource,
    folder?: FileFolder): FileFolder[] {
    const folders: FileFolder[] = Preferences.getFileFolder(PathUtils.appContext!)
    fileFolderDataSource.updateData([...folders])
    let currentFolder: FileFolder | undefined
    if (folder) {
      currentFolder = folders.find(item => item.name === folder.name)
    } else {
      currentFolder = folders[0]
    }
    if (!currentFolder) {
      ToolsUtil.showToast('出异常了：数据刷新失败')
      return folders
    }
    if (videoListController?.folder?.video_list) {
      videoListController.videoDataSource.updateData(currentFolder.video_list || [])
      videoListController.updateData(videoListController.videoDataSource, currentFolder!)
    }
    return folders
  }

  static switchFolder(
    targetIndex: number,
    folderList: FileFolder[],
    videoListController: VideoListController,
    fileFolderSource: FileFolderDataSource,
    searchValue: string
  ): SwitchFolderResult | undefined {
    if (targetIndex < 0 || targetIndex >= folderList.length) {
      return undefined
    }
    const targetFolder = folderList[targetIndex]
    if (!targetFolder || videoListController.folder?.date === targetFolder.date) {
      return undefined
    }
    const refreshedFolders = Preferences.getFileFolder(PathUtils.appContext!)
    fileFolderSource.updateData(refreshedFolders)
    const currentFolder = fileFolderSource.getFileFolder(targetFolder.name)
    if (!currentFolder) {
      return undefined
    }
    let filteredVideos: VideoMetadata[] = currentFolder.video_list
    if (searchValue.length > 0) {
      filteredVideos = SelectFileUtil.getItemFromSearch(currentFolder.video_list, searchValue)
    }
    XAnimation.runWithAnimation(() => {
      videoListController.videoDataSource.updateData(filteredVideos)
      videoListController.updateData(videoListController.videoDataSource, currentFolder)
    })
    return { refreshedFolders, currentFolder }
  }
}