import { SubtitleTrack } from '../../interfaces/AudioTrackInterface';

export interface MpvPlayerOptions {
  videoUrl: string;
}

export interface MpvSubtitleTrack extends SubtitleTrack {
  external: boolean;
  codec?: string;
}

export interface MpvSubtitleTexts {
  primary: string;
  secondary: string;
}

/**
 * 字幕样式配置
 */
export interface MpvSubtitleStyle {
  /** 字体大小 (像素) */
  fontSize?: number;

  /** 字体颜色 (16进制, 如 '#FFFFFF') */
  color?: string;

  /** 是否使用粗体 */
  bold?: boolean;

  /** 是否使用斜体 */
  italic?: boolean;

  /** 字幕位置（0-100，从顶部到底部） */
  position?: number;

  /** 字体边框宽度 */
  borderSize?: number;

  /** 描边颜色 */
  borderColor?: string;

  /** 是否启用阴影 */
  shadowEnabled?: boolean;

  /** 阴影偏移 */
  shadowOffset?: number;

  /** 阴影颜色 */
  shadowColor?: string;

  /** 字幕背景颜色 */
  backgroundColor?: string;

  /** 字体背景透明度 (0-100) */
  backgroundOpacity?: number;

  /** 保留 ASS 文件自带样式，只应用缩放和垂直位置 */
  preserveAssStyle?: boolean;

  /** 淇濈暀 MPV 鍓瓧骞曠殑 ASS 鏍峰紡 */
  preserveSecondaryAssStyle?: boolean;

  /** 相对于默认字号的缩放比例 */
  scale?: number;
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

export const enum MpvDecodingMethod {
  HARDWARE_SURFACE = 0,
  SOFTWARE = 1,
  HARDWARE_BUFFER = 2
}

export const enum MpvGpuApi {
  OPENGL = 0,
  VULKAN = 1
}

export const enum MpvAudioChannelMode {
  STEREO = 0,
  LEFT_ONLY = 1,
  RIGHT_ONLY = 2
}

export interface MpvChapter {
  index: number;
  title: string;
  time: number;
}
