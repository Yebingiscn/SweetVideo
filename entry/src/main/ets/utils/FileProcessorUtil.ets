import { FileFolder } from '../interfaces/FileFolderInterface';
import { VideoMetadata } from '../interfaces/VideoMetadataInterface';
import FileFolderUtil from './FileFolderUtil';
import SelectFileUtil from './SelectFileUtil';
import ToolsUtil from './ToolsUtil';

// 独立文件处理工具类
export class FileProcessorUtil {
  // 获取视频封面和处理文件的最大并发数
  public static MAX_CONCURRENT = 3

  // 分块处理，将文件列表分成多个块，每个块内的文件串行处理，不同块之间并行执行，通过MAX_CONCURRENT控制最大并发数
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
      ToolsUtil.showToast('没有任何文件被导入哦~');
      return;
    }
    FileFolderUtil.duplicateVideo = 0 // 这里重置重复视频数
    const chunks = FileProcessorUtil.splitListIntoChunks(fileList);
    const workers = chunks.map((chunk): Promise<void> => {
      return (async () => {
        for (const uri of chunk) {
          await SelectFileUtil.processSingleFile(
            uri,
            context,
            sandbox_video,
            sandbox_path,
            video_meta_data,
            fileFolder
          );
          // 通过回调更新进度
          progressCallback(1);
        }
      })();
    });
    await Promise.all(workers);
  }

  // 计算分块大小
  static splitListIntoChunks(list: string[]): string[][] {
    const chunks: string[][] = [];
    const chunkCount = Math.min(FileProcessorUtil.MAX_CONCURRENT, list.length); // 实际需要分块数
    const baseSize = Math.floor(list.length / chunkCount);
    const remainder = list.length % chunkCount;

    let start = 0;
    for (let i = 0; i < chunkCount; i++) {
      const extra = i < remainder ? 1 : 0;
      const end = start + baseSize + extra;
      chunks.push(list.slice(start, end));
      start = end;
    }
    return chunks;
  }
}

export class ConcurrencyManagerUtil {
  // 文件操作队列（按URI分组）
  private static fileQueues: Map<string, AsyncQueue> = new Map();
  // 全局锁存储
  private static locks: Map<string, MutexLock> = new Map();

  // 获取文件操作队列
  static getFileQueue(uri: string): AsyncQueue {
    if (!ConcurrencyManagerUtil.fileQueues.has(uri)) {
      ConcurrencyManagerUtil.fileQueues.set(uri, new AsyncQueue());
    }
    return ConcurrencyManagerUtil.fileQueues.get(uri)!;
  }

  // 获取互斥锁
  static getLock(key: string): MutexLock {
    if (!ConcurrencyManagerUtil.locks.has(key)) {
      ConcurrencyManagerUtil.locks.set(key, new MutexLock());
    }
    return ConcurrencyManagerUtil.locks.get(key)!;
  }
}

// 实现一个串行的异步队列
class AsyncQueue {
  private tasks: (() => Promise<void>)[] = [];
  private running = false;

  async run(task: () => Promise<void>): Promise<void> {
    return new Promise((resolve, reject) => {
      const wrappedTask = async () => {
        try {
          await task();
          resolve();
        } catch (e) {
          reject(e);
        } finally {
          this.running = false;
          this.runNext();
        }
      };

      this.tasks.push(wrappedTask);
      if (!this.running) {
        this.runNext();
      }
    });
  }

  private runNext() {
    if (this.tasks.length > 0) {
      this.running = true;
      const task = this.tasks.shift()!;
      task();
    }
  }
}

// 互斥锁实现
class MutexLock {
  private locked = false;
  private queue: (() => void)[] = [];

  async acquire(): Promise<void> {
    if (!this.locked) {
      this.locked = true;
      return;
    }
    return new Promise(resolve => this.queue.push(resolve));
  }

  release(): void {
    if (this.queue.length > 0) {
      const next = this.queue.shift()!;
      next();
    } else {
      this.locked = false;
    }
  }
}

export class ConcurrentQueue {
  private static activeCount = 0;
  private static pendingQueue: (() => void)[] = [];

  public static async enqueue<T>(task: () => Promise<T>): Promise<T> {
    return new Promise((resolve, reject) => {
      const wrappedTask = async () => {
        try {
          const result = await task();
          resolve(result);
        } catch (error) {
          reject(error);
        } finally {
          ConcurrentQueue.activeCount--;
          ConcurrentQueue.processNext();
        }
      };

      ConcurrentQueue.pendingQueue.push(wrappedTask);
      ConcurrentQueue.processNext();
    });
  }

  private static processNext() {
    if (ConcurrentQueue.activeCount < FileProcessorUtil.MAX_CONCURRENT &&
      ConcurrentQueue.pendingQueue.length > 0) {
      ConcurrentQueue.activeCount++;
      const task = ConcurrentQueue.pendingQueue.shift()!;
      Promise.resolve().then(() => task());
    }
  }
}