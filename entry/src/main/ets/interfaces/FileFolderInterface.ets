import { VideoMetadata } from './VideoMetadataInterface';

export interface FileFolder {
  name: string,
  date: string,
  video_list: VideoMetadata[]
}