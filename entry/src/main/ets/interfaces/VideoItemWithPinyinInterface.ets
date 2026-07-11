import { VideoMetadata } from './VideoMetadataInterface';

export interface ItemWithPinyin<T> {
  item: T;
  pinyin: string;
}

export interface VideoItemWithPinyin {
  item: VideoMetadata;
  pinyin: string;
}