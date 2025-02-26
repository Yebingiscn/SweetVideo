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
    file: fs.File): Promise<string[]> {
    const file1 = fs.openSync(uri, fs.OpenMode.READ_ONLY);
    const file2 = fs.openSync(sandbox_video + date, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
    return new Promise<string[]>((resolve, reject) => {
      fs.copyFile(file1.fd, file2.fd, async (error) => {
        if (error) {
          reject(error) // 处理错误
        } else {
          video_meta_data_encryption.push(await VideoInfoUtil.setVideoInfo(date, uri, file.name, metadata,
            encryption, sandbox_video, sandbox_path));
          this.saveVideoMetaDataEncryption(video_meta_data_encryption)
          fs.closeSync(file1)
          fs.closeSync(file2)
          resolve(video_meta_data_encryption.map(i => i.date)) // 返回结果
        }
      });
    });
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
      if (lastDotIndex === -1) {
        return false;
      }
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
}

const selectFileUtil = new SelectFileUtil()

export default selectFileUtil as SelectFileUtil