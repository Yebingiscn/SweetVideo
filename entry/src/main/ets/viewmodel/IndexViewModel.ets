import { FileFolder } from '../interfaces/FileFolderInterface'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import { VideoListController } from '../component/VideoItemComponent/VideoItemComponent'
import { FileFolderDataSource } from '../utils/DataUtil'
import FileFolderUtil from '../utils/FileFolderUtil'
import { PathUtils } from '../utils/PathUtils'
import { FileProcessorUtil } from '../utils/FileProcessorUtil'
import ToolsUtil from '../utils/ToolsUtil'
import VideoUtils from '../utils/VideoUtil'
import DataSyncUtil from '../utils/DataSyncUtil'
import { VideoMetaDataOperator } from '../database/VideoMetaData'
import SelectFileUtil from '../utils/SelectFileUtil'
import { DeleteType } from '../common/enum/DeleteType'
import { Context } from '@kit.AbilityKit'

// =============================================================================
// Index 页面 ViewModel（新增）
// =============================================================================
// 架构重构：将 Index.ets 中原本超过 500 行的业务逻辑抽离到此 ViewModel，实现 UI 与业务分离。
// 职责边界：
//   - Index.ets         : 负责 UI 构建、手势响应、导航跳转、状态绑定
//   - IndexViewModel    : 负责文件夹初始化、视频导入、删除检查、文件夹切换/删除/刷新
//   - FileFolderUtil    : 负责具体的 ORM 数据操作
// ORM 改造：所有数据操作均通过异步 Repository 完成，不再直接读写 Preferences。
// =============================================================================

/**
 * 进度回调类型
 */
export type ProgressCallback = (processed: number, total: number) => void

/**
 * 导入结果类型
 */
export interface ImportResult {
  success: boolean
  importedCount: number
  duplicateCount: number
  error?: string
}

/**
 * Index 页面 ViewModel
 * 封装业务逻辑和数据操作
 */
export class IndexViewModel {
  private context: Context
  private onProgressUpdate: ProgressCallback
  private onFoldersUpdated: (folders: FileFolder[]) => void

  constructor(
    context: Context,
    onProgressUpdate: ProgressCallback,
    onFoldersUpdated: (folders: FileFolder[]) => void
  ) {
    this.context = context
    this.onProgressUpdate = onProgressUpdate
    this.onFoldersUpdated = onFoldersUpdated
  }

  /**
   * 初始化文件夹列表
   * 1. 加载所有文件夹
   * 2. 如果没有文件夹，创建默认"首页"文件夹
   */
  async initializeFolders(): Promise<FileFolder[]> {
    console.info('[IndexViewModel] initializeFolders started')

    // 文件夹存在性检查
    FileFolderUtil.fileFolderExistCheck()

    // 加载文件夹列表
    let folders: FileFolder[] = []
    try {
      folders = await FileFolderUtil.getAllFolderAsync(this.context)
      console.info(`[IndexViewModel] Loaded ${folders.length} folders`)
    } catch (e) {
      console.error(`[IndexViewModel] Error loading folders: ${JSON.stringify(e)}`)
      folders = []
    }

    // 首次安装时创建默认文件夹
    if (folders.length === 0) {
      console.info('[IndexViewModel] No folders found, creating default folder')
      try {
        folders = await FileFolderUtil.createNewFolder(this.context, '首页')
        console.info(`[IndexViewModel] Created default folder, now have ${folders.length} folders`)
      } catch (e) {
        console.error(`[IndexViewModel] Error creating folder: ${JSON.stringify(e)}`)
      }
    }

    this.onFoldersUpdated(folders)
    return folders
  }

  /**
   * 处理视频导入
   * @param fileList 文件URI列表
   * @param fileFolder 目标文件夹
   * @param existingVideos 已存在的视频列表（用于去重）
   * @param videoListController 视频列表控制器
   */
  async importVideos(
    fileList: string[],
    fileFolder: FileFolder | undefined,
    existingVideos: VideoMetadata[],
    videoListController: VideoListController
  ): Promise<ImportResult> {
    if (fileList.length === 0) {
      ToolsUtil.showToast('没有任何文件被导入哦~')
      return { success: false, importedCount: 0, duplicateCount: 0 }
    }

    // 记录导入前的文件夹视频数量
    const folderCountsBefore = new Map<string, number>()
    const currentFolders = await FileFolderUtil.getAllFolderAsync(this.context)
    currentFolders.forEach(folder => {
      folderCountsBefore.set(folder.date, folder.video_list.length)
    })

    // 开始导入
    this.onProgressUpdate(0, fileList.length)
    let processedItems = 0

    try {
      await FileProcessorUtil.processFilesConcurrently(
        fileList,
        this.context,
        PathUtils.videoPath,
        PathUtils.coverPath,
        existingVideos,
        (increment: number) => {
          processedItems += increment
          this.onProgressUpdate(processedItems, fileList.length)
        },
        fileFolder
      )

      const duplicateCount = FileFolderUtil.duplicateVideo
      const importedCount = fileList.length - duplicateCount

      // 显示导入结果提示
      const message = `${ToolsUtil.getStringResource($r('app.string.add_time_info').id)}${importedCount}${duplicateCount > 0 ?
        '重复视频已经智能跳过，跳过视频数：' + duplicateCount : ''}`
      ToolsUtil.showToast(message)

      // 刷新数据
      const targetFolder = videoListController.folder ?? currentFolders[0]
      const updatedFolders = await VideoUtils.refresh(videoListController, new FileFolderDataSource([]), targetFolder)
      this.onFoldersUpdated(updatedFolders)

      // 同步导入文件夹可见性
      this.syncImportedFolderVisibility(updatedFolders, folderCountsBefore, targetFolder?.date, videoListController)

      return { success: true, importedCount, duplicateCount }
    } catch (error) {
      const errorMsg = '处理过程中发生意外错误:' + error
      ToolsUtil.showToast(errorMsg)
      return { success: false, importedCount: 0, duplicateCount: 0, error: errorMsg }
    }
  }

  /**
   * 同步导入后的文件夹可见性
   * 当视频导入到非当前文件夹时，自动切换到目标文件夹
   */
  private syncImportedFolderVisibility(
    updatedFolders: FileFolder[],
    folderCountsBefore: Map<string, number>,
    currentFolderDate: string | undefined,
    videoListController: VideoListController
  ): void {
    const importedFolders = updatedFolders.filter(folder =>
      folder.video_list.length > (folderCountsBefore.get(folder.date) ?? 0)
    )

    if (importedFolders.length === 0) {
      return
    }

    const currentFolder = updatedFolders.find(folder => folder.date === currentFolderDate)
    const currentFolderHasNewVideo = currentFolder ?
      currentFolder.video_list.length > (folderCountsBefore.get(currentFolder.date) ?? 0) : false

    if (currentFolderHasNewVideo) {
      return
    }

    if (importedFolders.length === 1) {
      const importedFolder = importedFolders[0]
      videoListController.updateData(undefined, importedFolder)
      AppStorage.setOrCreate('scrollToFolderDate', importedFolder.date)
      ToolsUtil.showToast(`视频已导入到文件夹：${importedFolder.name}`)
      return
    }

    ToolsUtil.showToast('视频已按目录导入到其他文件夹，请切换文件夹查看')
  }

  /**
   * 处理删除视频检查结果
   * @param result 被删除的视频列表
   * @param videoListController 视频列表控制器
   * @param fileFolderSource 文件夹数据源
   */
  async handleDeletedVideosCheck(
    result: VideoMetadata[],
    videoListController: VideoListController,
    fileFolderSource: FileFolderDataSource
  ): Promise<FileFolder[]> {
    if (result.length === 0) {
      return await FileFolderUtil.getAllFolderAsync(this.context)
    }

    // 删除不存在的文件
    for (const item of result) {
      await videoListController.videoDataSource?.deleteUnExistFile(item, videoListController, fileFolderSource)
    }

    // 刷新数据
    const targetFolder = videoListController.folder
    const updatedFolders = await VideoUtils.refresh(videoListController, fileFolderSource, targetFolder)

    // 保存被删除的视频列表用于显示
    DataSyncUtil.deletedVideos = result

    return updatedFolders
  }

  /**
   * 删除文件夹
   * @param folder 要删除的文件夹
   * @param videoListController 视频列表控制器
   */
  async deleteFolder(
    folder: FileFolder,
    videoListController: VideoListController
  ): Promise<FileFolder[]> {
    // 准备删除文件夹中的视频
    DataSyncUtil.delMultipleList = Array.from(folder.video_list)

    // 执行软删除
    await Promise.all(
      DataSyncUtil.delMultipleList.map(item => {
        VideoMetaDataOperator.deleteItem(videoListController, new FileFolderDataSource([]), DeleteType.SOFT, item)
        return Promise.resolve()
      })
    )

    videoListController.closeMultipleChoose()

    // 删除文件夹
    const updatedFolders = await FileFolderUtil.deleteFileFolder(this.context, folder)

    // 确定新的当前文件夹
    let newFolder: FileFolder | undefined
    if (videoListController.folder?.date === folder.date) {
      newFolder = updatedFolders[0]
    } else {
      newFolder = videoListController.folder
    }
    videoListController.folder = newFolder

    // 刷新视频列表
    await VideoUtils.refresh(videoListController, new FileFolderDataSource([]), newFolder)

    return updatedFolders
  }

  /**
   * 切换到指定文件夹
   * @param folder 目标文件夹
   * @param videoListController 视频列表控制器
   * @param fileFolderSource 文件夹数据源
   * @param searchValue 当前搜索值（可选）
   */
  async switchToFolder(
    folder: FileFolder,
    videoListController: VideoListController,
    fileFolderSource: FileFolderDataSource,
    searchValue: string = ''
  ): Promise<FileFolder[]> {
    if (videoListController.folder?.date === folder.date) {
      return await FileFolderUtil.getAllFolderAsync(this.context)
    }

    // 刷新文件夹列表
    const updatedFolders = await FileFolderUtil.getAllFolderAsync(this.context)
    fileFolderSource.updateData(updatedFolders)

    // 获取目标文件夹的最新数据
    const currentFolder = fileFolderSource.getFileFolder(folder.name)
    if (currentFolder) {
      // 应用搜索过滤
      let videosToShow = currentFolder.video_list
      if (searchValue.length > 0) {
        videosToShow = SelectFileUtil.getItemFromSearch(currentFolder.video_list, searchValue)
      }

      videoListController.videoDataSource.updateData(videosToShow)
      videoListController.updateData(videoListController.videoDataSource, currentFolder)

      // 同步面包屑选中状态
      AppStorage.setOrCreate('scrollToFolderDate', folder.date)
    }

    return updatedFolders
  }

  /**
   * 重命名文件夹
   * @param folder 要重命名的文件夹
   * @param newName 新名称
   * @param fileFolderSource 文件夹数据源
   */
  async renameFolder(
    folder: FileFolder,
    newName: string,
    fileFolderSource: FileFolderDataSource
  ): Promise<void> {
    await FileFolderUtil.changeFileFolderName(this.context, folder, newName, fileFolderSource)
  }

  /**
   * 创建新文件夹
   * @param name 文件夹名称
   */
  async createFolder(name: string): Promise<FileFolder[]> {
    return await FileFolderUtil.createNewFolder(this.context, name)
  }

  /**
   * 刷新所有文件夹数据
   */
  async refreshFolders(): Promise<FileFolder[]> {
    const folders = await FileFolderUtil.getAllFolderAsync(this.context)
    this.onFoldersUpdated(folders)
    return folders
  }
}
