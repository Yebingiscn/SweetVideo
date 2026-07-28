import { FileFolder } from '../interfaces/FileFolderInterface'
import { VideoMetadata } from '../interfaces/VideoMetadataInterface'

class DataSyncUtil {
  public editingVideo: VideoMetadata | undefined = undefined
  public editingFolder: FileFolder | undefined = undefined
  public movingFolderDate: string = ''
  public deletedVideos: VideoMetadata[] = []
  public delMultipleList: VideoMetadata[] = []
  public minSideBarWidth: number = 150
  public minContentWidth: number = 325
  public lastPlayVideoIndex: number = -1
}

export default new DataSyncUtil()

export const OOBEVersion = 0
