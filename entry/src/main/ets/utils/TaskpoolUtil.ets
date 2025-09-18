import { taskpool } from '@kit.ArkTS';
import { FileFolder } from '../interfaces/FileFolderInterface';
import { VideoMetadata } from '../interfaces/VideoMetadataInterface';
import { PathUtils } from './PathUtils';
import RecentPlayUtil from './RecentPlayUtil';
import SelectFileUtil from './SelectFileUtil';
import SubtitleUtil from './SubtitleUtil';
import ToolsUtil from './ToolsUtil';

@Concurrent
async function checkUriAvailable(fileFolderList: FileFolder[]): Promise<VideoMetadata[]> {
  const deletedVideos: VideoMetadata[] = [];
  const cleanupPromises: Promise<void>[] = [];
  for (let folderIndex = 0; folderIndex < fileFolderList.length; folderIndex++) {
    const videos = fileFolderList[folderIndex];
    for (let videoIndex = 0; videoIndex < videos.video_list.length; videoIndex++) {
      const video = videos.video_list[videoIndex];
      const exists = await ToolsUtil.isFileExist(video.uri);
      if (!exists) {
        deletedVideos.push(video)
        const cleanupTask = (async () => {
          try {
            await Promise.all([
              SubtitleUtil.deleteSubtitle(PathUtils.subtitlePath, video.date!),
              RecentPlayUtil.delData(PathUtils.appContext!, video.uri),
              SelectFileUtil.deleteCover(video.date!)
            ]);
          } catch (error) {
            console.warn(`清理视频资源失败: ${video.uri}`, error);
          }
        })();
        cleanupPromises.push(cleanupTask);
      }
    }
  }
  // 等待所有清理任务完成
  await Promise.all(cleanupPromises);
  return deletedVideos;
}

export function taskpoolExecTool(param: FileFolder[], callback: (re: Object) => void) {
  taskpool.execute(new taskpool.Task(checkUriAvailable, param), taskpool.Priority.HIGH).then((result: Object) => {
    console.info("taskPoolTest task result: " + result);
    callback(result);
  }).catch((err: string) => {
    console.error("taskPoolTest test occur error: " + err);
  })
}