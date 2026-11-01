import MediaLibraryService from './MediaLibraryService'
import { SortField } from '../common/enum/SortField'
import { VideoListController } from '../controller/VideoListController'
import Preferences from '../database/Preferences'
import { FileFolder } from '../interfaces/FileFolderInterface'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import { XAnimation } from './AnimationUtil'
import { FileFolderDataSource } from './DataUtil'
import { PathUtils } from './PathUtils'
import ToolsUtil from './ToolsUtil'

export interface SwitchFolderResult {
  refreshedFolders: FileFolder[]
  currentFolder: FileFolder | undefined
}

export default class VideoUtils {
  private static requests: WeakMap<VideoListController, number> = new WeakMap()

  private static sortVisible(controller: VideoListController, folder: FileFolder, searchValue: string = ''): void {
    const version = (VideoUtils.requests.get(controller) ?? 0) + 1
    VideoUtils.requests.set(controller, version)
    const field = Preferences.getSortField(PathUtils.appContext!) as SortField
    if (!field) return
    const source = controller.videoDataSource
    const revision = source.revision
    void ToolsUtil.sortBy(PathUtils.appContext!, folder.video_list, folder, field,
      Preferences.getSortAsc(PathUtils.appContext!), Preferences.getPinyinSort(PathUtils.appContext!)).then(videos => {
      if (VideoUtils.requests.get(controller) !== version || controller.folder?.date !== folder.date ||
        controller.videoDataSource !== source || source.revision !== revision) return
      const latest = Preferences.getFileFolder(PathUtils.appContext!).find(item => item.date === folder.date)
      if (!latest) return
      const filtered = searchValue.trim() ? MediaLibraryService.getItemFromSearch(videos, searchValue) : videos
      controller.videoDataSource.updateData(filtered)
      controller.updateData(controller.videoDataSource, latest)
    }).catch(() => {})
  }

  static refresh(videoListController: VideoListController, fileFolderDataSource: FileFolderDataSource,
    folder?: FileFolder): FileFolder[] {
    const folders: FileFolder[] = Preferences.getFileFolder(PathUtils.appContext!)
    fileFolderDataSource.updateData([...folders])
    let currentFolder: FileFolder | undefined
    if (folder) {
      currentFolder = folders.find(item => item.date === folder.date) ?? folders[0]
    } else {
      currentFolder = folders[0]
    }
    if (!currentFolder) {
      ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.data_refresh_failed').id))
      return folders
    }
    if (videoListController) {
      let videos: VideoMetadata[] = currentFolder.video_list || []
      videoListController.videoDataSource.updateData(videos)
      videoListController.updateData(videoListController.videoDataSource, currentFolder!)
      VideoUtils.sortVisible(videoListController, currentFolder)
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
    const currentFolder = refreshedFolders.find(item => item.date === targetFolder.date)
    if (!currentFolder) {
      return undefined
    }
    // sortBy 会持久化顺序，必须始终传入完整列表；搜索仅影响显示。
    const filteredVideos = searchValue.trim()
      ? MediaLibraryService.getItemFromSearch(currentFolder.video_list, searchValue)
      : currentFolder.video_list
    XAnimation.runWithAnimation(() => {
      videoListController.videoDataSource.updateData(filteredVideos)
      videoListController.updateData(videoListController.videoDataSource, currentFolder)
    })
    VideoUtils.sortVisible(videoListController, currentFolder, searchValue)
    return { refreshedFolders, currentFolder }
  }
}
