import { FileFolder } from '../interfaces/FileFolderInterface'
import { VideoMetadataInterface } from '../interfaces/VideoMetadataInterface'

// Navigation 传参设置
export class PlayerParams {
  public metadata: VideoMetadataInterface | undefined
  public metadata_list: VideoMetadataInterface [] | undefined
  public file_folder: FileFolder | undefined

  constructor(metadata: VideoMetadataInterface | undefined, metadata_list: VideoMetadataInterface [] | undefined,
    file_folder: FileFolder | undefined) {
    this.metadata = metadata
    this.metadata_list = metadata_list
    this.file_folder = file_folder
  }
}