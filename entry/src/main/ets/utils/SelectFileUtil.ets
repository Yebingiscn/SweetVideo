import { common } from '@kit.AbilityKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileUri, fileIo as fs, picker } from '@kit.CoreFileKit';
import VideoUtil, { VideoMetadata } from './VideoInfoUtil';
import { BusinessError } from '@kit.BasicServicesKit';
import PreferencesUtil from './PreferencesUtil';

class SelectFileUtil {
  public file_folder_uri = ''
  private query_cache = new Map<string, VideoMetadata>();

  async selectFiles(): Promise<string[]> {
    const documentSelectOptions = new picker.DocumentSelectOptions();
    documentSelectOptions.fileSuffixFilters = VideoUtil.support_video_format;
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

  async getDownloadFilesUri(): Promise<string[]> {
    const VIDEO_EXTENSIONS = new Set(VideoUtil.support_video_format);
    const MAX_CONCURRENCY = 5; // 控制最大并发数
    class ConcurrencyController {
      private queue: (() => Promise<void>)[] = [];
      private activeCount = 0;
      async run<T>(task: () => Promise<T>): Promise<T> {
        return new Promise((resolve, reject) => {
          const execute = async () => {
            this.activeCount++;
            try {
              const result = await task();
              resolve(result);
            } catch (error) {
              reject(error);
            } finally {
              this.activeCount--;
              this.next();
            }
          };
          this.queue.push(execute);
          this.next();
        });
      }
      private next() {
        while (this.queue.length > 0 && this.activeCount < MAX_CONCURRENCY) {
          const task = this.queue.shift();
          task!();
        }
      }
    }
    const isVideoFile = (filePath: string): boolean => {
      const lastDotIndex = filePath.lastIndexOf('.');
      if (lastDotIndex === -1) return false;
      const ext = filePath.slice(lastDotIndex + 1).toLowerCase();
      return VIDEO_EXTENSIONS.has(ext);
    };
    const controller = new ConcurrencyController();
    const collectFiles = async (directory: string): Promise<string[]> => {
      try {
        const entries = await fs.listFile(directory);
        const tasks = entries.map(entry =>
        controller.run(async () => {
          const fullPath = `${directory}/${entry}`;
          const stat = await fs.stat(fullPath);
          if (stat.isFile()) {
            return isVideoFile(fullPath) ? [fullPath] : [];
          } else if (stat.isDirectory()) {
            return collectFiles(fullPath);
          }
          return [];
        }));
        const nestedResults = await Promise.all(tasks);
        return nestedResults.flat();
      } catch (error) {
        console.error(`处理目录 ${directory} 失败:`, error);
        return [];
      }
    };
    return collectFiles(this.file_folder_uri);
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

  copyFileReName(item: VideoMetadata) {
    return [item.title.split('.')[item.title.split('.').length - 1]
      == item.format ? item.title : item.title + '.' + item.format]
  }

  async getVideMetaData() {
    return await PreferencesUtil.getPreferencesValue('sweet_video', 'video_meta_data', []) as VideoMetadata[]
  }

  async getVideoMetaDataEncryption() {
    return await PreferencesUtil.getPreferencesValue('sweet_video', 'video_meta_data_encryption', []) as VideoMetadata[]
  }

  async getPassword() {
    return await PreferencesUtil.getPreferencesValue('sweet_video', 'passwd', '') as string
  }

  saveVideoMetaData(video_meta_data: VideoMetadata[]) {
    PreferencesUtil.putPreferencesValue('sweet_video', 'video_meta_data', video_meta_data);
  }

  saveVideoMetaDataEncryption(video_meta_data_encryption: VideoMetadata[]) {
    PreferencesUtil.putPreferencesValue('sweet_video', 'video_meta_data_encryption', video_meta_data_encryption);
  }

  getItem(list: VideoMetadata[], item: string) {
    if (this.query_cache.has(item)) {
      return this.query_cache.get(item)
    }
    const foundItem = list.find(i => i.date == item)
    if (foundItem) {
      this.query_cache.set(item, foundItem)
    }
    return foundItem
  }

  getNextItem(list: VideoMetadata[], item: string) {
    const currentIndex = list.findIndex(i => i.date === item)
    const nextIndex = (currentIndex + 1) % list.length // 如果是最后一个，则返回 0
    return list[nextIndex]
  }

  getAllItem(list: VideoMetadata[]) {
    return list.map(i => i.date)
  }

  getSearchItem(list: VideoMetadata[], value: string) {
    return list.filter(i => i.title.toLowerCase().includes(value.toLowerCase())).map(i => i.date)
  }

  getItemIndex(list: VideoMetadata[], tmp: VideoMetadata) {
    return list.findIndex(i => i.title == tmp.title)
  }
}

const selectFileUtil = new SelectFileUtil()

export default selectFileUtil as SelectFileUtil