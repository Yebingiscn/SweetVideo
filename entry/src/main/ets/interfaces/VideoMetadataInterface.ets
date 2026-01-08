// 视频数据
export interface VideoMetadata {
  uri: string
  title: string
  date: string
  size: number[]
  time: number
  last_play: number
  format: string
  video_size: string
  hdr_type: number
  start_time: number
  end_time: number
  external_subtitle_format: string
  pointA: number
  pointB: number
}

// 保存数据
export interface SaveOptions {
  playTime?: number
  size?: number[]
  startTime?: number
  endTime?: number
  totalTime?: number
  pointA?: number
  pointB?: number
}