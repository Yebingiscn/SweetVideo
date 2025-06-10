import { FileFolder } from '../interfaces/FileFolderInterface';
import { VideoMetadata } from '../interfaces/VideoMetadataInterface';
import SelectFileUtil from './SelectFileUtil';
import ToolsUtil from './ToolsUtil';

export class FileProcessorUtil {
  // 独立文件处理工具类
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

    const chunkSize = SelectFileUtil.calculateChunkSize(fileList.length);
    const chunks = SelectFileUtil.splitListIntoChunks(fileList, chunkSize);

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
}