import MediaLibraryService from './MediaLibraryService'
import MediaSortUtil from './MediaSortUtil'
import { ExternalAudioStorage } from './ExternalAudioStorage'
import FolderHierarchy from './FolderHierarchy'
import FolderSelection from './FolderSelection'
import Preferences from '../database/Preferences'
import { FileFolder } from '../interfaces/FileFolderInterface'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import ToolsUtil from './ToolsUtil'
import { Context } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import DataSyncUtil from '../utils/DataSyncUtil'
import { FileFolderDataSource } from './DataUtil'
import { VideoListController } from '../controller/VideoListController'
import lazy SelectFileUtil from './SelectFileUtil'
import { PathUtils } from './PathUtils'
import { salmonLogger } from 'salmonlogger'
import PrivacySpaceUtil from './PrivacySpaceUtil'
import fileIo from '@ohos.file.fs'
import { DeleteType } from '../common/enum/DeleteType'
import { SortField } from '../common/enum/SortField'
import SubtitleUtil from './SubtitleUtil'
import { DanmakuStorage } from './DanmakuStorage'

const TAG = 'FileFolderUtil'

interface CleanupReferenceSources {
  privateVideos: VideoMetadata[]
  folders: FileFolder[]
  streams: VideoMetadata[]
  recent: VideoMetadata[]
}

// 文件夹类
export default class FileFolderUtil {
  public static duplicateVideo: number = 0

  static getAllFolder(context: Context): FileFolder[] {
    return Preferences.getFileFolder(context) as FileFolder[]
  }

  //新建文件夹
  static createNewFolder(context: Context, folder_name: string, parent_date: string | null = null): FileFolder[] {
    const file_folder_list = Preferences.getFileFolderForUpdate(context)
    if (parent_date !== null && !file_folder_list.some(folder => folder.date === parent_date)) {
      throw new Error('Parent folder no longer exists')
    }
    const new_folder: FileFolder = {
      name: folder_name,
      date: FolderHierarchy.createId(file_folder_list),
      video_list: [],
      parent_date: parent_date,
    }
    if (!file_folder_list.some(i => i.name === new_folder.name && i.parent_date === new_folder.parent_date)) {
      file_folder_list.push(new_folder)
      Preferences.saveFileFolder(context, file_folder_list, true)
      return Preferences.getFileFolder(context, true)
    } else {
      ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.folder_exists').id))
    }
    return file_folder_list
  }

  // 递归创建多级文件夹路径，返回最深层文件夹
  static async createFolderPath(context: Context, pathParts: string[], parent_date: string | null = null):
    Promise<FileFolder | undefined> {
    if (pathParts.length === 0) {
      return undefined
    }
    const currentName = pathParts[0]
    const latestFolders = Preferences.getFileFolder(context, true)
    let existingFolder = latestFolders.find(i => i.name === currentName && i.parent_date === parent_date)
    if (!existingFolder) {
      const updatedFolders = FileFolderUtil.createNewFolder(context, currentName, parent_date)
      existingFolder = updatedFolders.find(i => i.name === currentName && i.parent_date === parent_date)
    }
    if (!existingFolder) {
      throw new Error('Import target folder is unavailable')
    }
    if (pathParts.length === 1) {
      return existingFolder
    }
    return FileFolderUtil.createFolderPath(context, pathParts.slice(1), existingFolder.date)
  }

  // 获取某文件夹的所有子文件夹
  static getChildFolders(context: Context, parentDate: string): FileFolder[] {
    const folders = Preferences.getFileFolder(context) as FileFolder[]
    return folders.filter(f => f.parent_date === parentDate)
  }

  // 树形扁平化：父→子→子→下一个父，返回按树形顺序排列的文件夹列表
  static flattenTree(folders: FileFolder[]): FileFolder[] {
    return FolderHierarchy.flatten(folders)
  }

  // 获取某文件夹的同级文件夹（含自身，同一 parent_date 下）
  static getSiblingFolders(context: Context, folderDate: string): FileFolder[] {
    const folders = Preferences.getFileFolder(context) as FileFolder[]
    const current = folders.find(f => f.date === folderDate)
    if (!current) {
      return []
    }
    return folders.filter(f => f.parent_date === current.parent_date)
  }

  // 获取某文件夹的层级路径链（从根到当前）
  static getFolderPathChain(context: Context, folderDate: string): FileFolder[] {
    const folders = Preferences.getFileFolder(context) as FileFolder[]
    const chain: FileFolder[] = []
    let current = folders.find(f => f.date === folderDate)
    const visited = new Set<string>()
    while (current && !visited.has(current.date)) {
      visited.add(current.date)
      chain.unshift(current)
      if (current.parent_date) {
        current = folders.find(f => f.date === current!.parent_date)
      } else {
        current = undefined
      }
    }
    return chain
  }

  // 获取某文件夹的层级深度
  static getFolderDepth(context: Context, folderDate: string,
    folders: FileFolder[] = Preferences.getFileFolder(context)): number {
    let depth = 0
    let current = folders.find(f => f.date === folderDate)
    const visited = new Set<string>()
    while (current?.parent_date && !visited.has(current.date)) {
      visited.add(current.date)
      depth++
      current = folders.find(f => f.date === current!.parent_date)
    }
    return depth
  }

  // 删除文件夹及其所有子文件夹
  static async deleteFileFoldersRecursive(context: Context, folderDates: string[],
    fileDataSource?: FileFolderDataSource): Promise<FileFolder[]> {
    const folders = Preferences.getFileFolderForUpdate(context)
    const plan = FolderSelection.deletionPlan(folders, folderDates)
    if (plan.dates.size === 0) { return Preferences.getFileFolder(context, true) }
    // 写失败时不能先清掉仍有目录引用的播放记录和附件。
    Preferences.saveFileFolder(context, folders.filter(folder => !plan.dates.has(folder.date)), true)
    await MediaLibraryService.deleteVideoFiles(plan.videos, DeleteType.SOFT)
    // 清理期间可能另有导入或排序，不向 UI 发布等待前的快照。
    const savedFolders = Preferences.getFileFolder(context, true)
    fileDataSource?.updateData(savedFolders)
    return savedFolders
  }

  static async deleteFileFolderRecursive(context: Context, file_folder: FileFolder,
    fileDataSource?: FileFolderDataSource): Promise<FileFolder[]> {
    return FileFolderUtil.deleteFileFoldersRecursive(context, [file_folder.date], fileDataSource)
  }

  // 添加视频到文件夹，支持批量
  static transferVideosToFileFolder(context: Context, videos: VideoMetadata[], fromFolderDate: string,
    targetFolderDate: string): FileFolder[] {
    const folders = Preferences.getFileFolderForUpdate(context)
    // 单次遍历查找两个文件夹
    let fromFolder: FileFolder | undefined
    let targetFolder: FileFolder | undefined
    for (const folder of folders) {
      if (!fromFolder && folder.date === fromFolderDate) {
        fromFolder = folder
      }
      if (!targetFolder && folder.date === targetFolderDate) {
        targetFolder = folder
      }
      if (fromFolder && targetFolder) {
        break
      }
    }
    if (!fromFolder || !targetFolder || fromFolder === targetFolder) {
      return folders
    }
    // 创建目标视频集合用于快速查找
    const targetVideoSet = new Set(targetFolder.video_list.map(v => v.date))
    // 创建待移动视频集合
    const videosToMove = new Set(videos.map(v => v.date))
    // 批量过滤源文件夹视频
    fromFolder.video_list = fromFolder.video_list.filter(
      v => !videosToMove.has(v.date)
    )
    // 批量添加新视频（过滤已存在的）
    const newVideos = videos.filter(v => !targetVideoSet.has(v.date))
    targetFolder.video_list.push(...newVideos)
    // 按目标文件夹当前排序规则重新排序
    const sortField = Preferences.getSortField(context) as SortField
    const sortAsc = Preferences.getSortAsc(context)
    const pinyinSort = Preferences.getPinyinSort(context)
    switch (sortField) {
      case SortField.NAME:
        break
      case SortField.DATETIME:
        targetFolder.video_list = MediaSortUtil.sortByDatetimeProcess(targetFolder.video_list, sortAsc)
        break
      case SortField.TIME:
        targetFolder.video_list = MediaSortUtil.sortByTimeProcess(targetFolder.video_list, sortAsc)
        break
      case SortField.RECENT_PLAY:
        targetFolder.video_list = MediaSortUtil.sortByRecentPlayProcess(targetFolder.video_list, sortAsc)
        break
    }
    // Commit membership before awaiting any worker, so concurrent changes cannot resurrect moved files.
    Preferences.saveFileFolder(context, folders, true)
    if (sortField === SortField.NAME) {
      void ToolsUtil.sortBy(context, targetFolder.video_list, targetFolder, sortField, sortAsc, pinyinSort).catch(() => {})
    }
    return Preferences.getFileFolder(context, true)
  }

  static async delVideosFileFolder(context: Context, videoListController: VideoListController,
    folderDataSource: FileFolderDataSource, deleteType: DeleteType = DeleteType.SOFT) {
    const folderDate = videoListController.folder?.date
    const folders = Preferences.getFileFolderForUpdate(context)
    const folder = folders.find(item => item.date === folderDate)
    if (!folder) {
      throw new Error('Folder no longer exists')
    }
    const selectedUris = new Set(DataSyncUtil.delMultipleList.map(item => item.uri))
    const removed = folder.video_list.filter(item => selectedUris.has(item.uri))
    if (removed.length === 0) {
      return folder
    }
    folder.video_list = folder.video_list.filter(item => !selectedUris.has(item.uri))
    Preferences.saveFileFolder(context, folders, true)
    await MediaLibraryService.deleteVideoFiles(removed, deleteType)
    return FileFolderUtil.publishSavedFolder(context, folder.date, videoListController, folderDataSource)
  }

  static delVideoInFileFolder(context: Context, videoListController: VideoListController,
    folderDataSource: FileFolderDataSource, videoMetaData: VideoMetadata): boolean {
    const folders = Preferences.getFileFolderForUpdate(context)
    const folder = folders.find(item => item.date === videoListController.folder?.date)
    if (!folder || !folder.video_list.some(item => item.date === videoMetaData.date && item.uri === videoMetaData.uri)) {
      return false
    }
    folder.video_list = folder.video_list.filter(item => item.date !== videoMetaData.date)
    Preferences.saveFileFolder(context, folders, true)
    FileFolderUtil.publishSavedFolder(context, folder.date, videoListController, folderDataSource)
    return true
  }

  static updateVideoInFileFolder(context: Context, videoListController: VideoListController,
    folderDataSource: FileFolderDataSource, videoMetaData: VideoMetadata): boolean {
    const folders = Preferences.getFileFolderForUpdate(context)
    const targetFolder = folders.find(item => item.date === videoListController.folder?.date)
    if (!targetFolder) {
      return false
    }
    const videoIndex = targetFolder.video_list.findIndex(item => item.date === videoMetaData.date &&
      item.uri === videoMetaData.uri)
    if (videoIndex < 0) {
      return false
    }
    targetFolder.video_list[videoIndex] = videoMetaData
    Preferences.saveFileFolder(context, folders, true)
    FileFolderUtil.publishSavedFolder(context, targetFolder.date, videoListController, folderDataSource)
    return true
  }

  private static publishSavedFolder(context: Context, folderDate: string, videoListController: VideoListController,
    folderDataSource: FileFolderDataSource): FileFolder | undefined {
    const folders = Preferences.getFileFolder(context, true)
    const folder = folders.find(item => item.date === folderDate)
    if (folder && videoListController.folder?.date === folderDate) {
      videoListController.updateData(undefined, folder)
    }
    folderDataSource.updateData(folders)
    return folder
  }

  // 删除文件夹（含子文件夹）
  static deleteFileFolder(context: Context, file_folder: FileFolder,
    fileDataSource?: FileFolderDataSource): Promise<FileFolder[]> {
    return FileFolderUtil.deleteFileFolderRecursive(context, file_folder, fileDataSource)
  }

  static moveFileFolder(context: Context, folderDate: string, targetParentDate: string | null,
    fileFolderDataSource?: FileFolderDataSource): FileFolder[] {
    const folders = Preferences.getFileFolderForUpdate(context)
    if (folderDate === targetParentDate) {
      return folders
    }
    if (targetParentDate !== null) {
      if (!folders.some(folder => folder.date === targetParentDate)) {
        ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.target_folder_missing').id))
        return folders
      }
      if (FolderHierarchy.descendants(folders, folderDate).has(targetParentDate)) {
        ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.cannot_move_into_self').id))
        return folders
      }
    }
    const targetFolder = folders.find(i => i.date === folderDate)
    if (!targetFolder) {
      throw new Error('Folder no longer exists')
    }
    if ((targetFolder.name === '首页' && targetFolder.parent_date === null) ||
      targetFolder.parent_date === targetParentDate) {
      return folders
    }
    const duplicate = folders.find(i => i.name === targetFolder.name &&
      i.parent_date === targetParentDate && i.date !== targetFolder.date)
    if (duplicate) {
      ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.target_folder_name_exists').id))
      return folders
    }
    targetFolder.parent_date = targetParentDate
    Preferences.saveFileFolder(context, folders, true)
    const savedFolders = Preferences.getFileFolder(context, true)
    if (fileFolderDataSource) {
      fileFolderDataSource.updateData(savedFolders)
    }
    return savedFolders
  }

  //改变文件夹名称
  static async changeFileFolderName(context: Context, folder: FileFolder, newFolderName: string,
    fileFolderDataSource: FileFolderDataSource) {
    const folders = Preferences.getFileFolderForUpdate(context)
    const targetFolder = folders.find(i => i.date === folder.date)
    if (!targetFolder) {
      throw new Error('Folder no longer exists')
    }
    const duplicate = folders.find(i => i.name === newFolderName && i.parent_date === targetFolder.parent_date &&
      i.date !== targetFolder.date)
    if (duplicate) {
      ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.same_folder_name_exists').id))
      return
    }
    targetFolder.name = newFolderName
    Preferences.saveFileFolder(context, folders, true)
    fileFolderDataSource.updateData(Preferences.getFileFolder(context, true))
  }

  // 更新文件夹内视频
  static updateFileFolder(context: Context, folder: FileFolder, newVideoMetaDataList: VideoMetadata[]): void {
    const folders = Preferences.getFileFolderForUpdate(context)
    const folderIndex = folders.findIndex(i => i.date === folder.date)
    if (folderIndex === -1) {
      return
    }
    const oldList = folders[folderIndex].video_list
    if (newVideoMetaDataList.length === 0 && oldList && oldList.length > 0) {
      salmonLogger.addLog(TAG,
        `[test] updateFileFolder 阻止空列表覆盖 folder=${folder.name}, 旧列表长度=${oldList.length}`, true)
      return
    }
    folders[folderIndex].video_list = [...newVideoMetaDataList]
    Preferences.saveFileFolder(context, folders, true)
  }

  // 更新文件夹所有内容
  static async updateFileFolderList(context: Context, file_folder: FileFolder) {
    const file_folder_list = Preferences.getFileFolderForUpdate(context).filter(i => i.date !== file_folder.date)
    file_folder_list.push(file_folder)
    Preferences.saveFileFolder(context, file_folder_list, true)
  }

  static existsVideoInFolders(context: Context, uri: string, title: string,
    privateMode: boolean = PrivacySpaceUtil.getPrivacyMode() === true): boolean {
    let exists: boolean
    if (privateMode) {
      const videoMetaData = Preferences.getVideoMetaDataEncryption(context) || []
      exists = videoMetaData.some(item => item.title === title)
    } else {
      exists = Preferences.getVideoUriSet(context).has(uri)
    }
    if (exists) {
      FileFolderUtil.duplicateVideo++
    }
    return exists
  }

  static extractRootFolderNameFromUri(uri: string, fileName: string): string | undefined {
    const parts = FileFolderUtil.extractFolderPathFromUri(uri, fileName)
    return parts ? parts[0] : undefined
  }

  static extractFolderPathFromUri(uri: string, _fileName: string,
    rootUri: string = SelectFileUtil.fileFolderUri, rootFolderName?: string): string[] | undefined {
    const normalizedRootUri = rootUri.replace(/\/+$/, '')
    const prefix = normalizedRootUri + "/"
    if (!uri.startsWith(prefix)) {
      return undefined
    }
    const relativePath = uri.substring(prefix.length)
    const lastSlashIndex = relativePath.lastIndexOf('/')
    const cleanDir = lastSlashIndex >= 0 ? relativePath.substring(0, lastSlashIndex) : ''
    const parts = cleanDir.length > 0
      ? cleanDir.split("/").map((part: string) => ToolsUtil.safeDecodeURIComponent(part))
      : []
    if (rootFolderName && rootFolderName.length > 0) {
      parts.unshift(rootFolderName)
    }
    return parts.length > 0 ? parts : undefined
  }

  private static readCleanupReferenceSources(context: Context): CleanupReferenceSources {
    return {
      privateVideos: Preferences.getVideoMetaDataEncryption(context, true),
      folders: Preferences.getSavedFileFolders(context),
      streams: Preferences.getNetworkStreams(context, true),
      recent: Preferences.getRecentPlay(context, true)
    }
  }

  static async cleanInvalidFiles(context: Context): Promise<number> {
    // 引用源任一路失败都不能当成空库，先确认能完整读取再扫描沙箱附件。
    FileFolderUtil.readCleanupReferenceSources(context)
    const directories = await Promise.all([
      fileIo.listFile(PathUtils.coverPath).catch(() => {
        salmonLogger.addLog(TAG, 'get cover fail', true)
        return [] as string[]
      }),
      fileIo.listFile(PathUtils.subtitlePath).catch(() => {
        salmonLogger.addLog(TAG, 'get subtitle fail', true)
        return [] as string[]
      }),
      fileIo.listFile(DanmakuStorage.directory).catch(() => {
        // 尚未导入弹幕时目录不存在。
        return [] as string[]
      }),
      fileIo.listFile(ExternalAudioStorage.directory).catch(() => [] as string[])
    ])
    // 目录扫描期间可能发生导入或附件变更，按扫描后的最新引用计算删除集合。
    const references = FileFolderUtil.readCleanupReferenceSources(context)
    const coverResult = directories[0]
    const subtitleResult = directories[1]
    const danmakuResult = directories[2]
    const validFileRegex = /^(\d|stream_|smb_)/
    const coverFromSandboxArray: string[] = Array.isArray(coverResult)
      ? coverResult.filter(file => validFileRegex.test(file) && !file.endsWith('.tmp')) : []
    const subtitleFromSandboxArray: string[] = Array.isArray(subtitleResult)
      ? subtitleResult.filter(file => validFileRegex.test(file) && !file.endsWith('.tmp')) : []
    const existingItemsSet = new Set<string>()
    const audioReferences = new Set<string>()
    const collectReferences = (item: VideoMetadata): void => {
      if (item.date) existingItemsSet.add(item.date)
      if (item.external_audio_file) audioReferences.add(item.external_audio_file)
    }
    for (const item of references.privateVideos) collectReferences(item)
    for (const item of references.streams) collectReferences(item)
    for (const item of references.recent) collectReferences(item)
    for (const folder of references.folders) {
      for (const item of folder.video_list || []) collectReferences(item)
    }
    const audioFiles = directories[3]
    const missingAudioFiles = audioFiles.filter(file => {
      const candidate = file.replace(/\.\d+-\d+\.tmp$/, '')
      return !!ExternalAudioStorage.owner(file) && !audioReferences.has(file) &&
        !ExternalAudioStorage.pending.has(candidate)
    })
    const missingCoverFiles = coverFromSandboxArray.filter(file => !existingItemsSet.has(file))
    const missingSubtitleFiles = subtitleFromSandboxArray.filter(file => !existingItemsSet.has(file))
    salmonLogger.addLog(TAG,
      `检测到失效封面文件数：${missingCoverFiles.length}，内容：${missingCoverFiles.toString()}`, false)
    salmonLogger.addLog(TAG,
      `检测到失效字幕文件数：${missingSubtitleFiles.length}，内容：${missingSubtitleFiles.toString()}`, false)
    const missingDanmakuFiles: string[] = []
    for (const file of danmakuResult) {
      if (!file.endsWith('.xml')) {
        continue
      }
      try {
        const media = decodeURIComponent(file.slice(0, -4))
        if (media && media.length <= 200 && `${encodeURIComponent(media)}.xml` === file &&
          !existingItemsSet.has(media)) {
          missingDanmakuFiles.push(media)
        }
      } catch (_) {
        // 跳过不符合存储格式的文件。
      }
    }
    const totalMissing = missingCoverFiles.length + missingSubtitleFiles.length + missingDanmakuFiles.length +
      missingAudioFiles.length
    if (totalMissing === 0) {
      return 0
    }
    let deletedCount = 0
    const deleteTasks: Promise<void>[] = []
    for (const file of missingCoverFiles) {
      deleteTasks.push(MediaLibraryService.deleteCover(file).then(() => { deletedCount++ }).catch((err: BusinessError) => {
        salmonLogger.addLog(TAG, `删除封面失败: ${file}, ${err}`, true)
      }))
    }
    for (const file of missingSubtitleFiles) {
      deleteTasks.push(SubtitleUtil.deleteSubtitle(PathUtils.subtitlePath, file, true)
        .then(() => { deletedCount++ }).catch((err: BusinessError) => {
          salmonLogger.addLog(TAG, `删除字幕失败: ${file}, ${err}`, true)
        }))
    }
    for (const media of missingDanmakuFiles) {
      deleteTasks.push(DanmakuStorage.remove(media).then(() => { deletedCount++ }).catch((error: Error) => {
        salmonLogger.addLog(TAG, `删除失效弹幕失败: ${error}`, true)
      }))
    }
    for (const file of missingAudioFiles) {
      const candidate = file.replace(/\.\d+-\d+\.tmp$/, '')
      if (ExternalAudioStorage.pending.has(candidate)) { continue }
      deleteTasks.push(ExternalAudioStorage.removeFile(file).then(() => { deletedCount++ }).catch((_error: Error) => {
        salmonLogger.addLog(TAG, '删除失效外挂音频失败', true)
      }))
    }
    await Promise.all(deleteTasks)
    return deletedCount
  }

  // 检查文件夹是否存在
  static fileFolderExistCheck() {
    const paths = [
      PathUtils.videoPath,
      PathUtils.subtitlePath,
      PathUtils.photoPath
    ]

    paths.forEach(path => {
      try {
        if (!fileIo.accessSync(path)) {
          fileIo.mkdirSync(path)
        }
      } catch (error) {
        salmonLogger.addLog(TAG, `Failed to create directory ${path}: ` + error, true)
      }
    })
  }
}
