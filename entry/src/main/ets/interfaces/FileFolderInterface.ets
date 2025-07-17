import { VideoMetadata } from './VideoMetadataInterface';

// 文件夹
export interface FileFolder {
  name: string,
  date: string,
  video_list: VideoMetadata[]
}
