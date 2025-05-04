import { VideoMetadata } from './VideoMetadata';

export interface FileFolder {
  name: string,
  date: string,
  video_list: VideoMetadata[]
}