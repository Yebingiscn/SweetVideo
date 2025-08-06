// 播放器数据结构
export interface VideoMetadataFromPlayer {
  uri: string
  title: string
  date: string
  size: number[]
  time: number
  last_play: number
  start_time: number
  end_time: number
}