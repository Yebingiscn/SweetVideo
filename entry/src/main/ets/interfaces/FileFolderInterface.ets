import { VideoMetadataInterface } from './VideoMetadataInterface';

export interface FileFolderInterface {
  name: string,
  date: string,
  video_list: VideoMetadataInterface[]
}