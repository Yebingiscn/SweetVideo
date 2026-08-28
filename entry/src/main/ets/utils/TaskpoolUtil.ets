import { taskpool } from '@kit.ArkTS'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import { fileIo as fs } from '@kit.CoreFileKit'
import { pinyin4js } from '@ohos/pinyin4js'

export class FolderNameSortItem {
  date: string
  name: string
  index: number
  parts: string[] = []

  constructor(date: string, name: string, index: number) {
    this.date = date
    this.name = name
    this.index = index
  }
}
@Concurrent
async function sortFolderNamesTask(items: FolderNameSortItem[], ascending: boolean,
  pinyinSort: boolean): Promise<string[]> {
  const collator = new Intl.Collator('zh-CN', {
    sensitivity: 'variant',
    numeric: true,
    ignorePunctuation: false,
    caseFirst: 'upper'
  })
  const splitRegex = /(\d+)/g
  items.forEach(item => {
    // 拼音只生成一次；旧实现会在排序比较阶段重复拆分和比较字符串。
    item.parts = (pinyinSort ? pinyin4js.getShortPinyin(item.name || '') as string : item.name || '')
      .split(splitRegex).filter(Boolean)
  })
  items.sort((left, right) => {
    const leftParts = left.parts
    const rightParts = right.parts
    for (let i = 0; i < Math.min(leftParts.length, rightParts.length); i++) {
      const a = leftParts[i]
      const b = rightParts[i]
      const aIsNumber = /^\d+$/.test(a)
      const bIsNumber = /^\d+$/.test(b)
      let compare = 0
      if (aIsNumber && bIsNumber) {
        compare = Number(a) - Number(b)
      } else {
        compare = collator.compare(a, b)
      }
      if (compare !== 0) {
        return ascending ? compare : -compare
      }
    }
    const compare = leftParts.length - rightParts.length
    if (compare !== 0) {
      return ascending ? compare : -compare
    }
    // 明确稳定排序，避免同名文件夹在每次刷新时无意义跳动。
    return left.index - right.index
  })
  return items.map(item => item.date)
}

export async function sortFolderNamesInTaskPool(items: FolderNameSortItem[], ascending: boolean = true,
  pinyinSort: boolean = true): Promise<string[]> {
  try {
    const result = await taskpool.execute(
      new taskpool.Task(sortFolderNamesTask, items, ascending, pinyinSort),
      taskpool.Priority.HIGH
    )
    return result as string[]
  } catch (error) {
    return []
  }
}

@Concurrent
async function checkUriAvailable(videos: VideoMetadata[]): Promise<VideoMetadata[]> {
  const invalidVideos: VideoMetadata[] = []
  await Promise.all(videos.map(async (video: VideoMetadata) => {
    let file: fs.File | undefined
    try {
      file = await fs.open(video.uri, fs.OpenMode.READ_ONLY)
    } catch {
      invalidVideos.push(video)
    } finally {
      if (file) {
        try {
          fs.closeSync(file)
        } catch {}
      }
    }
  }))
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
