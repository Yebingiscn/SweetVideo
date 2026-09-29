import FolderHierarchy from './FolderHierarchy'
import Preferences from '../database/Preferences'
import { FileFolder } from '../interfaces/FileFolderInterface'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import ToolsUtil from './ToolsUtil'
import { Context } from '@kit.AbilityKit'
import { BusinessError, systemDateTime } from '@kit.BasicServicesKit'
import DataSyncUtil from '../utils/DataSyncUtil'
import { FileFolderDataSource } from './DataUtil'
import { VideoListController } from '../component/VideoItemComponent/VideoItemComponent'
import SelectFileUtil from './SelectFileUtil'
import { PathUtils } from './PathUtils'
import { salmonLogger } from 'salmonlogger'
import PrivacySpaceUtil from './PrivacySpaceUtil'
import VideoOperateUtil from './VideoOperateUtil'
import fileIo from '@ohos.file.fs'
import { DeleteType } from '../common/enum/DeleteType'
import { SortField } from '../common/enum/SortField'
import SubtitleUtil from './SubtitleUtil'
import { DanmakuStorage } from './DanmakuStorage'

const TAG = 'FileFolderUtil'

// 文件夹类
export default class FileFolderUtil {
  public static duplicateVideo: number = 0

  static getAllFolder(context: Context): FileFolder[] {
    return Preferences.getFileFolder(context) as FileFolder[]
  }

  //新建文件夹
  static createNewFolder(context: Context, folder_name: string, parent_date: string | null = null): FileFolder[] {
    const file_folder_list = Preferences.getFileFolder(context) as FileFolder[]
    const new_folder: FileFolder = {
      name: folder_name,
      date: FolderHierarchy.createId(file_folder_list),
      video_list: [],
      parent_date: parent_date,
    }
    if (!file_folder_list.some(i => i.name === new_folder.name && i.parent_date === new_folder.parent_date)) {
      file_folder_list.push(new_folder)
      Preferences.saveFileFolder(context, file_folder_list)
    } else {
      ToolsUtil.showToast('添加失败，已存在相同文件夹')
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
    const latestFolders = Preferences.getFileFolder(context) as FileFolder[]
    let existingFolder = latestFolders.find(i => i.name === currentName && i.parent_date === parent_date)
    if (!existingFolder) {
      FileFolderUtil.createNewFolder(context, currentName, parent_date)
      const updatedFolders = Preferences.getFileFolder(context) as FileFolder[]
      existingFolder = updatedFolders.find(i => i.name === currentName && i.parent_date === parent_date)
    }
    if (pathParts.length === 1) {
      return existingFolder
    }
    return FileFolderUtil.createFolderPath(context, pathParts.slice(1), existingFolder!.date)
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
  static async deleteFileFolderRecursive(context: Context, file_folder: FileFolder,
    fileDataSource?: FileFolderDataSource): Promise<FileFolder[]> {
    let folders = Preferences.getFileFolder(context)
    const datesToDelete = FolderHierarchy.descendants(folders, file_folder.date)
    const videos = new Map<string, VideoMetadata>()
    for (const folder of folders) {
      if (datesToDelete.has(folder.date)) {
        for (const video of folder.video_list ?? []) {
          if (video.date) {
            videos.set(video.date, video)
          }
        }
      }
    }
    await VideoOperateUtil.deleteVideoFiles(Array.from(videos.values()), DeleteType.SOFT)
    folders = Preferences.getFileFolder(context).filter(i => !datesToDelete.has(i.date))
    Preferences.saveFileFolder(context, folders)
    if (fileDataSource) {
      fileDataSource.updateData(folders)
    }
    return folders
  }

  // 添加视频到文件夹，支持批量
  static transferVideosToFileFolder(context: Context, videos: VideoMetadata[], fromFolderDate: string,
    targetFolderDate: string): FileFolder[] {
    const folders = Preferences.getFileFolder(context) || []
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
    if (!fromFolder || !targetFolder) {
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
        targetFolder.video_list = ToolsUtil.sortByNameProcess(targetFolder.video_list, sortAsc, pinyinSort)
        break
      case SortField.DATETIME:
        targetFolder.video_list = ToolsUtil.sortByDatetimeProcess(targetFolder.video_list, sortAsc)
        break
      case SortField.TIME:
        targetFolder.video_list = ToolsUtil.sortByTimeProcess(targetFolder.video_list, sortAsc)
        break
    }
    // 保存并返回
    Preferences.saveFileFolder(context, folders)
    return folders
  }

  static async delVideosFileFolder(context: Context, videoListController: VideoListController,
    folderDataSource: FileFolderDataSource, deleteType: DeleteType = DeleteType.SOFT) {
    let folders = Preferences.getFileFolder(context) as FileFolder[]
    let folderIndex = folders.findIndex(i => i.date === videoListController.folder.date)
    const folder = folders[folderIndex]
    const surviveVideo = new Map<string, VideoMetadata>()
    for (const video of folder.video_list) {
      surviveVideo.set(video.uri, video)
    }
    await VideoOperateUtil.deleteVideoFiles(DataSyncUtil.delMultipleList, deleteType)
    for (const item of DataSyncUtil.delMultipleList) {
      surviveVideo.delete(item.uri)
    }
    folder.video_list = Array.from(surviveVideo.values())
    folders[folderIndex] = folder
    Preferences.saveFileFolder(context, folders)
    videoListController.updateData(undefined, folders[folderIndex])
    folderDataSource.updateData(folders)
    return folders[folderIndex]
  }

  static delVideoInFileFolder(context: Context, videoListController: VideoListController,
    folderDataSource: FileFolderDataSource) {
    const videoMetaData = DataSyncUtil.editingVideo
    let folders = Preferences.getFileFolder(context) as FileFolder[]
    let folderIndex = folders.findIndex(i => i.date === videoListController.folder.date)
    if (folderIndex !== -1) {
      folders[folderIndex].video_list =
        folders[folderIndex].video_list.filter(item => item.date !== videoMetaData?.date)
      videoListController.updateData(undefined, folders[folderIndex])
      folderDataSource.updateData(folders)
      Preferences.saveFileFolder(context, folders)
    }
    return folders[folderIndex]
  }

  static updateVideoInFileFolder(context: Context, videoListController: VideoListController,
    folderDataSource: FileFolderDataSource) {
    const videoMetaData = DataSyncUtil.editingVideo
    if (!videoMetaData) {
      return
    }
    const folders = Preferences.getFileFolder(context) as FileFolder[]
    const folderIndex = folders.findIndex(i => i.date === videoListController.folder.date)
    if (folderIndex === -1) {
      return
    }
    const targetFolder = folders[folderIndex]
    let videoIndex = targetFolder.video_list.findIndex(item => item.date === videoMetaData.date)
    if (videoIndex >= 0) {
      targetFolder.video_list[videoIndex] = videoMetaData
    }
    videoListController.updateData(undefined, targetFolder)
    folderDataSource.updateData(folders)
    Preferences.saveFileFolder(context, folders)
  }

  // 删除文件夹（含子文件夹）
  static deleteFileFolder(context: Context, file_folder: FileFolder,
    fileDataSource?: FileFolderDataSource): Promise<FileFolder[]> {
    return FileFolderUtil.deleteFileFolderRecursive(context, file_folder, fileDataSource)
  }

  static moveFileFolder(context: Context, folderDate: string, targetParentDate: string | null,
    fileFolderDataSource?: FileFolderDataSource): FileFolder[] {
    // 不修改界面正在持有的对象；Repeat 必须收到新对象才能更新层级和缩进。
    const folders: FileFolder[] = Preferences.getFileFolder(context).map((folder): FileFolder => ({
      name: folder.name, date: folder.date, parent_date: folder.parent_date, video_list: folder.video_list
    }))
    if (folderDate === targetParentDate) {
      return folders
    }
    if (targetParentDate !== null) {
      if (!folders.some(folder => folder.date === targetParentDate)) {
        ToolsUtil.showToast('目标文件夹已不存在，请重新选择')
        return folders
      }
      if (FolderHierarchy.descendants(folders, folderDate).has(targetParentDate)) {
        ToolsUtil.showToast('不能移动到自身子文件夹下')
        return folders
      }
    }
    const targetFolder = folders.find(i => i.date === folderDate)
    if (targetFolder?.name === '首页' && targetFolder.parent_date === null) {
      return folders
    }
    if (targetFolder) {
      const duplicate = folders.find(i => i.name === targetFolder.name &&
        i.parent_date === targetParentDate && i.date !== targetFolder.date)
      if (duplicate) {
        ToolsUtil.showToast('目标目录下已存在同名文件夹')
        return folders
      }
      targetFolder.parent_date = targetParentDate
    }
    Preferences.saveFileFolder(context, folders)
    const savedFolders = Preferences.getFileFolder(context)
    if (fileFolderDataSource) {
      fileFolderDataSource.updateData(savedFolders)
    }
    return savedFolders
  }

  //改变文件夹名称
  static async changeFileFolderName(context: Context, folder: FileFolder, newFolderName: string,
    fileFolderDataSource: FileFolderDataSource) {
    let folders = Preferences.getFileFolder(context) as FileFolder[]
    const targetFolder = folders.find(i => i.date === folder.date)
    if (targetFolder) {
      const duplicate = folders.find(i => i.name === newFolderName && i.parent_date === targetFolder.parent_date &&
        i.date !== targetFolder.date)
      if (duplicate) {
        ToolsUtil.showToast('同一目录下已存在同名文件夹')
        return
      }
      targetFolder.name = newFolderName
    }
    Preferences.saveFileFolder(context, folders)
    fileFolderDataSource.updateData(folders)
  }

  // 更新文件夹内视频
  static updateFileFolder(context: Context, folder: FileFolder, newVideoMetaDataList: VideoMetadata[]): void {
    let folders = Preferences.getFileFolder(context) as FileFolder[]
    let folderIndex = folders.findIndex(i => i.date === folder.date)
    if (folderIndex === -1) {
      return
    }
    const oldList = folders[folderIndex].video_list
    if (newVideoMetaDataList.length === 0 && oldList && oldList.length > 0) {
      salmonLogger.addLog(TAG,
        `[test] updateFileFolder 阻止空列表覆盖 folder=${folder.name}, 旧列表长度=${oldList.length}`, true)
      return
    }
    folders[folderIndex].video_list = newVideoMetaDataList
    Preferences.saveFileFolder(context, folders)
  }

  // 更新文件夹所有内容
  static async updateFileFolderList(context: Context, file_folder: FileFolder) {
    let file_folder_list = Preferences.getFileFolder(context)
    file_folder_list = file_folder_list.filter(i => i.date !== file_folder?.date)
    file_folder_list.push(file_folder)
    Preferences.saveFileFolder(context, file_folder_list)
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

  static async cleanInvalidFiles(context: Context): Promise<number> {
    const coverResult = await fileIo.listFile(PathUtils.coverPath)?.catch(() => {
      salmonLogger.addLog(TAG, 'get cover fail', true)
    })
    const subtitleResult = await fileIo.listFile(PathUtils.subtitlePath)?.catch(() => {
      salmonLogger.addLog(TAG, 'get subtitle fail', true)
    })
    const danmakuResult = await fileIo.listFile(DanmakuStorage.directory).catch(() => {
      // 尚未导入弹幕时目录不存在。
      return [] as string[]
    })
    const validFileRegex = /^(\d|stream_|smb_)/
    const coverFromSandboxArray: string[] = Array.isArray(coverResult)
      ? coverResult.filter(file => validFileRegex.test(file) && !file.endsWith('.tmp')) : []
    const subtitleFromSandboxArray: string[] = Array.isArray(subtitleResult)
      ? subtitleResult.filter(file => validFileRegex.test(file) && !file.endsWith('.tmp')) : []
    const videoMetaData = Preferences.getVideoMetaData(context)
    const videoMetaDataEncryption = Preferences.getVideoMetaDataEncryption(context)
    const fileFolder = Preferences.getFileFolder(context)
    const networkStreams = Preferences.getNetworkStreams(context)
    const existingItemsSet = new Set<string>()
    // SMB 和从外部打开的视频可能只保存在播放历史中。
    for (const item of Preferences.getRecentPlay(context)) {
      if (item.date) {
        existingItemsSet.add(item.date)
      }
    }
    for (const v of videoMetaData) {
      existingItemsSet.add(v.date as string)
    }
    for (const v of videoMetaDataEncryption) {
      existingItemsSet.add(v.date as string)
    }
    for (const folder of fileFolder) {
      if (folder.video_list) {
        for (const item of folder.video_list) {
          if (item?.date) {
            existingItemsSet.add(item.date as string)
          }
        }
      }
    }
    for (const s of networkStreams) {
      if (s?.date) {
        existingItemsSet.add(s.date as string)
      }
    }
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
    const totalMissing = missingCoverFiles.length + missingSubtitleFiles.length + missingDanmakuFiles.length
    if (totalMissing === 0) {
      return 0
    }
    let deletedCount = 0
    const deleteTasks: Promise<void>[] = []
    for (const file of missingCoverFiles) {
      deleteTasks.push(SelectFileUtil.deleteCover(file).then(() => { deletedCount++ }).catch((err: BusinessError) => {
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
      try {
        DanmakuStorage.remove(media)
        deletedCount++
      } catch (error) {
        salmonLogger.addLog(TAG, `删除失效弹幕失败: ${error}`, true)
      }
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
