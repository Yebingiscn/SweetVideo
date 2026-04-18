import { FileFolder } from '../interfaces/FileFolderInterface'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import ToolsUtil from './ToolsUtil'
import { Context } from '@kit.AbilityKit'
import { systemDateTime } from '@kit.BasicServicesKit'
import DataSyncUtil from '../utils/DataSyncUtil'
import { FileFolderDataSource } from './DataUtil'
import { VideoListController } from '../component/VideoItemComponent/VideoItemComponent'
import PrivacySpaceUtil from './PrivacySpaceUtil'
import SelectFileUtil from './SelectFileUtil'
import { ConcurrencyManagerUtil } from './FileProcessorUtil'
import RecentPlayUtil from './RecentPlayUtil'
import { PathUtils } from './PathUtils'
import SubtitleUtil from './SubtitleUtil'
import { fileIo as fs } from '@kit.CoreFileKit'
import { FolderRepository } from '../repository/FolderRepository'
import { VideoRepository } from '../repository/VideoRepository'
import { PrivacyVideoRepository } from '../repository/PrivacyVideoRepository'
import { FolderEntity } from '../entity/FolderEntity'
import { VideoEntity } from '../entity/VideoEntity'
import { salmonLogger } from 'salmonlogger'
import Preferences from '../database/Preferences'
import { SortUtil } from './SortUtil'

// 文件夹类
// ORM 改造核心文件：所有文件夹/视频的增删改查从 Preferences 迁移到 ibest-orm 的 Repository 层
export default class FileFolderUtil {
  public static duplicateVideo: number = 0

  /**
   * 将 VideoEntity 转换为 VideoMetadata
   * 字段映射：Entity (snake_case) -> Metadata (camelCase)
   * 说明：ORM 引入后，数据库实体字段使用下划线命名（如 last_position），而 UI 层接口使用驼峰命名（如 last_play），
   *      需要显式转换以保证类型安全与 UI 兼容性。
   */
  static toVideoMetadata(entity: VideoEntity): VideoMetadata {
    console.info(`[toVideoMetadata] ${entity.uri}, title=${entity.title}`)
    return {
      uri: entity.uri,
      title: entity.title,
      date: entity.date,
      size: [Number(entity.width) || 0, Number(entity.height) || 0],
      time: Number(entity.duration) || 0,
      last_play: Number(entity.lastPosition) || 0,
      format: entity.format,
      video_size: entity.fileSize,
      hdr_type: Number(entity.hdrType) || 0,
      start_time: Number(entity.startTime) || 0,
      end_time: Number(entity.endTime) || 0,
      external_subtitle_format: entity.externalSubtitle,
      pointA: Number(entity.pointA) || 0,
      pointB: Number(entity.pointB) || 0
    }
  }

  /**
   * 将 VideoMetadata 转换为 VideoEntity
   * 字段映射：Metadata (camelCase) -> Entity (snake_case)
   */
  static toVideoEntity(metadata: VideoMetadata, folderId: number): VideoEntity {
    const entity = new VideoEntity()
    entity.uri = metadata.uri
    entity.folderId = folderId
    entity.title = metadata.title
    entity.date = metadata.date
    entity.width = metadata.size[0] || 0
    entity.height = metadata.size[1] || 0
    entity.duration = metadata.time
    entity.lastPosition = metadata.last_play
    entity.format = metadata.format
    entity.fileSize = metadata.video_size
    entity.hdrType = metadata.hdr_type
    entity.startTime = metadata.start_time
    entity.endTime = metadata.end_time
    entity.externalSubtitle = metadata.external_subtitle_format
    entity.pointA = metadata.pointA
    entity.pointB = metadata.pointB
    return entity
  }

  /**
   * 将 FolderEntity 转换为 FileFolder
   */
  static toFileFolder(entity: FolderEntity): FileFolder {
    return {
      name: entity.name,
      date: entity.date,
      video_list: (entity.videos || []).map(v => FileFolderUtil.toVideoMetadata(v))
    }
  }

  /**
   * 将 FileFolder 转换为 FolderEntity（不含id）
   */
  static toFolderEntity(folder: FileFolder): FolderEntity {
    const entity = new FolderEntity()
    entity.date = folder.date
    entity.name = folder.name
    return entity
  }

  /**
   * 获取所有文件夹（从 ORM）
   * 使用 folderId 外键关联，避免字符串格式问题
   * 注意：ibest-orm 的 with('videos') 关联查询在此项目场景下存在类型推断与懒加载问题，
   *      因此采用手动遍历 folderRepo.findAll() + videoRepo.findByFolderId(id) 的方式逐文件夹加载视频。
   *      该方式虽然增加了 N+1 查询，但文件夹数量通常较少（<100），性能可接受。
   */
  static async getAllFolderAsync(context: Context): Promise<FileFolder[]> {
    const folderRepo = FolderRepository.getInstance()
    const videoRepo = VideoRepository.getInstance()

    // 获取所有文件夹（首页置顶，其他按日期排序）
    let folderEntities = (await folderRepo.findAll()).sort((a, b) => {
      if (a.name === '首页' && b.name !== '首页') {
        return -1
      }
      if (a.name !== '首页' && b.name === '首页') {
        return 1
      }
      return (Number(a.date) || 0) - (Number(b.date) || 0)
    })

    // 获取当前排序偏好
    const isPrivacy = PrivacySpaceUtil.getPrivacyMode()
    const sortType = Preferences.getVideoSortType(context, isPrivacy)
    const sortOrder = Preferences.getVideoSortOrder(context, isPrivacy)

    // 手动加载每个文件夹的视频（避免 ORM with('videos') 关联查询问题）
    for (const folder of folderEntities) {
      if (folder.id !== undefined) {
        let videos = await videoRepo.findByFolderId(folder.id, sortType, sortOrder)
        // name 排序需要在应用层处理中文拼音
        if (sortType === 'name') {
          videos = FileFolderUtil.sortVideosByPinyin(videos, sortOrder)
        } else if (sortType === 'time') {
          videos = FileFolderUtil.sortVideosByDuration(videos, sortOrder)
        }
        folder.videos = videos
        console.info(`[getAllFolderAsync] Folder ${folder.name} has ${folder.videos?.length || 0} videos`)
      }
    }

    console.info(`[FileFolderUtil] getAllFolderAsync: loaded ${folderEntities.length} folders with videos`)

    // ✅ 修复：显式声明 map 回调的返回类型，避免对象字面量类型推断问题
    return folderEntities.map((entity): FileFolder => ({
      name: entity.name,
      date: entity.date,
      video_list: (entity.videos || []).map(v => FileFolderUtil.toVideoMetadata(v))
    }))
  }

  /**
   * 根据名称查找文件夹
   */
  static async findFolderByName(context: Context, name: string): Promise<FileFolder | undefined> {
    const folderRepo = FolderRepository.getInstance()
    const folder = await folderRepo.findByName(name)
    return folder ? FileFolderUtil.toFileFolder(folder) : undefined
  }

  // 新建文件夹
  // ORM 改造：通过 FolderRepository 插入新记录，并返回最新的完整文件夹列表（含视频）
  static async createNewFolder(context: Context, folder_name: string, fileFolderSource?: FileFolderDataSource): Promise<FileFolder[]> {
    const folderRepo = FolderRepository.getInstance()

    const newFolder: FolderEntity = new FolderEntity()
    newFolder.name = folder_name
    newFolder.date = systemDateTime.getTime(false).toString()

    const exists = await folderRepo.existsByName(folder_name)
    if (!exists) {
      await folderRepo.insert(newFolder)
    } else {
      ToolsUtil.showToast('添加失败，已存在相同文件夹')
    }

    const allEntities = await folderRepo.findAllWithVideos()
    const allFolders = allEntities.map(e => FileFolderUtil.toFileFolder(e))

    if (fileFolderSource) {
      fileFolderSource.updateData(allFolders)
    }
    return allFolders
  }

  // 添加视频到文件夹，支持批量
  // ORM 改造：不再操作 Preferences 中的数组，而是通过修改 VideoEntity.folderId 外键实现视频跨文件夹移动
  static async transferVideosToFileFolder(context: Context, videos: VideoMetadata[], fromFolderDate: string,
    targetFolderDate: string): Promise<FileFolder[]> {
    const folderRepo = FolderRepository.getInstance()
    const videoRepo = VideoRepository.getInstance()

    const fromFolder = await folderRepo.findByDate(fromFolderDate)
    const targetFolder = await folderRepo.findByDate(targetFolderDate)

    if (!fromFolder || !targetFolder) {
      return FileFolderUtil.getAllFolderAsync(context)
    }

    // 创建目标视频集合用于快速查找
    const targetVideoSet = new Set(targetFolder.videos?.map(v => v.uri) || [])
    // 创建待移动视频集合
    const videosToMove = new Set(videos.map(v => v.uri))

    // 批量更新：从源文件夹删除视频
    for (const videoUri of videosToMove) {
      const video = fromFolder.videos?.find(v => v.uri === videoUri)
      if (video && targetFolder.id !== undefined) {
        video.folderId = targetFolder.id
        await videoRepo.save(video)
      }
    }

    return FileFolderUtil.getAllFolderAsync(context)
  }

  // 批量删除文件夹中的视频（多选删除场景）
  // ORM 改造：通过 surviveVideo Map 计算需要保留的视频，对其余视频调用 videoRepo.delete 删除
  static async delVideosFileFolder(context: Context, videoListController: VideoListController,
    folderDataSource: FileFolderDataSource): Promise<FileFolder | undefined> {
    const folderRepo = FolderRepository.getInstance()
    const videoRepo = VideoRepository.getInstance()

    const folder = await folderRepo.findByDate(videoListController.folder.date)
    if (!folder) {
      return undefined
    }

    const surviveVideo = new Map<string, VideoEntity>()
    for (const video of folder.videos || []) {
      surviveVideo.set(video.uri, video)
    }

    for (const item of DataSyncUtil.delMultipleList) {
      if (!item.date) {
        continue
      }
      RecentPlayUtil.delData(PathUtils.appContext!, item.uri)
      await SubtitleUtil.deleteSubtitle(PathUtils.subtitlePath, item.date)
      await SelectFileUtil.deleteCover(item.date)
      surviveVideo.delete(item.uri)
    }

    // 删除不在存活列表中的视频
    for (const video of folder.videos || []) {
      if (!surviveVideo.has(video.uri)) {
        await videoRepo.delete(video)
      }
    }

    if (folder.id === undefined) {
      return undefined
    }

    const updatedFolder = await folderRepo.findById(folder.id)
    const fileFolder = updatedFolder ? FileFolderUtil.toFileFolder(updatedFolder) : undefined

    if (fileFolder) {
      videoListController.updateData(undefined, fileFolder)
    }

    const allFolders = await FileFolderUtil.getAllFolderAsync(context)
    folderDataSource.updateData(allFolders)

    return fileFolder
  }

  static async delVideoInFileFolder(context: Context, videoListController: VideoListController,
    folderDataSource: FileFolderDataSource): Promise<FileFolder | undefined> {
    const folderRepo = FolderRepository.getInstance()
    const videoRepo = VideoRepository.getInstance()

    const videoMetaData = DataSyncUtil.editingVideo
    if (!videoMetaData) {
      return undefined
    }

    const folder = await folderRepo.findByDate(videoListController.folder.date)
    if (!folder || folder.id === undefined) {
      return undefined
    }

    const videoToDelete = folder.videos?.find(v => v.uri === videoMetaData.uri)
    if (videoToDelete) {
      await videoRepo.delete(videoToDelete)
    }

    const updatedFolder = await folderRepo.findById(folder.id)
    const fileFolder = updatedFolder ? FileFolderUtil.toFileFolder(updatedFolder) : undefined

    if (fileFolder) {
      videoListController.updateData(undefined, fileFolder)
      folderDataSource.updateData(await FileFolderUtil.getAllFolderAsync(context))
    }

    return fileFolder
  }

  static async updateVideoInFileFolder(context: Context, videoListController: VideoListController,
    folderDataSource: FileFolderDataSource): Promise<void> {
    const folderRepo = FolderRepository.getInstance()
    const videoRepo = VideoRepository.getInstance()

    const videoMetaData = DataSyncUtil.editingVideo
    if (!videoMetaData) {
      return
    }

    const folder = await folderRepo.findByDate(videoListController.folder.date)
    if (!folder || folder.id === undefined) {
      return
    }

    const videoToUpdate = folder.videos?.find(v => v.date === videoMetaData.date)
    if (videoToUpdate) {
      videoToUpdate.title = videoMetaData.title
      await videoRepo.save(videoToUpdate)
    }

    const updatedFolder = await folderRepo.findById(folder.id)
    if (updatedFolder) {
      videoListController.updateData(undefined, FileFolderUtil.toFileFolder(updatedFolder))
      folderDataSource.updateData(await FileFolderUtil.getAllFolderAsync(context))
    }
  }

  // 删除文件夹
  static async deleteFileFolder(context: Context, file_folder: FileFolder, fileDataSource?: FileFolderDataSource): Promise<FileFolder[]> {
    const folderRepo = FolderRepository.getInstance()
    const videoRepo = VideoRepository.getInstance()
    const folder = await folderRepo.findByDate(file_folder.date)

    if (folder) {
      // 级联删除：先删除该文件夹下的所有视频
      if (folder.id !== undefined) {
        const videos = await videoRepo.findByFolderId(folder.id)
        for (const video of videos) {
          await videoRepo.delete(video)
        }
      }
      await folderRepo.delete(folder)
    }

    const allFolders = await FileFolderUtil.getAllFolderAsync(context)
    if (fileDataSource) {
      fileDataSource.updateData(allFolders)
    }
    return allFolders
  }

  // 改变文件夹名称
  static async changeFileFolderName(context: Context, folder: FileFolder, newFolderName: string,
    fileFolderDataSource: FileFolderDataSource): Promise<void> {
    const folderRepo = FolderRepository.getInstance()

    const folderEntity = await folderRepo.findByDate(folder.date)
    if (folderEntity) {
      folderEntity.name = newFolderName
      await folderRepo.save(folderEntity)
    }

    const allFolders = await FileFolderUtil.getAllFolderAsync(context)
    fileFolderDataSource.updateData(allFolders)
  }

  // 更新文件夹内视频（不再使用 sortOrder，保留方法用于视频列表更新）
  static async updateFileFolder(context: Context, folder: FileFolder, newVideoMetaDataList: VideoMetadata[]): Promise<void> {
    const folderRepo = FolderRepository.getInstance()
    const videoRepo = VideoRepository.getInstance()

    const folderEntity = await folderRepo.findByDate(folder.date)
    if (!folderEntity || folderEntity.id === undefined) {
      return
    }

    // 保存id到局部变量，避免在闭包中类型检查问题
    const folderId = folderEntity.id

    // 先删除该文件夹的所有视频
    const existingVideos = await videoRepo.findByFolderId(folderId)
    for (const video of existingVideos) {
      await videoRepo.delete(video)
    }

    // 插入新视频列表
    const newEntities = newVideoMetaDataList.map((v) =>
      FileFolderUtil.toVideoEntity(v, folderId)
    )
    if (newEntities.length > 0) {
      await videoRepo.insertBatch(newEntities)
    }
  }

  // 检查文件夹中是否存在指定视频（用于导入去重）
  // ORM 改造：隐私空间模式下使用 originalUri 去重（因为 uri 字段存储的是应用私有 sandbox 路径，不是原始路径）
  // 普通模式下使用标准化后的 URI 去重，同时兼容旧数据中的原始 URI
  static async existsVideoInFolders(context: Context, uri: string, title: string): Promise<boolean> {
    const videoRepo = VideoRepository.getInstance()
    const privacyRepo = PrivacyVideoRepository.getInstance()

    // ✅ 标准化URI（去掉查询参数等差异）
    const normalizedUri = ConcurrencyManagerUtil.normalizeUri(uri)

    // ✅ 添加详细诊断日志
    console.info(`[existsVideoInFolders] 输入URI: ${uri}`)
    console.info(`[existsVideoInFolders] 标准化URI: ${normalizedUri}`)
    console.info(`[existsVideoInFolders] 隐私模式: ${PrivacySpaceUtil.getPrivacyMode()}`)

    let exists: boolean
    if (PrivacySpaceUtil.getPrivacyMode()) {
      // ✅ 隐私空间：使用原始 URI (originalUri) 去重，因为保存的是隐私空间路径
      exists = await privacyRepo.existsByOriginalUri(normalizedUri)
    } else {
      // ✅ 普通模式：同时检查标准化和原始URI（兼容旧数据）
      const normalizedExists = await videoRepo.existsByUri(normalizedUri)
      const allVideo = await videoRepo.findAll()
      const originalExists = uri !== normalizedUri ? await videoRepo.existsByUri(uri) : false
      exists = normalizedExists || originalExists
      console.info(`[existsVideoInFolders] 标准化检查: ${normalizedExists}, 原始检查: ${originalExists}`)
    }

    console.info(`[existsVideoInFolders] 是否存在: ${exists}`)

    if (exists) {
      FileFolderUtil.duplicateVideo++
      // ✅ 添加提示：记录被跳过的重复视频
      salmonLogger.addLog('FileFolderUtil', `跳过重复视频: ${title}`, false)
    }
    return exists
  }

  static extractRootFolderNameFromUri(uri: string, fileName: string): string | undefined {
    const prefix = SelectFileUtil.fileFolderUri + "/"
    if (!uri.startsWith(SelectFileUtil.fileFolderUri) || !uri.startsWith(prefix)) {
      return undefined
    }
    const relativePath = uri.substring(prefix.length)
    // 必须以文件名结尾
    if (!relativePath.endsWith(fileName)) {
      return undefined
    }
    const dirPath = relativePath.substring(0, relativePath.length - fileName.length)
    const cleanDir = dirPath.replace(/\/+$/, "") // 移除尾部斜杠
    if (!cleanDir) {
      return undefined
    }
    const parts = cleanDir.split("/")
    return parts[0] || undefined
  }

  // 检查文件夹是否存在
  /**
   * 按拼音对视频列表进行排序（支持中文自然排序）
   * 使用 SortUtil 通用排序工具
   * @param videos 视频实体数组
   * @param order 排序方向：'asc' 升序(A-Z)，'desc' 降序(Z-A)
   * @returns 排序后的视频数组
   */
  static sortVideosByPinyin(videos: VideoEntity[], order: 'asc' | 'desc' = 'desc'): VideoEntity[] {
    return SortUtil.sortByPinyin(videos, (v) => v.title, order)
  }

  /**
   * 按时长对视频列表进行排序
   * 使用 SortUtil 通用排序工具
   * @param videos 视频实体数组
   * @param order 排序方向：'asc' 升序(短→长)，'desc' 降序(长→短)
   * @returns 排序后的视频数组
   */
  static sortVideosByDuration(videos: VideoEntity[], order: 'asc' | 'desc' = 'desc'): VideoEntity[] {
    return SortUtil.sortByDuration(videos, (v) => v.duration, order)
  }

  static fileFolderExistCheck(): void {
    const paths = [
      PathUtils.videoPath,
      PathUtils.subtitlePath,
      PathUtils.photoPath
    ]

    paths.forEach(path => {
      try {
        if (!fs.accessSync(path)) {
          fs.mkdirSync(path)
        }
      } catch (error) {
        console.error(`Failed to create directory ${path}:`, error)
      }
    })
  }
}
