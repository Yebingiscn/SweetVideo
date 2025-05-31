import Preferences from '../database/Preferences'
import { FileFolder } from '../interfaces/FileFolderInterface'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import ToolsUtil from './ToolsUtil'
import { Context } from '@kit.AbilityKit'

// 文件夹类
class FileFolderUtil {
  async createNewFolder(context: Context, folder_name: string): Promise<FileFolder[]> {
    const new_folder: FileFolder = {
      name: folder_name,
      date: new Date().getTime().toString(),
      video_list: []
    }
    const file_folder_list = Preferences.getFileFolder(context) as FileFolder[]
    if (!file_folder_list.some(i => i.name === new_folder.name)) {
      file_folder_list.push(new_folder)
      Preferences.saveFileFolder(context, file_folder_list)
      return file_folder_list
    } else {
      ToolsUtil.showToast('添加失败，已存在相同文件夹')
      return file_folder_list
    }
  }

  async addVideoInFileFolder(context: Context, video_meta_data: VideoMetadata, file_folder_date: string) {
    let file_folder_list = Preferences.getFileFolder(context) as FileFolder[]
    let file_folder = file_folder_list.find(i => i.date === file_folder_date)
    file_folder?.video_list.push(video_meta_data)
    Preferences.saveFileFolder(context, file_folder_list)
    return file_folder_list
  }

  async deleteFileFolder(context: Context, file_folder: FileFolder, file_folder_list: FileFolder[]) {
    file_folder_list = file_folder_list.filter(i => i.date !== file_folder.date)
    Preferences.saveFileFolder(context, file_folder_list)
    return file_folder_list
  }

  async changeFileFolderName(context: Context, file_folder: FileFolder, new_file_folder_name: string,
    file_folder_list: FileFolder[]) {
    file_folder.name = new_file_folder_name
    file_folder_list = file_folder_list.filter(i => i.date !== file_folder.date)
    file_folder_list.push(file_folder)
    Preferences.saveFileFolder(context, file_folder_list)
    return file_folder_list
  }

  async sortByNameFromFileFolder(context: Context, file_folder: FileFolder) {
    let file_folder_list = Preferences.getFileFolder(context)
    file_folder.video_list = ToolsUtil.sortByNameProcess(file_folder.video_list)
    file_folder_list = file_folder_list.filter(i => i.date !== file_folder.date)
    file_folder_list.push(file_folder)
    Preferences.saveFileFolder(context, file_folder_list)
    return file_folder
  }

  async sortByTimeFromFileFolder(context: Context, file_folder: FileFolder) {
    let file_folder_list = Preferences.getFileFolder(context)
    file_folder.video_list = [...file_folder.video_list].sort((a, b) => b.date.localeCompare(a.date));
    file_folder_list = file_folder_list.filter(i => i.date !== file_folder.date)
    file_folder_list.push(file_folder)
    Preferences.saveFileFolder(context, file_folder_list)
    return file_folder
  }
}

export default new FileFolderUtil()