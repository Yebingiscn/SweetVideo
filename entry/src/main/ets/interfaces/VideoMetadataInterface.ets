// 视频数据
export interface VideoMetadata {
  uri: string
  title: string
  /** 内嵌歌手信息；普通视频可能没有该字段。 */
  artist?: string
  /** 内嵌专辑信息；普通视频可能没有该字段。 */
  album?: string
  date: string
  size: number[]
  /** 内嵌封面的原始分辨率；纯音频的 size 同样使用此值。 */
  cover_size?: number[]
  /** 是否存在真正的视频轨；内嵌封面不计为视频轨。undefined 表示未探测或探测失败。 */
  has_video_track?: boolean
  time: number
  /** 上次保存的播放进度，单位为毫秒。 */
  last_play: number
  /** 最近一次实际播放的时间戳，单位为毫秒。 */
  last_played_at?: number
  format: string
  video_size: string
  /** 媒体平均码率，单位为 bit/s；纯音频用于品质分级。 */
  bit_rate?: number
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
  /** 仅用于当前网络播放请求，不写入播放历史等持久化数据。 */
  network_http_headers?: Record<string, string>
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
