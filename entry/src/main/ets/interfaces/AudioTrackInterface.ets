// 音频数据
export interface AudioTrack {
  index: number
  language: string
  name: string
  mime: string,
  channelCount: number,
}

export interface SubtitleTrack {
  id: number
  title: string
  lang: string
  external?: boolean
}