import { taskpool } from '@kit.ArkTS'
import { VideoSource } from '../common/enum/VideoSource'
import { FileFolder } from '../interfaces/FileFolderInterface'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import { PathUtils } from './PathUtils'
import RecentPlayUtil from './RecentPlayUtil'
import SelectFileUtil from './SelectFileUtil'
import SubtitleUtil from './SubtitleUtil'

@Concurrent
async function checkUriAvailable(fileFolderList: FileFolder[]): Promise<VideoMetadata[]> {
  const deletedVideos: VideoMetadata[] = []
  const cleanupPromises: Promise<void>[] = []
  const videosToCheck: VideoMetadata[] = []
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
        const cleanupTask = (async () => {
          try {
            await Promise.all([
              SubtitleUtil.deleteSubtitle(PathUtils.subtitlePath, video.date!),
              RecentPlayUtil.delData(PathUtils.appContext!, video.uri),
              SelectFileUtil.deleteCover(video.date!)
            ])
          } catch (error) {
            console.warn(`清理视频资源失败: ${video.uri}`, error)
          }
        })()
        cleanupPromises.push(cleanupTask)
      }
    } catch (error) {
      console.warn(`检查文件存在性失败: ${video.uri}`, error)
    }
  })
  await Promise.all(checkPromises)
  await Promise.all(cleanupPromises)
  return deletedVideos
}

export function checkUriProcess(param: FileFolder[], callback: (re: Object) => void) {
  taskpool.execute(new taskpool.Task(checkUriAvailable, param), taskpool.Priority.HIGH).then((result: Object) => {
    callback(result)
  })?.catch((err: string) => {
    console.error("taskPoolTest test occur error: " + err)
  })
}