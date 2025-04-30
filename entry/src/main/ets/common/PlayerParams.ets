import { FileFolder } from '../utils/FileFolderUtil'
import { VideoMetadata } from '../utils/VideoInfoUtil'

// Navigation 传参设置
export class PlayerParams {
  public metadata: VideoMetadata | undefined
  public metadata_list: VideoMetadata [] | undefined
  public file_folder: FileFolder | undefined

  constructor(metadata: VideoMetadata | undefined, metadata_list: VideoMetadata [] | undefined,
    file_folder: FileFolder | undefined) {
    this.metadata = metadata
    this.metadata_list = metadata_list
    this.file_folder = file_folder
  }
}