// Type declarations for libmpvnative native module
declare module 'libmpvnative.so' {
  // ==================== 硬件解码模式 ====================
  // 0 = HWDEC_MODE_BUFFER (gpu-next + ohcodec-copy，默认，支持后处理)
  // 1 = HWDEC_MODE_SURFACE (ohcodec + ohcodec，零拷贝，性能最优)
  export const setHwdecMode: (mode: number) => void;

  export const getHwdecMode: () => number;

  // ==================== 解码类型（仅 Buffer 模式可用） ====================
  // 0 = DECODE_TYPE_HW (硬件解码，默认)
  // 1 = DECODE_TYPE_SW (软件解码)
  export const setDecodeType: (type: number) => void;

  export const getDecodeType: () => number;

  // ==================== 核心函数 ====================
  export const create: () => number | null;

  export const destroy: (mpvHandle: number) => void;

  export const reset: (mpvHandle: number) => void;

  export const command: (mpvHandle: number, args: Array<string>) => any;

  export const isInitialized: () => boolean;

  // ==================== 视频加载 ====================
  export const loadVideo: (mpvHandle: number, url: string, startPosition?: number) => void;

  // ==================== 蓝光设备配置（ISO文件播放）====================
  export const setBlurayDevice: (mpvHandle: number, isoPath: string) => void;

  // ==================== 播放控制 ====================
  export const seek: (mpvHandle: number, seconds: number, exact: boolean) => void;

  export const pause: (playerId: number) => boolean;

  export const play: (playerId: number) => boolean;

  export const setSpeed: (mpvHandle: number, speed: number) => void;

  export const getCurrentPosition: (mpvHandle: number) => number;

  export const getDuration: (mpvHandle: number) => number;

  export const getCacheDuration: (mpvHandle: number) => number;

  // ==================== 字幕 ====================
  export const getSubtitleTracks: (mpvHandle: number) => Array<any>;

  export const selectSubtitle: (mpvHandle: number, trackId: number) => void;

  export const setSubtitleStyle: (mpvHandle: number, style: any) => void;

  export const getCurrentSubtitleTrack: (mpvHandle: number) => number;

  // ==================== 音频 ====================
  export const getAudioTracks: (mpvHandle: number) => Array<any>;

  export const selectAudio: (mpvHandle: number, trackId: number) => void;

  export const getCurrentAudioTrack: (mpvHandle: number) => number;

  export const setLoudnessGain: (mpvHandle: number, loudnessGain: number) => boolean;

  // ==================== 视频信息 ====================
  export const getHardwareDecoder: (mpvHandle: number) => string;

  export const getVideoWidth: (mpvHandle: number) => number;

  export const getVideoHeight: (mpvHandle: number) => number;

  export const setKeepAspect: (mpvHandle: number, keepAspect: boolean) => void;

  // ==================== 缓存配置 ====================
  export const setCacheSize: (size_mb: number) => void;

  export const getCacheSize: () => number;

  // ==================== 网络 ====================
  export const getNetworkSpeed: (mpvHandle: number) => any;

  // ==================== OSD Surface 配置 ====================
  export const setOsdSurface: (surfaceId: string, width: number, height: number) => void;

  // ==================== 播放完成事件 ====================
  export const registerPlaybackCompleteCallback: (callback: () => void) => void;

  export const unregisterPlaybackCompleteCallback: () => void;

  // ==================== 播放时间更新事件 ====================
  export const registerTimeUpdateCallback: (callback: (timeMs: number) => void) => void;

  export const unregisterTimeUpdateCallback: () => void;

  // ==================== 视频尺寸变化事件 ====================
  export const registerVideoSizeChangedCallback: (callback: () => void) => void;

  export const unregisterVideoSizeChangedCallback: () => void;

  // ==================== Surface模式错误事件 ====================
  export const registerSurfaceModeErrorCallback: (callback: (errorMessage: string) => void) => void;

  export const unregisterSurfaceModeErrorCallback: () => void;
}