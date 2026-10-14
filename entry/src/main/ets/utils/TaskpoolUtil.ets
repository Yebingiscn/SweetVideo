import { taskpool } from '@kit.ArkTS'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import { fileIo as fs } from '@kit.CoreFileKit'
import NameSortUtil from './NameSortUtil'
import ToolsUtil from './ToolsUtil'

export class FolderNameSortItem {
  date: string
  name: string
  index: number
  sortKey: string = ''

  constructor(date: string, name: string, index: number) {
    this.date = date
    this.name = name
    this.index = index
  }
}

@Concurrent
async function sortFolderNamesTask(items: FolderNameSortItem[], ascending: boolean,
  pinyinSort: boolean): Promise<number[]> {
  const collator = NameSortUtil.createCollator()
  items.forEach(item => {
    item.sortKey = NameSortUtil.getSortKey(item.name || '', pinyinSort)
  })
  items.sort((left, right) => {
    const compare = collator.compare(left.sortKey, right.sortKey)
    if (compare !== 0) {
      return ascending ? compare : -compare
    }
    // 明确稳定排序，避免同名文件夹在每次刷新时无意义跳动。
    return left.index - right.index
  })
  return items.map(item => item.index)
}

export async function sortFolderNamesInTaskPool(items: FolderNameSortItem[], ascending: boolean = true,
  pinyinSort: boolean = true): Promise<number[]> {
  try {
    const result = await taskpool.execute(
      new taskpool.Task(sortFolderNamesTask, items, ascending, pinyinSort),
      taskpool.Priority.HIGH
    )
    return result as number[]
  } catch (error) {
    throw new Error(ToolsUtil.getStringResource($r('app.string.folder_sort_task_failed').id))
  }
}

@Concurrent
async function checkUriAvailable(videos: VideoMetadata[]): Promise<VideoMetadata[]> {
  const invalidVideos: VideoMetadata[] = []
  // 限制同时打开的文件数，避免大媒体库耗尽文件描述符。
  for (let start = 0; start < videos.length; start += 16) {
    await Promise.all(videos.slice(start, start + 16).map(async (video: VideoMetadata) => {
      let file: fs.File | undefined
      try {
        file = await fs.open(video.uri, fs.OpenMode.READ_ONLY)
      } catch (error) {
        // 只有文件不存在才自动清理；权限、设备或临时 I/O 故障保留条目。
        if ((error as BusinessError).code === 13900002) {
          invalidVideos.push(video)
        }
      } finally {
        if (file) {
          try {
            fs.closeSync(file)
          } catch {
          }
        }
      }
    }))
  }
  return invalidVideos
}

export async function checkUriProcess(videos: VideoMetadata[]): Promise<VideoMetadata[]> {
  try {
    const result = await taskpool.execute(
      new taskpool.Task(checkUriAvailable, videos),
      taskpool.Priority.HIGH
    )
    return result as VideoMetadata[]
  } catch (error) {
    return []
  }
}

// 文件系统信息只负责文件名和大小；媒体内容统一由 FFmpeg 解析。
export interface VideoFileInfoResult {
  fileSize: number
  fileName: string
  success: boolean
  error?: string
}

// TaskPool 任务：读取不会触发媒体解析的文件系统信息。
@Concurrent
async function extractVideoFileInfoTask(uri: string): Promise<VideoFileInfoResult> {
  let file: fs.File | undefined
  try {
    file = fs.openSync(uri, fs.OpenMode.READ_ONLY)
    const stat = fs.statSync(file.fd)
    if (!stat.isFile()) {
      return {
        fileSize: 0,
        fileName: file.name,
        success: false,
        error: ToolsUtil.getStringResource($r('app.string.entry_not_regular_file').id)
      }
    }
    return {
      fileSize: stat.size,
      fileName: file.name,
      success: true
    }
  } catch (error) {
    return {
      fileSize: 0,
      fileName: '',
      success: false,
      error: String(error)
    }
  } finally {
    if (file) {
      try {
        fs.closeSync(file)
      } catch (error) {
        console.error('关闭文件失败:', error)
      }
    }
  }
}

export async function extractVideoFileInfoInTaskPool(uri: string): Promise<VideoFileInfoResult> {
  try {
    const result = await taskpool.execute(
      new taskpool.Task(extractVideoFileInfoTask, uri),
      taskpool.Priority.HIGH
    )
    return result as VideoFileInfoResult
  } catch (error) {
    return {
      fileSize: 0,
      fileName: '',
      success: false,
      error: String(error)
    }
  }
}
