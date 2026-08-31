// Type declarations for libmpvnative native module
declare module 'libmpvnative.so' {
  // ==================== 硬件解码模式 ====================
  // 0 = HWDEC_MODE_BUFFER (gpu-next + OpenGL ES/Vulkan + OHCodec Surface-to-GPU，支持后处理)
  // 1 = HWDEC_MODE_SURFACE (ohcodec-osd + ohcodec，零拷贝，性能最优)
  export const setHwdecMode: (mode: number) => void;

  export const getHwdecMode: () => number;

  // ==================== 解码类型（仅 Buffer 模式可用） ====================
  // 0 = DECODE_TYPE_HW (硬件解码，默认)
  // 1 = DECODE_TYPE_SW (软件解码)
  export const setDecodeType: (type: number) => void;

  export const getDecodeType: () => number;

  // 0 = OpenGL ES (default), 1 = Vulkan. Only used by Buffer mode.
  export const setGpuApi: (api: number) => void;

  export const getGpuApi: () => number;

  // ==================== 核心函数 ====================
  export const create: () => number | null;

  export const destroy: (mpvHandle: number) => void;

  export const reset: (mpvHandle: number) => number | null;

  export const command: (mpvHandle: number, args: Array<string>) => any;

  export const isInitialized: () => boolean;
  export const isCoreAlive: () => boolean;
  export const registerMpvLogCallback: (callback: (prefix: string, level: number, text: string,
    timestampMs: number) => void) => boolean;
  export const unregisterMpvLogCallback: () => void;

  // ==================== 视频加载 ====================
  export const loadVideo: (mpvHandle: number, url: string, startPosition?: number,
    subtitleTrackId?: number, userAgent?: string) => number;

  // ==================== 光盘设备配置（ISO文件播放）====================
  export const setBlurayDevice: (mpvHandle: number, isoPath: string) => boolean;
  export const setDvdDevice: (mpvHandle: number, isoPath: string) => boolean;

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

  export const selectSecondarySubtitle: (mpvHandle: number, trackId: number) => boolean;

  export const setSubtitleDelay: (mpvHandle: number, delayMillis: number) => boolean;

  export const setSubtitleRenderVisibility: (mpvHandle: number, primaryVisible: boolean,
    secondaryVisible: boolean) => boolean;

  export const getSubtitleTexts: (mpvHandle: number) => { primary: string; secondary: string };

  export const loadExternalSubtitle: (mpvHandle: number, options: {
    path: string;
    lang?: string;
    select?: boolean;
  }) => boolean;

  export const setSubtitleStyle: (mpvHandle: number, style: {
    fontSize?: number;
    color?: string;
    bold?: boolean;
    italic?: boolean;
    borderSize?: number;
    borderColor?: string;
    shadowEnabled?: boolean;
    shadowOffset?: number;
    shadowColor?: string;
    backgroundColor?: string;
    backgroundOpacity?: number;
    position?: number;
    preserveAssStyle?: boolean;
    preserveSecondaryAssStyle?: boolean;
    scale?: number;
  }) => boolean;

  export const getCurrentSubtitleTrack: (mpvHandle: number) => number;

  export const getCurrentSecondarySubtitleTrack: (mpvHandle: number) => number;

  // ==================== 音频 ====================
  export const getAudioTracks: (mpvHandle: number) => Array<any>;

  export const selectAudio: (mpvHandle: number, trackId: number) => void;

  export const getCurrentAudioTrack: (mpvHandle: number) => number;

  export const setLoudnessGain: (mpvHandle: number, loudnessGain: number) => boolean;

  export const setAudioChannel: (mpvHandle: number, channelMode: number) => boolean;

  // ==================== 视频信息 ====================
  export const getHardwareDecoder: (mpvHandle: number) => string;

  export const getVideoWidth: (mpvHandle: number) => number;

  export const getVideoHeight: (mpvHandle: number) => number;

  export const setKeepAspect: (mpvHandle: number, keepAspect: boolean) => void;

  // ==================== 杜比视界 Profile 检测 ====================
  // 0 = 非杜比视界, 5 = Profile 5, 7 = Profile 7, 8 = Profile 8, -1 = 其他杜比视界 Profile
  export const getDolbyVisionProfile: (mpvHandle: number) => number;

  // ==================== 视频 HDR 类型检测 ====================
  // 0=NONE, 1=HDR_VIVID, 2=HDR10, 3=DOLBY_VISION
  export const getVideoHdrType: (mpvHandle: number) => number;

  // ==================== 音频类型检测 ====================
  // 0=NONE, 1=DTS, 2=DOLBY_AUDIO, 3=AUDIO_VIVID
  export const getAudioType: (mpvHandle: number) => number;

  // ==================== 缓存配置 ====================
  export const setCacheSize: (size_mb: number) => void;

  export const getCacheSize: () => number;

  // ==================== 网络 ====================
  export interface NetworkSpeedInfo {
    speed: number;
    speedStr: string;
    /** mpv cache buffering state (0-100). Kept for API compatibility. */
    cacheSizeKB: number;
    bufferPercent: number;
    cacheDuration: number;
    buffering: boolean;
    /** Whether the current source is a network stream. */
    active: boolean;
  }

  export const getNetworkSpeed: (mpvHandle: number) => NetworkSpeedInfo;
  export const registerNetworkStateCallback: (callback: (state: NetworkSpeedInfo) => void) => boolean;
  export const unregisterNetworkStateCallback: () => boolean;

  // ==================== OSD Surface 配置 ====================
  export const setOsdSurface: (surfaceId: string, width: number, height: number) => void;

  // ==================== OSD 等级 ====================
  // 0=关闭, 1=进度条, 2=进度条+状态, 3=全部(含帧时间等调试信息)
  export const setOsdLevel: (level: number) => void;

  export const getOsdLevel: () => number;

  export const setGlslShaders: (shaders: string[]) => boolean;

  // ==================== 播放完成事件 ====================
  export const registerPlaybackCompleteCallback: (callback: (requestId: number) => void) => void;

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

  // ==================== 缓冲状态变化事件 ====================
  export const registerBufferingStateCallback: (callback: (buffering: boolean) => void) => void;

  export const unregisterBufferingStateCallback: () => void;

  // ==================== 暂停状态变化事件 ====================
  export const registerPauseStateCallback: (callback: (paused: boolean) => void) => void;

  export const unregisterPauseStateCallback: () => void;

  // ==================== 媒体加载状态事件 ====================
  export const registerMediaLoadCallback: (callback: (loaded: boolean, errorCode: number,
    requestId: number) => void) => void;

  export const unregisterMediaLoadCallback: () => void;

  // ==================== 章节 ====================
  export const getChapterList: (mpvHandle: number) => Array<{ index: number; title: string; time: number }>;

  // ==================== FFmpeg 缩略图 ====================
  export interface FFmpegMediaInfo {
    /** 已按容器旋转信息交换后的显示宽高。 */
    sourceWidth: number;
    sourceHeight: number;
    /** 内嵌封面的原始显示宽高；没有封面时为 0。 */
    coverWidth: number;
    coverHeight: number;
    /** 0、90、180 或 270。 */
    rotation: number;
    durationMs: number;
    frameRate: number;
    bitRate: number;
    /** 0=NONE, 1=HDR_VIVID/HLG, 2=HDR10, 3=DOLBY_VISION */
    hdrType: number;
    /** 0=非杜比视界，-1=未知 Profile，其余为 Profile 编号。 */
    dolbyVisionProfile: number;
    /** 0=NONE, 1=DTS, 2=DOLBY_AUDIO, 3=AUDIO_VIVID */
    audioType: number;
    audioStreamCount: number;
    subtitleStreamCount: number;
    hasEmbeddedCover: boolean;
    formatName: string;
    formatLongName: string;
    videoCodec: string;
    audioCodec: string;
    title: string;
    artist: string;
    album: string;
    comment: string;
    creationTime: string;
    /** FFmpeg 标签原始字节，由 ArkTS 的 UniversalDetector 识别编码。 */
    titleData: ArrayBuffer;
    artistData: ArrayBuffer;
    albumData: ArrayBuffer;
    commentData: ArrayBuffer;
    creationTimeData: ArrayBuffer;
  }

  export interface FFmpegThumbnailFrame {
    data: ArrayBuffer;
    width: number;
    height: number;
    stride: number;
    sourceWidth: number;
    sourceHeight: number;
    coverWidth: number;
    coverHeight: number;
    durationMs: number;
    frameRate: number;
    /** 0=NONE, 1=HDR_VIVID/HLG, 2=HDR10, 3=DOLBY_VISION */
    hdrType: number;
    /** 0=非杜比视界，-1=未知 Profile，其余为 Profile 编号。 */
    dolbyVisionProfile: number;
    /** 0=NONE, 1=DTS, 2=DOLBY_AUDIO, 3=AUDIO_VIVID */
    audioType: number;
    colorManaged: boolean;
  }

  /**
   * 创建可复用的缩略图会话。source 可以是本地 fd 或网络 URL；本地 fd 会在 native 内复制。
   */
  export const createThumbnailExtractor: (source: number | string, offset?: number, length?: number) => number;

  /** 只解析容器和轨道信息，不打开解码器或解码视频帧。 */
  export const getMediaInfo: (extractorId: number) => Promise<FFmpegMediaInfo>;

  export const extractThumbnailFrame: (extractorId: number, timeUs: number,
    maxWidth: number, maxHeight: number, preferEmbeddedCover?: boolean) => Promise<FFmpegThumbnailFrame>;

  export const releaseThumbnailExtractor: (extractorId: number) => boolean;
}
