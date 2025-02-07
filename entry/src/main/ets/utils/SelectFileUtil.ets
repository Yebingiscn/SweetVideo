import { common } from '@kit.AbilityKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo as fs, picker } from '@kit.CoreFileKit';
import VideoUtil, { VideoMetadata } from './VideoInfoUtil';
import { BusinessError } from '@kit.BasicServicesKit';
import PreferencesUtil from './PreferencesUtil';

class SelectFileUtil {
  private queryCache = new Map<string, VideoMetadata>();

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
    if (this.queryCache.has(item)) {
      return this.queryCache.get(item);
    }
    const foundItem = list.find(i => i.date == item);
    if (foundItem) {
      this.queryCache.set(item, foundItem);
    }
    return foundItem;
  }

  getNextItem(list: VideoMetadata[], item: string) {
    const currentIndex = list.findIndex(i => i.date === item);
    const nextIndex = (currentIndex + 1) % list.length; // 如果是最后一个，则返回 0
    return list[nextIndex];
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