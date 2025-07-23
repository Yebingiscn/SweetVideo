import Preferences from '../database/Preferences'
import { FileFolder } from '../interfaces/FileFolderInterface'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import ToolsUtil from './ToolsUtil'
import { Context } from '@kit.AbilityKit'
import { systemDateTime } from '@kit.BasicServicesKit'

// 文件夹类
class FileFolderUtil {
  static getAllFolder(context: Context): FileFolder[] {
    return Preferences.getFileFolder(context) as FileFolder[]
  }

  //新建文件夹
  static async createNewFolder(context: Context, folder_name: string): Promise<FileFolder[]> {
    const new_folder: FileFolder = {
      name: folder_name,
      date: systemDateTime.getTime(true).toString(),
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

  // 视频添加进文件夹
  static addVideoInFileFolder(context: Context, videoMetaData: VideoMetadata, fromFolderDate: string,
    targetFolderDate: string) {
    let folders = Preferences.getFileFolder(context) as FileFolder[]
    let fromFolderIndex = folders.findIndex(i => i.date === fromFolderDate)
    let targetFolderIndex = folders.findIndex(i => i.date === targetFolderDate)
    folders[fromFolderIndex].video_list = folders[fromFolderIndex].video_list.filter(i => i.uri !== videoMetaData.uri)
    if (folders[targetFolderIndex].video_list.findIndex(i => i.uri === videoMetaData.uri) === -1) {
      folders[targetFolderIndex].video_list.push(videoMetaData)
    }
    Preferences.saveFileFolder(context, folders)
    return folders
  }

  // 删除文件夹
  static deleteFileFolder(context: Context, file_folder: FileFolder) {
    let folders = Preferences.getFileFolder(context)
    folders = folders.filter(i => i.date !== file_folder.date)
    Preferences.saveFileFolder(context, folders)
    return folders
  }

  //改变文件夹名称
  static async changeFileFolderName(context: Context, folder: FileFolder, newFolderName: string) {
    let folders = Preferences.getFileFolder(context) as FileFolder[]
    let folderIndex = folders.findIndex(i => i.date === folder.date)
    folders[folderIndex].name = newFolderName
    Preferences.saveFileFolder(context, folders)
    return folders
  }

  // 更新文件夹内视频
  static async updateFileFolder(context: Context, folder: FileFolder, newVideoMetaDataList: VideoMetadata[]) {
    let folders = Preferences.getFileFolder(context) as FileFolder[]
    let folderIndex = folders.findIndex(i => i.date === folder.date)
    folders[folderIndex].video_list = newVideoMetaDataList
    Preferences.saveFileFolder(context, folders)
  }

  // 更新文件夹所有内容
  static async updateFileFolderList(context: Context, file_folder: FileFolder) {
    let file_folder_list = Preferences.getFileFolder(context)
    file_folder_list = file_folder_list.filter(i => i.date !== file_folder?.date)
    file_folder_list.push(file_folder)
    Preferences.saveFileFolder(context, file_folder_list)
  }
}

export default FileFolderUtil