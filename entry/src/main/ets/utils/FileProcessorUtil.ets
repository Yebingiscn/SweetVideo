import { salmonLogger } from 'salmonlogger'
import { FileFolder } from '../interfaces/FileFolderInterface'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import FileFolderUtil from './FileFolderUtil'
import { PathUtils } from './PathUtils'
import SelectFileUtil from './SelectFileUtil'
import ToolsUtil from './ToolsUtil'

const TAG = 'FileProcessorUtil'

// 进度信息接口
export interface ProgressInfo {
  current: number // 当前处理的文件索引
  total: number // 总文件数
  fileName: string // 当前处理的文件名
  stage: 'extracting' | 'cover' | 'saving' // 当前阶段
  failedCount: number // 失败文件数
}

// 独立文件处理工具类
export class FileProcessorUtil {
  public static MAX_CONCURRENT = 12
  public static failedFiles: string[] = []
  private static lastProgressTime: number = 0
  private static readonly PROGRESS_THROTTLE_MS = 100

  public static async processFilesConcurrently(
    fileList: string[],
    context: Context,
    sandbox_video: string,
    sandbox_path: string,
    video_meta_data: VideoMetadata[],
    progressCallback: (info: ProgressInfo) => void,
    fileFolder?: FileFolder
  ): Promise<void> {
    if (fileList.length === 0) {
      ToolsUtil.showToast('没有任何文件被导入哦~')
      return
    }
    FileFolderUtil.duplicateVideo = 0
    FileProcessorUtil.failedFiles = []
    FileProcessorUtil.lastProgressTime = 0

    let processedCount = 0
    let failedCount = 0
    let lastEmittedInfo: ProgressInfo | null = null

    const throttledProgressCallback = (info: ProgressInfo) => {
      lastEmittedInfo = info
      const now = Date.now()
      if (now - FileProcessorUtil.lastProgressTime >= FileProcessorUtil.PROGRESS_THROTTLE_MS ||
          info.current === info.total) {
        FileProcessorUtil.lastProgressTime = now
        progressCallback(info)
      }
    }

    const chunks = FileProcessorUtil.splitListIntoChunks(fileList)
    const workers = chunks.map((chunk): Promise<void> => {
      return (async () => {
        for (const uri of chunk) {
          const fileName = uri.split('/')[uri.split('/').length - 1]

          throttledProgressCallback({
            current: processedCount + 1,
            total: fileList.length,
            fileName: fileName,
            stage: 'extracting',
            failedCount: failedCount
          })

          try {
            await SelectFileUtil.addFile(
              context,
              sandbox_video,
              sandbox_path,
              uri,
              video_meta_data,
              fileFolder
            )
          } catch (error) {
            FileProcessorUtil.failedFiles.push(uri)
            failedCount++
            salmonLogger.addLog(TAG, `处理文件失败: ${fileName}, 错误: ${error}`, true)
          }

          processedCount++

          throttledProgressCallback({
            current: processedCount,
            total: fileList.length,
            fileName: fileName,
            stage: 'saving',
            failedCount: failedCount
          })
        }
      })()
    })
    await Promise.all(workers)
    if (lastEmittedInfo !== null && (lastEmittedInfo as ProgressInfo).current !== fileList.length) {
      progressCallback({
        current: processedCount,
        total: fileList.length,
        fileName: '',
        stage: 'saving',
        failedCount: failedCount
      })
    }
  }

  // 智能分块算法：按文件大小和数量优化分块，提高负载均衡
  static splitListIntoChunks(list: string[]): string[][] {
    const chunks: string[][] = []
    const chunkCount = Math.min(FileProcessorUtil.MAX_CONCURRENT, list.length) // 实际需要分块数

    // 如果文件数量较少，使用简单的平均分块
    if (list.length <= chunkCount * 2) {
      const baseSize = Math.floor(list.length / chunkCount)
      const remainder = list.length % chunkCount

      let start = 0
      for (let i = 0; i < chunkCount; i++) {
        const extra = i < remainder ? 1 : 0
        const end = start + baseSize + extra
        chunks.push(list.slice(start, end))
        start = end
      }
    } else {
      // 文件数量较多时，使用交错分配策略，确保每个块的负载均衡
      // 这样可以避免某些块处理大文件集合，而其他块处理小文件集合
      for (let i = 0; i < chunkCount; i++) {
        chunks.push([])
      }

      // 交错分配文件到各个块
      for (let i = 0; i < list.length; i++) {
        const chunkIndex = i % chunkCount
        chunks[chunkIndex].push(list[i])
      }
    }

    return chunks
  }
}

export class ConcurrencyManagerUtil {
  // 文件操作队列（按URI分组）
  private static fileQueues: Map<string, AsyncQueue> = new Map()
  // 全局锁存储
  private static locks: Map<string, MutexLock> = new Map()

  // 获取文件操作队列
  static getFileQueue(uri: string): AsyncQueue {
    if (!ConcurrencyManagerUtil.fileQueues.has(uri)) {
      ConcurrencyManagerUtil.fileQueues.set(uri, new AsyncQueue())
    }
    return ConcurrencyManagerUtil.fileQueues.get(uri)!
  }

  // 获取互斥锁
  static getLock(key: string): MutexLock {
    if (!ConcurrencyManagerUtil.locks.has(key)) {
      ConcurrencyManagerUtil.locks.set(key, new MutexLock())
    }
    return ConcurrencyManagerUtil.locks.get(key)!
  }
}

// 实现一个串行的异步队列
class AsyncQueue {
  private tasks: (() => Promise<void>)[] = []
  private running = false

  async run(task: () => Promise<void>): Promise<void> {
    return new Promise((resolve, reject) => {
      const wrappedTask = async () => {
        try {
          await task()
          resolve()
        } catch (e) {
          reject(e)
        } finally {
          this.running = false
          this.runNext()
        }
      }

      this.tasks.push(wrappedTask)
      if (!this.running) {
        this.runNext()
      }
    })
  }

  private runNext() {
    if (this.tasks.length > 0) {
      this.running = true
      const task = this.tasks.shift()!
      task()
    }
  }
}

// 互斥锁实现
class MutexLock {
  private locked = false
  private queue: (() => void)[] = []

  async acquire(): Promise<void> {
    if (!this.locked) {
      this.locked = true
      return
    }
    return new Promise(resolve => this.queue.push(resolve))
  }

  release(): void {
    if (this.queue.length > 0) {
      const next = this.queue.shift()!
      next()
    } else {
      this.locked = false
    }
  }
}

export async function importAndProcessFiles(
  fileList: string[],
  existingVideos: VideoMetadata[],
  onProgressUpdate: (info: ProgressInfo) => void,
  onLoadingChange: (loading: boolean) => void,
  onTotalItemsChange: (totalItems: number) => void,
  fileFolder?: FileFolder,
  onFinally?: () => void
): Promise<void> {
  if (fileList.length === 0) {
    ToolsUtil.showToast(ToolsUtil.getStringResource($r('app.string.no_files_imported').id))
    return
  }
  onLoadingChange(true)
  const totalItems = fileList.length
  onTotalItemsChange(totalItems)
  onProgressUpdate({
    current: 0,
    total: totalItems,
    fileName: '',
    stage: 'extracting',
    failedCount: 0
  })
  try {
    await FileProcessorUtil.processFilesConcurrently(
      fileList, PathUtils.appContext!, PathUtils.videoPath, PathUtils.coverPath, existingVideos,
      (info: ProgressInfo) => {
        onProgressUpdate(info)
      },
      fileFolder
    )
    ToolsUtil.showToast(
      `${ToolsUtil.getStringResource($r('app.string.add_time_info').id)}${totalItems -
        FileFolderUtil.duplicateVideo - FileProcessorUtil.failedFiles.length}${
      FileFolderUtil.duplicateVideo > 0 ? '，跳过重复视频：' + FileFolderUtil.duplicateVideo : ''}${
      FileProcessorUtil.failedFiles.length > 0 ? '，失败：' + FileProcessorUtil.failedFiles.length : ''}`
    )
  } catch (error) {
    ToolsUtil.showToast($r('app.string.processing_error') + error)
  } finally {
    onLoadingChange(false)
    onFinally?.()
  }
}