import { media } from '@kit.MediaKit'

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

export const PINCH_SCALE_SENSITIVITY = 0.007 // 捏合缩放的敏感度

export const MIN_SCALE_FACTOR = 0.5 // 最小缩放比例

export const MAX_SCALE_FACTOR = 2.0 // 最大缩放比例

export const MAX_WIDTH_MULTIPLIER = 3.0 // 最大宽度倍数（相对于原始宽度）

export const MIN_WIDTH_MULTIPLIER = 0.5 // 最小宽度倍数（相对于原始宽度）

export const PRIVACY_BACKGROUND_BLUR_AMOUNT = 1000; // 隐私背景下的模糊强度

export const NO_BLUR_AMOUNT = 0; // 无模糊

export const GB = 1024 * 1024 * 1024

export const MB = 1024 * 1024

export const IMAGE_ANALYZER_CONFIG: ImageAnalyzerConfig = {
  types: [ImageAnalyzerType.SUBJECT, ImageAnalyzerType.TEXT]
}

export const OPTIONS: ImageAIOptions = {
  types: [ImageAnalyzerType.SUBJECT, ImageAnalyzerType.TEXT],
  aiController: new ImageAnalyzerController()
}

export const SUPPORT_VIDEO_FORMAT: string[] = ['视频|.mpv,.mkv,.mp4,.mov,.rmvb,.wmv,.avi,.m4v',
  'mp4', 'flv', 'mkv', 'ts', 'mov', 'rmvb', 'wmv', 'avi', 'm4v'
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
  { value: '16:9' },
  { value: '4:3' },
  { value: '等比放大 110%' },
  { value: '等比放大 120%' },
  { value: '等比放大 130%' },
  { value: '等比放大 140%' }]

// 倍速枚举，绑定系统倍速，倍速映射：用户倍速 ↔ 系统枚举
export const VIDEO_SPEED_MAP =
  new Map<number, media.PlaybackSpeed>([[0.125, media.PlaybackSpeed.SPEED_FORWARD_0_125_X],
    [0.25, media.PlaybackSpeed.SPEED_FORWARD_0_25_X],
    [0.5, media.PlaybackSpeed.SPEED_FORWARD_0_50_X],
    [0.75, media.PlaybackSpeed.SPEED_FORWARD_0_75_X], [1, media.PlaybackSpeed.SPEED_FORWARD_1_00_X],
    [1.25, media.PlaybackSpeed.SPEED_FORWARD_1_25_X], [1.5, media.PlaybackSpeed.SPEED_FORWARD_1_50_X],
    [1.75, media.PlaybackSpeed.SPEED_FORWARD_1_75_X], [2, media.PlaybackSpeed.SPEED_FORWARD_2_00_X],
    [3, media.PlaybackSpeed.SPEED_FORWARD_3_00_X]])

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
  '3840': '4K Ultra HD',
  '4096': '4K Ultra HD',
  '7680': '8K Ultra HD',
  '2720x1530': 'FHD+',
  '1216x2160': 'FHD+',
}