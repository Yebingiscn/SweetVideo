import { common, Context } from '@kit.AbilityKit'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { fileIo as fs, fileUri, picker } from '@kit.CoreFileKit'
import VideoInfoUtil from './VideoInfoUtil'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
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
import { extractVideoFileInfoInTaskPool } from './TaskpoolUtil'
import { Available, SuppressWarnings, SuppressWarningsType, systemDateTime } from '@kit.BasicServicesKit'
import FFmpegThumbnailUtil, { FFmpegMediaProbe } from './FFmpegThumbnailUtil'
import MediaLibraryService from './MediaLibraryService'
import MediaExportUtil from './MediaExportUtil'
import MediaImportBatch from './MediaImportBatch'
import ImageStorage from './ImageStorage'
import { MediaBatchProgress, MediaBatchResult } from '../interfaces/MediaBatchInterface'

const TAG = 'SelectFileUtil'

export interface MediaFolderImport {
  name: string
  uri: string
  files: string[]
}

interface DirectoryScanResult {
  files: string[]
  directories: DirectoryScanTarget[]
}

interface DirectoryScanTarget {
  fileSystemPath: string
  importUri: string
}

export default class SelectFileUtil {
  public static fileFolderUri = ''
  private static downloadUriPromise: Promise<string> | undefined = undefined

  @SuppressWarnings({ rules: [SuppressWarningsType.SYSCAP] })
  static async selectFromFileManager(uri?: string,
    mode: 'video' | 'audio' | 'album' = 'video'): Promise<string[]> {
    const documentSelectOptions = new picker.DocumentSelectOptions()
    if (uri) {
      documentSelectOptions.defaultFilePathUri = uri
    }
    // 根据模式设置文件过滤器
    switch (mode) {
      case 'video':
        documentSelectOptions.fileSuffixFilters = ToolsUtil.localizeSuffixFilter(SUPPORT_VIDEO_FORMAT, $r('app.string.filter_video'))
        break
      case 'audio':
        documentSelectOptions.fileSuffixFilters = ToolsUtil.localizeSuffixFilter(SUPPORT_AUDIO_FORMAT, $r('app.string.filter_audio'))
        break
      default:
        documentSelectOptions.fileSuffixFilters = ToolsUtil.localizeSuffixFilter(SUPPORT_VIDEO_FORMAT, $r('app.string.filter_video'))
        break
    }
    // 如果没有指定uri，根据模式设置合并模式
    if (!uri) {
      switch (mode) {
        case 'video':
          // 聚合视频视图会忽略后缀筛选；普通文件视图才能选择 M4S 等系统未归类的视频文件。
          documentSelectOptions.mergeMode = picker.MergeTypeMode.DEFAULT
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

  @Available({ minApiVersion: 'HarmonyOS 26.0.0' })
  @SuppressWarnings({ rules: [SuppressWarningsType.SYSCAP] })
  static async selectMediaFolders(): Promise<MediaFolderImport[]> {
    const documentSelectOptions = new picker.DocumentSelectOptions()
    documentSelectOptions.selectMode = picker.DocumentSelectMode.FOLDER
    documentSelectOptions.allowsMulFolderSelection = true
    const documentViewPicker = new picker.DocumentViewPicker(PathUtils.appContext!)
    try {
      const selectedFolders = await documentViewPicker.select(documentSelectOptions)
      if (selectedFolders.length === 0) {
        return []
      }
      await Promise.allSettled(selectedFolders.map((folderUri: string) => PermissionUtil.persistPermission(folderUri)))
      const imports: MediaFolderImport[] = []
      for (const folderUri of selectedFolders) {
        imports.push({
          name: SelectFileUtil.getDirectoryName(folderUri),
          uri: folderUri,
          files: await SelectFileUtil.collectMediaFilesFromDirectories([folderUri])
        })
      }
      return imports
    } catch (error) {
      salmonLogger.addLog(TAG, `从文件夹导入失败: ${error}`, true)
      return []
    }
  }

  static async selectVideosFromAlbum(): Promise<string[]> {
    return SelectFileUtil.selectFromAlbum(photoAccessHelper.PhotoViewMIMETypes.VIDEO_TYPE)
  }

  static async selectPhoto(): Promise<string[]> {
    return SelectFileUtil.selectFromAlbum(photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE, 1)
  }

  // 获取下载文件夹路径
  static async getDownloadUri(): Promise<string> {
    if (SelectFileUtil.fileFolderUri) {
      return SelectFileUtil.fileFolderUri
    }
    if (SelectFileUtil.downloadUriPromise) {
      return SelectFileUtil.downloadUriPromise
    }
    SelectFileUtil.downloadUriPromise = SelectFileUtil.resolveDownloadUri()
    try {
      return await SelectFileUtil.downloadUriPromise
    } finally {
      SelectFileUtil.downloadUriPromise = undefined
    }
  }

  // 导出视频文件
  static async exportFile(uri: string, title: string, format: string, context: common.UIAbilityContext) {
    let sourceFile: fs.File | null = null
    let targetFile: fs.File | null = null
    try {
      sourceFile = fs.openSync(uri)
      const saverOption = new picker.DocumentSaveOptions()
      const exportFormat = format.trim() || await MediaExportUtil.detectExtension(uri)
      saverOption.newFileNames = SelectFileUtil.copyFileReName(title, exportFormat)
      const documentSaveResult = await new Promise<string[]>((resolve, reject) => {
        const saver = new picker.DocumentViewPicker(context)
        saver.save(saverOption, (err: BusinessError, uris: string[]) => {
          err ? reject(err) : resolve(uris)
        })
      })
      if (documentSaveResult.length === 0) {
        return
      }
      targetFile = fs.openSync(documentSaveResult[0], fs.OpenMode.READ_WRITE)
      await fs.copyFile(sourceFile.fd, targetFile.fd)
      ToolsUtil.showToast(ToolsUtil.getStringResourceArgs2($r('app.string.export_success_detail').id, targetFile?.name ?? '', targetFile?.path ?? ''))
    } catch (error) {
      ToolsUtil.showToast(ToolsUtil.getStringResourceArgs($r('app.string.export_failed_reason').id, String(error)))
    } finally {
      SelectFileUtil.closeFileSafely(sourceFile, '导出源文件')
      SelectFileUtil.closeFileSafely(targetFile, '导出目标文件')
    }
  }

  // 一次选择保存位置，复用单文件导出的命名、文件复制及句柄释放逻辑。
  static async exportFiles(items: VideoMetadata[], context: common.UIAbilityContext,
    isCancelled: () => boolean, onProgress: (info: MediaBatchProgress) => void): Promise<MediaBatchResult> {
    const result: MediaBatchResult = { successDates: [], failedCount: 0, cancelled: false }
    const itemMap: Map<string, VideoMetadata> = new Map()
    for (const item of items) itemMap.set(item.date, item)
    const uniqueItems: VideoMetadata[] = Array.from(itemMap.values())
    const names: string[] = []
    const usedNames: Set<string> = new Set()
    if (uniqueItems.length === 0) return result
    try {
      for (const item of uniqueItems) {
        if (isCancelled()) {
          result.cancelled = true
          return result
        }
        const format = item.format?.trim() || await MediaExportUtil.detectExtension(item.uri)
        const name = SelectFileUtil.copyFileReName(item.title, format)[0].replace(/[\\/\u0000-\u001f<>:"|?*]/g, '_')
        const dot = name.lastIndexOf('.')
        const stem = dot > 0 ? name.substring(0, dot) : name
        const suffix = dot > 0 ? name.substring(dot) : ''
        let candidate = name
        let index = 2
        while (usedNames.has(candidate.toLowerCase())) candidate = `${stem} (${index++})${suffix}`
        usedNames.add(candidate.toLowerCase())
        names.push(candidate)
      }
      if (isCancelled()) {
        result.cancelled = true
        return result
      }
      const options = new picker.DocumentSaveOptions()
      options.newFileNames = names
      const targets = await new picker.DocumentViewPicker(context).save(options)
      if (targets.length === 0 || isCancelled()) {
        result.cancelled = true
        return result
      }
      // 返回数量不匹配时不猜测文件对应关系，避免将内容写入错误的目标文件。
      if (targets.length !== uniqueItems.length || new Set(targets).size !== targets.length) {
        throw new Error('Invalid export destinations')
      }
      for (let index = 0; index < uniqueItems.length; index++) {
        if (isCancelled()) break
        const item = uniqueItems[index]
        let sourceFile: fs.File | null = null
        let targetFile: fs.File | null = null
        try {
          if (item.uri === targets[index]) throw new Error('Export destination equals source')
          sourceFile = fs.openSync(item.uri, fs.OpenMode.READ_ONLY)
          targetFile = fs.openSync(targets[index], fs.OpenMode.READ_WRITE)
          await fs.copyFile(sourceFile.fd, targetFile.fd)
          result.successDates.push(item.date)
        } catch (_) {
          result.failedCount++
          salmonLogger.addLog(TAG, '批量导出文件失败，保留隐私空间原文件', true)
        } finally {
          SelectFileUtil.closeFileSafely(sourceFile, '批量导出源文件')
          SelectFileUtil.closeFileSafely(targetFile, '批量导出目标文件')
        }
        onProgress({ processedItems: index + 1, totalItems: uniqueItems.length,
          currentFileName: item.title, failedCount: result.failedCount })
      }
    } catch (_) {
      result.failedCount = uniqueItems.length - result.successDates.length
      salmonLogger.addLog(TAG, '批量导出失败，保留隐私空间原文件', true)
    }
    result.cancelled = isCancelled() || result.cancelled
    return result
  }

  //复制视频进入隐私空间
  static async copyFileToPrivacySpace(context: Context, video_meta_data_encryption: VideoMetadata[], uri: string,
    sandbox_video: string, sandbox_path: string, date: string, fileName: string, fileSize: number,
    pixelMap: image.PixelMap | undefined,
    probe?: FFmpegMediaProbe): Promise<VideoMetadata> {
    let sourceFile: fs.File | null = null
    let targetFile: fs.File | null = null
    let coverTransferred = false
    try {
      sourceFile = fs.openSync(uri, fs.OpenMode.READ_ONLY)
      const targetPath = `${sandbox_video}${date}`
      targetFile = fs.openSync(targetPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE)
      await new Promise<void>((resolve, reject) => {
        fs.copyFile(sourceFile!.fd, targetFile!.fd, (error) => {
          error ? reject(error) : resolve()
        })
      })
      coverTransferred = true
      const videoInfo =
        await VideoInfoUtil.setVideoInfoOptimized(date, targetPath, fileName, sandbox_video, sandbox_path, fileSize,
          pixelMap, probe)
      video_meta_data_encryption.push(videoInfo)
      Preferences.saveVideoMetaDataEncryption(context, video_meta_data_encryption)
      return videoInfo // 返回新创建的元数据对象
    } catch (error) {
      salmonLogger.addLog(TAG, `文件复制失败: ${uri}: error ${error}`, true)
      throw new Error(`隐私空间复制失败: ${error.message}`)
    } finally {
      SelectFileUtil.closeFileSafely(sourceFile, '隐私空间源文件')
      SelectFileUtil.closeFileSafely(targetFile, '隐私空间目标文件')
      if (!coverTransferred) await ImageStorage.releaseImageSafely(pixelMap, '未保存的隐私封面')
    }
  }

  static copyFileReName(title: string, format: string) {
    return [MediaExportUtil.buildFileName(title, format)]
  }

  // 检查文件是否存在
  static async isFileExist(uri: string, showToast: boolean) {
    await PermissionUtil.activatePermission(uri)
    if (MediaLibraryService.isPathFromSource(uri, VideoSource.EXTERNAL_DEVICE)) {
      ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.file_reauth_required').id))
      await SelectFileUtil.selectFromFileManager(uri)
    }
    let file: fs.File | undefined
    try {
      file = await fs.open(String(uri))
      return true
    } catch (e) {
      if (showToast) {
        ToolsUtil.showToast(uri + ' ' + ToolsUtil.getStringResource($r('app.string.file_invalid_reimport').id))
        salmonLogger.addLog('file error', 'file error: ' + e.code + ':' + e.message, true)
      }
      return false
    } finally {
      if (file) {
        try {
          fs.closeSync(file)
        } catch (error) {
          salmonLogger.addLog(TAG, '关闭视频文件失败: ' + error, true)
        }
      }
    }
  }

  static async addFile(context: Context, sandbox_video: string, sandbox_path: string, uri: string,
    video_meta_data: VideoMetadata[], file_folder?: FileFolder,
    privateMode: boolean = PrivacySpaceUtil.getPrivacyMode() === true,
    allowDuplicateTitle: boolean = false, importRootUri?: string,
    importRootFolderName?: string, importBatch?: MediaImportBatch): Promise<boolean> {
    let unusedPixelMap: image.PixelMap | undefined
    try {
      const fileInfoResult = await extractVideoFileInfoInTaskPool(uri)
      if (!fileInfoResult.success) {
        salmonLogger.addLog(TAG, '读取视频文件信息失败: ' + fileInfoResult.error, true)
        return false
      }

      // 文件存在且不是目录后再持久化；失败不能伪造成功缓存。
      await PermissionUtil.persistPermission(uri)
      const fileSize = fileInfoResult.fileSize
      const fileName = fileInfoResult.fileName
      if (!(privateMode && allowDuplicateTitle)) {
        if (FileFolderUtil.existsVideoInFolders(context, uri, fileName, privateMode)) return true
        if (importBatch?.hasUri(uri)) {
          FileFolderUtil.duplicateVideo++
          return true
        }
      }
      // 同一 FFmpeg 会话先读取文字元数据，再解一张封面。
      const mediaResult = await FFmpegThumbnailUtil.probeAndExtractCover(uri)
      const mediaProbe = mediaResult.probe
      if (!mediaProbe) {
        // 媒体探测失败不能阻止用户导入；基础条目仍使用文件名和安全尺寸创建。
        salmonLogger.addLog(TAG,
          `FFmpeg 元数据提取失败，按文件信息导入 ${fileName}: ${mediaResult.thumbnail.error}`, true)
      }
      const pixelMap = mediaResult.thumbnail.success ? mediaResult.thumbnail.pixelMap : undefined
      unusedPixelMap = pixelMap
      if (mediaProbe && !mediaResult.thumbnail.success && mediaResult.thumbnail.error) {
        salmonLogger.addLog(TAG, 'FFmpeg 封面提取失败: ' + mediaResult.thumbnail.error, true)
      }

      const fileQueue = ConcurrencyManagerUtil.getFileQueue(uri)
      let importHandled = false
      await fileQueue.run(async () => {
        const dataLock = ConcurrencyManagerUtil.getLock('global_data')
        await dataLock.acquire()
        let shouldSaveCover = false
        let coverUri = ''
        let coverSandboxPath = ''
        let coverDate = ''
        let coverDurationMs = 0
        let coverPixelMap: image.PixelMap | undefined
        try {
          // 不同设备接收的同名文件不一定内容相同，隐私接收保留两份。
          let isDuplicate = privateMode && allowDuplicateTitle ? false :
            FileFolderUtil.existsVideoInFolders(context, uri, fileName, privateMode)
          if (!isDuplicate && importBatch?.hasUri(uri)) {
            FileFolderUtil.duplicateVideo++
            isDuplicate = true
          }
          if (!isDuplicate) {
            if (!privateMode && !file_folder) {
              const folderPathParts = FileFolderUtil.extractFolderPathFromUri(
                uri, fileName, importRootUri, importRootFolderName)
              if (folderPathParts && folderPathParts.length > 0) {
                const folderLock = ConcurrencyManagerUtil.getLock(`folder_${folderPathParts.join('/')}`)
                await folderLock.acquire()
                try {
                  file_folder = await FileFolderUtil.createFolderPath(context, folderPathParts)
                } finally {
                  folderLock.release()
                }
              }
            }
            if (privateMode) {
              // 持锁后读取最新隐私列表，避免异步接收覆盖期间新导入的条目。
              const privateVideos = Preferences.getVideoMetaDataEncryption(context)
              unusedPixelMap = undefined
              const imported = await SelectFileUtil.copyFileToPrivacySpace(context, privateVideos, uri, sandbox_video,
                sandbox_path, systemDateTime.getTime(true).toString(), fileName, fileSize, pixelMap, mediaProbe)
              if (video_meta_data !== privateVideos) {
                video_meta_data.push(imported)
              }
            } else {
              const date = systemDateTime.getTime(true).toString()
              const videoInfo = VideoInfoUtil.buildVideoMetadata(
                date, uri, fileName, sandbox_video, fileSize, mediaProbe)
              // 接收模式已固定，不能受此刻前台是否打开隐私空间影响。
              videoInfo.uri = uri
              if (importBatch) {
                const targetDate = file_folder?.date ?? Preferences.getFileFolder(context)[0]?.date
                if (!targetDate) throw new Error('Import target folder is unavailable')
                importBatch.add(targetDate, videoInfo)
              } else if (file_folder) {
                file_folder.video_list.push(videoInfo)
                FileFolderUtil.updateFileFolder(context, file_folder, file_folder.video_list)
              } else {
                const folders = Preferences.getFileFolder(context)
                folders[0].video_list.push(videoInfo)
                Preferences.saveFileFolder(context, folders)
              }
              shouldSaveCover = true
              coverUri = uri
              coverSandboxPath = sandbox_path
              coverDate = date
              coverDurationMs = mediaProbe?.durationMs || 0
              coverPixelMap = pixelMap
            }
            importHandled = true
          } else {
            importHandled = true
            salmonLogger.addLog(TAG, `跳过已导入文件: ${fileName}`, true)
          }
        } finally {
          dataLock.release()
        }
        if (shouldSaveCover) {
          unusedPixelMap = undefined
          await VideoInfoUtil.saveCoverDeferred(
            coverUri, coverSandboxPath, coverDate, coverDurationMs, coverPixelMap)
        }
      })
      return importHandled
    } catch (error) {
      salmonLogger.addLog(TAG, '导入视频发生错误, 原因是：' + error, true)
      return false
    } finally {
      await ImageStorage.releaseImageSafely(unusedPixelMap, '未使用的导入封面')
    }
  }

  static async getDownloadFilesUri(): Promise<string[]> {
    return SelectFileUtil.collectMediaFilesFromDirectories([SelectFileUtil.fileFolderUri])
  }

  private static async collectMediaFilesFromDirectories(rootDirectories: string[]): Promise<string[]> {
    const MEDIA_EXTENSIONS = new Set([
      ...ToolsUtil.localizeSuffixFilter(SUPPORT_VIDEO_FORMAT, $r('app.string.filter_video')),
      ...ToolsUtil.localizeSuffixFilter(SUPPORT_AUDIO_FORMAT, $r('app.string.filter_audio'))
    ].map(ext => ext.toLowerCase()))
    const isMediaFile = (filePath: string): boolean => {
      const ext = VideoInfoUtil.getExtension(filePath)
      return ext !== '' && MEDIA_EXTENSIONS.has(ext)
    }

    const joinDirectoryPath = (directory: string, entry: string): string => {
      return `${directory.replace(/\/+$/, '')}/${entry.replace(/^\/+/, '')}`
    }

    const DIRECTORY_BATCH_SIZE = 8
    const ENTRY_BATCH_SIZE = 50
    const filePaths: string[] = []
    const processedDirectories = new Set<string>()
    const directoryQueue: DirectoryScanTarget[] = rootDirectories
      .filter((directory: string) => directory.length > 0)
      .map((directory: string) => SelectFileUtil.createDirectoryScanTarget(directory))

    const scanDirectory = async (directory: DirectoryScanTarget): Promise<DirectoryScanResult> => {
      const result: DirectoryScanResult = { files: [], directories: [] }
      try {
        const entries: string[] = await fs.listFile(directory.fileSystemPath)
        for (let i = 0; i < entries.length; i += ENTRY_BATCH_SIZE) {
          const batch = entries.slice(i, i + ENTRY_BATCH_SIZE)
          const batchPromises = batch.map(async (entry: string) => {
            const fullFileSystemPath = joinDirectoryPath(directory.fileSystemPath, entry)
            const fullImportUri = joinDirectoryPath(directory.importUri,
              directory.importUri.startsWith('file://') ? encodeURIComponent(entry) : entry)
            try {
              const stat = await fs.stat(fullFileSystemPath)
              if (stat.isFile()) {
                if (isMediaFile(fullFileSystemPath)) {
                  result.files.push(fullImportUri)
                }
              } else if (stat.isDirectory()) {
                result.directories.push({
                  fileSystemPath: fullFileSystemPath,
                  importUri: fullImportUri
                })
              }
            } catch (error) {
              salmonLogger.addLog(TAG, `Failed to process ${fullFileSystemPath}: ${error}`, true)
            }
          })
          await Promise.allSettled(batchPromises)
        }
      } catch (error) {
        salmonLogger.addLog(TAG, `Failed to list directory ${directory.fileSystemPath}: ${error}`, true)
      }
      return result
    }

    try {
      let queueIndex = 0
      while (queueIndex < directoryQueue.length) {
        const directories: DirectoryScanTarget[] = []
        while (queueIndex < directoryQueue.length && directories.length < DIRECTORY_BATCH_SIZE) {
          const directory = directoryQueue[queueIndex++]
          if (!processedDirectories.has(directory.fileSystemPath)) {
            processedDirectories.add(directory.fileSystemPath)
            directories.push(directory)
          }
        }
        const scanResults = await Promise.allSettled(
          directories.map((directory: DirectoryScanTarget) => scanDirectory(directory)))
        scanResults.forEach(result => {
          if (result.status === 'fulfilled') {
            filePaths.push(...result.value.files)
            directoryQueue.push(...result.value.directories)
          }
        })
      }
      return Array.from(new Set(filePaths)).sort()
    } catch (error) {
      salmonLogger.addLog(TAG, `Root directory processing failed: ${error}`, true)
      return []
    }
  }

  private static createDirectoryScanTarget(directory: string): DirectoryScanTarget {
    if (!directory.startsWith('file://')) {
      return { fileSystemPath: directory, importUri: directory }
    }
    try {
      return {
        fileSystemPath: new fileUri.FileUri(directory).path,
        importUri: directory
      }
    } catch (error) {
      salmonLogger.addLog(TAG, `Failed to resolve directory URI ${directory}: ${error}`, true)
      return { fileSystemPath: directory, importUri: directory }
    }
  }

  private static getDirectoryName(directory: string): string {
    try {
      const name = new fileUri.FileUri(directory).name.trim()
      if (name.length > 0) {
        return name
      }
    } catch (error) {
      salmonLogger.addLog(TAG, `Failed to resolve directory name ${directory}: ${error}`, true)
    }
    const normalizedDirectory = directory.replace(/\/+$/, '')
    const name = normalizedDirectory.substring(normalizedDirectory.lastIndexOf('/') + 1).trim()
    return name.length > 0 ? name : ToolsUtil.getStringResource($r('app.string.import_folder').id)
  }

  private static closeFileSafely(file: fs.File | null | undefined, scene: string): void {
    if (!file) {
      return
    }
    try {
      fs.closeSync(file.fd)
    } catch (error) {
      salmonLogger.addLog(TAG, `${scene}关闭文件失败: ${error}`, true)
    }
  }

  private static async resolveDownloadUri(): Promise<string> {
    try {
      const documentViewPicker = new picker.DocumentViewPicker(PathUtils.appContext!)
      const documentSaveResult = await documentViewPicker.save({
        pickerMode: picker.DocumentPickerMode.DOWNLOAD
      })
      if (documentSaveResult.length === 0) {
        return ''
      }
      SelectFileUtil.fileFolderUri = new fileUri.FileUri(documentSaveResult[0]).path.replace(/\/+$/, '')
      return SelectFileUtil.fileFolderUri
    } catch (error) {
      salmonLogger.addLog(TAG, `获取公共下载目录失败: ${error}`, true)
      return ''
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
