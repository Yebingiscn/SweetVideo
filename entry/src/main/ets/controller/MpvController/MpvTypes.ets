export interface MpvPlayerOptions {
  videoUrl: string;
}

/**
 * 字幕轨道信息
 */
export interface MpvSubtitleTrack {
  /** 轨道 ID */
  id: number;

  /** 轨道标题 */
  title: string;

  /** 语言代码 (如 'en', 'zh', 'ja') */
  lang: string;

  /** 是否为外部字幕 */
  external: boolean;
}

/**
 * 字幕样式配置
 */
export interface MpvSubtitleStyle {
  /** 字体大小 (像素) */
  fontSize?: number;

  /** 字体颜色 (16进制, 如 '#FFFFFF') */
  color?: string;

  /** 字幕位置 ('bottom' | 'center' | 'top') */
  position?: string;

  /** 字体边框宽度 */
  borderWidth?: number;

  /** 字体背景透明度 (0-1) */
  alpha?: number;
}

/**
 * 音频轨道信息
 */
export interface MpvAudioTrack {
  /** 轨道 ID */
  id: number;

  /** 轨道标题 */
  title: string;

  /** 语言代码 (如 'en', 'zh', 'ja') */
  lang: string;

  /** 是否为外部音频 */
  external: boolean;

  /** 编解码器 */
  codec?: string;

  /** 声道数 */
  channels?: number;
}

/**
 * MPV命令执行结果
 */
export interface MpvCommandResult {
  /** 是否执行成功 */
  success: boolean;

  /** MPV返回的错误码 */
  code: number;

  /** 错误信息 (仅在失败时存在) */
  error?: string;
}
