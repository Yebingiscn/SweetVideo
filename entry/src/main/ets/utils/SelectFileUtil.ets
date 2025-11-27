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
import { FileFolder } from '../interfaces/FileFolderInterface';
import FileFolderUtil from './FileFolderUtil';
import { PathUtils } from './PathUtils';
import ToolsUtil from './ToolsUtil';
import RecentPlayUtil from './RecentPlayUtil';
import { ConcurrencyManagerUtil } from './FileProcessorUtil';
import { image } from '@kit.ImageKit';
import PermissionUtil from './PermissionUtil';
import { VideoSource } from '../common/enum/VideoSource';
import SubtitleUtil from './SubtitleUtil';

// 获取视频类
export default class SelectFileUtil {
  public static fileFolderUri = ''
  public static videoSourcePath = new Map<number, string>([
    [VideoSource.SWEET_VIDEO_DOWNLOAD_FILE, '/storage/Users/currentUser/'],
    [VideoSource.DOCUMENT_SELECT_OPTION, 'file://docs/storage/Users'],
    [VideoSource.PHOTO_SELECT_OPTION, 'file://media/Photo'],
    [VideoSource.PRIVACY_SPACE, '/data/storage/el2'],
    [VideoSource.EXTERNAL_DEVICE, 'file://docs/storage/External']
  ]);
  private static queryCache = new WeakMap<VideoMetadata[], Map<string, VideoMetadata>>();

  // 从文件管理器获取视频
  static async selectFiles(): Promise<string[]> {
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

  // 选择视频（支持多选）
  static async selectVideo(): Promise<string[]> {
    return SelectFileUtil.selectBackgroundImage(photoAccessHelper.PhotoViewMIMETypes.VIDEO_TYPE)
  }

  // 选择壁纸（单选）
  static async selectPhoto(): Promise<string[]> {
    return SelectFileUtil.selectBackgroundImage(photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE, 1)
  }

  static async deletePhoto() {
    fs.access(PathUtils.photoPath! + 'BackgroundImage').then((res: boolean) => {
      if (res) {
        fs.unlink(PathUtils.photoPath! + 'BackgroundImage', async (unlinkErr) => {
          if (unlinkErr) {
            ToolsUtil.showToast('删除自定义背景失败，原因是：' + unlinkErr.message)
          }
          ToolsUtil.showToast('删除自定义背景成功')
        });
      } else {
        ToolsUtil.showToast('自定义背景不存在')
      }
    })?.catch((err: BusinessError) => {
      console.error("access failed with error message: " + err.message + ", error code: " + err.code);
    });
  }

  // 获取下载文件夹路径
  static async getDownloadUri() {
    const documentViewPicker = new picker.DocumentViewPicker()
    let documentSaveResult = await documentViewPicker.save({ pickerMode: picker.DocumentPickerMode.DOWNLOAD })
    const uri = new fileUri.FileUri(documentSaveResult[0])
    SelectFileUtil.fileFolderUri = uri.path
  }

  // 导出视频文件
  static async exportFile(uri: string, title: string, format: string, context: common.UIAbilityContext) {
    let sourceFile: fs.File | null = null;
    let targetFile: fs.File | null = null;
    try {
      sourceFile = fs.openSync(uri)
      const saverOption = new picker.DocumentSaveOptions()
      saverOption.newFileNames = SelectFileUtil.copyFileReName(title, format)
      const documentSaveResult = await new Promise<string[]>((resolve, reject) => {
        const saver = new picker.DocumentViewPicker(context)
        saver.save(saverOption, (err: BusinessError, uris: string[]) => {
          err ? reject(err) : resolve(uris)
        })
      })
      targetFile = fs.openSync(documentSaveResult[0], fs.OpenMode.READ_WRITE)
      await fs.copyFile(sourceFile.fd, targetFile.fd)
      ToolsUtil.showToast(`导出成功: ${targetFile?.name} 路径为: ${targetFile?.path}`)
    } catch (error) {
      ToolsUtil.showToast(`导出失败，原因是：${error}`)
    } finally {
      if (sourceFile) {
        fs.closeSync(sourceFile.fd)
      }
      if (targetFile) {
        fs.closeSync(targetFile.fd)
      }
    }
  }

  static getImageUri() {
    try {
      const isExist = fs.accessSync(PathUtils.photoPath! + 'BackgroundImage');
      return isExist ? fileUri.getUriFromPath(PathUtils.photoPath! + 'BackgroundImage') : '';
    } catch (error) {
      return ''
    }
  }

  static async saveImageToPrivacySpace(sourceFileUri: string) {
    const filePath = PathUtils.photoPath + 'BackgroundImage'; // 定义完整文件路径
    try {
      // 检测文件是否存在
      if (fs.accessSync(filePath)) {
        fs.unlinkSync(filePath); // 存在则直接删除
      }
      let sourceFile = fs.openSync(sourceFileUri, fs.OpenMode.READ_ONLY)
      let targetFile = fs.openSync(filePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
      await new Promise<void>((resolve, reject) => {
        fs.copyFile(sourceFile.fd, targetFile.fd, (error) => {
          error ? reject(error) : resolve();
        });
      });
      fs.closeSync(sourceFile)
      fs.closeSync(targetFile)
    } catch (error) {
      console.error('File operation error:' + error);
    }
  }

  // 保存封面，封面获取后复制到应用私有目录下
  static saveVideoImageToPrivacySpace(sandbox_path: string, date: string, pixelMap: image.PixelMap) {
    let packer = image.createImagePacker()
    try {
      let file1 = fs.openSync(sandbox_path + date, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE)
      // 设置为85平衡内存、导入速度以及图片质量
      packer.packToFile(pixelMap, file1.fd, { format: 'image/webp', quality: 85 }).then(() => {
        fs.closeSync(file1)
      })?.catch((error: BusinessError) => {
        console.error(`Failed to pack the image to file.code ${error.code},message is ${error.message}`);
        fs.closeSync(file1)
      })
    } catch (error) {
      console.error('save cover error:' + error)
    }
  }

  //复制视频进入隐私空间
  static async copyFileToPrivacySpace(context: Context, video_meta_data_encryption: VideoMetadata[], uri: string,
    sandbox_video: string, sandbox_path: string, date: string, metadata: media.AVMetadata,
    file: fs.File): Promise<VideoMetadata> {
    let sourceFile: fs.File | null = null;
    let targetFile: fs.File | null = null;
    try {
      const sourceFile = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      const targetPath = `${sandbox_video}${date}`;
      const targetFile = fs.openSync(targetPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
      await new Promise<void>((resolve, reject) => {
        fs.copyFile(sourceFile.fd, targetFile.fd, (error) => {
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
      fs.closeSync(sourceFile);
      fs.closeSync(targetFile);
    }
  }

  static copyFileReName(title: string, format: string) {
    return [title.split('.')[title.split('.').length - 1]
      == format ? title : title + '.' + format]
  }

  static saveData(context: Context, target_data: VideoMetadataFromPlayer, play_time?: number, size?: number[],
    start_time?: number, end_time?: number, total_time?: number) {
    let save_time: number = 0
    if (target_data.time === 0 && total_time) {
      target_data.time = total_time
    }
    if (play_time && !start_time && !end_time && !total_time) {
      //计算保存进度，超过这个时间默认用户已经看完，从头开始, 但是保存为总时间
      save_time = play_time > target_data?.time * 0.95 ? target_data?.time : play_time
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
      if (total_time && video.time === 0) {
        video.time = total_time
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

  static deleteVideo(videoMetaData: VideoMetadata) {
    SelectFileUtil.deleteVideoFromFolder(videoMetaData)
    SelectFileUtil.deleteVideoEncryption(videoMetaData)
    RecentPlayUtil.delData(PathUtils.appContext!, videoMetaData.uri)
  }

  static deleteVideoFromFolder(videoMetaData: VideoMetadata, currentFolder?: FileFolder) {
    const context = PathUtils.appContext!;
    const folders = Preferences.getFileFolder(context);
    if (!folders || folders.length === 0) {
      return;
    }
    const targetFolders = currentFolder
      ? folders.filter(f => f.name === currentFolder.name)
      : folders;
    targetFolders.forEach(folder => {
      folder.video_list = folder.video_list.filter(video => video.date !== videoMetaData.date);
    });
    Preferences.saveFileFolder(context, folders);
  }

  static deleteVideoEncryption(videoMetaData: VideoMetadata) {
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
    })?.catch((err: BusinessError) => {
      console.error("access failed with error message: " + err.message + ", error code: " + err.code);
    });
  }

  static getItem(list: VideoMetadata[], item: string): VideoMetadata | undefined {
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
  static getNextItem(list: VideoMetadata[], item: string) {
    const currentIndex = list.findIndex(i => i.date === item);
    if (currentIndex === -1) {
      return list[0];
    } // 如果没有找到当前项，返回 第一项
    let nextIndex = (currentIndex + 1) % list.length;
    for (let i = 0; i < list.length; i++) {
      if (VideoInfoUtil.videoWidthAndHeightFormat(String(list[nextIndex].size)) !== '0 x 0') {
        return list[nextIndex];
      }
      nextIndex = (nextIndex + 1) % list.length; // 移动到下一个索引
    }
    return list[(currentIndex + 1) % list.length]; // 如果没有找到有效项，返回下一个项，0x0会自动调用其他播放核心
  }

  static getItemFromSearch(list: VideoMetadata[], value: string): VideoMetadata[] {
    const trimmedValue = value?.trim();
    if (!trimmedValue) {
      return [];
    }
    const lowerValue = trimmedValue.toLowerCase();
    return list.filter(item =>
    item.title.toLowerCase().includes(lowerValue)
    );
  }

  static getItemIndex(list: VideoMetadata[], tmp: VideoMetadata) {
    return list.findIndex(i => i.date == tmp.date)
  }

  static isPathFromSource(path: string | undefined, key: VideoSource) {
    const prefix = SelectFileUtil.videoSourcePath.get(key);
    if (!path || !prefix) {
      return false;
    }
    // 标准化路径比较
    const normalizedPath = path.replace(/\\/g, '/');
    const normalizedPrefix = prefix.replace(/\\/g, '/');
    return normalizedPath.startsWith(normalizedPrefix);
  }

  // 检查文件是否存在
  static async isFileExist(uri: string, showToast: boolean) {
    await PermissionUtil.activatePermission(uri)
    if (SelectFileUtil.isPathFromSource(uri, VideoSource.EXTERNAL_DEVICE)) {
      return true
    }
    try {
      await fs.open(String(uri))
      return true
    } catch (e) {
      console.log('file error' + e)
      if (showToast) {
        ToolsUtil.showToast(uri + '文件已经失效，请重新导入')
      }
      return false
    }
  }

  static async addFile(context: Context, sandbox_video: string, sandbox_path: string, uri: string,
    video_meta_data: VideoMetadata[], file_folder?: FileFolder) {
    if (canIUse('SystemCapability.Multimedia.Media.AVMetadataExtractor')) {
      await PermissionUtil.persistPermission(uri);
      try {
        const avMetadataExtractor: media.AVMetadataExtractor = await media.createAVMetadataExtractor();
        // 获取文件操作队列（按URI串行化），避免重复创建文件夹
        const fileQueue = ConcurrencyManagerUtil.getFileQueue(uri);
        await fileQueue.run(async () => {
          const file = await fs.open(uri);
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
                const folderName = FileFolderUtil.extractRootFolderNameFromUri(uri, file.name)
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
              isDuplicate = FileFolderUtil.existsVideoInFolders(context, uri, file.name);
              if (!isDuplicate) {
                if (PrivacySpaceUtil.getPrivacyMode()!) {
                  await SelectFileUtil.copyFileToPrivacySpace(context, video_meta_data, uri, sandbox_video,
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
            try {
              avMetadataExtractor.release?.()?.catch(() => {
                console.error('avMetadataExtractor release error')
              });
              fs.closeSync(file);
            } catch (error) {
              console.error('关闭文件出错，原因是：' + error)
            }
          }
        });
      } catch (error) {
        console.error('createAVMetadataExtractor 发生错误, 原因是：' + error)
      }
    }
  }

  static async processSingleFile(uri: string, context: Context, sandbox_video: string, sandbox_path: string,
    video_meta_data: VideoMetadata[], fileFolder?: FileFolder): Promise<void> {
    await SelectFileUtil.addFile(
      context,
      sandbox_video,
      sandbox_path,
      uri,
      video_meta_data,
      fileFolder
    );
  }

  static async deletePrivacyVideo(date: string, title: string, video_meta_data_encryption: VideoMetadata[]) {
    await SelectFileUtil.deleteCover(date)
    await SubtitleUtil.deleteSubtitle(PathUtils.subtitlePath, date)
    Preferences.saveVideoMetaDataEncryption(PathUtils.appContext!, video_meta_data_encryption)
    try {
      await fs.unlink(PathUtils.videoPath + date);
      ToolsUtil.showToast('删除成功');
    } catch (err) {
      const error = err as BusinessError;
      if (error.code === 13900002) { // 文件或目录不存在错误码
        console.warn('文件不存在');
      } else {
        console.error('delete failed: ' + error.code + ':' + error.message)
      }
      ToolsUtil.showToast('删除视频失败：' + title + '原因是：' + err)
    }
  }

  // 删除封面
  static async deleteCover(date: string) {
    await new Promise<void>((resolve, reject) => {
      fs.access(PathUtils.coverPath + date, (err) => {
        if (!err) {
          fs.unlink(PathUtils.coverPath + date, (unlinkErr) => {
            if (unlinkErr) {
              if (unlinkErr.code == 13900002) {
                resolve();
              } else {
                reject(new Error(`删除封面失败: ${unlinkErr.message}`));
              }
            } else {
              resolve();
            }
          });
        } else {
          resolve(); // 文件不存在也算删除成功
        }
      });
    });
  }

  private static async selectBackgroundImage(mimeType: photoAccessHelper.PhotoViewMIMETypes,
    maxSelect: number = Number.MAX_SAFE_INTEGER): Promise<string[]> {
    const options = new photoAccessHelper.PhotoSelectOptions()
    options.MIMEType = mimeType
    options.maxSelectNumber = maxSelect
    options.isPhotoTakingSupported = false
    try {
      const picker = new photoAccessHelper.PhotoViewPicker()
      const result: photoAccessHelper.PhotoSelectResult = await picker.select(options)
      return result.photoUris || []
    } catch (error) {
      console.error(`Error selecting media [${mimeType}]:`, error)
      return []
    }
  }

  static async getDownloadFilesUri(): Promise<string[]> {
    const VIDEO_EXTENSIONS = new Set([
      ...VideoUtil.support_video_format,
      ...VideoInfoUtil.support_audio_format
    ].map(ext => ext.toLowerCase()));

    class ConcurrencyPool {
      private active = 0;
      private pending: Array<() => void> = [];
      private concurrency: number;

      constructor(concurrency: number) {
        this.concurrency = concurrency;
      }

      async run<T>(task: () => Promise<T>): Promise<T> {
        // 如果当前活跃任务数达到并发上限，等待
        if (this.active >= this.concurrency) {
          await new Promise<void>(resolve => {
            this.pending.push(resolve);
          });
        }
        this.active++;
        try {
          return await task();
        } finally {
          this.active--;
          // 唤醒下一个等待的任务
          this.pending.shift()?.();
        }
      }

      async drain() {
        // 等待所有活跃任务完成
        while (this.active > 0 || this.pending.length > 0) {
          await new Promise<void>((resolve) => setTimeout(resolve, 10));
        }
      }
    }

    // 更高效的扩展名提取函数
    const isVideoFile = (filePath: string): boolean => {
      const lastDotIndex = filePath.lastIndexOf('.');
      if (lastDotIndex === -1) {
        return false;
      }
      const ext = filePath.slice(lastDotIndex + 1).toLowerCase();
      return VIDEO_EXTENSIONS.has(ext);
    };
    const dirPool = new ConcurrencyPool(8); // 目录遍历并发控制
    const filePaths: string[] = [];
    const processedPaths = new Set<string>(); // 避免重复处理

    const collectFiles = async (directory: string): Promise<void> => {
      if (processedPaths.has(directory)) {
        return;
      }
      processedPaths.add(directory);
      try {
        const entries: string[] = await fs.listFile(directory);
        // 批量处理条目，提高效率
        const batchSize = 50;
        for (let i = 0; i < entries.length; i += batchSize) {
          const batch = entries.slice(i, i + batchSize);
          const batchPromises = batch.map(async (entry: string) => {
            const fullPath: string = `${directory}/${entry}`.replace(/\/+/g, '/'); // 规范化路径
            try {
              const stat = await fs.stat(fullPath);
              if (stat.isFile()) {
                // 同步判断文件类型，避免不必要的异步开销
                if (isVideoFile(fullPath)) {
                  filePaths.push(fullPath);
                }
              } else if (stat.isDirectory()) {
                // 目录遍历使用线程池控制并发
                await dirPool.run(() => collectFiles(fullPath));
              }
            } catch (error) {
              console.warn(`Failed to process ${fullPath}:`,
                error instanceof Error ? error.message : 'Unknown error');
            }
          });
          // 等待当前批次完成，避免内存溢出
          await Promise.allSettled(batchPromises);
        }
      } catch (error) {
        console.error(`Failed to list directory ${directory}:`,
          error instanceof Error ? error.message : 'Unknown error');
      }
    };
    try {
      await collectFiles(SelectFileUtil.fileFolderUri);
      await dirPool.drain(); // 等待所有目录遍历任务完成
      // 去重并返回结果
      return Array.from(new Set(filePaths));
    } catch (error) {
      console.error('Root directory processing failed:', error);
      return [];
    }
  }
}