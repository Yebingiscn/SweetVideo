import { common, Context } from '@kit.AbilityKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileUri, fileIo as fs, picker } from '@kit.CoreFileKit';
import VideoUtil from './VideoInfoUtil';
import VideoInfoUtil from './VideoInfoUtil';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import ToolsUtil from './ToolsUtil';
import { media } from '@kit.MediaKit';
import { VideoMetadataFromPlayer } from '../interfaces/VideoMetadataFromPlayerInterface';
import { VideoMetadata } from '../interfaces/VideoMetadataInterface';
import Preferences from '../database/Preferences';
import PrivacySpaceUtil from './PrivacySpaceUtil';
import ReqPermissionUtil from './ReqPermissionUtil';
import { FileFolder } from '../interfaces/FileFolderInterface';
import FileFolderUtil from './FileFolderUtil';

// 获取视频类
class SelectFileUtil {
  private static queryCache = new WeakMap<VideoMetadata[], Map<string, VideoMetadata>>();
  public file_folder_uri = ''

  // 从文件管理器获取视频
  async selectFiles(): Promise<string[]> {
    const documentSelectOptions = new picker.DocumentSelectOptions();
    documentSelectOptions.fileSuffixFilters = VideoUtil.support_video_format.concat(VideoUtil.support_audio_format)
    let context = getContext(this) as common.Context;
    const documentViewPicker = new picker.DocumentViewPicker(context);
    try {
      const documentSelectResult: string[] = await documentViewPicker.select(documentSelectOptions);
      return documentSelectResult.length > 0 ? documentSelectResult : []; // 返回结果或空数组
    } catch (error) {
      console.error("Error selecting files:", error);
      return []; // 捕获错误并返回空数组
    }
  }

  // 从图库获取视频
  async selectVideo(): Promise<string[]> { // 确保返回类型是 Promise<string[]>
    const photoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
    photoSelectOptions.MIMEType = photoAccessHelper.PhotoViewMIMETypes.VIDEO_TYPE;
    const photoViewPicker = new photoAccessHelper.PhotoViewPicker();
    try {
      const photoSelectResult: photoAccessHelper.PhotoSelectResult = await photoViewPicker.select(photoSelectOptions);
      return photoSelectResult.photoUris.length > 0 ? photoSelectResult.photoUris : [];
    } catch (error) {
      console.error("Error selecting videos:", error);
      return []; // 捕获错误并返回空数组
    }
  }

  // 获取外挂字幕
  async selectExternalSubtitles(sandbox_subtitle: string, date: string) {
    const documentSelectOptions = new picker.DocumentSelectOptions();
    documentSelectOptions.fileSuffixFilters = VideoUtil.support_subtitle_format;
    documentSelectOptions.maxSelectNumber = 1
    let context = getContext(this) as common.Context;
    const documentViewPicker = new picker.DocumentViewPicker(context);
    documentViewPicker.select(documentSelectOptions).then((uris) => {
      if (uris.length > 0) {
        try {
          let file1 = fs.openSync(uris[0], fs.OpenMode.READ_ONLY)
          let file2 = fs.openSync(sandbox_subtitle + date, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE)
          fs.copyFileSync(file1.fd, file2.fd)
          fs.closeSync(file1.fd)
          fs.closeSync(file2.fd)
          ToolsUtil.showToast('导入成功')
        } catch (err) {
          hilog.error(777, 'testFlag', 'err' + err)
          ToolsUtil.showToast('导入失败')
        }
      }
    })
  }

  // 检查字幕是否存在
  async isSubtitleExist(sandbox_subtitle: string, date: string): Promise<boolean> {
    return new Promise((resolve) => {
      fs.access(sandbox_subtitle + date).then((res: boolean) => {
        if (res) {
          resolve(true);
        } else {
          resolve(false);
        }
      }).catch((err: BusinessError) => {
        console.error("access failed with error message: " + err.message + ", error code: " + err.code);
        resolve(false);
      });
    })
  }

  // 删除字幕
  async deleteSubtitle(sandbox_subtitle: string, date: string) {
    fs.access(sandbox_subtitle + date, (err) => {
      if (!err) { // 文件存在
        fs.unlink(sandbox_subtitle + date, (unlinkErr) => {
          if (unlinkErr) {
            ToolsUtil.showToast('删除失败')
          } else {
            ToolsUtil.showToast('删除成功')
          }
        })
      }
    })
  }

  // 获取下载文件夹路径
  async getDownloadUri() {
    const documentViewPicker = new picker.DocumentViewPicker()
    let documentSaveResult = await documentViewPicker.save({ pickerMode: picker.DocumentPickerMode.DOWNLOAD })
    const uri = new fileUri.FileUri(documentSaveResult[0])
    this.file_folder_uri = uri.path
  }

  // 导出视频文件
  exportFile(item: VideoMetadata, context: common.UIAbilityContext) {
    let file = fs.openSync(item.uri)
    let saverOption = new picker.DocumentSaveOptions()
    saverOption.newFileNames = this.copyFileReName(item)
    let saver = new picker.DocumentViewPicker(context)
    saver.save(saverOption, (err: BusinessError, documentSaveResult: string[]) => {
      if (!err) {
        let file1 = fs.openSync(documentSaveResult[0], fs.OpenMode.READ_WRITE)
        fs.copyFileSync(file.fd, file1.fd)
        fs.close(file.fd)
        fs.close(file1.fd)
      }
    })
  }

  //复制视频进入隐私空间
  async copyFileToPrivacySpace(context: Context, video_meta_data_encryption: VideoMetadata[], uri: string,
    sandbox_video: string, sandbox_path: string, date: string, metadata: media.AVMetadata,
    file: fs.File): Promise<VideoMetadata> {
    const file1 = fs.openSync(uri, fs.OpenMode.READ_ONLY);
    const targetPath = `${sandbox_video}${date}`;
    const file2 = fs.openSync(targetPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
    try {
      await new Promise<void>((resolve, reject) => {
        fs.copyFile(file1.fd, file2.fd, (error) => {
          error ? reject(error) : resolve();
        });
      });
      const videoInfo =
        await VideoInfoUtil.setVideoInfo(date, targetPath, file.name, metadata, sandbox_video, sandbox_path)
      video_meta_data_encryption.push(videoInfo);
      Preferences.saveVideoMetaDataEncryption(context, video_meta_data_encryption);
      return videoInfo; // 返回新创建的元数据对象
    } catch (error) {
      console.error(`文件复制失败: ${uri}`, error);
      throw new Error(`隐私空间复制失败: ${error.message}`);
    } finally {
      fs.closeSync(file1);
      fs.closeSync(file2);
    }
  }

  copyFileReName(item: VideoMetadata) {
    return [item.title.split('.')[item.title.split('.').length - 1]
      == item.format ? item.title : item.title + '.' + item.format]
  }

  async saveData(context: Context, update_list: VideoMetadata[], target_data: VideoMetadataFromPlayer) {
    const results = await Promise.all([
      Preferences.getVideoMetaData(context),
      Preferences.getVideoMetaDataEncryption(context),
      Preferences.getRecentPlay(context)
    ]);
    const tmp_meta_data = results[0];
    const tmp_meta_data_encryption = results[1];
    const recent_play_deque = results[2];
    if (tmp_meta_data.some(item => item.date === target_data.date)) {
      Preferences.saveVideoMetaData(context, update_list)
    }
    if (tmp_meta_data_encryption.some(item => item.date === target_data.date)) {
      Preferences.saveVideoMetaDataEncryption(context, update_list)
    }
    if (recent_play_deque.some(item => item.date === target_data.date)) {
      Preferences.saveRecentPlay(context, update_list)
    }
  }

  getItem(list: VideoMetadata[], item: string): VideoMetadata | undefined {
    if (!list || !item) {
      return undefined;
    }
    if (!SelectFileUtil.queryCache.has(list)) {
      SelectFileUtil.queryCache.set(list, new Map());
    }
    const listCache = SelectFileUtil.queryCache.get(list)!;
    if (listCache.has(item)) {
      return listCache.get(item);
    }
    const dateMap = new Map(list.map(i => [i.date, i]));
    const foundItem = dateMap.get(item);
    if (foundItem) {
      const typedListCache: Map<string, VideoMetadata> = listCache;
      typedListCache.set(item, foundItem);
      if (typedListCache.size > (list.length >= 100 ? 100 : list.length * 0.5)) {
        const iterator: IterableIterator<string> = typedListCache.keys();
        const oldestEntry: IteratorResult<string, undefined> = iterator.next();
        if (!oldestEntry.done) {
          const oldestKey: string = oldestEntry.value;
          typedListCache.delete(oldestKey);
        }
      }
    }
    return foundItem;
  }

  // 获取下一个视频
  getNextItem(list: VideoMetadata[], item: string) {
    const currentIndex = list.findIndex(i => i.date === item);
    if (currentIndex === -1) {
      return null;
    } // 如果没有找到当前项，返回 null
    let nextIndex = (currentIndex + 1) % list.length;
    for (let i = 0; i < list.length; i++) {
      if (VideoInfoUtil.videoWidthAndHeightFormat(String(list[nextIndex].size)) !== '0 x 0') {
        return list[nextIndex];
      }
      nextIndex = (nextIndex + 1) % list.length; // 移动到下一个索引
    }
    return list[(currentIndex + 1) % list.length]; // 如果没有找到有效项，返回下一个项
  }

  getItemFromSearch(list: VideoMetadata[], value: string): VideoMetadata[] {
    const lowerValue = value.toLowerCase().trim();
    const results: VideoMetadata[] = [];
    for (const item of list) {
      if (item.title.toLowerCase().includes(lowerValue)) {
        (results as VideoMetadata[]).push(item);
      }
    }
    return results;
  }

  getItemIndex(list: VideoMetadata[], tmp: VideoMetadata) {
    return list.findIndex(i => i.title == tmp.title)
  }

  // 从下载文件夹获取视频，视频和文件夹太多
  async getDownloadFilesUri(): Promise<string[]> {
    const VIDEO_EXTENSIONS = new Set(VideoUtil.support_video_format.concat(VideoInfoUtil.support_audio_format));
    const EXT_REGEX = /\.([a-z0-9]+)$/i; // 预编译正则提升性能

    class ConcurrencyPool {
      private active = new Set<Promise<void>>();
      private pendingQueue: Array<() => void> = [];
      private concurrency: number;

      constructor(concurrency: number) {
        this.concurrency = concurrency;
      }

      async run<T>(task: () => Promise<T>): Promise<T> {
        return new Promise<T>((resolve, reject) => {
          const wrapper = async () => {
            const promise = task()
              .then(resolve)
              .catch(reject)
              .finally(() => {
                this.active.delete(promise as Promise<void>);
                this.processQueue(); // 立即唤醒新任务
              });
            this.active.add(promise as Promise<void>);
          };
          this.pendingQueue.push(wrapper);
          this.processQueue();
        });
      }

      async drain() {
        while (this.active.size > 0 || this.pendingQueue.length > 0) {
          await Promise.allSettled(Array.from(this.active));
          this.processQueue(); // 确保处理剩余任务
        }
      }

      private processQueue() {
        while (this.active.size < this.concurrency && this.pendingQueue.length > 0) {
          const task = this.pendingQueue.shift()!;
          task();
        }
      }
    }

    const isVideoFile = (filePath: string): boolean => {
      const ext = filePath.match(EXT_REGEX)?.[1]?.toLowerCase() || '';
      return VIDEO_EXTENSIONS.has(ext);
    };
    const filePool = new ConcurrencyPool(12); // 文件处理：高并发
    const dirPool = new ConcurrencyPool(24); // 目录遍历：更高并发
    const collectFiles = async (directory: string): Promise<string[]> => {
      try {
        const entries: string[] = await fs.listFile(directory);
        const tasks: Promise<string[]>[] = entries.map((entry: string) => {
          const fullPath: string = `${directory}/${entry}`;
          const handler = async (): Promise<string[]> => {
            const stat = await fs.stat(fullPath);
            if (stat.isFile()) {
              return filePool.run<string[]>(async () =>
              isVideoFile(fullPath) ? [fullPath] : []
              );
            } else if (stat.isDirectory()) {
              return dirPool.run<string[]>(() => collectFiles(fullPath));
            }
            return [];
          };
          return handler();
        });
        const results: PromiseSettledResult<string[]>[] = await Promise.allSettled(tasks);
        return results.flatMap((result: PromiseSettledResult<string[]>) => {
          return result.status === 'fulfilled' ? result.value : [];
        });
      } catch (error) {
        console.error(`Directory ${directory} error:`,
          error instanceof Error ? error.message : 'Unknown error');
        return [];
      }
    };
    try {
      const result = await collectFiles(this.file_folder_uri);
      await dirPool.drain(); // 确保目录任务完成
      await filePool.drain(); // 确保文件任务完成
      return result
    } catch (error) {
      console.error('Root processing failed:', error);
      return [];
    }
  }

  async addFile(context: Context, sandbox_video: string, sandbox_path: string, uri: string,
    video_meta_data: VideoMetadata[], file_folder: FileFolder | undefined) {
    await ReqPermissionUtil.persistPermission(uri);
    const avMetadataExtractor: media.AVMetadataExtractor = await media.createAVMetadataExtractor();
    const file = fs.openSync(uri);
    try {
      avMetadataExtractor.fdSrc = file;
      const metadata = await new Promise<media.AVMetadata>((resolve, reject) => {
        avMetadataExtractor.fetchMetadata((error: BusinessError, metadata: media.AVMetadata) => {
          error ? reject(error) : resolve(metadata);
        });
      });
      let isDuplicate = video_meta_data.some(item => item.title === file.name)
      if (file_folder) {
        isDuplicate = file_folder.video_list.some(item => item.title === file.name)
      }
      if (!isDuplicate) {
        if (PrivacySpaceUtil.getPrivacyMode()!) {
          await this.copyFileToPrivacySpace(context, video_meta_data, uri, sandbox_video,
            sandbox_path, new Date().getTime().toString(), metadata, file)
        } else {
          const videoInfo = await VideoUtil.setVideoInfo(new Date().getTime().toString(), uri, file.name, metadata,
            sandbox_video, sandbox_path);
          if (file_folder) {
            file_folder.video_list.push(videoInfo)
            FileFolderUtil.updateFileFolder(context, file_folder, file_folder.video_list)
          } else {
            video_meta_data.push(videoInfo);
            Preferences.saveVideoMetaData(context, video_meta_data);
          }
        }
      }
    } finally {
      fs.closeSync(file);
    }
  }

  // 计算分块大小
  calculateChunkSize(totalItems: number): number {
    return Math.ceil(totalItems / VideoUtil.MAX_CONCURRENT);
  }

  // 将列表拆分为多个块
  splitListIntoChunks(list: string[], chunkSize: number): string[][] {
    const chunks: string[][] = [];

    for (let i = 0; i < VideoUtil.MAX_CONCURRENT; i++) {
      const start = i * chunkSize;
      if (start >= list.length) {
        break;
      } // 防止空分块

      const end = Math.min(start + chunkSize, list.length);
      chunks.push(list.slice(start, end));
    }

    return chunks;
  }

  async processSingleFile(uri: string, context: Context, sandbox_video: string, sandbox_path: string,
    video_meta_data: VideoMetadata[], fileFolder?: FileFolder): Promise<void> {
    await this.addFile(
      context,
      sandbox_video,
      sandbox_path,
      uri,
      video_meta_data,
      fileFolder
    );
  }
}

export default new SelectFileUtil()