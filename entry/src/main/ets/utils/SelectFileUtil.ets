import { common, Context } from '@kit.AbilityKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileUri, fileIo as fs, picker } from '@kit.CoreFileKit';
import VideoUtil from './VideoInfoUtil';
import VideoInfoUtil from './VideoInfoUtil';
import { BusinessError, systemDateTime } from '@kit.BasicServicesKit';
import { media } from '@kit.MediaKit';
import { VideoMetadataFromPlayer } from '../interfaces/VideoMetadataFromPlayerInterface';
import { VideoMetadata } from '../interfaces/VideoMetadataInterface';
import Preferences from '../database/Preferences';
import PrivacySpaceUtil from './PrivacySpaceUtil';
import ReqPermissionUtil from './ReqPermissionUtil';
import { FileFolder } from '../interfaces/FileFolderInterface';
import FileFolderUtil from './FileFolderUtil';
import { PathUtils } from './PathUtils';
import ToolsUtil from './ToolsUtil';
import RecentPlayUtil from './RecentPlayUtil';
import { ConcurrencyManagerUtil } from './FileProcessorUtil';

// 获取视频类
class SelectFileUtil {
  private static queryCache = new WeakMap<VideoMetadata[], Map<string, VideoMetadata>>();
  public file_folder_uri = ''

  // 从文件管理器获取视频
  async selectFiles(): Promise<string[]> {
    const documentSelectOptions = new picker.DocumentSelectOptions();
    documentSelectOptions.fileSuffixFilters = VideoUtil.support_video_format.concat(VideoUtil.support_audio_format)
    const documentViewPicker = new picker.DocumentViewPicker(PathUtils.appContext!);
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

  saveData(context: Context, target_data: VideoMetadataFromPlayer, play_time?: number, size?: number[],
    start_time?: number, end_time?: number) {
    let save_time: number = 0
    if (play_time && !start_time && !end_time) {
      //计算保存进度，超过这个时间默认用户已经看完，从头开始
      save_time = play_time > target_data?.time * 0.95 ? 0 : play_time
    }
    const updateVideo = (video: VideoMetadata) => {
      if (play_time !== undefined) {
        video.last_play = save_time;
      }
      if (start_time !== undefined) {
        video.start_time = start_time;
      }
      if (end_time !== undefined) {
        video.end_time = end_time;
      }
      if (size?.[0] && video.size[0] === 0) {
        video.size = size;
      }
    };
    if (PrivacySpaceUtil.getPrivacyMode()) {
      //确认是否在隐私空间并更新隐私空间的数据
      const videoMetaDataEncryption = Preferences.getVideoMetaDataEncryption(context);
      const targetVideoMetaDataEncryption = videoMetaDataEncryption.find(v => v.date === target_data.date);
      if (targetVideoMetaDataEncryption) {
        updateVideo(targetVideoMetaDataEncryption);
        Preferences.saveVideoMetaDataEncryption(context, videoMetaDataEncryption);
      }
      return // 隐私空间不需要加入最近播放
    }
    //  更新文件夹的数据
    const folders = Preferences.getFileFolder(context)
    for (const folder of folders) {
      const videoMetaData: VideoMetadata[] = folder.video_list
      const targetVideoMetaData = videoMetaData.find(video => video.date === target_data.date)
      if (targetVideoMetaData) {
        updateVideo(targetVideoMetaData);
      }
    }
    Preferences.saveFileFolder(context, folders)
    //更新最近播放的数据
    const recent_play_deque = Preferences.getRecentPlay(context);
    const recentTargetVideoMetaData = recent_play_deque.find(video => video.date === target_data.date)
    if (recentTargetVideoMetaData) {
      updateVideo(recentTargetVideoMetaData);
    }
    Preferences.saveRecentPlay(context, recent_play_deque)
  }

  deleteVideo(videoMetaData: VideoMetadata) {
    this.deleteVideoFolder(videoMetaData)
    this.deleteVideoEncryption(videoMetaData)
    RecentPlayUtil.delData(PathUtils.appContext!, videoMetaData)
  }

  deleteVideoFolder(videoMetaData: VideoMetadata, currentFolder?: FileFolder) {
    const context = PathUtils.appContext!
    //  更新文件夹的数据
    const folders = Preferences.getFileFolder(context)
    if (currentFolder) {
      const folderIndex = folders.findIndex(i => i.name === currentFolder.name)
      folders[folderIndex].video_list.filter(i => i.date !== videoMetaData.date)
    } else {
      for (let folderIndex = 0; folderIndex < folders.length; folderIndex++) {
        folders[folderIndex].video_list = folders[folderIndex].video_list.filter(i => i.date !== videoMetaData.date)
      }
    }
    Preferences.saveFileFolder(context, folders)
  }

  deleteVideoEncryption(videoMetaData: VideoMetadata) {
    //更新隐私空间的数据
    let videoMetaDataEncryption = Preferences.getVideoMetaDataEncryption(PathUtils.appContext!);
    videoMetaDataEncryption = videoMetaDataEncryption.filter(video => video.date !== videoMetaData.date)
    Preferences.saveVideoMetaDataEncryption(PathUtils.appContext!, videoMetaDataEncryption)
    fs.access(PathUtils.videoPath + videoMetaData.date).then((res: boolean) => {
      if (res) {
        fs.unlink(PathUtils.videoPath + videoMetaData.date, async (unlinkErr) => {
          if (unlinkErr) {
            ToolsUtil.showToast('删除视频失败：' + videoMetaData.title + '原因是：' + unlinkErr.message)
          }
          Preferences.saveVideoMetaDataEncryption(PathUtils.appContext!, videoMetaDataEncryption)
        });
      }
    }).catch((err: BusinessError) => {
      console.error("access failed with error message: " + err.message + ", error code: " + err.code);
    });
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
    return list.findIndex(i => i.date == tmp.date)
  }

  async addFile(context: Context, sandbox_video: string, sandbox_path: string, uri: string,
    video_meta_data: VideoMetadata[], file_folder: FileFolder | undefined) {
    if (canIUse('SystemCapability.Multimedia.Media.AVMetadataExtractor')) {
      await ReqPermissionUtil.persistPermission(uri);
      const avMetadataExtractor: media.AVMetadataExtractor = await media.createAVMetadataExtractor();
      // 获取文件操作队列（按URI串行化），避免重复创建文件夹
      const fileQueue = ConcurrencyManagerUtil.getFileQueue(uri);
      await fileQueue.run(async () => {
        const file = fs.openSync(uri);
        try {
          avMetadataExtractor.fdSrc = file;
          const metadata = await new Promise<media.AVMetadata>((resolve, reject) => {
            avMetadataExtractor.fetchMetadata((error: BusinessError, metadata: media.AVMetadata) => {
              error ? reject(error) : resolve(metadata);
            });
          });
          // 获取全局数据锁（保证原子操作）
          const dataLock = ConcurrencyManagerUtil.getLock('global_data');
          await dataLock.acquire();
          try {
            if (!file_folder) {
              let folderName: string | undefined;
              // 从 uri 中获取文件夹名
              if (uri.startsWith(this.file_folder_uri)) {
                const prefix = this.file_folder_uri + "/";
                const suffix = file.name;
                folderName = uri.substring(prefix.length);
                folderName = folderName.replace(suffix, "");
                const pathArray = folderName.split("/");
                if (pathArray.length > 1) {
                  folderName = pathArray[0];
                }
              }
              if (folderName) {
                const folderLock = ConcurrencyManagerUtil.getLock(`folder_${folderName}`);
                await folderLock.acquire();
                try {
                  // 每次获取最新数据，防止不同线程覆盖数据
                  const latestFolders = Preferences.getFileFolder(context) as FileFolder[];
                  if (!latestFolders.some(i => i.name === folderName)) {
                    await FileFolderUtil.createNewFolder(context, folderName);
                    // 创建后重新获取最新数据
                    file_folder = (Preferences.getFileFolder(context) as FileFolder[])
                      .find(item => item.name === folderName);
                  } else {
                    file_folder = latestFolders.find(item => item.name === folderName);
                  }
                } finally {
                  folderLock.release();
                }
              }
            }
            let isDuplicate = false;
            isDuplicate = FileFolderUtil.existVideoInFolders(context, uri);
            if (!isDuplicate) {
              if (PrivacySpaceUtil.getPrivacyMode()!) {
                await this.copyFileToPrivacySpace(context, video_meta_data, uri, sandbox_video,
                  sandbox_path, systemDateTime.getTime(true).toString(), metadata, file);
              } else {
                const videoInfo =
                  await VideoUtil.setVideoInfo(systemDateTime.getTime(true).toString(), uri, file.name, metadata,
                    sandbox_video, sandbox_path);
                if (file_folder) {
                  file_folder.video_list.push(videoInfo)
                  FileFolderUtil.updateFileFolder(context, file_folder, file_folder.video_list)
                } else {
                  const folders = Preferences.getFileFolder(context)
                  folders[0].video_list.push(videoInfo)
                  Preferences.saveFileFolder(context, folders)
                }
              }
            }
          } finally {
            dataLock.release();
          }
        } finally {
          fs.closeSync(file);
        }
      });
    }
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

  // 从下载文件夹获取视频，视频和文件夹太多，通过分离文件夹和文件两个线程池提高性能，进行递归遍历
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
}

export default new SelectFileUtil()