export const DELAY_JUMP_TO_PLAYER: number = 450

export const DEFAULT_ANGLE: number = 0

export const MIRRORED_ANGLE: number = 180

export const AUTO_HIDE_SHOW_CONTROL_TIME: number = 12000

export const VOLUME_STEP: number = 0.5

export const SWIPE_THRESHOLD: number = 15 // 滑动距离阈值

export const SCREEN_DIVISIONS: number = 5 // 屏幕划分份数

export const LEFT_ZONE_DIVISION: number = 1 // 左侧区域占1份

export const RIGHT_ZONE_DIVISION: number = 4 // 右侧区域从第4份开始（即最后1份）

export const VERTICAL_PAN_SENSITIVITY: number = 2.5 // 垂直滑动手势灵敏度

export const VOLUME_PAN_MULTIPLIER: number = 20 // 音量手势调整倍率

export const SCREEN_HALF_DIVIDER: number = 2 // 屏幕对半分界

export const SCROLL_VOLUME_SENSITIVITY: number = 0.03 // 滚轮音量灵敏度

export const SCROLL_BRIGHTNESS_SENSITIVITY: number = 0.003 // 滚轮亮度灵敏度

export const PINCH_SCALE_SENSITIVITY = 0.5 // 捏合缩放的敏感度

export const MIN_SCALE_FACTOR = 0.5 // 最小缩放比例

export const MAX_SCALE_FACTOR = 2.0 // 最大缩放比例

export const MAX_WIDTH_MULTIPLIER = 3.0 // 最大宽度倍数（相对于原始宽度）

export const MIN_WIDTH_MULTIPLIER = 0.5 // 最小宽度倍数（相对于原始宽度）

export const PRIVACY_BACKGROUND_BLUR_AMOUNT = 1000 // 隐私背景下的模糊强度

export const LIGHT_MODE_BAR_COLOR = '#000000'

export const DARK_MODE_BAR_COLOR = '#ffffff'

export const NO_BLUR_AMOUNT = 0 // 无模糊

export const GB = 1024 * 1024 * 1024

export const MB = 1024 * 1024

export const KB = 1024

export enum LoginWithHWErrorCode {
  // 账号未登录
  ERROR_CODE_LOGIN_OUT = 1001502001,
  // 网络错误
  ERROR_CODE_NETWORK_ERROR = 1001502005,
  // 内部错误
  ERROR_CODE_INTERNAL_ERROR = 1001502009,
  // 用户取消授权
  ERROR_CODE_USER_CANCEL = 1001502012,
  // 系统服务异常
  ERROR_CODE_SYSTEM_SERVICE = 12300001,
  // 用户未同意用户协议
  ERROR_CODE_AGREEMENT_STATUS_NOT_ACCEPTED = 1005300001,
  // 重复请求
  ERROR_CODE_REQUEST_REFUSE = 1001500002
}

export const IMAGE_ANALYZER_CONFIG: ImageAnalyzerConfig = {
  types: [ImageAnalyzerType.SUBJECT, ImageAnalyzerType.TEXT]
}

export const OPTIONS: ImageAIOptions = {
  types: [ImageAnalyzerType.SUBJECT, ImageAnalyzerType.TEXT],
  aiController: new ImageAnalyzerController()
}

export const SUPPORT_VIDEO_FORMAT: string[] = ['视频|.mpv,.mkv,.mp4,.mov,.rmvb,.wmv,.avi,.m4v,.iso,.webm,.flv,.ts,.pmp',
  'mp4', 'flv', 'mkv', 'ts', 'mov', 'rmvb', 'wmv', 'avi', 'm4v', 'iso', 'webm', 'pmp'
]

export const SUPPORT_AUDIO_FORMAT: string[] =
  ['音频|.mp3,.wav,.flac,.dsf,.dsd,.dff,.m4a,.ape,.aac,.ogg,.amr,.aif,.aiff,.dts,.wma,.av3a',
    'wav', 'mp3', 'flac', 'dsf', 'dsd', 'dff', 'm4a', 'ape', 'aac', 'ogg', 'amr', 'aif', 'aiff', 'dts', 'wma', 'av3a'
  ]

export const SUPPORT_SUBTITLE_FORMAT: string[] = ['字幕|.ass,.srt,.vtt', 'srt', 'vtt', 'ass']

export const SCALE_FACTORS: Map<string, number> = new Map<string, number>([
  ['等比放大 110%', 1.1],
  ['等比放大 120%', 1.2],
  ['等比放大 130%', 1.3],
  ['等比放大 140%', 1.4]
])

export const SCREEN_EXTEND_LIST: Array<SelectOption> = [//屏幕扩展
  { value: '原始比例' },
  { value: '拉伸全屏' },
  { value: '按宽度全屏' },
  { value: '按高度全屏' },
  { value: '自定义比例' },
  { value: '16:9' },
  { value: '4:3' },
  { value: '等比放大 110%' },
  { value: '等比放大 120%' },
  { value: '等比放大 130%' },
  { value: '等比放大 140%' }]

export const VIDEO_SIZE_MAP: Record<string, string> = {
  '720': '720P HD',
  '800': 'HD+',
  '900': '900P HD+',
  '960': 'HD+',
  '1080': '1080P FHD',
  '1440': '2K QHD',
  '1600': 'UW QHD',
  '1666': 'Quad HD+',
  '1800': 'QHD+',
  '1960': '1080P FHD',
  '2560': '2K QHD',
  '3840': '4K UHD',
  '4096': '4K UHD',
  '7680': '8K UHD',
  '2720x1530': 'FHD+',
  '1216x2160': 'FHD+',
}

export const DANGER_COLOR = '#FF4D4F'

export const DANGER_COLOR_ALPHA_15 = 'rgba(255, 77, 79, 0.15)'

export const WARNING_COLOR = '#FAAD14'

export const WARNING_COLOR_ALPHA_15 = 'rgba(250, 173, 20, 0.15)'

export const DIALOG_TITLE_FONT_SIZE: number = 25

export const FULL_ALPHABET: string[] = [
  '#', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
  'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z'
]