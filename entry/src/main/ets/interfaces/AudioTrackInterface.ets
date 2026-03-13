// 音频数据
export interface AudioTrack {
  index: number
  language: string
  name: string
  mime: string
}

export interface SubtitleTrack {
  /** 轨道 ID */
  id: number;

  /** 轨道标题 */
  title: string;

  /** 语言代码 (如 'en', 'zh', 'ja') */
  lang: string;
}