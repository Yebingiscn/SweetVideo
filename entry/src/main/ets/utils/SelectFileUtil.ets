import { common, ConfigurationConstant, Context } from '@kit.AbilityKit'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { fileIo as fs, fileUri, picker } from '@kit.CoreFileKit'
import VideoInfoUtil from './VideoInfoUtil'
import { media } from '@kit.MediaKit'
import { SaveOptions, VideoMetadata } from '../interfaces/VideoMetadataInterface'
import { FileFolder } from '../interfaces/FileFolderInterface'
import ToolsUtil from './ToolsUtil'
import { image } from '@kit.ImageKit'
import PermissionUtil from './PermissionUtil'
import { VideoSource } from '../common/enum/VideoSource'
import { salmonLogger } from 'salmonlogger'
import { SUPPORT_AUDIO_FORMAT, SUPPORT_VIDEO_FORMAT } from '../common/Constants'
import Preferences from '../database/Preferences'
import FileFolderUtil from './FileFolderUtil'
import { ConcurrencyManagerUtil } from './FileProcessorUtil'
import { PathUtils } from './PathUtils'
import PrivacySpaceUtil from './PrivacySpaceUtil'
import RecentPlayUtil from './RecentPlayUtil'
import SubtitleUtil from './SubtitleUtil'
import { systemDateTime } from '@kit.BasicServicesKit'
import { PrivacyVideoRepository } from '../repository/PrivacyVideoRepository'
import { PrivacyVideoEntity } from '../entity/PrivacyVideoEntity'
import { VideoRepository } from '../repository/VideoRepository'
import { RecentPlayRepository } from '../repository/RecentPlayRepository'
import { FolderRepository } from '../repository/FolderRepository'
import { VideoEntity } from '../entity/VideoEntity'

// ORM 改造 + 导入优化：引入异步封面获取任务队列
// 原因：视频导入时同步获取封面会严重阻塞 UI，尤其是大文件或高并发场景。
// 策略：导入流程中 skipCover=true 跳过封面生成，仅保存视频元数据到 ORM；
//       将封面获取任务加入 pendingCoverTasks，由 processPendingCoverTasks 在后台串行异步处理。
interface PendingCoverTask {
  videoEntity: VideoEntity
  sandbox_path: string
  uri: string
}

const pendingCoverTasks: PendingCoverTask[] = []

const TAG = 'SelectFileUtil'

export default class SelectFileUtil {
  public static fileFolderUri = ''
  public static videoSourcePath = new Map<number, string>([
    [VideoSource.SWEET_VIDEO_DOWNLOAD_FILE, '/storage/Users/currentUser/'],
    [VideoSource.DOCUMENT_SELECT_OPTION, 'file://docs/storage/Users'],
    [VideoSource.PHOTO_SELECT_OPTION, 'file://media/Photo'],
    [VideoSource.PRIVACY_SPACE, '/data/storage/el2'],
    [VideoSource.EXTERNAL_DEVICE, 'file://docs/storage/External']
  ])
  private static queryCache = new WeakMap<VideoMetadata[], Map<string, VideoMetadata>>()

  static async selectFromFileManager(uri?: string): Promise<string[]> {
    const documentSelectOptions = new picker.DocumentSelectOptions()
    if (uri) {
      documentSelectOptions.defaultFilePathUri = uri
    }
    documentSelectOptions.fileSuffixFilters = SUPPORT_VIDEO_FORMAT.concat(SUPPORT_AUDIO_FORMAT)
    const documentViewPicker = new picker.DocumentViewPicker(PathUtils.appContext!)
    try {
      const documentSelectResult: string[] = await documentViewPicker.select(documentSelectOptions)
      return documentSelectResult.length > 0 ? documentSelectResult : [] // 返回结果或空数组
    } catch (error) {
      console.error("Error selecting files:", error)
      return [] // 捕获错误并返回空数组
    }
  }

  static async selectVideos(): Promise<string[]> {
    return SelectFileUtil.selectFromAlbum(photoAccessHelper.PhotoViewMIMETypes.VIDEO_TYPE)
  }

  static async selectPhoto(): Promise<string[]> {
    return SelectFileUtil.selectFromAlbum(photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE, 1)
  }

  static async deletePhoto(imageName: 'BackgroundImage' | 'BackgroundDarkImage') {
    fs.access(PathUtils.photoPath! + imageName).then((res: boolean) => {
      if (res) {
        fs.unlink(PathUtils.photoPath! + imageName, async (unlinkErr) => {
          if (unlinkErr) {
            ToolsUtil.showToast('删除自定义背景失败，原因是：' + unlinkErr.message)
          }
          ToolsUtil.showToast('删除自定义背景成功')
        })
      } else {
        salmonLogger.addLog(TAG, "自定义背景不存在", true)
      }
    })?.catch((err: BusinessError) => {
      salmonLogger.addLog(TAG, "access failed with error message: " + err.message + ", error code: " + err.code, true)
    })
  }

  // 获取下载文件夹路径
  static async getDownloadUri() {
    const documentViewPicker = new picker.DocumentViewPicker()
    let documentSaveResult = await documentViewPicker.save({ pickerMode: picker.DocumentPickerMode.DOWNLOAD })
    const uri = new fileUri.FileUri(documentSaveResult[0])
    SelectFileUtil.fileFolderUri = uri.path
  }

  // 导出视频文件
  static async exportFile(uri: string, title: string, format: string, context: common.UIAbilityContext) {
    let sourceFile: fs.File | null = null
    let targetFile: fs.File | null = null
    try {
      sourceFile = fs.openSync(uri)
      const saverOption = new picker.DocumentSaveOptions()
      saverOption.newFileNames = SelectFileUtil.copyFileReName(title, format)
      const documentSaveResult = await new Promise<string[]>((resolve, reject) => {
        const saver = new picker.DocumentViewPicker(context)
        saver.save(saverOption, (err: BusinessError, uris: string[]) => {
          err ? reject(err) : resolve(uris)
        })
      })
      targetFile = fs.openSync(documentSaveResult[0], fs.OpenMode.READ_WRITE)
      await fs.copyFile(sourceFile.fd, targetFile.fd)
      ToolsUtil.showToast(`导出成功: ${targetFile?.name} 路径为: ${targetFile?.path}`)
    } catch (error) {
      ToolsUtil.showToast(`导出失败，原因是：${error}`)
    } finally {
      if (sourceFile) {
        try {
          fs.closeSync(sourceFile.fd)
        } catch (e) {
          console.error('关闭源文件失败', e)
        }
      }
      if (targetFile) {
        try {
          fs.closeSync(targetFile.fd)
        } catch (e) {
          console.error('关闭目标文件失败', e)
        }
      }
    }
  }

  static getImageUri(): string {
    const currentColorMode = AppStorage.get('currentColorMode') as number
    const basePhotoPath = PathUtils.photoPath!
    // 辅助函数：安全地获取文件 URI
    // 如果文件存在返回 URI，否则返回空字符串
    const getSafeUri = (fileName: string): string => {
      const fullPath = `${basePhotoPath}${fileName}`
      try {
        if (fs.accessSync(fullPath)) {
          return fileUri.getUriFromPath(fullPath)
        }
      } catch (e) {
        // accessSync 抛出异常通常意味着权限问题或路径严重错误，视为文件不存在
        console.warn(`Failed to access image: ${fullPath}`, e)
      }
      return ''
    }
    try {
      // 1. 处理亮色模式
      if (currentColorMode === ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT) {
        return getSafeUri('BackgroundImage')
      }
      // 2. 处理暗色模式
      if (currentColorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK) {
        // 优先尝试获取暗色背景
        const darkUri = getSafeUri('BackgroundDarkImage')
        if (darkUri) {
          return darkUri
        }
        // 降级策略：如果暗色背景不存在，尝试返回亮色背景
        return getSafeUri('BackgroundImage')
      }
      // 3. 其他未定义的模式，默认返回空或根据需求返回亮色图
      return ''
    } catch (error) {
      // 捕获顶层意外错误（如 AppStorage 读取失败等）
      console.error('Unexpected error in getImageUri', error)
      return ''
    }
  }

  static saveImageToPrivacySpace(sourceFileUri: string, isDark: boolean) {
    const filePath = PathUtils.photoPath + (isDark ? 'BackgroundDarkImage' : 'BackgroundImage') // 定义完整文件路径
    try {
      let sourceFile = fs.openSync(sourceFileUri, fs.OpenMode.READ_ONLY)
      let targetFile = fs.openSync(filePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE)

      fs.copyFileSync(sourceFile.fd, targetFile.fd)

      fs.closeSync(sourceFile)
      fs.closeSync(targetFile)
    } catch (error) {
      salmonLogger.addLog(TAG, 'File operation error:' + error, true)
    }
  }

  // 保存封面，封面获取后复制到应用私有目录下
  static async saveVideoImageToSandBox(sandbox_path: string, date: string, pixelMap: image.PixelMap) {
    const filePath = sandbox_path + date
    let packer: image.ImagePacker | undefined = undefined
    let file: fs.File | undefined = undefined
    try {
      packer = image.createImagePacker()
      file = fs.openSync(filePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE)
      await packer.packToFile(pixelMap, file.fd, { format: 'image/webp', quality: 85 })
    } catch (error) {
      const err = error as BusinessError
      salmonLogger.addLog(TAG, `Failed to save cover: code ${err.code}, message: ${err.message}`, true)
      // 删除可能损坏的文件
      try {
        fs.accessSync(filePath) && fs.unlinkSync(filePath)
      } catch {
        // 忽略删除错误
      }
      // 不抛出异常，由调用方通过其他方式检测封面是否存在
    } finally {
      // 确保资源释放
      if (file) {
        try {
          fs.closeSync(file)
        } catch (e) {
          salmonLogger.addLog(TAG, 'Failed to close file: ' + e, false)
        }
      }
      if (packer) {
        try {
          packer.release()
        } catch (e) {
          salmonLogger.addLog(TAG, 'Failed to release packer: ' + e, false)
        }
      }
      // 释放 pixelMap
      try {
        pixelMap.release()
      } catch (e) {
        salmonLogger.addLog(TAG, 'Failed to release pixelMap: ' + e, false)
      }
    }
  }

  // 复制视频进入隐私空间
  // ORM 改造：将隐私空间视频元数据从 Preferences 迁移到 PrivacyVideoRepository
  // 注意：privacyRepo.save 会根据主键自动判断 insert 或 update，无需手动维护数组
  static async copyFileToPrivacySpace(context: Context, video_meta_data_encryption: VideoMetadata[], uri: string,
    sandbox_video: string, sandbox_path: string, date: string, metadata: media.AVMetadata,
    file: fs.File): Promise<VideoMetadata> {
    let sourceFile: fs.File | null = null
    let targetFile: fs.File | null = null
    try {
      sourceFile = fs.openSync(uri, fs.OpenMode.READ_ONLY)
      const targetPath = `${sandbox_video}${date}`
      targetFile = fs.openSync(targetPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE)
      await new Promise<void>((resolve, reject) => {
        // ✅ 修复：使用非空断言，因为前面已经赋值
        fs.copyFile(sourceFile!.fd, targetFile!.fd, (error) => {
          error ? reject(error) : resolve()
        })
      })
      const videoInfo =
        await VideoInfoUtil.setVideoInfo(date, targetPath, file.name, metadata, sandbox_video, sandbox_path)

      // 保存到 ORM
      const privacyRepo = PrivacyVideoRepository.getInstance()
      const entity = new PrivacyVideoEntity()
      entity.uri = videoInfo.uri
      entity.title = videoInfo.title
      entity.originalUri = uri
      entity.width = videoInfo.size[0] || 0
      entity.height = videoInfo.size[1] || 0
      entity.duration = videoInfo.time
      entity.lastPosition = videoInfo.last_play
      entity.format = videoInfo.format
      entity.fileSize = videoInfo.video_size
      entity.hdrType = videoInfo.hdr_type
      entity.importedAt = new Date().toISOString()
      await privacyRepo.save(entity)

      return videoInfo // 返回新创建的元数据对象
    } catch (error) {
      salmonLogger.addLog(TAG, `文件复制失败: ${uri}: error ${error}`, true)
      throw new Error(`隐私空间复制失败: ${error.message}`)
    } finally {
      // ✅ 修复：使用 != null 进行非空检查，避免类型问题
      if (sourceFile != null) {
        try {
          fs.closeSync(sourceFile)
        } catch (e) {
          console.error('关闭源文件失败', e)
        }
      }
      if (targetFile != null) {
        try {
          fs.closeSync(targetFile)
        } catch (e) {
          console.error('关闭目标文件失败', e)
        }
      }
    }
  }

  static copyFileReName(title: string, format: string) {
    return [title.split('.')[title.split('.').length - 1]
      == format ? title : title + '.' + format]
  }

  // 保存播放进度、AB 点、字幕等数据
  // ORM 改造：分别更新隐私空间/普通视频/最近播放三张表
  // 注意：不再通过 Preferences 保存整个数组，而是按 uri 精准定位单条记录并局部更新，避免并发覆盖问题
  static async saveData(context: Context, target_data: VideoMetadata, options: SaveOptions): Promise<void> {
    ToolsUtil.addLogger('开始保存播放数据', false, undefined, TAG)
    let save_time: number = 0
    if (target_data.time === 0 && options.totalTime) {
      target_data.time = options.totalTime
    }
    if (options.playTime) {
      const totalDuration = target_data?.time
      const endTime = target_data?.end_time
      let shouldMarkAsWatched = false
      if (totalDuration && options.playTime > totalDuration * 0.95) {
        shouldMarkAsWatched = true
        ToolsUtil.addLogger('播放进度超过95%，标记为已观看', false, undefined, TAG)
      } else if (endTime > 0 && options.playTime >= endTime) {
        shouldMarkAsWatched = true
        ToolsUtil.addLogger('播放至指定结束时间，标记为已观看', false, undefined, TAG)
      }
      save_time = shouldMarkAsWatched ? totalDuration : options.playTime
    }

    const updateEntity = (entity: PrivacyVideoEntity | VideoEntity) => {
      if (options.playTime) {
        entity.lastPosition = save_time
      }
      if (options.startTime) {
        entity.startTime = options.startTime
      }
      if (options.endTime) {
        entity.endTime = options.endTime
      }
      if (options.size?.[0]) {
        entity.width = options.size[0]
        entity.height = options.size[1]
      }
      if (options.totalTime && entity.duration === 0) {
        entity.duration = options.totalTime
      }
      if (options.pointA) {
        entity.pointA = options.pointA
      }
      if (options.pointB) {
        entity.pointB = options.pointB
      }
      if (options.subtitleMode !== undefined) {
        entity.subtitle_mode = options.subtitleMode
      }
      if (options.subtitleVisible !== undefined) {
        entity.subtitle_visible = options.subtitleVisible
      }
      if (options.subtitleAIAsrShown !== undefined) {
        entity.subtitle_ai_asr_shown = options.subtitleAIAsrShown
      }
      if (options.subtitle3DMode !== undefined) {
        entity.subtitle_3d_mode = options.subtitle3DMode
      }
      if (options.subtitleOffsetMillis !== undefined) {
        entity.subtitle_offset_millis = options.subtitleOffsetMillis
      }
      if (options.subtitleTrackId !== undefined) {
        entity.subtitle_track_id = options.subtitleTrackId
      }
    }

    if (PrivacySpaceUtil.getPrivacyMode()) {
      ToolsUtil.addLogger('当前处于隐私空间，更新隐私空间数据', false, undefined, TAG)
      const privacyRepo = PrivacyVideoRepository.getInstance()
      const entities = await privacyRepo.query().where({ uri: target_data.uri }).find()
      const entity = entities.length > 0 ? entities[0] : undefined
      if (entity) {
        updateEntity(entity)
        await privacyRepo.save(entity)
        ToolsUtil.addLogger('隐私空间数据更新完成', false, undefined, TAG)
      } else {
        ToolsUtil.addLogger('未在隐私空间中找到目标视频数据', true, undefined, TAG)
      }
      return
    }

    ToolsUtil.addLogger('更新文件夹中的视频数据', false, undefined, TAG)
    const videoRepo = VideoRepository.getInstance()
    const entities = await videoRepo.query().where({ uri: target_data.uri }).find()
    const entity = entities.length > 0 ? entities[0] : undefined
    if (entity) {
      updateEntity(entity)
      await videoRepo.save(entity)
    }
    ToolsUtil.addLogger('文件夹数据更新完成', false, undefined, TAG)

    ToolsUtil.addLogger('更新最近播放列表数据', false, undefined, TAG)
    const recentRepo = RecentPlayRepository.getInstance()
    const recentEntities = await recentRepo.query().where({ uri: target_data.uri }).find()
    const recentEntity = recentEntities.length > 0 ? recentEntities[0] : undefined
    if (recentEntity) {
      if (options.playTime) {
        recentEntity.lastPosition = save_time
      }
      await recentRepo.save(recentEntity)
    }
    ToolsUtil.addLogger('最近播放列表更新完成', false, undefined, TAG)
  }

  static async deleteVideo(videoMetaData: VideoMetadata) {
    await SelectFileUtil.deleteVideoFromFolder(videoMetaData)
    SelectFileUtil.deleteVideoEncryption(videoMetaData)
    RecentPlayUtil.delData(PathUtils.appContext!, videoMetaData.uri)
  }

  // 从文件夹中删除指定视频
  // ORM 改造：通过 VideoRepository 按实体删除，不再操作 Preferences 中的数组
  static async deleteVideoFromFolder(videoMetaData: VideoMetadata, currentFolder?: FileFolder) {
    const videoRepo = VideoRepository.getInstance()
    const folderRepo = FolderRepository.getInstance()

    if (currentFolder) {
      // 如果有指定文件夹，只从该文件夹删除
      const folder = await folderRepo.findByDate(currentFolder.date)
      if (folder && folder.videos) {
        const videoToDelete = folder.videos.find(v => v.date === videoMetaData.date)
        if (videoToDelete) {
          await videoRepo.delete(videoToDelete)
        }
      }
    } else {
      // 否则从所有文件夹中查找并删除
      const folders = await folderRepo.findAllWithVideos()
      for (const folder of folders) {
        if (folder.videos) {
          const videoToDelete = folder.videos.find(v => v.date === videoMetaData.date)
          if (videoToDelete) {
            await videoRepo.delete(videoToDelete)
            break // 找到一个就删除并退出
          }
        }
      }
    }
  }

  static async deleteVideoEncryption(videoMetaData: VideoMetadata) {
    // 更新隐私空间的数据 - 使用 Repository 删除
    const privacyRepo = PrivacyVideoRepository.getInstance()
    try {
      // 根据 date 查找视频实体
      const entities = await privacyRepo.query().where({ date: videoMetaData.date }).find()
      if (entities.length > 0) {
        await privacyRepo.delete(entities[0])
        salmonLogger.addLog(TAG, `隐私空间视频已删除: ${videoMetaData.title}`, false)
      }
    } catch (error) {
      salmonLogger.addLog(TAG, `删除隐私空间视频失败: ${error}`, true)
    }

    // 删除物理文件
    fs.access(PathUtils.videoPath + videoMetaData.date).then((res: boolean) => {
      if (res) {
        fs.unlink(PathUtils.videoPath + videoMetaData.date, async (unlinkErr) => {
          if (unlinkErr) {
            ToolsUtil.showToast('删除视频失败：' + videoMetaData.title + '原因是：' + unlinkErr.message)
          }
        })
      }
    })?.catch((err: BusinessError) => {
      salmonLogger.addLog(TAG, "access failed with error message: " + err.message + ", error code: " + err.code, true)
    })
  }

  static getItem(list: VideoMetadata[], item: string): VideoMetadata | undefined {
    if (!list || !item) {
      return undefined
    }
    if (!SelectFileUtil.queryCache.has(list)) {
      SelectFileUtil.queryCache.set(list, new Map())
    }
    const listCache = SelectFileUtil.queryCache.get(list)!
    if (listCache.has(item)) {
      return listCache.get(item)
    }
    const dateMap = new Map(list.map(i => [i.date, i]))
    const foundItem = dateMap.get(item)
    if (foundItem) {
      const typedListCache: Map<string, VideoMetadata> = listCache
      typedListCache.set(item, foundItem)
      if (typedListCache.size > (list.length >= 100 ? 100 : list.length * 0.5)) {
        const iterator: IterableIterator<string> = typedListCache.keys()
        const oldestEntry: IteratorResult<string, undefined> = iterator.next()
        if (!oldestEntry.done) {
          const oldestKey: string = oldestEntry.value
          typedListCache.delete(oldestKey)
        }
      }
    }
    return foundItem
  }

  public static async getVideoListByVideoDate(videoDate: string): Promise<[VideoMetadata | undefined, VideoMetadata[]]> {
    const folderRepo = FolderRepository.getInstance()
    const folders = await folderRepo.findAllWithVideos()
    for (const folder of folders) {
      const targetVideo = folder.videos?.find(video => video.date === videoDate)
      if (targetVideo) {
        return [FileFolderUtil.toVideoMetadata(targetVideo), folder.videos?.map(v => FileFolderUtil.toVideoMetadata(v)) ?? []]
      }
    }
    return [undefined, []]
  }

  // 获取下一个视频
  static getNextItem(list: VideoMetadata[], date: string) {
    const currentIndex = list.findIndex(i => i.date === date)
    if (currentIndex === -1) {
      return list[0]
    } // 如果没有找到当前项，返回 第一项
    let nextIndex = (currentIndex + 1) % list.length
    for (let i = 0; i < list.length; i++) {
      if (VideoInfoUtil.videoWidthAndHeightFormat(String(list[nextIndex].size)) !== '0 x 0') {
        return list[nextIndex]
      }
      nextIndex = (nextIndex + 1) % list.length // 移动到下一个索引
    }
    return list[(currentIndex + 1) % list.length] // 如果没有找到有效项，返回下一个项，0x0会自动调用其他播放核心
  }

  // 判断是否为最后一个视频
  static isLastItem(list: VideoMetadata[], date: string) {
    const currentIndex = list.findIndex(i => i.date === date)
    if (currentIndex === -1) {
      return true
    }
    return (list.length - 1) === currentIndex
  }

  static getItemFromSearch(list: VideoMetadata[], value: string): VideoMetadata[] {
    const trimmedValue = value?.trim()
    if (!trimmedValue) {
      return []
    }
    const lowerValue = trimmedValue.toLowerCase()
    return list.filter(item =>
    item.title.toLowerCase().includes(lowerValue)
    )
  }

  static getItemIndex(list: VideoMetadata[], tmp: VideoMetadata) {
    return list.findIndex(i => i.date == tmp.date)
  }

  static isPathFromSource(path: string | undefined, key: VideoSource) {
    const prefix = SelectFileUtil.videoSourcePath.get(key)
    if (!path || !prefix) {
      return false
    }
    // 标准化路径比较
    const normalizedPath = path.replace(/\\/g, '/')
    const normalizedPrefix = prefix.replace(/\\/g, '/')
    return normalizedPath.startsWith(normalizedPrefix)
  }

  // 检查文件是否存在
  static async isFileExist(uri: string, showToast: boolean) {
    await PermissionUtil.activatePermission(uri)
    if (SelectFileUtil.isPathFromSource(uri, VideoSource.EXTERNAL_DEVICE)) {
      ToolsUtil.showToast('文件需要重新授权才能继续播放，请点击确定予以授权')
      await SelectFileUtil.selectFromFileManager(uri)
    }
    try {
      await fs.open(String(uri))
      return true
    } catch (e) {
      if (showToast) {
        ToolsUtil.showToast(uri + '文件已经失效，请重新导入')
        salmonLogger.addLog('file error', 'file error: ' + e.code + ':' + e.message, true)
      }
      return false
    }
  }

  /**
   * 解析视频应保存到的目标文件夹ID
   * ORM 改造：原逻辑直接操作 Preferences 中的 folder.date；现改为通过 FolderRepository 查询或创建实体后返回 id。
   * 增加了补偿机制参数 createdFoldersForCompensation，用于导入失败时回滚自动创建的文件夹。
   */
  private static async resolveTargetFolderId(
    context: Context,
    file_folder: FileFolder | undefined,
    createdFoldersForCompensation: FileFolder[]
  ): Promise<number> {
    const folderRepo = FolderRepository.getInstance()

    // 情况1: 有指定文件夹，尝试查找或创建
    if (file_folder) {
      // 先按 date 查找
      const folderEntity = await folderRepo.findByDate(String(file_folder.date))
      if (folderEntity?.id) {
        return folderEntity.id
      }

      // 再按 name 查找
      const folders = await folderRepo.findAll()
      const matchedFolder = folders.find(f => f.name === file_folder.name)
      if (matchedFolder?.id) {
        return matchedFolder.id
      }

      // 都没找到，创建新文件夹
      const newFolders = await FileFolderUtil.createNewFolder(context, file_folder.name)
      const createdFolder = newFolders.find(f => f.name === file_folder.name)
      if (createdFolder) {
        createdFoldersForCompensation.push(createdFolder)
      }
      const createdEntity = createdFolder ? await folderRepo.findByDate(createdFolder.date) : undefined
      return createdEntity?.id ?? 0
    }

    // 情况2: 无指定文件夹，使用”首页”
    const folders = await folderRepo.findAll()
    const rootFolder = folders.find(folder => folder.name === '首页')
    if (rootFolder?.id) {
      return rootFolder.id
    }

    // 没有”首页”，创建一个
    const newFolders = await FileFolderUtil.createNewFolder(context, '首页')
    const createdRootFolder = newFolders.find(folder => folder.name === '首页')
    if (createdRootFolder) {
      createdFoldersForCompensation.push(createdRootFolder)
    }

    const fallbackFolder = createdRootFolder
      ? await folderRepo.findByDate(createdRootFolder.date)
      : await folderRepo.findByDate(newFolders[0]?.date)
    return fallbackFolder?.id ?? 0
  }

  // 单文件导入核心逻辑
  // ORM 改造 + 并发优化：
  // 1. 使用 ConcurrencyManagerUtil.getFileQueue 按 URI 串行化，避免同一文件被多个并发任务同时处理；
  // 2. 使用 global_data 互斥锁保证数据库操作原子性；
  // 3. 自动从文件路径提取文件夹名称并查找/创建；
  // 4. skipCover=true 跳过同步封面获取，改为加入 pendingCoverTasks 后台异步处理；
  // 5. 增加补偿机制：若视频保存失败，自动删除本次导入过程中新建的文件夹，避免脏数据。
  static async addFile(context: Context, sandbox_video: string, sandbox_path: string, uri: string,
    video_meta_data: VideoMetadata[], file_folder?: FileFolder) {
    // 标准化URI（去掉查询参数等差异），确保相同文件在不同来源下被识别为同一个
    const normalizedUri = ConcurrencyManagerUtil.normalizeUri(uri)

    if (canIUse('SystemCapability.Multimedia.Media.AVMetadataExtractor')) {
      await PermissionUtil.persistPermission(normalizedUri)
      try {
        const avMetadataExtractor: media.AVMetadataExtractor = await media.createAVMetadataExtractor()
        // 获取文件操作队列（按URI串行化），避免重复创建文件夹
        const fileQueue = ConcurrencyManagerUtil.getFileQueue(normalizedUri)
        await fileQueue.run(async () => {
          const file = await fs.open(normalizedUri)
          try {
            avMetadataExtractor.fdSrc = file
            const metadata = await new Promise<media.AVMetadata>((resolve, reject) => {
              avMetadataExtractor.fetchMetadata((error: BusinessError, metadata: media.AVMetadata) => {
                error ? reject(error) : resolve(metadata)
              })
            })
            // 获取全局数据锁（保证原子操作）
            const dataLock = ConcurrencyManagerUtil.getLock('global_data')
            await dataLock.acquire()
            try {
              // 自动提取文件夹名称（如果没有指定）
              if (!file_folder) {
                const folderName = FileFolderUtil.extractRootFolderNameFromUri(normalizedUri, file.name)
                if (folderName) {
                  const folderLock = ConcurrencyManagerUtil.getLock(`folder_${folderName}`)
                  await folderLock.acquire()
                  try {
                    const folderRepo = FolderRepository.getInstance()
                    const latestFolders = await folderRepo.findAllWithVideos()
                    const existingFolder = latestFolders.find(i => i.name === folderName)
                    if (!existingFolder) {
                      const newFolders = await FileFolderUtil.createNewFolder(context, folderName)
                      file_folder = newFolders.find(item => item.name === folderName)
                    } else {
                      file_folder = FileFolderUtil.toFileFolder(existingFolder)
                    }
                  } finally {
                    folderLock.release()
                  }
                }
              }

              // 检查重复视频
              const isDuplicate = await FileFolderUtil.existsVideoInFolders(context, normalizedUri, file.name)
              salmonLogger.addLog(TAG, `isDuplicate=${isDuplicate}, file_folder=${JSON.stringify(file_folder)}`, false)

              if (!isDuplicate) {
                // 事务保护：记录本次创建的文件夹，失败时执行补偿删除
                const createdFoldersForCompensation: FileFolder[] = []
                try {
                  if (PrivacySpaceUtil.getPrivacyMode()!) {
                    await SelectFileUtil.copyFileToPrivacySpace(context, video_meta_data, normalizedUri, sandbox_video,
                      sandbox_path, systemDateTime.getTime(true).toString(), metadata, file)
                  } else {
                    // 优化：skipCover=true 跳过封面获取，加快导入速度
                    const videoInfo = await VideoInfoUtil.setVideoInfo(
                      systemDateTime.getTime(true).toString(), normalizedUri, file.name, metadata,
                      sandbox_video, sandbox_path, true
                    )

                    // 使用简化后的方法解析文件夹ID
                    const targetFolderId = await SelectFileUtil.resolveTargetFolderId(
                      context, file_folder, createdFoldersForCompensation
                    )

                    // 创建视频实体并保存到 ORM
                    salmonLogger.addLog(TAG, `准备保存视频: targetFolderId=${targetFolderId}, videoTitle=${videoInfo.title}`, false)
                    const videoEntity = FileFolderUtil.toVideoEntity(videoInfo, targetFolderId)
                    salmonLogger.addLog(TAG, `视频实体: folderId=${videoEntity.folderId}, uri=${videoEntity.uri}`, false)

                    const videoRepo = VideoRepository.getInstance()
                    await videoRepo.insert(videoEntity)
                    salmonLogger.addLog(TAG, `视频保存成功到文件夹id: ${targetFolderId}`, false)

                    // 优化：将封面获取任务加入队列，后台异步处理，避免阻塞主线程和导入流程
                    pendingCoverTasks.push({
                      videoEntity: videoEntity,
                      sandbox_path: sandbox_path,
                      uri: normalizedUri
                    })
                    // 延迟执行封面获取，避免与当前导入事务竞争资源
                    const timer = setTimeout(() => {
                      SelectFileUtil.processPendingCoverTasks()
                      clearTimeout(timer)
                    }, 100)
                  }
                } catch (error) {
                  // 补偿机制：视频保存失败时，删除本次导入过程中新建的文件夹，避免留下空文件夹脏数据
                  if (createdFoldersForCompensation.length > 0) {
                    salmonLogger.addLog(TAG, `视频保存失败，执行补偿删除: ${createdFoldersForCompensation.length} 个文件夹`, true)
                    const folderRepo = FolderRepository.getInstance()
                    for (const folder of createdFoldersForCompensation) {
                      try {
                        const folderEntity = await folderRepo.findByDate(folder.date)
                        if (folderEntity) {
                          await folderRepo.delete(folderEntity)
                          salmonLogger.addLog(TAG, `补偿删除文件夹成功: ${folder.name}`, false)
                        }
                      } catch (cleanupError) {
                        salmonLogger.addLog(TAG, `补偿删除文件夹失败: ${folder.name}, error: ${cleanupError}`, true)
                      }
                    }
                  }
                  // ArkTS 要求 throw 的值必须是 Error 类型
                  if (error instanceof Error) {
                    throw error
                  } else {
                    throw new Error(String(error))
                  }
                }
              }
            } finally {
              dataLock.release()
            }
          } finally {
            try {
              // 先关闭文件，再释放提取器（符合资源依赖顺序）
              fs.closeSync(file)
            } catch (error) {
              console.error('关闭文件出错，原因是：' + error)
            }
            try {
              avMetadataExtractor.release?.()?.catch(() => {
                salmonLogger.addLog(TAG, 'avMetadataExtractor release error', true)
              })
            } catch (error) {
              console.error('释放提取器出错，原因是：' + error)
            }
          }
        })
      } catch (error) {
        salmonLogger.addLog(TAG, 'createAVMetadataExtractor 发生错误, 原因是：' + error, true)
      }
    }
  }

  static async processSingleFile(uri: string, context: Context, sandbox_video: string, sandbox_path: string,
    video_meta_data: VideoMetadata[], fileFolder?: FileFolder): Promise<void> {
    await SelectFileUtil.addFile(
      context,
      sandbox_video,
      sandbox_path,
      uri,
      video_meta_data,
      fileFolder
    )
  }

  static async deletePrivacyVideo(date: string, title: string) {
    await SelectFileUtil.deleteCover(date)
    await SubtitleUtil.deleteSubtitle(PathUtils.subtitlePath, date)
    // 从 Repository 删除视频记录
    const privacyRepo = PrivacyVideoRepository.getInstance()
    try {
      const entities = await privacyRepo.query().where({ date: date }).find()
      if (entities.length > 0) {
        await privacyRepo.delete(entities[0])
        salmonLogger.addLog(TAG, `隐私空间视频记录已删除: ${title}`, false)
      }
    } catch (error) {
      salmonLogger.addLog(TAG, `删除隐私空间视频记录失败: ${error}`, true)
    }
    try {
      await fs.unlink(PathUtils.videoPath + date)
      ToolsUtil.showToast('删除成功')
    } catch (err) {
      const error = err as BusinessError
      if (error.code === 13900002) { // 文件或目录不存在错误码
        salmonLogger.addLog(TAG, 'file not exist', false)
      } else {
        salmonLogger.addLog(TAG, 'delete failed: ' + error.code + ':' + error.message, true)
      }
      ToolsUtil.showToast('删除视频失败：' + title + '原因是：' + err)
    }
  }

  // 删除封面
  static async deleteCover(date: string) {
    await new Promise<void>((resolve, reject) => {
      fs.access(PathUtils.coverPath + date, (err) => {
        if (!err) {
          fs.unlink(PathUtils.coverPath + date, (unlinkErr) => {
            if (unlinkErr) {
              if (unlinkErr.code == 13900002) {
                resolve()
              } else {
                reject(new Error(`删除封面失败: ${unlinkErr.message}`))
              }
            } else {
              resolve()
            }
          })
        } else {
          resolve() // 文件不存在也算删除成功
        }
      })
    })
  }

  static async getDownloadFilesUri(): Promise<string[]> {
    const VIDEO_EXTENSIONS = new Set([
      ...SUPPORT_VIDEO_FORMAT,
      ...SUPPORT_AUDIO_FORMAT
    ].map(ext => ext.toLowerCase()))

    class ConcurrencyPool {
      private active = 0
      private pending: Array<() => void> = []
      private concurrency: number

      constructor(concurrency: number) {
        this.concurrency = concurrency
      }

      async run<T>(task: () => Promise<T>): Promise<T> {
        // 如果当前活跃任务数达到并发上限，等待
        if (this.active >= this.concurrency) {
          await new Promise<void>(resolve => {
            this.pending.push(resolve)
          })
        }
        this.active++
        try {
          return await task()
        } finally {
          this.active--
          // 唤醒下一个等待的任务
          this.pending.shift()?.()
        }
      }

      async drain() {
        // 等待所有活跃任务完成
        while (this.active > 0 || this.pending.length > 0) {
          await new Promise<void>((resolve) => setTimeout(resolve, 10))
        }
      }
    }

    // 更高效的扩展名提取函数
    const isVideoFile = (filePath: string): boolean => {
      const lastDotIndex = filePath.lastIndexOf('.')
      if (lastDotIndex === -1) {
        return false
      }
      const ext = filePath.slice(lastDotIndex + 1).toLowerCase()
      return VIDEO_EXTENSIONS.has(ext)
    }
    const dirPool = new ConcurrencyPool(48) // 目录遍历并发控制
    const filePaths: string[] = []
    const processedPaths = new Set<string>() // 避免重复处理

    const collectFiles = async (directory: string): Promise<void> => {
      if (processedPaths.has(directory)) {
        return
      }
      processedPaths.add(directory)
      try {
        const entries: string[] = await fs.listFile(directory)
        // 批量处理条目，提高效率
        const batchSize = 50
        for (let i = 0; i < entries.length; i += batchSize) {
          const batch = entries.slice(i, i + batchSize)
          const batchPromises = batch.map(async (entry: string) => {
            const fullPath: string = `${directory}/${entry}`.replace(/\/+/g, '/') // 规范化路径
            try {
              const stat = await fs.stat(fullPath)
              if (stat.isFile()) {
                // 同步判断文件类型，避免不必要的异步开销
                if (isVideoFile(fullPath)) {
                  filePaths.push(fullPath)
                }
              } else if (stat.isDirectory()) {
                // 目录遍历使用线程池控制并发
                await dirPool.run(() => collectFiles(fullPath))
              }
            } catch (error) {
              salmonLogger.addLog(TAG, `Failed to process ${fullPath}: ${error}`, true)
            }
          })
          // 等待当前批次完成，避免内存溢出
          await Promise.allSettled(batchPromises)
        }
      } catch (error) {
        salmonLogger.addLog(TAG, `Failed to list directory ${directory}: ${error}`, true)
      }
    }
    try {
      await collectFiles(SelectFileUtil.fileFolderUri)
      await dirPool.drain() // 等待所有目录遍历任务完成
      // 去重并返回结果
      return Array.from(new Set(filePaths))
    } catch (error) {
      salmonLogger.addLog(TAG, `Root directory processing failed: ${error}`, true)
      return []
    }
  }

  private static async selectFromAlbum(mimeType: photoAccessHelper.PhotoViewMIMETypes,
    maxSelect: number = Number.MAX_SAFE_INTEGER): Promise<string[]> {
    const options = new photoAccessHelper.PhotoSelectOptions()
    options.MIMEType = mimeType
    options.maxSelectNumber = maxSelect
    options.isPhotoTakingSupported = false
    try {
      const picker = new photoAccessHelper.PhotoViewPicker()
      const result: photoAccessHelper.PhotoSelectResult = await picker.select(options)
      return result.photoUris || []
    } catch (error) {
      salmonLogger.addLog(TAG, `Error selecting media [${mimeType}]:${error}`, true)
      return []
    }
  }
  // 异步处理封面获取任务队列
  // 设计说明：封面提取是 CPU/IO 密集型操作，串行处理可避免内存峰值过高；
  //         每个任务间隔 50ms，给主线程留出响应时间，防止 UI 卡顿。
  private static isProcessingCovers = false

  private static async processPendingCoverTasks(): Promise<void> {
    if (SelectFileUtil.isProcessingCovers || pendingCoverTasks.length === 0) {
      return
    }

    SelectFileUtil.isProcessingCovers = true
    salmonLogger.addLog(TAG, `开始异步处理 ${pendingCoverTasks.length} 个封面任务`, false)

    // 复制当前任务列表并清空原队列，防止处理过程中新任务被当前批次遗漏或重复处理
    const tasks = [...pendingCoverTasks]
    pendingCoverTasks.length = 0

    // 串行处理封面任务，避免并发过高导致内存不足或 UI 卡顿
    for (const task of tasks) {
      try {
        await VideoInfoUtil.fetchCoverAndFileSizeAsync(task.videoEntity, task.sandbox_path, task.uri)
        // 每处理完一个任务延迟一下，避免阻塞主线程
        await new Promise<void>(resolve => {
          const timer = setTimeout(() => {
            clearTimeout(timer)
            resolve()
          }, 50)
        })
      } catch (error) {
        salmonLogger.addLog(TAG, `封面任务处理失败: ${task.videoEntity.title}, error=${error}`, true)
      }
    }

    SelectFileUtil.isProcessingCovers = false
    salmonLogger.addLog(TAG, '封面任务处理完成', false)

    // 如果在处理过程中有新任务加入，继续处理
    if (pendingCoverTasks.length > 0) {
      SelectFileUtil.processPendingCoverTasks()
    }
  }
}
