// 视频数据
export interface VideoMetadata {
  uri: string
  title: string
  date: string
  size: number[]
  /** 内嵌封面的原始分辨率；纯音频的 size 同样使用此值。 */
  cover_size?: number[]
  /** 是否存在真正的视频轨；内嵌封面不计为视频轨。 */
  has_video_track?: boolean
  time: number
  last_play: number
  format: string
  video_size: string
  hdr_type: number
  audio_type: number
  frame_rate: number
  start_time: number
  end_time: number
  external_subtitle_format: string
  pointA: number
  pointB: number
  subtitle_mode?: number
  subtitle_visible?: boolean
  subtitle_ai_asr_shown?: boolean
  subtitle_3d_mode?: number
  subtitle_offset_millis?: number
  subtitle_track_id?: number
  audio_track_id?: number
  network_user_agent?: string
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
  subtitleMode?: number
  subtitleVisible?: boolean
  subtitleAIAsrShown?: boolean
  subtitle3DMode?: number
  subtitleOffsetMillis?: number
  subtitleTrackId?: number
  audioTrackId?: number | null
  hdrType?: number
  audioType?: number
}
