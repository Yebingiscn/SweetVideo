import { FileFolder } from '../interfaces/FileFolderInterface'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import FileFolderUtil from './FileFolderUtil'
import SelectFileUtil from './SelectFileUtil'
import ToolsUtil from './ToolsUtil'
import { salmonLogger } from 'salmonlogger'

// 独立文件处理工具类
export class FileProcessorUtil {
  // 获取视频封面和处理文件的最大并发数
  public static MAX_CONCURRENT = 3

  // 分块并发处理文件列表
  // 设计说明：将文件列表分成 MAX_CONCURRENT 个块，块内串行处理（避免单个文件 I/O 冲突），
  //         块间并行执行（充分利用多核）。同时配合 ConcurrencyManagerUtil.tryMarkImporting 防止
  //         不同块之间的并发重复导入同一文件。
  public static async processFilesConcurrently(
    fileList: string[],
    context: Context,
    sandbox_video: string,
    sandbox_path: string,
    video_meta_data: VideoMetadata[],
    progressCallback: (increment: number) => void,
    fileFolder?: FileFolder
  ): Promise<void> {
    if (fileList.length === 0) {
      ToolsUtil.showToast('没有任何文件被导入哦~')
      return
    }
    FileFolderUtil.duplicateVideo = 0 // 这里重置重复视频数
    const chunks = FileProcessorUtil.splitListIntoChunks(fileList)
    const workers = chunks.map((chunk): Promise<void> => {
      return (async () => {
        for (const uri of chunk) {
          // ✅ 原子性检查并标记（防止并发重复导入同个文件）
          if (!ConcurrencyManagerUtil.tryMarkImporting(uri)) {
            salmonLogger.addLog('FileProcessorUtil', `跳过正在导入中的文件: ${uri}`, false)
            FileFolderUtil.duplicateVideo++
            progressCallback(1)
            continue
          }

          try {
            await SelectFileUtil.processSingleFile(
              uri,
              context,
              sandbox_video,
              sandbox_path,
              video_meta_data,
              fileFolder
            )
          } finally {
            // 无论成功失败，都取消标记
            ConcurrencyManagerUtil.unmarkImporting(uri)
          }
          // 通过回调更新进度
          progressCallback(1)
        }
      })()
    })
    await Promise.all(workers)

    // 重复视频提示由调用方（IndexViewModel）统一处理，避免双重 Toast
  }

  // 计算分块大小
  static splitListIntoChunks(list: string[]): string[][] {
    const chunks: string[][] = []
    const chunkCount = Math.min(FileProcessorUtil.MAX_CONCURRENT, list.length) // 实际需要分块数
    const baseSize = Math.floor(list.length / chunkCount)
    const remainder = list.length % chunkCount

    let start = 0
    for (let i = 0; i < chunkCount; i++) {
      const extra = i < remainder ? 1 : 0
      const end = start + baseSize + extra
      chunks.push(list.slice(start, end))
      start = end
    }
    return chunks
  }
}

export class ConcurrencyManagerUtil {
  // 文件操作队列（按URI分组）
  private static fileQueues: Map<string, AsyncQueue> = new Map()
  // 全局锁存储
  private static locks: Map<string, MutexLock> = new Map()
  // 记录锁的最后访问时间，用于清理
  private static lockLastAccessTime: Map<string, number> = new Map()
  // 正在导入的URI集合，用于防止并发重复导入
  // 说明：同一个文件可能在不同分块中被同时选中，此 Set 提供进程内的原子标记能力
  private static importingUris: Set<string> = new Set()

  // 获取文件操作队列
  // 使用标准化 URI 作为 key，确保来自不同来源（如相册/文件管理器）的同一文件进入同一队列
  static getFileQueue(uri: string): AsyncQueue {
    const normalizedUri = ConcurrencyManagerUtil.normalizeUri(uri)
    if (!ConcurrencyManagerUtil.fileQueues.has(normalizedUri)) {
      ConcurrencyManagerUtil.fileQueues.set(normalizedUri, new AsyncQueue())
    }
    return ConcurrencyManagerUtil.fileQueues.get(normalizedUri)!
  }

  // 获取互斥锁
  // 对 URI 类型的 key 进行标准化，避免 ?timestamp=xxx 等查询参数导致同一文件生成多把锁
  static getLock(key: string): MutexLock {
    const normalizedKey = key.startsWith('file://') || key.startsWith('http')
      ? ConcurrencyManagerUtil.normalizeUri(key)
      : key
    if (!ConcurrencyManagerUtil.locks.has(normalizedKey)) {
      ConcurrencyManagerUtil.locks.set(normalizedKey, new MutexLock())
    }
    ConcurrencyManagerUtil.lockLastAccessTime.set(normalizedKey, Date.now())
    return ConcurrencyManagerUtil.locks.get(normalizedKey)!
  }

  // 清理长时间未使用的锁（建议在应用进入后台时调用），防止 Map 无限增长导致内存泄漏
  static cleanupIdleLocks(maxIdleTime: number = 5 * 60 * 1000): number {
    const now = Date.now()
    let cleanedCount = 0
    // ArkTS 不支持 for...of 解构声明，使用传统方式遍历
    const keys = Array.from(ConcurrencyManagerUtil.lockLastAccessTime.keys())
    for (const key of keys) {
      const lastAccess = ConcurrencyManagerUtil.lockLastAccessTime.get(key)
      if (lastAccess !== undefined && now - lastAccess > maxIdleTime) {
        const lock = ConcurrencyManagerUtil.locks.get(key)
        if (lock && lock.isIdle()) {
          ConcurrencyManagerUtil.locks.delete(key)
          ConcurrencyManagerUtil.lockLastAccessTime.delete(key)
          cleanedCount++
        }
      }
    }
    return cleanedCount
  }

  // 标准化URI：去掉查询参数（比如 ?timestamp=xxx）等差异，确保同一文件被识别为同一个 key
  static normalizeUri(uri: string): string {
    const queryIndex = uri.indexOf('?')
    if (queryIndex > 0) {
      return uri.substring(0, queryIndex)
    }
    return uri
  }

  // 原子性检查并标记URI正在导入，返回是否成功获取锁
  static tryMarkImporting(uri: string): boolean {
    const normalizedUri = ConcurrencyManagerUtil.normalizeUri(uri)
    if (ConcurrencyManagerUtil.importingUris.has(normalizedUri)) {
      return false
    }
    ConcurrencyManagerUtil.importingUris.add(normalizedUri)
    return true
  }

  // 标记URI导入完成（无论成功或失败都必须在 finally 中调用，防止死锁）
  static unmarkImporting(uri: string): void {
    const normalizedUri = ConcurrencyManagerUtil.normalizeUri(uri)
    ConcurrencyManagerUtil.importingUris.delete(normalizedUri)
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

  // ✅ 检查锁是否处于空闲状态（未锁定且无等待队列）
  isIdle(): boolean {
    return !this.locked && this.queue.length === 0
  }
}

export class ConcurrentQueue {
  private static activeCount = 0
  private static pendingQueue: (() => void)[] = []

  public static async enqueue<T>(task: () => Promise<T>): Promise<T> {
    return new Promise((resolve, reject) => {
      const wrappedTask = async () => {
        try {
          const result = await task()
          resolve(result)
        } catch (error) {
          reject(error)
        } finally {
          ConcurrentQueue.activeCount--
          ConcurrentQueue.processNext()
        }
      }

      ConcurrentQueue.pendingQueue.push(wrappedTask)
      ConcurrentQueue.processNext()
    })
  }

  private static processNext() {
    if (ConcurrentQueue.activeCount < FileProcessorUtil.MAX_CONCURRENT &&
      ConcurrentQueue.pendingQueue.length > 0) {
      ConcurrentQueue.activeCount++
      const task = ConcurrentQueue.pendingQueue.shift()!
      Promise.resolve().then(() => task())
    }
  }
}