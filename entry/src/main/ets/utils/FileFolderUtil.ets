import Preferences from '../database/Preferences'
import { FileFolder } from '../interfaces/FileFolderInterface'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'
import ToolsUtil from './ToolsUtil'
import { Context } from '@kit.AbilityKit'
import { systemDateTime } from '@kit.BasicServicesKit'
import DataSyncUtil from '../utils/DataSyncUtil'
import { FileFolderDataSource } from './DataUtil'
import { VideoListController } from '../component/VideoItemComponent/VideoItemComponent'
import PrivacySpaceUtil from './PrivacySpaceUtil'
import SelectFileUtil from './SelectFileUtil'
import RecentPlayUtil from './RecentPlayUtil'
import { PathUtils } from './PathUtils'
import SubtitleUtil from './SubtitleUtil'
import { fileIo as fs } from '@kit.CoreFileKit'

// 文件夹类
export default class FileFolderUtil {
  public static duplicateVideo: number = 0

  static getAllFolder(context: Context): FileFolder[] {
    return Preferences.getFileFolder(context) as FileFolder[]
  }

  //新建文件夹
  static async createNewFolder(context: Context, folder_name: string, fileFolderSource?: FileFolderDataSource) {
    const new_folder: FileFolder = {
      name: folder_name,
      date: systemDateTime.getTime(false).toString(), // 这里不需要使用纳秒
      video_list: [],
    }
    const file_folder_list = Preferences.getFileFolder(context) as FileFolder[]
    if (!file_folder_list.some(i => i.name === new_folder.name)) {
      file_folder_list.push(new_folder)
      Preferences.saveFileFolder(context, file_folder_list)
    } else {
      ToolsUtil.showToast('添加失败，已存在相同文件夹')
    }
    if (fileFolderSource) {
      fileFolderSource.updateData(file_folder_list)
    }
    return file_folder_list
  }

  // 添加视频到文件夹，支持批量
  static transferVideosToFileFolder(context: Context, videos: VideoMetadata[], fromFolderDate: string,
    targetFolderDate: string): FileFolder[] {
    const folders = Preferences.getFileFolder(context) || [];
    // 单次遍历查找两个文件夹
    let fromFolder: FileFolder | undefined;
    let targetFolder: FileFolder | undefined;
    for (const folder of folders) {
      if (!fromFolder && folder.date === fromFolderDate) {
        fromFolder = folder;
      }
      if (!targetFolder && folder.date === targetFolderDate) {
        targetFolder = folder;
      }
      if (fromFolder && targetFolder) {
        break;
      }
    }
    if (!fromFolder || !targetFolder) {
      return folders;
    }
    // 创建目标视频集合用于快速查找
    const targetVideoSet = new Set(targetFolder.video_list.map(v => v.date));
    // 创建待移动视频集合
    const videosToMove = new Set(videos.map(v => v.date));
    // 批量过滤源文件夹视频
    fromFolder.video_list = fromFolder.video_list.filter(
      v => !videosToMove.has(v.date)
    );
    // 批量添加新视频（过滤已存在的）
    const newVideos = videos.filter(v => !targetVideoSet.has(v.date));
    targetFolder.video_list.push(...newVideos);
    // 保存并返回
    Preferences.saveFileFolder(context, folders);
    return folders;
  }

  static async delVideosFileFolder(context: Context, videoListController: VideoListController,
    folderDataSource: FileFolderDataSource) {
    let folders = Preferences.getFileFolder(context) as FileFolder[]
    let folderIndex = folders.findIndex(i => i.date === videoListController.folder.date)
    const folder = folders[folderIndex]
    const surviveVideo = new Map<string, VideoMetadata>()
    for (const video of folder.video_list) {
      surviveVideo.set(video.uri, video)
    }
    for (const item of DataSyncUtil.delMultipleList) {
      if (!item.date) {
        continue;
      } // 跳过无效数据

      RecentPlayUtil.delData(PathUtils.appContext!, item.uri);
      await SubtitleUtil.deleteSubtitle(PathUtils.subtitlePath, item.date);
      await SelectFileUtil.deleteCover(item.date);
      surviveVideo.delete(item.uri);
    }
    folder.video_list = Array.from(surviveVideo.values())
    folders[folderIndex] = folder
    Preferences.saveFileFolder(context, folders)
    videoListController.updateData(undefined, folders[folderIndex])
    folderDataSource.updateData(folders)
    return folders[folderIndex]
  }

  static delVideoInFileFolder(context: Context, videoListController: VideoListController,
    folderDataSource: FileFolderDataSource) {
    const videoMetaData = DataSyncUtil.editingVideo
    let folders = Preferences.getFileFolder(context) as FileFolder[]
    let folderIndex = folders.findIndex(i => i.date === videoListController.folder.date)
    if (folderIndex !== -1) {
      folders[folderIndex].video_list =
        folders[folderIndex].video_list.filter(item => item.date !== videoMetaData?.date)
      videoListController.updateData(undefined, folders[folderIndex])
      folderDataSource.updateData(folders)
      Preferences.saveFileFolder(context, folders)
    }
    return folders[folderIndex]
  }

  // 删除文件夹
  static deleteFileFolder(context: Context, file_folder: FileFolder, fileDataSource?: FileFolderDataSource) {
    let folders = Preferences.getFileFolder(context)
    folders = folders.filter(i => i.date !== file_folder.date)
    Preferences.saveFileFolder(context, folders)
    if (fileDataSource) {
      fileDataSource.updateData(folders)
    }
    return folders
  }

  //改变文件夹名称
  static async changeFileFolderName(context: Context, folder: FileFolder, newFolderName: string,
    fileFolderDataSource: FileFolderDataSource) {
    let folders = Preferences.getFileFolder(context) as FileFolder[]
    const targetFolder = folders.find(i => i.date === folder.date);
    if (targetFolder) {
      targetFolder.name = newFolderName;
    }
    Preferences.saveFileFolder(context, folders)
    fileFolderDataSource.updateData(folders)
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

  static existsVideoInFolders(context: Context, uri: string, title: string): boolean {
    let exists: boolean;
    if (PrivacySpaceUtil.getPrivacyMode()) {
      const videoMetaData = Preferences.getVideoMetaDataEncryption(context) || [];
      exists = videoMetaData.some(item => item.title === title);
    } else {
      const folders = Preferences.getFileFolder(context) || [];
      exists = folders.some(folder =>
      folder.video_list?.some(video => video.uri === uri)
      );
    }
    if (exists) {
      FileFolderUtil.duplicateVideo++;
    }
    return exists;
  }

  static extractRootFolderNameFromUri(uri: string, fileName: string): string | undefined {
    const prefix = SelectFileUtil.fileFolderUri + "/";
    if (!uri.startsWith(SelectFileUtil.fileFolderUri) || !uri.startsWith(prefix)) {
      return undefined;
    }
    const relativePath = uri.substring(prefix.length);
    // 必须以文件名结尾
    if (!relativePath.endsWith(fileName)) {
      return undefined;
    }
    const dirPath = relativePath.substring(0, relativePath.length - fileName.length);
    const cleanDir = dirPath.replace(/\/+$/, ""); // 移除尾部斜杠
    if (!cleanDir) {
      return undefined;
    }
    const parts = cleanDir.split("/");
    return parts[0] || undefined;
  }

  // 检查文件夹是否存在
  static fileFolderExistCheck() {
    const paths = [
      PathUtils.videoPath,
      PathUtils.subtitlePath,
      PathUtils.photoPath
    ];

    paths.forEach(path => {
      try {
        if (!fs.accessSync(path)) {
          fs.mkdirSync(path);
        }
      } catch (error) {
        console.error(`Failed to create directory ${path}:`, error);
      }
    });
  }
}