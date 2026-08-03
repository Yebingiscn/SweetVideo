import { taskpool } from '@kit.ArkTS'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import { media } from '@kit.MediaKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { image } from '@kit.ImageKit'
import { BusinessError } from '@kit.BasicServicesKit'
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

// 元数据提取结果接口
export interface MetadataExtractionResult {
  metadata: media.AVMetadata
  pixelMap: image.PixelMap | undefined
  fileSize: number
  fileName: string
  success: boolean
  error?: string
}

// TaskPool 任务：提取视频元数据和封面
@Concurrent
async function extractVideoMetadataTask(uri: string): Promise<MetadataExtractionResult> {
  let avMetadataExtractor: media.AVMetadataExtractor | undefined
  let file: fs.File | undefined
  let fileSize = 0
  let fileName = ''

  try {
    // 获取文件信息（使用独立的fd，不与AVMetadataExtractor共用同一fd）
    let statFile: fs.File | undefined
    try {
      statFile = fs.openSync(uri, fs.OpenMode.READ_ONLY)
      fileName = statFile.name
      const stat = fs.statSync(statFile.fd)
      fileSize = stat.size
    } catch (error) {
      console.error('获取文件信息失败:', error)
    } finally {
      if (statFile) {
        fs.closeSync(statFile)
      }
    }

    // 创建元数据提取器（使用新的fd，确保不与stat共用）
    avMetadataExtractor = await media.createAVMetadataExtractor()
    file = fs.openSync(uri, fs.OpenMode.READ_ONLY)
    let avFileDescriptor: media.AVFileDescriptor = { fd: file.fd }
    avMetadataExtractor.fdSrc = avFileDescriptor

    const metadata = await new Promise<media.AVMetadata>((resolve, reject) => {
      avMetadataExtractor!.fetchMetadata((error: BusinessError, metadata: media.AVMetadata) => {
        error ? reject(error) : resolve(metadata)
      })
    })

    let pixelMap: image.PixelMap | undefined
    try {
      pixelMap = await avMetadataExtractor.fetchAlbumCover()
    } catch (coverError) {
      console.error('fetchAlbumCover failed:', coverError)
    }

    return {
      metadata: metadata,
      pixelMap: pixelMap,
      fileSize: fileSize,
      fileName: fileName,
      success: true
    }
  } catch (error) {
    return {
      metadata: {} as media.AVMetadata,
      pixelMap: undefined,
      fileSize: 0,
      fileName: '',
      success: false,
      error: String(error)
    }
  } finally {
    // 先释放AVMetadataExtractor，再关闭fd，避免释放时访问已关闭的fd
    if (avMetadataExtractor) {
      try {
        await avMetadataExtractor.release()
      } catch (error) {
        console.error('释放元数据提取器失败:', error)
      }
    }
    if (file) {
      try {
        fs.closeSync(file)
      } catch (error) {
        console.error('关闭文件失败:', error)
      }
    }
  }
}

// 导出函数：使用 TaskPool 提取视频元数据
export async function extractVideoMetadataInTaskPool(uri: string): Promise<MetadataExtractionResult> {
  try {
    const result = await taskpool.execute(
      new taskpool.Task(extractVideoMetadataTask, uri),
      taskpool.Priority.HIGH
    )
    return result as MetadataExtractionResult
  } catch (error) {
    return {
      metadata: {} as media.AVMetadata,
      pixelMap: undefined,
      fileSize: 0,
      fileName: '',
      success: false,
      error: String(error)
    }
  }
}

// 视频帧提取结果接口
export interface VideoFrameExtractionResult {
  pixelMap: image.PixelMap | undefined
  success: boolean
  error?: string
}

// TaskPool 任务：从视频中提取指定时间的帧作为封面
@Concurrent
async function extractVideoFrameAsCoverTask(
  uri: string,
  width: number,
  height: number,
  timeUs: number
): Promise<VideoFrameExtractionResult> {
  let avImageGenerator: media.AVImageGenerator | undefined
  let file: fs.File | undefined

  try {
    avImageGenerator = await media.createAVImageGenerator()
    file = fs.openSync(uri, fs.OpenMode.READ_ONLY)
    let avFileDescriptor: media.AVFileDescriptor = { fd: file.fd }
    avImageGenerator.fdSrc = avFileDescriptor

    let queryOption = media.AVImageQueryOptions.AV_IMAGE_QUERY_PREVIOUS_SYNC
    let param: media.PixelMapParams = {
      width: width,
      height: height
    }

    const pixelMap = await avImageGenerator.fetchFrameByTime(timeUs, queryOption, param)

    return {
      pixelMap: pixelMap,
      success: true
    }
  } catch (error) {
    return {
      pixelMap: undefined,
      success: false,
      error: String(error)
    }
  } finally {
    // 先释放AVImageGenerator，再关闭fd，避免释放时访问已关闭的fd
    if (avImageGenerator) {
      try {
        await avImageGenerator.release()
      } catch (error) {
        console.error('释放 AVImageGenerator 失败:', error)
      }
    }
    if (file) {
      try {
        fs.closeSync(file)
      } catch (error) {
        console.error('关闭文件失败:', error)
      }
    }
  }
}

// 导出函数：使用 TaskPool 从视频中提取帧作为封面
export async function extractVideoFrameAsCoverInTaskPool(
  uri: string,
  width: number,
  height: number,
  duration: number
): Promise<VideoFrameExtractionResult> {
  try {
    // 1小时以下截取第一帧，1小时以上截取第3分钟（微秒）
    const oneHourMs = 3600000
    const timeUs = (duration >= oneHourMs) ? 180000000 : 0

    const result = await taskpool.execute(
      new taskpool.Task(extractVideoFrameAsCoverTask, uri, width, height, timeUs),
      taskpool.Priority.HIGH
    )
    return result as VideoFrameExtractionResult
  } catch (error) {
    return {
      pixelMap: undefined,
      success: false,
      error: String(error)
    }
  }
}
