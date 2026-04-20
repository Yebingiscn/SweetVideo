import { taskpool } from '@kit.ArkTS'
import { VideoSource } from '../common/enum/VideoSource'
import { FileFolder } from '../interfaces/FileFolderInterface'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import SelectFileUtil from './SelectFileUtil'
import { media } from '@kit.MediaKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { image } from '@kit.ImageKit'
import { BusinessError } from '@kit.BasicServicesKit'

@Concurrent
async function checkUriAvailable(fileFolderList: FileFolder[]): Promise<VideoMetadata[]> {
  const deletedVideos: VideoMetadata[] = []
  const videosToCheck: VideoMetadata[] = []

  // 收集需要检查的视频
  for (let folderIndex = 0; folderIndex < fileFolderList.length; folderIndex++) {
    const folder = fileFolderList[folderIndex]
    for (let videoIndex = 0; videoIndex < folder.video_list.length; videoIndex++) {
      const video = folder.video_list[videoIndex]
      if (SelectFileUtil.isPathFromSource(video.uri, VideoSource.EXTERNAL_DEVICE)) {
        continue
      }
      videosToCheck.push(video)
    }
  }

  // 并行检查视频是否存在
  const checkPromises = videosToCheck.map(async (video: VideoMetadata) => {
    try {
      let exists = false
      try {
        exists = await SelectFileUtil.isFileExist(video.uri, false)
      } catch (isExistError) {
        console.error('调用isFileExist失败:', isExistError)
        exists = false
      }
      if (!exists) {
        deletedVideos.push(video)
      }
    } catch (error) {
      console.warn(`检查文件存在性失败: ${video.uri}`, error)
    }
  })

  await Promise.all(checkPromises)
  return deletedVideos
}

export function checkUriProcess(param: FileFolder[], callback: (re: Object) => void) {
  taskpool.execute(new taskpool.Task(checkUriAvailable, param), taskpool.Priority.HIGH).then((result: Object) => {
    callback(result)
  })?.catch((err: string) => {
    console.error("taskPoolTest test occur error: " + err)
  })
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

  try {
    // 创建元数据提取器
    avMetadataExtractor = await media.createAVMetadataExtractor()

    // 打开文件
    file = fs.openSync(uri)
    const fileName = file.name

    // 获取文件大小
    const stat = fs.statSync(file.fd)
    const fileSize = stat.size

    // 设置文件源并提取元数据
    avMetadataExtractor.fdSrc = file
    const metadata = await new Promise<media.AVMetadata>((resolve, reject) => {
      avMetadataExtractor!.fetchMetadata((error: BusinessError, metadata: media.AVMetadata) => {
        error ? reject(error) : resolve(metadata)
      })
    })

    // 尝试提取封面
    let pixelMap: image.PixelMap | undefined
    try {
      pixelMap = await avMetadataExtractor.fetchAlbumCover()
    } catch (coverError) {
      // 封面提取失败，返回 undefined（不使用 salmonLogger，TaskPool 中无法访问）
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
    // 确保释放资源
    if (file) {
      try {
        fs.closeSync(file)
      } catch (error) {
        console.error('关闭文件失败:', error)
      }
    }
    if (avMetadataExtractor) {
      try {
        avMetadataExtractor.release?.().catch(() => {
        })
      } catch (error) {
        console.error('释放元数据提取器失败:', error)
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
    // 确保释放资源
    if (avImageGenerator) {
      try {
        avImageGenerator.release()?.catch(() => {
          console.error('avImageGenerator release error')
        })
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
    // 计算提取帧的时间点（微秒）
    const timeUs = (duration > 0) ? duration * 100 : 0

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