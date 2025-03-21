import { common } from '@kit.AbilityKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileUri, fileIo as fs, picker } from '@kit.CoreFileKit';
import VideoUtil from './VideoInfoUtil';
import VideoInfoUtil, { VideoMetadata } from './VideoInfoUtil';
import { BusinessError } from '@kit.BasicServicesKit';
import PreferencesUtil from './PreferencesUtil';
import { hilog } from '@kit.PerformanceAnalysisKit';
import ToolsUtil from './ToolsUtil';
import { media } from '@kit.MediaKit';

class SelectFileUtil {
  private static queryCache = new WeakMap<VideoMetadata[], Map<string, VideoMetadata>>();
  public file_folder_uri = ''

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

  async getDownloadUri() {
    const documentViewPicker = new picker.DocumentViewPicker()
    let documentSaveResult = await documentViewPicker.save({ pickerMode: picker.DocumentPickerMode.DOWNLOAD })
    const uri = new fileUri.FileUri(documentSaveResult[0])
    this.file_folder_uri = uri.path
  }

  copyFile(item: VideoMetadata, context: common.UIAbilityContext) {
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

  async copyFileToPrivacySpace(video_meta_data_encryption: VideoMetadata[], uri: string, sandbox_video: string,
    encryption: boolean, sandbox_path: string, date: string, metadata: media.AVMetadata,
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
        await VideoInfoUtil.setVideoInfo(date, targetPath, file.name, metadata, encryption, sandbox_video, sandbox_path)
      video_meta_data_encryption.push(videoInfo);
      await this.saveVideoMetaDataEncryption(video_meta_data_encryption);
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

  async getVideoMetaData() {
    return await PreferencesUtil.getPreferencesValue('sweet_video', 'video_meta_data', []) as VideoMetadata[]
  }

  async getVideoMetaDataEncryption() {
    return await PreferencesUtil.getPreferencesValue('sweet_video', 'video_meta_data_encryption', []) as VideoMetadata[]
  }

  async getPassword() {
    return await PreferencesUtil.getPreferencesValue('sweet_video', 'passwd', '') as string
  }

  async saveVideoMetaData(video_meta_data: VideoMetadata[]) {
    await PreferencesUtil.putPreferencesValue('sweet_video', 'video_meta_data', video_meta_data);
  }

  async saveVideoMetaDataEncryption(video_meta_data_encryption: VideoMetadata[]) {
    await PreferencesUtil.putPreferencesValue('sweet_video', 'video_meta_data_encryption', video_meta_data_encryption);
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

  getAllItems(list: VideoMetadata[]) {
    return list.map(i => i.date)
  }

  getItemFromSearch(list: VideoMetadata[], value: string): string[] {
    const lowerValue = value.toLowerCase().trim();
    const results: string[] = [];
    for (const item of list) {
      if (item.title.toLowerCase().includes(lowerValue)) {
        results.push(item.date);
      }
    }
    return results;
  }

  getItemIndex(list: VideoMetadata[], tmp: VideoMetadata) {
    return list.findIndex(i => i.title == tmp.title)
  }

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