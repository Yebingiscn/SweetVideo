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
import { extractVideoMetadataInTaskPool } from './TaskpoolUtil'
import { systemDateTime } from '@kit.BasicServicesKit'

const TAG = 'SelectFileUtil'

export interface SavePixelMapOptions {
  releasePixelMap?: boolean
  deleteOnFail?: boolean
}

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

  static async selectFromFileManager(uri?: string, mode: 'video' | 'audio' | 'album' = 'video'): Promise<string[]> {
    const documentSelectOptions = new picker.DocumentSelectOptions()
    if (uri) {
      documentSelectOptions.defaultFilePathUri = uri
    }
    // 根据模式设置文件过滤器
    switch (mode) {
      case 'video':
        documentSelectOptions.fileSuffixFilters = SUPPORT_VIDEO_FORMAT
        break
      case 'audio':
        documentSelectOptions.fileSuffixFilters = SUPPORT_AUDIO_FORMAT
        break
      case 'album':
      default:
        documentSelectOptions.fileSuffixFilters = SUPPORT_VIDEO_FORMAT
        break
    }
    // 如果没有指定uri，根据模式设置合并模式
    if (!uri) {
      switch (mode) {
        case 'video':
          documentSelectOptions.mergeMode = picker.MergeTypeMode.VIDEO
          break
        case 'audio':
          documentSelectOptions.mergeMode = picker.MergeTypeMode.AUDIO
          break
        case 'album':
          return SelectFileUtil.selectVideosFromAlbum()
      }
    }
    const documentViewPicker = new picker.DocumentViewPicker(PathUtils.appContext!)
    try {
      const documentSelectResult: string[] = await documentViewPicker.select(documentSelectOptions)
      return documentSelectResult.length > 0 ? documentSelectResult : []
    } catch (error) {
      salmonLogger.addLog(TAG, "Error selecting files: " + error, true)
      return []
    }
  }

  static async selectVideosFromAlbum(): Promise<string[]> {
    return SelectFileUtil.selectFromAlbum(photoAccessHelper.PhotoViewMIMETypes.VIDEO_TYPE)
  }

  static async selectPhoto(): Promise<string[]> {
    return SelectFileUtil.selectFromAlbum(photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE, 1)
  }

  static async deletePhoto(imageName: 'BackgroundImage' | 'BackgroundDarkImage' | 'avatar') {
    fs.access(PathUtils.photoPath! + imageName).then((res: boolean) => {
      if (res) {
        fs.unlink(PathUtils.photoPath! + imageName, async (unlinkErr) => {
          if (unlinkErr) {
            ToolsUtil.showToast('删除失败，原因是：' + unlinkErr.message)
          }
          ToolsUtil.showToast('删除成功')
        })
      } else {
        salmonLogger.addLog(TAG, "照片不存在", true)
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
        fs.closeSync(sourceFile.fd)
      }
      if (targetFile) {
        fs.closeSync(targetFile.fd)
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
        salmonLogger.addLog(TAG, `Failed to access image: ${fullPath} ` + e)
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
      salmonLogger.addLog(TAG, 'Unexpected error in getImageUri' + error, true)
      return ''
    }
  }

  static saveImageToSandBox(sourceFileUri: string, imageName: string) {
    const filePath = PathUtils.photoPath + imageName // 定义完整文件路径
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

  static async savePixelMapToFile(basePath: string, fileName: string, pixelMap: image.PixelMap,
    options?: SavePixelMapOptions): Promise<string> {
    const filePath = basePath + fileName
    let packer: image.ImagePacker | undefined = undefined
    let file: fs.File | undefined = undefined
    try {
      packer = image.createImagePacker()
      file = fs.openSync(filePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE)
      await packer.packToFile(pixelMap, file.fd, { format: 'image/webp', quality: 85 })
      return filePath
    } catch (error) {
      const errMsg = error instanceof Error ? error.message : String(error)
      salmonLogger.addLog(TAG, `Failed to save pixelMap to ${filePath}: ${errMsg}`, true)
      if (options?.deleteOnFail) {
        try {
          fs.accessSync(filePath) && fs.unlinkSync(filePath)
        } catch {
        }
      }
      return ''
    } finally {
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
      if (options?.releasePixelMap) {
        try {
          pixelMap.release()
        } catch (e) {
          salmonLogger.addLog(TAG, 'Failed to release pixelMap: ' + e, false)
        }
      }
    }
  }

  //复制视频进入隐私空间（优化版：减少文件打开次数）
  static async copyFileToPrivacySpace(context: Context, video_meta_data_encryption: VideoMetadata[], uri: string,
    sandbox_video: string, sandbox_path: string, date: string, metadata: media.AVMetadata,
    fileName: string, fileSize: number, pixelMap: image.PixelMap | undefined): Promise<VideoMetadata> {
    let sourceFile: fs.File | null = null
    let targetFile: fs.File | null = null
    try {
      const sourceFile = fs.openSync(uri, fs.OpenMode.READ_ONLY)
      const targetPath = `${sandbox_video}${date}`
      const targetFile = fs.openSync(targetPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE)
      await new Promise<void>((resolve, reject) => {
        fs.copyFile(sourceFile.fd, targetFile.fd, (error) => {
          error ? reject(error) : resolve()
        })
      })
      const videoInfo =
        await VideoInfoUtil.setVideoInfoOptimized(date, targetPath, fileName, metadata, sandbox_video, sandbox_path,
          fileSize, pixelMap)
      video_meta_data_encryption.push(videoInfo)
      Preferences.saveVideoMetaDataEncryption(context, video_meta_data_encryption)
      return videoInfo // 返回新创建的元数据对象
    } catch (error) {
      salmonLogger.addLog(TAG, `文件复制失败: ${uri}: error ${error}`, true)
      throw new Error(`隐私空间复制失败: ${error.message}`)
    } finally {
      fs.closeSync(sourceFile)
      fs.closeSync(targetFile)
    }
  }

  static copyFileReName(title: string, format: string) {
    return [title.split('.')[title.split('.').length - 1]
      == format ? title : title + '.' + format]
  }

  static saveData(context: Context, target_data: VideoMetadata, options: SaveOptions) {
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
    const updateVideo = (video: VideoMetadata) => {
      if (options.playTime) {
        video.last_play = save_time
      }
      if (options.startTime) {
        video.start_time = options.startTime
      }
      if (options.endTime) {
        video.end_time = options.endTime
      }
      if (options.size?.[0] && video.size[0] === 0) {
        video.size = options.size
      }
      if (options.totalTime && video.time === 0) {
        video.time = options.totalTime
      }
      if (options.pointA) {
        video.pointA = options.pointA
      }
      if (options.pointB) {
        video.pointB = options.pointB
      }
      if (options.subtitleMode !== undefined) {
        video.subtitle_mode = options.subtitleMode
      }
      if (options.subtitleVisible !== undefined) {
        video.subtitle_visible = options.subtitleVisible
      }
      if (options.subtitleAIAsrShown !== undefined) {
        video.subtitle_ai_asr_shown = options.subtitleAIAsrShown
      }
      if (options.subtitle3DMode !== undefined) {
        video.subtitle_3d_mode = options.subtitle3DMode
      }
      if (options.subtitleOffsetMillis !== undefined) {
        video.subtitle_offset_millis = options.subtitleOffsetMillis
      }
      if (options.subtitleTrackId !== undefined) {
        video.subtitle_track_id = options.subtitleTrackId
      }
    }
    if (PrivacySpaceUtil.getPrivacyMode()) {
      ToolsUtil.addLogger('当前处于隐私空间，更新隐私空间数据', false, undefined, TAG)
      const videoMetaDataEncryption = Preferences.getVideoMetaDataEncryption(context)
      const targetVideoMetaDataEncryption = videoMetaDataEncryption.find(v => v.date === target_data.date)
      if (targetVideoMetaDataEncryption) {
        updateVideo(targetVideoMetaDataEncryption)
        Preferences.saveVideoMetaDataEncryption(context, videoMetaDataEncryption)
        ToolsUtil.addLogger('隐私空间数据更新完成', false, undefined, TAG)
      } else {
        ToolsUtil.addLogger('未在隐私空间中找到目标视频数据', true, undefined, TAG)
      }
      return
    }
    ToolsUtil.addLogger('更新文件夹中的视频数据', false, undefined, TAG)
    // 一次性读取所有数据，避免竞态条件
    const folders = Preferences.getFileFolder(context)
    const recent_play_deque = Preferences.getRecentPlay(context)

    // 更新文件夹中的视频
    for (const folder of folders) {
      const videoMetaData: VideoMetadata[] = folder.video_list
      const targetVideoMetaData = videoMetaData.find(video => video.date === target_data.date)
      if (targetVideoMetaData) {
        updateVideo(targetVideoMetaData)
      }
    }

    // 更新最近播放列表
    const recentTargetVideoMetaData = recent_play_deque.find(video => video.date === target_data.date)
    if (recentTargetVideoMetaData) {
      updateVideo(recentTargetVideoMetaData)
    }

    // 一次性保存所有数据，确保数据一致性
    Preferences.saveFileFolder(context, folders)
    Preferences.saveRecentPlay(context, recent_play_deque)
    ToolsUtil.addLogger('文件夹和最近播放列表数据更新完成', false, undefined, TAG)
  }

  static deleteVideo(videoMetaData: VideoMetadata) {
    SelectFileUtil.deleteVideoFromFolder(videoMetaData)
    SelectFileUtil.deleteVideoEncryption(videoMetaData)
    RecentPlayUtil.delData(PathUtils.appContext!, videoMetaData.uri)
  }

  static deleteVideoFromFolder(videoMetaData: VideoMetadata, currentFolder?: FileFolder) {
    const context = PathUtils.appContext!
    const folders = Preferences.getFileFolder(context)
    if (!folders || folders.length === 0) {
      return
    }
    const targetFolders = currentFolder
      ? folders.filter(f => f.name === currentFolder.name)
      : folders
    targetFolders.forEach(folder => {
      folder.video_list = folder.video_list.filter(video => video.date !== videoMetaData.date)
    })
    Preferences.saveFileFolder(context, folders)
  }

  static deleteVideoEncryption(videoMetaData: VideoMetadata) {
    //更新隐私空间的数据
    let videoMetaDataEncryption = Preferences.getVideoMetaDataEncryption(PathUtils.appContext!)
    videoMetaDataEncryption = videoMetaDataEncryption.filter(video => video.date !== videoMetaData.date)
    Preferences.saveVideoMetaDataEncryption(PathUtils.appContext!, videoMetaDataEncryption)
    fs.access(PathUtils.videoPath + videoMetaData.date).then((res: boolean) => {
      if (res) {
        fs.unlink(PathUtils.videoPath + videoMetaData.date, async (unlinkErr) => {
          if (unlinkErr) {
            ToolsUtil.showToast('删除视频失败：' + videoMetaData.title + '原因是：' + unlinkErr.message)
          }
          Preferences.saveVideoMetaDataEncryption(PathUtils.appContext!, videoMetaDataEncryption)
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

  public static getVideoListByVideoDate(videoDate: string): [VideoMetadata | undefined, VideoMetadata[]] {
    const fileFolderList = Preferences.getFileFolder(PathUtils.appContext!)
    for (const folder of fileFolderList) {
      const targetVideo = folder.video_list.find(video => video.date === videoDate)
      if (targetVideo) {
        return [targetVideo, folder.video_list]
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

  static async addFile(context: Context, sandbox_video: string, sandbox_path: string, uri: string,
    video_meta_data: VideoMetadata[], file_folder?: FileFolder) {
    if (canIUse('SystemCapability.Multimedia.Media.AVMetadataExtractor')) {
      // 1. 权限持久化（主线程）
      await PermissionUtil.persistPermission(uri)

      try {
        // 2. 使用 TaskPool 提取元数据（后台线程，性能优化）
        const extractionResult = await extractVideoMetadataInTaskPool(uri)

        if (!extractionResult.success) {
          salmonLogger.addLog(TAG, 'TaskPool 元数据提取失败: ' + extractionResult.error, true)
          return
        }

        // 不使用解构赋值，逐个获取属性
        const metadata = extractionResult.metadata
        const pixelMap = extractionResult.pixelMap
        const fileSize = extractionResult.fileSize
        const fileName = extractionResult.fileName

        // 3. 数据处理和保存（主线程）
        const fileQueue = ConcurrencyManagerUtil.getFileQueue(uri)
        await fileQueue.run(async () => {
          // 获取全局数据锁（保证原子操作）
          const dataLock = ConcurrencyManagerUtil.getLock('global_data')
          await dataLock.acquire()
          try {
            if (!file_folder) {
              const folderName = FileFolderUtil.extractRootFolderNameFromUri(uri, fileName)
              if (folderName) {
                const folderLock = ConcurrencyManagerUtil.getLock(`folder_${folderName}`)
                await folderLock.acquire()
                try {
                  // 每次获取最新数据，防止不同线程覆盖数据
                  const latestFolders = Preferences.getFileFolder(context) as FileFolder[]
                  if (!latestFolders.some(i => i.name === folderName)) {
                    await FileFolderUtil.createNewFolder(context, folderName)
                    // 创建后重新获取最新数据
                    file_folder = (Preferences.getFileFolder(context) as FileFolder[])
                      .find(item => item.name === folderName)
                  } else {
                    file_folder = latestFolders.find(item => item.name === folderName)
                  }
                } finally {
                  folderLock.release()
                }
              }
            }
            let isDuplicate = false
            isDuplicate = FileFolderUtil.existsVideoInFolders(context, uri, fileName)
            if (!isDuplicate) {
              if (PrivacySpaceUtil.getPrivacyMode()!) {
                await SelectFileUtil.copyFileToPrivacySpace(context, video_meta_data, uri, sandbox_video,
                  sandbox_path, systemDateTime.getTime(true).toString(), metadata!, fileName, fileSize, pixelMap)
              } else {
                const videoInfo =
                  await VideoInfoUtil.setVideoInfoOptimized(systemDateTime.getTime(true).toString(), uri, fileName,
                    metadata!, sandbox_video, sandbox_path, fileSize, pixelMap)
                if (file_folder) {
                  file_folder.video_list.push(videoInfo)
                  FileFolderUtil.updateFileFolder(context, file_folder, file_folder.video_list)
                } else {
                  const folders = Preferences.getFileFolder(context)
                  folders[0].video_list.push(videoInfo)
                  Preferences.saveFileFolder(context, folders)
                }
              }
            }
          } finally {
            dataLock.release()
          }
        })
      } catch (error) {
        salmonLogger.addLog(TAG, '导入视频发生错误, 原因是：' + error, true)
      }
    }
  }

  static async deletePrivacyVideo(date: string, title: string, video_meta_data_encryption: VideoMetadata[]) {
    await SelectFileUtil.deleteCover(date)
    await SubtitleUtil.deleteSubtitle(PathUtils.subtitlePath, date)
    Preferences.saveVideoMetaDataEncryption(PathUtils.appContext!, video_meta_data_encryption)
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
}
