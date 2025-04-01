import SelectFileUtil from './SelectFileUtil'
import ToolsUtil from './ToolsUtil'
import { VideoMetadata } from './VideoInfoUtil'

export interface FileFolder {
  name: string,
  date: string,
  video_list: VideoMetadata[]
}

class FileFolderUtil {
  async createNewFolder(context: Context, folder_name: string): Promise<FileFolder[]> {
    const new_folder: FileFolder = {
      name: folder_name,
      date: new Date().getTime().toString(),
      video_list: []
    }
    const file_folder_list = await SelectFileUtil.getFileFolder(context) as FileFolder[]
    if (!file_folder_list.some(i => i.name === new_folder.name)) {
      console.error('test1')
      file_folder_list.push(new_folder)
      await SelectFileUtil.saveFileFolder(context, file_folder_list)
      return file_folder_list
    } else {
      ToolsUtil.showToast('添加失败，已存在相同文件夹')
      return file_folder_list
    }
  }

  async addVideoInFileFolder(context: Context, video_meta_data: VideoMetadata, file_folder_date: string) {
    let file_folder_list = await SelectFileUtil.getFileFolder(context) as FileFolder[]
    let file_folder = file_folder_list.find(i => i.date === file_folder_date)
    file_folder?.video_list.push(video_meta_data)
    await SelectFileUtil.saveFileFolder(context, file_folder_list)
    return file_folder_list
  }

  async deleteFileFolder(context: Context, file_folder: FileFolder, file_folder_list: FileFolder[]) {
    file_folder_list = file_folder_list.filter(i => i.date !== file_folder.date)
    await SelectFileUtil.saveFileFolder(context, file_folder_list)
    return file_folder_list
  }
}

export default new FileFolderUtil()